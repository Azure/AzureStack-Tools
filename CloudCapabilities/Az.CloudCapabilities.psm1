# Copyright (c) Microsoft Corporation. All rights reserved.

# See LICENSE.txt in the project root for license information.

<#

    .SYNOPSIS

    Get Cloud Capabilities (ARM resources, Api-version, VM Extensions, VM Images, VMSizes etc) for Azure Stack and Azure.

#>

function Get-AzCloudCapability() {
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [Parameter(ParameterSetName = "local")]
        [Parameter(ParameterSetName = "url")]
        [Parameter(HelpMessage = 'Json output file')]
        [String] $OutputPath = "AzureCloudCapabilities.Json",

        [Parameter(ParameterSetName = "local")]
        [Parameter(ParameterSetName = "url")]
        [Parameter(HelpMessage = 'Cloud Capabilities for the specified location')]
        [String] $Location,

        [Parameter(Mandatory = $true, HelpMessage = "Directory containing api profile jsons for the supported api profiles. Use this parameter when running in a disconnected environment. Please save the api profile jsons from https://github.com/Azure/azure-rest-api-specs/tree/master/profile to a local directory and pass the location.", ParameterSetName = "local")]
        [ValidateScript( { Test-Path -Path $_  })]
        [String] $ApiProfilePath,

        [Parameter(HelpMessage = "Url pointing to the location of the supported api profiles", ParameterSetName = "url")]
        [String] $ApiProfilesUrl = "https://api.github.com/repos/Azure/azure-rest-api-specs/contents/profile",

        [Parameter(ParameterSetName = "local")]
        [Parameter(ParameterSetName = "url")]
        [Parameter(HelpMessage = 'Set this to get compute resource provider Capabilities like Extensions, Images, Sizes')]
        [Switch] $IncludeComputeCapabilities,

        [Parameter(ParameterSetName = "local")]
        [Parameter(ParameterSetName = "url")]
        [Parameter(HelpMessage = 'Set this to get storage resource provider Capabilities like Sku')]
        [Switch] $IncludeStorageCapabilities
    )

    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-Verbose "Getting CloudCapabilities for location: '$location'"

    $rootPath = $env:TEMP
    $fileDir = "ApiProfiles"
    $localDirPath = Join-Path -Path $rootPath -ChildPath $fileDir
    if(Test-Path($localDirPath))
    {
        Remove-Item -Path $localDirPath -Recurse -Force -ErrorAction Stop
    }
    New-Item -Path $rootPath -Name $fileDir -ItemType "directory"
    if ($PSCmdlet.ParameterSetName -eq "url")
    {
        Write-Verbose "Downloading api profile jsons from '$ApiProfilesUrl'"
        try {
            $content = Invoke-RestMethod -Method GET -UseBasicParsing -Uri $ApiProfilesUrl
            $webClient = [System.Net.WebClient]::new()
            foreach( $c in $content) {
                $destPath = Join-Path -Path $localDirPath -ChildPath $c.name
                $webClient.DownloadFile($c.download_url, $destPath)
            }
        }
        catch {
              $err = "Exception: Unable to get the api profile jsons. ApiProfilesUrl - $ApiProfilesUrl. $($_.Exception.Message)"
              Write-Error $err
        }
    }
    else
    {
        Write-Verbose "Using api profile jsons from local path: '$ApiProfilePath'"
        $localDirPath = $ApiProfilePath
    }
    Write-Verbose "Reading api profiles jsons..."
    $apiProfiles = @()
    if(Test-Path($localDirPath)) {
        $ApiProfilePattern = "*.json"
        $ProfilesDirectory = Get-ChildItem -Path $localDirPath -Recurse -Include $ApiProfilePattern
        foreach ($apiProfilejson in $ProfilesDirectory) { 
            $apiProfileFileName = Split-path -Path $apiProfilejson.FullName -Leaf
            Write-Verbose "Reading api profile $apiProfileFileName"
            $apiProfile = ConvertFrom-Json (Get-Content -Path $apiProfilejson -Raw) -ErrorAction Stop
            $apiProfileName = $apiProfile.info.name
            $apiProfiles += $apiProfile
        }
    }
    else {
        Write-Warning "Api profiles jsons not found!"
    }

    $providerNamespaces = (Get-AzResourceProvider -ListAvailable -Location $location -ErrorAction Stop).ProviderNamespace
    $resources = @()
    foreach ($providerNamespace in $providerNamespaces) {
        Write-Verbose "Working on $providerNamespace provider namespace"
        try {
            $resourceTypes = (Get-AzResourceProvider -ProviderNamespace $providerNamespace -ErrorAction Stop).ResourceTypes
            foreach ($resourceType in $resourceTypes) {
                $result = "" | Select-Object ProviderNamespace, ResourceTypeName, Locations, ApiVersions, ApiProfiles
                $result.ProviderNamespace = $providerNamespace
                $result.ResourceTypeName = $resourceType.ResourceTypeName
                $result.Locations = $resourceType.Locations
                $result.ApiVersions = $resourceType.ApiVersions
                $profileNames = @()
                foreach ($apiProfile in $apiProfiles) {
                    #if $resourceType.ResourceTypeName exists in $apiProfile add $apiProfile.info.name to $profileNames
                    $apiProfileProviderNamespace = $apiProfile.'resource-manager'.$providerNamespace
                    if($null -ne ($apiProfileProviderNamespace.Psobject.Properties | % { $_.value } | ? { $_ -eq $resourceType.ResourceTypeName } )) {
                        $profileNames += $apiProfile.info.name
                    }
                }
                $result.ApiProfiles = $profileNames
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
            $vmSizes = (Get-AzVMSize -Location $location -ErrorAction Stop| Where-Object {$_.Name -like "*"}).Name
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
            $publishers = Get-AzVMImagePublisher -Location $location | Where-Object { $_.PublisherName -like "*" }
        }
        catch {
            Write-Error "Error occurred processing VMimagePublisher for $location. Exception: " $_.Exception.Message
        }
        if ($publishers) {
            $imageList = New-Object System.Collections.ArrayList
            $extensionList = New-Object System.Collections.ArrayList
            foreach ($publisherObj in $publishers) {
                $publisher = $publisherObj.PublisherName
                $offers = Get-AzVMImageOffer -Location $location -PublisherName $publisher
                if ($offers) {
                    $offerList = New-Object System.Collections.ArrayList
                    foreach ($offerObj in $offers) {
                        $offer = $offerObj.Offer
                        $skuList = New-Object System.Collections.ArrayList
                        $skus = Get-AzVMImageSku -Location $location -PublisherName $publisher -Offer $offer
                        foreach ($skuObj in $skus) {
                            $sku = $skuObj.Skus
                            Write-Verbose "Getting VMImage for publisher:$publisher , Offer:$offer , sku:$sku , location: $location"
                            $images = Get-AzVMImage -Location $location -PublisherName $publisher -Offer $offer -sku $sku
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
                    $types = Get-AzVMExtensionImageType  -Location $location -PublisherName $publisher
                    $typeList = New-Object System.Collections.ArrayList
                    if ($types) {
                        foreach ($type in $types.Type) {
                            Write-Verbose "Getting VMExtension for publisher:$publisher , Type:$type , location: $location"
                            $extensions = Get-AzVMExtensionImage -Location $location -PublisherName $publisher -Type $type
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
            $storageSkus = Get-AzResource -ResourceType "Microsoft.Storage/Skus" -ResourceName "/"
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