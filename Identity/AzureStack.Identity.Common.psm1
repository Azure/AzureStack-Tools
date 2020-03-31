# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

Import-Module 'Az.Accounts' -Verbose:$false 4> $null

<#
   .Synopsis
      This function is used to initialize an Azure Resource Manager Environment for a given EnvironmentName and its ResourceManagerEndpoint 
   .DESCRIPTION
      Add an Azure Environment with a given EnvironmentName or retrieves an existing one 
   .EXAMPLE
      $azureEnvironment = Initialize-AzEnvironment -EnvironmentName "AzureStack" -ResourceManagerEndpoint "https://adminmanagement.redmond.ext-v.masd.stbtest.microsoft.com"
#>
function Initialize-AzEnvironment {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $EnvironmentName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $ResourceManagerEndpoint
    )

    $azureEnvironment = Add-AzEnvironment -Name $EnvironmentName -ARMEndpoint $ResourceManagerEndpoint -ErrorAction Ignore
    $azureEnvironment = Get-AzEnvironment -Name $environmentName -ErrorAction Stop
    return $azureEnvironment
}

<#
.Synopsis
    Initialize the Azure user account
#>
function Initialize-AzAccount {
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
        [string] $SubscriptionId = $null,

        # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [string] $SubscriptionName = $null,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
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
    Write-Verbose "Add azure account with parameters $(ConvertTo-JSON $params)" -Verbose
    $azureAccount = Add-AzAccount @params
    if ($SubscriptionName) {
        Select-AzSubscription -SubscriptionName $SubscriptionName | Out-Null
    }
    elseif ($SubscriptionId) {
        Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null
    }

    return $azureAccount
}

<#
.Synopsis
    Resolve the graph enviornment name
#>
function Resolve-GraphEnvironment {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$ActiveDirectoryAuthority
    )
    $graphEnvironment = switch ($ActiveDirectoryAuthority) {
        'https://login.microsoftonline.com/' { 'AzureCloud' }
        'https://login.chinacloudapi.cn/' { 'AzureChinaCloud' }
        'https://login-us.microsoftonline.com/' { 'AzureUSGovernment' }
        'https://login.microsoftonline.us/' { 'AzureUSGovernment' }
        'https://login.microsoftonline.de/' { 'AzureGermanCloud' }
        Default { 'CustomCloud' }
    }
    return $graphEnvironment
}

<#
.Synopsis
    Retrieves an access or refresh token to use when making direct REST calls.
#>
function Get-AzToken {
    [CmdletBinding(DefaultParameterSetName = 'default')]
    param
    (
        # The Azure PowerShell context representing the context of a token to be resolved.
        [Parameter()]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext] $Context = (Get-AzContext -ErrorAction Stop),

        # The target resource for which a token should be resolved.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Resource = ($Context.Environment.ActiveDirectoryServiceEndpointResourceId),

        # The target tenantId in which a token should be resolved.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $TenantId = ($t = if ($Context.Tenant) { $Context.Tenant } else { $Context.Subscription.TenantId }),

        # The account for which a token should be resolved.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $AccountId = ($Context.Account.Id),

        # Indicates that target token should be resolved from existing cache data (including a refresh token, if one is available).
        [Parameter(Mandatory = $true, ParameterSetName = 'FromCache')]
        [switch] $FromCache,

        # Indicates that all token cache data should be returned.
        [Parameter(ParameterSetName = 'FromCache')]
        [switch] $Raw
    )

    $originalErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Stop'

        Write-Verbose "Attempting to retrieve a token for account '$AccountId' in tenant '$TenantId' for resource '$Resource'..."

        if (-not $FromCache) {
            $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate(
                ($account = $Context.Account),
                ($environment = $Context.Environment),
                ($tenant = $TenantId),
                ($password = $null),
                ($promptBehavior = 'Never'),
                ($promptAction = $null),
                ($tokenCache = $null),
                ($resourceIdEndpoint = $Resource))

            return [pscustomobject]@{ AccessToken = ConvertTo-SecureString $token.AccessToken -AsPlainText -Force } |
            Add-Member -MemberType ScriptMethod -Name 'GetAccessToken' -Value { return [System.Net.NetworkCredential]::new('$tokenType', $this.AccessToken).Password } -PassThru
        }
        else {
            Write-Verbose "Attempting to find a refresh token and an access token from the existing token cache data..."
        }

        #
        # Resolve token cache data
        #

        [Microsoft.Azure.Commands.Common.Authentication.Authentication.Clients.AuthenticationClientFactory]$authenticationClientFactory = $null
        if (-not ([Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TryGetComponent(
                    [Microsoft.Azure.Commands.Common.Authentication.Authentication.Clients.AuthenticationClientFactory]::AuthenticationClientFactoryKey,
                    [ref]$authenticationClientFactory))) {
            $m = 'Please ensure you have authenticated with Az Accounts module!'
            $m += ' Unable to resolve authentication client factory from Az Accounts module runtime'
            $m += ' ([Microsoft.Azure.Commands.Common.Authentication.Authentication.Clients.AuthenticationClientFactory])'
            Write-Error $m
            return
        }

        $client = $authenticationClientFactory.CreatePublicClient(
            ($clientId = '1950a258-227b-4e31-a9cf-717495945fc2'),
            ($TenantId),
            ($authority = if ($Context.Environment.EnableAdfsAuthentication) { $Context.Environment.ActiveDirectoryAuthority } else { '{0}/{1}' -f $Context.Environment.ActiveDirectoryAuthority.TrimEnd('/'), $TenantId }),
            ($redirectUri = $null),
            ($useAdfs = $Context.Environment.EnableAdfsAuthentication))

        $authenticationClientFactory.RegisterCache($client)

        $accounts = $client.GetAccountsAsync().ConfigureAwait($true).GetAwaiter().GetResult()

        $bytes = ([Microsoft.Identity.Client.ITokenCacheSerializer]$client.UserTokenCache).SerializeMsalV3()
        $json = [System.Text.Encoding]::UTF8.GetString($bytes)
        $data = ConvertFrom-Json $json

        Write-Debug "MSAL token cache deserialized ($($bytes.Length) bytes); Looking for target tokens..."

        foreach ($name in 'AccessToken', 'Account', 'AppMetadata', 'IdToken', 'RefreshToken') {
            $data | Add-Member -NotePropertyName "${name}s" -NotePropertyValue ((Get-Member -MemberType NoteProperty -InputObject $data."$name").Name | ForEach { $data."$name"."$_" })
        }

        if ($Raw) {
            Write-Warning "Returning raw token cache data!"
            Write-Output $data
            return
        }

        #
        # Resolve target account
        #

        $targetAccount = $accounts | Where Username -EQ $AccountId

        if (-not $targetAccount -or $targetAccount.Count -gt 1) {
            Write-Error "Unable to resolve acccount for identity '$AccountId'; available accounts: $(ConvertTo-Json $accounts.Username -Compress)"
            return
        }

        Write-Verbose "Target account resolved to: $(ConvertTo-Json $targetAccount -Compress)"

        #
        # Resolve target token(s)
        #

        $resolvedRefreshToken = $data.RefreshToken."$(Get-Member -InputObject $data.RefreshToken -MemberType NoteProperty |
            Where { "$($_.Name)".StartsWith($targetAccount.HomeAccountId.Identifier, [System.StringComparison]::OrdinalIgnoreCase) } |
            Select -ExpandProperty Name)".secret

        $resolvedAccessToken = Get-Member -InputObject $data.AccessToken -MemberType NoteProperty |
        ForEach { $data.AccessToken."$($_.Name)" } | 
        Where home_account_id -EQ $targetAccount.HomeAccountId.Identifier |
        Where { (-not $_.realm) -or ($_.realm -eq $TenantId) } |
        Where target -Like "*$Resource*" |
        Sort expires_on -Descending |
        Select -First 1 -ExpandProperty secret

        if (-not $resolvedAccessToken -and -not $resolvedRefreshToken) {
            Write-Error "Unable to resolve an access token or refresh token for identity '$AccountId' with the specified properties..."
            return
        }
        elseif (-not $resolvedAccessToken) {
            Write-Warning "Unable to resolve an access token for identity '$AccountId' with the specified properties..."
        }
        elseif (-not $resolvedRefreshToken) {
            Write-Warning "Unable to resolve a refresh token for identity '$AccountId' with the specified properties..."
        }

        $result = [pscustomobject]@{
            AccessToken  = if ($resolvedAccessToken) { ConvertTo-SecureString $resolvedAccessToken  -AsPlainText -Force } else { $null }
            RefreshToken = if ($resolvedRefreshToken) { ConvertTo-SecureString $resolvedRefreshToken -AsPlainText -Force } else { $null }
        }
    
        return $result |
        Add-Member -MemberType ScriptMethod -Name 'GetAccessToken' -Value { return [System.Net.NetworkCredential]::new('$tokenType', $this.AccessToken).Password } -PassThru |
        Add-Member -MemberType ScriptMethod -Name 'GetRefreshToken' -Value { return [System.Net.NetworkCredential]::new('$tokenType', $this.RefreshToken).Password } -PassThru
    }
    finally {
        $ErrorActionPreference = $originalErrorActionPreference
    }
}

Export-ModuleMember -Function @(
    "Initialize-AzEnvironment",
    "Initialize-AzAccount",
    "Resolve-GraphEnvironment",
    "Get-AzToken"
)
