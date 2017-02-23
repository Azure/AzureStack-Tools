# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.
<#
    .SYNOPSIS
    Contains 3 functions.
    Add-VMImage: Uploads a VM Image to your Azure Stack and creates a Marketplace item for it.
    Remove-VMImage: Removes an existing VM Image from your Azure Stack.  Does not delete any 
    maketplace items created by Add-VMImage.
    New-Server2016VMImage: Creates and Uploads a new Server 2016 Core and / or Full Image and
    creates a Marketplace item for it.
#>

Function Add-VMImage{

    [CmdletBinding(DefaultParameterSetName='VMImageFromLocal')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $publisher,
       
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $offer,
    
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $sku,
    
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [ValidatePattern(“\d+\.\d+\.\d+”)]
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
        [string] $ArmEndpoint = 'https://api.local.azurestack.global',

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

    $Domain = ""
    try {
        $uriARMEndpoint = [System.Uri] $ArmEndpoint
        $Domain = $ArmEndpoint.Split(".")[-3] + '.' + $ArmEndpoint.Split(".")[-2] + '.' + $ArmEndpoint.Split(".")[-1] 
    }
    catch {
        Write-Error "The specified ARM endpoint was invalid"
    }

    if($CreateGalleryItem -eq $false -and $PSBoundParameters.ContainsKey('title'))
    {
        Write-Error -Message "The title parameter only applies to creating a gallery item." -ErrorAction Stop
    }

    if($CreateGalleryItem -eq $false -and $PSBoundParameters.ContainsKey('description'))
    {
        Write-Error -Message "The description parameter only applies to creating a gallery item." -ErrorAction Stop
    }

    
    $resourceGroupName = "addvmimageresourcegroup"
    $storageAccountName = "addvmimagestorageaccount"
    $containerName = "addvmimagecontainer"

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint)

    #pre validate if image is not already deployed
    if (Get-AzureRmVMImage -Location $location -PublisherName $publisher -Offer $offer -Skus $sku -Version $version -ErrorAction SilentlyContinue) {
        Write-Error -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}", version "{3}" already is present. Please remove it first or change on of the values' -f $publisher,$offer,$sku,$version) -ErrorAction Stop
    }

    #potentially the RG was not cleaned up when exception happened in previous run. Test for exist
    if (-not (Get-AzureRmResourceGroup -Name $resourceGroupName -Location $location -ErrorAction SilentlyContinue)) {
        New-AzureRmResourceGroup -Name $resourceGroupName -Location $location 
    }

    #same for storage
    if (-not (Get-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
        $storageAccount = New-AzureRmStorageAccount -Name $storageAccountName -Location $location -ResourceGroupName $resourceGroupName -Type Standard_LRS
    }
    Set-AzureRmCurrentStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName
    #same for container
    if (-not (Get-AzureStorageContainer -Name $containerName -ErrorAction SilentlyContinue)) {
        New-AzureStorageContainer -Name $containerName -Permission Blob
    }

    if($pscmdlet.ParameterSetName -eq "VMImageFromLocal")
    {
        $script:osDiskName = Split-Path $osDiskLocalPath -Leaf
        $script:osDiskBlobURIFromLocal = "https://$storageAccountName.blob.$Domain/$containerName/$osDiskName"
        Add-AzureRmVhd -Destination $osDiskBlobURIFromLocal -ResourceGroupName $resourceGroupName -LocalFilePath $osDiskLocalPath -OverWrite

        $script:dataDiskBlobURIsFromLocal = New-Object System.Collections.ArrayList
        if ($PSBoundParameters.ContainsKey('dataDisksLocalPaths'))
        {
            foreach($dataDiskLocalPath in $dataDisksLocalPaths)
            {
                $dataDiskName = Split-Path $dataDiskLocalPath -Leaf
                $dataDiskBlobURI = "https://$storageAccountName.blob.$Domain/$containerName/$dataDiskName"
                $dataDiskBlobURIsFromLocal.Add($dataDiskBlobURI) 
                Add-AzureRmVhd  -Destination $dataDiskBlobURI -ResourceGroupName $resourceGroupName -LocalFilePath $dataDiskLocalPath -OverWrite
            }
        }
    }

    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/platformImage/publishers/' + $publisher
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
            Write-Error -Message "VM image download failed." -ErrorAction Stop
        }

        if($platformImage.Properties.ProvisioningState -eq 'Canceled')
        {
            Write-Error -Message "VM image download was canceled." -ErrorAction Stop
        }

        Write-Host "Downloading";
        Start-Sleep -Seconds 4
        $platformImage = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    }

    if($CreateGalleryItem -eq $true -And $platformImage.Properties.ProvisioningState -eq 'Succeeded')
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $basePath = Split-Path -Parent $MyInvocation.MyCommand.Module.Path
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

        $name = "$offer$sku"
        #Remove periods so that the offer and sku can be part of the MarketplaceItem name 
        $name =$name -replace "\.","-"

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

        $galleryItemURI = "https://$storageAccountName.blob.$Domain/$containerName/$galleryItemName"

        $blob = Set-AzureStorageBlobContent –Container $containerName –File $newPKGPath –Blob $galleryItemName

        Add-AzureRMGalleryItem -SubscriptionId $subscription -GalleryItemUri $galleryItemURI -ApiVersion 2015-04-01

        #cleanup
        Remove-Item $extractedGalleryItemPath -Recurse -Force
        Remove-Item $extractedGalleryPackagerPath -Recurse -Force
        Remove-Item $compressedGalleryPackagerPath
    }

    Remove-AzureStorageContainer –Name $containerName -Force
    Remove-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName 
    Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
}

Function Remove-VMImage{
    Param(
        [Parameter(Mandatory=$true)]
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $publisher,
       
        [Parameter(Mandatory=$true)]
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $offer,
    
        [Parameter(Mandatory=$true)]
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $sku,
    
        [Parameter(Mandatory=$true)]
        [ValidatePattern(“\d+\.\d+\.\d+”)]
        [String] $version,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Windows' ,'Linux')]
        [String] $osType,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [String] $location = 'local',

        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [string] $ArmEndpoint = 'https://api.local.azurestack.global'

    )

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint)

    if (Get-AzureRmVMImage -Location $location -PublisherName $publisher -Offer $offer -Skus $sku -Version $version -ErrorAction SilentlyContinue -ov images) {
        Write-Verbose "VM Image has been added to Azure Stack - continuing"
    }
    else{
        Write-Error -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}" is not present.' -f $publisher,$offer,$sku) -ErrorAction Stop
    }

    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/platformImage/publishers/' + $publisher
    $uri = $uri + '/offers/' + $offer + '/skus/' + $sku + '/versions/' + $version + '?api-version=2015-12-01-preview'

    try{
        Invoke-RestMethod -Method DELETE -Uri $uri -ContentType 'application/json' -Headers $headers
    }
    catch{
        Write-Error -Message ('Deletion of VM Image with publisher "{0}", offer "{1}", sku "{2}" failed with Error:"{3}.' -f $publisher,$offer,$sku,$Error) -ErrorAction Stop
    }

}

function New-Server2016VMImage {
    [cmdletbinding()]
    param (
        [Parameter()]
        [validateset('Full','Core','Both')]
        [String] $Version = 'Full',

        [switch] $IncludeLatestCU,

        [Parameter(ParameterSetName = 'PreDownloadedISO')]
        [ValidateScript({Test-Path -Path $_})]
        [string] $ISOPath,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.Credential()] $AzureStackCredentials,

        [ValidateNotNullorEmpty()]
        [String] $TenantId
    )
    process {
        if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Error -Message "New-Server2016VMImage must run with Administrator privileges" -ErrorAction Stop
        }
        $ModulePath = Split-Path -Path $MyInvocation.MyCommand.Module.Path
        $CoreEdition = 'Windows Server 2016 SERVERDATACENTERCORE'
        $FullEdition = 'Windows Server 2016 SERVERDATACENTER'

        if ($PSCmdlet.ParameterSetName -ne 'PreDownloadedISO') {
            #download ISO to temp file
            $CurrentProgressPref = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            Write-Verbose -Message "Starting download of Server 2016 Eval ISO. This will take some time." -Verbose
            $IsoIWRArg = @{
                Uri = 'http://care.dlservice.microsoft.com/dl/download/1/6/F/16FA20E6-4662-482A-920B-1A45CF5AAE3C/14393.0.160715-1616.RS1_RELEASE_SERVER_EVAL_X64FRE_EN-US.ISO'
                OutFile = "$ModulePath\14393.0.16715-1616.RS1_RELEASE_SERVER_EVAL_X64FRE_EN-US.ISO"
                UseBasicParsing = $true
            }
            Invoke-WebRequest @IsoIWRArg
            $ProgressPreference = $CurrentProgressPref
            Unblock-File -Path $IsoIWRArg.OutFile
            $ISOPath = $IsoIWRArg.OutFile
        }

        if ($IncludeLatestCU) {
            $CurrentProgressPref = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            Write-Verbose -Message "Starting download of latest CU. This will take some time." -Verbose
            $CUIWRArg = @{
                #for latest CU, check https://support.microsoft.com/en-us/help/4000825/windows-10-and-windows-server-2016-update-history
                Uri = 'http://download.windowsupdate.com/d/msdownload/update/software/updt/2017/01/windows10.0-kb4010672-x64_e12a6da8744518197757d978764b6275f9508692.msu'
                OutFile = "$ModulePath\windows10.0-kb3213986-x64_a1f5adacc28b56d7728c92e318d6596d9072aec4.msu"
                UseBasicParsing = $true
            }
            Invoke-WebRequest @CUIWRArg
            $ProgressPreference = $CurrentProgressPref
            Unblock-File -Path $CUIWRArg.OutFile
         
            #expand cab from msu
            $expandcab = expand -f:*KB*.cab (Resolve-Path $CUIWRArg.OutFile) (Split-Path (Resolve-Path $CUIWRArg.OutFile))
        }

        $mount = Mount-DiskImage -ImagePath $ISOPath -PassThru
        $DriveLetter = ($mount | Get-Volume).DriveLetter
        . $DriveLetter`:\NanoServer\NanoServerImageGenerator\Convert-WindowsImage.ps1
        $mount | Dismount-DiskImage
    
        $ConvertParams = @{
            SourcePath          = $ISOPath
            VHDFormat           = 'vhd'
            DiskLayout          = 'BIOS'
            SizeBytes           = 60GB
            RemoteDesktopEnable = $true
        }

        if ($IncludeLatestCU) {
            [void] $ConvertParams.Add('Package', $expandcab[3].Split()[1])
        }

        $PublishArguments = @{
            publisher = 'MicrosoftWindowsServer'
            offer = 'WindowsServer'
            version = '1.0.0'
            osType = 'Windows'
            tenantID = $tenantID
            azureStackCredentials = $AzureStackCredentials
        }
        
        if ($Version -eq 'Core' -or $Version -eq 'Both') {
            $2016CoreParams = $ConvertParams.Clone()
            [void] $2016CoreParams.Add('VHDPath',"$ModulePath\Server2016DatacenterCoreEval.vhd")
            [void] $2016CoreParams.Add('Edition',$CoreEdition)
            Write-Verbose -Message "Creating Server Core Image"
            Convert-WindowsImage @2016CoreParams
            Add-VMImage -sku "2016-Datacenter-Core" -osDiskLocalPath $2016CoreParams.VHDPath @PublishArguments
        }
        if ($Version -eq 'Full' -or $Version -eq 'Both') {
            $2016FullParams = $ConvertParams.Clone()
            [void] $2016FullParams.Add('VHDPath',"$ModulePath\Server2016DatacenterFullEval.vhd")
            [void] $2016FullParams.Add('Edition',$FullEdition)
            Write-Verbose -Message "Creating Server Full Image" -Verbose
            Convert-WindowsImage @2016FullParams
            Add-VMImage -sku "2016-Datacenter" -osDiskLocalPath $2016FullParams.VHDPath @PublishArguments
        }
    }
}