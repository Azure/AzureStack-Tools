<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

$ErrorActionPreference = "Stop"

<#
.Synopsis
   Clear the portal user data under AAD environment
#>
function Clear-AzsUserDataUnderAAD
{
    param
    (
        # The user credential with which to acquire an access token targeting Graph.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [pscredential] $AadGraphCred = $null,

         # The name of the supported Cloud Environment in which the target Graph Service is available.
        [Parameter(Mandatory=$false)]
        [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment', 'AzureGermanCloud')]
        [string] $Environment = 'AzureCloud',

        # The Azure Stack administrator credential.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [pscredential] $AzsAdminCred = $null,

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

        # The directory tenant identifier of account who's user data should be cleared.
        # If it is not specified, it will delete all the 
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId
    )
    #requires -Version 4.0
    #requires -Module "AzureRM.Profile"
    #requires -Module "Azs.Subscriptions.Admin"
    #requires -RunAsAdministrator

    Import-Module $PSScriptRoot\..\..\Identity\GraphAPI\GraphAPI.psm1 -Force

    Write-Verbose "Login to Azure Stack Admin ARM..." -Verbose
    $AzsAdminEnvironmentName = "AzureStackAdmin"
    $adminArmEnv = Add-AzureRmEnvironment -Name ($AzsAdminEnvironmentName) -ARMEndpoint $AzsAdminArmEndpoint
    Write-Verbose "Created admin ARM env as $(ConvertTo-JSON $adminArmEnv)" -Verbose
    $loginInfo = Add-AzureRmAccount -EnvironmentName $AzsAdminEnvironmentName -Credential $AzsAdminCred -TenantId $AzsAdminDirectoryTenantId
    Write-Verbose "Login into admin ARM with $(ConvertTo-JSON $loginInfo)" -Verbose

    $adminSubscriptionId = (Get-AzureRmSubscription -Verbose | where { $_.Name -ieq "Default Provider Subscription" }).Id
    if (-not $adminSubscriptionId)
    {
        throw "There is no Default Provider Subscription under the user account. Please use the Azure Stack admin account to clear user data"
    }

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
    foreach ($dirId in $directoryTenantIdsArray)
    {
        Write-Verbose "Intializing graph env..." -Verbose
        $graphEnvInfo = Initialize-GraphEnvironment -DirectoryTenantId $dirId -UserCredential $AadGraphCred -Environment $Environment
        Write-Verbose "Intialized graph env with $(ConvertTo-JSON $graphEnvInfo)" -Verbose

        Write-Verbose "Querying all users..." -Verbose
        $usersResponse = Invoke-GraphApi -ApiPath "/users"

        $userObjectId = ($usersResponse.value | where { ($_.userPrincipalName -ieq $UserPrincipalName) -or ($_.userPrincipalName.ToLower().Contains($UserPrincipalName.Replace("@", "_").ToLower() + "#")) }).objectId
        Write-Verbose "Retrieved user object Id as $userObjectId" -Verbose
        if (-not $userObjectId)
        {
            Write-Warning "There is no user '$UserPrincipalName' under directory tenant Id $dirId."
            $curResult = New-Object PSObject
            $curResult | add-member Noteproperty DirectoryTenantId       $dirId
            $curResult | add-member Noteproperty UserName                $UserPrincipalName
            $curResult | add-member Noteproperty ErrorMessage            "No user under tenant directory"
            $clearUserDataResult += @( $curResult )
            continue
        }
        elseif (([string[]]$userObjectId).Length -gt 1)
        {
            Write-Warning "There is one more users retrieved with '$UserPrincipalName' under directory tenant Id $dirId."
            $curResult = New-Object PSObject
            $curResult | add-member Noteproperty DirectoryTenantId       $dirId
            $curResult | add-member Noteproperty UserName                $UserPrincipalName
            $curResult | add-member Noteproperty ErrorMessage            "User principal name incorrect. One more user accounts under tenant directory"
            $clearUserDataResult += @( $curResult )
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
            $curResult = Clear-AzsUserData @params
            $clearUserDataResult += @( $curResult )
        }
    }

    return $clearUserDataResult
}

<#
.Synopsis
   Clear the portal user data under ADFS environment
#>
function Clear-AzsUserDataUnderADFS
{
    param
    (
        # The user credential with which to acquire an access token targeting Graph.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [pscredential] $AdfsGraphCred = $null,

        # The Azure Stack administrator credential.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [pscredential] $AzsAdminCred = $null,

        # The directory tenant identifier.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId,

        # The Azure Stack ARM endpoint URI.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Uri] $AzsAdminArmEndpoint,

        # The user principal name of the account who's user data should be cleared.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserPrincipalName
    )
    #requires -Version 4.0
    #requires -Module "AzureRM.Profile"
    #requires -RunAsAdministrator

    Import-Module $PSScriptRoot\..\..\Identity\GraphAPI\GraphAPI.psm1 -Force

    Write-Verbose "Login to Azure Stack Admin ARM..." -Verbose
    $AzsAdminEnvironmentName = "AzureStackAdmin"
    $adminArmEnv = Add-AzureRmEnvironment -Name ($AzsAdminEnvironmentName) -ARMEndpoint $AzsAdminArmEndpoint
    Write-Verbose "Created admin ARM env as $(ConvertTo-JSON $adminArmEnv)" -Verbose
    $loginInfo = Add-AzureRmAccount -EnvironmentName $AzsAdminEnvironmentName -Credential $AzsAdminCred -TenantId $DirectoryTenantId
    Write-Verbose "Login into admin ARM with $(ConvertTo-JSON $loginInfo)" -Verbose
    $endpoints = Invoke-RestMethod "$AzsAdminArmEndpoint/metadata/endpoints?api-version=2018-01-01"

    $adminSubscriptionId = (Get-AzureRmSubscription -Verbose | where { $_.Name -ieq "Default Provider Subscription" }).Id
    if (-not $adminSubscriptionId)
    {
        throw "There is no Default Provider Subscription under the user account. Please use the Azure Stack admin account to clear user data"
    }

    Write-Host "Clearing the user data with input user principal name $UserPrincipalName and directory tenants '$DirectoryTenantId'..."

    $params = @{
        DirectoryTenantId   = $DirectoryTenantId
        UserCredential      = $AdfsGraphCred
        AdfsFqdn            = (New-Object Uri $endpoints.authentication.loginEndpoint).Host
        GraphFqdn           = (New-Object Uri $endpoints.graphEndpoint).Host
    }
    Write-Verbose "Intializing graph env with parameters $(ConvertTo-JSON $params)..." -Verbose
    $graphEnvInfo = Initialize-GraphEnvironment @params
    Write-Verbose "Intialized graph env with $(ConvertTo-JSON $graphEnvInfo)" -Verbose

    Write-Verbose "Retrieving the user information with user name $UserPrincipalName..." -Verbose
    $userObjectId = (Invoke-GraphApi -ApiPath "/users" -QueryParameters @{ '$filter' = "userPrincipalName eq '$userPrincipalName'" }).value.objectId

    Write-Verbose "Retrieved user object Id as $userObjectId" -Verbose
    if (-not $userObjectId)
    {
        Write-Warning "There is no user '$UserPrincipalName' under directory tenant Id $DirectoryTenantId."
        $curResult = New-Object PSObject
        $curResult | add-member Noteproperty DirectoryTenantId       $DirectoryTenantId
        $curResult | add-member Noteproperty UserName                $UserPrincipalName
        $curResult | add-member Noteproperty ErrorMessage            "No user under tenant directory"
        return curResult
    }
    elseif (([string[]]$userObjectId).Length -gt 1)
    {
        Write-Warning "There is one more users retrieved with '$UserPrincipalName' under directory tenant Id $DirectoryTenantId."
        $curResult = New-Object PSObject
        $curResult | add-member Noteproperty DirectoryTenantId       $DirectoryTenantId
        $curResult | add-member Noteproperty UserName                $UserPrincipalName
        $curResult | add-member Noteproperty ErrorMessage            "User principal name incorrect. One more user accounts under tenant directory"
        return curResult
    }
    else
    {
        $params = @{
            AzsEnvironment      = $adminArmEnv
            UserObjectId        = $userObjectId
            DirectoryTenantId   = $DirectoryTenantId
            AdminSubscriptionId = $adminSubscriptionId
            AzsAdminArmEndpoint = $AzsAdminArmEndpoint
        }
        return Clear-AzsUserData @params
    }
}

function Clear-AzsUserData
{
    param
    (
        # The user credential with which to acquire an access token targeting Graph.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment] $AzsEnvironment = $null,

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
        $clearUserDataResponse = $httpPayload | Invoke-RestMethod -Headers $headers -Method POST -Uri $clearUserDataEndpoint -Verbose

        $curResult = New-Object PSObject
        $curResult | add-member Noteproperty DirectoryTenantId       $DirectoryTenantId
        $curResult | add-member Noteproperty UserName                $UserPrincipalName
        $curResult | add-member Noteproperty ResponseData            $clearUserDataResponse
        return $curResult
    }
    catch 
    {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound -and (ConvertFrom-JSON $_.ErrorDetails.Message).error.code -eq "NoPortalUserData")
        {
            $curResult = New-Object PSObject
            $curResult | add-member Noteproperty DirectoryTenantId       $DirectoryTenantId
            $curResult | add-member Noteproperty UserName                $UserPrincipalName
            $curResult | add-member Noteproperty ErrorMessage            "There is no portal user data"
            Write-Warning "No user data with user object Id and directory tenant Id"
            return $curResult
        }
        else
        {
            $curResult = New-Object PSObject
            $curResult | add-member Noteproperty DirectoryTenantId       $DirectoryTenantId
            $curResult | add-member Noteproperty UserName                $UserPrincipalName
            $curResult | add-member Noteproperty ErrorMessage            "Error when clearing user data"
            $curResult | add-member Noteproperty Exception               $_.Exception
            Write-Warning "Exception when clear user data with user object Id and directory tenant Id: $_`r`n$($_.Exception)"
            return $curResult
        }
    }
}

Export-ModuleMember -Function Clear-AzsUserDataUnderAAD
Export-ModuleMember -Function Clear-AzsUserDataUnderADFS