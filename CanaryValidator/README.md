# AzureStack Canary validator
Canary validator provides a breadth customer experience with the Azure Stack deployment. It tries to exercise the various customer scenarios/usecases on the deployment. 

Instructions are relative to the .\CanaryValidator directory.
Canary can be invoked either as Service Administrator or Tenant Administrator.

## Download Canary

```powershell
Invoke-WebRequest https://github.com/Azure/AzureStack-Tools/archive/master.zip -OutFile master.zip
Expand-Archive master.zip -DestinationPath . -Force
Set-Location -Path ".\AzureStack-Tools-master\CanaryValidator" -PassThru
```

## To execute Canary as Tenant Administrator (if Windows Server 2016 or Windows Server 2012-R2 images are already present in the PIR)

```powershell
# Install-Module -Name 'AzureRm.Bootstrapper'
# Install-AzureRmProfile -profile '2017-03-09-profile' -Force
# Install-Module -Name AzureStack -RequiredVersion 1.2.11
# $TenantID = To retrieve the TenantID if not available already, you can use Get-AzureStackStampInformation cmdlet Using the privileged endpoint in Azure Stack. https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-privileged-endpoint
$TenantAdminCreds =  New-Object System.Management.Automation.PSCredential "tenantadminuser@contoso.com", (ConvertTo-SecureString "<Tenant Admin password>" -AsPlainText -Force)
$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "serviceadmin@contoso.com", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1  -TenantID "<TenantID from Azure Active Directory>" -AdminArmEndpoint "<Administrative ARM endpoint>" -ServiceAdminCredentials $ServiceAdminCreds -TenantArmEndpoint "<Tenant ARM endpoint>" -TenantAdminCredentials $TenantAdminCreds
```

## To execute Canary as Tenant Administrator (if Windows Server 2016 or Windows Server 2012-R2 images are not present in PIR)

```powershell
# Download the WS2016 ISO image from: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2016, and place it on your local machine
# Install-Module -Name 'AzureRm.Bootstrapper'
# Install-AzureRmProfile -profile '2017-03-09-profile' -Force
# Install-Module -Name AzureStack -RequiredVersion 1.2.11
# $TenantID = To retrieve the TenantID if not available already, you can use Get-AzureStackStampInformation cmdlet Using the privileged endpoint in Azure Stack. https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-privileged-endpoint
$TenantAdminCreds =  New-Object System.Management.Automation.PSCredential "tenantadminuser@contoso.com", (ConvertTo-SecureString "<Tenant Admin password>" -AsPlainText -Force)
$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "serviceadmin@contoso.com", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1  -TenantID "<TenantID from Azure Active Directory>" -AdminArmEndpoint "<Administrative ARM endpoint>" -ServiceAdminCredentials $ServiceAdminCreds -TenantArmEndpoint "<Tenant ARM endpoint>" -TenantAdminCredentials $TenantAdminCreds -WindowsISOPath "<path where the WS2016 ISO is present>"
```
## To execute Canary as Tenant Administrator (In ADFS disconnected scenario)
Install Azure PowerShell - To install Azure PowerShell in a disconnected or a partially connected senario, follow the instructions @ https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install?view=azurestackps-1.2.9&toc=%2fpowershell%2fmodule%2ftoc.json%3fview%3dazurestackps-1.2.9&view=azurestackps-1.2.9#install-powershell-in-a-disconnected-or-in-a-partially-connected-scenario
```powershell
# TenantID = To retrieve the TenantID if not available already, you can use Get-AzureStackStampInformation cmdlet Using the privileged endpoint in Azure Stack. https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-privileged-endpoint

# If there is no tenant user available, you can create one and use it as shown below

$tenantAdminUserName = "TenantAdminUser"
$tenantAdminPassword = "<Tenant Admin password>"
$tenantAdminAccount  = New-ADUser -Name $tenantAdminUserName -UserPrincipalName "$tenantAdminUserName@$env:USERDNSDOMAIN" -AccountPassword $tenantAdminPassword -ChangePasswordAtLogin $false -Enabled $true -PasswordNeverExpires $true -PassThru
$tenantAdminUpn      = $tenantAdminAccount.UserPrincipalName
$tenantAdminObjectId = $tenantAdminAccount.SID.Value
$TenantAdminCreds    = New-Object System.Management.Automation.PSCredential $tenantAdminUpn, (ConvertTo-SecureString $tenantAdminPassword -AsPlainText -Force)
$ServiceAdminCreds   =  New-Object System.Management.Automation.PSCredential "ServiceAdmin@contoso.com", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1  -TenantID "<TenantID from Azure Active Directory>" -TenantAdminObjectID $tenantAdminObjectId -AdminArmEndpoint "<Administrative ARM endpoint>" -ServiceAdminCredentials $ServiceAdminCreds -TenantArmEndpoint "<Tenant ARM endpoint>" -TenantAdminCredentials $TenantAdminCreds
```

## NOTE: 
While running Canary make sure to pass the usernames in the format: user@domain.com

## To list the usecases in Canary

```powershell
# Install-Module -Name 'AzureRm.Bootstrapper'
# Install-AzureRmProfile -profile '2017-03-09-profile' -Force
# Install-Module -Name AzureStack -RequiredVersion 1.2.11
.\Canary.Tests.ps1 -ListAvailable

Sample output:
PS C:\AzureStack-Tools-vnext\CanaryValidator> .\Canary.Tests.ps1 -ListAvailable
List of scenarios in Canary:
        CreateAdminAzureStackEnv
        LoginToAzureStackEnvAsSvcAdmin
        SelectDefaultProviderSubscription
        ListFabricResourceProviderInfo
        |-- GetAzureStackInfraRole
        |-- GetAzureStackInfraRoleInstance
        |-- GetAzureStackLogicalNetwork
        |-- GetAzureStackStorageCapacity
        |-- GetAzureStackInfrastructureShare
        |-- GetAzureStackScaleUnit
        |-- GetAzureStackScaleUnitNode
        |-- GetAzureStackIPPool
        |-- GetAzureStackMacPool
        |-- GetAzureStackGatewayPool
        |-- GetAzureStackSLBMux
        |-- GetAzureStackGateway
        ListHealthResourceProviderAlerts
        |-- GetAzureStackAlert
        ListUpdatesResourceProviderInfo
        |-- GetAzureStackUpdateSummary
        |-- GetAzureStackUpdateToApply
        UploadLinuxImageToPIR
        CreateTenantAzureStackEnv
        CreateResourceGroupForTenantSubscription
        CreateTenantPlan
        CreateTenantOffer
        CreateTenantDefaultManagedSubscription
        LoginToAzureStackEnvAsTenantAdmin
        CreateTenantSubscription
        RoleAssignmentAndCustomRoleDefinition
        |-- ListAssignedRoles
        |-- ListExistingRoleDefinitions
        |-- GetProviderOperations
        |-- AssignReaderRole
        |-- VerifyReaderRoleAssignment
        |-- RemoveReaderRoleAssignment
        |-- CustomRoleDefinition
        |-- ListRoleDefinitionsAfterCustomRoleCreation
        |-- RemoveCustomRoleDefinition
        RegisterResourceProviders
        CreateResourceGroupForUtilities
        CreateStorageAccountForUtilities
        CreateStorageContainerForUtilities
        CreateDSCScriptResourceUtility
        CreateCustomScriptResourceUtility
        CreateDataDiskForVM
        UploadUtilitiesToBlobStorage
        CreateKeyVaultStoreForCertSecret
        CreateResourceGroupForVMs
        DeployARMTemplate
        RetrieveResourceDeploymentTimes
        QueryTheVMsDeployed
        CheckVMCommunicationPreVMReboot
        TransmitMTUSizedPacketsBetweenTenantVMs
        AddDatadiskToVMWithPrivateIP
        |-- StopDeallocateVMWithPrivateIPBeforeAddingDatadisk
        |-- AddTheDataDiskToVMWithPrivateIP
        |-- StartVMWithPrivateIPAfterAddingDatadisk
        ApplyDataDiskCheckCustomScriptExtensionToVMWithPrivateIP
        |-- CheckForExistingCustomScriptExtensionOnVMWithPrivateIP
        |-- ApplyCustomScriptExtensionToVMWithPrivateIP
        RestartVMWithPublicIP
        StopDeallocateVMWithPrivateIP
        StartVMWithPrivateIP
        CheckVMCommunicationPostVMReboot
        CheckExistenceOfScreenShotForVMWithPrivateIP
        EnumerateAllResources
        DeleteVMWithPrivateIP
        DeleteVMResourceGroup
        DeleteUtilitiesResourceGroup
        TenantRelatedcleanup
        |-- DeleteTenantSubscriptions
        |-- LoginToAzureStackEnvAsSvcAdminForCleanup
        |-- RemoveLinuxImageFromPIR
        |-- DeleteSubscriptionResourceGroup
```

## To exclude certain usecases from getting executed

```powershell
# Install-Module -Name 'AzureRm.Bootstrapper'
# Install-AzureRmProfile -profile '2017-03-09-profile' -Force
# Install-Module -Name AzureStack -RequiredVersion 1.2.11
# A new paramter called ExclusionList has been added which is a string array. Pass in the list of usecases you don't want to execute to this parameter.
$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "<Service Admin username>", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1 -TenantID "<TenantID from Azure Active Directory>" -AdminArmEndpoint "<Administrative ARM endpoint>" -ServiceAdminCredentials $ServiceAdminCreds -ExclusionList "ListFabricResourceProviderInfo","ListUpdateResourceProviderInfo"
```

## Reading the results & logs

Canary generates log files in the TMP directory ($env:TMP). The logs can be found under the directory "CanaryLogs[DATETIME]". There are two types of logs generated, a text log and a JSON log. JSON log provides a quick and easy view of all the usecases and their corresponding results. Text log provides a more detailed output of each usecase execution, its output and results.

Each usecase entry in the JSON log consists of the following fields.

- Name
- Description
- StartTime
- EndTime
- Result
- Exception (in case a scenario fails)

The exception field is helpful to debug failed use cases.
