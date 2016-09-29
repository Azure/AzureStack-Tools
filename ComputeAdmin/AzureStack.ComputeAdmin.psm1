# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.
<#
    .SYNOPSIS
    Uploads a VM Image to your Azure Stack and creates a Marketplace item for it.
#>

Function Add-VMImage{

    [CmdletBinding(DefaultParameterSetName='VMImageFromLocal')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $publisher,
       
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $offer,
    
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $sku,
    
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $version,

        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [ValidateNotNullorEmpty()]
        [String] $osDiskLocalPath,

        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $osDiskBlobURI,

        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidateSet('Windows' ,'Linux')]
        [String] $osType,

        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [Parameter(ParameterSetName='VMImageFromLocal')]
        [Parameter(ParameterSetName='VMImageFromAzure')]
        [String] $location = 'local',

        [Parameter(ParameterSetName='VMImageFromLocal')]
        [string[]] $dataDisksLocalPaths,

        [Parameter(ParameterSetName='VMImageFromAzure')]
        [string[]] $dataDiskBlobURIs,

        [Parameter(ParameterSetName='VMImageFromLocal')]
        [Parameter(ParameterSetName='VMImageFromAzure')]
        [string] $billingPartNumber,

        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='VMImageFromLocal')]
        [Parameter(ParameterSetName='VMImageFromAzure')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='VMImageFromLocal')]
        [Parameter(ParameterSetName='VMImageFromAzure')]
        [string] $title,

        [Parameter(ParameterSetName='VMImageFromLocal')]
        [Parameter(ParameterSetName='VMImageFromAzure')]
        [string] $description,

        [Parameter(ParameterSetName='VMImageFromLocal')]
        [Parameter(ParameterSetName='VMImageFromAzure')]
        [bool] $CreateGalleryItem = $true
    )

    if($CreateGalleryItem -eq $false -and $PSBoundParameters.ContainsKey('title'))
    {
        throw "The title parameter only applies to creating a gallery item."
        exit
    }

    if($CreateGalleryItem -eq $false -and $PSBoundParameters.ContainsKey('description'))
    {
        throw "The description parameter only applies to creating a gallery item."
        exit
    }

    
    $resourceGroupName = "addvmimageresourcegroup"
    $storageAccountName = "addvmimagestorageaccount"
    $containerName = "addvmimagecontainer"
    $subscriptionName = "Default Provider Subscription"

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"

    Add-AzureRmEnvironment -Name 'Azure Stack' `
        -ActiveDirectoryEndpoint $authority `
        -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId `
        -ResourceManagerEndpoint  "https://api.$azureStackDomain/" `
        -GalleryEndpoint $galleryEndpoint `
        -GraphEndpoint $graphEndpoint `

    $environment = Get-AzureRmEnvironment 'Azure Stack'

    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials

    Select-AzureRmProfile -Profile $profile
    $subscription = Get-AzureRmSubscription -SubscriptionName $subscriptionName  | Select-AzureRmSubscription

    New-AzureRmResourceGroup -Name $resourceGroupName -Location $location 
    $storageAccount = New-AzureRmStorageAccount -Name $storageAccountName -Location $location -ResourceGroupName $resourceGroupName -Type Standard_LRS
    Set-AzureRmCurrentStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName
    New-AzureStorageContainer -Name $containerName  -Permission Blob

    if($pscmdlet.ParameterSetName -eq "VMImageFromLocal")
    {
        $script:osDiskName = Split-Path $osDiskLocalPath -Leaf
        $script:osDiskBlobURIFromLocal = "https://$storageAccountName.blob.$azureStackDomain/$containerName/$osDiskName"
        Add-AzureRmVhd  -Destination $osDiskBlobURIFromLocal -ResourceGroupName $resourceGroupName -LocalFilePath $osDiskLocalPath

        $script:dataDiskBlobURIsFromLocal = New-Object System.Collections.ArrayList
        if ($PSBoundParameters.ContainsKey('dataDisksLocalPaths'))
        {
            foreach($dataDiskLocalPath in $dataDisksLocalPaths)
            {
                $dataDiskName = Split-Path $dataDiskLocalPath -Leaf
                $dataDiskBlobURI = "https://$storageAccountName.blob.$azureStackDomain/$containerName/$dataDiskName"
                $dataDiskBlobURIsFromLocal.Add($dataDiskBlobURI) 
                Add-AzureRmVhd  -Destination $dataDiskBlobURI -ResourceGroupName $resourceGroupName -LocalFilePath $dataDiskLocalPath 
            }
        }
    }

    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"

    $adminToken = Get-AzureStackToken `
        -Authority $authority `
        -Resource $activeDirectoryServiceEndpointResourceId `
        -AadTenantId $tenantID `
        -ClientId $powershellClientId `
        -Credential $azureStackCredentials

    $headers =  @{ Authorization = ("Bearer $adminToken") }

    $armEndpoint = 'https://api.' + $azureStackDomain
    $uri = $armEndpoint + '/subscriptions/' + $subscription.Subscription.SubscriptionId + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/platformImage/publishers/' + $publisher
    $uri = $uri + '/offers/' + $offer + '/skus/' + $sku + '/versions/' + $version + '?api-version=2015-12-01-preview'


#building platform image JSON

    #building osDisk json
    if($pscmdlet.ParameterSetName -eq "VMImageFromLocal")
    {
        $osDiskJSON = '"OsDisk":{"OsType":"'+ $osType + '","Uri":"'+$osDiskBlobURIFromLocal+'"}'
    }
    else
    {
        $osDiskJSON = '"OsDisk":{"OsType":"'+ $osType + '","Uri":"'+$osDiskBlobURI+'"}'
    }

    #building details JSON
    $detailsJSON = ''
    if ($PSBoundParameters.ContainsKey('billingPartNumber'))
    {
        $detailsJSON = '"Details":{"BillingPartNumber":"' + $billingPartNumber+'"}'
    }

    #building dataDisk JSON
    $dataDisksJSON = ''

    if($pscmdlet.ParameterSetName -eq "VMImageFromLocal")
    {
        if ($dataDiskBlobURIsFromLocal.Count -ne 0)
        {
             $dataDisksJSON = '"DataDisks":['
             $i = 0
             foreach($dataDiskBlobURI in $dataDiskBlobURIsFromLocal)
             {
                if($i -ne 0)
                {
                    $dataDisksJSON = $dataDisksJSON +', '
                }

                $newDataDisk = '{"Lun":' + $i + ', "Uri":"' + $dataDiskBlobURI + '"}'
                $dataDisksJSON = $dataDisksJSON + $newDataDisk;
            
                ++$i
             }

             $dataDisksJSON = $dataDisksJSON +']'
       }
    }
    else
    {
        if ($dataDiskBlobURIs.Count -ne 0)
        {
            $dataDisksJSON = '"DataDisks":['
            $i = 0
            foreach($dataDiskBlobURI in $dataDiskBlobURIs)
            {
                if($i -ne 0)
                {
                    $dataDisksJSON = $dataDisksJSON +', '
                }

                $newDataDisk = '{"Lun":' + $i + ', "Uri":"' + $dataDiskBlobURI + '"}'
                $dataDisksJSON = $dataDisksJSON + $newDataDisk;
            
                ++$i
            }

            $dataDisksJSON = $dataDisksJSON +']'
        }
    }

    #building ARMResource

    $propertyBody = $osDiskJSON 

    if(![string]::IsNullOrEmpty($dataDisksJson))
    {
        $propertyBody = $propertyBody + ', ' + $dataDisksJson
    }

    if(![string]::IsNullOrEmpty($detailsJson))
    {
        $propertyBody = $propertyBody + ', ' + $detailsJson
    }

    $RequestBody = '{"Properties":{'+$propertyBody+'}}'

    Invoke-RestMethod -Method PUT -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $Headers

    $platformImage = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers

    while($platformImage.Properties.ProvisioningState -ne 'Succeeded')
    {
        if($platformImage.Properties.ProvisioningState -eq 'Failed')
        {
            Write-Host "VM image download failed.";
            break;
        }

        if($platformImage.Properties.ProvisioningState -eq 'Canceled')
        {
            Write-Host "VM image download was canceled.";
            break;
        }

        Write-Host "Downloading";
        Start-Sleep -s 4
        $platformImage = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    }

    if($CreateGalleryItem -eq $true -And $platformImage.Properties.ProvisioningState -eq 'Succeeded')
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $basePath = Split-Path -Parent  $MyInvocation.MyCommand.Module.Path
        $compressedGalleryItemPath = Join-Path $basePath 'CustomizedVMGalleryItem.azpkg'
        $extractedGalleryItemPath = Join-Path $basePath 'galleryItem'

        New-Item -ItemType directory -Path $extractedGalleryItemPath

        [System.IO.Compression.ZipFile]::ExtractToDirectory($compressedGalleryItemPath, $extractedGalleryItemPath)

        $createUIDefinitionPath = Join-Path $extractedGalleryItemPath 'DeploymentTemplates\CreateUIDefinition.json'
        $JSON = Get-Content $createUIDefinitionPath | Out-String | ConvertFrom-Json
        $JSON.parameters.osPlatform = $osType
        $JSON.parameters.imageReference.publisher = $publisher
        $JSON.parameters.imageReference.offer = $offer
        $JSON.parameters.imageReference.sku = $sku
        $JSON | ConvertTo-Json -Compress| set-content $createUIDefinitionPath

        $manifestPath = Join-Path $extractedGalleryItemPath 'manifest.json'
        $JSON = Get-Content $manifestPath | Out-String | ConvertFrom-Json

        $displayName = ''
        if ($PSBoundParameters.ContainsKey('title'))
        {
            $displayName = $title
        }
        else
        {
            $displayName = "{0}-{1}-{2}" -f $publisher, $offer, $sku
        }

        $name = (New-Guid).guid

        $JSON.name = $name
        $JSON.publisher = $publisher
        $JSON.version = $version
        $JSON.displayName = $displayName
        $JSON.publisherDisplayName = $publisher
        $JSON.publisherLegalName = $publisher
        $JSON | ConvertTo-Json -Compress| set-content $manifestPath

        $stringsPath = Join-Path $extractedGalleryItemPath 'strings\resources.resjson'
        $JSON = Get-Content $stringsPath | Out-String | ConvertFrom-Json

        $descriptionToSet = ''
        if ($PSBoundParameters.ContainsKey('description'))
        {
            $descriptionToSet = $description
        }
        else
        {
            $descriptionToSet = "Create a virtual machine from a VM image. Publisher: {0}, Offer: {1}, Sku:{2}, Version: {3}" -f $publisher, $offer, $sku, $version
        }

        $extractedName = 'MarketplaceItem.zip'
        $compressedGalleryPackagerPath = Join-Path $basePath $extractedName
        $extractedGalleryPackagerPath = Join-Path $basePath 'MarketplaceItem'

        $JSON.longSummary = $descriptionToSet
        $JSON.description = $descriptionToSet
        $JSON.summary = $descriptionToSet
        $JSON | ConvertTo-Json -Compress | set-content $stringsPath

        Invoke-WebRequest -Uri http://www.aka.ms/azurestackmarketplaceitem -OutFile $compressedGalleryPackagerPath

        [System.IO.Compression.ZipFile]::ExtractToDirectory($compressedGalleryPackagerPath, $extractedGalleryPackagerPath)

        $extractedGalleryPackagerExePath = Join-Path $extractedGalleryPackagerPath "Azure Stack Marketplace Item Generator and Sample\AzureGalleryPackageGenerator"

        $galleryItemName = $publisher + "." + $name + "." + $version + ".azpkg"
        $newPKGPath = Join-Path $extractedGalleryPackagerExePath $galleryItemName

        $currentPath = $pwd

        cd $extractedGalleryPackagerExePath

        .\AzureGalleryPackager.exe package -m $manifestPath -o .

        cd $currentPath

        $galleryItemURI = "https://$storageAccountName.blob.$azureStackDomain/$containerName/$galleryItemName"

        $blob = Set-AzureStorageBlobContent –Container $containerName –File $newPKGPath –Blob $galleryItemName

        Add-AzureRMGalleryItem -SubscriptionId $subscription.Subscription.SubscriptionId -GalleryItemUri $galleryItemURI -ApiVersion 2015-04-01

        #cleanup
        Remove-Item $extractedGalleryItemPath -recurse -Force
        Remove-Item $extractedGalleryPackagerPath -recurse -Force
        Remove-Item $compressedGalleryPackagerPath
    }

    Remove-AzureStorageContainer –Name $containerName -Force
    Remove-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName 
    Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
}