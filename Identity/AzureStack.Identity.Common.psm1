# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
.Synopsis
    Initialize the Azure RM environment
#>
function Initialize-AzureRmEnvironment {
    [CmdletBinding()]
    param
    (
        # The endpoint of the Azure Stack Resource Manager service.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateScript( { $_.Scheme -eq [System.Uri]::UriSchemeHttps })]
        [uri] $ResourceManagerEndpoint,

        # The specified name of this environment
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $EnvironmentName
    )

    Remove-AzureRMEnvironment -Name $environmentName -ErrorAction Ignore | Out-Null
    $azureEnvironmentParams = @{
        Name        = $environmentName
        ARMEndpoint = $ResourceManagerEndpoint
    }
    
    Write-Verbose -Message "Add azure environment with parameters: $(ConvertTo-Json $azureEnvironmentParams)" -Verbose
    $azureEnvironment = Add-AzureRmEnvironment @azureEnvironmentParams -ErrorAction Ignore
    $azureEnvironment = Get-AzureRmEnvironment -Name $environmentName -ErrorAction Stop
    return $azureEnvironment
}

<#
.Synopsis
    Initialize the Azure user account
#>
function Initialize-AzureRmUserAccount {
    [CmdletBinding()]
    param
    (
        # The azure environment
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment] $AzureEnvironment,

        # The name of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId,

        # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId = $null,

        # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionName = $null,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $params = @{
        EnvironmentName = $azureEnvironment.Name
    }
    if (-not $azureEnvironment.EnableAdfsAuthentication) {
        $params += @{ TenantId = $DirectoryTenantId }
    }
    if ($AutomationCredential) {
        $params += @{ Credential = $AutomationCredential }
    }
    # Prompts the user for interactive login flow if automation credential is not specified
    #$DebugPreference = "Continue"
    Write-Verbose "Add azure RM account with parameters $(ConvertTo-JSON $params)" -Verbose
    $azureAccount = Add-AzureRmAccount @params
    if ($SubscriptionName) {
        Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
    }
    elseif ($SubscriptionId) {
        Select-AzureRmSubscription -SubscriptionId $SubscriptionId | Out-Null
    }

    return $azureAccount
}

<#
.Synopsis
    Initialize the Azure user account and get refresh token for the azure environment
#>
function Initialize-AzureRmUserRefreshToken {
    [CmdletBinding()]
    param
    (
        # The azure environment
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment] $AzureEnvironment,

        # The name of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId,

        # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId = $null,

        # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionName = $null,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $params = @{
        AzureEnvironment  = $AzureEnvironment
        DirectoryTenantId = $DirectoryTenantId
    }
    if ($SubscriptionId) {
        $params.SubscriptionId = $SubscriptionId
    }
    if ($SubscriptionName) {
        $params.SubscriptionName = $SubscriptionName
    }
    if ($AutomationCredential) {
        $params.AutomationCredential = $AutomationCredential
    }
    Write-Verbose "Initializing user account with parameters $(ConvertTo-JSON $params)" -Verbose
    $azureStackAccount = Initialize-AzureRmUserAccount @params
    
    # Retrieve the refresh token
    $tokens = @()
    $tokens += try { [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems() } catch { }
    $tokens += try { [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache.ReadItems() } catch { }
    $refreshToken = $tokens |
    Where Resource -IEQ $AzureEnvironment.ActiveDirectoryServiceEndpointResourceId |
    Where IsMultipleResourceRefreshToken -EQ $true |
    Where DisplayableId -IEQ $azureStackAccount.Context.Account.Id |
    Sort ExpiresOn |
    Select -Last 1 -ExpandProperty RefreshToken |
    ConvertTo-SecureString -AsPlainText -Force
    # Workaround due to regression in AzurePowerShell profile module which fails to populate the response object of "Add-AzureRmAccount" cmdlet
    if (-not $refreshToken) {
        if ($tokens.Count -eq 1) {
            Write-Warning "Failed to find target refresh token from Azure PowerShell Cache; attempting to reuse the single cached auth context..."
            $refreshToken = $tokens[0].RefreshToken | ConvertTo-SecureString -AsPlainText -Force
        }
        else {
            throw "Unable to find refresh token from Azure PowerShell Cache. Please try the command again in a fresh PowerShell instance after running 'Clear-AzureRmContext -Scope CurrentUser -Force -Verbose'."
        }
    }

    return $refreshToken
}

<#
.Synopsis
    Resolve the graph enviornment name
#>
function Resolve-GraphEnvironment {
    [CmdletBinding()]
    param
    (
        # The azure environment
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment] $AzureEnvironment
    )

    $graphEnvironment = switch ($AzureEnvironment.ActiveDirectoryAuthority) {
        'https://login.microsoftonline.com/' { 'AzureCloud' }
        'https://login.chinacloudapi.cn/' { 'AzureChinaCloud' }
        'https://login-us.microsoftonline.com/' { 'AzureUSGovernment' }
        'https://login.microsoftonline.us/' { 'AzureUSGovernment' }
        'https://login.microsoftonline.de/' { 'AzureGermanCloud' }
        Default { throw "Unsupported graph resource identifier: $_" }
    }
    return $graphEnvironment
}

Export-ModuleMember -Function @(
    "Initialize-AzureRmEnvironment",
    "Initialize-AzureRmUserAccount",
    "Initialize-AzureRmUserRefreshToken",
    "Resolve-GraphEnvironment"
)
