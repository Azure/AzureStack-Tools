# Copyright (c) Microsoft Corporation. All rights reserved.

# See LICENSE.txt in the project root for license information.

<#
    .SYNOPSIS

    Validate Azure ARM Template Capabilities (ARM resources, Api-version, VM Extensions, VM Images, VMSizes etc) for Azure Stack and Azure.

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
	$successCount =0
    foreach ($template in $TemplateDirectory)
    {
		$templateName = (Split-path -Path $template.FullName).Split("\")[-1]
		Write-Verbose "Template name is $templateName"
		try 
		{
			$result = ValidateTemplate -TemplatePath $template.FullName  -Capabilities $Capabilities -IncludeComputeCapabilities:$IncludeComputeCapabilities			
			if ($result.Status -like "Failed")
			{
				$errorCount++;
			}
			elseif ($result.Status -like "Warning")
			{
				$warningCount++;
			}
			else
			{
				$successCount++;
			}
		}
		catch
		{
			$errorCount++;
			$result = [PSCustomObject]@{
			TemplateName = $templateName
			Status = "Failed"
			Details = "Error: $($_.Exception.Message)"
			}
		}
		finally
		{
			$totalcount++
		}
        $reportOutPut += $result
    }
	if (([System.IO.FileInfo]$Report).Extension -eq '.csv')
	{
		$reportOutPut | Export-CSV -delimiter ';' -NoTypeInformation -Encoding $Report
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
		[xml] $reportXml = $reportOutPut | ConvertTo-Html -Fragment
		for ($i = 1; $i -le $reportXml.table.tr.count-1; $i++)
		{
			$class =$reportXml.CreateAttribute("class")
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
		$reportHtml = $title+$reportXml.OuterXml|Out-String
		$postContent = "<H3>Template Validation completed on $(Get-Date)<br> 
		Success: $successCount<br> 
		Warning: $warningCount<br> 
		Failure: $errorCount<br> 
		Total Templates: $totalCount</H3>"

		ConvertTo-Html -head $head -Body $reportHtml -PostContent $postContent| out-File $Report
	}
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
	$TemplatePS = ConvertFrom-Json (Get-Content -Path $TemplatePath -Raw)
	$ValidationOutput =[PSCustomObject]@{
		TemplateName = ""
		Status = ""
		Details = ""
		}
	$ValidationOutPut.TemplateName = (Split-path -Path $template.FullName).Split("\")[-1]
	$ErrorList = @()
	foreach ($templateResource in $TemplatePS.resources)
	{ 
		$ErrorList += ValidateResource $templateResource $TemplatePS
		foreach ($nestedResource in $templateResource.resources)
		{
			$ErrorList += ValidateResource $nestedResource $TemplatePS
		}
	}
	
	# validating the Storage Endpoint
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
	return $ValidationOutput
}

function Get-PropertyValue
{
	param(
		[ValidateNotNullOrEmpty()]
		[String] $property,
		[ValidateNotNullOrEmpty()]
		[PSCustomObject] $Template
	)
	if ($property -like "*variables*")
	{
		$propertyName = $property.Split("'")[1]
		$property = $Template.variables.$propertyName
		#Variable referencing another variable
		if ($property -like "*variables*")
		{
			$propertyName = $property.Split("'")[1]
			$property = $Template.variables.$propertyName
		}
	}
	if ($property -like "*parameters*")
	{
		$propertyName = $property.Split("'")[1]
		$DefaultValue = $Template.parameters.$propertyName.defaultValue
		if (-not $DefaultValue)
		{
			throw "Parameter: $property  No defaultvalue set"
		}
		return $DefaultValue
	}
	return $property
}

function ValidateResource
{
	param(
		[ValidateNotNullOrEmpty()]
		[PSObject] $resource,
		[ValidateNotNullOrEmpty()]
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
			$templateResApiversion = Get-PropertyValue $resource.apiversion $Template
		}
		catch
		{
			Write-Error $_.Exception.Message
			$resourceOutput += "Error: $($_.Exception.Message)"
		}
		$supportedApiVersions = $ResourceTypeProperties.Apiversions
		if ($templateResApiversion -iin $supportedApiVersions)
		{
			Write-Verbose "Resource type $($resource.type) apiversion:$templateResApiversion. Supported Values are $supportedApiVersions"
		}
		else
		{
			Write-Error  "Resource type $($resource.type) apiversion: $templateResApiversion. Supported Values are $supportedApiVersions"
			$resourceOutput += "Error:Resource type $($resource.type) apiversion: $templateResApiversion. Supported Values are $supportedApiVersions"
		}

		Write-Verbose "Validating Location info for $ResourceProviderNameSpace\$ResourceTypeName"
		# Excluding resourceType == Deployment since location property is not required there
		if ($resource.type -ne 'Microsoft.Resources/deployments')
		{
			try
			{
				$locationToCheck = Get-PropertyValue $resource.location $Template
			}
			catch
			{
				Write-Error $_.Exception.Message
				$resourceOutput += "Error: $($_.Exception.Message)"
			}
			$supportedLocations = $ResourceTypeProperties.Locations
			if (($locationToCheck -notin $supportedLocations ) -and ($locationToCheck -notlike "*resourceGroup().location*"))
			{
				Write-Error "Resource type $($resource.type) targets $locationToCheck location. Supported Values are 'resourceGroup().location' or $supportedLocations"
				$resourceOutput += "Error:Resource type $($resource.type) targets $locationToCheck location. Supported Values are 'resourceGroup().location' or $supportedLocations"
			}
			elseif (($locationToCheck -in $supportedLocations ) -and ($locationToCheck -notlike "*resourceGroup().location*"))
			{
				$resourceOutput += "Warning:For Resource type $($resource.type), it is recommended to set location as resourceGroup().location"
			}
		
		}
		#Process VMImages 
		if ($IncludeComputeCapabilities)
		{
			if ($ResourceTypeName -Like '*extensions')
			{
				Write-Verbose "Validating VMExtension $ResourceProviderNameSpace/$ResourceTypeName"
				$templateextPublisher = $resource.properties.publisher
				$templateextType = $resource.properties.type
				$templateextVersion = $resource.properties.typeHandlerVersion                
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

			if ($resource.type -eq "Microsoft.Compute/virtualMachines")
			{
				$templateImagePublisher = $resource.properties.storageprofile.imagereference.publisher
				if ($templateImagePublisher)
				{
					Write-Verbose "Validating VMImages"
					try
					{
						$templateImagePublisher = Get-PropertyValue $templateImagePublisher $Template
					}
					catch
					{
						Write-Error $_.Exception.Message
						$resourceOutput += "Error: $($_.Exception.Message)"
					}
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
							$templateImageOffer = Get-PropertyValue $resource.properties.storageprofile.imagereference.offer $Template
						}
						catch
						{
							Write-Error $_.Exception.Message
							$resourceOutput += "Error: $($_.Exception.Message)"
						}
						$supportedOffer = $capabilities.VMImages.Offers | Where-Object { $_.offerName -eq $templateImageOffer }
						if (-not $supportedOffer)
						{
							Write-Error "VMImage Offer: $templateImageOffer currently not supported. Refer to Capabilities.json for supported VMImages Offers"
							$resourceOutput += "Error: VMImage Offer: $templateImageOffer currently not supported. Refer to Capabilities.json for supported VMImages Offers"
						}
						else
						{
							$templateImageSku = $resource.properties.storageprofile.imagereference.sku
							try
							{
								$templateImagesku = Get-PropertyValue $templateImagesku $Template
							}
							catch
							{
								Write-Error $_.Exception.Message
								$resourceOutput += "Error: $($_.Exception.Message)"
							}
							$supportedSku = $capabilities.VMImages.Offers.skus | where { $_.skuName -eq $templateImagesku}
							if (-not $supportedSku)
							{
								Write-Error "VMImage SKu: $templateImageSku currently not supported. Refer to Capabilities.json for supported VMImages Skus"
								$resourceOutput += "Error:VMImage SKu: $templateImageSku currently not supported. Refer to Capabilities.json for supported VMImages Skus"
							}
							else
							{
								$templateImageskuVersion = $resource.properties.storageprofile.imagereference.version
								try
								{
									$templateImageskuVersion = Get-PropertyValue $templateImageskuVersion $Template
								}
								catch
								{
									Write-Error $_.Exception.Message
									$resourceOutput += "Error: $($_.Exception.Message)"
								}
								if (($templateImageskuVersion -ne "latest") -and ($templateImageskuVersion -notin $supportedSku.versions)) 
								{
									Write-Error "VMImage SKu version: $templateImageskuVersion currently not supported. Set to latest or Refer to Capabilities.json for supported VMImages Skus version "
									$resourceOutput += "Error: VMImage SKu version: $templateImageskuVersion currently not supported. Set to latest or Refer to Capabilities.json for supported VMImages Skus version"
								}
								elseif (($templateImageskuVersion -ne "latest") -and ($templateImageskuVersion -in $supportedSku.versions)) 
								{
									Write-Error "Warning: It is recommended to set storageprofile.imagereference.version to 'latest'"
									$resourceOutput += "Warning: It is recommended to set storageprofile.imagereference.version to 'latest'"
								}
							}
						}
					}
				}
				try
				{
					$templateVMSize = Get-PropertyValue $resource.properties.hardwareprofile.vmSize $Template
				}
				catch
				{
					Write-Error $_.Exception.Message
					$resourceOutput += "Error: $($_.Exception.Message)"
				}
				$supportedSize = $capabilities.VMSizes | Where-Object { $_ -eq $templateVMSize }
				if (-not $supportedSize)
				{
					Write-Error "VMSize: $templateVMSize currently not supported. Refer to Capabilities.json for supported VMSizes"
					$resourceOutput += "Error:VMSize: $templateVMSize currently not supported. Refer to Capabilities.json for supported VMSizes"
				}
			}
		}
	}
	return $resourceOutput
}

