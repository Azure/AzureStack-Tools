# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
    .SYNOPSIS
    List all Azure Marketplace Items available for syndication and allows to download them
    Requires an Azure Stack System to be registered for the subscription used to login
#>

function Export-AzSOfflineMarketplaceItem {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $azureContext = (Get-AzureRmContext),

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [String] $resourceGroup = "azurestack",

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 128)]
        [Int] $AzCopyDownloadThreads,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $destination,

        [Parameter(Mandatory = $false, ParameterSetName = 'SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $azCopyPath
    )

    $params = @{
        resourceGroup       = $resourceGroup
        destination         = $destination
        resourceProvider    = $false
        azureContext        = $azureContext
    }
    if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
        $params.AzCopyDownloadThreads = $AzCopyDownloadThreads
    }
    if ($PSBoundParameters.ContainsKey('azCopyPath')) {
        $params.azCopyPath = $azCopyPath
    }

    Export-AzSOfflineProductInternal @params
}

<#
    .SYNOPSIS
    List all Azure Resource Providers available for syndication and allows to download them
    Requires an Azure Stack System to be registered for the subscription used to login
#>

function Export-AzSOfflineResourceProvider {
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $azureContext = (Get-AzureRmContext),

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [String] $resourceGroup = "azurestack",

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 128)]
        [Int] $AzCopyDownloadThreads,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $destination,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [String] $azCopyPath
    )

    $params = @{
        resourceGroup       = $resourceGroup
        destination         = $destination
        resourceProvider    = $true
        azureContext        = $azureContext
    }
    if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads'))
    {
        $params.AzCopyDownloadThreads = $AzCopyDownloadThreads
    }
    if ($PSBoundParameters.ContainsKey('azCopyPath'))
    {
        $params.azCopyPath = $azCopyPath
    }

    Export-AzSOfflineProductInternal @params
}

function Export-AzSOfflineProductInternal {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $azureContext,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $resourceGroup,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 128)]
        [Int] $AzCopyDownloadThreads,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $destination,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [String] $azCopyPath,
        
        [Parameter(Mandatory = $true)]
        [Switch] $resourceProvider
    )

    # in case it is relative path
    $destination = Resolve-Path -Path $destination

    $azureSubscriptionID = $azureContext.Subscription.Id
    $azureEnvironment = $azureContext.Environment

    # Retrieve the access token
    $accessToken = Get-AccessTokenFromContext -azureContext $azureContext
    
    $params = @{
        azureEnvironment        = $azureEnvironment
        azureSubscriptionID     = $azureSubscriptionID
        accessToken             = $accessToken
        resourceGroup           = $resourceGroup
        resourceProvider        = $resourceProvider
    }
    $aggregatedProducts = Get-ProductsList @params

    $productObjects = [pscustomobject[]]@()
    foreach ($product in $aggregatedProducts) {
        if ($product.VersionEntries.length -eq 1) {
            $version = $product.VersionEntries[0].version
            $size = $product.VersionEntries[0].Size
        }
        else {
            $version = "Multiple versions"
            $size = "--"
        }

        $productObjects += ([pscustomobject]@{
            Name        = $product.Name
            Id          = $product.ProductName
            Type        = $product.Type
            Publisher   = $product.Publisher
            Version     = $version
            Size        = $size
        })
    }

    if (-not $productObjects) {
        Write-Warning "There is not existing products from Azure, please check your subscription"
        return
    }

    $selectionWindowsTitle = 'Download marketplace items from Azure'
    if ($resourceProvider) {
        $selectionWindowsTitle = 'Download resource providers from Azure'
    }
    
    $selectedProducts = OutGridViewWrapper -InputObject $productObjects -Title $selectionWindowsTitle
    foreach ($selectedProduct in $selectedProducts) {
        $versionEntries = ($aggregatedProducts | Where ProductName -eq $selectedProduct.Id).VersionEntries

        $getDependencyParam = @{
            azureEnvironment    = $azureEnvironment
            accessToken         = $accessToken
            destination         = $destination
        }

        if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
            $getDependencyParam.AzCopyDownloadThreads = $azCopyDownloadThreads
        }
        if ($PSBoundParameters.ContainsKey('azCopyPath')) {
            $getDependencyParam.azCopyPath = $azCopyPath
        }

        if ($versionEntries.length -eq 1) {
            $getDependencyParam.productid = $versionEntries[0].ProductId
            $getDependencyParam.productResourceId = $versionEntries[0].ProductResourceId
            Get-DependenciesAndDownload @getDependencyParam
        }
        else {
            $versionObjects = foreach ($versionObject in $versionEntries) {
                Write-output ([pscustomobject]@{
                    Name        = $selectedProduct.Name  # Product Name
                    "Product Id"= $selectedProduct.Id
                    Version     = $versionObject.Version
                    Size        = $versionObject.Size
                })
            }

            OutGridViewWrapper -InputObject $versionObjects -Title "Select version for $($selectedProduct.Id)" | foreach {
                $getDependencyParam.productid = "$($selectedProduct.Id)-$($_.Version)"
                $getDependencyParam.ProductResourceId = ($versionEntries | where ProductId -eq $getDependencyParam.productid).ProductResourceId

                Get-DependenciesAndDownload @getDependencyParam
            }
        }
    }
}

function OutGridViewWrapper {
    param (
        [parameter(mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $Title,

        [pscustomobject[]] $InputObject
    )

    return ($InputObject | Out-GridView -Title $Title -PassThru)
}

function Get-AccessTokenFromContext {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $azureContext
    )

    $azureTenantID = $azureContext.Tenant.TenantId
    $azureSubscriptionID = $azureContext.Subscription.Id
    $azureEnvironment = $azureContext.Environment

    # Retrieve the access token
    $tokens = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache.ReadItems()
    $token = $tokens |Where Resource -EQ $azureEnvironment.ActiveDirectoryServiceEndpointResourceId |Where DisplayableId -EQ $azureContext.Account.id |Where TenantID -EQ $azureTenantID |Sort ExpiresOn |Select -Last 1

    return $token.AccessToken
}

function Get-DependenciesAndDownload {
    param (
        [parameter(mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $productid,

        [parameter(mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $productResourceId,

        [parameter(mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [Object] $azureEnvironment,

        [parameter(mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $accessToken,

        [parameter(mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $destination,

        [parameter(mandatory = $false)]
        [ValidateRange(1, 128)]
        [Int] $azCopyDownloadThreads,

        [Parameter(mandatory = $false)]
        [String] $azCopyPath
    )

    $headers = @{ 'authorization' = "Bearer $accessToken"}
    $uri = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/$productResourceId/listDetails?api-version=2016-01-01"
    $downloadDetails = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -TimeoutSec 180

    if ($downloadDetails.properties.dependentProducts)
    {
        foreach ($dependentProductId in $downloadDetails.properties.dependentProducts)
        {
            $dependentProductResourceId = $productResourceId.replace($productId, $dependentProductId)
            $getDependencyParam = @{
                productId           = $dependentProductId
                productResourceId   = $dependentProductResourceId
                azureEnvironment    = $azureEnvironment
                accessToken         = $accessToken
                destination         = $destination
            }
            if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                $getDependencyParam.azCopyDownloadThreads = $azCopyDownloadThreads
            }
            if ($PSBoundParameters.ContainsKey('azCopyPath')) {
                $getDependencyParam.azCopyPath = $azCopyPath
            }

            Get-DependenciesAndDownload @getDependencyParam
        }
    }

    $productFolder = "$destination\$productid"
    $destinationCheck = Test-Path $productFolder
    if ($destinationCheck) {
        $productJsonFile = "$productFolder\$productid.json"
        $jsonFileCheck = Test-Path $productJsonFile
        if ($jsonFileCheck) {
            Write-Warning "$productid already exists at $destination\$productid, skip download."
            return
        }
    }

    Write-Host "`nDownloading product: $productid" -ForegroundColor DarkCyan
    $downloadProductParam = @{
        productid           = $productid
        productResourceId   = $productResourceId
        azureEnvironment    = $azureEnvironment
        accessToken         = $accessToken
        destination         = $destination
    }
    if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
        $downloadProductParam.azCopyDownloadThreads = $azCopyDownloadThreads
    }
    if ($PSBoundParameters.ContainsKey('azCopyPath')) {
        $downloadProductParam.azCopyPath = $azCopyPath
    }
    Download-Product @downloadProductParam
}

function ValidateOrGetAzCopyPath($azCopyPath) {
    # getting azcopy path from environment variables user didn't provide azCopyPath parameter 
    if ([string]::IsNullOrEmpty($azCopyPath)){ 
        $azCopyPath = (Get-Command 'azcopy' -ErrorAction Ignore).Source
        if ([string]::IsNullOrEmpty($azCopyPath)){
            return $null
        }
    }else{
        # if user just provided the directory containing azcopy.exe
        if (-not ($azCopyPath -match ".exe$")){ $azCopyPath = $azCopyPath.TrimEnd("\")+"\azcopy.exe" }
    }
    try{
        # invoking azcopy command to validate if it exists and getting info such as version
        $azCopyInfo = & $azCopyPath
        # getting version data from other details
        $azCopyVersion = $azCopyInfo | Where-Object {$_ -match "AzCopy [0-9]+\.[0-9]+\.[0-9]+"} | Foreach {$matches[0]}
        # checking if the AzCopy V10 is being used or not
        if (-not ($azCopyVersion -match "10\.[0-9]+\.[0-9]+")){
            Write-Verbose "$azCopyVersion is not compatible with this script." -verbose
            return $null
        }
    }catch{
        Write-Verbose "$azCopyPath doesn't exist." -verbose
        return $null
    }
    return $azCopyPath
}

function Download-Product {
    param (
        [parameter(mandatory = $true)]
        [String] $productid,

        [parameter(mandatory = $true)]
        [String] $productResourceId,

        [parameter(mandatory = $true)]
        [Object] $azureEnvironment,

        [parameter(mandatory = $true)]
        [string] $accessToken,

        [parameter(mandatory = $true)]
        [String] $destination,

        [parameter(mandatory = $false)]
        [ValidateRange(1, 128)]
        [Int] $azCopyDownloadThreads,

        # Get the path of AzCopy executable if path is set in Environment variables
        [parameter(mandatory = $false)]
        [String] $azCopyPath
    )

    # get name of azpkg
    $azpkgURI = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/$($productResourceId)?api-version=2016-01-01"
    Write-Debug $azpkgURI
    $headers = @{ 'authorization' = "Bearer $accessToken"}
    $productDetails = Invoke-RestMethod -Method GET -Uri $azpkgURI -Headers $headers -TimeoutSec 180
    $azpkgName = $productDetails.properties.galleryItemIdentity
    if (!$azpkgName) {
        $azpkgName = $productid
    }

    # get download location for azpkg
    $downloadURI = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/$productResourceId/listDetails?api-version=2016-01-01"
    Write-Debug $downloadURI
    $downloadDetails = Invoke-RestMethod -Method POST -Uri $downloadURI -Headers $headers -TimeoutSec 180

    # create Legal Terms POPUP
    $legalTitle = "Legal Terms"
    $legalText = $productDetails.properties.description -replace '<[^>]+>',''
    Write-Host $("-"*20)
    Write-Host "$legalTitle`n$legalText" -ForegroundColor DarkYellow
    $confirmation = Read-Host "Accept Legal Terms. (Y/N)?"
    if ($confirmation -eq 'Y') {
        $productFolder = "$destination\$productid"

        # output parameters required for import
        $fileExists = Test-Path "$productFolder\$azpkgName.txt"
        $destinationCheck = Test-Path $productFolder
        if ($destinationCheck -eq $false) {
            New-item -ItemType Directory -force $productFolder | Out-Null
        }

        if ($fileExists) {
            Remove-Item "$productFolder\$azpkgName.txt" -force -ErrorAction SilentlyContinue | Out-Null
        } else {
            New-Item "$productFolder\$azpkgName.txt" | Out-Null
        }

        if ($fileExists) {
            Remove-Item "$productFolder\$azpkgName.json" -force -ErrorAction SilentlyContinue | Out-Null
        }

        $productInfo = @{}
        $productInfo['displayName'] = $productDetails.properties.displayName
        $productInfo['description'] = $productDetails.properties.description
        $productInfo['publisherDisplayName'] = $productDetails.properties.publisherDisplayName
        $productInfo['publisherIdentifier'] = $productDetails.properties.publisherIdentifier
        $productInfo['offer'] = $productDetails.properties.offer
        $productInfo['offerVersion'] = $productDetails.properties.offerVersion
        $productInfo['sku'] = $productDetails.properties.sku
        $productInfo['billingPartNumber'] = $productDetails.properties.billingPartNumber
        $productInfo['vmExtensionType'] = $productDetails.properties.vmExtensionType
        $productInfo['legalTerms'] = $productDetails.properties.description
        $productInfo['payloadLength'] = $productDetails.properties.payloadLength
        $productInfo['galleryItemIdentity'] = $productDetails.properties.galleryItemIdentity
        $productInfo['productKind'] = $productDetails.properties.productKind
        $productInfo['productProperties'] = $productDetails.properties.productProperties
        $productDetailsProperties = @{}
        $productDetailsProperties['version'] = $downloadDetails.properties.version
        if ($downloadDetails.productKind -in ('solution', 'resourceProvider')){
            $productInfo['dependentProducts'] = $downloadDetails.properties.dependentProducts
            $containerIds = @()
            $containerIds += $downloadDetails.properties.fileContainers.Id
            $productInfo['fileContainers'] = $containerIds
            $productDetailsProperties['dependentProducts'] = $downloadDetails.properties.dependentProducts
            $productDetailsProperties['fileContainers'] = $downloadDetails.properties.fileContainers
        } elseif ($downloadDetails.productKind -eq 'virtualMachine') {
            $productDetailsProperties['OsDiskImage'] = $downloadDetails.properties.OsDiskImage
            $productDetailsProperties['DataDiskImages'] = $downloadDetails.properties.DataDiskImages
        } else {
            $productDetailsProperties['vmOsType'] = $downloadDetails.properties.vmOsType
            $productDetailsProperties['sourceBlob'] = $downloadDetails.properties.sourceBlob
            $productDetailsProperties['computeRole'] = $downloadDetails.properties.computeRole
            $productDetailsProperties['vmScaleSetEnabled'] = $downloadDetails.properties.vmScaleSetEnabled
            $productDetailsProperties['supportMultipleExtensions'] = $downloadDetails.properties.supportMultipleExtensions
            $productDetailsProperties['isSystemExtension'] = $downloadDetails.properties.isSystemExtension
        }

        $productInfo['links'] = $productDetails.properties.links
        $productInfo['iconUris'] = $productDetails.properties.iconUris
        $productInfo['galleryPackageBlobSasUri'] = $downloadDetails.galleryPackageBlobSasUri

        $productDetails.properties|select publisherIdentifier,offer,sku,productKind,vmExtensionType  |out-file "$productFolder\$azpkgName.txt" -Append
        $productDetails.properties.productProperties|select version| out-file "$productFolder\$azpkgName.txt" -Append

        # select premium download
        Write-Host $("-"*20)
        $downloadConfirmation = Read-Host "Downloading package files. Would you like to use Premium download? This requires Azure Storage Tools to be installed. (Y/N)?"
        # getting azcopy path from environment variables if premium download is selected and user didn't provide azCopyPath parameter 
        if ($downloadConfirmation -eq 'Y'){
            $azCopyPath = ValidateOrGetAzCopyPath($azCopyPath)
            if ([string]::IsNullOrEmpty($azCopyPath)) { 
                Write-Verbose "Please download AzCopy V10 and add its path to Environment variables path or pass AzCopy V10 path as an addtional parameter (-azCopyPath), canceling" -verbose
                return 
            }
        }

        if ($downloadDetails.productKind -ne 'resourceProvider')
        {
            # download azpkg
            $azpkgsource = $downloadDetails.galleryPackageBlobSasUri
            $fileExists = Test-Path "$productFolder\$azpkgName.azpkg"
            $destinationCheck = Test-Path $productFolder
            if ($destinationCheck -eq $false) {
                New-item -ItemType Directory -force $productFolder | Out-Null
            }

            if ($fileExists) {
                Remove-Item "$productFolder\$azpkgName.azpkg" -force | Out-Null
            }
            $azpkgdestination = "$productFolder\$azpkgName.azpkg"

            if ($downloadConfirmation -eq 'Y') {
                if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                    DownloadMarketplaceProduct -Source $azpkgsource -Destination $azpkgdestination -ProductName "$azpkgName.azpkg" -azCopyDownloadThreads $azCopyDownloadThreads -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                } else {
                    DownloadMarketplaceProduct -Source $azpkgsource -Destination $azpkgdestination -ProductName "$azpkgName.azpkg" -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                }
                "$productFolder\$azpkgName.azpkg"|out-file "$productFolder\$azpkgName.txt" -Append
            } else {
                DownloadMarketplaceProduct -Source $azpkgsource -Destination $azpkgdestination -ProductName "$azpkgName.azpkg" -MaxRetry 2
                "$productFolder\$azpkgName.azpkg"|out-file "$productFolder\$azpkgName.txt" -Append
            }
        }

        $iconsFolder = "$productFolder\Icons"
        $destinationCheck = Test-Path $iconsFolder
        if ($destinationCheck -eq $false) {
            New-item -ItemType Directory -force $iconsFolder | Out-Null
        }

        # download icons
        $icon = $productDetails.properties.iconUris
        if (Test-Path "$iconsFolder\hero.png") {Remove-Item "$iconsFolder\hero.png" -force -ErrorAction SilentlyContinue | Out-Null}
        if (Test-Path "$iconsFolder\large.png") {Remove-Item "$iconsFolder\large.png" -force -ErrorAction SilentlyContinue | Out-Null}
        if (Test-Path "$iconsFolder\medium.png") {Remove-Item "$iconsFolder\medium.png" -force -ErrorAction SilentlyContinue | Out-Null}
        if (Test-Path "$iconsFolder\small.png") {Remove-Item "$iconsFolder\small.png" -force -ErrorAction SilentlyContinue | Out-Null}
        if (Test-Path "$iconsFolder\wide.png") {Remove-Item "$iconsFolder\wide.png" -force -ErrorAction SilentlyContinue | Out-Null}

        if ($downloadConfirmation -eq 'Y') {
            if ($icon.hero) {
                if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                    DownloadMarketplaceProduct -Source "$($icon.hero)" -Destination "$iconsFolder\hero.png" -ProductName "hero.png" -azCopyDownloadThreads $azCopyDownloadThreads -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                } else {
                    DownloadMarketplaceProduct -Source "$($icon.hero)" -Destination "$iconsFolder\hero.png" -ProductName "hero.png" -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                }
                "$iconsFolder\hero.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.large) {
                if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                    DownloadMarketplaceProduct -Source "$($icon.large)" -Destination "$iconsFolder\large.png" -ProductName "large.png" -azCopyDownloadThreads $azCopyDownloadThreads -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                } else {
                    DownloadMarketplaceProduct -Source "$($icon.large)" -Destination "$iconsFolder\large.png" -ProductName "large.png" -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                }
                "$iconsFolder\large.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.medium) {
                if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                    DownloadMarketplaceProduct -Source "$($icon.medium)" -Destination "$iconsFolder\medium.png" -ProductName "medium.png" -azCopyDownloadThreads $azCopyDownloadThreads -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                } else {
                    DownloadMarketplaceProduct -Source "$($icon.medium)" -Destination "$iconsFolder\medium.png" -ProductName "medium.png" -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                }
                "$iconsFolder\medium.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.small) {
                if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                    DownloadMarketplaceProduct -Source "$($icon.small)" -Destination "$iconsFolder\small.png" -ProductName "small.png" -azCopyDownloadThreads $azCopyDownloadThreads -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                } else {
                    DownloadMarketplaceProduct -Source "$($icon.small)" -Destination "$iconsFolder\small.png" -ProductName "small.png" -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                }
                "$iconsFolder\small.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.wide) {
                if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                    DownloadMarketplaceProduct -Source "$($icon.wide)" -Destination "$iconsFolder\wide.png" -ProductName "wide.png" -azCopyDownloadThreads $azCopyDownloadThreads -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                } else {
                    DownloadMarketplaceProduct -Source "$($icon.wide)" -Destination "$iconsFolder\wide.png" -ProductName "wide.png" -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                }
                "$iconsFolder\wide.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            Write-Verbose "icons has been downloaded" -verbose
        } else {
            if ($icon.hero) {
                DownloadMarketplaceProduct -Source "$($icon.hero)" -Destination "$iconsFolder\hero.png" -ProductName "hero.png" -MaxRetry 2
                "$iconsFolder\hero.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.large) {
                DownloadMarketplaceProduct -Source "$($icon.large)" -Destination "$iconsFolder\large.png" -ProductName "large.png" -MaxRetry 2
                "$iconsFolder\large.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.medium) {
                DownloadMarketplaceProduct -Source "$($icon.medium)" -Destination "$iconsFolder\medium.png" -ProductName "medium.png" -MaxRetry 2
                "$iconsFolder\medium.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.small) {
                DownloadMarketplaceProduct -Source "$($icon.small)" -Destination "$iconsFolder\small.png" -ProductName "small.png" -MaxRetry 2
                "$iconsFolder\small.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.wide) {
                DownloadMarketplaceProduct -Source "$($icon.wide)" -Destination "$iconsFolder\wide.png" -ProductName "wide.png" -MaxRetry 2
                "$iconsFolder\wide.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            Write-Verbose "icons has been downloaded" -verbose
        }

        switch ($downloadDetails.productKind) {
            'virtualMachine' {
                # download vhd
                $vhdName = $productDetails.properties.galleryItemIdentity
                $vhdSource = $downloadDetails.properties.osDiskImage.sourceBlobSasUri
                if ([string]::IsNullOrEmpty($vhdsource)) {
                    throw "VM vhd source is empty"
                } else {
                    $fileExists = Test-Path "$productFolder\$vhdName.vhd"
                    if ($fileExists) {
                        Remove-Item "$productFolder\$vhdName.vhd" -force | Out-Null
                    }
                    $vhdDestination = "$productFolder\$vhdName.vhd"

                    if ($downloadConfirmation -eq 'Y') {
                        if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                            DownloadMarketplaceProduct -Source $vhdsource -Destination $vhddestination -ProductName "$vhdName.vhd" -azCopyDownloadThreads $azCopyDownloadThreads -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                        } else {
                            DownloadMarketplaceProduct -Source $vhdsource -Destination $vhddestination -ProductName "$vhdName.vhd" -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                        }
                        "$productFolder\$vhdName.vhd"|out-file "$productFolder\$azpkgName.txt" -Append
                    } else {
                        DownloadMarketplaceProduct -Source $vhdsource -Destination $vhddestination -ProductName "$vhdName.vhd" -MaxRetry 2
                    }
                    Write-Verbose "$vhdName.vhd has been downloaded" -verbose
                    "$productFolder\$vhdName.vhd"|out-file "$productFolder\$azpkgName.txt" -Append
                }
            }
            'virtualMachineExtension' {
                # download zip
                $zipName = $productDetails.properties.galleryItemIdentity
                $zipsource = $downloadDetails.properties.sourceBlob.uri
                if ([string]::IsNullOrEmpty($zipsource)) {
                    throw "VM extension zip source is empty"
                } else {
                    $fileExists = Test-Path "$productFolder\$zipName.zip"
                    if ($fileExists) {
                        Remove-Item "$productFolder\$zipName.zip" -force | Out-Null
                    }
                    $zipDestination = "$productFolder\$zipName.zip"

                    if ($downloadConfirmation -eq 'Y') {
                        if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                            DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "$zipName.zip" -azCopyDownloadThreads $azCopyDownloadThreads -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                        } else {
                            DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "$zipName.zip" -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                        }
                        "$productFolder\$zipName.zip"|out-file "$productFolder\$azpkgName.txt" -Append
                        $productDetailsProperties['sourceBlob'].uri = "$zipName.zip"
                    } else {
                        DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "$zipName.zip" -MaxRetry 2
                        "$productFolder\$zipName.zip"|out-file "$productFolder\$azpkgName.txt" -Append
                        $productDetailsProperties['sourceBlob'].uri = "$zipName.zip"
                    }
                }
            }

            {($_ -eq 'resourceProvider') -or ($_ -eq 'solution')} {
                # download zip
                foreach ($container in $downloadDetails.properties.fileContainers)
                {
                    $zipsource = $container.sourceUri
                    $containerName = $container.id
                    if ([string]::IsNullOrEmpty($zipsource)) {
                        throw "zip source is empty"
                    } else {
                        $zipDestination = "$productFolder\$containerName"
                        if ($container.type -match 'zip'){
                            $zipDestination = "$productFolder\$containerName.zip"
                        } else {
                            $zipuri = [uri]$zipsource
                            $fileName = $zipuri.Segments[-1]
                            $dotposition = $fileName.LastIndexOf('.')
                            if ($dotposition -ne -1)
                            {
                                $fileExtension = $fileName.Substring($dotposition+1)
                                $zipDestination = "$productFolder\$containerName.$fileExtension"
                            }
                        }

                        $fileExists = Test-Path $zipDestination
                        if ($fileExists) {
                            Remove-Item $zipDestination -force | Out-Null
                        }

                        if ($downloadConfirmation -eq 'Y') {
                            if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                                DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "Container [$containerName]" -azCopyDownloadThreads $azCopyDownloadThreads -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                            } else {
                                DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "Container [$containerName]" -azCopyPath $azCopyPath -PremiumDownload -MaxRetry 2
                            }
                            "$productFolder\$containerName"|out-file "$productFolder\$azpkgName.txt" -Append
                        } else {
                            DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "Container [$containerName]" -MaxRetry 2
                            "$productFolder\$containerName"|out-file "$productFolder\$azpkgName.txt" -Append
                        }
                    }
                }
            }

            Default {
                Write-Warning "Unknown product kind '$_'"
            }
        }

        $productInfo['productDetailsProperties'] = $productDetailsProperties
        $productInfo |ConvertTo-Json -Depth 99 |out-file "$productFolder\$productid.json"
        Write-Verbose "Download marketplace product finished" -verbose
    }
    else {
        Write-Verbose "Legal Terms not accepted, canceling" -verbose
    }
}

function DownloadMarketplaceProduct {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Uri] $source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [String] $destination,

        [Parameter(Mandatory = $true)]
        [String] $productName,

        [parameter(mandatory = $false)]
        [ValidateRange(1, 128)]
        [Int] $azCopyDownloadThreads,

        [Parameter(Mandatory = $false)]
        [Switch] $premiumDownload,

        [Parameter(Mandatory = $false)]
        [object] $maxRetry = 1,

        [Parameter(Mandatory = $false)]
        [String] $azCopyPath
    )

    $content = $null
    $response = $null
    $completed = $false
    $retryCount = 0
    $sleepSeconds = 5
    $tmpDestination = "$destination.marketplace"

    if ($source -notmatch 'windows.net')
    {
        $premiumDownload = $false
        Write-Verbose "$source is not in storage account, use regular download" -verbose
    }

    while (-not $completed) {
        try {
            if ($PremiumDownload) {
                Write-Verbose "azCopyPath: $azCopyPath" -Verbose
                if ($PSBoundParameters.ContainsKey('azCopyDownloadThreads')) {
                    $env:AZCOPY_CONCURRENCY_VALUE = $azCopyDownloadThreads
                    & $azCopyPath copy $Source $tmpDestination --recursive
                } else {
                    & $azCopyPath copy $Source $tmpDestination --recursive
                }
                ## Check $LastExitcode to see if AzCopy Succeeded 
                if ($LastExitCode -ne 0) {
                    $downloadError = $_
                    Write-Error "Unable downloading files using AzCopy: $downloadError LastExitCode: $LastExitCode" -ErrorAction Stop
                }
            } else {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($source, $tmpDestination)
            }

            $completed = $true
            Write-Verbose "[$productName] has been downloaded" -verbose
        }
        catch
        {
            if ($retryCount -ge $maxRetry) {
                Write-Warning "Request to download from $source failed the maximum number of $maxRetry times."
                throw
            } else {
                Write-Warning "Request to download from $source failed. Retrying in $sleepSeconds seconds."
                Start-Sleep $sleepSeconds
                $retryCount++
            }
        }
    }

    Move-Item -Path $tmpDestination -Destination $destination -Force
}

<#
    .SYNOPSIS
    Import all Azure Marketplace Items available for upload. These marketplace items should
    be downloaded from Export-AzSOfflineMarketplaceItem step.
#>

function Import-AzSOfflineMarketplaceItem
{
    param (
        [parameter(mandatory = $true)]
        [ValidateNotNull()]
        [String] $origin,

        [Parameter(Mandatory = $false)]
        [PSCredential] $azsCredential
    )

    if (-not (Test-Path $origin)) {
        throw "$origin not exist."
    }
    if ((Get-Item $origin) -isnot [System.IO.DirectoryInfo]) {
        throw "$origin is not folder."
    }

    Get-AzureRmSubscription | Out-Null
    $defaultProviderSubscription = Select-AzureRmSubscription -SubscriptionName 'Default Provider Subscription'

    $resourceGroup = "System.syndication"
    $dirs = Get-ChildItem -Path $origin
    $importedProducts  = New-Object System.Collections.Generic.HashSet[string]

    PreCheck -contentFolder $origin

    $ctx = Get-AzureRmContext
    $accessToken = Resolve-AccessToken -Context $ctx -AccessToken $accessToken
    $headers = @{ 'authorization' = "Bearer $accessToken"}
    $armEndpoint = $ctx.Environment.ResourceManagerUrl

    foreach($dir in $dirs)
    {
        Import-ByDependency -contentFolder $origin -productid $dir -resourceGroup $resourceGroup -armEndpoint $armEndpoint -defaultProviderSubscription $defaultProviderSubscription.subscription.id -headers ([ref]$headers) -importedProducts $importedProducts -azsCredential $azsCredential
    }

    # remove note resource group
    Get-AzureRmResourceGroup -Name $resourceGroup -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if(!$notPresent)
    {
        Write-Verbose "Removing temporary resource group '$resourceGroup'..." -verbose
        Remove-AzureRmResourceGroup -Name $resourceGroup -Force | Out-Null
    }

    Write-Verbose "Import marketplace product finished" -verbose
}

function PreCheck
{
    param (
        [parameter(mandatory = $true)]
        [String] $contentFolder
    )

    $dirs = Get-ChildItem -Path $contentFolder
    $iconsFolder = Join-Path -Path $contentFolder -ChildPath "Icons"

     # Check if the user specified marketplace item folder instead of parent directory
     if(Test-Path -Path $iconsFolder -PathType Container)
     {
        $message = @"
        `r`nImport-AzSOfflineMarketplaceItem requires specified content folder (specified with -origin parameter) to have 1 or more downloaded product folders. 
        Each product folder should contain a product definition json file.  
        E.g. product folder c:\downloads\product1 should contain c:\downloads\product1\product1.json 
        Please specifiy correct top level folder that contains the list of downloaded products.
"@
         Write-Verbose -Message "$message" -Verbose
         throw "$message"
     }
 
    foreach ($dir in $dirs)
    {
        $folderPath = $contentFolder + "\$dir"
        $jsonFileExists = Test-Path "$folderPath\$dir.json"
        if ($jsonFileExists -eq $False) {
            throw "json file not exist for product '$dir'. Please download '$dir' again, then import"
        }

        $originFileExists = Test-Path "$folderPath\$dir.json.origin"
        if ($originFileExists -eq $True) {
            Write-Warning "$dir.json.origin exists, you have probably run import before, if you want to import again, please replace $dir.json with $dir.json.origin, then run import"
            throw "$dir.json.origin file exists"
        }

        $tmpfileExists = (Test-Path "$folderPath\*.marketplace") -or (Test-Path "$folderPath\icons\*.marketplace")
        if ($tmpfileExists -eq $True) {
            Write-Warning ".marketplace file exists, these are temp files not fully downloaded. Please download product '$dir' again, then retry import"
            throw ".marketplace file exists"
        }

        ## Validate Json 
        $jsonPath = "$folderPath\$dir.json"
        $configuration = Get-Content $jsonPath | ConvertFrom-Json 
        $properties = ($configuration | Get-Member -MemberType NoteProperty).Name
        ## define required properties
        $requiredprops = @("displayName","publisherDisplayName","publisherIdentifier", "productProperties", "payloadLength", "iconUris", "productKind" )
        foreach ($property in $requiredprops) {
            if (-not [string]::IsNullOrEmpty($configuration.$property)) {
                Write-Verbose -Message "$property = $($configuration.$property)"              
            }
            else
            {
                $errorMessage = "`r`nProperty value for $property is null. Please check JSON contents, then retry import"
                $errorMessage += "`r`nJSON file contains null values for required properties: $($properties)"
                Write-Error -Message $errorMessage -ErrorAction Stop
            }
        }

        $iconUris = $configuration.iconUris
       
        if ($iconUris.small -eq $null -or $iconUris.large -eq $null -or $iconUris.medium -eq $null -or $iconUris.wide -eq $null )
        {
            $errorMessage = "`r`nProperty value for certain Icons is null. Please check JSON contents, then retry import."
            $errorMessage += "`r`nJSON file contains null values for certain Icons. Please ensure small, medium, large and wide icons exist in the JSON."
            Write-Error -Message $errorMessage -ErrorAction Stop
        }
    }
}

function Import-ByDependency
{
    param (
        [parameter(mandatory = $true)]
        [String] $contentFolder,
        
        [parameter(mandatory = $true)]
        [String] $productid,

        [parameter(mandatory = $true)]
        [String] $resourceGroup,

        [parameter(mandatory = $true)]
        [String] $armEndpoint,

        [parameter(mandatory = $true)]
        [String] $defaultProviderSubscription,

        [Parameter(mandatory = $true)]
        [object] [ref]$headers,

        [parameter(mandatory = $true)]
        [Object] $importedProducts,

        [Parameter(Mandatory = $false)]
        [PSCredential] $azsCredential
    )

    if ($importedProducts.contains($productid)) {
        Write-Debug "$productid already imported"
        return
    }

    $syndicateUri = [string]::Format("{0}/subscriptions/{1}/resourceGroups/azurestack-activation/providers/Microsoft.AzureBridge.Admin/activations/default/downloadedProducts/{2}?api-version=2016-01-01",
        $armEndpoint,
        $defaultProviderSubscription,
        $productid
    )

    try {
        $getStateResponse = Invoke-WebRequest -Method GET -Uri $syndicateUri -ContentType "application/json" -Headers $headers -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if ($getStateResponse -and $getStateResponse.Content) {
            $content = $getStateResponse.Content | convertFrom-json
            if ($content.properties.provisioningState -eq 'Succeeded') {
                Write-Verbose "Marketplace product '$productid' was syndicated, skip import" -verbose
                return
            }
        }
    }
    catch
    {
        if ($_.Exception.Response.StatusCode -ne 404)
        {
            Write-Warning -Message "Failed to execute web request: Exception: $($_.Exception)" 
        }
    }

    Write-Verbose "Importing product '$productid' ..." -verbose
    $folderPath = $contentFolder + "\$productid"
    if (-not (Test-Path $folderPath)) {
        throw "Folder $folderPath not exist."
    }
    $jsonFile = Get-Content "$folderPath\$productid.json"
    $properties = $jsonFile | ConvertFrom-Json
    if ($properties.dependentProducts) {
        foreach($product in $properties.dependentProducts)
        {
            Import-ByDependency -contentFolder $contentFolder -productid $product -resourceGroup $resourceGroup -armEndpoint $armEndpoint -defaultProviderSubscription $defaultProviderSubscription -headers ([ref]$headers) -importedProducts $importedProducts -azsCredential $azsCredential
        }
    }

    Resolve-ToLocalURI -productFolder $folderPath -productid $productid -resourceGroup $resourceGroup
    Syndicate-Product -productid $productid -armEndpoint $armEndpoint -headers ([ref]$headers) -defaultProviderSubscription $defaultProviderSubscription -downloadFolder $contentFolder -azsCredential $azsCredential
    $importedProducts.Add($productid) | Out-Null
}

<#
    .SYNOPSIS
    Check consistency of all Azure Marketplace Items available for import.
#>

function Test-AzSOfflineMarketplaceItem {
    param (
        [parameter(mandatory = $true)]
        [String] $destination
    )

    if (-not (Test-Path $destination)) {
        throw "$destination not exist."
    }
    if ((Get-Item $destination) -isnot [System.IO.DirectoryInfo]) {
        throw "$destination is not folder."
    }

    $ctx = Get-AzureRmContext
    $accessToken = Resolve-AccessToken -Context $ctx -AccessToken $accessToken
    $headers = @{ 'authorization' = "Bearer $accessToken"}
    $armEndpoint = $ctx.Environment.ResourceManagerUrl
    Get-AzureRmSubscription | Out-Null
    $defaultProviderSubscription = Select-AzureRmSubscription -SubscriptionName 'Default Provider Subscription'
    $subscriptionId = $defaultProviderSubscription.subscription.id

    $dirs = Get-ChildItem -Path $destination
    foreach($product in $dirs)
    {
        $syndicateUri = [string]::Format("{0}/subscriptions/{1}/resourceGroups/azurestack-activation/providers/Microsoft.AzureBridge.Admin/activations/default/downloadedProducts/{2}?api-version=2016-01-01",
            $armEndpoint,
            $subscriptionId,
            $product
        )

        try {
            $getStateResponse = Invoke-WebRequest -Method GET -Uri $syndicateUri -ContentType "application/json" -Headers $headers -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if ($getStateResponse -and $getStateResponse.Content) {
                $content = $getStateResponse.Content | convertFrom-json
                if ($content.properties.provisioningState -eq 'Succeeded') {
                    Write-Verbose "Marketplace product '$product' was syndicated, you can skip import" -verbose
                }
            }
        }
        catch
        {
            if ($_.Exception.Response.StatusCode -ne 404)
            {
                Write-Warning -Message "Failed to execute web request, Exception: `r`n$($_.Exception)"
            }
        }
    }

    PreCheck -contentFolder $destination

    Write-Verbose "Test-AzSOfflineMarketplaceItem finished successfully" -verbose
}

function Resolve-ToLocalURI {
    param (
        [parameter(mandatory = $true)]
        [String] $productFolder,

        [parameter(mandatory = $true)]
        [String] $productid,

        [parameter(mandatory = $true)]
        [String] $resourceGroup
    )

    $jsonPath = Get-Item "$productFolder\*.json"
    $jsonFile = Get-Content $jsonPath
    $json = $jsonFile | ConvertFrom-Json

    # check azpkg
    if($json.galleryPackageBlobSasUri) {
        $azpkgFile = Get-Item -path "$productFolder\*.azpkg"
        $azpkgURI = Upload-ToStorage -filePath $azpkgFile.FullName -productid $productid -resourceGroup $resourceGroup
        $json.galleryPackageBlobSasUri = $azpkgURI
    }

    # check icons
    $iconsFolder = "$productFolder\Icons"
    if ($json.iconUris.hero) {
        $heroPath = "$iconsFolder\hero.png"
        $heroURI = Upload-ToStorage -filePath $heroPath -productid $productid -resourceGroup $resourceGroup
        $json.iconUris.hero = $heroURI
    }
    if ($json.iconUris.large) {
        $largePath = "$iconsFolder\large.png"
        $largeURI = Upload-ToStorage -filePath $largePath -productid $productid -resourceGroup $resourceGroup
        $json.iconUris.large = $largeURI
    }
    if ($json.iconUris.medium) {
        $mediumPath = "$iconsFolder\medium.png"
        $mediumURI = Upload-ToStorage -filePath $mediumPath -productid $productid -resourceGroup $resourceGroup
        $json.iconUris.medium = $mediumURI
    }
    if ($json.iconUris.small) {
        $smallPath = "$iconsFolder\small.png"
        $smallURI = Upload-ToStorage -filePath $smallPath -productid $productid -resourceGroup $resourceGroup
        $json.iconUris.small = $smallURI
    }
    if ($json.iconUris.wide) {
        $widePath = "$iconsFolder\wide.png"
        $wideURI = Upload-ToStorage -filePath $widePath -productid $productid -resourceGroup $resourceGroup
        $json.iconUris.wide = $wideURI
    }

    # check osDiskImage
    if ($json.productDetailsProperties.OsDiskImage) {
        $osDiskImageFile = Get-Item -path "$productFolder\*.vhd"
        $osImageURI = Upload-ToStorage -filePath $osDiskImageFile.FullName -productid $productid -resourceGroup $resourceGroup -blobType Page
        $json.productDetailsProperties.OsDiskImage.sourceBlobSasUri = $osImageURI
    }

    # check vm extension zip
    if ($json.productDetailsProperties.sourceBlob) {
        $vmExtensionZip = "$productFolder\" + $json.productDetailsProperties.sourceBlob.uri
        $vmExtensionURI = Upload-ToStorage -filePath $vmExtensionZip -productid $productid -resourceGroup $resourceGroup
        $json.productDetailsProperties.sourceBlob.uri = $vmExtensionURI
    }

    # check fileContainers
    if ($json.productDetailsProperties.fileContainers) {
        for($i = 0; $i -le $json.productDetailsProperties.fileContainers.GetUpperBound(0); $i++)
        {
            $container = $json.productDetailsProperties.fileContainers[$i]
            $containerId = $container.id
            $containerFile = "$productFolder\$containerId"
            if ($container.type -match 'zip')
            {
                $containerFile = "$productFolder\$containerId.zip"
            }
            else
            {
                $file = get-item -Path "$productFolder\$containerId*"
                $containerFile = $file.FullName
            }
            $containerURI = Upload-ToStorage -filePath $containerFile -productid $productid -resourceGroup $resourceGroup
            $json.productDetailsProperties.fileContainers[$i].sourceUri = $containerURI
        }
    }

    Move-Item -path $jsonPath.FullName -Destination "$jsonPath.origin"
    $json |ConvertTo-Json -Depth 99 |out-file $jsonPath.FullName
}

function Resolve-AccessToken {
    param(
        [object] $context,
        [string] $accessToken
    )

    if (-not [string]::IsNullOrEmpty($accessToken)) {
        return $accessToken
    }

    $accessToken = $context.Account.ExtendedProperties.AccessToken

    if (-not [string]::IsNullOrEmpty($accessToken)) {
        return $accessToken
    }

    $cachedToken = $context.TokenCache.ReadItems() | Sort-Object -Property ExpiresOn -Descending | Select-Object -First 1

    if ($null -ne $cachedToken) {
        return $cachedToken.AccessToken
    }

    throw 'Unable to resolve access token.'
}

function Get-AccessToken
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String] $authorityEndpoint,

        [Parameter(Mandatory=$false)]
        [String] $resource,

        [Parameter(Mandatory=$false)]
        [String] $aadTenantId,

        [Parameter(Mandatory=$false)]
        [PSCredential] $credential,

        [Parameter(Mandatory=$false)]
        [String] $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    )

    Write-Debug "Getting Access token using supplied credentials"

    $contextAuthorityEndpoint = ([System.IO.Path]::Combine($authorityEndpoint, $aadTenantId)).Replace('\','/')
    $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($contextAuthorityEndpoint, $false)
    $userCredential = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential($credential.UserName, $credential.Password)
    return ($authContext.AcquireToken($resource, $clientId, $userCredential)).AccessToken
}

function Get-ResourceManagerMetaDataEndpoints
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String] $armEndpoint
    )

    $endpoints = Invoke-RestMethod -Method Get -Uri "$($armEndpoint.TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -TimeoutSec 180
    Write-Debug "Endpoints: $(ConvertTo-Json $endpoints)"

    Write-Output $endpoints
}

function Syndicate-Product {
    param (
        [parameter(mandatory = $true)]
        [String] $productid,

        [parameter(mandatory = $true)]
        [String] $armEndpoint,

        [Parameter(mandatory = $true)]
        [object] [ref]$headers,

        [parameter(mandatory = $true)]
        [String] $defaultProviderSubscription,
        
        [parameter(mandatory = $true)]
        [String] $downloadFolder,

        [Parameter(Mandatory = $false)]
        [PSCredential] $azsCredential
    )

    $jsonFile = Get-Content "$downloadFolder\$productid\*.json"
    $properties = $jsonFile | ConvertFrom-Json

    $syndicateUri = [string]::Format("{0}/subscriptions/{1}/resourceGroups/azurestack-activation/providers/Microsoft.AzureBridge.Admin/activations/default/downloadedProducts/{2}?api-version=2016-01-01",
        $armEndpoint,
        $defaultProviderSubscription,
        $productid
    )

    $json = @{
        properties = $properties
    }

    Write-Verbose -Message "properties : $($json | ConvertTo-Json -Compress)" -Verbose

    $syndicateResponse = InvokeWebRequest -Method PUT -Uri $syndicateUri -ArmEndpoint $armEndpoint -Headers ([ref]$headers) -Body $json -MaxRetry 2 -azsCredential $azsCredential

    if ($syndicateResponse.StatusCode -eq 200) {
        Write-Verbose "product '$productid' was syndicated" -verbose
    } elseif (-not (Wait-AzsAsyncOperation -AsyncOperationStatusUri $syndicateResponse.Headers.'Azure-AsyncOperation' -Headers ([ref]$headers) -azsCredential $azsCredential -Verbose)) {
        Write-Error "Unable to complete syndication operation." -ErrorAction Stop
    }
}

function Upload-ToStorage {
    param (
        [parameter(mandatory = $true)]
        [String] $filePath,

        [parameter(mandatory = $true)]
        [String] $productid,

        [parameter(mandatory = $true)]
        [String] $resourceGroup,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Page', 'Block')]
        [String] $blobType = "Block"
    )

    $syndicationStorageName = "syndicationstorage"
    $syndicationContainerName = "syndicationartifacts"
    # Get environment region
    $region = Get-AzureRmLocation

    Get-AzureRmResourceGroup -Name $resourceGroup -ErrorVariable notPresent -ErrorAction SilentlyContinue | Out-Null
    if($notPresent)
    {
        New-AzureRmResourceGroup -Name $resourceGroup -Location $region.Location -Force | Out-Null
    }

    $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -AccountName $syndicationStorageName -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if($notPresent)
    {
        $storageAccount = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup `
            -Name $syndicationStorageName `
            -Location $region.Location `
            -Type Standard_LRS
    }

    $ctx = $storageAccount.Context
    $container = Get-AzureStorageContainer -Name $syndicationContainerName -Context $ctx -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if($notPresent)
    {
        $container = New-AzureStorageContainer -Name $syndicationContainerName -Context $ctx -Permission blob
    }

    $file = Get-item -path $filePath

    $blobName = $productid + "_" + $file.Name
    $blobInfo = Get-AzureStorageBlob -Container $syndicationContainerName -Blob $blobName -Context $ctx -ErrorAction SilentlyContinue -ErrorVariable notPresent

    if($notPresent)
    {
        Set-AzureStorageBlobContent -File $file.FullName `
            -Container $syndicationContainerName `
            -Blob $blobName `
            -Context $ctx `
            -BlobType $blobType `
            -Force | Out-Null

        $fileURI = (Get-AzureStorageBlob -blob $blobName -Container $syndicationContainerName -Context $ctx).ICloudBlob.Uri.AbsoluteUri
    }
    else
    {
        Write-Verbose "$blobName exist in storage, skip upload" -verbose
        $fileURI = $blobInfo.ICloudBlob.uri.AbsoluteUri
    }

    return $fileURI
}

function Ensure-SuccessStatusCode {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpStatusCode] $statusCode
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Test-SuccessStatusCode -statusCode $statusCode)) {
        throw "HTTP response status code is not successful: $statusCode"
    }
}

function Wait-AzsAsyncOperation {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Uri] $asyncOperationStatusUri,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object] [ref]$headers,

        [Parameter(Mandatory = $false)]
        [PSCredential] $azsCredential
    )

    $ErrorActionPreference = 'Stop'

    # max wait for two hours, otherwise treat it as failed
    $currentAttempt = 0
    $maxAttempts = 720
    $sleepSeconds = 10

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($true) {
        $response = InvokeWebRequest -Method GET -Uri $asyncOperationStatusUri -ArmEndpoint $armEndpoint -Headers ([ref]$headers) -MaxRetry 10 -azsCredential $azsCredential

        Ensure-SuccessStatusCode -statusCode $response.statusCode

        $operationResult = $response.Content | ConvertFrom-Json

        if (Test-OperationResultTerminalState $operationResult.status) {
            if ($operationResult.status -eq 'Succeeded') {
                return $true
            }

            return $false
        }

        $currentAttempt++
        if ($currentAttempt -ge $maxAttempts)
        {
            throw "Async operation was not finished after $currentAttempt retries. Provisiong state: $operationResult.status"
        }

        Write-Debug "Sleeping for $sleepSeconds seconds, waiting time: $($stopwatch.Elapsed)"

        Start-Sleep -Seconds $sleepSeconds
    }
}

function Test-OperationResultTerminalState {
    param (
        [Parameter(Mandatory = $true)]
        [string] $value
    )

    return $value -in @('Canceled', 'Failed', 'Succeeded')
}

function Test-SuccessStatusCode {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpStatusCode] $statusCode
    )

    return [int]$statusCode -ge 200 -and [int]$statusCode -le 299
}

function InvokeWebRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('GET', 'PUT', 'POST', 'DELETE')]
        [string] $method,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Uri] $uri,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string] $armEndpoint,

        [Parameter(Mandatory = $true)]
        [object] [ref]$headers,

        [Parameter(Mandatory = $false)]
        [object] $body = $null,

        [Parameter(Mandatory = $false)]
        [object] $maxRetry = 1,

        [Parameter(Mandatory = $false)]
        [PSCredential] $azsCredential
    )

    $content = $null
    $response = $null
    $retryCount = 0
    $completed = $false
    $sleepSeconds = 5

    if ($body) {
        $content = $body | ConvertTo-Json -Depth 99 -Compress
    }

    $VerbosePreference = "SilentlyContinue"
    $ProgressPreference = "SilentlyContinue"

    while (-not $completed) {
        try {
            if ($content -ne $null) {
                $content = [System.Text.Encoding]::UTF8.GetBytes($content)
            }
            [void]($response = Invoke-WebRequest -Method $method -Uri $uri -ContentType "application/json; charset=utf-8" -Headers $headers -Body $content -ErrorAction Stop)
            $retryCount = 0
            Ensure-SuccessStatusCode -StatusCode $response.StatusCode
            $completed = $true
        }
        catch
        {
            if ($retryCount -ge $maxRetry) {
                Write-Warning "Request to $method $uri failed the maximum number of $maxRetry times. Timestamp: $((get-date).ToString('T'))"
                Write-Warning "Exception: `r`n$($_.Exception)"
                throw
            } else {
                if ($_.Exception.Response.StatusCode -eq 401)
                {
                    try {
                        if (!$azsCredential) {
                            Write-Warning -Message "Access token expired."
                            $azsCredential = Get-Credential -Message "Enter the Azure Stack operator credential"
                        }
                        $endpoints = Get-ResourceManagerMetaDataEndpoints -ArmEndpoint $armEndpoint
                        $aadAuthorityEndpoint = $endpoints.authentication.loginEndpoint
                        $aadResource = $endpoints.authentication.audiences[0]
                        $context = Get-AzureRmContext
                        $accessToken = Get-AccessToken -AuthorityEndpoint $aadAuthorityEndpoint -Resource $aadResource -AadTenantId $context.Tenant.TenantId -Credential $azsCredential
                        $headers.authorization = "Bearer $accessToken"
                    }
                    catch
                    {
                        Write-Warning "webrequest exception. `r`n$($_.Exception)"
                    }
                }

                $retryCount++
                Write-Warning "Request to $method $uri failed with exception: `r`n$($_.Exception). `r`nRetrying in $sleepSeconds seconds, retry count - $retryCount. Timestamp: $((get-date).ToString('T'))"
                Start-Sleep $sleepSeconds
            }
        }
    }

    return $response
}

function Get-SizeDisplayString {
    param (
        [parameter(mandatory = $true)]
        [long] $size
    )

    if ($size -gt 1073741824) {
        return [string]([math]::Round($size / 1GB)) + " GB"
    }
    elseif ($size -gt 1048576) {
        return [string]([math]::Round($size / 1MB)) + " MB"
    }
    else {return "<1 MB"} 
}

function Get-ProductsList {
    Param(
        [parameter(mandatory = $true)]
        [ValidateNotNull()]
        [Object] $azureEnvironment,

        [parameter(mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $azureSubscriptionID,

        [parameter(mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $accessToken,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $resourceGroup,

        [Parameter(Mandatory = $true)]
        [Switch] $resourceProvider
    )

    $registrationResources = Get-AzureRmResource -ResourceGroupName $resourceGroup -ResourceType Microsoft.AzureStack/registrations
    $registrationId = $registrationResources.ResourceId | Select-Object -First 1

    if (-not $registrationId) {
        throw "The subscription does not have Azure Stack registration. Please use the correct subscription."
    }

    $armEndpoint = $azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/')
    $headers = @{ 'authorization' = "Bearer $accessToken"}
    $productsUri = "$armEndpoint/$registrationId/products?api-version=2016-01-01"
    $products = (Invoke-RestMethod -Method GET -Uri $productsUri -Headers $headers -TimeoutSec 180).value

    if ($resourceProvider) {
        $displayKind = @{
            "resourceProvider" = "Resource Provider"
        }
    } else {
        $displayKind = @{
            "virtualMachine" = "Virtual Machine"
            "virtualMachineExtension" = "Virtual Machine Extension"
            "Solution" = "Solution"
        }
    }

    $aggregatedProducts = [pscustomobject[]]@()

    foreach ($product in $products) {
        if(!$displayKind.contains($product.properties.productKind))
        {
            # skip
            continue;
        }

        $displayType = $displayKind[$product.properties.productKind]
        $productNameAndVersion = $product.name.Split('/')[-1]
        $productName = $productNameAndVersion.substring(0, $productNameAndVersion.lastIndexOf('-'))

        $versionEntry = [pscustomobject]@{
            ProductId               = $product.name.Split('/')[-1]
            ProductResourceId       = $product.Id
            Version                 = $product.properties.productProperties.version
            Description             = $product.properties.description
            Size                    = Get-SizeDisplayString -size $product.properties.payloadLength
            # Provide more dependencies information
        }

        $existingProductEntry = $aggregatedProducts | where { $_.productName -ieq $productName }

        if ($existingProductEntry) {
            $existingProductEntry.VersionEntries += $versionEntry
            $existingProductEntry.VersionEntries = $existingProductEntry.VersionEntries | Sort-Object -Property Version
        } else {
            $newProductEntry = @{
                ProductName     = $productName
                Type            = $displayType
                Name            = $product.properties.displayName
                Publisher       = $product.properties.publisherDisplayName
                VersionEntries  = [pscustomobject[]]@( $versionEntry )
            }

            $aggregatedProducts += @($newProductEntry)
        }
    }

    return $aggregatedProducts | Sort-Object -Property ProductId
}

Export-ModuleMember -Function Export-AzSOfflineMarketplaceItem
Export-ModuleMember -Function Export-AzSOfflineResourceProvider
Export-ModuleMember -Function Import-AzSOfflineMarketplaceItem
Export-ModuleMember -Function Test-AzSOfflineMarketplaceItem