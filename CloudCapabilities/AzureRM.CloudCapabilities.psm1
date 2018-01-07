# Copyright (c) Microsoft Corporation. All rights reserved.

# See LICENSE.txt in the project root for license information.

<#

    .SYNOPSIS

    Get Cloud Capabilities (ARM resources, Api-version, VM Extensions, VM Images, VMSizes etc) for Azure Stack and Azure.

#>

function Get-AzureRMCloudCapability() {
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [Parameter(HelpMessage = 'Json output file')]
        [String] $OutputPath = "AzureCloudCapabilities.Json",

        [Parameter(HelpMessage = 'Cloud Capabilities for the specified location')]
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
    foreach ($providerNamespace in $providerNamespaces) {
        Write-Verbose "Working on $providerNamespace provider namespace"
        try {
            $resourceTypes = (Get-AzureRmResourceProvider -ProviderNamespace $providerNamespace -ErrorAction Stop).ResourceTypes
            foreach ($resourceType in $resourceTypes) {
                $result = "" | Select-Object ProviderNamespace, ResourceTypeName, Locations, ApiVersions
                $result.ProviderNamespace = $providerNamespace
                $result.ResourceTypeName = $resourceType.ResourceTypeName
                $result.Locations = $resourceType.Locations
                $result.ApiVersions = $resourceType.ApiVersions
                $resources += , $result
            }
        }
        catch {
            Write-Error "Error occurred processing $providerNamespace provider namespace.Exception: " $_.Exception.Message
        }
    }

    $capabilities = @{}
    $capabilities.Add("resources", $resources) | Out-Null

    if ($IncludeComputeCapabilities) {
        Write-Verbose "Getting VMSizes for $location"
        try {
            $vmSizes = (Get-AzureRmVMSize -Location $location -ErrorAction Stop| Where-Object {$_.Name -like "*"}).Name
            if ($vmSizes) {
                $capabilities.Add("VMSizes", $vmSizes)
            }
            else {
                Write-Verbose "No VMSizes found for $location"
            }
        }
        catch {
            Write-Error "Error occurred processing VMSizes for $location. Exception: " $_.Exception.Message
        }

        Write-Verbose "Getting VMImages and Extensions for location $location"
        try {
            $publishers = Get-AzureRmVMImagePublisher -Location $location | Where-Object { $_.PublisherName -like "*" }
        }
        catch {
            Write-Error "Error occurred processing VMimagePublisher for $location. Exception: " $_.Exception.Message
        }
        if ($publishers) {
            $imageList = New-Object System.Collections.ArrayList
            $extensionList = New-Object System.Collections.ArrayList
            foreach ($publisherObj in $publishers) {
                $publisher = $publisherObj.PublisherName
                $offers = Get-AzureRmVMImageOffer -Location $location -PublisherName $publisher
                if ($offers) {
                    $offerList = New-Object System.Collections.ArrayList
                    foreach ($offerObj in $offers) {
                        $offer = $offerObj.Offer
                        $skuList = New-Object System.Collections.ArrayList
                        $skus = Get-AzureRmVMImageSku -Location $location -PublisherName $publisher -Offer $offer
                        foreach ($skuObj in $skus) {
                            $sku = $skuObj.Skus
                            Write-Verbose "Getting VMImage for publisher:$publisher , Offer:$offer , sku:$sku , location: $location"
                            $images = Get-AzureRmVMImage -Location $location -PublisherName $publisher -Offer $offer -sku $sku
                            $versions = $images.Version
                            if ($versions.Count -le 1) {
                                $versions = @($versions)
                            }
                            $skuDict = @{"skuName" = $sku; "versions" = $versions}
                            $skuList.Add($skuDict) | Out-Null
                        }

                        $offerDict = @{ "offerName" = $offer; "skus" = $skuList }
                        $offerList.Add($offerDict) | Out-Null
                    }

                    $publisherDict = @{ "publisherName" = $publisher; "offers" = $offerList; "location" = $location }
                    $imageList.Add($publisherDict) | Out-Null
                }
                else {
                    $types = Get-AzureRmVMExtensionImageType  -Location $location -PublisherName $publisher
                    $typeList = New-Object System.Collections.ArrayList
                    if ($types) {
                        foreach ($type in $types.Type) {
                            Write-Verbose "Getting VMExtension for publisher:$publisher , Type:$type , location: $location"
                            $extensions = Get-AzureRmVMExtensionImage -Location $location -PublisherName $publisher -Type $type
                            $versions = $extensions.Version
                            if ($versions.Count -le 1) {
                                $versions = @($versions)
                            }
                            $typeDict = @{ "type" = $type; "versions" = $versions }
                            $typeList.Add($typeDict) | Out-Null
                        }
                        $publisherDict = @{ "publisher" = $publisher; "types" = $typeList; "location" = $location }
                        $extensionList.Add($publisherDict) | Out-Null
                    }
                    else {
                        "none @ " + $publisher
                    }
                }
            }
            $capabilities.Add("VMExtensions", $extensionList)
            $capabilities.Add("VMImages", $imageList)
        }
    }
    if ($IncludeStorageCapabilities) {
        Write-Verbose "Getting Storage Sku supported for $location"
        try {
            $storageSkus = Get-AzureRmResource -ResourceType "Microsoft.Storage/Skus" -ResourceName "/"
            if ($storageSkus) {
                $skuList = New-Object System.Collections.ArrayList
                $storageKind = $storageSkus| Select-Object Kind | Get-Unique -AsString
                foreach ($kind in $storageKind.Kind) {
                    $skus = ($storageSkus | Where-Object { $_.Kind -eq $kind }).Name
                    $kindDict = @{ "kind" = $kind; "skus" = $skus }
                    $skuList.Add($kindDict) | Out-Null
                }
                $capabilities.Add("StorageSkus", $skuList)
            }
            else {
                Write-Verbose "No StorageSkus found for $location"
            }
        }
        catch {
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
