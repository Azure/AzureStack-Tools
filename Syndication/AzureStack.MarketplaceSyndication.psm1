# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
    .SYNOPSIS
    List all Azure Marketplace Items available for syndication and allows to download them
    Requires an Azure Stack System to be registered for the subscription used to login
#>

function Sync-AzSOfflineMarketplaceItem {
    [CmdletBinding(DefaultParameterSetName = 'SyncOfflineAzsMarketplaceItem')]

    Param(    
        [Parameter(Mandatory = $false, ParameterSetName = 'SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $Cloud = "AzureCloud",

        [Parameter(Mandatory = $true, ParameterSetName = 'SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $Destination,

        [Parameter(Mandatory = $true, ParameterSetName = 'SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $AzureTenantID,

        [Parameter(Mandatory = $true, ParameterSetName = 'SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $AzureSubscriptionID
        
    )


   
    $azureAccount = Add-AzureRmAccount -subscriptionid $AzureSubscriptionID -TenantId $AzureTenantID -Environment $Cloud

    $azureEnvironment = Get-AzureRmEnvironment -Name $Cloud

    $resources = Get-AzureRmResource
    $resource = $resources.resourcename
    $registrations = $resource|where-object {$_ -like "AzureStack*"}
    if ($registrations.count -gt 1) {
        $Registration = $registrations[0]
    }
    else {
        $Registration = $registrations
    }
        

    # Retrieve the access token
    $tokens = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache.ReadItems()
    $token = $tokens |Where Resource -EQ $azureEnvironment.ActiveDirectoryServiceEndpointResourceId |Where DisplayableId -EQ $azureAccount.Context.Account.Id |Sort ExpiresOn |Select -Last 1

    
    $uri1 = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($AzureSubscriptionID.ToString())/resourceGroups/azurestack/providers/Microsoft.AzureStack/registrations/$($Registration.ToString())/products?api-version=2016-01-01"
    $Headers = @{ 'authorization' = "Bearer $($Token.AccessToken)"} 
    $products = (Invoke-RestMethod -Method GET -Uri $uri1 -Headers $Headers).value
    

    $Marketitems = foreach ($product in $products) {
        switch ($product.properties.productKind) {
            'virtualMachine' {
                Write-output ([pscustomobject]@{
                        Id          = $product.name.Split('/')[-1]
                        Type        = "Virtual Machine"
                        Name        = $product.properties.displayName
                        Description = $product.properties.description
                        Publisher   = $product.properties.publisherDisplayName
                        Version     = $product.properties.offerVersion
                        Size        = Set-String -size $product.properties.payloadLength
                    })
            }

            'virtualMachineExtension' {
                Write-output ([pscustomobject]@{
                        Id          = $product.name.Split('/')[-1]
                        Type        = "Virtual Machine Extension"
                        Name        = $product.properties.displayName
                        Description = $product.properties.description
                        Publisher   = $product.properties.publisherDisplayName
                        Version     = $product.properties.productProperties.version
                        Size        = Set-String -size $product.properties.payloadLength
                    })
            }

            Default {
                Write-Warning "Unknown product kind '$_'"
            }
        }
    }
      
   

    $Marketitems|Out-GridView -Title 'Azure Marketplace Items' -PassThru|foreach {

        $productid = $_.id

        # get name of azpkg
        $uri2 = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($AzureSubscriptionID.ToString())/resourceGroups/azurestack/providers/Microsoft.AzureStack/registrations/$Registration/products/$($productid)?api-version=2016-01-01"
        Write-Debug $URI2
        $Headers = @{ 'authorization' = "Bearer $($Token.AccessToken)"} 
        $productDetails = Invoke-RestMethod -Method GET -Uri $uri2 -Headers $Headers
        $azpkgName = $productDetails.properties.galleryItemIdentity
    

        # get download location for apzkg
        $uri3 = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($AzureSubscriptionID.ToString())/resourceGroups/azurestack/providers/Microsoft.AzureStack/registrations/$Registration/products/$productid/listDetails?api-version=2016-01-01"
        $uri3
        $downloadDetails = Invoke-RestMethod -Method POST -Uri $uri3 -Headers $Headers

        #Create Legal Terms POPUP
        $a = new-object -comobject wscript.shell
        $intAnswer = $a.popup($productDetails.properties.description, `
                0, "Legal Terms", 4)
        If ($intAnswer -eq 6) {
           
            #Output Parameters required for Import
            $FileExists = Test-Path "$destination\$azpkgName.txt"
            $DestinationCheck = Test-Path $destination
            If ($DestinationCheck -eq $false) {
                new-item -ItemType Directory -force $destination
            }
            else {}

            If ($FileExists -eq $true) {Remove-Item "$destination\$azpkgName.txt" -force} else {
                New-Item "$destination\$azpkgName.txt"
            }
            $productDetails.properties|select publisherIdentifier,offer,offerversion,sku |out-file "$destination\$azpkgName.txt" -Append
           
           
            # download azpkg
            $azpkgsource = $downloadDetails.galleryPackageBlobSasUri
            $FileExists = Test-Path "$destination\$azpkgName.azpkg"
            $DestinationCheck = Test-Path $destination
            If ($DestinationCheck -eq $false) {
                new-item -ItemType Directory -force $destination
            }
            else {}

            If ($FileExists -eq $true) {Remove-Item "$destination\$azpkgName.azpkg" -force} else {
                New-Item "$destination\$azpkgName.azpkg"
            }
            $azpkgdestination = "$destination\$azpkgName.azpkg"
            (New-Object System.Net.WebClient).DownloadFile("$azpkgsource",$azpkgdestination) 



            switch ($downloadDetails.productKind) {
                'virtualMachine' {

                    # download vhd
                    $vhdName = $productDetails.properties.galleryItemIdentity
                    $vhdSource = $downloadDetails.properties.osDiskImage.sourceBlobSasUri
                    If ([string]::IsNullOrEmpty($vhdsource)) {exit} else {
                        $FileExists = Test-Path "$destination\$vhdName.vhd" 
                        If ($FileExists -eq $true) {Remove-Item "$destination\$vhdName.vhd" -force} else {
                            New-Item "$destination\$vhdName.vhd" 
                        }
                        $vhdDestination = "$destination\$vhdName.vhd"
                        (New-Object System.Net.WebClient).DownloadFile("$vhdsource",$vhddestination) 
                    }
                }
                'virtualMachineExtension' {
                    # download zip
                    $zipName = $productDetails.properties.galleryItemIdentity
                    $zipsource = $downloadDetails.properties.sourceBlob.uri
                    If ([string]::IsNullOrEmpty($zipsource)) {exit} else {
                        $FileExists = Test-Path "$destination\$zipName.zip" 
                        If ($FileExists -eq $true) {Remove-Item "$destination\$zipName.zip" -force} else {
                            New-Item "$destination\$zipName.zip" 
                        }
                        $zipDestination = "$destination\$zipName.zip"
    
                        Start-BitsTransfer -source $zipsource -destination $zipDestination -Priority High
                    }
                }

                Default {
                    Write-Warning "Unknown product kind '$_'"
                }
            }
        }

        else {
            $a.popup("Legal Terms not accepted, canceling")
        }

    }
}



function Set-String {
    param (
        [parameter(mandatory = $true)]
        [long] $size
    )

    if ($size -gt 1073741824) {
        return [string]([math]::Round($size / 1073741824)) + " GB"
    }
    elseif ($size -gt 1048576) {
        return [string]([math]::Round($size / 1048576)) + " MB"
    }
    else {return "<1 MB"} 
}

Export-ModuleMember -Function Sync-AzSOfflineMarketplaceItem
