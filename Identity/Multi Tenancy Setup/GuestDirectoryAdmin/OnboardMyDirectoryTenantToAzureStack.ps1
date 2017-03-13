<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

<#
.SYNOPSIS
    Completes the directory tenant onboarding process for an Azure Stack deployment. Will prompt for user credentials.
#>
[CmdletBinding()]
param
(
    # The endpoint of the Azure Stack Resource Manager service.
    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [ValidateScript({$_.Scheme -eq [System.Uri]::UriSchemeHttps})]
    [uri] $TenantResourceManagerEndpoint,

    # The name of the directory tenant being onboarded.
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $DirectoryTenantName
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Install-Module AzureRm -RequiredVersion '1.2.8'
Import-Module 'AzureRm.Profile' -RequiredVersion '1.0.4.2' -Force -Verbose:$false 4> $null
Import-Module "$PSScriptRoot\GraphAPI\GraphAPI.psm1"       -Force -Verbose:$false 4> $null

function Invoke-Main
{
    # Initialize the Azure PowerShell module to communicate with the Azure Resource Manager corresponding to their home Graph Service. Will prompt user for credentials.
    $azureStackEnvironment = Initialize-AzureRmEnvironment 'AzureStack'
    $azureEnvironment      = Resolve-AzureEnvironment $azureStackEnvironment
    $refreshToken          = Initialize-AzureRmUserAccount $azureEnvironment $azureStackEnvironment.AdTenant

    # Initialize the Graph PowerShell module to communicate with the correct graph service
    $graphEnvironment = Resolve-GraphEnvironment $azureEnvironment
    Initialize-GraphEnvironment -Environment $graphEnvironment -DirectoryTenantId $DirectoryTenantName -RefreshToken $refreshToken

    # Authorize the Azure Powershell module to act as a client to call the Azure Stack Resource Manager in the onboarded tenant
    Initialize-GraphOAuth2PermissionGrant -ClientApplicationId (Get-GraphEnvironmentInfo).Applications.PowerShell.Id -ResourceApplicationIdentifierUri $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId

    # Call Azure Stack Resource Manager to retrieve the list of registered applications which need to be initialized in the onboarding directory tenant
    $armAccessToken   = (Get-GraphToken -Resource $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId -UseEnvironmentData).access_token
    $applicationRegistrationParams = @{
        Method  = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        Headers = @{ Authorization = "Bearer $armAccessToken" }
        Uri     = "$($TenantResourceManagerEndpoint.ToString().TrimEnd('/'))/applicationRegistrations?api-version=2014-04-01-preview"
    }
    $applicationRegistrations = Invoke-RestMethod @applicationRegistrationParams | Select -ExpandProperty value

    # Initialize each registered application in the onboarding directory tenant
    foreach ($applicationRegistration in $applicationRegistrations)
    {
        # Initialize the service principal for the registered application, updating any tags as necessary
        $applicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $applicationRegistration.appId
        if ($applicationRegistration.tags)
        {
            Update-GraphApplicationServicePrincipalTags -ApplicationId $applicationRegistration.appId -Tags $applicationRegistration.tags
        }

        # Initialize the necessary oauth2PermissionGrants for the registered application
        foreach($oauth2PermissionGrant in $applicationRegistration.oauth2PermissionGrants)
        {
            $oauth2PermissionGrantParams = @{
                ClientApplicationId   = $oauth2PermissionGrant.client
                ResourceApplicationId = $oauth2PermissionGrant.resource
                Scope                 = $oauth2PermissionGrant.scope
            }
            Initialize-GraphOAuth2PermissionGrant @oauth2PermissionGrantParams
        }

        # Initialize the necessary directory role membership(s) for the registered application
        foreach($directoryRole in $applicationRegistration.directoryRoles)
        {
            Initialize-GraphDirectoryRoleMembership -ApplicationId $applicationRegistration.appId -RoleDisplayName $directoryRole
        }
    }
}

function Initialize-AzureRmEnvironment([string]$environmentName)
{
    $endpoints = Invoke-RestMethod -Method Get -Uri "$($TenantResourceManagerEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -Verbose
    Write-Verbose -Message "Endpoints: $(ConvertTo-Json $endpoints)" -Verbose

    # resolve the directory tenant ID from the name
    $directoryTenantId = (New-Object uri(Invoke-RestMethod "$($endpoints.authentication.loginEndpoint.TrimEnd('/'))/$DirectoryTenantName/.well-known/openid-configuration").token_endpoint).AbsolutePath.Split('/')[1]

    $azureEnvironmentParams = @{
        Name                                     = $environmentName
        ActiveDirectoryEndpoint                  = $endpoints.authentication.loginEndpoint.TrimEnd('/') + "/"
        ActiveDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
        AdTenant                                 = $directoryTenantId
        ResourceManagerEndpoint                  = $TenantResourceManagerEndpoint
        GalleryEndpoint                          = $endpoints.galleryEndpoint
        GraphEndpoint                            = $endpoints.graphEndpoint
        GraphAudience                            = $endpoints.graphEndpoint
    }

    Remove-AzureRmEnvironment -Name $environmentName -Force -ErrorAction Ignore | Out-Null
    $azureEnvironment = Add-AzureRmEnvironment @azureEnvironmentParams
    $azureEnvironment = Get-AzureRmEnvironment -Name $environmentName
    
    return $azureEnvironment
}

function Resolve-AzureEnvironment([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureStackEnvironment)
{
    $azureEnvironment = Get-AzureRmEnvironment |
        Where GraphEndpointResourceId -EQ $azureStackEnvironment.GraphEndpointResourceId |
        Where Name -In @('AzureCloud','AzureChinaCloud','AzureUSGovernment','AzureGermanCloud')

    # Differentiate between AzureCloud and AzureUSGovernment
    if ($azureEnvironment.Count -ge 2)
    {
        $name = if ($azureStackEnvironment.ActiveDirectoryAuthority -eq 'https://login-us.microsoftonline.com/') { 'AzureUSGovernment' } else { 'AzureCloud' }
        $azureEnvironment = $azureEnvironment | Where Name -EQ $name
    }

    return $azureEnvironment
}

function Initialize-AzureRmUserAccount([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureEnvironment, [string]$directoryTenantId)
{
    # Prompts the user for interactive login flow
    $azureAccount = Add-AzureRmAccount -EnvironmentName $azureEnvironment.Name -TenantId $directoryTenantId

    # Retrieve the refresh token
    $tokens = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()
    $refreshToken = $tokens |
        Where Resource -EQ $azureEnvironment.ActiveDirectoryServiceEndpointResourceId |
        Where IsMultipleResourceRefreshToken -EQ $true |
        Where DisplayableId -EQ $azureAccount.Context.Account.Id |
        Select -ExpandProperty RefreshToken |
        ConvertTo-SecureString -AsPlainText -Force

    return $refreshToken
}

function Resolve-GraphEnvironment([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureEnvironment)
{
    $graphEnvironment = switch($azureEnvironment.ActiveDirectoryAuthority)
    {
        'https://login.microsoftonline.com/'    { 'AzureCloud'        }
        'https://login.chinacloudapi.cn/'       { 'AzureChinaCloud'   }
        'https://login-us.microsoftonline.com/' { 'AzureUSGovernment' }
        'https://login.microsoftonline.de/'     { 'AzureGermanCloud'  }

        Default { throw "Unsupported graph resource identifier: $_" }
    }

    return $graphEnvironment
}

Invoke-Main
