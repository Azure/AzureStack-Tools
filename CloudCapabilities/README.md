# Get Cloud Capabilities
Instructions below are relative to the .\CloudCapabilities folder of the [AzureStack-Tools repo](..).
To get VMImages, Extensions & Sizes available in the cloud, add -IncludeComputeCapabilities
```powershell
Import-Module ".\GetCloudCapabilities.psm1"
```
# Prerequisites
 Connected Azure or AzureStack powershell environment (Refer [AzureStack-Tools repo/Connect](../Connect) for connecting to an Azure Stack instance. )

```powershell
Get-CloudCapabilities -Location '<provide location>' -Verbose #-IncludeComputeCapabilities
```
