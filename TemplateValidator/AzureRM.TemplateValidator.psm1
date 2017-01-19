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
				if ($templateValidationStatus.Contains("Exception"))
				{
					$templateResults[0].Status = "Exception"
				}
				elseif ($templateValidationStatus.Contains("NotSupported"))
				{
					$templateResults[0].Status = "NotSupported"
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
.FAIL td:nth-child(2){background-color: orangered}
.WARN td:nth-child(2){background-color: yellow}
.RECOMMEND td:nth-child(2){background-color: Orange}
table td:nth-child(2){font-weight: bold;}
table td:nth-child(3){white-space:pre-line}
</style>
"@
		$title = "<H1>Template Validation Report</H1>"
		$validationSummary = "<H3>Template Validation completed on $(Get-Date)<br>
		Passed: $passedCount<br>		
		Recommend: $recommendCount<br>
		Warning: $warningCount<br> 
		NotSupported: $notSupportedCount<br>
		Exception: $exceptionCount<br>
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
			if (($reportXml.table.tr[$i].td[1] -eq 'NotSupported') -or ($reportXml.table.tr[$i].td[1] -eq 'Exception'))
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
			elseif ($reportXml.table.tr[$i].td[1] -eq 'Recommend')
			{
				$class.value ="RECOMMEND"
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
		$parameterValue = $TemplateJSON.parameters.$parameterKey.allowedValues
		if (-not $parameterValue)
		{
			if (-not $TemplateJSON.parameters.$parameterKey.defaultValue)
			{				
				throw "Parameter: $parameterKey - No defaultvalue or allowedValues set"
			}
			$parameterValue = $TemplateJSON.parameters.$parameterKey.defaultValue
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
	$ResourceTypeName = $resource.type.Substring($resource.type.indexOf('/')+1)    
	$ResourceTypeProperties = $capabilities.resources | Where-Object { $_.providerNameSpace -eq $ResourceProviderNameSpace } | Where-Object { $_.ResourcetypeName -eq $ResourceTypeName }
	$resourceOutput = @()
	Write-Verbose "Validating ProviderNameSpace and ResourceType"
	if (-not $ResourceTypeProperties)
	{
		Write-Error "NotSupported: Resource type $($resource.type) is currently not supported."
		$resourceOutput += "NotSupported: Resource type $($resource.type) is currently not supported."
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
				Write-Warning "Recommend: For apiVersion ($templateResApiversion), it is recommended to set a literal value."
				$resourceOutput += "Recommend: For apiVersion ($templateResApiversion), it is recommended to set a literal value."
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
				Write-Warning "Warning: Resource type $($resource.type) apiversion: $templateResApiversion. Supported Values are $supportedApiVersions"
				$resourceOutput += "Warning: Resource type $($resource.type) apiversion: $templateResApiversion. Supported Values are $supportedApiVersions"
			}
		}
		catch
		{
			Write-Error "Exception: Resource apiVersion: $($_.Exception.Message)"
			$resourceOutput += "Exception: Resource apiVersion: $($_.Exception.Message)"
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
				$supported = CompareValues $locationToCheck $supportedLocations
				if ((-not $supported) -and ($locationToCheck -notlike "*resourceGroup().location*"))
				{
					Write-Warning "Warning: Resource type $($resource.type) targets $locationToCheck location. Supported Values are 'resourceGroup().location' or $supportedLocations"
					$resourceOutput += "Warning: Resource type $($resource.type) targets $locationToCheck location. Supported Values are 'resourceGroup().location' or $supportedLocations"
				}
				elseif (($supported) -and ($locationToCheck -notlike "*resourceGroup().location*"))
				{
					Write-Warning "Recommend:For Resource type $($resource.type), it is recommended to set location as resourceGroup().location"
					$resourceOutput += "Recommend:For Resource type $($resource.type), it is recommended to set location as resourceGroup().location"
				}
			}
		}
		catch
		{
			Write-Error "Exception: Resource location: $($_.Exception.Message)"
			$resourceOutput += "Exception: Resource location: $($_.Exception.Message)"
		}
		Write-Verbose "Process VMImages"

		if ($IncludeComputeCapabilities)
		{
			if ($ResourceTypeName -Like '*extensions')
			{
				Write-Verbose "Validating VMExtension $ResourceProviderNameSpace/$ResourceTypeName"
				if (-not $capabilities.VMExtensions)
				{
					Write-Warning "Warning: No VMExtensions found in Capabilities.json. Run Get-AzureRMCloudCapabilities with -IncludeComputeCapabilities"
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
							Write-Warning "Warning: VMExtension publisher: $templateextPublisher currently not supported. Refer to Capabilities.json for supported VMExtension publishers"
							$resourceOutput += "Warning: VMExtension publisher: $templateextPublisher currently not supported. Refer to Capabilities.json for supported VMExtension publishers"
						}
						else
						{
							$supportedType = $supportedPublisher.types| Where-Object { $_.type -eq $templateextType }
							if (-not $supportedType)
							{
								Write-Error "Warning: VMExtension type: $templateextPublisher\$templateextType is currently not supported. Refer to Capabilities.json for supported VMExtension Types"
								$resourceOutput += "Warning: VMExtension type: $templateextPublisher\$templateextType is currently not supported. Refer to Capabilities.json for supported VMExtension Types"
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
											Write-Warning "Warning: VMExtension version: $templateextPublisher\$templateextType\$templateextVersion not found in $supportedVersions. Refer to Capabilities.json for supported VMExtension versions"
											$resourceOutput += "Warning: VMExtension version: $templateextPublisher\$templateextType\$templateextVersion not found in $supportedVersions. Refer to Capabilities.json for supported VMExtension versions"
										}
									}
								}
							}
						}
					}
					catch
					{
						Write-Error "Exception: Resource VMExtension: $($_.Exception.Message)"
						$resourceOutput += "Exception: Resource VMExtension: $($_.Exception.Message)"
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
							$supportedPublisher = $capabilities.VMImages | Where-Object { $_.publisherName -eq $templateImagePublisher }
							if (-not $supportedPublisher)
							{
								Write-Warning "Warning: VMImage publisher: $templateImagePublisher currently not supported. Refer to Capabilities.json for supported VMImages publishers"
								$resourceOutput += "Warning: VMImage publisher: $templateImagePublisher currently not supported. Refer to Capabilities.json for supported VMImages publishers"
							}
							else
							{
								try
								{
									$templateImageOffer = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "offer"
									$supportedOffer = $supportedPublisher.Offers | Where-Object { $_.offerName -eq $templateImageOffer }
									if (-not $supportedOffer)
									{
										Write-Warning "Warning: VMImage Offer: $templateImagePublisher\$templateImageOffer currently not supported. Refer to Capabilities.json for supported VMImages Offers"
										$resourceOutput += "Warning: VMImage Offer: $templateImagePublisher\$templateImageOffer currently not supported. Refer to Capabilities.json for supported VMImages Offers"
									}
									else
									{
										try
										{
											$templateImagesku = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "sku"
											$supportedSku = $supportedOffer.skus | where { $_.skuName -eq $templateImagesku}
											if (-not $supportedSku)
											{
												Write-Warning "Warning: VMImage SKu: $templateImagePublisher\$templateImageOffer\$templateImageSku currently not supported. Refer to Capabilities.json for supported VMImages Skus"
												$resourceOutput += "Warning: VMImage SKu: $templateImagePublisher\$templateImageOffer\$templateImageSku currently not supported. Refer to Capabilities.json for supported VMImages Skus"
											}
											else
											{
												try
												{
													$templateImageskuVersion = Get-PropertyValue $resource.properties.storageprofile.imagereference $Template $resource "version"
													$supported = CompareValues $templateImageskuVersion $supportedSku.versions
													if (($templateImageskuVersion -ne "latest") -and (-not $supported)) 
													{
														Write-Warning "Warning: VMImage SKu version: $templateImagePublisher\$templateImageOffer\$templateImageSku\$templateImageskuVersion currently not supported. Set to latest or Refer to Capabilities.json for supported VMImages Skus version "
														$resourceOutput += "Warning: VMImage SKu version: $templateImagePublisher\$templateImageOffer\$templateImageSku\$templateImageskuVersion currently not supported. Set to latest or Refer to Capabilities.json for supported VMImages Skus version"
													}
													elseif (($templateImageskuVersion -ne "latest") -and ($supported)) 
													{
														Write-Warning "Recommend: It is recommended to set storageprofile.imagereference.version to 'latest'"
														$resourceOutput += "Recommend: It is recommended to set storageprofile.imagereference.version to 'latest'"
													}
												}
												catch
												{
													Write-Error "Exception: Resource ImageSkuVersion $($_.Exception.Message)"
													$resourceOutput += "Exception: Resource ImageSkuVersion $($_.Exception.Message)"
												}
											}
										}
										catch
										{
											Write-Error "Exception: Resource ImageSku $($_.Exception.Message)"
											$resourceOutput += "Exception: Resource ImageSku $($_.Exception.Message)"
										}
									}
								}
								catch
								{
									Write-Error "Exception: Resource ImageOffer $($_.Exception.Message)"
									$resourceOutput += "Exception: Resource ImageOffer $($_.Exception.Message)"
								}
							}
						}
						catch
						{
							Write-Error "Exception: Resource ImagePublisher $($_.Exception.Message)"
							$resourceOutput += "Exception: Resource ImagePublisher $($_.Exception.Message)"
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
						$supported = CompareValues $templateVMSize $capabilities.VMSizes
						if (-not $supported)
						{
							Write-Warning "Warning: VMSize: $templateVMSize currently not supported. Refer to Capabilities.json for supported VMSizes"
							$resourceOutput += "Warning: VMSize: $templateVMSize currently not supported. Refer to Capabilities.json for supported VMSizes"
						}
					}
					catch
					{
						Write-Error "Exception: Resource VMSize $($_.Exception.Message)"
						$resourceOutput += "Exception: Resource VMSize $($_.Exception.Message)"
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
						$templateStorageKind = Get-PropertyValue $resource.properties.kind $Template $resource
						$supportedKind = $capabilities.StorageSkus | Where-Object { $_.kind -eq $templateStorageKind }
						$supportedKind = CompareValues $templateStorageKind $supportedKind 
						if (-not $supported)
						{
							Write-Warning "Warning: Storage kind: $templateStorageKind currently not supported. Refer to Capabilities.json for supported storage kind"
							$resourceOutput += "Warning: Storage kind: $templateStorageKind currently not supported. Refer to Capabilities.json for supported storage kind"
						}
						else
						{
							$templateStorageSku = Get-PropertyValue $resource.properties.sku.Name $Template $resource
							$supportedSkus= ($capabilities.StorageSkus | Where-Object { $_.kind -eq $templateStorageKind }).skus
							$supported= CompareValues $templateStorageSku $supportedSkus
							if (-not $supported)
							{
								Write-Warning "Warning: Storage sku: $templateStorageKind\$templateStorageSku currently not supported. Refer to Capabilities.json for supported storage kind and its Skus"
								$resourceOutput += "Warning: Storage Sku: $templateStorageKind\$templateStorageSku currently not supported. Refer to Capabilities.json for supported storage kind and its Skus"
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
							$supported = CompareValues $templateStorageAccountType $supportedTypes
							if (-not $supported)
							{
								Write-Warning "Warning: Storage AccountType: $templateStorageAccountType currently not supported. Refer to Capabilities.json for supported Storage skus"
								$resourceOutput += "Warning: Storage AccountType: $templateStorageAccountType currently not supported. Refer to Capabilities.json for supported Storage skus"
							}
						}
						catch
						{
							Write-Error "Exception: Resource Storage AccountType $($_.Exception.Message)"
							$resourceOutput += "Exception: Resource Storage AccountType $($_.Exception.Message)"
						}
					}
				}
			}
		}
	}
	return $resourceOutput
}