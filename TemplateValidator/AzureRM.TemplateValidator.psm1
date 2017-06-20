# Copyright (c) Microsoft Corporation. All rights reserved
# See LICENSE.txt in the project root for license information
<#
	SYNOPSIS
	Validate Azure ARM Template Capabilities (ARM resources, Api-version, VM Extensions, VM Images, VMSizes, Storage SKU's etc) for Azure Stack and Azure
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
	[Parameter(HelpMessage = "Set to process Storage Skus")]
	[Switch] $IncludeStorageCapabilities,
	[Parameter(HelpMessage = "Output Report FileName")]
	[String] $Report = "TemplateValidationReport.html"
	)
	$capabilities = ConvertFrom-Json (Get-Content -Path $CapabilitiesPath -Raw) -ErrorAction Stop
	$TemplateDirectory = Get-ChildItem -Path $TemplatePath -Recurse -Include $TemplatePattern
	$reportOutPut = @()
	$totalCount = 0
	$warningCount = 0
	$notSupportedCount = 0
	$exceptionCount = 0
	$passedCount = 0
	$recommendCount = 0
	foreach ($template in $TemplateDirectory)
	{
		$templateName = (Split-path -Path $template.FullName).Split("\")[-1]
		$templateResults = @()
		$templateResults.Clear() 
		Write-Verbose "Template name is $templateName"
		try
		{
			$rootTemplateResult = ValidateTemplate -TemplatePath $template.FullName  -Capabilities $Capabilities -IncludeComputeCapabilities:$IncludeComputeCapabilities -IncludeStorageCapabilities:$IncludeStorageCapabilities
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
							Status = "Exception"
							Details = $nestedTemplate.DownloadError
							}
					}
					else
					{
						$nestedTemplateResult = ValidateTemplate -TemplatePath $nestedTemplate.LocalTemplatePath -Capabilities $Capabilities -IncludeComputeCapabilities:$IncludeComputeCapabilities -IncludeStorageCapabilities:$IncludeStorageCapabilities
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
				if ($templateValidationStatus.Contains("NotSupported"))
				{
					$templateResults[0].Status = "NotSupported"
				}
				elseif ($templateValidationStatus.Contains("Exception"))
				{
					$templateResults[0].Status = "Exception"
				}
				elseif ($templateValidationStatus.Contains("Warning"))
				{
					$templateResults[0].Status = "Warning"
				}
				elseif ($templateValidationStatus.Contains("Recommend"))
				{
					$templateResults[0].Status = "Recommend"
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
				Status = "Exception"
				Details = "Exception: $($_.Exception.Message)"
				}
		}
		finally
		{
			$totalcount++
		}
		if ($templateResults[0].Status -like "NotSupported")
		{
			$notSupportedCount++
		}
		elseif ($templateResults[0].Status -like "Exception")
		{
			$exceptionCount++
		}
		elseif ($templateResults[0].Status -like "Warning")
		{
			$warningCount++
		}
		elseif ($templateResults[0].Status -like "Recommend")
		{
			$recommendCount++
		}
		else
		{
			$passedCount++
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
.NOTSUPPORTED td:nth-child(2){background-color: orangered}
.EXCEPTION td:nth-child(2){background-color: gray}
.WARN td:nth-child(2){background-color: yellow}
.RECOMMEND td:nth-child(2){background-color: Orange}
table td:nth-child(2){font-weight: bold;}
table td:nth-child(3){white-space:pre-line}
</style>
"@
		$title = "<H1>Template Validation Report</H1>"
		$validationSummary = "<H3>Template Validation completed on $(Get-Date)<br>
		Passed: $passedCount<br>
		NotSupported: $notSupportedCount<br>
		Exception: $exceptionCount<br>
		Warning: $warningCount<br>		
		Recommend: $recommendCount<br>
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
			if ($reportXml.table.tr[$i].td[1] -eq 'Passed')
			{
				$class.value ="PASS"
				$reportXml.table.tr[$i].Attributes.Append($class)| out-null
			}
			elseif ($reportXml.table.tr[$i].td[1] -eq 'NotSupported')
			{
				$class.value ="NOTSUPPORTED"
				$reportXml.table.tr[$i].Attributes.Append($class)| out-null
			}
			elseif ($reportXml.table.tr[$i].td[1] -eq 'Exception')
			{
				$class.value ="EXCEPTION"
				$reportXml.table.tr[$i].Attributes.Append($class)| out-null
			}
			elseif ($reportXml.table.tr[$i].td[1] -eq 'Warning')
			{
				$class.value ="WARN"
				$reportXml.table.tr[$i].Attributes.Append($class)| out-null
			}
			elseif ($reportXml.table.tr[$i].td[1] -eq 'Recommend')
			{
				$class.value ="RECOMMEND"
				$reportXml.table.tr[$i].Attributes.Append($class)| out-null
			}
		}
		$reportHtml = $title + $validationSummary + $reportXml.OuterXml|Out-String
		ConvertTo-Html  $postContent -head $head -Body $reportHtml | out-File $Report
	}
	$reportFilePath = Join-Path $PSScriptRoot $Report
	Write-Output "Validation Summary:
	`Passed: $passedCount
	`NotSupported: $notSupportedCount
	`Exception: $exceptionCount
	`Warning: $warningCount
	`Recommend: $recommendCount
	`Total Templates: $totalCount"
	Write-Output "Report available at - $reportFilePath"
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
					$err = "Exception: Unable to get nested template link. Template link - $templateLink. $($_.Exception.Message)"
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
		$err = "Exception: Unable to get nested templates for $TemplatePath. $($_.Exception.Message)"
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
	[Switch] $IncludeComputeCapabilities,
	[Parameter(HelpMessage = "Set to process Storage Skus")]
	[Switch] $IncludeStorageCapabilities
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
			$ErrorList += ValidateResource $templateResource $TemplatePS $Capabilities -IncludeComputeCapabilities:$IncludeComputeCapabilities -IncludeStorageCapabilities:$IncludeStorageCapabilities
			foreach ($nestedResource in $templateResource.resources)
			{
				$ErrorList += ValidateResource $nestedResource $TemplatePS $Capabilities -IncludeComputeCapabilities:$IncludeComputeCapabilities -IncludeStorageCapabilities:$IncludeStorageCapabilities
			}
		}
		Write-Verbose "Validating the Storage Endpoint"
		$hardCodedStorageURI =  (Get-Content $TemplatePath) | Select-String -Pattern "`'.blob.core.windows.net`'" | Select LineNumber, Line | Out-string
		if ($hardCodedStorageURI)
		{
			Write-Warning "Warning: Storage Endpoint has a hardcoded URI. This endpoint will not resolve correctly outside of public Azure. It is recommended that you instead use a reference function to derive the correct Storage Endpoint $hardCodedStorageURI"
			$ErrorList  += "Warning: Storage Endpoint has a hardcoded URI. This endpoint will not resolve correctly outside of public Azure. It is recommended that you instead use a reference function to derive the correct Storage Endpoint $hardCodedStorageURI"
		}
		if (-not $ErrorList)
		{
			$ValidationOutput.Status = "Passed"
		}
		else
		{
			if ($ErrorList | Select-String -pattern 'NotSupported')
			{
				$ValidationOutput.Status = "NotSupported"
			}
			elseif ($ErrorList | Select-String -pattern 'Exception')
			{
				$ValidationOutput.Status = "Exception"
			}
			elseif ($ErrorList | Select-String -pattern 'Warning') 
			{
				$ValidationOutput.Status = "Warning"
			}
			elseif ($ErrorList | Select-String -pattern 'Recommend')
			{
				$ValidationOutput.Status = "Recommend"
			}
		}
		$ValidationOutPut.Details = $ErrorList | out-string
	}
	catch
	{
		$ValidationOutput.Status = "Exception"
		$ValidationOutPut.Details = "Exception: $($_.Exception.Message)"
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
			$funRetVal = ExecuteTemplateFunction $functionParam $TemplateJSON $Resource
			$propertyValueType = GetPropertyType $funRetVal
			if ($propertyValueType -eq "array")
			{
				$propertyValue += $funRetVal[0]
			}
			else
			{
				$PropertyValue += $funRetVal
			}
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
			$parameterValue = $TemplateJSON.parameters.$parameterKey.allowedValues
			if (-not $parameterValue)
			{
				throw "Parameter: $parameterKey - No defaultvalue or allowedValues set"
			}
		}
		$parameterValueType = GetPropertyType $parameterValue
		if ($parameterValueType -eq "function")
		{
			$propertyValue = ExecuteTemplateFunction $parameterValue $TemplateJSON $Resource
		}
		else
		{
			$propertyValue = $parameterValue
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
		$variableKeyType = GetPropertyType $variableKey
		if ($variableKeyType -eq "array")
		{
			$variableKey = $variableKey[0]
		}
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
			$functionParamValueType = GetPropertyType $functionParamValue
			if ($functionParamValueType -eq "array")
			{
				$functionParamValue = $functionParamValue[0]
			}
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
		if (($result -and $ProvidedValue.GetType().Name -eq "Object[]" -and $result.Count -eq $ProvidedValue.Count) -or ($result -and $ProvidedValue.GetType().Name -eq "String"))
		{
			$result = [PSCustomObject]@{
							NoneSupported = $true
							NotSupportedValues = $result.InputObject
							}
		}
		elseif($result)
		{
			$result = [PSCustomObject]@{
							NoneSupported = $false
							NotSupportedValues = $result.InputObject
							}
		}
	}
	return $result
}

function ValidateResource
{
	param(
		[ValidateNotNullOrEmpty()]
		[PSObject] $resource,
		[ValidateNotNullOrEmpty()]
		[PSCustomObject] $Template,
		[ValidateNotNullOrEmpty()]
		[PSObject] $Capabilities,
		[Switch] $IncludeComputeCapabilities,
		[Switch] $IncludeStorageCapabilities
	)
	$ResourceProviderNameSpace = $resource.type.Split("/")[0]
	$ResourceTypeName = ""
	if ($resource.type.Contains('/'))
	{
		$ResourceTypeName = $resource.type.Substring($resource.type.indexOf('/') + 1)
	}
	$ResourceTypeProperties = $capabilities.resources | Where-Object { $_.providerNameSpace -eq $ResourceProviderNameSpace } | Where-Object { $_.ResourcetypeName -eq $ResourceTypeName }
	$resourceOutput = @()
	Write-Verbose "Validating ProviderNameSpace and ResourceType"
	if (-not $ResourceTypeProperties)
	{
		$msg = "NotSupported: Resource type '$($resource.type)'"
		Write-Error $msg
		$resourceOutput += $msg
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
				$msg = "Recommend: apiVersion (Resource type: $($resource.type)). It is recommended to set it as a literal value."
				Write-Warning $msg
				$resourceOutput += $msg
			}
			$templateResApiversion = Get-PropertyValue $templateResApiversion $Template $resource
			$supportedApiVersions = $ResourceTypeProperties.Apiversions
			$notSupported = CompareValues $templateResApiversion $supportedApiVersions
			if ($notSupported)
			{
				if ($notSupported.NoneSupported)
				{
					$msg = "NotSupported: apiversion (Resource type: $($resource.type)). Not Supported Values - $($notSupported.NotSupportedValues)"
				}
				else
				{
					$msg = "Warning: apiversion (Resource type: $($resource.type)). Not Supported Values - $($notSupported.NotSupportedValues)"
				}
				Write-Warning $msg
				$resourceOutput += $msg
			}
		}
		catch
		{
			$msg = "Exception: apiVersion. $($_.Exception.Message)"
			Write-Error $msg
			$resourceOutput += $msg
		}
		Write-Verbose "Validating Location info for $ResourceProviderNameSpace\$ResourceTypeName"
		try
		{
			if(-not $resource.location)
			{
				Write-Warning "Location property is not required or has not been set for $ResourceProviderNameSpace\$ResourceTypeName."
			}
			else
			{
				$locationToCheck = Get-PropertyValue $resource.location $Template $resource
				$supportedLocations = $ResourceTypeProperties.Locations
				$notSupported = CompareValues $locationToCheck $supportedLocations
				if (($notSupported) -and ($locationToCheck -notlike "*resourceGroup().location*"))
				{
					if ($notSupported.NoneSupported)
					{
						$msg = "NotSupported: Location (Resource type: $($resource.type)). Not supported values - $($notSupported.NotSupportedValues). It is recommended to set it as resourceGroup().location."
					}
					else
					{
						$msg = "Warning: Location (Resource type: $($resource.type)). Not supported values - $($notSupported.NotSupportedValues). It is recommended to set it as resourceGroup().location."
					}
					Write-Warning $msg
					$resourceOutput += $msg
				}
				elseif ((-not $notSupported) -and ($locationToCheck -notlike "*resourceGroup().location*"))
				{
					$msg = "Recommend: Location (Resource type: $($resource.type)). It is recommended to set it as resourceGroup().location."
					Write-Warning $msg
					$resourceOutput += $msg
				}
			}
		}
		catch
		{
			$msg = "Exception: Location (Resource type: $($resource.type)). $($_.Exception.Message)"
			Write-Error $msg
			$resourceOutput += $msg
		}
		Write-Verbose "Process VMImages"
		if ($IncludeComputeCapabilities)
		{
			if ($ResourceTypeName -Like '*extensions')
			{
				Write-Verbose "Validating VMExtension $ResourceProviderNameSpace/$ResourceTypeName"
				if (-not $capabilities.VMExtensions)
				{
					Write-Warning "Warning: No VMExtensions found in Capabilities json file. Run Get-AzureRMCloudCapabilities with -IncludeComputeCapabilities"
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
							$msg = "NotSupported: VMExtension publisher '$templateextPublisher'"
							Write-Warning $msg
							$resourceOutput += $msg
						}
						else
						{
							$supportedType = $supportedPublisher.types| Where-Object { $_.type -eq $templateextType }
							if (-not $supportedType)
							{
								$msg = "NotSupported: VMExtension type '$templateextPublisher\$templateextType'"
								Write-Error $msg
								$resourceOutput += $msg
							}
							else
							{
								$supportedVersions = $supportedType.versions
								if ($templateextVersion -notin $supportedVersions)
								{
									if ($templateextVersion.Split(".").Count -eq 2) 
									{
										$templateextVersion = $templateextVersion + ".0.0" 
									}
									elseif ($templateextVersion.Split(".").Count -eq 3) 
									{
										$templateextVersion = $templateextVersion + ".0" 
									}
									if ($templateextVersion -notin $supportedVersions)
									{
										$autoupgradeSupported = $supportedVersions | Where-Object { (([version]$_).Major -eq ([version]$templateextVersion).Major) -and (([version]$_).Minor -ge ([version]$templateextVersion).Minor) }
										if ($autoupgradeSupported)
										{
											if ((-not $resource.properties.autoupgrademinorversion) -or ($resource.properties.autoupgrademinorversion -eq $false))
											{
												$msg = "Warning: Exact Match for VMExtension version ($templateextPublisher\$templateextType\$templateextVersion) not found in supported versions ($supportedVersions). It is recommended to set autoupgrademinorversion property to true."
												Write-warning $msg
												$resourceOutput += $msg
											}
										}
										else
										{
											$msg = "Warning: VMExtension version ($templateextPublisher\$templateextType\$templateextVersion) not found in supported versions ($supportedVersions)."
											Write-Warning $msg
											$resourceOutput += $msg
										}
									}
								}
							}
						}
					}
					catch
					{
						$msg = "Exception: VMExtension. $($_.Exception.Message)"
						Write-Error $msg
						$resourceOutput += $msg
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
						Write-Warning "Warning: No VMImages found in Capabilities.json. Run Get-AzureRMCloudCapabilities with -IncludeComputeCapabilities"
					}
					else
					{
						try
						{
							$templateImagePublisher = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "publisher"							
							$notSupported = CompareValues $templateImagePublisher $capabilities.VMImages.publisherName
							if ($notSupported)
							{
								if ($notSupported.NoneSupported)
								{
									$msg = "NotSupported: VMImage publisher (Resource type: $($resource.type)). Not supported values - $($notSupported.NotSupportedValues)"
								}
								else
								{
									$msg = "Warning: VMImage publisher (Resource type: $($resource.type)). Not supported values - $($notSupported.NotSupportedValues)"
								}
								Write-Warning $msg
								$resourceOutput += $msg
							}
							else
							{
								if ($templateImagePublisher.GetType().Name -eq "Object[]")
								{
									$templateImagePublisher = $templateImagePublisher[0]
								}
								$supportedPublisher = $capabilities.VMImages | Where-Object { $_.publisherName -eq $templateImagePublisher }
								try
								{
									$templateImageOffer = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "offer"
									$notSupported = CompareValues $templateImageOffer $supportedPublisher.Offers.offerName
									if ($notSupported)
									{
										if ($notSupported.NoneSupported)
										{
											$msg = "NotSupported: VMImage Offer (Publisher: $templateImagePublisher). Not supported values - $($notSupported.NotSupportedValues)"
										}
										else
										{
											$msg = "Warning: VMImage Offer (Publisher: $templateImagePublisher). Not supported values - $($notSupported.NotSupportedValues)"
										}
										Write-Warning $msg
										$resourceOutput += $msg
									}
									else
									{
										if ($templateImageOffer.GetType().Name -eq "Object[]")
										{
											$templateImageOffer = $templateImageOffer[0]
										}
										$supportedOffer = $supportedPublisher.Offers | Where-Object { $_.offerName -eq $templateImageOffer }
										try
										{
											$templateImagesku = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "sku"
											$notSupported = CompareValues $templateImagesku $supportedOffer.skus.skuName
											if ($notSupported)
											{
												if ($notSupported.NoneSupported)
												{
													$msg = "NotSupported: VMImage SKu (Offer: $templateImagePublisher\$templateImageOffer). Not supported values - $($notSupported.NotSupportedValues)"
												}
												else
												{
													$msg = "Warning: VMImage SKu (Offer: $templateImagePublisher\$templateImageOffer). Not supported values - $($notSupported.NotSupportedValues)"
												}
												Write-Warning $msg
												$resourceOutput += $msg
											}
											else
											{
												if ($templateImagesku.GetType().Name -eq "Object[]")
												{
													$templateImagesku = $templateImagesku[0]
												}
												$supportedSku = $supportedOffer.skus | Where-Object { $_.skuName -eq $templateImagesku }
												try
												{
													$templateImageskuVersion = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "version"
													$notSupported = CompareValues $templateImageskuVersion $supportedSku.versions
													if (($templateImageskuVersion -ne "latest") -and ($notSupported))
													{
														if ($notSupported.NoneSupported)
														{
															$msg = "NotSupported: VMImage SKu version (Sku: $templateImagePublisher\$templateImageOffer\$templateImageSku). Not supported values - $($notSupported.NotSupportedValues)"
														}
														else
														{
															$msg = "Warning: VMImage SKu version (Sku: $templateImagePublisher\$templateImageOffer\$templateImageSku). Not supported values - $($notSupported.NotSupportedValues)"
														}
														Write-Warning $msg
														$resourceOutput += $msg
													}
													elseif (($templateImageskuVersion -ne "latest") -and (-not $notSupported)) 
													{
														$msg = "Recommend: It is recommended to set storageprofile.imagereference.version to 'latest'"
														Write-Warning $msg
														$resourceOutput += $msg
													}
												}
												catch
												{
													$msg = "Exception: VMImage SKu version (Sku: $templateImagePublisher\$templateImageOffer\$templateImageSku). $($_.Exception.Message)"
													Write-Error $msg
													$resourceOutput += $msg
												}
											}
										}
										catch
										{
											$msg = "Exception: VMImage SKu (Offer: $templateImagePublisher\$templateImageOffer). $($_.Exception.Message)"
											Write-Error $msg
											$resourceOutput += $msg
										}
									}
								}
								catch
								{
									$msg = "Exception: VMImage Offer (Publisher: $templateImagePublisher). $($_.Exception.Message)"
									Write-Error $msg
									$resourceOutput += $msg
								}
							}
						}
						catch
						{
							$msg = "Exception: VMImage publisher (Resource type: $($resource.type)). $($_.Exception.Message)"
							Write-Error $msg
							$resourceOutput += $msg
						}
					}
				}
				if (-not $capabilities.VMSizes)
				{
					Write-Warning "Warning: No VMSizes found in Capabilities.json. Run Get-AzureRMCloudCapabilities with -IncludeComputeCapabilities"
				}
				else
				{
					try
					{
						$templateVMSize = Get-PropertyValue $resource.properties.hardwareprofile $Template $resource "vmSize"
						$notSupported = CompareValues $templateVMSize $capabilities.VMSizes
						if ($notSupported)
						{
							if ($notSupported.NoneSupported)
							{
								$msg = "NotSupported: VMSize. Not Supported Values - $($notSupported.NotSupportedValues)"
							}
							else
							{
								$msg = "Warning: VMSize. Not Supported Values - $($notSupported.NotSupportedValues)"
							}
							Write-Warning $msg
							$resourceOutput += $msg
						}
					}
					catch
					{
						$msg = "Exception: VMSize. $($_.Exception.Message)"
						Write-Error $msg
						$resourceOutput += $msg
					}
				}
			}
		}
		if ($IncludeStorageCapabilities)
		{
			if ($resource.type -eq "Microsoft.Storage/StorageAccounts")
			{
				Write-Verbose "Validating StorageAcount Sku"
				if (-not $capabilities.StorageSkus)
				{
					Write-Warning "Warning: No StorageSkus found in Capabilities.json. Run Get-AzureRMCloudCapabilities with -IncludeStorageCapabilities"
				}
				else
				{
					try
					{
						$templateStorageKind = Get-PropertyValue $resource.kind $Template $resource
						$supportedKind = ($capabilities.StorageSkus | Where-Object { $_.kind -eq $templateStorageKind }).kind
						$notSupported = CompareValues $templateStorageKind $supportedKind 
						if ($notSupported)
						{
							if ($notSupported.NoneSupported)
							{
								$msg = "NotSupported: Storage kind. Not Supported Values - $($notSupported.NotSupportedValues)"
							}
							else
							{
								$msg = "Warning: Storage kind. Not Supported Values - $($notSupported.NotSupportedValues)"
							}
							Write-Warning $msg
							$resourceOutput += $msg
						}
						else
						{
							$templateStorageSku = Get-PropertyValue $resource.sku.Name $Template $resource
							$supportedSkus= ($capabilities.StorageSkus | Where-Object { $_.kind -eq $templateStorageKind }).skus
							$notSupported= CompareValues $templateStorageSku $supportedSkus
							if ($notSupported)
							{
								if ($notSupported.NoneSupported)
								{
									$msg = "NotSupported: Storage sku '$templateStorageKind\$templateStorageSku'. Not Supported Values - $($notSupported.NotSupportedValues)"
								}
								else
								{
									$msg = "Warning: Storage sku '$templateStorageKind\$templateStorageSku'. Not Supported Values - $($notSupported.NotSupportedValues)"
								}
								Write-Warning $msg
								$resourceOutput += $msg
							}
						}
					}
					catch
					{
						Write-Warning "$($_.Exception.Message). Proceeding to see if there is Storage Accountype"
						try 
						{
							$templateStorageAccountType = Get-PropertyValue $resource.properties.accountType $Template $resource
							$supportedTypes = ($capabilities.StorageSkus | Where-Object { $_.kind -eq 'Storage' }).skus
							$notSupported = CompareValues $templateStorageAccountType $supportedTypes
							if ($notSupported)
							{
								if ($notSupported.NoneSupported)
								{
									$msg = "NotSupported: Storage AccountType. Not Supported Values - $($notSupported.NotSupportedValues)"
								}
								else
								{
									$msg = "Warning: Storage AccountType. Not Supported Values - $($notSupported.NotSupportedValues)"
								}
								Write-Warning $msg
								$resourceOutput += $msg
							}
						}
						catch
						{
							$msg = "Exception: Storage AccountType. $($_.Exception.Message)"
							Write-Error $msg
							$resourceOutput += $msg
						}
					}
				}
			}
		}
	}
	return $resourceOutput
}

# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5IE53hh6ppGQpCE7jbtQf3ZP
# tKCgghhlMIIEwzCCA6ugAwIBAgITMwAAAMWWQGBL9N6uLgAAAAAAxTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODUy
# WhcNMTgwOTA3MTc1ODUyWjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkMwRjQtMzA4Ni1ERUY4MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtrwz4CWOpvnw
# EBVOe1crKElrs3CQl/yun1cdkpugh/MxsuoGn7BL43GRTxRn7sPD7rq1Dxj4smPl
# gVZr/ZhGMA8J3zXOqyIcD4hYFikXuhlGuuSokunCAxUl5N4gjN/M7+NwJPm2JtYK
# ZLBdH5J/y+GIk7rQhpgbstpLOZf4GHgC8Myji7089O1uX2MCKFFU+wt2Y560O4Xc
# 2NVjeuG+nnq5pGyq9111nK3f0DeT7FWjDVQWFghKOhyeBb4iMhmkdA8vWpYmx6TN
# c+d35nSZcLc0EhSIVJkzEBYfwkrzxFaG/pgNJ9C4jm/zHgwWLZwQpU7K2fP15fGk
# BGplwNjr1wIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFA4B9X87yXgCWEZxOwn8mnVX
# hjjEMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAAUS3tgSEzCpyuw21ySUAWvGltQxunyLUCaOf1dffUcG25oa
# OW/WuIFJs0lv8Py6TsOrulsx/4NTkIyXra/MsJvwczMX2s/vx6g63O3osQI85qHD
# dp8IMULGmry+oqPVTuvL7Bac905EqqGXGd9UY7y14FcKWBWJ28vjncTw8CW876pY
# 80nSm8hC/38M4RMGNEp7KGYxx5ZgGX3NpAVeUBio7XccXHEy7CSNmXm2V8ijeuGZ
# J9fIMkhiAWLEfKOgxGZ63s5yGwpMt2QE/6Py03uF+X2DHK76w3FQghqiUNPFC7uU
# o9poSfArmeLDuspkPAJ46db02bqNyRLP00bczzwwggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TCCBhEwggP5
# oAMCAQICEzMAAACOh5GkVxpfyj4AAAAAAI4wDQYJKoZIhvcNAQELBQAwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xNjExMTcyMjA5MjFaFw0xODAy
# MTcyMjA5MjFaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQh9RCK36d2cZ61KLD4xWS
# 0lOdlRfJUjb6VL+rEK/pyefMJlPDwnO/bdYA5QDc6WpnNDD2Fhe0AaWVfIu5pCzm
# izt59iMMeY/zUt9AARzCxgOd61nPc+nYcTmb8M4lWS3SyVsK737WMg5ddBIE7J4E
# U6ZrAmf4TVmLd+ArIeDvwKRFEs8DewPGOcPUItxVXHdC/5yy5VVnaLotdmp/ZlNH
# 1UcKzDjejXuXGX2C0Cb4pY7lofBeZBDk+esnxvLgCNAN8mfA2PIv+4naFfmuDz4A
# lwfRCz5w1HercnhBmAe4F8yisV/svfNQZ6PXlPDSi1WPU6aVk+ayZs/JN2jkY8fP
# AgMBAAGjggGAMIIBfDAfBgNVHSUEGDAWBgorBgEEAYI3TAgBBggrBgEFBQcDAzAd
# BgNVHQ4EFgQUq8jW7bIV0qqO8cztbDj3RUrQirswUgYDVR0RBEswSaRHMEUxDTAL
# BgNVBAsTBE1PUFIxNDAyBgNVBAUTKzIzMDAxMitiMDUwYzZlNy03NjQxLTQ0MWYt
# YmM0YS00MzQ4MWU0MTVkMDgwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1
# ApUwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEF
# BQcBAQRVMFMwUQYIKwYBBQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNV
# HRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBEiQKsaVPzxLa71IxgU+fKbKhJ
# aWa+pZpBmTrYndJXAlFq+r+bltumJn0JVujc7SV1eqVHUqgeSxZT8+4PmsMElSnB
# goSkVjH8oIqRlbW/Ws6pAR9kRqHmyvHXdHu/kghRXnwzAl5RO5vl2C5fAkwJnBpD
# 2nHt5Nnnotp0LBet5Qy1GPVUCdS+HHPNIHuk+sjb2Ns6rvqQxaO9lWWuRi1XKVjW
# kvBs2mPxjzOifjh2Xt3zNe2smjtigdBOGXxIfLALjzjMLbzVOWWplcED4pLJuavS
# Vwqq3FILLlYno+KYl1eOvKlZbiSSjoLiCXOC2TWDzJ9/0QSOiLjimoNYsNSa5jH6
# lEeOfabiTnnz2NNqMxZQcPFCu5gJ6f/MlVVbCL+SUqgIxPHo8f9A1/maNp39upCF
# 0lU+UK1GH+8lDLieOkgEY+94mKJdAw0C2Nwgq+ZWtd7vFmbD11WCHk+CeMmeVBoQ
# YLcXq0ATka6wGcGaM53uMnLNZcxPRpgtD1FgHnz7/tvoB3kH96EzOP4JmtuPe7Y6
# vYWGuMy8fQEwt3sdqV0bvcxNF/duRzPVQN9qyi5RuLW5z8ME0zvl4+kQjOunut6k
# LjNqKS8USuoewSI4NQWF78IEAA1rwdiWFEgVr35SsLhgxFK1SoK3hSoASSomgyda
# Qd691WZJvAuceHAJvDCCB3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEx
# MB4XDTExMDcwODIwNTkwOVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUg
# U2lnbmluZyBQQ0EgMjAxMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AKvw+nIQHC6t2G6qghBNNLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL
# 8DjCmQawyDnVARQxQtOJDXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/X
# llnKYBoF6WZ26DJSJhIv56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5k
# NXimoGMPLdNAk/jj3gcN1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJ
# Xtjt7UORg9l7snuGG9k+sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4
# ftKdgCz1TlaRITUlwzluZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgo
# tswnKDglmDlKNs98sZKuHCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0Xpb
# L9Uj43BdD1FGd7P4AOG8rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy
# 5yTfv0aZxe/CHFfbg43sTUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9
# Z4DmimJ4X7IvhNdXnFy/dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4
# IFgsE11glZo+TzOE2rCIF96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQ
# BgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUw
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0f
# BFMwUTBPoE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcB
# AQRSMFAwTgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kv
# Y2VydHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGX
# MIGUMIGRBgkrBgEEAYI3LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcC
# AjA0HjIgHQBMAGUAZwBhAGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUA
# bgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFj
# kplCln3SeQyQwWVfLiw++MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtG
# UFXYDJJ80hpLHPM8QotS0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32m
# kHSDjfTLJgJGKsKKELukqQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr
# 3vw70L01724lruWvJ+3Q3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYK
# wsatruWy2dsViFFFWDgycScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6C
# PxNNZgvAs0314Y9/HG8VfUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX
# 0O5dY0HjWwechz4GdwbRBrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADW
# oUa9WfOXpQlLSBCZgB/QACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9r
# t0uX4ut1eBrs6jeZeRhL/9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGd
# Vk5Pv4BXIqF4ETIheu9BCrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9
# bW1qyVJzEw16UM0xggTlMIIE4QIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5n
# IFBDQSAyMDExAhMzAAAAjoeRpFcaX8o+AAAAAACOMAkGBSsOAwIaBQCggfkwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFAH1GxdvLktdx/iqOpiZXe7Z1y5DMIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEAOROuc4gr6q4eQAH2n6T108A/kfTH1dd1
# Vhf7KUvUMZOVx8SFV8WIwX/6OgKLwtzPR34kRC3G/UtpECSylk2HWtv7vbdqRV8t
# COhCTVRTcJFwBu0opm2c7TCuu9BcTmLwPK9F5L/9n3WsnMU9Uli/NVjh0gGljprT
# iliXAqvrsp4wJDkn9Yo33l+DHRDLJVTnOKInf7dCunF8EA4QFZw5VtA3h4xznvy5
# DEcml4R1y/N0t0vD7FJH6fbCNikiDwK5pGzoaAjvAkomAacH0Tuhd11J2YYYD1G7
# iqX1JKsgyNKAVzhRqnL72Hq6HEi/ZC0Ag9t+TVP3tNoIdtJRD8JSEKGCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADFlkBgS/Teri4AAAAAAMUwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxNFowIwYJ
# KoZIhvcNAQkEMRYEFPGOql0+o56mpJURSAFkyyoBosRgMA0GCSqGSIb3DQEBBQUA
# BIIBADLwbnM3QSxWpFBEr1ua7xDOJhg599cJOx86lyVVnhsciTif5bGULKaoNgiD
# BkdyoaXBEx4VNwp50AANV17SIsTjA8Ga4FvSKqq0rMNwRzZQVeVqu0iIBQJx9xW6
# 5qDeE1IYtYZ1l4mtVXQTfEG/yTeaBTY2h0hef62iyUgfX/FoGoszivVxIEWQFlGz
# 462RmcSLwnyoKFfYNZ2i8L+yMNC7de0duBZgHhBhLUUl12Q9AZDDRlF74Q4lpbCd
# HGWVvEu/ph65ZyC7IQChJWsK8jd+Cl0EfBKudDV1kOPObkTJ7BSfEVhNHKFPhVog
# Q7fKCNS5SObhN1JL/zs8baFu72I=
# SIG # End signature block
