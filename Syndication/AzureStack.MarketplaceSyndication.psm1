# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
    .SYNOPSIS
    List all Azure Marketplace Items available for syndication and allows to download them
    Requires an Azure Stack System to be registered for the subscription used to login
#>

function Export-AzSOfflineMarketplaceItem {
    [CmdletBinding(DefaultParameterSetName = 'SyncOfflineAzsMarketplaceItem')]

    Param(
        [Parameter(Mandatory = $false, ParameterSetName = 'SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $Cloud = "AzureCloud",

        [Parameter(Mandatory = $false, ParameterSetName = 'SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $ResourceGroup = "azurestack",

        [Parameter(Mandatory = $false, ParameterSetName = 'SyncOfflineAzsMarketplaceItem')]
        [Switch] $ReduceDownloadThreads = $false,

        [Parameter(Mandatory = $true, ParameterSetName = 'SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $Destination
    )

    # in case it is relative path
    $Destination = Resolve-Path -Path $Destination

    $AzureContext = Get-AzureRmContext
    $AzureTenantID = $AzureContext.Tenant.TenantId
    $AzureSubscriptionID = $AzureContext.Subscription.Id

    $azureEnvironment = Get-AzureRmEnvironment -Name $Cloud

    $resources = Get-AzureRmResource -ResourceGroupName $ResourceGroup -ResourceType Microsoft.AzureStack/registrations
    $resource = $resources.resourcename
    # workaround for a breaking change from moving from profile version 2017-03-09-profile to 2018-03-01-hybrid
    # the output model of Get-AzureRmResource has changed between these versions
    # in future this code path can be changed to simply with  (Get-AzureRMResource -Name "AzureStack*").Name
    if($resource -eq $null)
    {
        $resource = $resources.Name
    }
    $registrations = $resource
    if ($registrations.count -gt 1) {
        $Registration = $registrations[0]
    } else {
        $Registration = $registrations
    }

    # Retrieve the access token
    $tokens = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache.ReadItems()
    $token = $tokens |Where Resource -EQ $azureEnvironment.ActiveDirectoryServiceEndpointResourceId |Where DisplayableId -EQ $AzureContext.Account.id |Where TenantID -EQ $AzureTenantID |Sort ExpiresOn |Select -Last 1
    
    $productsUri = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($AzureSubscriptionID.ToString())/resourceGroups/$ResourceGroup/providers/Microsoft.AzureStack/registrations/$($Registration.ToString())/products?api-version=2016-01-01"
    $Headers = @{ 'authorization' = "Bearer $($Token.AccessToken)"} 
    $products = (Invoke-RestMethod -Method GET -Uri $productsUri -Headers $Headers -TimeoutSec 180).value

    $displayKind = @{
        "virtualMachine" = "Virtual Machine"
        "virtualMachineExtension" = "Virtual Machine Extension"
        "Solution" = "Solution"
        "resourceProvider" = "Resource Provider"
    }
    $Marketitems = foreach ($product in $products) {
        if(!$displayKind.contains($product.properties.productKind))
        {
            throw "Unknown product kind '$_'"
        }
        $displayType = $displayKind[$product.properties.productKind]

		Write-output ([pscustomobject]@{
            Id          = $product.name.Split('/')[-1]
            Type        = $displayType
            Name        = $product.properties.displayName
            Description = $product.properties.description
            Publisher   = $product.properties.publisherDisplayName
            Version     = $product.properties.productProperties.version
            Size        = Get-SizeDisplayString -size $product.properties.payloadLength
        })
    }

    $Marketitems|Out-GridView -Title 'Azure Marketplace Items' -PassThru|foreach {
        Get-Dependency -productid $_.id -resourceGroup $ResourceGroup -azureEnvironment $azureEnvironment -azureSubscriptionID $AzureSubscriptionID -registration $Registration -token $token -destination $Destination -reduceDownloadThreads:$reduceDownloadThreads
    }
}

function Get-Dependency {
    param (
        [parameter(mandatory = $true)]
        [String] $productid,

        [parameter(mandatory = $true)]
        [String] $resourceGroup,

        [parameter(mandatory = $true)]
        [Object] $azureEnvironment,

        [parameter(mandatory = $true)]
        [String] $azureSubscriptionID,

        [parameter(mandatory = $true)]
        [String] $registration,

        [parameter(mandatory = $true)]
        [Object] $token,

        [parameter(mandatory = $true)]
        [String] $destination,

        [parameter(mandatory = $true)]
        [Switch] $reduceDownloadThreads
    )

    $Headers = @{ 'authorization' = "Bearer $($Token.AccessToken)"}
    $uri = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($azureSubscriptionID.ToString())/resourceGroups/$resourceGroup/providers/Microsoft.AzureStack/registrations/$registration/products/$productid/listDetails?api-version=2016-01-01"
    $downloadDetails = Invoke-RestMethod -Method POST -Uri $uri -Headers $Headers -TimeoutSec 180

    if ($downloadDetails.properties.dependentProducts)
    {
        foreach ($id in $downloadDetails.properties.dependentProducts)
        {
            Get-Dependency -productid $id -resourceGroup $resourceGroup -azureEnvironment $azureEnvironment -azureSubscriptionID $azureSubscriptionID -registration $registration -token $token -destination $destination -reduceDownloadThreads:$reduceDownloadThreads
        }
    }

    $productFolder = "$destination\$productid"
    $destinationCheck = Test-Path $productFolder
    If ($destinationCheck) {
        $productJsonFile = "$productFolder\$productid.json"
        $jsonFileCheck = Test-Path $productJsonFile
        if ($jsonFileCheck) {
            Write-Warning "$productid already exists at $destination\$productid, skip download."
            return
        }
    }

    Write-Host "`nDownloading product: $productid" -ForegroundColor DarkCyan
    Download-Product -productid $productid -resourceGroup $resourceGroup -azureEnvironment $azureEnvironment -azureSubscriptionID $azureSubscriptionID -registration $registration -token $token -destination $destination -reduceDownloadThreads:$reduceDownloadThreads
}

function Download-Product {
    param (
        [parameter(mandatory = $true)]
        [String] $productid,

        [parameter(mandatory = $true)]
        [String] $resourceGroup,

        [parameter(mandatory = $true)]
        [Object] $azureEnvironment,

        [parameter(mandatory = $true)]
        [String] $azureSubscriptionID,

        [parameter(mandatory = $true)]
        [String] $registration,

        [parameter(mandatory = $true)]
        [Object] $token,

        [parameter(mandatory = $true)]
        [String] $destination,

        [parameter(mandatory = $true)]
        [Switch] $reduceDownloadThreads
    )

    # get name of azpkg
    $azpkgURI = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($AzureSubscriptionID.ToString())/resourceGroups/$resourceGroup/providers/Microsoft.AzureStack/registrations/$Registration/products/$($productid)?api-version=2016-01-01"
    Write-Debug $azpkgURI
    $Headers = @{ 'authorization' = "Bearer $($Token.AccessToken)"}
    $productDetails = Invoke-RestMethod -Method GET -Uri $azpkgURI -Headers $Headers -TimeoutSec 180
    $azpkgName = $productDetails.properties.galleryItemIdentity
    if (!$azpkgName) {
        $azpkgName = $productid
    }

    # get download location for azpkg
    $downloadURI = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($AzureSubscriptionID.ToString())/resourceGroups/$resourceGroup/providers/Microsoft.AzureStack/registrations/$Registration/products/$productid/listDetails?api-version=2016-01-01"
    Write-Debug $downloadURI
    $downloadDetails = Invoke-RestMethod -Method POST -Uri $downloadURI -Headers $Headers -TimeoutSec 180

    # create Legal Terms POPUP
    $legalTitle = "Legal Terms"
    $legalText = $productDetails.properties.description -replace '<[^>]+>',''
    Write-Host $("-"*20)
    Write-Host "$legalTitle`n$legalText" -ForegroundColor DarkYellow
    $confirmation = Read-Host "Accept Legal Terms. (Y/N)?"
    If ($confirmation -eq 'Y') {
        $productFolder = "$destination\$productid"

        # output parameters required for import
        $FileExists = Test-Path "$productFolder\$azpkgName.txt"
        $DestinationCheck = Test-Path $productFolder
        If ($DestinationCheck -eq $false) {
            New-item -ItemType Directory -force $productFolder | Out-Null
        }

        If ($FileExists) {
            Remove-Item "$productFolder\$azpkgName.txt" -force -ErrorAction SilentlyContinue | Out-Null
        } else {
            New-Item "$productFolder\$azpkgName.txt" | Out-Null
        }

        If ($FileExists) {
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

        if ($downloadDetails.productKind -ne 'resourceProvider')
        {
            # download azpkg
            $azpkgsource = $downloadDetails.galleryPackageBlobSasUri
            $FileExists = Test-Path "$productFolder\$azpkgName.azpkg"
            $DestinationCheck = Test-Path $productFolder
            If ($DestinationCheck -eq $false) {
                New-item -ItemType Directory -force $productFolder | Out-Null
            }

            If ($FileExists) {
                Remove-Item "$productFolder\$azpkgName.azpkg" -force | Out-Null
            }
            $azpkgdestination = "$productFolder\$azpkgName.azpkg"

            If ($downloadConfirmation -eq 'Y') {
                $checktool= Test-Path "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
                If ($checktool -eq $true){
                    DownloadMarketplaceProduct -Source $azpkgsource -Destination $azpkgdestination -ProductName "$azpkgName.azpkg" -reduceDownloadThreads:$reduceDownloadThreads -PremiumDownload -MaxRetry 2
                    "$productFolder\$azpkgName.azpkg"|out-file "$productFolder\$azpkgName.txt" -Append
                }
                else{
                    Write-Verbose "Please install Azure Storage Tools AzCopy first, canceling" -verbose
                    return
                }
            } else {
                DownloadMarketplaceProduct -Source $azpkgsource -Destination $azpkgdestination -ProductName "$azpkgName.azpkg" -reduceDownloadThreads:$reduceDownloadThreads -MaxRetry 2
                "$productFolder\$azpkgName.azpkg"|out-file "$productFolder\$azpkgName.txt" -Append
            }
        }

        $iconsFolder = "$productFolder\Icons"
        $DestinationCheck = Test-Path $iconsFolder
        If ($DestinationCheck -eq $false) {
            New-item -ItemType Directory -force $iconsFolder | Out-Null
        }

        # download icons
        $icon = $productDetails.properties.iconUris
        If (Test-Path "$iconsFolder\hero.png") {Remove-Item "$iconsFolder\hero.png" -force -ErrorAction SilentlyContinue | Out-Null}
        If (Test-Path "$iconsFolder\large.png") {Remove-Item "$iconsFolder\large.png" -force -ErrorAction SilentlyContinue | Out-Null}
        If (Test-Path "$iconsFolder\medium.png") {Remove-Item "$iconsFolder\medium.png" -force -ErrorAction SilentlyContinue | Out-Null}
        If (Test-Path "$iconsFolder\small.png") {Remove-Item "$iconsFolder\small.png" -force -ErrorAction SilentlyContinue | Out-Null}
        If (Test-Path "$iconsFolder\wide.png") {Remove-Item "$iconsFolder\wide.png" -force -ErrorAction SilentlyContinue | Out-Null}

        If ($downloadConfirmation -eq 'Y') {
            $checktool= Test-Path "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
            If ($checktool -eq $true){
                if ($icon.hero) {
                    DownloadMarketplaceProduct -Source "$($icon.hero)" -Destination "$iconsFolder\hero.png" -ProductName "hero.png" -reduceDownloadThreads:$reduceDownloadThreads -PremiumDownload -MaxRetry 2
                    "$iconsFolder\hero.png"|out-file "$productFolder\$azpkgName.txt" -Append
                }
                if ($icon.large) {
                    DownloadMarketplaceProduct -Source "$($icon.large)" -Destination "$iconsFolder\large.png" -ProductName "large.png" -reduceDownloadThreads:$reduceDownloadThreads -PremiumDownload -MaxRetry 2
                    "$iconsFolder\large.png"|out-file "$productFolder\$azpkgName.txt" -Append
                }
                if ($icon.medium) {
                    DownloadMarketplaceProduct -Source "$($icon.medium)" -Destination "$iconsFolder\medium.png" -ProductName "medium.png" -reduceDownloadThreads:$reduceDownloadThreads -PremiumDownload -MaxRetry 2
                    "$iconsFolder\medium.png"|out-file "$productFolder\$azpkgName.txt" -Append
                }
                if ($icon.small) {
                    DownloadMarketplaceProduct -Source "$($icon.small)" -Destination "$iconsFolder\small.png" -ProductName "small.png" -reduceDownloadThreads:$reduceDownloadThreads -PremiumDownload -MaxRetry 2
                    "$iconsFolder\small.png"|out-file "$productFolder\$azpkgName.txt" -Append
                }
                if ($icon.wide) {
                    DownloadMarketplaceProduct -Source "$($icon.wide)" -Destination "$iconsFolder\wide.png" -ProductName "wide.png" -reduceDownloadThreads:$reduceDownloadThreads -PremiumDownload -MaxRetry 2
                    "$iconsFolder\wide.png"|out-file "$productFolder\$azpkgName.txt" -Append
                }
                Write-Verbose "icons has been downloaded" -verbose
            }
            else{
                Write-Verbose "Please install Azure Storage Tools AzCopy first, canceling" -verbose
                return
            }
        } else {
            if ($icon.hero) {
                DownloadMarketplaceProduct -Source "$($icon.hero)" -Destination "$iconsFolder\hero.png" -ProductName "hero.png" -reduceDownloadThreads:$reduceDownloadThreads -MaxRetry 2
                "$iconsFolder\hero.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.large) {
                DownloadMarketplaceProduct -Source "$($icon.large)" -Destination "$iconsFolder\large.png" -ProductName "large.png" -reduceDownloadThreads:$reduceDownloadThreads -MaxRetry 2
                "$iconsFolder\large.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.medium) {
                DownloadMarketplaceProduct -Source "$($icon.medium)" -Destination "$iconsFolder\medium.png" -ProductName "medium.png" -reduceDownloadThreads:$reduceDownloadThreads -MaxRetry 2
                "$iconsFolder\medium.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.small) {
                DownloadMarketplaceProduct -Source "$($icon.small)" -Destination "$iconsFolder\small.png" -ProductName "small.png" -reduceDownloadThreads:$reduceDownloadThreads -MaxRetry 2
                "$iconsFolder\small.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            if ($icon.wide) {
                DownloadMarketplaceProduct -Source "$($icon.wide)" -Destination "$iconsFolder\wide.png" -ProductName "wide.png" -reduceDownloadThreads:$reduceDownloadThreads -MaxRetry 2
                "$iconsFolder\wide.png"|out-file "$productFolder\$azpkgName.txt" -Append
            }
            Write-Verbose "icons has been downloaded" -verbose
        }

        switch ($downloadDetails.productKind) {
            'virtualMachine' {
                # download vhd
                $vhdName = $productDetails.properties.galleryItemIdentity
                $vhdSource = $downloadDetails.properties.osDiskImage.sourceBlobSasUri
                If ([string]::IsNullOrEmpty($vhdsource)) {
                    throw "VM vhd source is empty"
                } else {
                    $FileExists = Test-Path "$productFolder\$vhdName.vhd"
                    If ($FileExists) {
                        Remove-Item "$productFolder\$vhdName.vhd" -force | Out-Null
                    }
                    $vhdDestination = "$productFolder\$vhdName.vhd"

                    If ($downloadConfirmation -eq 'Y') {
                        $checktool= Test-Path "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
                        If ($checktool -eq $true){
                            DownloadMarketplaceProduct -Source $vhdsource -Destination $vhddestination -ProductName "$vhdName.vhd" -reduceDownloadThreads:$reduceDownloadThreads -PremiumDownload -MaxRetry 2
                            "$productFolder\$vhdName.vhd"|out-file "$productFolder\$azpkgName.txt" -Append
                        } else {
                            Write-Verbose "Please install Azure Storage Tools AzCopy first,canceling" -verbose
                            return
                        }
                    } else {
                        DownloadMarketplaceProduct -Source $vhdsource -Destination $vhddestination -ProductName "$vhdName.vhd" -reduceDownloadThreads:$reduceDownloadThreads -MaxRetry 2
                    }
                    Write-Verbose "$vhdName.vhd has been downloaded" -verbose
                    "$productFolder\$vhdName.vhd"|out-file "$productFolder\$azpkgName.txt" -Append
                }
            }
            'virtualMachineExtension' {
                # download zip
                $zipName = $productDetails.properties.galleryItemIdentity
                $zipsource = $downloadDetails.properties.sourceBlob.uri
                If ([string]::IsNullOrEmpty($zipsource)) {
                    throw "VM extension zip source is empty"
                } else {
                    $FileExists = Test-Path "$productFolder\$zipName.zip"
                    If ($FileExists) {
                        Remove-Item "$productFolder\$zipName.zip" -force | Out-Null
                    }
                    $zipDestination = "$productFolder\$zipName.zip"

                    If ($downloadConfirmation -eq 'Y') {
                        $checktool= Test-Path "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
                        If ($checktool -eq $true){
                            DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "$zipName.zip" -reduceDownloadThreads:$reduceDownloadThreads -PremiumDownload -MaxRetry 2
                            "$productFolder\$zipName.zip"|out-file "$productFolder\$azpkgName.txt" -Append
                            $productDetailsProperties['sourceBlob'].uri = "$zipName.zip"
                        } else {
                            Write-Verbose "Please install Azure Storage Tools AzCopy first,canceling" -verbose
                            return
                        }
                    } else {
                        DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "$zipName.zip" -reduceDownloadThreads:$reduceDownloadThreads -MaxRetry 2
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
                    If ([string]::IsNullOrEmpty($zipsource)) {
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

                        $FileExists = Test-Path $zipDestination
                        If ($FileExists) {
                            Remove-Item $zipDestination -force | Out-Null
                        }

                        If ($downloadConfirmation -eq 'Y') {
                            $checktool= Test-Path "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
                            If ($checktool -eq $true){
                                DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "Container [$containerName]" -reduceDownloadThreads:$reduceDownloadThreads -PremiumDownload -MaxRetry 2
                                "$productFolder\$containerName"|out-file "$productFolder\$azpkgName.txt" -Append
                            } else {
                                Write-Verbose "Please install Azure Storage Tools AzCopy first,canceling" -verbose
                                return
                            }
                        } else {
                            DownloadMarketplaceProduct -Source $zipsource -Destination $zipdestination -ProductName "Container [$containerName]" -reduceDownloadThreads:$reduceDownloadThreads -MaxRetry 2
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
        [Uri] $Source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [String] $Destination,

        [Parameter(Mandatory = $true)]
        [String] $ProductName,

        [parameter(mandatory = $true)]
        [Switch] $reduceDownloadThreads,

        [Parameter(Mandatory = $false)]
        [Switch] $PremiumDownload,

        [Parameter(Mandatory = $false)]
        [object] $MaxRetry = 1
    )

    $content = $null
    $response = $null
    $completed = $false
    $retryCount = 0
    $sleepSeconds = 5
    $tmpDestination = "$Destination.marketplace"

    if ($Source -notmatch 'windows.net')
    {
        $PremiumDownload = $false
        Write-Verbose "$Source is not in storage account, use regular download" -verbose
    }

    while (-not $completed) {
        try {
            if ($PremiumDownload) {
                if ($reduceDownloadThreads) {
                    & 'C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe' /Source:$Source /Dest:$tmpDestination /Y /NC:1
                } else {
                    & 'C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe' /Source:$Source /Dest:$tmpDestination /Y
                }
            } else {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($Source, $tmpDestination)
            }

            $completed = $true
            Write-Verbose "[$ProductName] has been downloaded" -verbose
        }
        catch
        {
            if ($retryCount -ge $MaxRetry) {
                Write-Warning "Request to download from $Source failed the maximum number of $MaxRetry times."
                throw
            } else {
                Write-Warning "Request to download from $Source failed. Retrying in $sleepSeconds seconds."
                Start-Sleep $sleepSeconds
                $retryCount++
            }
        }
    }

    Move-Item -Path $tmpDestination -Destination $Destination -Force
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
        [String] $Origin,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Uri] $ArmEndpoint,

        [Parameter(Mandatory = $false)]
        [PSCredential] $AzsCredential
    )

    $defaultProviderSubscription = Get-AzureRmSubscription -SubscriptionName 'Default Provider Subscription' | Select-AzureRmSubscription

    $resourceGroup = "System.syndication"
    $dirs = Get-ChildItem -Path $Origin
    $importedProducts  = New-Object System.Collections.Generic.HashSet[string]

    PreCheck -contentFolder $Origin

    $ctx = Get-AzureRmContext
    $AccessToken = Resolve-AccessToken -Context $ctx -AccessToken $AccessToken
    $headers = @{ 'authorization' = "Bearer $AccessToken"}

    foreach($dir in $dirs)
    {
        Import-ByDependency -contentFolder $Origin -productid $dir -resourceGroup $resourceGroup -armEndpoint $ArmEndpoint -defaultProviderSubscription $defaultProviderSubscription.subscription.id -headers ([ref]$headers) -importedProducts $importedProducts -AzsCredential $AzsCredential
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
        [PSCredential] $AzsCredential
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
            Write-Warning -Message "Failed to execute web request" -Exception $_.Exception
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
            Import-ByDependency -contentFolder $contentFolder -productid $product -resourceGroup $resourceGroup -armEndpoint $armEndpoint -defaultProviderSubscription $defaultProviderSubscription -headers ([ref]$headers) -importedProducts $importedProducts -AzsCredential $AzsCredential
        }
    }

    Resolve-ToLocalURI -productFolder $folderPath -productid $productid -resourceGroup $resourceGroup
    Syndicate-Product -productid $productid -armEndpoint $armEndpoint -headers ([ref]$headers) -defaultProviderSubscription $defaultProviderSubscription -downloadFolder $contentFolder -AzsCredential $AzsCredential
    $importedProducts.Add($productid) | Out-Null
}

<#
    .SYNOPSIS
    Check consistency of all Azure Marketplace Items available for import.
#>

function Test-AzSOfflineMarketplaceItem {
    param (
        [parameter(mandatory = $true)]
        [String] $Destination,

        [parameter(mandatory = $true)]
        [String] $ArmEndpoint,

        [parameter(mandatory = $true)]
        [String] $SubscriptionId
    )

    $ctx = Get-AzureRmContext
    $AccessToken = Resolve-AccessToken -Context $ctx -AccessToken $AccessToken
    $headers = @{ 'authorization' = "Bearer $AccessToken"}

    $dirs = Get-ChildItem -Path $Destination
    foreach($product in $dirs)
    {
        $syndicateUri = [string]::Format("{0}/subscriptions/{1}/resourceGroups/azurestack-activation/providers/Microsoft.AzureBridge.Admin/activations/default/downloadedProducts/{2}?api-version=2016-01-01",
            $ArmEndpoint,
            $SubscriptionId,
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
                Write-Warning -Message "Failed to execute web request" -Exception $_.Exception
            }
        }
    }

    PreCheck -contentFolder $Destination

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
        $osImageURI = Upload-ToStorage -filePath $osDiskImageFile.FullName -productid $productid -resourceGroup $resourceGroup
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
        [String] $AuthorityEndpoint,

        [Parameter(Mandatory=$false)]
        [String] $Resource,

        [Parameter(Mandatory=$false)]
        [String] $AadTenantId,

        [Parameter(Mandatory=$false)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$false)]
        [String] $ClientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    )

    Write-Debug "Getting Access token using supplied credentials"

    $contextAuthorityEndpoint = ([System.IO.Path]::Combine($AuthorityEndpoint, $AadTenantId)).Replace('\','/')
    $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($contextAuthorityEndpoint, $false)
    $userCredential = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential($Credential.UserName, $Credential.Password)
    return ($authContext.AcquireToken($Resource, $ClientId, $userCredential)).AccessToken
}

function Get-ResourceManagerMetaDataEndpoints
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String] $ArmEndpoint
    )

    $endpoints = Invoke-RestMethod -Method Get -Uri "$($ArmEndpoint.TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -TimeoutSec 180
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
        [PSCredential] $AzsCredential
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

    $syndicateResponse = InvokeWebRequest -Method PUT -Uri $syndicateUri -ArmEndpoint $armEndpoint -Headers ([ref]$headers) -Body $json -MaxRetry 2 -AzsCredential $AzsCredential

    if ($syndicateResponse.StatusCode -eq 200) {
        Write-Verbose "product '$productid' was syndicated" -verbose
    } elseif (-not (Wait-AzsAsyncOperation -AsyncOperationStatusUri $syndicateResponse.Headers.'Azure-AsyncOperation' -Headers ([ref]$headers) -AzsCredential $AzsCredential -Verbose)) {
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
        [String] $resourceGroup
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
        [System.Net.HttpStatusCode] $StatusCode
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Test-SuccessStatusCode -StatusCode $StatusCode)) {
        throw "HTTP response status code is not successful: $StatusCode"
    }
}

function Wait-AzsAsyncOperation {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Uri] $AsyncOperationStatusUri,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object] [ref]$Headers,

        [Parameter(Mandatory = $false)]
        [PSCredential] $AzsCredential
    )

    $ErrorActionPreference = 'Stop'

    # max wait for two hours, otherwise treat it as failed
    $currentAttempt = 0
    $maxAttempts = 720
    $sleepSeconds = 10

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($true) {
        $response = InvokeWebRequest -Method GET -Uri $AsyncOperationStatusUri -ArmEndpoint $armEndpoint -Headers ([ref]$Headers) -MaxRetry 10 -AzsCredential $AzsCredential

        Ensure-SuccessStatusCode -StatusCode $response.StatusCode

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
        [string] $Value
    )

    return $Value -in @('Canceled', 'Failed', 'Succeeded')
}

function Test-SuccessStatusCode {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpStatusCode] $StatusCode
    )

    return [int]$StatusCode -ge 200 -and [int]$StatusCode -le 299
}

function InvokeWebRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('GET', 'PUT', 'POST', 'DELETE')]
        [string] $Method,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Uri] $Uri,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string] $ArmEndpoint,

        [Parameter(Mandatory = $true)]
        [object] [ref]$Headers,

        [Parameter(Mandatory = $false)]
        [object] $Body = $null,

        [Parameter(Mandatory = $false)]
        [object] $MaxRetry = 1,

        [Parameter(Mandatory = $false)]
        [PSCredential] $AzsCredential
    )

    $content = $null
    $response = $null
    $retryCount = 0
    $completed = $false
    $sleepSeconds = 5

    if ($Body) {
        $content = $body | ConvertTo-Json -Depth 99 -Compress
    }

    $VerbosePreference = "SilentlyContinue"
    $ProgressPreference = "SilentlyContinue"

    while (-not $completed) {
        try {
            if ($content -ne $null) {
                $content = [System.Text.Encoding]::UTF8.GetBytes($content)
            }
            [void]($response = Invoke-WebRequest -Method $Method -Uri $Uri -ContentType "application/json; charset=utf-8" -Headers $Headers -Body $content -ErrorAction Stop)
            $retryCount = 0
            Ensure-SuccessStatusCode -StatusCode $response.StatusCode
            $completed = $true
        }
        catch
        {
            if ($retryCount -ge $MaxRetry) {
                Write-Warning "Request to $Method $Uri failed the maximum number of $MaxRetry times. Timestamp: $($(get-date).ToString('T'))"
                throw
            } else {
                $error = $_.Exception
                if ($_.Exception.Response.StatusCode -eq 401)
                {
                    try {
                        if (!$AzsCredential) {
                            Write-Warning -Message "Access token expired."
                            $AzsCredential = Get-Credential -Message "Enter the azure stack operator credential"
                        }
                        $endpoints = Get-ResourceManagerMetaDataEndpoints -ArmEndpoint $ArmEndpoint
                        $aadAuthorityEndpoint = $endpoints.authentication.loginEndpoint
                        $aadResource = $endpoints.authentication.audiences[0]
                        $context = Get-AzureRmContext
                        $AccessToken = Get-AccessToken -AuthorityEndpoint $aadAuthorityEndpoint -Resource $aadResource -AadTenantId $context.Tenant.TenantId -Credential $AzsCredential
                        $Headers.authorization = "Bearer $AccessToken"
                    }
                    catch
                    {
                        Write-Warning "webrequest exception. `n$error"
                    }
                }

                $retryCount++
                Write-Debug "Request to $Method $Uri failed with status $error. `nRetrying in $sleepSeconds seconds, retry count - $retryCount. Timestamp: $($(get-date).ToString('T'))"
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

Export-ModuleMember -Function Export-AzSOfflineMarketplaceItem
Export-ModuleMember -Function Import-AzSOfflineMarketplaceItem
Export-ModuleMember -Function Test-AzSOfflineMarketplaceItem