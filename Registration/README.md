# Registration

The functions in this module allow you to perform the steps of registering your Azure Stack with your Azure subscription. Additional details can be found in the [documentation](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register).

These functions must be run from the Host machine. As a prerequisite, make sure that you have an Azure subscription and that you have installed the correct version of Azure Powershell as outlined here: [Install Powershell for Azure Stack](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install)

Once you have downloaded this module, to run the functions contained:

```powershell
CD "<path to RegisterWithAzure.psm1>"
Import-Module RegisterWithAzure.psm1
RegisterWithAzure -CloudAdminCredential $cloudAdminCredential -AzureSubscriptionId $AzureSubscriptionId -JeaComputerName $JeaComputerName
```

If you are not logged into an Azure account during your powershell session you will be prompted for your Azure credentials before registration completes.
