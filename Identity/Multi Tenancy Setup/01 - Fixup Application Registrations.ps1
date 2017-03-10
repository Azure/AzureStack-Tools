<#
.SYNOPSIS
    Initializes a directory tenant for use with Azure Stack. This script completes the onboarding process for the target directory.
#>
[CmdletBinding()]
param
(
    # The endpoint URI of the Admin Resource Manager.
    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [uri] $ResourceManagerEndpointUri,

    # Credential with access to the Azure Stack Administrator subscription. Must support non-interactive auth flow.
    [Parameter()]
    [ValidateNotNull()]
    [pscredential] $AzureStackAdminCredential = (Get-Credential -UserName 'ciserviceadmin@msazurestack.onmicrosoft.com' -Message 'Provide Azure Stack Admin Credential:'),

    # The identifier of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $DirectoryTenantId,

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
    [string] $Location = 'local',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
    [string] $InfrastructureSharePath = '\\SU1FileServer\SU1_Infrastructure_1'
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Import-Module -Name "AzureRm" -RequiredVersion "1.2.8"

# Initialize Azure PowerShell to call ARM
$params = @{
    ResourceManagerEndpoint = $ResourceManagerEndpointUri
    DirectoryTenantId       = $DirectoryTenantId
    Credential              = $AzureStackAdminCredential
    Name = "AzureStack-Admin"
}
& "$PSScriptRoot\AzurePowerShell\Initialize-AzurePowerShellEnvironment.ps1" @params

if ($SubscriptionName)
{
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName
}
elseif ($SubscriptionId)
{
    Select-AzureRmSubscription -SubscriptionId $SubscriptionId
}

# Import and read application data
# Note - The relevant metadata we need will be exposed via an API on ARM; for now, we retrieve this information from the environment
Write-Host "Loading identity application data..."
$xmlData = [xml](Get-ChildItem -Path C:\EceStore -Recurse -Force -File | Sort Length | Select -Last 1 | Get-Content | Out-String)
$xmlIdentityApplications = $xmlData.SelectNodes('//IdentityApplication')

foreach ($xmlIdentityApplication in $xmlIdentityApplications)
{
    $applicationData = Get-Content -Path ($xmlIdentityApplication.ConfigPath.Replace('{Infrastructure}', $InfrastructureSharePath)) | Out-String | ConvertFrom-Json

    # Note - 'Admin' applications do not need to be registered for replication into a new directory tenant
    if ($xmlIdentityApplication.Name.StartsWith('Admin'))
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
        }
    }

    # Advertise 'ReadDirectoryData' workaround for applications which require this permission of type 'Role'
    if ($xmlIdentityApplication.AADPermissions.ApplicationPermission.Name -icontains 'ReadDirectoryData')
    {
        # This is a 'false' oauth2permission requirement that downstream script knows how to handle
        $params.Properties.directoryRoles = @('Directory Readers')
    }

    $registeredApplication = New-AzureRmResource @params -Force -Verbose -ErrorAction Stop
    Write-Verbose -Message "Identity application registered: $(ConvertTo-Json $registeredApplication)" -Verbose
}
