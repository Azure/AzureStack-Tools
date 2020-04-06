<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

$DefaultAdminSubscriptionName = "Default Provider Subscription"

function Initialize-UserDataClearEnv {
    param
    (
        # The directory tenant identifier of Azure Stack.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AzsDirectoryTenantId,

        # The Azure Stack ARM endpoint URI.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri] $AzsArmEndpoint,

        # The subscription name
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionName,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [pscredential] $AutomationCredential = $null,

        [ValidateNotNullOrEmpty()]
        [string] $UserPrincipalName
    )

    #requires -Module "Az.Accounts"
    #requires -RunAsAdministrator

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    Import-Module $PSScriptRoot\..\..\Identity\GraphAPI\GraphAPI.psm1 -Force
    Import-Module $PSScriptRoot\..\..\Identity\AzureStack.Identity.Common.psm1 -Force

    Write-Verbose "Login to Azure Stack ARM..." -Verbose
    $AzsAdminEnvironmentName = New-Guid
    $params = @{
        ResourceManagerEndpoint = $AzsArmEndpoint
        EnvironmentName         = $AzsAdminEnvironmentName
    }
    $adminArmEnv = Initialize-AzEnvironment @params
    Write-Verbose "Created admin ARM env as $(ConvertTo-JSON $adminArmEnv)" -Verbose

    $params = @{
        AzureEnvironment  = $adminArmEnv
        DirectoryTenantId = $AzsDirectoryTenantId
    }
    if ($SubscriptionName) {
        $params.SubscriptionName = $SubscriptionName
    }
    if ($AutomationCredential) {
        $params.AutomationCredential = $AutomationCredential
    }
    $azAccount = Initialize-AzAccount @param
    $azContext = Get-AzContext
    $refreshToken = (Get-AzToken -Context $azContext -FromCache -Verbose).GetRefreshToken()
    Write-Verbose "Login into ARM and got the refresh token." -Verbose

    $script:initializeGraphEnvParams = @{
        RefreshToken = $refreshToken
    }
    if ($adminArmEnv.EnableAdfsAuthentication) {
        $script:initializeGraphEnvParams.AdfsFqdn = (New-Object Uri $adminArmEnv.ActiveDirectoryAuthority).Host
        $script:initializeGraphEnvParams.GraphFqdn = (New-Object Uri $adminArmEnv.GraphUrl).Host

        $script:queryParameters = @{
            '$filter' = "userPrincipalName eq '$($UserPrincipalName.ToLower())'"
        }
    }
    else {
        $graphEnvironment = Resolve-GraphEnvironment -AzureEnvironment $adminArmEnv
        Write-Verbose "Resolve the graph env as '$graphEnvironment '" -Verbose
        $script:initializeGraphEnvParams.Environment = $graphEnvironment

        $script:queryParameters = @{
            '$filter' = "userPrincipalName eq '$($UserPrincipalName.ToLower())' or startswith(userPrincipalName, '$($UserPrincipalName.Replace("@", "_").ToLower() + "#")')"
        }
    }

    Initialize-GraphEnvironment @script:initializeGraphEnvParams -DirectoryTenantId $AzsDirectoryTenantId
    $script:adminArmAccessToken = (Get-GraphToken -Resource $adminArmEnv.ActiveDirectoryServiceEndpointResourceId -UseEnvironmentData).access_token
}

<#
.Synopsis
   Clear the portal user data
#>
function Clear-AzsUserDataWithUserPrincipalName {
    param
    (
        # The directory tenant identifier of Azure Stack Administrator.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AzsAdminDirectoryTenantId,

        # The Azure Stack ARM endpoint URI.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri] $AzsAdminArmEndpoint,

        # The user principal name of the account whoes user data should be cleared.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserPrincipalName,

        # Optional: The directory tenant identifier of account whoes user data should be cleared.
        # If it is not specified, it will delete user with principal name under all regitered directory tenants
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    Write-Warning "Please use PortalUserDataUtilities.psm1. This module is deprecated and will be deleted soon."

    $params = @{
        AzsAdminDirectoryTenantId = $AzsAdminDirectoryTenantId
        AzsAdminArmEndpoint       = $AzsAdminArmEndpoint
        UserPrincipalName         = $UserPrincipalName
    }

    if ($DirectoryTenantId) {
        $params.DirectoryTenantId = $DirectoryTenantId
    }

    if ($AutomationCredential) {
        $params.AutomationCredential = $AutomationCredential
    }

    Clear-AzsUserData @params
}

<#
.Synopsis
    Deprecated: Clear the portal user data
#>
function Clear-AzsUserData {
    param
    (
        # The directory tenant identifier of Azure Stack Administrator.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AzsAdminDirectoryTenantId,

        # The Azure Stack ARM endpoint URI.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri] $AzsAdminArmEndpoint,

        # The user principal name of the account whoes user data should be cleared.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserPrincipalName,

        # Optional: The directory tenant identifier of account whoes user data should be cleared.
        # If it is not specified, it will delete user with principal name under all regitered directory tenants
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    $params = @{
        AzsDirectoryTenantId = $AzsAdminDirectoryTenantId
        AzsArmEndpoint       = $AzsAdminArmEndpoint
        AutomationCredential = $AutomationCredential
        UserPrincipalName    = $UserPrincipalName
        SubscriptionName     = $DefaultAdminSubscriptionName
    }
    Initialize-UserDataClearEnv @params

    if ($DirectoryTenantId) {
        $directoryTenantIdsArray = [string[]]$DirectoryTenantId
    }
    else {
        Write-Verbose "Input parameter 'DirectoryTenantId' is empty. Retrieving all the registered tenant directory..." -Verbose
        $directoryTenantIdsArray = (Get-AzsDirectoryTenant -Verbose).TenantId
    }

    Write-Host "Clearing the user data with input user principal name $UserPrincipalName and directory tenants '$DirectoryTenantIdsArray'..."

    $clearUserDataResults = @() # key is directory Id, value is clear response

    foreach ($dirId in $directoryTenantIdsArray) {
        Write-Verbose "Intializing graph env..." -Verbose
        Initialize-GraphEnvironment @script:initializeGraphEnvParams -DirectoryTenantId $dirId
        Write-Verbose "Intialized graph env" -Verbose

        Write-Verbose "Querying all users..." -Verbose
        $usersResponse = Invoke-GraphApi -ApiPath "/users" -QueryParameters $script:queryParameters
        Write-Verbose "Retrieved user object as $(ConvertTo-JSON $usersResponse.value)" -Verbose

        $userObjectId = $usersResponse.value.objectId
        Write-Verbose "Retrieved user object Id as $userObjectId" -Verbose
        if (-not $userObjectId) {
            Write-Warning "There is no user '$UserPrincipalName' under directory tenant Id $dirId."
            $clearUserDataResult += [pscustomobject]@{
                DirectoryTenantId = $dirId
                UserPrincipalName = $UserPrincipalName
                ErrorMessage      = "User not found in directory."
            }
            continue
        }
        elseif (([string[]]$userObjectId).Length -gt 1) {
            Write-Warning "There is one more users retrieved with '$UserPrincipalName' under directory tenant Id $dirId."
            $clearUserDataResult += [pscustomobject]@{
                DirectoryTenantId = $dirId
                UserPrincipalName = $UserPrincipalName
                ErrorMessage      = "One more user accounts found in directory. User principal name may be incorrect. "
            }
            continue
        }
        else {
            $params = @{
                AccessToken         = $script:adminArmAccessToken
                UserObjectId        = $userObjectId
                DirectoryTenantId   = $dirId
                AzsAdminArmEndpoint = $AzsAdminArmEndpoint
            }
            $curResult = Clear-SinglePortalUserData @params
            $clearUserDataResult += @( $curResult )
        }
    }

    return $clearUserDataResult
}

<#
.Synopsis
   Clear the portal user data
#>
function Clear-AzsUserDataWithUserObjectId {
    param
    (
        # The directory tenant identifier of Azure Stack Administrator.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AzsAdminDirectoryTenantId,

        # The Azure Stack ARM endpoint URI.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri] $AzsAdminArmEndpoint,

        # The user object Id of the account whoes user data should be cleared.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserObjectId,

        # The directory tenant identifier of account whoes user data should be cleared.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    Write-Warning "Please use PortalUserDataUtilities.psm1. This module is deprecated and will be deleted soon."

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    $params = @{
        AzsDirectoryTenantId = $AzsAdminDirectoryTenantId
        AzsArmEndpoint       = $AzsAdminArmEndpoint
        AutomationCredential = $AutomationCredential
        SubscriptionName     = $DefaultAdminSubscriptionName
    }
    Initialize-UserDataClearEnv @params

    $params = @{
        AccessToken         = $script:adminArmAccessToken
        UserObjectId        = $UserObjectId
        DirectoryTenantId   = $DirectoryTenantId
        AzsAdminArmEndpoint = $AzsAdminArmEndpoint
    }
    Clear-SinglePortalUserData @params
}

function Get-UserObjectId {
    param
    (
        # The directory tenant identifier of user account
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId,

        # The Azure Stack ARM endpoint URI.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri] $AzsArmEndpoint,

        # The user principal name of the account whoes user data should be cleared.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserPrincipalName,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    Write-Warning "Please use PortalUserDataUtilities.psm1. This module is deprecated and will be deleted soon."

    $params = @{
        AzsDirectoryTenantId = $DirectoryTenantId
        AzsArmEndpoint       = $AzsArmEndpoint
        AutomationCredential = $AutomationCredential
        UserPrincipalName    = $UserPrincipalName
    }
    Initialize-UserDataClearEnv @params

    Write-Verbose "Intializing graph env..." -Verbose
    Initialize-GraphEnvironment @script:initializeGraphEnvParams -DirectoryTenantId $DirectoryTenantId
    Write-Verbose "Intialized graph env" -Verbose

    Write-Verbose "Querying all users..." -Verbose
    $usersResponse = Invoke-GraphApi -ApiPath "/users" -QueryParameters $script:queryParameters
    Write-Verbose "Retrieved user object as $(ConvertTo-JSON $usersResponse.value)" -Verbose

    return $usersResponse.value.objectId
}

function Clear-SinglePortalUserData {
    param
    (
        # The user credential with which to acquire an access token targeting Graph.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string] $AccessToken,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string] $UserObjectId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string] $DirectoryTenantId,

        # The Azure Stack ARM endpoint URI.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Uri] $AzsAdminArmEndpoint
    )

    try {
        $adminSubscriptionId = (Get-AzSubscription -Verbose | where { $_.Name -ieq $DefaultAdminSubscriptionName }).Id
        Write-Verbose "Get default Admin subscription id $adminSubscriptionId." -Verbose

        $clearUserDataEndpoint = "$AzsAdminArmEndpoint/subscriptions/$adminSubscriptionId/providers/Microsoft.PortalExtensionHost.Providers/ClearUserSettings?api-version=2017-09-01-preview"
        $headers = @{ 
            Authorization  = "Bearer $accessToken" 
            "Content-Type" = "application/json"
        }
        $payload = @{
            UserObjectId      = $UserObjectId
            DirectoryTenantId = $DirectoryTenantId
        }
        $httpPayload = ConvertTo-Json $payload -Depth 10
        Write-Verbose "Clearing user data with URI '$clearUserDataEndpoint' and payload: `r`n$httpPayload..." -Verbose
        $clearUserDataResponse = $httpPayload | Invoke-RestMethod -Headers $headers -Method POST -Uri $clearUserDataEndpoint -TimeoutSec 120 -Verbose

        return [pscustomobject]@{
            DirectoryTenantId = $DirectoryTenantId
            UserPrincipalName = $UserPrincipalName
            ResponseData      = $clearUserDataResponse
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound -and (ConvertFrom-JSON $_.ErrorDetails.Message).error.code -eq "NoPortalUserData") {
            Write-Warning "No user data with user object Id and directory tenant Id"
            return [pscustomobject]@{
                DirectoryTenantId = $DirectoryTenantId
                UserPrincipalName = $UserPrincipalName
                ErrorMessage      = "No portal user data"
            }
        }
        else {
            Write-Warning "Exception when clear user data with user object Id and directory tenant Id: $_`r`n$($_.Exception)"
            return [pscustomobject]@{
                DirectoryTenantId = $DirectoryTenantId
                UserPrincipalName = $UserPrincipalName
                ErrorMessage      = "Exception when clearing user data"
                Exception         = $_.Exception
            }
        }
    }
}

Export-ModuleMember -Function Get-UserObjectId
Export-ModuleMember -Function Clear-AzsUserData
Export-ModuleMember -Function Clear-AzsUserDataWithUserPrincipalName
Export-ModuleMember -Function Clear-AzsUserDataWithUserObjectId