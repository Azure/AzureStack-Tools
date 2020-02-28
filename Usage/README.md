# PreReqs

As a prerequisite, make sure that you installed the correct PowerShell modules and versions:

For Azure stack 1901 or later

```powershell
Install-Module -Name AzureRM -RequiredVersion 2.4.0
Install-Module -Name AzureStack -RequiredVersion 1.7.0
```

For all other azure stack versions, please follow the instructions at https://aka.ms/azspsh for the needed azure powershell


Use this script to extract usage data from the AzureStack Usage API's and export it to a CSV file
For more information on Billing and Usage see [here](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-billing-and-chargeback)
