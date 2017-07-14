# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#

.SYNOPSIS

This script can be used to register Azure Stack POC with Azure. To run this script, you must have a public Azure subscription of any type.
There must also be an account that is an owner or contributor of the subscription, and you must have registered the AzureStack resource provider

.DESCRIPTION

RegisterWithAzure runs scripts already present in Azure Stack (path: $root\CloudDeployment\Setup\Activation\Bridge)to connect your Azure Stack to Azure.
After connecting with Azure, you can test marketplace syndication by downloading products from the marketplace. Usage data will also default to being reported to Azure for billing purposes.
To turn these features off see examples below.

The script will follow four steps:
Configure bridge identity: Creates Azure AD application that is used by Azure Bridge for marketplace syndication and by Usage Bridge to send Usage records (if configured).
Get registration request: get Azure Stack environment information to create a registration for this Azure Stack in azure
Register with Azure: uses Azure powershell to create an "Azure Stack Registration" resource on your Azure subscription
Activate Azure Stack: final step in connecting Azure Stack to be able to call out to Azure

.PARAMETER azureCredential

Powershell object that contains credential information such as user name and password. If not supplied script will request login via gui

.PARAMETER azureAccountId

Username for an owner/contributor of the azure subscription. This user must not be an MSA or 2FA account. This parameter is mandatory.

.PARAMETER azureSubscriptionId

Azure subscription ID that you want to register your Azure Stack with. This parameter is mandatory.

.PARAMETER azureDirectoryTenantName

Name of your AAD Tenant which your Azure subscription is a part of. This parameter is mandatory.

.PARAMETER azureEnvironment

Environment name for use in retrieving tenant details and running several of the activation scripts. Defaults to "AzureCloud".

.PARAMETER azureResourceManagerEndpoint

URI used for ActivateBridge.ps1 that refers to the endpoint for Azure Resource Manager. Defaults to "https://management.azure.com"

.PARAMETER enableSyndication

Boolean value used in Register-AzureStack.ps1 to enable marketplace syndication. Defaults to $true

.PARAMETER reportUsage

Boolean value used in Register-AzureStack.ps1 to enable reporting of usage records to Azure. Defaults to $true

.EXAMPLE

This example registers your AzureStack account with Azure, enables syndication, and enables usage reporting to Azure.
This script must be run from the Host machine of the POC.

.\RegisterWithAzure.ps1 -azureCredential $yourCredentials -azureSubscriptionId $subsciptionId -azureDirectoryTenantName "contoso.onmicrosoft.com" -azureAccountId "serviceadmin@contoso.onmicrosoft.com"

.EXAMPLE

This example registers your AzureStack account with Azure, enables syndication, and disables usage reporting to Azure. 

.\RegisterWithAzure.ps1 -azureCredential $yourCredentials -azureSubscriptionId $subsciptionId -azureDirectoryTenantName "contoso.onmicrosoft.com" -azureAccountId "serviceadmin@contoso.onmicrosoft.com" -reportUsage:$false

.NOTES
 Ensure that you have an Azure subscription and it is registered for Microsoft.AzureStack namespace in Azure.
 Namespace can be registered with the following command:
 Register-AzureRmResourceProvider -ProviderNamespace 'microsoft.azurestack' 

 If you would like to un-Register with azure by turning off marketplace syndication and usage reporting you can run this script again with both enableSyndication
 and reportUsage set to false. This will unconfigure usage bridge so that syndication isn't possible and usage data is not reported. 
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [PSCredential] $azureCredential,

    [Parameter(Mandatory = $true)]
    [String] $azureAccountId,

    [Parameter(Mandatory = $true)]
    [String] $azureSubscriptionId,

    [Parameter(Mandatory = $true)]
    [String] $azureDirectoryTenantName,

    [Parameter(Mandatory = $false)]
    [String] $azureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $false)]
    [String] $azureResourceManagerEndpoint = "https://management.azure.com",

    [Parameter(Mandatory = $false)]
    [bool] $enableSyndication = $true,

    [Parameter(Mandatory = $false)]
    [Switch] $reportUsage = $true
)

#requires -Module AzureRM.Profile
#requires -Module AzureRM.Resources
#requires -RunAsAdministrator

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

Import-Module C:\CloudDeployment\ECEngine\EnterpriseCloudEngine.psd1 -Force
Set-Location  C:\CloudDeployment\Setup\Activation\Bridge

#
# Pre-req: Version check
#

$versionInfo = [xml] (Get-Content -Path C:\CloudDeployment\Configuration\Version\version.xml) 
$minVersion = "1.0.170501.1"
if ($versionInfo.Version -lt $minVersion) {
    Write-Error -Message "Script only applicable for Azure Stack builds $minVersion or later"
}
else {
    Write-Verbose -Message "Running registration on build $($versionInfo.Version)" -Verbose
}

#
# Obtain refresh token for Azure identity
#

Import-Module C:\CloudDeployment\Setup\Common\AzureADConfiguration.psm1 -ErrorAction Stop
$AzureDirectoryTenantId = Get-TenantIdFromName -azureEnvironment $azureEnvironment -tenantName $azureDirectoryTenantName

if (-not $azureCredential) {
    Write-Verbose "Prompt user to enter Azure Credentials to get refresh token"
    $tenantDetails = Get-AzureADTenantDetails -AzureEnvironment $azureEnvironment -AADDirectoryTenantName $azureDirectoryTenantName
}
else {
    Write-Verbose "Using provided Azure Credentials to get refresh token"
    $tenantDetails = Get-AzureADTenantDetails -AzureEnvironment $azureEnvironment -AADDirectoryTenantName $azureDirectoryTenantName -AADAdminCredential $azureCredential
}

$refreshToken = (ConvertTo-SecureString -string $tenantDetails["RefreshToken"] -AsPlainText -Force)

$maxAttempts = 3
$currentAttempt = 0
$registerRPsuccessful = $false
do{

    try {
        Register-AzureRmResourceProvider -ProviderNamespace 'Microsoft.AzureStack'-Force -Verbose
        $registerRPsuccessful = $true
    }
    catch {
        $currentAttempt++
        if ($currentAttempt -gt $maxAttempts)
        {
            $exceptionMessage = $_.Exception.Message
            Write-Warning "Failed to register the Azure resource provider 'Microsoft.AzureStack' on attempt # $currentAttempt. Cancelling RegisterWithAzure.ps1"
            throw $exceptionMessage
        }
        Write-Verbose "Failed to register Azure resource provider 'Microsoft.AzureStack'. Trying again in 10 seconds"
        Start-Sleep -Seconds 10
    }
}while ((-not $registerRPsuccessful) -and ($currentAttempt -le $maxAttempts))


#
# Step 1: Configure Bridge identity
#

Write-Verbose "Calling Configure-BridgeIdentity.ps1"
.\Configure-BridgeIdentity.ps1 -RefreshToken $refreshToken -AzureAccountId $azureAccountId -AzureDirectoryTenantName $azureDirectoryTenantName -AzureEnvironment $azureEnvironment -Verbose
Write-Verbose "Configure Bridge identity completed"

#
# Step 2: Create new registration request
#

$bridgeAppConfigFile = "\\SU1FileServer\SU1_Infrastructure_1\ASResourceProvider\Config\AzureBridge.IdentityApplication.Configuration.json"
$registrationOutputFile = "c:\temp\registration.json"

Write-Verbose "Calling New-RegistrationRequest.ps1"
.\New-RegistrationRequest.ps1 -BridgeAppConfigFile $bridgeAppConfigFile -RegistrationRequestOutputFile $registrationOutputFile -Verbose
Write-Verbose "New registration request completed"

#
# Step 3: Register Azure Stack with Azure
#

New-Item -ItemType Directory -Force -Path "C:\temp"
$registrationRequestFile = "c:\temp\registration.json"
$registrationOutputFile = "c:\temp\registrationOutput.json"

$timestamp = [DateTime]::Now.ToString("yyyyMMdd-HHmmss")
$logPath = (New-Item -Path "$env:SystemDrive\CloudDeployment\Logs\" -ItemType Directory -Force).FullName
$logFile = Join-Path -Path $logPath -ChildPath "Register-AzureStack.${timestamp}.txt"
try { Start-Transcript -Path $logFile -Force | Out-String | Write-Verbose -Verbose } catch { Write-Warning -Message $_.Exception.Message }

    Write-Verbose "Calling Register-AzureStack.ps1"
    .\Register-AzureStack.ps1 -BillingModel PayAsYouUse -EnableSyndication -ReportUsage -SubscriptionId $azureSubscriptionId -AzureAdTenantId $AzureDirectoryTenantId `
                                -RefreshToken $refreshToken -AzureAccountId $azureAccountId -AzureEnvironmentName $azureEnvironment -RegistrationRequestFile $registrationRequestFile `
                                -RegistrationOutputFile $registrationOutputFile -Location "westcentralus" -Verbose
    Write-Verbose "Register Azure Stack with Azure completed"

try { Stop-Transcript -Verbose } catch { Write-Warning "$_" }

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

try {
    .\Activate-Bridge.ps1 -activationCode $activationCode -AzureResourceManagerEndpoint $azureResourceManagerEndpoint -Verbose
}
catch {
    $exceptionMessage = $_.Exception.Message

    if($exceptionMessage.Contains("Application is currently being upgraded"))
    {
        Write-Warning "Activate-Bridge: Known issue with redundant service fabric upgrade call" 
    }
    else
    {
        Write-Error -Message "Activate-Bridge: Error : $($_.Exception)"
    }
}

Write-Verbose "Azure Stack activation completed"
