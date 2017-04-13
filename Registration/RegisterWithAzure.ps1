# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information. 

<# 
 
.SYNOPSIS 
 
This script can be used to register Azure Stack POC with Azure. To run this script, you must have a public Azure subscription of any type. 
There must also be an account that is an owner or contributor of the subscription. This account cannot be an MSA (i.e. cannot be live.com or hotmail.com) or 2FA account. 

.DESCRIPTION 
 
RegisterToAzure runs local scripts to connect your Azure Stack to Azure. After connecting with Azure, you can test marketplace syndication. 

The script will follow four steps:
Configure bridge identity: configures Azure Stack so that it can call to Azure via your Azure subscription
Get registration request: get Azure Stack environment information to create a registration for this azure stack in azure
Register with Azure: uses Azure powershell to create an "Azure Stack Registration" resource on your Azure subscription
Activate Azure Stack: final step in connecting Azure Stack to be able to call out to Azure

.PARAMETER azureSubscriptionId  
 
Azure subscription ID that you want to register your Azure Stack with. This parameter is mandatory.

.PARAMETER azureDirectory  
 
Name of your AAD Tenant which your Azure subscription is a part of. This parameter is mandatory.

.PARAMETER azureSubscriptionOwner
 
Username for an owner/contributor of the azure subscription. This user must not be an MSA or 2FA account. This parameter is mandatory.

.PARAMETER azureSubscriptionPassword

Password for the Azure subscription. You will be prompted to type in this password. This parameter is mandatory.

.PARAMETER marketplaceSyndication

Flag (ON/OFF) whether to enable downloading items from the Azure marketplace on this environment. Defaults to "ON".

.PARAMETER reportUsage

Flag (ON/OFF) whether to enable pushing usage data to Azure on this environment. Defaults to "ON".


.EXAMPLE

This script must be run from the Host machine of the POC. 
.\RegisterWithAzure.ps1 -azureSubscriptionId "5e0ae55d-0b7a-47a3-afbc-8b372650abd3" -azureDirectory "contoso.onmicrosoft.com" -azureSubscriptionOwner "serviceadmin@contoso.onmicrosoft.com"

 
.NOTES 
 Ensure that you have an Azure subscription 
#>

[CmdletBinding()]
Param     (
    [Parameter(Mandatory = $true)]
    [string]$azureDirectory,

    [Parameter(Mandatory = $true)]
    [String]$azureSubscriptionId,

    [Parameter(Mandatory = $true)]
    [String]$azureSubscriptionOwner,

    [Parameter(Mandatory = $true)]
    [securestring]$azureSubscriptionPassword,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('On', 'Off')]
    [string] $marketplaceSyndication = 'On',

    [Parameter(Mandatory=$false)]
    [ValidateSet('On', 'Off')]
    [string] $reportUsage = 'On'
)

#requires -Module AzureRM.Profile
#requires -Module AzureRM.Resources
#requires -RunAsAdministrator

Import-Module C:\CloudDeployment\ECEngine\EnterpriseCloudEngine.psm1 -Force 
cd  C:\CloudDeployment\Setup\Activation\Bridge

Read-Host "This script will turn marketplace syndication $marketplaceSyndication and usage reporting $reportUsage. You can change this by running the script using different flags. Press Enter to continue."

# Determine version of TP3 and set values accordingly
 $versionInfo = [xml] (Get-Content -Path C:\CloudDeployment\Configuration\Version\version.xml) 
if($versionInfo.Version -ge "1.0.170308.2") 
{ 
    Write-Verbose -Message "Using TP3.N release" -Verbose
    $bridgeAppConfigFile = "\\SU1FileServer\SU1_Infrastructure_1\ASResourceProvider\Config\AzureBridge.IdentityApplication.Configuration.json" 
} 
elseif($versionInfo.Version -eq "1.0.170225.2") 
{ 
    Write-Verbose -Message "Using TP3.O release" -Verbose
    $bridgeAppConfigFile = "\\SU1FileServer\SU1_Infrastructure_1\ASResourceProvider\Config\ConnectionAzureArm.IdentityApplication.Configuration.json"
} 
else 
{ 
    Write-Error -Message "Unsupported TP3 release" -Verbose 
} 


#
# Step 1: Configure Bridge identity
#

$azureCreds = New-Object System.Management.Automation.PSCredential($azureSubscriptionOwner, $azureSubscriptionPassword)
.\Configure-BridgeIdentity.ps1 -AzureCredential $azureCreds -AzureDirectoryTenantId $azureDirectory -AzureEnvironment AzureCloud -Verbose
Write-Host "STEP 1: Configure local identity completed"

#
# Step 2: Create new registration request
#

$registrationOutputFile = "c:\temp\registration.json"
.\New-RegistrationRequest.ps1 -BridgeAppConfigFile $bridgeAppConfigFile -RegistrationRequestOutputFile $registrationOutputFile -Verbose
Read-Host "STEP 2: Registration request completed. Re-enter your Azure subscription credentials in the next step. Note: Step 3 can be run from a different machine that is connected to Azure. Press Enter to continue and run step 3 from this machine."

#
# Step 3: Register Azure Stack with Azure
#
New-Item -ItemType Directory -Force -Path "C:\temp"
$registrationRequestFile = "c:\temp\registration.json"
$registrationOutputFile = "c:\temp\registrationOutput.json"

Login-AzureRmAccount -EnvironmentName AzureCloud
Select-AzureRmSubscription -SubscriptionId $azureSubscriptionId

# Ensure subscription is registered to Microsoft.AzureStack namespace in Azure
Register-AzureRmResourceProvider -ProviderNamespace 'microsoft.azurestack'
$result                        = $null
$attempts                      = 0
$maxAttempts                   = 20
$delayInSecondsBetweenAttempts = 10
do
{
    $attempts++
    Write-Verbose "[CHECK] Checking for resource provider registration... (attempt $attempts of $maxAttempts)"
    $result = $(Get-AzureRmResourceProvider -ProviderNamespace 'microsoft.azurestack')[0].RegistrationState -EQ 'Registered'
    $result
    if ((-not $result) -and ($attempts -lt $maxAttempts))
    {
        Write-Verbose "[DELAY] Attempt $attempts failed to see provider registration, delaying for $delayInSecondsBetweenAttempts seconds before retry"
        Start-Sleep -Seconds $delayInSecondsBetweenAttempts
    }
}
while ((-not $result) -and ($attempts -lt $maxAttempts))

if (-not $result)
{
    throw New-Object System.InvalidOperationException("Azure Bridge Resource Provider was registered but did not become routable within the alloted time")
}

.\Register-AzureStack.ps1 -BillingModel Consumption -Syndication $marketplaceSyndication -ReportUsage $reportUsage -SubscriptionId $azureSubscriptionId -AzureAdTenantId $azureDirectory `
  -AzureCredential $azureCreds -AzureEnvironmentName AzureCloud -RegistrationRequestFile $registrationRequestFile -RegistrationOutputFile $registrationOutputFile -Location "westcentralus" -Verbose
Read-Host "STEP 3: Register Azure Stack with Azure completed. Press Enter to continue."

#
# Step 4: Activate Azure Stack
#

# temporary step to adjust registration output to expected format
$reg = Get-Content $registrationOutputFile | ConvertFrom-Json
$newProps = @{
ObjectId = $reg.properties.ObjectId
ProvisioningState = $reg.properties.provisioningState
syndication = $marketplaceSyndication
usagebridge = $reportUsage
}
$reg.properties = $newProps
$reg | ConvertTo-Json -Depth 4 | Out-File -FilePath $registrationOutputFile

$regResponse = Get-Content -path  $registrationOutputFile
$AzureResourceManagerEndpoint = "https://management.azure.com"

if($versionInfo.Version -ge "1.0.170308.2") 
{ 
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($regResponse)
    $activationCode = [Convert]::ToBase64String($bytes)
    .\Activate-Bridge.ps1 -activationCode $activationCode -AzureResourceManagerEndpoint $AzureResourceManagerEndpoint -Verbose
}
elseif($versionInfo.Version -eq "1.0.170225.2") 
{ 
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($regResponse)
    $activationCode = [Convert]::ToBase64String($bytes)
    .\Activate-Bridge.ps1 -activationCode $activationCode -Verbose
} 

Write-Host "STEP 4: Activate Azure Stack completed"
Write-Host "Registration complete. Close and re-open the Marketplace Management blade in the admin portal."
