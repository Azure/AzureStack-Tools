# Copyright (c) Microsoft Corporation. All rights reserved
# See LICENSE.txt in the project root for license information
<#
	SYNOPSIS
	Validate Azure ARM Template Capabilities (ARM resources, Api-version, VM Extensions, VM Images, VMSizes etc) for Azure Stack and Azure
#>
$Global:VerbosePreference = 'SilentlyContinue'
function Test-AzureRMTemplate()
{
	[CmdletBinding()]
	param(
	[Parameter(Mandatory = $true, HelpMessage = "Template directory or TemplateFullPath to Validate")]
	[ValidateScript({ Test-Path -Path $_  })]
	[String] $TemplatePath,
	[Parameter(HelpMessage = "Template Pattern to match.Default is *azuredeploy.json")]
	[String] $TemplatePattern = "*azuredeploy.json",
	[Parameter(Mandatory = $true, HelpMessage = "Cloud Capabilities JSON File Name in the current folder or with full path")]
	[ValidateScript({ Test-Path -Path $_  })]
	[String] $CapabilitiesPath,
	[Parameter(HelpMessage = "Set to process VMImages , VMExtensions & VMSizes")]
	[Switch] $IncludeComputeCapabilities,
	[Parameter(HelpMessage = "Output Report FileName")]
	[String] $Report = "TemplateValidationReport.html"
	)
	$capabilities = ConvertFrom-Json (Get-Content -Path $CapabilitiesPath -Raw) -ErrorAction Stop
	$TemplateDirectory = Get-ChildItem -Path $TemplatePath -Recurse -Include $TemplatePattern
	$reportOutPut = @()
	$totalCount = 0
	$warningCount = 0
	$errorCount = 0
	$successCount = 0
	foreach ($template in $TemplateDirectory)
	{
		$templateName = (Split-path -Path $template.FullName).Split("\")[-1]
		$templateResults = @()
		$templateResults.Clear() 
		Write-Verbose "Template name is $templateName"
		try
		{
			$rootTemplateResult = ValidateTemplate -TemplatePath $template.FullName  -Capabilities $Capabilities -IncludeComputeCapabilities:$IncludeComputeCapabilities
			Write-Verbose "Get nested templates from $templateName"
			[System.Collections.Stack] $nestedTemplates = New-Object System.Collections.Stack
			$rootTemplateResult.Details += ([Environment]::NewLine) + (Get-NestedTemplates $template.FullName $nestedTemplates)
			if ($nestedTemplates.Count)
			{
				$nestedTemplateResults = @()
				$templateValidationStatus = @()
				$templateValidationStatus.Clear()
				$templateValidationStatus += $rootTemplateResult.Status
				while ($nestedTemplates.Count)
				{
					$nestedTemplate = $nestedTemplates.Pop()
					if ($nestedTemplate.DownloadError)
					{
						$nestedTemplateResult = [PSCustomObject]@{
							TemplateName = ""
							Status = "Failed"
							Details = $nestedTemplate.DownloadError
							}
					}
					else
					{
						$nestedTemplateResult = ValidateTemplate -TemplatePath $nestedTemplate.LocalTemplatePath -Capabilities $Capabilities -IncludeComputeCapabilities:$IncludeComputeCapabilities
						Write-Verbose "Get nested templates from $nestedTemplate.TemplateLink"
						$rootTemplateResult.Details += ([Environment]::NewLine) + (Get-NestedTemplates $nestedTemplate.LocalTemplatePath $NestedTemplates)
						Remove-Item $nestedTemplate.LocalTemplatePath
					}
					$nestedTemplateResult.TemplateName = "--  " + $nestedTemplate.TemplateLink
					$nestedTemplateResults += $nestedTemplateResult
					$templateValidationStatus += $nestedTemplateResult.Status
				}
				$templateResults += [PSCustomObject]@{
					TemplateName = $templateName
					Status = "Passed"
					Details = ""
					}
				if ($templateValidationStatus.Contains("Failed"))
				{
					$templateResults[0].Status = "Failed"
				}
				elseif ($templateValidationStatus.Contains("Warning"))
				{
					$templateResults[0].Status = "Warning"
				}
				$rootTemplateResult.TemplateName = "--  azuredeploy.json"
				$templateResults += $rootTemplateResult
				$templateResults += $nestedTemplateResults
			}
			else
			{
				$templateResults += $rootTemplateResult
			}
		}
		catch
		{
			$templateResults += [PSCustomObject]@{
				TemplateName = $templateName
				Status = "Failed"
				Details = "Error: $($_.Exception.Message)"
				}
		}
		finally
		{
			$totalcount++
		}
		if ($templateResults[0].Status -like "Failed")
		{
			$errorCount++
		}
		elseif ($templateResults[0].Status -like "Warning")
		{
			$warningCount++
		}
		else
		{
			$successCount++
		}
		$reportOutPut += $templateResults
	}
	if (([System.IO.FileInfo]$Report).Extension -eq '.csv')
	{
		$reportOutPut | Export-CSV -delimiter ';' -NoTypeInformation -Encoding "unicode" -Path $Report
	}
	elseif (([System.IO.FileInfo]$Report).Extension -eq '.html')
	{
$head = @"
<style>
body { font: verdana}
table { width:100%}
table, th, td {
	border: 1px solid black;
	border-collapse: collapse;
}
th, td {
	padding: 5px;
	text-align: left;
}
th { background-color: LightSlateGrey;
	color: white;
	font-size: large;
}
tr:hover {
background: peachpuff;
}
h1 { font-size:200%; text-align:center;text-decoration: underline;}
.PASS td:nth-child(2){background-color: Lime }
.FAIL td:nth-child(2){background-color: orangered}
.WARN td:nth-child(2){background-color: yellow}
table td:nth-child(2){font-weight: bold;}
table td:nth-child(3){white-space:pre-line}
</style>
"@
		$title = "<H1>Template Validation Report</H1>"
		$validationSummary = "<H3>Template Validation completed on $(Get-Date)<br>
		Success: $successCount<br> 
		Warning: $warningCount<br> 
		Failure: $errorCount<br> 
		Total Templates: $totalCount</H3>"
		[xml] $reportXml = $reportOutPut | ConvertTo-Html -Fragment
		for ($i = 1; $i -le $reportXml.table.tr.count-1; $i++)
		{
			$class =$reportXml.CreateAttribute("class")
			if ($reportXml.table.tr[$i].td[0] -like '--*')
			{
				$style = $reportXml.CreateAttribute("style")
				$style.Value = "background-color: goldenrod"
				$reportXml.table.tr[$i].Attributes.Append($style)| out-null
			}
			if ($reportXml.table.tr[$i].td[1] -eq 'Failed')
			{
				$class.value ="FAIL"
				$reportXml.table.tr[$i].Attributes.Append($class)| out-null
			}
			elseif ($reportXml.table.tr[$i].td[1] -eq 'Passed')
			{
				$class.value ="PASS"
				$reportXml.table.tr[$i].Attributes.Append($class)| out-null
			}
			elseif ($reportXml.table.tr[$i].td[1] -eq 'Warning')
			{
				$class.value ="WARN"
				$reportXml.table.tr[$i].Attributes.Append($class)| out-null
			}
		}
		$reportHtml = $title + $validationSummary + $reportXml.OuterXml|Out-String
		ConvertTo-Html  $postContent -head $head -Body $reportHtml | out-File $Report
	}
}

function Get-NestedTemplates
{
	param(
	[Parameter(Mandatory = $true, HelpMessage = "Path for a template JSON which will be checked for nested templates")]
	[String] $TemplatePath,
	[Parameter(Mandatory = $true, HelpMessage = "Stack containing nested templates")]
	[System.Collections.Stack] $NestedTemplates
	)
	try
	{
		$TemplatePS = ConvertFrom-Json (Get-Content -Path $TemplatePath -Raw)
		foreach ($resource in $TemplatePS.resources)
		{
			if ($resource.type -eq 'Microsoft.Resources/deployments')
			{
				$templateLink = ""
				$err = ""
				$localTemplatePath = ""
				try
				{
					$templateLink = Get-PropertyValue $resource.properties.templateLink.uri $TemplatePS $resource
					Write-Verbose "Download nested template. Template link - $templateLink"
					$localTemplatePath = Join-Path $env:TEMP ("NestedTemplate-{0}.json" -f ([DateTime]::Now).Ticks.ToString())
					Invoke-RestMethod -Method GET -Uri $templateLink -OutFile $localTemplatePath
				}
				catch
				{
					$err = "Unable to get nested template link. Template link - $templateLink. Error: $($_.Exception.Message)"
					Write-Error $err
				}
				$nestedTemplate = [PSCustomObject]@{
						TemplateLink = $templateLink
						LocalTemplatePath = $localTemplatePath
						DownloadError = $err
						}
				$NestedTemplates.Push($nestedTemplate)
			}
		}
	}
	catch
	{
		$err = "Error getting nested templates for $TemplatePath. Error: $($_.Exception.Message)"
		Write-Error $err
		return $err
	}
	return ""
}

function ValidateTemplate
{
	param(
	[Parameter(Mandatory = $true, HelpMessage = "Template JSON Path")]
	[String] $TemplatePath,
	[Parameter(Mandatory = $true, HelpMessage = "Cloud Capabilities Json ")]
	[PSObject] $Capabilities,
	[Parameter(HelpMessage = "Set to process VMImages, VMExtensions and VMSizes")]
	[Switch] $IncludeComputeCapabilities
	)
	$ValidationOutput =[PSCustomObject]@{
		TemplateName = ""
		Status = ""
		Details = ""
		}
	try
	{
		$ValidationOutPut.TemplateName = (Split-path -Path $template.FullName).Split("\")[-1]
		$TemplatePS = ConvertFrom-Json (Get-Content -Path $TemplatePath -Raw)
		$ErrorList = @()
		foreach ($templateResource in $TemplatePS.resources)
		{
			$ErrorList += ValidateResource $templateResource $TemplatePS
			foreach ($nestedResource in $templateResource.resources)
			{
				$ErrorList += ValidateResource $nestedResource $TemplatePS
			}
		}
		Write-Verbose "Validating the Storage Endpoint"
		$hardCodedStorageURI =  (Get-Content $TemplatePath) | Select-String -Pattern "`'.blob.core.windows.net`'" | Select LineNumber, Line | Out-string
		if ($hardCodedStorageURI)
		{
			Write-Error "Storage Endpoint has a hardcoded URI. This endpoint will not resolve correctly outside of public Azure. It is recommended that you instead use a reference function to derive the correct Storage Endpoint $hardCodedStorageURI"
			$ErrorList  += "Error: Storage Endpoint has a hardcoded URI. This endpoint will not resolve correctly outside of public Azure. It is recommended that you instead use a reference function to derive the correct Storage Endpoint $hardCodedStorageURI"
		}
		if (-not $ErrorList)
		{
			$ValidationOutput.Status = "Passed"
		}
		else
		{
			if ($ErrorList | Select-String -pattern 'Error')
			{
				$ValidationOutput.Status = "Failed"
			}
			else
			{
				$ValidationOutput.Status = "Warning"
			}
		}
		$ValidationOutPut.Details = $ErrorList | out-string
	}
	catch
	{
		$ValidationOutput.Status = "Failed"
		$ValidationOutPut.Details = "Error: $($_.Exception.Message)"
	}
	return $ValidationOutput
}

function ExecuteTemplateFunction
{
	param(
	[string] $Property,
	[PSCustomObject] $TemplateJSON,
	[PSCustomObject] $Resource
	)
	if ($Property.StartsWith("[") -and $Property.EndsWith("]"))
	{
		$Property = $Property.Remove(0,1).Trim()
		$Property = $Property.Remove($Property.Length-1, 1).Trim()
	}
	$Property = $Property.Trim()
	$propertyValue = ""
	if ($Property.StartsWith("concat(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		foreach ($functionParam in $functionParams)
		{
			$PropertyValue += ExecuteTemplateFunction $functionParam $TemplateJSON $Resource
		}
	}
	elseif ($Property.StartsWith("length(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$propertyValue = ExecuteTemplateFunction $Property $TemplateJSON $Resource
		$propertyValue = $propertyValue.Length
	}
	elseif ($Property.StartsWith("padleft(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		$propertyValue = $propertyValue.PadLeft($functionParams[1], $functionParams[2]) 
	}
	elseif ($Property.StartsWith("replace(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		$propertyValue = $propertyValue.Replace($functionParams[1], $functionParams[2])
	}
	elseif ($Property.StartsWith("skip(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		if ($functionParams[1] -gt $propertyValue.Length)
		{
			$propertyValue = ""
		}
		elseif (-not ($functionParams[1] -le 0))
		{
			$propertyValue = $propertyValue.Replace($functionParams[1]) 
		}
	}
	elseif ($Property.StartsWith("split(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		$propertyValue = $propertyValue.Split($functionParams[1])
	}
	elseif ($Property.StartsWith("string(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		[string] $convertedPropertyValue = $propertyValue
		$propertyValue = $convertedPropertyValue
	}
	elseif ($Property.StartsWith("substring(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		$propertyValue = $propertyValue.Substring($functionParams[1], $functionParams[2])
	}
	elseif ($Property.StartsWith("take(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		if ($functionParams[1] -le 0)
		{
			$propertyValue = ""
		}
		elseif (-not ($functionParams[1] -gt $propertyValue.Length))
		{
			$propertyValue = $propertyValue.Substring(0, $functionParams[1]) 
		}
	}
	elseif ($Property.StartsWith("tolower(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		$propertyValue = $propertyValue.ToLower()
	}
	elseif ($Property.StartsWith("toupper(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		$propertyValue = $propertyValue.ToUpper()
	}
	elseif ($Property.StartsWith("trim(", 'CurrentCultureIgnoreCase'))
	{
		$Property = TrimFunctionName $Property
		$functionParams = GetFunctionParams $Property ","
		$propertyValue = ExecuteTemplateFunction $functionParams[0] $TemplateJSON $Resource
		$propertyValue = $propertyValue.Trim()
	}
	elseif ($Property.StartsWith("parameters(", 'CurrentCultureIgnoreCase'))
	{
		$functionParams = GetFunctionParams $Property "."
		$parameterKey = $functionParams[0]
		$parameterKey = TrimFunctionName $parameterKey
		$parameterKey = ExecuteTemplateFunction $parameterKey $TemplateJSON $Resource
		$parameterValue = $TemplateJSON.parameters.$parameterKey.defaultValue
		if (-not $parameterValue)
		{
			throw "Parameter: $parameterKey - No defaultvalue set"
		}
		else
		{
			$parameterValueType = GetPropertyType $parameterValue
			if ($parameterValueType -eq "function")
			{
				$propertyValue = ExecuteTemplateFunction $parameterValue $TemplateJSON $Resource
			}
			else
			{
				$propertyValue = $parameterValue
			}
		}
		for($indx = 1; $indx -lt $functionParams.Count; $indx++)
		{
			$functionParamValue = ExecuteTemplateFunction $functionParams[$indx] $TemplateJSON $Resource
			$propertyValue = ExecuteTemplateFunction $propertyValue.($functionParamValue) $TemplateJSON $Resource
		}
	}
	elseif ($Property.StartsWith("variables(", 'CurrentCultureIgnoreCase'))
	{
		$functionParams = @($Property)
		$functionParams = GetFunctionParams $Property @(".", "[")
		$variableKey = $functionParams[0]
		$variableKey = TrimFunctionName $variableKey
		$variableKey = ExecuteTemplateFunction $variableKey $TemplateJSON $Resource
		$variableValue = $TemplateJSON.variables.$variableKey
		$variableValueType = GetPropertyType $variableValue
		if ($variableValueType -eq "function")
		{
			$propertyValue = ExecuteTemplateFunction $variableValue $TemplateJSON $Resource
		}
		else
		{
			$propertyValue = $variableValue
		}
		for($indx = 1; $indx -lt $functionParams.Count; $indx++)
		{
			if ($functionParams[$indx].EndsWith("]"))
			{
				$functionParams[$indx] = $functionParams[$indx].Remove($functionParams[$indx].Length-1, 1).Trim()
			}
			$functionParamValue = ExecuteTemplateFunction $functionParams[$indx] $TemplateJSON $Resource
			$propertyValueType = GetPropertyType $propertyValue
			if ($propertyValueType -eq "array")
			{
				$propertyValue = $propertyValue[$functionParamValue]
			}
			else
			{
				$propertyValue = $propertyValue.($functionParamValue)
			}
		}
	}
	elseif ($Property.StartsWith("'") -and $Property.EndsWith("'"))
	{
		return $Property.TrimStart("'").TrimEnd("'").Trim()
	}
	else
	{
		return $Property
	}
	$propertyType = GetPropertyType $propertyValue
	if ($propertyType -eq "function")
	{
		$propertyValue = ExecuteTemplateFunction $propertyValue $TemplateJSON $Resource
	}
	return $propertyValue
}

function TrimFunctionName
{
	param(
	[string] $FunctionName
	)
	$FunctionName = $FunctionName.Remove(0, $FunctionName.IndexOf("(")+1).Trim()
	$FunctionName = $FunctionName.Remove($FunctionName.Length-1, 1).Trim()
	return $FunctionName
}

function GetFunctionParams
{
	param(
	[PSCustomObject] $Property,
	$seperator
	)
	[PSCustomObject] $functionParams = @()
	$functionParam = ""
	$openingBrackets = 0
	$closingBrackets = 0
	$propertyLength = $Property.Length
	$indx = 0
	while($true)
	{
		if ($indx -eq $propertyLength)
		{
			$functionParams += $functionParam
			return , $functionParams
		}
		elseif (($Property[$indx] -in $seperator) -and ($openingBrackets -eq $closingBrackets))
		{
			$functionParams += $functionParam
			$functionParam = ""
			$openingBrackets = 0
			$closingBrackets = 0
		}
		else
		{
			$functionParam += $Property[$indx]
			if ($Property[$indx] -eq "(")
			{
				$openingBrackets++
			}
			elseif ($Property[$indx] -eq ")")
			{
				$closingBrackets++
			}
		}
		$indx++
	}
}

function GetPropertyType
{
	param(
	[PSCustomObject] $Property
	)
	$propertyType = $Property.GetType().Name
	$propertyBaseType = $Property.GetType().BaseType.Name
	if ($propertyBaseType -eq "ValueType")
	{
		return "literal"
	}
	elseif ($propertyBaseType -eq "Object")
	{
		if ($propertyType -eq "String")
		{
			if ($Property.StartsWith("[") -and $Property.EndsWith("]"))
			{
				return "function"
			}
			else
			{
				return "literal"
			}
		}
		elseif ($propertyType -eq "PSCustomObject")
		{
			return "object"
		}
	}
	elseif ($propertyBaseType -eq "Array" -and $propertyType -eq "Object[]")
	{
		return "array"
	}
}

function Get-PropertyValue
{
	param(
	[PSCustomObject] $Property,
	[PSCustomObject] $Template,
	[PSCustomObject] $Resource,
	[Parameter(Mandatory=$false)]
	[string] $Key
	)
	if (-not $Property)
	{
		throw "Property is null or empty"
	}
	$propertyType = GetPropertyType $Property
	if ($propertyType -eq "function")
	{
		$Property = ExecuteTemplateFunction $Property $Template $Resource
		$propertyType = GetPropertyType $Property
	}
	if ($propertyType -eq "object")
	{
		$Property = ExecuteTemplateFunction $Property.($Key) $Template $Resource
	}
	return $Property
}

function CompareValues
{
	param(
	[PSCustomObject] $ProvidedValue,
	[PSCustomObject] $SupportedValue
	)
	if (-not $ProvidedValue -or -not $SupportedValue)
	{
		return $false
	}
	$result = Compare-Object $ProvidedValue $SupportedValue
	if ($result)
	{
		$result = $result | ? { $_.SideIndicator -eq "<="}
	}
	return ($result -eq $null)
}

function ValidateResource
{
	param(
	[PSObject] $resource,
	[PSCustomObject] $Template
	)
	$ResourceProviderNameSpace = $resource.type.Split("/")[0]
	$ResourceTypeName = $resource.type.Substring($resource.type.indexOf('/')+1)    
	$ResourceTypeProperties = $capabilities.resources | Where-Object { $_.providerNameSpace -eq $ResourceProviderNameSpace } | Where-Object { $_.ResourcetypeName -eq $ResourceTypeName }
	$resourceOutput = @()
	Write-Verbose "Validating ProviderNameSpace and ResourceType"
	if (-not $ResourceTypeProperties)
	{
		Write-Error "Resource type $($resource.type) is currently not supported."
		$resourceOutput += "Error:Resource type $($resource.type) is currently not supported."
	}
	else
	{
		Write-Verbose "Validating API version for $ResourceProviderNameSpace\$ResourceTypeName"
		try
		{
			$templateResApiversion = $resource.apiversion
			$templateResApiversionType = GetPropertyType $templateResApiversion
			if ($templateResApiversionType -eq "function")
			{
				$resourceOutput += "Warning:For apiVersion ($templateResApiversion), it is recommended to set a literal value."
			}
			$templateResApiversion = Get-PropertyValue $templateResApiversion $Template $resource
			$supportedApiVersions = $ResourceTypeProperties.Apiversions
			$supported = CompareValues $templateResApiversion $supportedApiVersions
			if ($supported)
			{
				Write-Verbose "Resource type $($resource.type) apiversion:$templateResApiversion. Supported Values are $supportedApiVersions"
			}
			else
			{
				Write-Error  "Resource type $($resource.type) apiversion: $templateResApiversion. Supported Values are $supportedApiVersions"
				$resourceOutput += "Error:Resource type $($resource.type) apiversion: $templateResApiversion. Supported Values are $supportedApiVersions"
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
			$resourceOutput += "Error: Resource apiVersion: $($_.Exception.Message)"
		}
		Write-Verbose "Validating Location info for $ResourceProviderNameSpace\$ResourceTypeName"
		if ($resource.type -ne 'Microsoft.Resources/deployments')
		{
			try
			{
				$locationToCheck = Get-PropertyValue $resource.location $Template $resource
				$supportedLocations = $ResourceTypeProperties.Locations
				$supported = CompareValues $locationToCheck $supportedLocations
				if ((-not $supported) -and ($locationToCheck -notlike "*resourceGroup().location*"))
				{
					Write-Error "Resource type $($resource.type) targets $locationToCheck location. Supported Values are 'resourceGroup().location' or $supportedLocations"
					$resourceOutput += "Error:Resource type $($resource.type) targets $locationToCheck location. Supported Values are 'resourceGroup().location' or $supportedLocations"
				}
				elseif (($supported) -and ($locationToCheck -notlike "*resourceGroup().location*"))
				{
					$resourceOutput += "Warning:For Resource type $($resource.type), it is recommended to set location as resourceGroup().location"
				}
			}
			catch
			{
				Write-Error $_.Exception.Message
				$resourceOutput += "Error: Resource location: $($_.Exception.Message)"
			}
		}
		Write-Verbose "Process VMImages"
		if ($IncludeComputeCapabilities)
		{
			if ($ResourceTypeName -Like '*extensions')
			{
				Write-Verbose "Validating VMExtension $ResourceProviderNameSpace/$ResourceTypeName"
				if (-not $capabilities.VMExtensions)
				{
					Write-Warning "No VMExtensions found in Capabilities.json. Run Get-AzureRMCloudCapabilities with -IncludeComputeCapabilities"
				}
				else
				{
					try
					{
						$templateextPublisher = Get-PropertyValue $resource.properties.publisher $Template $resource
						$templateextType = Get-PropertyValue $resource.properties.type $Template $resource
						$templateextVersion = Get-PropertyValue $resource.properties.typeHandlerVersion $Template $resource
						$supportedPublisher = $capabilities.VMExtensions | Where-Object { $_.publisher -eq $templateextPublisher }
						if (-not $supportedPublisher)
						{
							Write-Error "VMExtension publisher: $templateextPublisher currently not supported. Refer to Capabilities.json for supported VMExtension publishers"
							$resourceOutput += "Error: VMExtension publisher: $templateextPublisher currently not supported. Refer to Capabilities.json for supported VMExtension publishers"
						}
						else
						{
							$supportedType = $supportedPublisher.types| Where-Object { $_.type -eq $templateextType }
							if (-not $supportedType)
							{
								Write-Error "VMExtension type: $templateextType is currently not supported"
								$resourceOutput += "Error: VMExtension type: $templateextType is currently not supported "
							}
							else
							{
								$supportedVersions = @()
								foreach ($ver in $supportedType.versions)
								{
									$supportedVersions +=[version]$ver 
								}
								if ($templateextVersion -notin $supportedVersions)
								{
									if ($templateextVersion.Split(".").Count -eq 2) {$templateextVersion = $templateextVersion + ".0.0" }
									$v = [version]$templateextVersion
									if ($v -notin $supportedVersions)
									{
										$autoupgradeSupported = $supportedVersions| Where-Object { ($_.Major -eq $v.Major) -and ($_.Minor -gt $v.Minor) }
										if ($autoupgradeSupported)
										{
											if ((-not $resource.properties.autoupgrademinorversion) -or ($resource.properties.autoupgrademinorversion -eq $false))
											{
												Write-warning "Warning: Exact Match for VMExtension version: $templateextVersion not found in $supportedVersions. It is recommended to set autoupgrademinorversion property to true"
												$resourceOutput += "Warning: Exact Match for VMExtension version: $templateextVersion not found in $supportedVersions. It is recommended to set autoupgrademinorversion property to true"
											}
										}
										else
										{
											Write-Error "VMExtension version: $templateextVersion not found in $supportedVersions"
											$resourceOutput += "Error:VMExtension version: $templateextVersion not found in $supportedVersions"
										}
									}
								}
							}
						}
					}
					catch
					{
						Write-Error $_.Exception.Message
						$resourceOutput += "Error: Resource VMExtension: $($_.Exception.Message)"
					}
				}
			}
			if ($resource.type -eq "Microsoft.Compute/virtualMachines")
			{
				Write-Verbose "Validating VMImages"
				if ($resource.properties.storageprofile.imagereference)
				{
					if (-not $capabilities.VMImages)
					{
						Write-Warning "No VMImages found in Capabilities.json. Run Get-AzureRMCloudCapabilities with -IncludeComputeCapabilities"
					}
					else
					{
						try
						{
							$templateImagePublisher = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "publisher"
							$supportedPublisher = $capabilities.VMImages | Where-Object { $_.publisherName -eq $templateImagePublisher }
							if (-not $supportedPublisher)
							{
								Write-Error "VMImage publisher: $templateImagePublisher currently not supported. Refer to Capabilities.json for supported VMImages publishers"
								$resourceOutput += "Error: VMImage publisher: $templateImagePublisher currently not supported. Refer to Capabilities.json for supported VMImages publishers"
							}
							else
							{
								try
								{
									$templateImageOffer = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "offer"
									$supportedOffer = $supportedPublisher.Offers | Where-Object { $_.offerName -eq $templateImageOffer }
									if (-not $supportedOffer)
									{
										Write-Error "VMImage Offer: $templateImageOffer currently not supported. Refer to Capabilities.json for supported VMImages Offers"
										$resourceOutput += "Error: VMImage Offer: $templateImageOffer currently not supported. Refer to Capabilities.json for supported VMImages Offers"
									}
									else
									{
										try
										{
											$templateImagesku = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "sku"
											$supportedSku = $supportedOffer.skus | where { $_.skuName -eq $templateImagesku}
											if (-not $supportedSku)
											{
												Write-Error "VMImage SKu: $templateImageSku currently not supported. Refer to Capabilities.json for supported VMImages Skus"
												$resourceOutput += "Error:VMImage SKu: $templateImageSku currently not supported. Refer to Capabilities.json for supported VMImages Skus"
											}
											else
											{
												try
												{
													$templateImageskuVersion = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "version"
													$supported = CompareValues $templateImageskuVersion $supportedSku.versions
													if (($templateImageskuVersion -ne "latest") -and (-not $supported)) 
													{
														Write-Error "VMImage SKu version: $templateImageskuVersion currently not supported. Set to latest or Refer to Capabilities.json for supported VMImages Skus version "
														$resourceOutput += "Error: VMImage SKu version: $templateImageskuVersion currently not supported. Set to latest or Refer to Capabilities.json for supported VMImages Skus version"
													}
													elseif (($templateImageskuVersion -ne "latest") -and ($supported)) 
													{
														Write-Error "Warning: It is recommended to set storageprofile.imagereference.version to 'latest'"
														$resourceOutput += "Warning: It is recommended to set storageprofile.imagereference.version to 'latest'"
													}
												}
												catch
												{
													Write-Error $_.Exception.Message
													$resourceOutput += "Error: Resource ImageSkuVersion $($_.Exception.Message)"
												}
											}
										}
										catch
										{
											Write-Error $_.Exception.Message
											$resourceOutput += "Error: Resource ImageSku $($_.Exception.Message)"
										}
									}
								}
								catch
								{
									Write-Error $_.Exception.Message
									$resourceOutput += "Error: Resource ImageOffer $($_.Exception.Message)"
								}
							}
						}
						catch
						{
							Write-Error $_.Exception.Message
							$resourceOutput += "Error: Resource ImagePublisher $($_.Exception.Message)"
						}
					}
				}
				if (-not $capabilities.VMSizes)
				{
					Write-Warning "No VMSizes found in Capabilities.json. Run Get-AzureRMCloudCapabilities with -IncludeComputeCapabilities"
				}
				else
				{
					try
					{
						$templateVMSize = Get-PropertyValue $resource.properties.hardwareprofile $Template $resource "vmSize"
						$supported = CompareValues $templateVMSize $capabilities.VMSizes
						if (-not $supported)
						{
							Write-Error "VMSize: $templateVMSize currently not supported. Refer to Capabilities.json for supported VMSizes"
							$resourceOutput += "Error:VMSize: $templateVMSize currently not supported. Refer to Capabilities.json for supported VMSizes"
						}
					}
					catch
					{
						Write-Error $_.Exception.Message
						$resourceOutput += "Error: Resource VMSize $($_.Exception.Message)"
					}
				}
			}
		}
	}
	return $resourceOutput
}