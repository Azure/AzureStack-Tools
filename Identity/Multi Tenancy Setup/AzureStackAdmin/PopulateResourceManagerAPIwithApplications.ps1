<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

<#
.SYNOPSIS
    Prepares the Azure Stack deployment for future multitenant onboarding. This script only needs to be run once after deployment. Will prompt for user credentials.
#>
[CmdletBinding()]
param
(
    # The endpoint of the Azure Stack Resource Manager service.
    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [ValidateScript({$_.Scheme -eq [System.Uri]::UriSchemeHttps})]
    [uri] $ResourceManagerEndpoint,

    # The name of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $DirectoryTenantName,

    # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
    [Parameter()]
    [ValidateNotNull()]
    [string] $SubscriptionId = $null,

    # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
    [Parameter()]
    [ValidateNotNull()]
    [string] $SubscriptionName = $null,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName = 'system',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Location = 'local',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path -Path $_ -PathType Container -ErrorAction Stop})]
    [string] $InfrastructureSharePath = '\\SU1FileServer\SU1_Infrastructure_1'
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Install-Module AzureRm -RequiredVersion '1.2.8'
Import-Module 'AzureRm.Profile' -RequiredVersion '1.0.4.2' -Force -Verbose:$false 4> $null

function Invoke-Main
{
    Write-Warning "This script is intended to work only with the initial TP3 release of Azure Stack and will be deprecated."
 
    # Initialize the Azure PowerShell module to communicate with Azure Stack. Will prompt user for credentials.
    $azureEnvironment = Initialize-AzureRmEnvironment 'AzureStackAdmin'
    $azureAccount     = Initialize-AzureRmUserAccount $azureEnvironment

    # Register each identity application for future onboarding.
    $xmlIdentityApplications = Get-IdentityApplicationData
    foreach ($xmlIdentityApplication in $xmlIdentityApplications)
    {
        $applicationData = Get-Content -Path ($xmlIdentityApplication.ConfigPath.Replace('{Infrastructure}', $InfrastructureSharePath)) | Out-String | ConvertFrom-Json

        # Note - 'Admin' applications do not need to be registered for replication into a new directory tenant
        if ($xmlIdentityApplication.Name.StartsWith('Admin', [System.StringComparison]::OrdinalIgnoreCase))
        {
            Write-Warning "Skipping registration of Admin application: $('{0}.{1}' -f $xmlIdentityApplication.Name, $xmlIdentityApplication.DisplayName)"
            continue
        }

        # Advertise any necessary OAuth2PermissionGrants for the application
        $oauth2PermissionGrants = @()
        foreach ($applicationFriendlyName in $xmlIdentityApplication.OAuth2PermissionGrants.FirstPartyApplication.FriendlyName)
        {
            $oauth2PermissionGrants += [pscustomobject]@{
                Resource    = $applicationData.ApplicationInfo.appId
                Client      = $applicationData.GraphInfo.Applications."$applicationFriendlyName".Id
                ConsentType = 'AllPrincipals'
                Scope       = 'user_impersonation'
            }
        }

        $params = @{
            ApiVersion        = '2015-11-01' # needed if using "latest" / later version of Azure Powershell
            ResourceType      = "Microsoft.Subscriptions.Providers/applicationRegistrations"
            ResourceGroupName = $ResourceGroupName
            ResourceName      = '{0}.{1}' -f $xmlIdentityApplication.Name, $xmlIdentityApplication.DisplayName
            Location          = $Location
            Properties        = @{
                "objectId"               = $applicationData.ApplicationInfo.objectId
                "appId"                  = $applicationData.ApplicationInfo.appId
                "oauth2PermissionGrants" = $oauth2PermissionGrants
                "directoryRoles"         = @()
                "tags"                   = @()
            }
        }

        # Advertise 'ReadDirectoryData' workaround for applications which require this permission of type 'Role'
        if ($xmlIdentityApplication.AADPermissions.ApplicationPermission.Name -icontains 'ReadDirectoryData')
        {
            $params.Properties.directoryRoles = @('Directory Readers')
        }

        # Advertise any specified tags required for application integration scenarios
        if ($xmlIdentityApplication.tags)
        {
            $params.Properties.tags += $xmlIdentityApplication.tags
        }

        $registeredApplication = New-AzureRmResource @params -Force -Verbose -ErrorAction Stop
        Write-Verbose -Message "Identity application registered: $(ConvertTo-Json $registeredApplication)" -Verbose
    }
}

function Initialize-AzureRmEnvironment([string]$environmentName)
{
    $endpoints = Invoke-RestMethod -Method Get -Uri "$($ResourceManagerEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -Verbose
    Write-Verbose -Message "Endpoints: $(ConvertTo-Json $endpoints)" -Verbose

    # resolve the directory tenant ID from the name
    $directoryTenantId = (New-Object uri(Invoke-RestMethod "$($endpoints.authentication.loginEndpoint.TrimEnd('/'))/$DirectoryTenantName/.well-known/openid-configuration").token_endpoint).AbsolutePath.Split('/')[1]

    $azureEnvironmentParams = @{
        Name                                     = $environmentName
        ActiveDirectoryEndpoint                  = $endpoints.authentication.loginEndpoint.TrimEnd('/') + "/"
        ActiveDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
        AdTenant                                 = $directoryTenantId
        ResourceManagerEndpoint                  = $ResourceManagerEndpoint
        GalleryEndpoint                          = $endpoints.galleryEndpoint
        GraphEndpoint                            = $endpoints.graphEndpoint
        GraphAudience                            = $endpoints.graphEndpoint
    }

    Remove-AzureRmEnvironment -Name $environmentName -Force -ErrorAction Ignore | Out-Null
    $azureEnvironment = Add-AzureRmEnvironment @azureEnvironmentParams
    $azureEnvironment = Get-AzureRmEnvironment -Name $environmentName
    
    return $azureEnvironment
}

function Initialize-AzureRmUserAccount([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureEnvironment)
{
    # Prompts the user for interactive login flow
    $azureAccount = Add-AzureRmAccount -EnvironmentName $azureEnvironment.Name -TenantId $azureEnvironment.AdTenant
    
    if ($SubscriptionName)
    {
        Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
    }
    elseif ($SubscriptionId)
    {
        Select-AzureRmSubscription -SubscriptionId $SubscriptionId  | Out-Null
    }

    return $azureAccount
}

function Get-IdentityApplicationData
{
    # Import and read application data
    Write-Host "Loading identity application data..."
    $xmlData = [xml](Get-ChildItem -Path C:\EceStore -Recurse -Force -File | Sort Length | Select -Last 1 | Get-Content | Out-String)
    $xmlIdentityApplications = $xmlData.SelectNodes('//IdentityApplication')

    return $xmlIdentityApplications
}

Invoke-Main
