# Get Cloud Capabilities

Instructions below are relative to the .\CloudCapabilities folder of the [AzureStack-Tools repo](..).
To get VMImages, Extensions & Sizes available in the cloud, add -IncludeComputeCapabilities
To get StorageSkus available in the cloud, add -IncludeStorageCapabilities

```powershell

Import-Module ".\AzureRM.CloudCapabilities.psm1"
```

## Prerequisites

 Connected Azure or AzureStack powershell environment (Refer [AzureStack-Tools repo/Connect](../Connect) for connecting to an Azure Stack instance. )

```powershell
Get-AzureRMCloudCapability -Location '<provide location>' -Verbose #-IncludeComputeCapabilities -IncludeStorageCapabilities
```
