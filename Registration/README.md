# Registration

The functions in this module allow you to perform the steps of registering your Azure Stack with your Azure subscription. Additional details can be found in the [documentation](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register).

### Prerequisites 

- You must install the correct version of Azure Powershell, and download the Azure Stack tools
  - For Integrated Systems, see [Install Powershell for Azure Stack](https://docs.microsoft.com/azure-stack/operator/azure-stack-powershell-install). To download the Azure Stack tools, either clone this repository or [use the repository zip file](https://github.com/Azure/AzureStack-Tools/archive/master.zip).
  - For ASDK: see [post-deployment configuration](https://docs.microsoft.com/azure-stack/asdk/asdk-post-deploy), which covers both the PowerShell for Azure Stack installation and downloading of the Azure Stack tools.
- The registration functions must be run on a machine that has access to the Privileged Endpoint. 
- You must have access to an Azure subscription, and your Azure account must be an Owner of the subscription.
- Open an elevated instance of Powershell ISE (ie: Run as Administrator).

### Import RegisterWithAzure.psm1
To import the RegisterWithAzure.psm1 module, navigate to where the module was downloaded (typically `C:\AzureStack-Tools-master\Registration`) and run the below:
```powershell
Import-Module .\RegisterWithAzure.psm1 -Force -Verbose
```

## Register in a connected environment
In a connected environment, to register with Azure, allow the download of marketplace items, and start reporting usage data to Azure you must be logged in to the correct Azure Powershell context

### Set the correct Azure Powershell Context
```powershell
Login-AzAccount -Subscription '<Your Azure Subscription>' -Environment '<The Azure Environment where subscription was created>'
```

### Complete registration / activation 
Then you must run the below command from RegisterWithAzure.psm1:
```powershell
Set-AzsRegistration -PrivilegedEndpoint "<Computer Name>-ERCS01" -BillingModel PayAsYouUse
```
The process takes between 10 and 15 minutes.

### Registration with usage reporting or marketplace syndication disabled
```powershell
# usage reporting and marketplace syndication are enabled by default, to disable use the below command
# with disabled usage reporting
Set-AzsRegistration -PrivilegedEndpoint "<Computer Name>-ERCS01" -BillingModel PayAsYouUse -UsageReportingEnabled:$false
# with disabled marketplace syndication
Set-AzsRegistration -PrivilegedEndpoint "<Computer Name>-ERCS01" -BillingModel PayAsYouUse -MarketplaceSyndicationEnabled:$false
```

## Change or remove registration in a connected environment

### Remove Registration 
To remove the existing registration resource and disable marketplace syndication and usage data reporting. While running **Remove-AzsRegistration**, you must be signed in to the subscription used during the registration and use values of the `RegistrationName` and `ResourceGroupName` parameters as shown in the administrator portal [Find current registration details](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-registration?pivots=state-connected#verify-azure-stack-hub-registration):
```powershell
Remove-AzsRegistration -PrivilegedEndpoint "<Computer Name>-ERCS01" -RegistrationName '<Registration name from portal>' -ResourceGroupName '<Registration resource group from portal>'
```
[!NOTE] You must be logged in to the same Azure Powershell context that you ran Set-AzsRegistration under. The process takes between 10 and 15 minutes.

### Switch registration to a new subscription
To switch the existing registration to a new subscription or directory, first remove the existing registration ([Remove Registration](#remove-registration)) and then run below cmds:
```powershell
# Set the Azure Powershell context to the appropriate subscription
Set-AzureRmContext -SubscriptionId "<new subscription to register>"
# Register with the new subscription
Set-AzsRegistration -PrivilegedEndpoint "<Computer Name>-ERCS01" -BillingModel PayAsYouUse
```


## Register in a disconnected environment
If you are registering in an internet-disconnected scenario there are a few more steps to complete registration. 
1) Get registration token from Azure Stack
2) Create registration resource in Azure
3) Retrieve activation token from registration resource in Azure
4) Create activation resource in Azure stack

### Get a registration token
You must first retrieve a registration token from the Azure Stack environment
```powershell
# Retrieve a registration token and save it to the TokenOutputFilePath
$TokenOutputFilePath = "<file path where token will be saved>"
Get-AzsRegistrationToken -PrivilegedEndpoint "<Computer Name>-ERCS01" -BillingModel Capacity -AgreementNumber '<EA Agreement Number>' -TokenOutputFilePath $TokenOutputFilepath
```

### Create a registration resource in Azure
You must use the registration token created in the step above and perform the below command on a computer connected to public Azure
[!NOTE] Remember to download and import the RegisterWithAzure.psm1 module before running the below commands
```powershell
# Log in to the correct Azure Powershell context
Login-AzAccount -Subscription '<Your Azure Subscription>' -Environment '<The Azure Environment where subscription was created>'
# Create a registration resource in Azure
Register-AzsEnvironment -RegistrationToken "<Registration token text value>"
```

### Retrieve activation key 
An activation key is required to create an activation resource in Azure Stack. You can retrieve this from the registration resource in Azure.
Run the below command under the same context as the step above:
```powershell
$KeyOutputFilePath = "<file path where key will be saved>"
Get-AzsActivationKey -RegistrationName "<name of registration resource in Azure>" -KeyOutputFilePath $KeyOutputFilePath
```

### Create activation resource in Azure Stack
The activation key created above must be copied to the Azure Stack environment before registration / activation can be complete.
Run the below commands to complete registration in a disconnected environment: 
```powershell
New-AzsActivationResource -PrivilegedEndpoint "<Computer Name>-ERCS01" -ActivationKey "<activation key text value>"
```

Registration and activation is now complete for a disconnected environment. If you need to change or update your registration in a disconnected environment follow the below instructions

## Change or remove registration in a disconnected environment

### Remove activation resource from Azure Stack
You must first remove the activation resource from your Azure Stack
```powershell
Remove-AzsActivationResource -PrivilegedEndpoint "<Computer Name>-ERCS01"
```

### Remove registration resource from Azure
Next you must remove the registration resource from Azure. The below command must be run on a computer with connection to public Azure and be logged in to the correct Azure Powershell context.
You must provide either the registration token or the registration name to the below command:
```powershell
# Use the registration name
UnRegister-AzsEnvironment -RegistrationName "<name of registration resource in Azure>"
# Or use the registration token
UnRegister-AzsEnvironment -RegistrationToken "<original registration token text value>"
```
### Repeat the process for registering in a disconnected environment
Once the above steps are complete you must go through the steps for registering in a disconnected environment but you will need to update parameters on the registration token (if necessary) and ensure
that commands performed on the public Azure connected machine are performed under the new Azure Powershell context.
