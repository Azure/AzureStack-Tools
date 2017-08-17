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
# Install-Module -Name AzureStack -RequiredVersion 1.2.10
$TenantAdminCreds =  New-Object System.Management.Automation.PSCredential "<Tenant Admin username>", (ConvertTo-SecureString "<Tenant Admin password>" -AsPlainText -Force)
$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "<Service Admin username>", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1  -TenantID "<TenantID from Azure Active Directory>" -AdminArmEndpoint "<Administrative ARM endpoint>" -ServiceAdminCredentials $ServiceAdminCreds -TenantArmEndpoint "<Tenant ARM endpoint>" -TenantAdminCredentials $TenantAdminCreds
```

## To execute Canary as Tenant Administrator (if Windows Server 2016 or Windows Server 2012-R2 images are not present in PIR)

```powershell
# Download the WS2016 ISO image from: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2016, and place it on your local machine
# Install-Module -Name 'AzureRm.Bootstrapper'
# Install-AzureRmProfile -profile '2017-03-09-profile' -Force
# Install-Module -Name AzureStack -RequiredVersion 1.2.10 
$TenantAdminCreds =  New-Object System.Management.Automation.PSCredential "<Tenant Admin username>", (ConvertTo-SecureString "<Tenant Admin password>" -AsPlainText -Force)
$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "<Service Admin username>", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1  -TenantID "<TenantID from Azure Active Directory>" -AdminArmEndpoint "<Administrative ARM endpoint>" -ServiceAdminCredentials $ServiceAdminCreds -TenantArmEndpoint "<Tenant ARM endpoint>" -TenantAdminCredentials $TenantAdminCreds -WindowsISOPath "<path where the WS2016 ISO is present>"
```

## To execute Canary as Service Administrator

```powershell
# Install-Module -Name 'AzureRm.Bootstrapper'
# Install-AzureRmProfile -profile '2017-03-09-profile' -Force
# Install-Module -Name AzureStack -RequiredVersion 1.2.10
$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "<Service Admin username>", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1 -TenantID "<TenantID from Azure Active Directory>" -AdminArmEndpoint "<Administrative ARM endpoint>" -ServiceAdminCredentials $ServiceAdminCreds
```

## To list the usecases in Canary

```powershell
# Install-Module -Name 'AzureRm.Bootstrapper'
# Install-AzureRmProfile -profile '2017-03-09-profile' -Force
# Install-Module -Name AzureStack -RequiredVersion 1.2.10
.\Canary.Tests.ps1 -ListAvailable

Sample output:
PS C:\AzureStack-Tools-vnext\CanaryValidator> .\Canary.Tests.ps1 -ListAvailable
List of scenarios in Canary:
        CreateAdminAzureStackEnv
        LoginToAzureStackEnvAsSvcAdmin
        SelectDefaultProviderSubscription
        ListFabricResourceProviderInfo
        |--GetAzureStackInfraRole
        |--GetAzureStackInfraRoleInstance
        |--GetAzureStackLogicalNetwork
        |--GetAzureStackStorageCapacity
        |--GetAzureStackStorageShare
        |--GetAzureStackScaleUnit
        |--GetAzureStackScaleUnitNode
        |--GetAzureStackIPPool
        |--GetAzureStackMacPool
        |--GetAzureStackGatewayPool
        |--GetAzureStackSLBMux
        |--GetAzureStackGateway
        ListHealthResourceProviderAlerts
        |--GetAzureStackAlert
        ListUpdatesResourceProviderInfo
        |--GetAzureStackUpdateSummary
        |--GetAzureStackUpdateToApply
        CreateTenantAzureStackEnv
        CreateResourceGroupForTenantSubscription
        CreateTenantPlan
        CreateTenantOffer
        CreateTenantDefaultManagedSubscription
        LoginToAzureStackEnvAsTenantAdmin
        CreateTenantSubscription
        RoleAssignmentAndCustomRoleDefinition
        |--ListAssignedRoles
        |--ListExistingRoleDefinitions
        |--GetProviderOperations
        |--AssignReaderRole
        |--VerifyReaderRoleAssignment
        |--RemoveReaderRoleAssignment
        |--CustomRoleDefinition
        |--ListRoleDefinitionsAfterCustomRoleCreation
        |--RemoveCustomRoleDefinition
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
        AddDatadiskToVMWithPrivateIP
        |--StopDeallocateVMWithPrivateIPBeforeAddingDatadisk
        |--AddTheDataDiskToVMWithPrivateIP
        |--StartVMWithPrivateIPAfterAddingDatadisk
        ApplyDataDiskCheckCustomScriptExtensionToVMWithPrivateIP
        |--CheckForExistingCustomScriptExtensionOnVMWithPrivateIP
        |--ApplyCustomScriptExtensionToVMWithPrivateIP
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
        |--DeleteTenantSubscriptions
        |--LoginToAzureStackEnvAsSvcAdminForCleanup
        |--RemoveLinuxImageFromPIR
        |--DeleteSubscriptionResourceGroup
```

## To exclude certain usecases from getting executed

```powershell
# Install-Module -Name 'AzureRm.Bootstrapper'
# Install-AzureRmProfile -profile '2017-03-09-profile' -Force
# Install-Module -Name AzureStack -RequiredVersion 1.2.10
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
