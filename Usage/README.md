# PreReqs

As a prerequisite, make sure that you installed the correct PowerShell modules and versions:

```powershell
Install-Module -Name 'AzureRm.Bootstrapper' -Scope CurrentUser
Install-AzureRmProfile -profile '2017-03-09-profile' -Force -Scope CurrentUser
Install-Module -Name AzureStack -RequiredVersion 1.2.9 -Scope CurrentUser
```

Use this script to extract usage data from the AzureStack Usage API's and export it to a CSV file
For more information on Billing and Usage see [here](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-billing-and-chargeback)
