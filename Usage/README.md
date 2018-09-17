# PreReqs

As a prerequisite, make sure that you installed the correct PowerShell modules and versions:

```powershell
Install-Module -Name 'AzureRm.Bootstrapper'
Install-AzureRmProfile -profile '2018-03-01-hybrid' -Force
Install-Module -Name AzureStack -RequiredVersion 1.5.0
```

Use this script to extract usage data from the AzureStack Usage API's and export it to a CSV file
For more information on Billing and Usage see [here](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-billing-and-chargeback)
