# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
    .SYNOPSIS
    Adds the VMSS Gallery Item to your Azure Stack Marketplace.
#>
function Add-AzsVMSSGalleryItem {
    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidatePattern("^[0-9a-zA-Z]+$")]
        [ValidateLength(1, 128)]
        [String] $Location
    )
    
    $Location = Get-AzsHomeLocation -Location $Location
    $rgName = "vmss.gallery"

    New-AzureRmResourceGroup -Name $rgName -Location $Location -Force

    $saName = "vmssgallery"

    $null = New-AzureRmStorageAccount -ResourceGroupName $rgName -Location $Location -Name $saName -Type Standard_LRS

    $cName = "gallery"

    Set-AzureRmCurrentStorageAccount -StorageAccountName $saName -ResourceGroupName $rgName

    $container = Get-AzureStorageContainer -Name $cName -ErrorAction SilentlyContinue

    if (-not ($container)) {
        New-AzureStorageContainer -Name $cName -Permission Blob
    }
    
    $fileName = "microsoft.vmss.1.3.6.azpkg"

    $blob = Set-AzureStorageBlobContent -File ($PSScriptRoot + "\" + $fileName) -Blob $fileName -Container $cName -Force

    $container = Get-AzureStorageContainer -Name $cName -ErrorAction SilentlyContinue

    $uri = $blob.Context.BlobEndPoint + $container.Name + "/" + $blob.Name    

    Add-AzsGalleryItem -GalleryItemUri $uri
}

Export-ModuleMember -Function 'Add-AzsVMSSGalleryItem' 

<#
    .SYNOPSIS
    Adds the VMSS Gallery Item from your Azure Stack Marketplace.
#>
function Remove-AzsVMSSGalleryItem {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    $item = Get-AzsGalleryItem -Name "microsoft.vmss.1.3.6"

    if ($item) {
        
        if ($pscmdlet.ShouldProcess("Delete VMSS Gallery Item")) {
            $null = $item | Remove-AzsGalleryItem
            $item
        }
    }
}

Export-ModuleMember -Function 'Remove-AzsVMSSGalleryItem' 

<#
    .SYNOPSIS
    Uploads a VM Image to your Azure Stack and creates a Marketplace item for it.
#>
function Add-AzsVMImage {

    [CmdletBinding(DefaultParameterSetName = 'VMImageFromLocal')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromLocal')]
        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromAzure')]
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Publisher,
       
        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromLocal')]
        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromAzure')]
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Offer,
    
        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromLocal')]
        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromAzure')]
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Sku,
    
        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromLocal')]
        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromAzure')]
        [ValidatePattern("\d+\.\d+\.\d+")]
        [String] $Version,

        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromLocal')]
        [ValidateNotNullorEmpty()]
        [String] $OSDiskLocalPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $OSDiskBlobURI,

        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromLocal')]
        [Parameter(Mandatory = $true, ParameterSetName = 'VMImageFromAzure')]
        [ValidateSet('Windows' , 'Linux')]
        [String] $OSType,

        [Parameter(Mandatory = $false, ParameterSetName = 'VMImageFromLocal')]
        [Parameter(Mandatory = $false, ParameterSetName = 'VMImageFromAzure')]
        [String] $Location,

        [Parameter(ParameterSetName = 'VMImageFromLocal')]
        [string[]] $DataDisksLocalPaths,

        [Parameter(ParameterSetName = 'VMImageFromAzure')]
        [string[]] $DataDiskBlobURIs,

        [Parameter(ParameterSetName = 'VMImageFromLocal')]
        [Parameter(ParameterSetName = 'VMImageFromAzure')]
        [string] $BillingPartNumber,

        [Parameter(ParameterSetName = 'VMImageFromLocal')]
        [Parameter(ParameterSetName = 'VMImageFromAzure')]
        [string] $Title,

        [Parameter(ParameterSetName = 'VMImageFromLocal')]
        [Parameter(ParameterSetName = 'VMImageFromAzure')]
        [string] $Description,

        [Parameter(ParameterSetName = 'VMImageFromLocal')]
        [Parameter(ParameterSetName = 'VMImageFromAzure')]
        [bool] $CreateGalleryItem = $true,

        [switch] $Force
    )
        
    $location = Get-AzsHomeLocation -Location $location

    if ($CreateGalleryItem -eq $false -and $PSBoundParameters.ContainsKey('title')) {
        Write-Error -Message "The title parameter only applies to creating a gallery item." -ErrorAction Stop
    }

    if ($CreateGalleryItem -eq $false -and $PSBoundParameters.ContainsKey('description')) {
        Write-Error -Message "The description parameter only applies to creating a gallery item." -ErrorAction Stop
    }
   
    $resourceGroupName = "addvmimageresourcegroup"
    $storageAccountName = "addvmimagestorageaccount"
    $containerName = "addvmimagecontainer"

    #pre validate if image is not already deployed
    $VMImageAlreadyAvailable = $false
    if ($(Get-AzsVMImage -publisher $publisher -offer $offer -sku $sku -version $version -location $location -ErrorAction SilentlyContinue).Properties.ProvisioningState -eq 'Succeeded') {
        $VMImageAlreadyAvailable = $true
        Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}", version "{3}" already is present.' -f $publisher, $offer, $sku, $version) -Verbose -ErrorAction Stop
    }

    #potentially the RG was not cleaned up when exception happened in previous run. Test for exist
    if (-not (Get-AzureRmResourceGroup -Name $resourceGroupName -Location $location -ErrorAction SilentlyContinue)) {
        New-AzureRmResourceGroup -Name $resourceGroupName -Location $location 
    }

    #same for storage
    $storageAccount = Get-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    if (-not ($storageAccount)) {
        $storageAccount = New-AzureRmStorageAccount -Name $storageAccountName -Location $location -ResourceGroupName $resourceGroupName -Type Standard_LRS 
    }
    Set-AzureRmCurrentStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName 
    #same for container
    $container = Get-AzureStorageContainer -Name $containerName -ErrorAction SilentlyContinue
    if (-not ($container)) {
        $container = New-AzureStorageContainer -Name $containerName -Permission Blob
    }

    if (($pscmdlet.ParameterSetName -eq "VMImageFromLocal") -and (-not $VMImageAlreadyAvailable)) {
        $storageAccount.PrimaryEndpoints.Blob
        $script:osDiskName = Split-Path $osDiskLocalPath -Leaf
        $script:osDiskBlobURIFromLocal = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName, $osDiskName
        Add-AzureRmVhd -Destination $osDiskBlobURIFromLocal -ResourceGroupName $resourceGroupName -LocalFilePath $osDiskLocalPath -OverWrite

        $script:dataDiskBlobURIsFromLocal = New-Object System.Collections.ArrayList
        if ($PSBoundParameters.ContainsKey('dataDisksLocalPaths')) {
            foreach ($dataDiskLocalPath in $dataDisksLocalPaths) {
                $dataDiskName = Split-Path $dataDiskLocalPath -Leaf
                $dataDiskBlobURI = "https://$storageAccountName.blob.$Domain/$containerName/$dataDiskName"
                $dataDiskBlobURIsFromLocal.Add($dataDiskBlobURI) 
                Add-AzureRmVhd  -Destination $dataDiskBlobURI -ResourceGroupName $resourceGroupName -LocalFilePath $dataDiskLocalPath -OverWrite
            }
        }
    }
       
    #building platform image JSON

    #building osDisk json
    if ($pscmdlet.ParameterSetName -eq "VMImageFromLocal") {
        $osDiskJSON = '"OsDisk":{"OsType":"' + $osType + '","Uri":"' + $osDiskBlobURIFromLocal + '"}'
    }
    else {
        $osDiskJSON = '"OsDisk":{"OsType":"' + $osType + '","Uri":"' + $osDiskBlobURI + '"}'
    }

    #building details JSON
    $detailsJSON = ''
    if ($PSBoundParameters.ContainsKey('billingPartNumber')) {
        $detailsJSON = '"Details":{"BillingPartNumber":"' + $billingPartNumber + '"}'
    }

    #building dataDisk JSON
    $dataDisksJSON = ''

    if ($pscmdlet.ParameterSetName -eq "VMImageFromLocal") {
        if ($dataDiskBlobURIsFromLocal.Count -ne 0) {
            $dataDisksJSON = '"DataDisks":['
            $i = 0
            foreach ($dataDiskBlobURI in $dataDiskBlobURIsFromLocal) {
                if ($i -ne 0) {
                    $dataDisksJSON = $dataDisksJSON + ', '
                }

                $newDataDisk = '{"Lun":' + $i + ', "Uri":"' + $dataDiskBlobURI + '"}'
                $dataDisksJSON = $dataDisksJSON + $newDataDisk;
            
                ++$i
            }

            $dataDisksJSON = $dataDisksJSON + ']'
        }
    }
    else {
        if ($dataDiskBlobURIs.Count -ne 0) {
            $dataDisksJSON = '"DataDisks":['
            $i = 0
            foreach ($dataDiskBlobURI in $dataDiskBlobURIs) {
                if ($i -ne 0) {
                    $dataDisksJSON = $dataDisksJSON + ', '
                }

                $newDataDisk = '{"Lun":' + $i + ', "Uri":"' + $dataDiskBlobURI + '"}'
                $dataDisksJSON = $dataDisksJSON + $newDataDisk;
            
                ++$i
            }

            $dataDisksJSON = $dataDisksJSON + ']'
        }
    }

    #building ARMResource

    $propertyBody = $osDiskJSON 

    if (![string]::IsNullOrEmpty($dataDisksJson)) {
        $propertyBody = $propertyBody + ', ' + $dataDisksJson
    }

    if (![string]::IsNullOrEmpty($detailsJson)) {
        $propertyBody = $propertyBody + ', ' + $detailsJson
    }
    
    if (-not $VMImageAlreadyAvailable) {
        $imageDescription = "publisher: {0}, offer: {1}, sku: {2}, version: {3}" -f $publisher, $offer, $sku, $version
        
        $propertyBody = "{" + $propertyBody + "}"
        $params = @{
            ResourceType = "Microsoft.Compute.Admin/locations/artifactTypes/publishers/offers/skus/versions"
            ResourceName = "{0}/platformImage/{1}/{2}/{3}/{4}" -f $location, $publisher, $offer, $sku, $version
            ApiVersion   = "2015-12-01-preview"
            Properties   = ConvertFrom-Json $propertyBody
        }
        
        Write-Verbose "Creating VM Image..."
        New-AzureRmResource @params -ErrorAction Stop -Force
    }

    $platformImage = Get-AzsVMImage -publisher $publisher -offer $offer -sku $sku -version $version -location $location

    while ($platformImage.Properties.ProvisioningState -ne 'Succeeded') {
        if ($platformImage.Properties.ProvisioningState -eq 'Failed') {
            Write-Error -Message "VM image download failed." -ErrorAction Stop
        }

        if ($platformImage.Properties.ProvisioningState -eq 'Canceled') {
            Write-Error -Message "VM image download was canceled." -ErrorAction Stop
        }

        Write-Verbose "Downloading...";
        Start-Sleep -Seconds 10
        $platformImage = Get-AzsVMImage -publisher $publisher -offer $offer -sku $sku -version $version -location $location
    }

    #reaquire storage account context
    Set-AzureRmCurrentStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName
    $container = Get-AzureStorageContainer -Name $containerName -ErrorAction SilentlyContinue

    if ($CreateGalleryItem -eq $true -And $platformImage.Properties.ProvisioningState -eq 'Succeeded') {
        $GalleryItem = CreateGalleryItem -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -title $title -description $description 
        $null = $container| Set-AzureStorageBlobContent -File $GalleryItem.FullName -Blob $galleryItem.Name
        $galleryItemURI = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName, $galleryItem.Name

        Add-AzsGalleryItem -GalleryItemUri $galleryItemURI

        #cleanup
        Remove-Item $GalleryItem
    }

    Remove-AzureStorageContainer -Name $containerName -Force
    Remove-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName 
    Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
}

Export-ModuleMember -Function 'Add-AzsVMImage' 

<#
    .SYNOPSIS
    Removes an existing VM Image from your Azure Stack.  Does not delete any maketplace items created by Add-AzSVMImage.
#>
function Remove-AzsVMImage {

    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Publisher,
       
        [Parameter(Mandatory = $true)]
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Offer,
    
        [Parameter(Mandatory = $true)]
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Sku,
    
        [Parameter(Mandatory = $true)]
        [ValidatePattern("\d+\.\d+\.\d+")]
        [String] $Version,

        [Parameter(Mandatory = $false)]
        [String] $Location,

        [switch] $KeepMarketplaceItem,

        [switch] $Force
    )
        
    $location = Get-AzsHomeLocation -Location $location
        
    $VMImageExists = $false
    if (Get-AzsVMImage -publisher $publisher -offer $offer -sku $sku -version $version -location $location -ErrorAction SilentlyContinue) {
        Write-Verbose "VM Image is present in Azure Stack - continuing to remove" -Verbose
        $VMImageExists = $true
    }
    else {
        Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}" is not present and will not be removed. Marketplace item may still be removed.' -f $publisher, $offer, $sku) -ErrorAction Stop
    }

    if ($VMImageExists) {
        $imageDescription = "publisher: {0}, offer: {1}, sku: {2}, version: {3}" -f $publisher, $offer, $sku, $version
        if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to delete VM image with $imageDescription ?", "")) {
            try {
                $params = @{
                    ResourceType = "Microsoft.Compute.Admin/locations/artifactTypes/publishers/offers/skus/versions"
                    ResourceName = "{0}/platformImage/{1}/{2}/{3}/{4}" -f $location, $publisher, $offer, $sku, $version
                    ApiVersion   = "2015-12-01-preview"
                }

                Write-Verbose -Message "Deleting VM Image" -Verbose
                Remove-AzureRmResource @params -Force
            }
            catch {                
                Write-Error -Message ('Deletion of VM Image with {0} failed with Error:{1}.' -f $imageDescription, $Error) -ErrorAction Stop
            }
        }
    }

    if (-not $KeepMarketplaceItem) {
        Write-Verbose "Removing the marketplace item for the VM Image." -Verbose
        $name = "$offer$sku"
        #Remove periods so that the offer and sku can be retrieved from the Marketplace Item name
        $name = $name -replace "\.", "-"

        if ($pscmdlet.ShouldProcess("$("Remove Gallery Item: '{0}', offer: '{1}', sku: '{2}'" -f $publisher,$offer,$sku)")) {

            Get-AzsGalleryItem | Where-Object {$_.Name -contains "$publisher.$name.$version"} | Remove-AzsGalleryItem 
        }
    }
}

Export-ModuleMember -Function 'Remove-AzsVMImage' 

<#
    .SYNOPSIS
    Gets a VM Image from your Azure Stack as an Administrator to view the provisioning state of the image.
#>
function Get-AzsVMImage {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Publisher,
       
        [Parameter(Mandatory = $true)]
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Offer,
    
        [Parameter(Mandatory = $true)]
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Sku,
    
        [Parameter(Mandatory = $true)]
        [ValidatePattern("\d+\.\d+\.\d+")]
        [String] $Version,

        [Parameter(Mandatory = $false)]
        [String] $Location
    )

    $location = Get-AzsHomeLocation -Location $location

    $params = @{
        ResourceType = "Microsoft.Compute.Admin/locations/artifactTypes/publishers/offers/skus/versions"
        ResourceName = "{0}/platformImage/{1}/{2}/{3}/{4}" -f $location, $publisher, $offer, $sku, $version
        ApiVersion   = "2015-12-01-preview"
    }

    try {
        $platformImage = Get-AzureRmResource @params
        return $platformImage
    }
    catch {
        return $null
    }
}

Export-ModuleMember -Function 'Get-AzsVMImage'

<#
    .SYNOPSIS
    Creates and Uploads a new Server 2016 Core and / or Full Image and creates a Marketplace item for it.
#>
function New-AzsServer2016VMImage {
    [cmdletbinding(DefaultParameterSetName = 'NoCU')]
    param (
        [Parameter()]
        [validateset('Full', 'Core', 'Both')]
        [String] $Version = 'Full',

        [Parameter(ParameterSetName = 'LatestCU')]
        [switch] $IncludeLatestCU,

        [Parameter(ParameterSetName = 'ManualCUUri')]
        [string] $CUUri,

        [Parameter(ParameterSetName = 'ManualCUPath')]
        [string] $CUPath,
        
        [Parameter()]
        [string] $VHDSizeInMB = 40960,

        [Parameter(Mandatory)]
        [ValidateScript( {Test-Path -Path $_})]
        [string] $ISOPath,

        [Parameter(Mandatory = $false)]
        [String] $Location,
        
        [Parameter()]
        [bool] $CreateGalleryItem = $true,

        [Parameter()]
        [bool] $Net35 = $true
    )
    begin {
        function CreateWindowsVHD {
            [cmdletbinding()]
            param (
                [string] $VHDPath,
                [uint32] $VHDSizeInMB,
                [string] $IsoPath,
                [string] $Edition,
                [string] $CabPath,
                [switch] $Net35
            )
            $tmpfile = New-TemporaryFile
            "create vdisk FILE=`"$VHDPath`" TYPE=EXPANDABLE MAXIMUM=$VHDSizeInMB" | 
                Out-File -FilePath $tmpfile.FullName -Encoding ascii

            Write-Verbose -Message "Creating VHD at: $VHDPath of size: $VHDSizeInMB MB"
            diskpart.exe /s $tmpfile.FullName | Out-Null

            $tmpfile | Remove-Item -Force

            try {
                if (!(Test-Path -Path $VHDPath)) {
                    Write-Error -Message "VHD was not created" -ErrorAction Stop
                }
                Write-Verbose -Message "Preparing VHD"

                $VHDMount = Mount-DiskImage -ImagePath $VHDPath -PassThru -ErrorAction Stop
                $disk = $VHDMount | Get-DiskImage -ErrorAction Stop | Get-Disk -ErrorAction SilentlyContinue
                $disk | Initialize-Disk -PartitionStyle MBR -ErrorAction Stop
                $partition = New-Partition -UseMaximumSize -Disknumber $disk.DiskNumber -IsActive:$True -AssignDriveLetter -ErrorAction Stop
                $volume = Format-Volume -Partition $partition -FileSystem NTFS -confirm:$false -ErrorAction Stop
                $VHDDriveLetter = $volume.DriveLetter

                Write-Verbose -Message "VHD is mounted at drive letter: $VHDDriveLetter"

                Write-Verbose -Message "Mounting ISO"
                $IsoMount = Mount-DiskImage -ImagePath $ISOPath -PassThru
                $IsoDriveLetter = ($IsoMount | Get-Volume).DriveLetter

                Write-Verbose -Message "ISO is mounted at drive letter: $IsoDriveLetter"

                Write-Verbose -Message "Applying Image $Edition to VHD"
                $ExpandArgs = @{
                    ApplyPath   = "$VHDDriveLetter`:\" 
                    ImagePath   = "$IsoDriveLetter`:\Sources\install.wim"
                    Name        = $Edition
                    ErrorAction = 'Stop'
                }
                $null = Expand-WindowsImage @ExpandArgs

                if ($CabPath) {
                    Write-Verbose -Message "Applying update: $(Split-Path -Path $CabPath -Leaf)"
                    $null = Add-WindowsPackage -PackagePath $CabPath -Path "$VHDDriveLetter`:\"  -ErrorAction Stop
                }
                
                if ($Net35) {
                    Write-Verbose -Message "Adding .NET 3.5"
                    $null = Add-WindowsPackage -PackagePath "$IsoDriveLetter`:\sources\sxs\microsoft-windows-netfx3-ondemand-package.cab" -Path "$VHDDriveLetter`:\" 
                }

                Write-Verbose -Message "Making VHD bootable"
                $null = & "$VHDDriveLetter`:\Windows\System32\bcdboot.exe" "$VHDDriveLetter`:\windows" "/s" "$VHDDriveLetter`:" "/f" "BIOS"
            }
            catch {
                Write-Error -ErrorRecord $_ -ErrorAction Stop
            }
            finally {
                if ($VHDMount) {
                    $VHDMount | Dismount-DiskImage
                }
                if ($IsoMount) {
                    $IsoMount | Dismount-DiskImage
                }
            }
        }

        function ExpandMSU {
            param (
                $Path
            )

            $expandcab = expand -f:*KB*.cab (Resolve-Path $Path) (Split-Path (Resolve-Path $Path))
            $expandcab[3].Split()[1]
        }
    }
    process {
    
        $location = Get-AzsHomeLocation -Location $location
        Write-Verbose -Message "Checking ISO path for a valid ISO." -Verbose
        if (!$IsoPath.ToLower().contains('.iso')) {
            Write-Error -Message "ISO path is not a valid ISO file." -ErrorAction Stop
        }

        if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Error -Message "New-AzsServer2016VMImage must run with Administrator privileges" -ErrorAction Stop
        }
        $ModulePath = Split-Path -Path $MyInvocation.MyCommand.Module.Path
        $CoreEdition = 'Windows Server 2016 SERVERDATACENTERCORE'
        $FullEdition = 'Windows Server 2016 SERVERDATACENTER'

        if ($pscmdlet.ParameterSetName -ne 'NoCU') {
            if ($pscmdlet.ParameterSetName -eq 'ManualCUPath') {
                $CUFile = Split-Path -Path $CUPath -Leaf
                $FileExt = $CUFile.Split('.')[-1]
                if ($FileExt -eq 'msu') {
                    $CabPath = ExpandMSU -Path $CUPath
                }
                elseif ($FileExt -eq 'cab') {
                    $CabPath = $CUPath
                }
                else {
                    Write-Error -Message "CU File: $CUFile has the wrong file extension. Should be 'cab' or 'msu' but is $FileExt" -ErrorAction Stop
                }
            }
            else {
                if ($IncludeLatestCU) {
                    #for latest CU, check https://support.microsoft.com/en-us/help/4000825/windows-10-and-windows-server-2016-update-history
                    $Uri = 'http://download.windowsupdate.com/c/msdownload/update/software/secu/2017/10/windows10.0-kb4041691-x64_6b578432462f6bec9b4c903b3119d437ef32eb29.msu'
                    $OutFile = "$ModulePath\update.msu"
                }
                else {
                    #test if manual Uri is giving 200
                    $TestCUUri = Invoke-WebRequest -Uri $CUUri -UseBasicParsing -Method Head
                    if ($TestCUUri.StatusCode -ne 200) {
                        Write-Error -Message "The CU Uri specified is not valid. StatusCode: $($TestCUUri.StatusCode)" -ErrorAction Stop
                    }
                    else {
                        $Uri = $CUUri
                        $OutFile = "$ModulePath\" + $CUUri.Split('/')[-1]
                    }
                }
                $CurrentProgressPref = $ProgressPreference
                $ProgressPreference = 'SilentlyContinue'
                Write-Verbose -Message "Starting download of CU. This will take some time." -Verbose
                Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
                $ProgressPreference = $CurrentProgressPref
                Unblock-File -Path $OutFile
                $CabPath = ExpandMSU -Path $OutFile
            }
        }

        $ConvertParams = @{
            VHDSizeInMB = $VhdSizeInMB
            IsoPath     = $ISOPath
        }

        if ($null -ne $CabPath) {
            [void] $ConvertParams.Add('CabPath', $CabPath)
        }

        if ($Net35) {
            [void] $ConvertParams.Add('Net35', $true)
        }

        $PublishArguments = @{
            publisher = 'MicrosoftWindowsServer'
            offer     = 'WindowsServer'
            version   = '1.0.0'
            osType    = 'Windows'
            location  = $location
        }
        
        if ($Version -eq 'Core' -or $Version -eq 'Both') {
            
            $sku = "2016-Datacenter-Server-Core"

            #Pre-validate that the VM Image is not already available
            $VMImageAlreadyAvailable = $false
            if ($(Get-AzsVMImage -publisher $PublishArguments.publisher -offer $PublishArguments.offer -sku $sku -version $PublishArguments.version -location $PublishArguments.location -ErrorAction SilentlyContinue).Properties.ProvisioningState -eq 'Succeeded') {
                $VMImageAlreadyAvailable = $true
                Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}", version "{3}" already is present.' -f $publisher, $offer, $sku, $version) -Verbose -ErrorAction Stop
            }

            $ImagePath = "$ModulePath\Server2016DatacenterCoreEval.vhd" 
            try {
                if ((!(Test-Path -Path $ImagePath)) -and (!$VMImageAlreadyAvailable)) {
                    Write-Verbose -Message "Creating Server Core Image"
                    CreateWindowsVHD @ConvertParams -VHDPath $ImagePath -Edition $CoreEdition -ErrorAction Stop -Verbose
                }
                else {
                    Write-Verbose -Message "Server Core VHD already found."
                }

                if ($CreateGalleryItem) {
                    $description = "This evaluation image should not be used for production workloads."
                    Add-AzsVMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -title "Windows Server 2016 Datacenter Core Eval" -description $description -CreateGalleryItem $CreateGalleryItem
                }
                else {
                    Add-AzsVMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -CreateGalleryItem $CreateGalleryItem
                }
            }
            catch {
                Write-Error -ErrorRecord $_ -ErrorAction Stop
            }
        }

        if ($Version -eq 'Full' -or $Version -eq 'Both') {
        
            $ImagePath = "$ModulePath\Server2016DatacenterFullEval.vhd"
            
            try {
                $sku = "2016-Datacenter"

                #Pre-validate that the VM Image is not already available
                $VMImageAlreadyAvailable = $false
                if ($(Get-AzsVMImage -publisher $PublishArguments.publisher -offer $PublishArguments.offer -sku $sku -version $PublishArguments.version -location $PublishArguments.location -ErrorAction SilentlyContinue).Properties.ProvisioningState -eq 'Succeeded') {
                    $VMImageAlreadyAvailable = $true
                    Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}", version "{3}" already is present.' -f $publisher, $offer, $sku, $version) -Verbose -ErrorAction Stop
                }

                if ((!(Test-Path -Path $ImagePath)) -and (!$VMImageAlreadyAvailable)) {
                    Write-Verbose -Message "Creating Server Full Image" -Verbose
                    CreateWindowsVHD @ConvertParams -VHDPath $ImagePath -Edition $FullEdition -ErrorAction Stop -Verbose
                }
                else {
                    Write-Verbose -Message "Server Full VHD already found."
                }
                if ($CreateGalleryItem) {
                    $description = "This evaluation image should not be used for production workloads."
                    Add-AzsVMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -title "Windows Server 2016 Datacenter Eval" -description $description -CreateGalleryItem $CreateGalleryItem
                }
                else {
                    Add-AzsVMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -CreateGalleryItem $CreateGalleryItem
                }
            }
            catch {
                Write-Error -ErrorRecord $_ -ErrorAction Stop
            }
        }

        if (Test-Path -Path $ImagePath) {
            Remove-Item $ImagePath
        }
    }
}

Export-ModuleMember -Function 'New-AzsServer2016VMImage' 

Function CreateGalleryItem {
    Param(
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Publisher,

        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Offer,

        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [String] $Sku,

        [ValidatePattern("\d+\.\d+\.\d")]
        [String] $Version,

        [ValidateSet('Windows' , 'Linux')]
        [String] $OSType,

        [string] $Title,

        [string] $Description
    )
    $workdir = '{0}{1}' -f [System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString() 
    New-Item $workdir -ItemType Directory | Out-Null

    $compressedGalleryItemPath = Join-Path $PSScriptRoot 'CustomizedVMGalleryItem.azpkg'
    Copy-Item -Path $compressedGalleryItemPath -Destination "$workdir\CustomizedVMGalleryItem.zip"
    $extractedGalleryItemPath = Join-Path $workdir 'galleryItem'
    New-Item -ItemType directory -Path $extractedGalleryItemPath | Out-Null
    expand-archive -Path "$workdir\CustomizedVMGalleryItem.zip" -DestinationPath $extractedGalleryItemPath -Force
        
    $maxAttempts = 5
    for ($retryAttempts = 1; $retryAttempts -le $maxAttempts; $retryAttempts++) {
        try {
            Write-Verbose -Message "Downloading Azure Stack Marketplace Item Generator Attempt $retryAttempts" -Verbose
            Invoke-WebRequest -Uri http://www.aka.ms/azurestackmarketplaceitem -OutFile "$workdir\MarketplaceItem.zip" 
            break
        }
        catch {
            if ($retryAttempts -ge $maxAttempts) {
                Write-Error "Failed to download Azure Stack Marketplace Item Generator" -ErrorAction Stop
            }
        }
    }

    Expand-Archive -Path "$workdir\MarketplaceItem.zip" -DestinationPath $workdir -Force

    #region UIDef
    $createUIDefinitionPath = Join-Path $extractedGalleryItemPath 'DeploymentTemplates\CreateUIDefinition.json'
    $JSON = Get-Content $createUIDefinitionPath | Out-String | ConvertFrom-Json
    $JSON.parameters.osPlatform = $osType
    $JSON.parameters.imageReference.publisher = $publisher
    $JSON.parameters.imageReference.offer = $offer
    $JSON.parameters.imageReference.sku = $sku
    $JSON | ConvertTo-Json -Compress| set-content $createUIDefinitionPath
    #endregion

    #region Manifest
    $manifestPath = Join-Path $extractedGalleryItemPath 'manifest.json'
    $JSON = Get-Content $manifestPath | Out-String | ConvertFrom-Json

    if (!$title) {
        $title = "{0}-{1}-{2}" -f $publisher, $offer, $sku
    }
    $name = "$offer$sku"
    #Remove periods so that the offer and sku can be part of the MarketplaceItem name 
    $name = $name -replace "\.", "-"
    $JSON.name = $name
    $JSON.publisher = $publisher
    $JSON.version = $version
    $JSON.displayName = $title
    $JSON.publisherDisplayName = $publisher
    $JSON.publisherLegalName = $publisher
    $JSON | ConvertTo-Json -Compress| set-content $manifestPath

    #endregion

    #region Strings
    if (!$description) {
        $description = "Create a virtual machine from a VM image. Publisher: {0}, Offer: {1}, Sku:{2}, Version: {3}" -f $publisher, $offer, $sku, $version
    }
    $stringsPath = Join-Path $extractedGalleryItemPath 'strings\resources.resjson'
    $JSON = Get-Content $stringsPath | Out-String | ConvertFrom-Json
    $JSON.longSummary = $description
    $JSON.description = $description
    $JSON.summary = $description
    $JSON | ConvertTo-Json -Compress | set-content $stringsPath
    #endregion
 
    $extractedGalleryPackagerExePath = Join-Path $workdir "Azure Stack Marketplace Item Generator and Sample\AzureGalleryPackageGenerator"
    $galleryItemName = $publisher + "." + $name + "." + $version + ".azpkg"
    $currentPath = $pwd
    Set-Location -Path $extractedGalleryPackagerExePath
    .\AzureGalleryPackager.exe package -m $manifestPath -o $workdir
    Set-Location -Path  $currentPath

    #cleanup
    Remove-Item $extractedGalleryItemPath -Recurse -Force
    Remove-Item "$workdir\Azure Stack Marketplace Item Generator and Sample" -Recurse -Force
    Remove-Item "$workdir\CustomizedVMGalleryItem.zip"
    Remove-Item "$workdir\MarketplaceItem.zip"
    $azpkg = '{0}\{1}' -f $workdir, $galleryItemName
    return Get-Item -LiteralPath $azpkg
}
Function Get-AzsHomeLocation {
    param(
        [Parameter(Mandatory = $false)]
        [string] $Location
    )
    if ($Location) {
        return $Location
    }
    
    $locationResource = Get-AzsLocation
    return $locationResource.Name
}
