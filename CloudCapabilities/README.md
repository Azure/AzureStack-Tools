# Get Cloud Capabilities
Instructions below are relative to the .\CloudCapabilities folder of the [AzureStack-Tools repo](..).
To get VMImages, Extensions & Sizes available in the cloud, add -IncludeComputeCapabilities
```powershell
Import-Module ".\AzureRM.CloudCapabilities.psm1"
```
# Prerequisites
 Connected Azure or AzureStack powershell environment (Refer [AzureStack-Tools repo/Connect](../Connect) for connecting to an Azure Stack instance. )

```powershell
Get-AzureRMCloudCapabilities -Location '<provide location>' -Verbose #-IncludeComputeCapabilities
```

# Compare Cloud Capabilities

Compare the capabilities in your Azure Stack environment to the capabilities available in public Azure. This can be used the clarify differences in available resource types and API versions for commonly available services.  

```powershell
Import-Module ".\CompareCloudCapabilities.psm1"
```

# Prerequisites
Obtain two Cloud Capability JSON files by leveraging the above Get-CloudCapabilities command. For example, select the Azure Stack TP2 capabilities file and compare it the capabilities file for Azure. 

# Parameters
The 'aPath' parameter should refer to the cloud that has a superset of capability and the 'bPath' the cloud with a subset of capabilities. It is generally good practice to restrict comparison namespaces to those commonly available to both clouds and exclude nested resources as seen in the example below. This makes the comparison more comprehensible.  

```powershell
Compare-CloudCapabilities -aPath ".\AzureCloudCapabilities.Json" -bPath ".\AzureStackCapabilities_TP2.json" -excludeNestedResources -restrictNamespaces
```
