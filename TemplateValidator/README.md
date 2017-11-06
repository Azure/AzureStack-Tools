# Validate Azure ARM Template Capabilities

Generate the Cloud capabilities json by Get-AzureRMCloudCapability cmdlet under module .\CloudCapabilities\AzureRM.CloudCapabilities.psm1 based on your environment. You are required to deploy SQL RP, MYSQL RP or AppServices in order to use the respective resources.

Instructions below are relative to the .\TemplateValidator folder of the [AzureStack-Tools repo](..).
To Validate Compute Capabilities such as Images, Extensions & Sizes available in the CloudCapabilities.json add -IncludeComputeCapabilities
To Validate Storage Capabilities such as Skus available in the CloudCapabilities.json add -IncludeStorageCapabilities

```powershell
Import-Module ".\AzureRM.TemplateValidator.psm1"
```

## Prerequisites

Create CloudCapabilities.json by using Get-AzureRMCloudCapabilities tool [AzureStack-Tools repo/CloudCapabilities](../CloudCapabilities). or use the provided sample AzureStackCapabilities_TP3.json in this folder
For Azure/AzureStack quickstart templates, git clone from below links
`https://github.com/Azure/AzureStack-QuickStart-Templates/`
`https://github.com/Azure/Azure-QuickStart-Templates/`

## Usage

```powershell
$TemplatePath = "<Provide Template(s) Path>"
$CapabilitiesPath = ".\AzureStackCapabilities_TP3.json"
Test-AzureRMTemplate -TemplatePath $TemplatePath -CapabilitiesPath $CapabilitiesPath -Verbose #-IncludeComputeCapabilities -IncludeStorageCapabilities
```

## Reporting Usage

Passed - Validation passed. The template has all the Capabilities to deploy on the validated Cloud
NotSupported - The template Capabilities is currently not supported on the validated cloud
Exception - Exception in processing and validating the template
Recommend - The template has all the Capabilities to deploy on the validated Cloud but has recommendations for best practices
Warning - Changes are required either in Template or the validated cloud to deploy succesfully

## TroubleShooting

For "NotSupported" - Refer the region specific capability JSON for the supported capabilities.
For Warnings(in Console Output) such as "No StorageSkus found in region specific Capabilities JSON file.", Please run Get-AzureRMCloudCapabilities with -IncludeComputeCapabilities and -IncludeStorageCapabilities
