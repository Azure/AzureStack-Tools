# Validate Azure ARM Template Capabilities
Instructions below are relative to the .\TemplateValidator folder of the [AzureStack-Tools repo](..).
To Validate Compute Capabilities such as Images, Extensions & Sizes available in the CloudCapabilities.json add -IncludeComputeCapabilities
Notes: 
The following are currently not supported
1. StorageCapabilities(ex:Sku)
2. Nested Templates

```powershell
Import-Module ".\AzureRM.TemplateValidator.psm1"
```
# Prerequisites
Create CloudCapabilities.json by using Get-AzureRMCloudCapabilities tool [AzureStack-Tools repo/CloudCapabilities](../CloudCapabilities). or use the provided sample AzureStackCapabilities_TP2.json in this folder
For Azure/AzureStack quickstart templates, git clone from below links
https://github.com/Azure/AzureStack-QuickStart-Templates/
https://github.com/Azure/Azure-QuickStart-Templates/
# Usage
```powershell
$TemplatePath = "<Provide Template(s) Path>"
$CapabilitiesPath = ".\AzureStackCapabilities_TP2.json"
Test-AzureRMTemplate -TemplatePath $TemplatePath -CapabilitiesPath $CapabilitiesPath -Verbose #-IncludeComputeCapabilities
```