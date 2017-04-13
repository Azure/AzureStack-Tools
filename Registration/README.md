This script must be run from the Host machine. As a prerequisite, make sure that you have an Azure subscription and that you have installed Azure PowerShell:

```powershell
Install-Module -Name AzureRM 
```

This script helps you to run through the steps of registering your Azure Stack with your Azure subscription. Additional details can be found in the [documentation](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register). 

To run the script:

```powershell
 RegisterWithAzure.ps1 -azureDirectory YourDirectory -azureSubscriptionId YourGUID -azureSubscriptionOwner YourAccountName
```

You will be prompted for your Azure credentials one more time as well as prompted to click "Enter" twice as the script runs. 
