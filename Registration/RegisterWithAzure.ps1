# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#

.SYNOPSIS

This script can be used to register Azure Stack POC with Azure. To run this script, you must have a public Azure subscription of any type.
There must also be an account that is an owner or contributor of the subscription. 

.DESCRIPTION

RegisterToAzure runs local scripts to connect your Azure Stack to Azure. After connecting with Azure, you can test marketplace syndication.

The script will follow four steps:
Configure bridge identity: configures Azure Stack so that it can call to Azure via your Azure subscription
Get registration request: get Azure Stack environment information to create a registration for this azure stack in azure
Register with Azure: uses Azure powershell to create an "Azure Stack Registration" resource on your Azure subscription
Activate Azure Stack: final step in connecting Azure Stack to be able to call out to Azure

.PARAMETER azureSubscriptionId


Azure subscription ID that you want to register your Azure Stack with. This parameter is mandatory.

.PARAMETER azureDirectoryTenantName

Name of your AAD Tenant which your Azure subscription is a part of. This parameter is mandatory.

.PARAMETER azureAccountId

Username for an owner/contributor of the azure subscription. This user must not be an MSA or 2FA account. This parameter is mandatory.

.PARAMETER azureAccountPassword

Password for the Azure subscription. You will be prompted to type in this password if its not specified.  Make sure JavaScript is enabled for the browser.

.PARAMETER azureEnvironment

Environment name for use in retrieving tenant details and running several of the activation scripts. Defaults to "AzureCloud".

.PARAMETER azureResourceManagerEndpoint

URI used for ActivateBridge.ps1 that refers to the endpoint for Azure Resource Manager. Defaults to "https://management.azure.com"

.EXAMPLE

This script must be run from the Host machine of the POC.
.\RegisterWithAzure.ps1 -azureSubscriptionId "5e0ae55d-0b7a-47a3-afbc-8b372650abd3" -azureDirectoryTenantId "contoso.onmicrosoft.com" -azureAccountId "serviceadmin@contoso.onmicrosoft.com" -azureCredentialPassword "password"


.NOTES
 Ensure that you have an Azure subscription and it is registered for Microsoft.AzureStack namespace in Azure.
 Namespace can be registered with the following command:
 Register-AzureRmResourceProvider -ProviderNamespace 'microsoft.azurestack' 
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [PSCredential] $azureCredential,

    [Parameter(Mandatory=$true)]
    [String] $azureAccountId,

    [Parameter(Mandatory=$true)]
    [String] $azureSubscriptionId,

    [Parameter(Mandatory=$true)]
    [String] $azureDirectoryTenantName,

    [Parameter(Mandatory=$false)]
    [String] $azureEnvironment = "AzureCloud",

    [Parameter(Mandatory=$false)]
    [String] $azureResourceManagerEndpoint = "https://management.azure.com",

    [Parameter(Mandatory=$false)]
    [Switch] $enableSyndication = $true,

    [Parameter(Mandatory=$false)]
    [Switch] $reportUsage = $false
)

#requires -Module AzureRM.Profile
#requires -Module AzureRM.Resources
#requires -RunAsAdministrator

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$VerbosePreference     = [System.Management.Automation.ActionPreference]::Continue

Import-Module C:\CloudDeployment\ECEngine\EnterpriseCloudEngine.psd1 -Force
Set-Location  C:\CloudDeployment\Setup\Activation\Bridge

#
# Pre-req: Version check
#

$versionInfo = [xml] (Get-Content -Path C:\CloudDeployment\Configuration\Version\version.xml) 
$minVersion  = "1.0.170501.1"
if($versionInfo.Version -lt $minVersion)
{
    Write-Error -Message "Script only applicable for Azure Stack builds $minVersion or later"
}
else
{
    Write-Verbose -Message "Running registration on build $($versionInfo.Version)" -Verbose
}

#
# Obtain refresh token for Azure identity
#

Import-Module C:\CloudDeployment\Setup\Common\AzureADConfiguration.psm1 -ErrorAction Stop
$AzureDirectoryTenantId = Get-TenantIdFromName -azureEnvironment $azureEnvironment -tenantName $azureDirectoryTenantName

if(-not $azureCredential)
{
    Write-Verbose "Prompt user to enter Azure Credentials to get refresh token"
    $tenantDetails = Get-AzureADTenantDetails -AzureEnvironment $azureEnvironment -AADDirectoryTenantName $azureDirectoryTenantName
}
else
{
    Write-Verbose "Using provided Azure Credentials to get refresh token"
    $tenantDetails = Get-AzureADTenantDetails -AzureEnvironment $azureEnvironment -AADDirectoryTenantName $azureDirectoryTenantName -AADAdminCredential $azureCredential
}

$refreshToken = (ConvertTo-SecureString -string $tenantDetails["RefreshToken"] -AsPlainText -Force)

#
# Step 1: Configure Bridge identity
#

.\Configure-BridgeIdentity.ps1 -RefreshToken $refreshToken -AzureAccountId $azureAccountId -AzureDirectoryTenantName $azureDirectoryTenantName -AzureEnvironment $azureEnvironment -Verbose
Write-Verbose "Configure Bridge identity completed"

#
# Step 2: Create new registration request
#

$bridgeAppConfigFile = "\\SU1FileServer\SU1_Infrastructure_1\ASResourceProvider\Config\AzureBridge.IdentityApplication.Configuration.json"
$registrationOutputFile = "c:\temp\registration.json"
.\New-RegistrationRequest.ps1 -BridgeAppConfigFile $bridgeAppConfigFile -RegistrationRequestOutputFile $registrationOutputFile -Verbose
Write-Verbose "New registration request completed"

#
# Step 3: Register Azure Stack with Azure
#

New-Item -ItemType Directory -Force -Path "C:\temp"
$registrationRequestFile = "c:\temp\registration.json"
$registrationOutputFile = "c:\temp\registrationOutput.json"

.\Register-AzureStack.ps1 -BillingModel PayAsYouUse -EnableSyndication -ReportUsage -SubscriptionId $azureSubscriptionId -AzureAdTenantId $AzureDirectoryTenantId `
                          -RefreshToken $refreshToken -AzureAccountId $azureAccountId -AzureEnvironmentName $azureEnvironment -RegistrationRequestFile $registrationRequestFile `
                          -RegistrationOutputFile $registrationOutputFile -Location "westcentralus" -Verbose
Write-Verbose "Register Azure Stack with Azure completed"

#
# workaround to enable syndication and usage
#

$activationDataFile = "c:\temp\regOutput2.json"
$reg = Get-Content $registrationOutputFile | ConvertFrom-Json

$newProps = @{
    ObjectId          = $reg.properties.ObjectId
    ProvisioningState = $reg.properties.provisioningState
    enablesyndication = $enableSyndication
    reportusage       = $reportUsage
}

$reg.properties = $newProps
$reg | ConvertTo-Json -Depth 4 | Out-File -FilePath $activationDataFile

Write-Verbose "Activation file is at : $activationDataFile"

#
# Step 4: Activate Azure Stack
#
$regResponse = Get-Content -path  $activationDataFile
$bytes = [System.Text.Encoding]::UTF8.GetBytes($regResponse)
$activationCode = [Convert]::ToBase64String($bytes)

.\Activate-Bridge.ps1 -activationCode $activationCode -AzureResourceManagerEndpoint $azureResourceManagerEndpoint -Verbose
Write-Verbose "Azure Stack activation completed"
