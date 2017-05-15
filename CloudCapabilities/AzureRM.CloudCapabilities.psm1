# Copyright (c) Microsoft Corporation. All rights reserved.

# See LICENSE.txt in the project root for license information.

<#

    .SYNOPSIS
	
    Get Cloud Capabilities (ARM resources, Api-version, VM Extensions, VM Images, VMSizes etc) for Azure Stack and Azure.

	Compare the capabilities of two clouds to determine resources and API versions that are commonly available in both. 
    Can be used to compare the availability of resource types in Azure and Azure Stack.

#>

function Get-AzureRMCloudCapabilities()
{
	[CmdletBinding()]
    Param(
		[Parameter(HelpMessage = 'Json output file')]
        [String] $OutputPath = "AzureCloudCapabilities.Json",

		[Parameter(HelpMessage='Cloud Capabilities for the specified location')]
		[String] $Location,

		[Parameter(HelpMessage = 'Set this to get compute resource provider Capabilities like Extensions, Images, Sizes')]
		[Switch] $IncludeComputeCapabilities,

		[Parameter(HelpMessage = 'Set this to get storage resource provider Capabilities like Sku')]
		[Switch] $IncludeStorageCapabilities
    )
	$sw = [Diagnostics.Stopwatch]::StartNew()
	Write-Verbose "Getting CloudCapabilities for location: '$location'"
	$providerNamespaces = (Get-AzureRmResourceProvider -ListAvailable -Location $location -ErrorAction Stop).ProviderNamespace
	$resources = @()
	foreach ($providerNamespace in $providerNamespaces)
	{
		Write-Verbose "Working on $providerNamespace provider namespace"
		try
		{
			$resourceTypes = (Get-AzureRmResourceProvider -ProviderNamespace $providerNamespace -Location $location -ErrorAction Stop).ResourceTypes
			foreach ($resourceType in $resourceTypes)
			{ 
				$result = "" | Select-Object ProviderNamespace, ResourceTypeName, Locations, ApiVersions
				$result.ProviderNamespace = $providerNamespace
				$result.ResourceTypeName = $resourceType.ResourceTypeName
				$result.Locations = $resourceType.Locations
				$result.ApiVersions = $resourceType.ApiVersions
				$resources += , $result
			}
		}
		catch
		{
			Write-Error "Error occurred processing $providerNamespace provider namespace.Exception: " $_.Exception.Message
		}
	}

	$capabilities = @{}
	$capabilities.Add("resources", $resources) | Out-Null
	
	if ($IncludeComputeCapabilities)
	{
		Write-Verbose "Getting VMSizes for $location"
		try
		{
			$vmSizes = (Get-AzureRmVMSize -Location $location -ErrorAction Stop| Where-Object {$_.Name -like "*"}).Name
			if ($vmSizes)
			{
				$capabilities.Add("VMSizes",  $vmSizes)
			}
			else
			{
				Write-Verbose "No VMSizes found for $location"
			}
		}
		catch
		{
			Write-Error "Error occurred processing VMSizes for $location. Exception: " $_.Exception.Message
		}
		
		Write-Verbose "Getting VMImages and Extensions for location $location"
		try
		{
			$publishers = Get-AzureRmVMImagePublisher -Location $location | Where-Object { $_.PublisherName -like "*" }
		}
		catch
		{
			Write-Error "Error occurred processing VMimagePublisher for $location. Exception: " $_.Exception.Message
		}
		if ($publishers)
		{
			$imageList = New-Object System.Collections.ArrayList
			$extensionList = New-Object System.Collections.ArrayList
			foreach ($publisherObj in $publishers)
			{
				$publisher = $publisherObj.PublisherName
				$offers = Get-AzureRmVMImageOffer -Location $location -PublisherName $publisher
				if ($offers -ne $null)
				{
					$offerList = New-Object System.Collections.ArrayList
					foreach ($offerObj in $offers)
					{
						$offer = $offerObj.Offer
						$skuList = New-Object System.Collections.ArrayList
						$skus = Get-AzureRmVMImageSku -Location $location -PublisherName $publisher -Offer $offer
						foreach ($skuObj in $skus)
						{
							$sku = $skuObj.Skus
							Write-Verbose "Getting VMImage for publisher:$publisher , Offer:$offer , sku:$sku , location: $location"
							$images = Get-AzureRmVMImage -Location $location -PublisherName $publisher -Offer $offer -sku $sku
							$versions = $images.Version
							if ($versions.Count -le 1)
							{
								$versions = @($versions)
							}
							$skuDict = @{"skuName" = $sku; "versions" = $versions}
							$skuList.Add($skuDict) | Out-Null
						}

						$offerDict = @{ "offerName" = $offer; "skus" = $skuList }
						$offerList.Add($offerDict) | Out-Null
					}

					$publisherDict = @{ "publisherName" = $publisher; "offers"= $offerList;"location" = $location }
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
							Write-Verbose "Getting VMExtension for publisher:$publisher , Type:$type , location: $location"
							$extensions = Get-AzureRmVMExtensionImage -Location $location -PublisherName $publisher -Type $type
							$versions = $extensions.Version
							if ($versions.Count -le 1)
							{
								$versions = @($versions)
							}
							$typeDict = @{ "type" = $type; "versions" = $versions }
							$typeList.Add($typeDict) | Out-Null
						}
						$publisherDict = @{ "publisher" = $publisher; "types" = $typeList;"location" = $location }
						$extensionList.Add($publisherDict) | Out-Null
					}
					else
					{
						"none @ " + $publisher
					}
				}
			}
			$capabilities.Add("VMExtensions", $extensionList)
			$capabilities.Add("VMImages", $imageList)
		}
	}
	if ($IncludeStorageCapabilities)
	{
		Write-Verbose "Getting Storage Sku supported for $location"
		try
		{
			$storageSkus = Get-AzureRmResource -ResourceType "Microsoft.Storage/Skus" -ResourceName "/"
			if ($storageSkus)
			{
				$skuList = New-Object System.Collections.ArrayList
				$storageKind = $storageSkus| Select-Object Kind | Get-Unique -AsString
				foreach ($kind in $storageKind.Kind)
				{
					$skus= ($storageSkus | Where-Object { $_.Kind -eq $kind }).Name
					$kindDict = @{ "kind" = $kind; "skus" = $skus }
					$skuList.Add($kindDict) | Out-Null
				}
				$capabilities.Add("StorageSkus",  $skuList)
			}
			else
			{
				Write-Verbose "No StorageSkus found for $location"
			}
		}
		catch
		{
			Write-Error "Error occurred processing StorageSkus for $location. Exception: " $_.Exception.Message
		}
	}
	$capabilitiesJson = ConvertTo-Json $capabilities -Depth 10
	$capabilitiesJson | Out-File $OutputPath

	$sw.Stop()
	$time = $sw.Elapsed
	"Cloud Capabilities JSON Generation Complete"
	"Time Elapsed = " + [math]::floor($time.TotalMinutes) + " min " + $time.Seconds + " sec"
}

function Compare-AzureRMCloudCapabilities()
{
	[CmdletBinding()]
    Param(
		[Parameter(Mandatory=$true, HelpMessage = 'Cloud A Capabilties File Path. This cloud will be the comparison superset.')]
        [String] $aPath,

		[Parameter(Mandatory=$true, HelpMessage= 'Cloud B Capabilties File Path. ')]
		[String] $bPath,

		[Parameter(HelpMessage = 'Restrict the cloud comparision to only provider namespaces available in Cloud B')]
		[Switch] $restrictNamespaces,

        [Parameter(HelpMessage = 'Restrict the cloud comparision to only namespaces specified')]
		[array] $comparisonNamespaces,

        [Parameter(HelpMessage = 'Restrict the comparison to top level resources and do not examine nested resources')]
		[Switch] $excludeNestedResources
    )

    $cloudACapabilities = ConvertFrom-Json (Get-Content -Path $aPath -Raw) -ErrorAction Stop
    $cloudBCapabilities = ConvertFrom-Json (Get-Content -Path $bPath -Raw) -ErrorAction Stop

    Write-Verbose "Loaded cloud A and B capabilities."
    Write-Verbose "Now comparing..."

    $commonResources = @()
    $AonlyResources = @()
    $namespaces = @()

    if($comparisonNamespaces){
        $namespaces = $comparisonNamespaces
    }elseif ($restrictNamespaces) {
        $namespaces = @()
        foreach ($bResource in $cloudBCapabilities.resources) {
            $namespaces += $bResource.providerNameSpace
        } 
    }

    # Look for common resources and resources only available in cloud A
    foreach ($aResource in $cloudACapabilities.resources) {
        $validResourceToMatch = $false
        if($namespaces){
            #Check for whether this is in a valid Provider Namespace
            if($aResource.providerNameSpace -iin $namespaces){
                #Check to see if this is a nested resource and whether it should be accounted for
                if($excludeNestedResources -and ($aResource.ResourcetypeName -like "*/*")){
                    $validResourceToMatch = $false
                }else{
                    $validResourceToMatch = $true
                }

            }
        }else{
            #Check to see if this is a nested resource and whether it should be accounted for
            if($excludeNestedResources -and ($aResource.ResourcetypeName -like "*/*")){
                $validResourceToMatch = $false
            }else{
                $validResourceToMatch = $true
            }
        }
        if($validResourceToMatch){
            $bResource = $cloudBCapabilities.resources | Where-Object { $_.providerNameSpace -eq $aResource.providerNameSpace } | Where-Object { $_.ResourcetypeName -eq $aResource.ResourcetypeName }
            $commonAPIVersions = @()
            $aOnlyAPIVersions = @()
            $bOnlyAPIVersions = @()
            $validCommonResource = $false
            if($bResource){
                $commonAPIVersions = Compare-Object -ReferenceObject $aResource.ApiVersions -DifferenceObject $bResource.ApiVersions -IncludeEqual -ExcludeDifferent -PassThru
                $aOnlyAPIVersions = Compare-Object -ReferenceObject $aResource.ApiVersions -DifferenceObject $bResource.ApiVersions -PassThru | Where-Object { $_.SideIndicator -eq "<=" }
                $bOnlyAPIVersions = Compare-Object -ReferenceObject $aResource.ApiVersions -DifferenceObject $bResource.ApiVersions -PassThru | Where-Object { $_.SideIndicator -eq ">=" }

                if($commonAPIVersions){
                    $validCommonResource = $true
                }else{
                    Write-Verbose "A resource has been found as common, but without common API versions between clouds A and B"
                }
            }
            if($validCommonResource){
                #Construct common resource object
                $commonResource = $bResource
                $commonResource | Add-Member NoteProperty aOnlyAPIVersions($aOnlyAPIVersions)
                $commonResource | Add-Member NoteProperty bOnlyAPIVersions($bOnlyAPIVersions)
                $commonResource | Add-Member NoteProperty commonAPIVersions($commonAPIVersions)
                $commonResource = $commonResource  | Select-Object -Property * -ExcludeProperty ApiVersions
                $commonResource.locations += $aResource.locations
                
                #Find latest common API version
                $latestCommonAPIVersion = [datetime]::ParseExact("1900-01-01",'yyyy-MM-dd',$null)
                foreach ($version in $commonAPIVersions){
                    #Replace preview versions
                    $shortVersion = $version -replace "-preview",""
                    $dateVersion = [datetime]::ParseExact($shortVersion,'yyyy-MM-dd',$null)
                    if($dateVersion -gt $latestCommonAPIVersion){
                        $latestCommonAPIVersion = $shortVersion
                    }
                }

                #Count API versions in A ahead of the latest common version
                if($aOnlyAPIVersions){
                    $versionDiffCount = 0
                    $latestAonlyAPIVersion = [datetime]::ParseExact("1900-01-01",'yyyy-MM-dd',$null)
                    foreach ($version in $aOnlyAPIVersions){
                        #Replace preview versions
                        $shortVersion = $version -replace "-preview",""
                        $dateVersion = [datetime]::ParseExact($shortVersion,'yyyy-MM-dd',$null)
                        
                        #Preview versions should be considered previous to non-preview versions of the same date
                        #Only preview versions will be equal because other equal versions are filtered previously with Compare-Object
                        if($dateVersion -ge $latestCommonAPIVersion){
                            $versionDiffCount++
                        }

                        #Keep track of the date of the latest API version available only in Cloud A so that a time span can be completed
                        if($dateVersion -gt $latestAonlyAPIVersion){
                            $latestAonlyAPIVersion = $shortVersion
                        }
                    } 
                }

                $commonResource | Add-Member NoteProperty APIVersionsBehindA($versionDiffCount)

                #Compute timespan between latest API version available in A and the latest commonly available version
                $APIVersionTimeDelta = New-Timespan -Start $latestCommonAPIVersion -End $latestAonlyAPIVersion
                $TimeDeltaMonths = $APIVersionTimeDelta.Days / 30.5;
                if($TimeDeltaMonths -ge 0){
                    $commonResource | Add-Member NoteProperty TimeDeltaBehindAMonths($TimeDeltaMonths)
                }else{
                    $commonResource | Add-Member NoteProperty TimeDeltaBehindAMonths(0)
                }


                $commonResources += $commonResource
            }else{
                $AonlyResources+= $aResource
            }
        }
    }


    Write-Output "Common resources available in both clouds:"
    $commonResources.count
    foreach ($commonResource in $commonResources) {
        $commonResource.locations = $commonResource.locations -join ","
        $commonResource.commonAPIVersions = $commonResource.commonAPIVersions -join ","
        $commonResource.aOnlyAPIVersions = $commonResource.aOnlyAPIVersions -join ","
        $commonResource.bOnlyAPIVersions = $commonResource.bOnlyAPIVersions -join ","
    }
    $commonResources | Export-Csv "CommonResources.csv" -NoTypeInformation

    Write-Output "--------------------------------------"

    Write-Output "Resources only available in Cloud A:"
    $AonlyResources.count
    foreach ($AonlyResource in $AonlyResources) {
        $AonlyResource.locations = $AonlyResource.locations -join ","
        $AonlyResource.apiVersions = $AonlyResource.apiVersions -join ","
    }
    $AonlyResources | Export-Csv "AResources.csv" -NoTypeInformation

    Write-Output "Detailed resource comparison available in the AResources.csv file and the CommonResources.csv file."
}