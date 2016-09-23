## Template Validator
		
Test-TemplateCapability [-CapabilitiesPath] <String> [-TemplateDirectory] <String> [-TemplatePattern] <String>  [-OutputPath] <String>
	
Parameter Description
CapabilitiesPath - Full Directory path to the Json that has Azure Stack TP2 capabillities ex: AzureStackCapabilitiesTP2.json
TemplateDirectory - Path to directory containing templates to validate ex: ".\Templates"
TemplatePattern - Pattern to select templates. Performs PowerShell -like comparison over all files contained in TemplateDirectory including subfile paths. ex: "*\azuredeploy.json"
OutputPath	- Output filename with path for the validation output. Supports plain txt, html, and xlsx file extensions

#Usage Instructions
Copy contents to C:\TemplateValidator and run the below script

```powershell
Import-Module ".\TemplateValidator.psm1"
Import-module ".\CapabilityParser.dll"
Test-TemplateCapability -CapabilitiesPath "C:\TemplateValidator\AzureStackCapabilitiesTP2.json" -TemplateDirectory ".\Templates" `
-TemplatePattern "*\azuredeploy.json" -OutputPath ".\TemplateValidationResults.html" -Verbose
```

# To Perform Compute Resource Provider Images and Extensions validation use as below
```powershell
Test-TemplateCapability -CapabilitiesPath "C:\TemplateValidator\AzureStackCapabilitiesTP2.json" -TemplateDirectory ".\Templates" `
-TemplatePattern "*\azuredeploy.json" -OutputPath ".\TemplateValidationResults.html" -ProcessImageExtensions $True -Verbose
```