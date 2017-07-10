# Registration

This script must be run from the Host machine. As a prerequisite, make sure that you have an Azure subscription, that you have installed Azure PowerShell, and that you have registered the AzureStack resource provider:

```powershell
Install-Module -Name AzureRM
Register-AzureRmResourceProvider -ProviderNamespace 'microsoft.azurestack'
```

This script helps you to run through the steps of registering your Azure Stack with your Azure subscription. Additional details can be found in the [documentation](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register).

To run the script:

```powershell
RegisterWithAzure.ps1 -azureCredentials YourCredentialObject -azureAccountId YourAccountName -azureSubscriptionId YourSubscriptionGUID -azureDirectoryTenantName YourAADTenantName
```

AzureCredentials are not mandatory, if you do not pass in a credential object you will be prompted for your Azure credentials before continuing. 
