# Get Cloud Capabilities

Instructions below are relative to the .\CloudCapabilities folder of the [AzureStack-Tools-az repo](..).
To get VMImages, Extensions & Sizes available in the cloud, add -IncludeComputeCapabilities
To get StorageSkus available in the cloud, add -IncludeStorageCapabilities

```powershell

Import-Module ".\Az.CloudCapabilities.psm1"
```

## Prerequisites

 Connected Azure or AzureStack powershell environment (Refer [AzureStack-Tools-az repo/Connect](../Connect) for connecting to an Azure Stack instance. )

```powershell
Get-AzCloudCapability -Location '<provide location>' -Verbose #-IncludeComputeCapabilities -IncludeStorageCapabilities
```