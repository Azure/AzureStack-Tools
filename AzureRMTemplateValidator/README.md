# Validate Azure ARM Template Capabilities
Instructions below are relative to the .\AzureRMTemplateValidator folder of the [AzureStack-Tools repo](..).
To Validate Compute Capabilities such as Images, Extensions & Sizes available in the Capabilities.json add -IncludeComputeCapabilities
Notes: 
The following are currently not supported
1. StorageCapabilities(ex:Sku)
2. Nested Templates

```powershell
Import-Module ".\TestAzureRMTemplate.psm1"
```
# Prerequisites
Create CloudCapabilties.json by using Get-CloudCapabilities tool [AzureStack-Tools repo/CloudCapabilties](../CloudCapabilties). or use the provided sample AzureStackCapabilities_TP2.json in this folder
For Azure/AzureStack quickstart templates, git clone from below links
https://github.com/Azure/AzureStack-QuickStart-Templates/
https://github.com/Azure/Azure-QuickStart-Templates/
# Usage
```powershell
$TemplatePath = "<Provide Template(s) Path>"
$CapabilitiesPath = ".\AzureStackCapabilities_TP2.json"
Test-AzureRMTemplate -TemplatePath $TemplatePath -CapabilitiesPath $CapabilitiesPath -Verbose #-IncludeComputeCapabilities
```