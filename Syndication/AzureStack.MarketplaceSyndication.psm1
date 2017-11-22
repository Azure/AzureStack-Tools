# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
    .SYNOPSIS
    List all Azure Marketplace Items available for syndication and allows to download them
    Requires an Azure Stack System to be registered for the subscription used to login
#>

function Sync-AzSOfflineMarketplaceItem{
[CmdletBinding(DefaultParameterSetName='SyncOfflineAzsMarketplaceItem')]

  Param(    
        [Parameter(Mandatory=$false, ParameterSetName='SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $Cloud = "AzureCloud",

        [Parameter(Mandatory=$true, ParameterSetName='SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $Destination,

        [Parameter(Mandatory=$true, ParameterSetName='SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $AzureTenantID,

        [Parameter(Mandatory=$true, ParameterSetName='SyncOfflineAzsMarketplaceItem')]
        [ValidateNotNullorEmpty()]
        [String] $AzureSubscriptionID
        
        )


   
    $azureAccount = Add-AzureRmAccount -subscriptionid $AzureSubscriptionID -TenantId $AzureTenantID

    $azureEnvironment = Get-AzureRmEnvironment -Name $Cloud

    $resources=Get-AzureRmResource
    $resource=$resources.resourcename
    $registrations=$resource|where-object {$_ -like "AzureStack*"}
    $registration = $registrations[0]

    # Retrieve the access token
    $tokens = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache.ReadItems()
    $token = $tokens |Where Resource -EQ $azureEnvironment.ActiveDirectoryServiceEndpointResourceId |Where DisplayableId -EQ $azureAccount.Context.Account.Id |Sort ExpiresOn |Select -Last 1

    
    $uri1 = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($AzureSubscriptionID.ToString())/resourceGroups/azurestack/providers/Microsoft.AzureStack/registrations/$($Registration.ToString())/products?api-version=2016-01-01"
    $Headers = @{ 'authorization'="Bearer $($Token.AccessToken)"} 
    $products = (Invoke-RestMethod -Method GET -Uri $uri1 -Headers $Headers).value
    

    $Marketitems=foreach ($product in $products)
    {
        switch($product.properties.productKind)
        {
            'virtualMachine'
            {
                Write-output ([pscustomobject]@{
                    Id        = $product.name.Split('/')[-1]
                    Type      = "Virtual Machine"
                    Name      = $product.properties.displayName
                    Description = $product.properties.description
                    Publisher = $product.properties.publisherDisplayName
                    Version   = $product.properties.offerVersion
                    Size      = Set-String -size $product.properties.payloadLength
                })
            }

            'virtualMachineExtension'
            {
                Write-output ([pscustomobject]@{
                    Id        = $product.name.Split('/')[-1]
                    Type      = "Virtual Machine Extension"
                    Name      = $product.properties.displayName
                    Description = $product.properties.description
                    Publisher = $product.properties.publisherDisplayName
                    Version   = $product.properties.productProperties.version
                    Size      = Set-String -size $product.properties.payloadLength
                })
            }

            Default
            {
                Write-Warning "Unknown product kind '$_'"
            }
        }
    }
      
   

$Marketitems|Out-GridView -Title 'Azure Marketplace Items' -PassThru|foreach{

   $productid=$_.id

   # get name of azpkg
    $uri2 = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($AzureSubscriptionID.ToString())/resourceGroups/azurestack/providers/Microsoft.AzureStack/registrations/$Registration/products/$($productid)?api-version=2016-01-01"
    Write-Debug $URI2
    $Headers = @{ 'authorization'="Bearer $($Token.AccessToken)"} 
    $productDetails = Invoke-RestMethod -Method GET -Uri $uri2 -Headers $Headers
    $azpkgName = $productDetails.properties.galleryItemIdentity
    

    # get download location for apzkg
    $uri3 = "$($azureEnvironment.ResourceManagerUrl.ToString().TrimEnd('/'))/subscriptions/$($AzureSubscriptionID.ToString())/resourceGroups/azurestack/providers/Microsoft.AzureStack/registrations/$Registration/products/$productid/listDetails?api-version=2016-01-01"
    $uri3
    $downloadDetails = Invoke-RestMethod -Method POST -Uri $uri3 -Headers $Headers

    #Create Legal Terms POPUP
    $a = new-object -comobject wscript.shell
    $intAnswer = $a.popup($productDetails.properties.description, `
    0,"Legal Terms",4)
    If ($intAnswer -eq 6) 
    
    {
    # download azpkg
    $azpkgsource = $downloadDetails.galleryPackageBlobSasUri
    $FileExists=Test-Path "$destination\$azpkgName.azpkg"
    $DestinationCheck=Test-Path $destination
    If ($DestinationCheck -eq $false)
    {
    new-item -ItemType Directory -force $destination} else{}

    If ($FileExists -eq $true) {Remove-Item "$destination\$azpkgName.azpkg" -force} else {
    New-Item "$destination\$azpkgName.azpkg"}
    $azpkgdestination = "$destination\$azpkgName.azpkg"
    Start-BitsTransfer -source $azpkgsource -destination $azpkgdestination -Priority High
    


    # download vhd
    $vhdName = $productDetails.properties.galleryItemIdentity
    $vhdSource = $downloadDetails.properties.osDiskImage.sourceBlobSasUri
    If ([string]::IsNullOrEmpty($vhdsource)) {exit} else {
    $FileExists=Test-Path "$destination\$productid.vhd" 
    If ($FileExists -eq $true) {Remove-Item "$destination\$productid.vhd" -force} else {
    New-Item "$destination\$productid.vhd" }
    $vhdDestination = "$destination\$productid.vhd"
    
    Start-BitsTransfer -source $vhdSource -destination $vhdDestination -Priority High
} 
}

else {
  $a.popup("Legal Terms not accpeted, canceling")
}

}
}



function Set-String {
    param (
           [parameter(mandatory=$true)]
           [long] $size
         )

    if ($size -gt 1073741824) {
        return [string]([math]::Round($size / 1073741824)) + " GB"
    } elseif ($size -gt 1048576) {
        return [string]([math]::Round($size / 1048576)) + " MB"
    } else {return "<1 MB"} 
}

Export-ModuleMember -Function Sync-AzSOfflineMarketplaceItem
