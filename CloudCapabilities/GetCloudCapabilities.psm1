# Copyright (c) Microsoft Corporation. All rights reserved.

# See LICENSE.txt in the project root for license information.

<#

    .SYNOPSIS

    Get Cloud Capabilities (ARM resources, version etc) for Azure Stack and Azure.

#>

function Get-CloudCapabilities()
{
	[CmdletBinding()]
    Param(		
        [Parameter(Mandatory=$true, HelpMessage="Active Directory tenant id for Azure stack. leave this empty for Azure")]	
		[String] $tenantID,

		[Parameter(HelpMessage='Azure stack domain name. Leave this empty for Azure')]
        [string] $azureStackDomain = 'azurestack.local',

		[Parameter(HelpMessage='Deployment location. Default is local for azure stack')]
		[String] $location = 'local',

		[Parameter(HelpMessage = 'Json output file name')]
        [String] $outputPath = "AzureStackCapabilities.Json",

		[Parameter(HelpMessage = 'Set this to true to get compute resource provider Images and extensions. Default value is false')]
		[bool] $getComputeImageExtensions = $false
    )
	# To calculate the execution time across environments
	$sw = [Diagnostics.Stopwatch]::StartNew()	
	
	if ($location -eq "local")
	{
		AuthenticateAzureStack -Domain $azureStackDomain -tenantID $tenantID #-aadCredential $azureStackCredential 
	}
	else
	{
		Login-AzureRmAccount
	}
	# Get all the registered resource provider
	$providerNamespaces = (Get-AzureRmResourceProvider -ListAvailable | Select-Object ProviderNamespace).ProviderNamespace
	# Custom result object
	$results = @()
	foreach($providerNamespace in $providerNamespaces) {
		"Working on $providerNamespace provider namespace"
		try {
			$resourceTypes = (Get-AzureRmResourceProvider -ProviderNamespace $providerNamespace -ErrorAction Stop).ResourceTypes
			foreach($resourceTypesa in $resourceTypes) { 
				foreach($loc in $resourceTypesa.Locations) {
					foreach($resourceTypespi in $resourceTypesa.ApiVersions) {
						$result = "" | Select-Object ProviderNamespace, ResourceTypeName, Location, ApiVersion
						$result.ProviderNamespace = $providerNamespace
						$result.ResourceTypeName = $resourceTypesa.ResourceTypeName
						$result.Location = $loc
						$result.ApiVersion = $resourceTypespi
						$results += ,$result
					}
			
				} 
			}
		} catch [Exception] {
			Write-Verbose "Error occurred processing $providerNamespace provider namespace"
		}
	}

	$resourceAggregate = $results | Group-Object ProviderNamespace, ResourceTypeName
	 
	# Output Json structure
	$OutputJsonDict = @{"functions" = New-Object System.Collections.ArrayList; "resources" = New-Object System.Collections.ArrayList;
						"images" = New-Object System.Collections.ArrayList; "extensions" = New-Object System.Collections.ArrayList}	

	foreach ($resourceAggElem in $resourceAggregate)
	{
		$memberDict = @{}

		$name = $resourceAggElem.Group[0].ResourceTypeName
		$namespace = $resourceAggElem.Group[0].ProviderNamespace
		$resourceInfoObj = $resourceAggElem.Group
		$locationAgg = $resourceInfoObj | Group-Object Location
		$versionAgg = $resourceInfoObj | Group-Object ApiVersion

		$locationList = New-Object System.Collections.ArrayList
		foreach ($locationAggElem in $locationAgg)
		{
			$locationElemDict = @{}
			$location = $locationAggElem.Name

			$versionList = New-Object System.Collections.ArrayList
			foreach ($groupElem in $locationAggElem.Group){
				$apiVersion = $groupElem.ApiVersion
				$versionList.Add($apiVersion) | Out-Null
			}

			$locationElemDict.Set_Item("name", $location)
			$locationElemDict.Set_Item("versions", $versionList)
			$locationList.Add($locationElemDict) | Out-Null
		}

		$memberDict.Set_Item("name",$name)
		$memberDict.Set_Item("namespace", $namespace)
		$memberDict.Set_Item("locations", $locationList)

		$OutputJsonDict["resources"].Add($memberDict) | Out-Null
	}
	
	$presetSupportedARMFunctions = @("add", "copyIndex", "div", "int", "length", "mod", "mul", "sub", "base64", 
		"concat", "padLeft", "replace", "split", "string", "substring", "toLower", "toUpper", "trim", 
		"uniqueString", "uri","skip", "split", "take", "deployment", "parameters", "variables", "listkeys", 
		"list*", "providers", "reference", "resourceGroup", "resourceId", "subscription")

	foreach ($line in $presetSupportedARMFunctions)
	{
		$memberDict = @{}
		$locationList = @(@{"name"="all";"versions"=@("all")})
		$memberDict.Set_Item("name",$line)
		$memberDict.Set_Item("locations", $locationList)
		$OutputJsonDict["functions"].Add($memberDict) | Out-Null
	}

if ($getComputeImageExtensions)
{
	$publishers = Get-AzureRmVMImagePublisher -Location $location| Where-Object {$_.PublisherName -like "*"}
	$publisherList = New-Object System.Collections.ArrayList

	$imageList = New-Object System.Collections.ArrayList
	$extensionList = New-Object System.Collections.ArrayList

	foreach ($publisherObj in $publishers)
	{

		$publisher = $publisherObj.PublisherName
		"Working on publisher "+$publisher

		$offers = Get-AzureRmVMImageOffer -Location $location -PublisherName $publisher
		if ($offers -ne $null){

			$offerList = New-Object System.Collections.ArrayList

			foreach($offerObj in $offers)
			{
				$offer = $offerObj.Offer
				$skuList = New-Object System.Collections.ArrayList

				$skus = Get-AzureRmVMImageSku -Location $location -PublisherName $publisher -Offer $offer

				foreach ($skuObj in $skus)
				{
					$sku = $skuObj.Skus

					$images = Get-AzureRmVMImage -Location $location -PublisherName $publisher -Offer $offer -sku $sku
					$versions = $images.Version
					if ($versions.Count -le 1){
						$versions = @($versions)
					}
					
					$locationDict = @{"name" = $location; "versions" = $versions}
					$locationList = New-Object System.Collections.ArrayList
					$locationList.Add($locationDict) | Out-Null
					$skuDict = @{"skuName" = $sku; "locations" = $locationList}
					$skuList.Add($skuDict) | Out-Null
					
				}

				$offerDict = @{"offerName" = $offer; "skus" = $skuList}
				$offerList.Add($offerDict) | Out-Null
			}

			$publisherDict = @{"publisherName" = $publisher; "offers"=$offerList}
			$imageList.Add($publisherDict) | Out-Null
		}
		else
		{
			
			$types = Get-AzureRmVMExtensionImageType  -Location $location -PublisherName $publisher
			$typeList = New-Object System.Collections.ArrayList
			if ($types -ne $null)
			{
				foreach ($type in $types.Type)
				{
					$extensions = Get-AzureRmVMExtensionImage -Location $location -PublisherName $publisher -Type $type
					$versions = $extensions.Version
					if ($versions.Count -le 1){
						$versions = @($versions)
					}
					
					$locationDict = @{"name" = $location; "versions" = $versions}
					$locationList = New-Object System.Collections.ArrayList
					$locationList.Add($locationDict) | Out-Null
					$typeDict = @{"type" = $type; "locations" = $locationList}
					$typeList.Add($typeDict) | Out-Null
				}
				$publisherDict = @{"publisher" = $publisher; "types" = $typeList}
				$extensionList.Add($publisherDict) | Out-Null
			}
			else
			{
				"none @ "+ $publisher
			}
		}    
	}
	$OutputJsonDict.Set_Item("extensions", $extensionList)
	$OutputJsonDict.Set_Item("images", $imageList)	
}

	$OutputJson = ConvertTo-Json $OutputJsonDict -Depth 10
	$OutputJson | Out-File $OutputPath

	$sw.Stop()
	$time = $sw.Elapsed
	"Cloud Capabilities Database Generation Complete"
	"Time Elapsed = "+[math]::floor($time.TotalMinutes)+" min "+$time.Seconds+" sec"
}

function AuthenticateAzureStack()
{
    Param(
        [Parameter(Mandatory=$true)][String] $Domain,
		[String] $tenantID
    )
	#defaults
	
	$VerbosePreference="SilentlyContinue"; $WarningPreference="SilentlyContinue"

	#Endpoints
	"ARM: GET ENDPOINTS AND ADD aZURE STACK ENVIRONMENT" | Write-Verbose  -Verbose
	$envName = "AzureStackCloud" 
	$ResourceManagerEndpoint = $("https://api.$Domain".ToLowerInvariant())
	$endptres = Invoke-RestMethod "${ResourceManagerEndpoint}/metadata/endpoints?api-version=1.0"

	Add-AzureRmEnvironment -Name ($envName) `
			-ActiveDirectoryEndpoint ($($endptres.authentication.loginEndpoint) + $tenantID + "/") `
			-ActiveDirectoryServiceEndpointResourceId ($($endptres.authentication.audiences[0])) `
			-ResourceManagerEndpoint ($ResourceManagerEndpoint) `
			-GalleryEndpoint ($endptres.galleryEndpoint) `
			-GraphEndpoint ($endptres.graphEndpoint) `
		   -StorageEndpointSuffix ("$($Domain)".ToLowerInvariant()) `
		   -AzureKeyVaultDnsSuffix ("vault.$($Domain)".ToLowerInvariant()) | Out-Null

	"ARM: LOGIN AAD CREDENTIALS" | Write-Verbose  -Verbose
	Add-AzureRmAccount -Environment (Get-AzureRmEnvironment -Name ($envName)) | Out-Null

	"ARM: Select Default provider subscription" | Write-Verbose  -Verbose
    $subscriptionName = "Default Provider Subscription"
	Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription | Out-Null
}

