<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

<#
.SYNOPSIS
    Allows a new directory tenant to be onboarded to the Azure Stack deployment. Will prompt for user credentials.
#>
[CmdletBinding()]
param
(
    # The endpoint of the Azure Stack Resource Manager service.
    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [ValidateScript({$_.Scheme -eq [System.Uri]::UriSchemeHttps})]
    [uri] $AdminResourceManagerEndpoint,

    # The name of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $DirectoryTenantName,

    # The name of the guest Directory Tenant which is to be onboarded.
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $GuestDirectoryTenantName,

    # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
    [ValidateNotNull()]
    [string] $SubscriptionId = $null,

    # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
    [ValidateNotNull()]
    [string] $SubscriptionName = $null,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName = 'system',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Location = 'local'
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Install-Module AzureRm -RequiredVersion '1.2.8'
Import-Module 'AzureRm.Profile' -RequiredVersion '1.0.4.2' -Force -Verbose:$false 4> $null

function Invoke-Main
{
    # Initialize the Azure PowerShell module to communicate with Azure Stack. Will prompt user for credentials.
    $azureEnvironment = Initialize-AzureRmEnvironment 'AzureStackAdmin'
    $azureAccount     = Initialize-AzureRmUserAccount $azureEnvironment

    # resolve the guest directory tenant ID from the name
    $guestDirectoryTenantId = (New-Object uri(Invoke-RestMethod "$($azureEnvironment.ActiveDirectoryAuthority.TrimEnd('/'))/$GuestDirectoryTenantName/.well-known/openid-configuration").token_endpoint).AbsolutePath.Split('/')[1]

    # Add (or update) the new directory tenant to the Azure Stack deployment
    $params = @{
        ApiVersion        = '2015-11-01' # needed if using "latest" / later version of Azure Powershell
        ResourceType      = "Microsoft.Subscriptions.Admin/directoryTenants"
        ResourceGroupName = $ResourceGroupName
        ResourceName      = $GuestDirectoryTenantName
        Location          = $Location
        Properties        = @{ tenantId = $guestDirectoryTenantId }
    }
    $directoryTenant = New-AzureRmResource @params -Force -Verbose -ErrorAction Stop
    Write-Verbose -Message "Directory Tenant onboarded: $(ConvertTo-Json $directoryTenant)" -Verbose
}

function Initialize-AzureRmEnvironment([string]$environmentName)
{
    $endpoints = Invoke-RestMethod -Method Get -Uri "$($AdminResourceManagerEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -Verbose
    Write-Verbose -Message "Endpoints: $(ConvertTo-Json $endpoints)" -Verbose

    # resolve the directory tenant ID from the name
    $directoryTenantId = (New-Object uri(Invoke-RestMethod "$($endpoints.authentication.loginEndpoint.TrimEnd('/'))/$DirectoryTenantName/.well-known/openid-configuration").token_endpoint).AbsolutePath.Split('/')[1]

    $azureEnvironmentParams = @{
        Name                                     = $environmentName
        ActiveDirectoryEndpoint                  = $endpoints.authentication.loginEndpoint.TrimEnd('/') + "/"
        ActiveDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
        AdTenant                                 = $directoryTenantId
        ResourceManagerEndpoint                  = $AdminResourceManagerEndpoint
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

Invoke-Main
