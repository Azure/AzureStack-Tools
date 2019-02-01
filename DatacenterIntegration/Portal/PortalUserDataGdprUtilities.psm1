﻿<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

$DefaultAdminSubscriptionName = "Default Provider Subscription"

<#
.Synopsis
   Clear the portal user data
#>
function Clear-AzsUserData
{
    param
    (
        # The directory tenant identifier of Azure Stack Administrator.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $AzsAdminDirectoryTenantId,

        # The Azure Stack ARM endpoint URI.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Uri] $AzsAdminArmEndpoint,

        # The user principal name of the account who's user data should be cleared.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserPrincipalName,

        # Optional: The directory tenant identifier of account who's user data should be cleared.
        # If it is not specified, it will delete all the 
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId,

        # Indicate whether it is ADFS env or not
        [switch] $ADFS,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )
    #requires -Version 4.0
    #requires -Module "AzureRM.Profile"
    #requires -Module "Azs.Subscriptions.Admin"
    #requires -RunAsAdministrator

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    Import-Module $PSScriptRoot\..\..\Identity\GraphAPI\GraphAPI.psm1 -Force
    Import-Module $PSScriptRoot\..\..\Identity\AzureStack.Identity.Common.psm1 -Force

    Write-Verbose "Login to Azure Stack Admin ARM..." -Verbose
    $AzsAdminEnvironmentName = "AzureStackAdmin"
    $adminArmEnv = Initialize-AzureRmEnvironment -AdminResourceManagerEndpoint $AzsAdminArmEndpoint -DirectoryTenantId $AzsAdminDirectoryTenantId -EnvironmentName $AzsAdminEnvironmentName
    Write-Verbose "Created admin ARM env as $(ConvertTo-JSON $adminArmEnv)" -Verbose

    $params = @{
        AzureEnvironment = $adminArmEnv
        SubscriptionName = $DefaultAdminSubscriptionName
    }
    if ($AutomationCredential)
    {
        $params.AutomationCredential = $AutomationCredential
    }
    $refreshToken = Initialize-AzureRmUserRefreshToken @params
    Write-Verbose "Login into admin ARM and got the refresh token." -Verbose

    $adminSubscriptionId = (Get-AzureRmSubscription -Verbose | where { $_.Name -ieq $DefaultAdminSubscriptionName }).Id
    Write-Verbose "Get default Admin subscription id $adminSubscriptionId." -Verbose

    if ($DirectoryTenantId)
    {
        $directoryTenantIdsArray = [string[]]$DirectoryTenantId
    }
    else 
    {
        Write-Verbose "Input parameter 'DirectoryTenantId' is empty. Retrieving all the registered tenant directory..." -Verbose
        $directoryTenantIdsArray = (Get-AzsDirectoryTenant -Verbose).TenantId
    }

    Write-Host "Clearing the user data with input user principal name $UserPrincipalName and directory tenants '$DirectoryTenantIdsArray'..."

    $clearUserDataResults = @() # key is directory Id, value is clear response

    $initializeGraphEnvParams = @{
        RefreshToken = $refreshToken
    }
    if ($ADFS)
    {
        $initializeGraphEnvParams.AdfsFqdn = (New-Object Uri $adminArmEnv.ActiveDirectoryAuthority).Host
        $initializeGraphEnvParams.GraphFqdn = (New-Object Uri $adminArmEnv.GraphUrl).Host

        $QueryParameters = @{
            '$filter' = "userPrincipalName eq '$($UserPrincipalName.ToLower())'"
        }
    }
    else
    {
        $graphEnvironment = Resolve-GraphEnvironment -AzureEnvironment $adminArmEnv
        Write-Verbose "Resolve the graph env as '$graphEnvironment '" -Verbose
        $initializeGraphEnvParams.Environment = $graphEnvironment

        $QueryParameters = @{
            '$filter' = "userPrincipalName eq '$($UserPrincipalName.ToLower())' or startswith(userPrincipalName, '$($UserPrincipalName.Replace("@", "_").ToLower())')"
        }
    }

    foreach ($dirId in $directoryTenantIdsArray)
    {
        Write-Verbose "Intializing graph env..." -Verbose
        Initialize-GraphEnvironment @initializeGraphEnvParams -DirectoryTenantId $dirId
        Write-Verbose "Intialized graph env" -Verbose

        Write-Verbose "Querying all users..." -Verbose
        $usersResponse = Invoke-GraphApi -ApiPath "/users" -QueryParameters $QueryParameters
        Write-Verbose "Retrieved user object as $(ConvertTo-JSON $usersResponse.value)" -Verbose

        $userObjectId = $usersResponse.value.objectId
        Write-Verbose "Retrieved user object Id as $userObjectId" -Verbose
        if (-not $userObjectId)
        {
            Write-Warning "There is no user '$UserPrincipalName' under directory tenant Id $dirId."
            $clearUserDataResult += [pscustomobject]@{
                DirectoryTenantId = $dirId
                UserPrincipalName = $UserPrincipalName
                ErrorMessage      = "User not found in directory."
            }
            continue
        }
        elseif (([string[]]$userObjectId).Length -gt 1)
        {
            Write-Warning "There is one more users retrieved with '$UserPrincipalName' under directory tenant Id $dirId."
            $clearUserDataResult += [pscustomobject]@{
                DirectoryTenantId = $dirId
                UserPrincipalName = $UserPrincipalName
                ErrorMessage      = "One more user accounts found in directory. User principal name may be incorrect. "
            }
            continue
        }
        else
        {
            $params = @{
                AzsEnvironment      = $adminArmEnv
                UserObjectId        = $userObjectId
                DirectoryTenantId   = $dirId
                AdminSubscriptionId = $adminSubscriptionId
                AzsAdminArmEndpoint = $AzsAdminArmEndpoint
            }
            $curResult = Clear-SinglePortalUserData @params
            $clearUserDataResult += @( $curResult )
        }
    }

    return $clearUserDataResult
}

function Clear-SinglePortalUserData
{
    param
    (
        # The user credential with which to acquire an access token targeting Graph.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment] $AzsEnvironment,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $UserObjectId,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $DirectoryTenantId,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $AdminSubscriptionId,

        # The Azure Stack ARM endpoint URI.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Uri] $AzsAdminArmEndpoint
    )

    try
    {
        Write-Verbose "Retrieving access token..." -Verbose
        $accessToken = (Get-GraphToken -Resource $AzsEnvironment.ActiveDirectoryServiceEndpointResourceId -UseEnvironmentData).access_token
        
        $clearUserDataEndpoint = "$AzsAdminArmEndpoint/subscriptions/$AdminSubscriptionId/providers/Microsoft.PortalExtensionHost.Providers/ClearUserSettings?api-version=2017-09-01-preview"
        $headers = @{ 
            Authorization   = "Bearer $accessToken" 
            "Content-Type"  = "application/json"
        }
        $payload = @{
            UserObjectId = $UserObjectId
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
    catch 
    {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound -and (ConvertFrom-JSON $_.ErrorDetails.Message).error.code -eq "NoPortalUserData")
        {
            Write-Warning "No user data with user object Id and directory tenant Id"
            return [pscustomobject]@{
                DirectoryTenantId = $DirectoryTenantId
                UserPrincipalName = $UserPrincipalName
                ErrorMessage      = "No portal user data"
            }
        }
        else
        {
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

Export-ModuleMember -Function Clear-AzsUserData