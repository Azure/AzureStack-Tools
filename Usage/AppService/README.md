# PreReqs

As a prerequisite, Configure and sign in to Azure stack environment. Please refer [here](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-configure-admin#configure-the-operator-environment-and-sign-in-to-azure-stack)

### Get-AppServiceBillingRecords
This sample fetches AppService billing records from Azure Stack usage API. You can also export data to CSV

```powershell
.\Get-AppServiceBillingRecords.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true

.\Get-AppServiceBillingRecords.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true -ExportToCSV $true

.\Get-AppServiceBillingRecords.ps1 -StartTime 01/08/2018 -EndTime 01/24/2018 -Granularity Daily -TenantUsage $false
```

### Get-AppServiceSubscriptionUsage
This sample calculates AppService usage amount  per subscription. This will calculate the usage amount based on the usage data fecthed using Azure stack API and price provided per meter (refer script file).

```powershell
.\Get-AppServiceSubscriptionUsage.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true

.\Get-AppServiceSubscriptionUsage.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true -ExportToCSV $true

.\Get-AppServiceSubscriptionUsage.ps1 -StartTime 01/08/2018 -EndTime 01/24/2018 -Granularity Daily -TenantUsage $false
```

### Suspend-UserSubscriptions
This sample suspends or enables subscription based on usage limit specified (refer script file).

```powershell
.\Suspend-UserSubscriptions.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true

.\Suspend-UserSubscriptions.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true -ExportToCSV $true

.\Suspend-UserSubscriptions.ps1 -StartTime 01/08/2018 -EndTime 01/24/2018 -Granularity Daily -TenantUsage $false
```

### Common.ps1
This file has list of AppService meters defined.

For more information on Azure stack Meter IDs see [here](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-usage-related-faq#what-meter-ids-can-i-see)

For more information on Billing and Usage see [here](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-billing-and-chargeback)

IMPORTANT  : THIS SAMPLE IS PROVIDED AS IS AND ONLY INTENDED FOR REFERENCE PURPOSE.