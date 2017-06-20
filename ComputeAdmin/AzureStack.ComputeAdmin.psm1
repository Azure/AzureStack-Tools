# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Modules AzureStack.Connect

<#
    .SYNOPSIS
    Add-AzureStackVMSSGalleryItem: Adds the VMSS Gallery Item to your Azure Stack Marketplace.
    Remove-AzureStackVMSSGalleryItem: Adds the VMSS Gallery Item from your Azure Stack Marketplace.
    Add-VMImage: Uploads a VM Image to your Azure Stack and creates a Marketplace item for it.
    Remove-VMImage: Removes an existing VM Image from your Azure Stack.  Does not delete any 
    maketplace items created by Add-VMImage.
    New-Server2016VMImage: Creates and Uploads a new Server 2016 Core and / or Full Image and
    creates a Marketplace item for it.
    Get-VMImage: Gets a VM Image from your Azure Stack as an Administrator to view the provisioning state of the image.
    Add-VMExtension: Uploads a VM extension to your Azure Stack.
    Remove-VMExtension: Removes an existing VM extension from your Azure Stack.
#>

function Add-AzureStackVMSSGalleryItem {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidatePattern("^[0-9a-zA-Z]+$")]
        [ValidateLength(1,128)]
        [String] $Location = 'local'
    )

    $rgName = "vmss.gallery"

    New-AzureRmResourceGroup -Name $rgName -Location $Location -Force

    $saName = "vmssgallery"

    $sa = New-AzureRmStorageAccount -ResourceGroupName $rgName -Location $Location -Name $saName -Type Standard_LRS

    $cName = "gallery"

    Set-AzureRmCurrentStorageAccount -StorageAccountName $saName -ResourceGroupName $rgName

    $container = Get-AzureStorageContainer -Name $cName -ErrorAction SilentlyContinue
    if (-not ($container)) {
        New-AzureStorageContainer -Name $cName -Permission Blob
    }
    
    $fileName = "microsoft.vmss.1.3.6.azpkg"
    $basePath = (Get-Module AzureStack.ComputeAdmin).ModuleBase

    $blob = Set-AzureStorageBlobContent –File ($basePath + "\" + $fileName) –Blob $fileName -Container $cName -Force
    $container = Get-AzureStorageContainer -Name $cName -ErrorAction SilentlyContinue

    $uri = $blob.Context.BlobEndPoint + $container.Name + "/" + $blob.Name    

     Add-AzureRMGalleryItem -GalleryItemUri $uri
}

function Remove-AzureStackVMSSGalleryItem {
    $item = Get-AzureRMGalleryItem -Name "microsoft.vmss.1.3.6"
    if($item) {
        $request = $item | Remove-AzureRMGalleryItem
        $item
    }
}

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

        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMImageFromAzure')]
        [string] $EnvironmentName,

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

    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
    
    if($CreateGalleryItem -eq $false -and $PSBoundParameters.ContainsKey('title')) {
        Write-Error -Message "The title parameter only applies to creating a gallery item." -ErrorAction Stop
    }

    if($CreateGalleryItem -eq $false -and $PSBoundParameters.ContainsKey('description')) {
        Write-Error -Message "The description parameter only applies to creating a gallery item." -ErrorAction Stop
    }
   
    $resourceGroupName = "addvmimageresourcegroup"
    $storageAccountName = "addvmimagestorageaccount"
    $containerName = "addvmimagecontainer"

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)

    #pre validate if image is not already deployed
    $VMImageAlreadyAvailable = $false
    if ($(Get-VMImage -publisher $publisher -offer $offer -sku $sku -version $version -EnvironmentName $EnvironmentName -tenantID $tenantID -azureStackCredentials $azureStackCredentials -location $location -ErrorAction SilentlyContinue).Properties.ProvisioningState -eq 'Succeeded') {
        $VMImageAlreadyAvailable = $true
        Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}", version "{3}" already is present.' -f $publisher,$offer,$sku,$version) -Verbose -ErrorAction Stop
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

    if(($pscmdlet.ParameterSetName -eq "VMImageFromLocal") -and (-not $VMImageAlreadyAvailable)) {
        $storageAccount.PrimaryEndpoints.Blob
        $script:osDiskName = Split-Path $osDiskLocalPath -Leaf
        $script:osDiskBlobURIFromLocal = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName,$osDiskName
        Add-AzureRmVhd -Destination $osDiskBlobURIFromLocal -ResourceGroupName $resourceGroupName -LocalFilePath $osDiskLocalPath -OverWrite

        $script:dataDiskBlobURIsFromLocal = New-Object System.Collections.ArrayList
        if ($PSBoundParameters.ContainsKey('dataDisksLocalPaths')) {
            foreach($dataDiskLocalPath in $dataDisksLocalPaths) {
                $dataDiskName = Split-Path $dataDiskLocalPath -Leaf
                $dataDiskBlobURI = "https://$storageAccountName.blob.$Domain/$containerName/$dataDiskName"
                $dataDiskBlobURIsFromLocal.Add($dataDiskBlobURI) 
                Add-AzureRmVhd  -Destination $dataDiskBlobURI -ResourceGroupName $resourceGroupName -LocalFilePath $dataDiskLocalPath -OverWrite
            }
        }
    }

    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")
    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/platformImage/publishers/' + $publisher
    $uri = $uri + '/offers/' + $offer + '/skus/' + $sku + '/versions/' + $version + '?api-version=2015-12-01-preview'


    #building platform image JSON

    #building osDisk json
    if($pscmdlet.ParameterSetName -eq "VMImageFromLocal") {
        $osDiskJSON = '"OsDisk":{"OsType":"'+ $osType + '","Uri":"'+$osDiskBlobURIFromLocal+'"}'
    }
    else {
        $osDiskJSON = '"OsDisk":{"OsType":"'+ $osType + '","Uri":"'+$osDiskBlobURI+'"}'
    }

    #building details JSON
    $detailsJSON = ''
    if ($PSBoundParameters.ContainsKey('billingPartNumber')) {
        $detailsJSON = '"Details":{"BillingPartNumber":"' + $billingPartNumber+'"}'
    }

    #building dataDisk JSON
    $dataDisksJSON = ''

    if($pscmdlet.ParameterSetName -eq "VMImageFromLocal") {
        if ($dataDiskBlobURIsFromLocal.Count -ne 0) {
            $dataDisksJSON = '"DataDisks":['
            $i = 0
            foreach($dataDiskBlobURI in $dataDiskBlobURIsFromLocal) {
                if($i -ne 0) {
                    $dataDisksJSON = $dataDisksJSON +', '
                }

                $newDataDisk = '{"Lun":' + $i + ', "Uri":"' + $dataDiskBlobURI + '"}'
                $dataDisksJSON = $dataDisksJSON + $newDataDisk;
            
                ++$i
            }

            $dataDisksJSON = $dataDisksJSON +']'
        }
    }
    else {
        if ($dataDiskBlobURIs.Count -ne 0) {
            $dataDisksJSON = '"DataDisks":['
            $i = 0
            foreach($dataDiskBlobURI in $dataDiskBlobURIs) {
                if($i -ne 0) {
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

    if(![string]::IsNullOrEmpty($dataDisksJson)) {
        $propertyBody = $propertyBody + ', ' + $dataDisksJson
    }

    if(![string]::IsNullOrEmpty($detailsJson)) {
        $propertyBody = $propertyBody + ', ' + $detailsJson
    }

    $RequestBody = '{"Properties":{'+$propertyBody+'}}'

    if(-not $VMImageAlreadyAvailable){
        Invoke-RestMethod -Method PUT -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $Headers
    }

    $platformImage = Get-VMImage -publisher $publisher -offer $offer -sku $sku -version $version -EnvironmentName $EnvironmentName -tenantID $tenantID -azureStackCredentials $azureStackCredentials -location $location

    $downloadingStatusCheckCount = 0
    while($platformImage.Properties.ProvisioningState -ne 'Succeeded') {
        if($platformImage.Properties.ProvisioningState -eq 'Failed') {
            Write-Error -Message "VM image download failed." -ErrorAction Stop
        }

        if($platformImage.Properties.ProvisioningState -eq 'Canceled') {
            Write-Error -Message "VM image download was canceled." -ErrorAction Stop
        }

        Write-Host "Downloading";
        Start-Sleep -Seconds 10
        $downloadingStatusCheckCount++
        if($downloadingStatusCheckCount % 30 -eq 0){
            Write-Verbose -Message "Obtaining refreshed token..."
            $subscription, $Headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
        }
        $platformImage = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    }

    #reaquire storage account context
    Set-AzureRmCurrentStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName
    $container = Get-AzureStorageContainer -Name $containerName -ErrorAction SilentlyContinue

    if($CreateGalleryItem -eq $true -And $platformImage.Properties.ProvisioningState -eq 'Succeeded') {
        $GalleryItem = CreateGalleyItem -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -title $title -description $description 
        $blob = $container| Set-AzureStorageBlobContent  –File $GalleryItem.FullName  –Blob $galleryItem.Name
        $galleryItemURI = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName,$galleryItem.Name

        
        Add-AzureRMGalleryItem -GalleryItemUri $galleryItemURI

        #cleanup
        Remove-Item $GalleryItem
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
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [String] $location = 'local',

        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [switch] $KeepMarketplaceItem,

        [Parameter(Mandatory=$true)]
        [string] $EnvironmentName

    )

    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)

    $VMImageExists = $false
    if (Get-VMImage -publisher $publisher -offer $offer -sku $sku -version $version -EnvironmentName $EnvironmentName -tenantID $tenantID -azureStackCredentials $azureStackCredentials -location $location -ErrorAction SilentlyContinue) {
        Write-Verbose "VM Image is present in Azure Stack - continuing to remove" -Verbose
        $VMImageExists = $true
    }
    else{
        Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}" is not present and will not be removed. Marketplace item may still be removed.' -f $publisher,$offer,$sku) -ErrorAction Stop
    }

    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")
    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/platformImage/publishers/' + $publisher
    $uri = $uri + '/offers/' + $offer + '/skus/' + $sku + '/versions/' + $version + '?api-version=2015-12-01-preview'

    if($VMImageExists){
        $maxAttempts = 5
        for ($retryAttempts = 1; $retryAttempts -le $maxAttempts; $retryAttempts++) {
            try {
                Write-Verbose -Message "Deleting VM Image Attempt $retryAttempts" -Verbose
                Invoke-RestMethod -Method DELETE -Uri $uri -ContentType 'application/json' -Headers $headers
                break
            }
            catch {
                if($retryAttempts -ge $maxAttempts){
                    Write-Error -Message ('Deletion of VM Image with publisher "{0}", offer "{1}", sku "{2}" failed with Error:"{3}.' -f $publisher,$offer,$sku,$Error) -ErrorAction Stop
                }
            }
        }
    }

    if(-not $KeepMarketplaceItem){
        Write-Verbose "Removing the marketplace item for the VM Image." -Verbose
        $name = "$offer$sku"
        #Remove periods so that the offer and sku can be retrieved from the Marketplace Item name
        $name =$name -replace "\.","-"
        Get-AzureRMGalleryItem | Where-Object {$_.Name -contains "$publisher.$name.$version"} | Remove-AzureRMGalleryItem 
    }

}

function New-Server2016VMImage {
    [cmdletbinding(DefaultParameterSetName = 'NoCU')]
    param (
        [Parameter()]
        [validateset('Full','Core','Both')]
        [String] $Version = 'Full',

        [Parameter(ParameterSetName = 'LatestCU')]
        [switch] $IncludeLatestCU,

        [Parameter(ParameterSetName = 'ManualCUUri')]
        [string] $CUUri,

        [Parameter(ParameterSetName = 'ManualCUPath')]
        [string] $CUPath,
        
        [Parameter(Mandatory)]
        [string] $EnvironmentName,

        [Parameter()]
        [string] $VHDSizeInMB = 40960,

        [Parameter(Mandatory)]
        [ValidateScript({Test-Path -Path $_})]
        [string] $ISOPath,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.Credential()] $AzureStackCredentials,

        [ValidateNotNullorEmpty()]
        [String] $TenantId,

        [String] $location = 'local',
        
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
                    ApplyPath = "$VHDDriveLetter`:\" 
                    ImagePath = "$IsoDriveLetter`:\Sources\install.wim"
                    Name = $Edition
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
                $null = Invoke-Expression -Command "$VHDDriveLetter`:\Windows\System32\bcdboot.exe $VHDDriveLetter`:\windows /s $VHDDriveLetter`: /f BIOS" -ErrorAction Stop
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Stop
            } finally {
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

        Write-Verbose -Message "Checking ISO path for a valid ISO." -Verbose
        if(!$IsoPath.ToLower().contains('.iso')){
            Write-Error -Message "ISO path is not a valid ISO file." -ErrorAction Stop
        }

        Write-Verbose -Message "Checking authorization against your Azure Stack environment" -Verbose
    
        $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName -ErrorAction Stop)

        Write-Verbose -Message "Authorization verified" -Verbose
        
        if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Error -Message "New-Server2016VMImage must run with Administrator privileges" -ErrorAction Stop
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
                } elseif ($FileExt -eq 'cab') {
                    $CabPath = $CUPath
                } else {
                    Write-Error -Message "CU File: $CUFile has the wrong file extension. Should be 'cab' or 'msu' but is $FileExt" -ErrorAction Stop
                }
            } else {
                if ($IncludeLatestCU) {
                    #for latest CU, check https://support.microsoft.com/en-us/help/4000825/windows-10-and-windows-server-2016-update-history
                    $Uri = 'http://download.windowsupdate.com/d/msdownload/update/software/updt/2017/01/windows10.0-kb4010672-x64_e12a6da8744518197757d978764b6275f9508692.msu'
                    $OutFile = "$ModulePath\windows10.0-kb3213986-x64_a1f5adacc28b56d7728c92e318d6596d9072aec4.msu"
                } else {
                    #test if manual Uri is giving 200
                    $TestCUUri = Invoke-WebRequest -Uri $CUUri -UseBasicParsing -Method Head
                    if ($TestCUUri.StatusCode -ne 200) {
                        Write-Error -Message "The CU Uri specified is not valid. StatusCode: $($TestCUUri.StatusCode)" -ErrorAction Stop
                    } else {
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
            IsoPath = $ISOPath
        }

        if ($null -ne $CabPath) {
            [void] $ConvertParams.Add('CabPath', $CabPath)
        }

        if ($Net35) {
            [void] $ConvertParams.Add('Net35', $true)
        }

        $PublishArguments = @{
            publisher = 'MicrosoftWindowsServer'
            offer = 'WindowsServer'
            version = '1.0.0'
            osType = 'Windows'
            tenantID = $tenantID
            azureStackCredentials = $AzureStackCredentials
            EnvironmentName = $EnvironmentName
            location = $location
        }
        
        if ($Version -eq 'Core' -or $Version -eq 'Both') {
            
            $sku = "2016-Datacenter-Core"

            #Pre-validate that the VM Image is not already available
            $VMImageAlreadyAvailable = $false
            if ($(Get-VMImage -publisher $PublishArguments.publisher -offer $PublishArguments.offer -sku $sku -version $PublishArguments.version -EnvironmentName $EnvironmentName -tenantID $tenantID -azureStackCredentials $azureStackCredentials -location $PublishArguments.location -ErrorAction SilentlyContinue).Properties.ProvisioningState -eq 'Succeeded') {
                $VMImageAlreadyAvailable = $true
                Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}", version "{3}" already is present.' -f $publisher,$offer,$sku,$version) -Verbose -ErrorAction Stop
            }

            $ImagePath = "$ModulePath\Server2016DatacenterCoreEval.vhd" 
            try {
                if ((!(Test-Path -Path $ImagePath)) -and (!$VMImageAlreadyAvailable)) {
                    Write-Verbose -Message "Creating Server Core Image"
                    CreateWindowsVHD @ConvertParams -VHDPath $ImagePath -Edition $CoreEdition -ErrorAction Stop -Verbose
                }else{
                    Write-Verbose -Message "Server Core VHD already found."
                }

                if ($CreateGalleryItem) {
                    $description = "This evaluation image should not be used for production workloads."
                    Add-VMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -title "Windows Server 2016 Datacenter Core Eval" -description $description -CreateGalleryItem $CreateGalleryItem
                }
                else {
                    Add-VMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -CreateGalleryItem $CreateGalleryItem
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Stop
            }
        }
        if ($Version -eq 'Full' -or $Version -eq 'Both') {
            $ImagePath = "$ModulePath\Server2016DatacenterFullEval.vhd"
            
            try {
                $sku = "2016-Datacenter"

                #Pre-validate that the VM Image is not already available
                $VMImageAlreadyAvailable = $false
                if ($(Get-VMImage -publisher $PublishArguments.publisher -offer $PublishArguments.offer -sku $sku -version $PublishArguments.version -EnvironmentName $EnvironmentName -tenantID $tenantID -azureStackCredentials $azureStackCredentials -location $PublishArguments.location -ErrorAction SilentlyContinue).Properties.ProvisioningState -eq 'Succeeded') {
                    $VMImageAlreadyAvailable = $true
                    Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}", version "{3}" already is present.' -f $publisher,$offer,$sku,$version) -Verbose -ErrorAction Stop
                }

                if ((!(Test-Path -Path $ImagePath)) -and (!$VMImageAlreadyAvailable)) {
                    Write-Verbose -Message "Creating Server Full Image" -Verbose
                    CreateWindowsVHD @ConvertParams -VHDPath $ImagePath -Edition $FullEdition -ErrorAction Stop -Verbose
                }else{
                    Write-Verbose -Message "Server Full VHD already found."
                }
                if ($CreateGalleryItem) {
                    $description = "This evaluation image should not be used for production workloads."
                    Add-VMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -title "Windows Server 2016 Datacenter Eval" -description $description -CreateGalleryItem $CreateGalleryItem
                }
                else {
                    Add-VMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -CreateGalleryItem $CreateGalleryItem
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Stop
            }
        }

        if(Test-Path -Path $ImagePath){
            Remove-Item $ImagePath
        }
    }
}

Function CreateGalleyItem{
    Param(
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $publisher,      
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $offer,
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $sku,
        [ValidatePattern(“\d+\.\d+\.\d+”)]
        [String] $version,
        [ValidateSet('Windows' ,'Linux')]
        [String] $osType,
        [string] $title,
        [string] $description
    )
    $workdir = '{0}{1}' -f [System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString()  
    New-Item $workdir -ItemType Directory | Out-Null
    $basePath = (Get-Module AzureStack.ComputeAdmin).ModuleBase
    $compressedGalleryItemPath = Join-Path $basePath 'CustomizedVMGalleryItem.azpkg'
    Copy-Item -Path $compressedGalleryItemPath -Destination "$workdir\CustomizedVMGalleryItem.zip"
    $extractedGalleryItemPath = Join-Path $workdir 'galleryItem'
    New-Item -ItemType directory -Path $extractedGalleryItemPath | Out-Null
    expand-archive -Path "$workdir\CustomizedVMGalleryItem.zip" -DestinationPath $extractedGalleryItemPath -Force
        
    $extractedName = 'MarketplaceItem.zip'
    $maxAttempts = 5
    for ($retryAttempts = 1; $retryAttempts -le $maxAttempts; $retryAttempts++) {
        try {
            Write-Verbose -Message "Downloading Azure Stack Marketplace Item Generator Attempt $retryAttempts" -Verbose
            Invoke-WebRequest -Uri http://www.aka.ms/azurestackmarketplaceitem -OutFile "$workdir\MarketplaceItem.zip" 
            break
        }
        catch {
            if($retryAttempts -ge $maxAttempts){
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
    $name =$name -replace "\.","-"
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
    cd $extractedGalleryPackagerExePath
    .\AzureGalleryPackager.exe package -m $manifestPath -o $workdir
    cd $currentPath

    #cleanup
    Remove-Item $extractedGalleryItemPath -Recurse -Force
    Remove-Item "$workdir\Azure Stack Marketplace Item Generator and Sample" -Recurse -Force
    Remove-Item "$workdir\CustomizedVMGalleryItem.zip"
    Remove-Item "$workdir\MarketplaceItem.zip"
    $azpkg = '{0}\{1}' -f $workdir, $galleryItemName
    return Get-Item -LiteralPath $azpkg
}

Function Get-VMImage{
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
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [String] $location = 'local',

        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true)]
        [string] $EnvironmentName

    )

    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)

    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/platformImage/publishers/' + $publisher
    $uri = $uri + '/offers/' + $offer + '/skus/' + $sku + '/versions/' + $version + '?api-version=2015-12-01-preview'

    try{
        $platformImage = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
        return $platformImage
    }catch{
        return $null
    }
}

Function Add-VMExtension{

    [CmdletBinding(DefaultParameterSetName='VMExtensionFromLocal')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $publisher,

        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [String] $version,

        [Parameter(ParameterSetName='VMExtensionFromLocal')]
        [Parameter(ParameterSetName='VMExtesionFromAzure')]
        [String] $type,

        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [ValidateNotNullorEmpty()]
        [String] $extensionLocalPath,

        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $extensionBlobURI,

        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [ValidateSet('Windows' ,'Linux')]
        [String] $osType,

        [Parameter(ParameterSetName='VMExtensionFromLocal')]
        [Parameter(ParameterSetName='VMExtesionFromAzure')]
        [bool] $vmScaleSetEnabled = $false,

        [Parameter(ParameterSetName='VMExtensionFromLocal')]
        [Parameter(ParameterSetName='VMExtesionFromAzure')]
        [bool] $supportMultipleExtensions = $false,
    
        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [Parameter(ParameterSetName='VMExtensionFromLocal')]
        [Parameter(ParameterSetName='VMExtesionFromAzure')]
        [String] $location = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [string] $EnvironmentName
        
    )

    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $resourceGroupName = "addvmextresourcegroup"
    $storageAccountName = "addvmextstorageaccount"
    $containerName = "addvmextensioncontainer"

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)

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

    if($pscmdlet.ParameterSetName -eq "VMExtensionFromLocal")
    {
        $storageAccount.PrimaryEndpoints.Blob
        $script:extensionName = Split-Path $extensionLocalPath -Leaf
        $script:extensionBlobURIFromLocal = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName,$extensionName
        Set-AzureStorageBlobContent -File $extensionLocalPath -Container $containerName -Blob $extensionName
    }

    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")
    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/VMExtension/publishers/' + $publisher
    $uri = $uri + '/types/' + $type + '/versions/' + $version + '?api-version=2015-12-01-preview'

    Write-Verbose $uri

    #building request body JSON
    if($pscmdlet.ParameterSetName -eq "VMExtensionFromLocal") {
        $sourceBlobJSON = '"SourceBlob" : {"Uri" :"' + $extensionBlobURIFromLocal + '"}'
    }
    else {
        $sourceBlobJSON = '"SourceBlob" : {"Uri" :"' + $extensionBlobURI + '"}'
    }
    
    $osTypeJSON = '"VmOsType" : "' + $osType + '"'
    $ComputeRoleJSON = '"ComputeRole" : "N/A"'
    $VMScaleSetEnabledJSON = '"VMScaleSetEnabled" : "' + $vmScaleSetEnabled + '"'
    $SupportMultipleExtensionsJSON = '"SupportMultipleExtensions" : "' + $supportMultipleExtensions + '"'
    $IsSystemExtensionJSON = '"IsSystemExtension" : "false"'

    $propertyBody = $sourceBlobJSON + "," + $osTypeJSON + ',' + $ComputeRoleJSON + "," + $VMScaleSetEnabledJSON + "," + $SupportMultipleExtensionsJSON + "," + $IsSystemExtensionJSON 

    #building ARMResource

    $RequestBody = '{"Properties":{'+$propertyBody+'}}'

    Invoke-RestMethod -Method PUT -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $Headers

    $extensionHandler = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers

    while($extensionHandler.Properties.ProvisioningState -ne 'Succeeded')
    {
        if($extensionHandler.Properties.ProvisioningState -eq 'Failed')
        {
            Write-Error -Message ('VM extension download failed with Error:"{0}.' -f $publisher, $_.Exception.Message ) -ErrorAction Stop
        }

        if($extensionHandler.Properties.ProvisioningState -eq 'Canceled')
        {
            Write-Error -Message "VM extension download was canceled." -ErrorAction Stop
        }

        Write-Host "Downloading";
        Start-Sleep -Seconds 4
        $extensionHandler = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    }

    Remove-AzureStorageContainer –Name $containerName -Force
    Remove-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName 
    Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
}

Function Remove-VMExtension{
    Param(
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $publisher,

        [Parameter(Mandatory=$true)]
        [String] $version,

        [String] $type,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Windows' ,'Linux')]
        [String] $osType,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [String] $location = 'local',

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true)]
        [string] $EnvironmentName
        
    )

    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)

    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")
    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/VMExtension/publishers/' + $publisher
    $uri = $uri + '/types/' + $type + '/versions/' + $version + '?api-version=2015-12-01-preview'

    Write-Verbose $uri

    try{
        Invoke-RestMethod -Method DELETE -Uri $uri -ContentType 'application/json' -Headers $headers
    }
    catch{
        Write-Error -Message ('Deletion of VM extension with publisher "{0}" failed with Error:"{1}.' -f $publisher, $_.Exception.Message ) -ErrorAction Stop
    }
}

Function GetARMEndpoint{
    param(
        # Azure Stack environment name
        [Parameter(Mandatory=$true)]
        [string] $EnvironmentName
        
    )

    $armEnv = Get-AzureRmEnvironment -Name $EnvironmentName
    if($armEnv -ne $null) {
        $ARMEndpoint = $armEnv.ResourceManagerUrl
    }
    else {
        Write-Error "The Azure Stack environment with the name $EnvironmentName does not exist. Create one with Add-AzureStackAzureRmEnvironment." -ErrorAction Stop
    }

    $ARMEndpoint
}
# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUryyiECqdz2ANTpv98zAA/FlZ
# h/SgghhlMIIEwzCCA6ugAwIBAgITMwAAAMlkTRbbGn2zFQAAAAAAyTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODU0
# WhcNMTgwOTA3MTc1ODU0WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkIxQjctRjY3Ri1GRUMyMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAotVXnfm6iRvJ
# s2GZXZXB2Jr9GoHX3HNAOp8xF/cnCE3fyHLwo1VF+TBQvObTTbxxdsUiqJ2Ew8DL
# jW8dolC9WqrPuP9Wj0gJNAdhnAYjtZN5fYEoGIsHBtuR3k+UxD2W7VWfjPDTY2zH
# e44WzfDvL2aXL2fomH73B7cx7YjT/7Du7vSdAHbr7SEdIyGJ5seMa+Y9MBJI48wZ
# A9CSnTGTFvhMXCYJuoR6Xc34A0EdHiTzfxY2tEWSiw5Xr+Oottc4IIHksNttYMgw
# HCu+tKqUlDkq5EdELh067r2Mv+OVkUkDQnLd1Vh/bP+yz92NKw7THQDYN7/4MTD2
# faNVsutryQIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFB7ZK3kpWqMOy6M4tybE49oI
# BMpsMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBACvoEvJ84B3DuFj+SDfpkM3OCxYon2F4wWTOQmpDmTwysrQ0
# grXhxNqMVL7QRKk34of1uvckfIhsjnckTjkaFJk/bQc8n5wwTzCKJ3T0rV/Vasoh
# MbGm4y3UYEh9nflmKbPpNhps20EeU9sdNIkxsrpQsPwk59wv13STtUjywuTvpM5s
# 1dQOIiUWrAMR14ZzOSBA7kgWI+UEj5iaGYOczxD+wH+07llzwlIC4TyRXtgKFuMF
# AONNNYUedbi6oOX7IPo0hb5RVPuVqAFxT98xIheJXNod9lf2JLhGD+H/pXnkZJRr
# VjJFcuJeEAnYAe7b97+BfhbPgv8V9FIAwqTxgxIwggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TCCBhEwggP5
# oAMCAQICEzMAAACOh5GkVxpfyj4AAAAAAI4wDQYJKoZIhvcNAQELBQAwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xNjExMTcyMjA5MjFaFw0xODAy
# MTcyMjA5MjFaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQh9RCK36d2cZ61KLD4xWS
# 0lOdlRfJUjb6VL+rEK/pyefMJlPDwnO/bdYA5QDc6WpnNDD2Fhe0AaWVfIu5pCzm
# izt59iMMeY/zUt9AARzCxgOd61nPc+nYcTmb8M4lWS3SyVsK737WMg5ddBIE7J4E
# U6ZrAmf4TVmLd+ArIeDvwKRFEs8DewPGOcPUItxVXHdC/5yy5VVnaLotdmp/ZlNH
# 1UcKzDjejXuXGX2C0Cb4pY7lofBeZBDk+esnxvLgCNAN8mfA2PIv+4naFfmuDz4A
# lwfRCz5w1HercnhBmAe4F8yisV/svfNQZ6PXlPDSi1WPU6aVk+ayZs/JN2jkY8fP
# AgMBAAGjggGAMIIBfDAfBgNVHSUEGDAWBgorBgEEAYI3TAgBBggrBgEFBQcDAzAd
# BgNVHQ4EFgQUq8jW7bIV0qqO8cztbDj3RUrQirswUgYDVR0RBEswSaRHMEUxDTAL
# BgNVBAsTBE1PUFIxNDAyBgNVBAUTKzIzMDAxMitiMDUwYzZlNy03NjQxLTQ0MWYt
# YmM0YS00MzQ4MWU0MTVkMDgwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1
# ApUwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEF
# BQcBAQRVMFMwUQYIKwYBBQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNV
# HRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBEiQKsaVPzxLa71IxgU+fKbKhJ
# aWa+pZpBmTrYndJXAlFq+r+bltumJn0JVujc7SV1eqVHUqgeSxZT8+4PmsMElSnB
# goSkVjH8oIqRlbW/Ws6pAR9kRqHmyvHXdHu/kghRXnwzAl5RO5vl2C5fAkwJnBpD
# 2nHt5Nnnotp0LBet5Qy1GPVUCdS+HHPNIHuk+sjb2Ns6rvqQxaO9lWWuRi1XKVjW
# kvBs2mPxjzOifjh2Xt3zNe2smjtigdBOGXxIfLALjzjMLbzVOWWplcED4pLJuavS
# Vwqq3FILLlYno+KYl1eOvKlZbiSSjoLiCXOC2TWDzJ9/0QSOiLjimoNYsNSa5jH6
# lEeOfabiTnnz2NNqMxZQcPFCu5gJ6f/MlVVbCL+SUqgIxPHo8f9A1/maNp39upCF
# 0lU+UK1GH+8lDLieOkgEY+94mKJdAw0C2Nwgq+ZWtd7vFmbD11WCHk+CeMmeVBoQ
# YLcXq0ATka6wGcGaM53uMnLNZcxPRpgtD1FgHnz7/tvoB3kH96EzOP4JmtuPe7Y6
# vYWGuMy8fQEwt3sdqV0bvcxNF/duRzPVQN9qyi5RuLW5z8ME0zvl4+kQjOunut6k
# LjNqKS8USuoewSI4NQWF78IEAA1rwdiWFEgVr35SsLhgxFK1SoK3hSoASSomgyda
# Qd691WZJvAuceHAJvDCCB3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEx
# MB4XDTExMDcwODIwNTkwOVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUg
# U2lnbmluZyBQQ0EgMjAxMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AKvw+nIQHC6t2G6qghBNNLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL
# 8DjCmQawyDnVARQxQtOJDXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/X
# llnKYBoF6WZ26DJSJhIv56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5k
# NXimoGMPLdNAk/jj3gcN1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJ
# Xtjt7UORg9l7snuGG9k+sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4
# ftKdgCz1TlaRITUlwzluZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgo
# tswnKDglmDlKNs98sZKuHCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0Xpb
# L9Uj43BdD1FGd7P4AOG8rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy
# 5yTfv0aZxe/CHFfbg43sTUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9
# Z4DmimJ4X7IvhNdXnFy/dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4
# IFgsE11glZo+TzOE2rCIF96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQ
# BgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUw
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0f
# BFMwUTBPoE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcB
# AQRSMFAwTgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kv
# Y2VydHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGX
# MIGUMIGRBgkrBgEEAYI3LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcC
# AjA0HjIgHQBMAGUAZwBhAGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUA
# bgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFj
# kplCln3SeQyQwWVfLiw++MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtG
# UFXYDJJ80hpLHPM8QotS0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32m
# kHSDjfTLJgJGKsKKELukqQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr
# 3vw70L01724lruWvJ+3Q3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYK
# wsatruWy2dsViFFFWDgycScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6C
# PxNNZgvAs0314Y9/HG8VfUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX
# 0O5dY0HjWwechz4GdwbRBrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADW
# oUa9WfOXpQlLSBCZgB/QACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9r
# t0uX4ut1eBrs6jeZeRhL/9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGd
# Vk5Pv4BXIqF4ETIheu9BCrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9
# bW1qyVJzEw16UM0xggTlMIIE4QIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5n
# IFBDQSAyMDExAhMzAAAAjoeRpFcaX8o+AAAAAACOMAkGBSsOAwIaBQCggfkwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFDg0BG47hwEbJWpO0k5rRJELW6SCMIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEAZ8teOpIZbrhmEIMc1AFk+YJcYJZvoqx7
# M1Un9yY9UynFlxBujSClmKjRb5qsd0uLbjcCOlq7s67kEC42HmugfgSoULuEF4br
# xRtGPDdcbsmI7edj55WCVB/Po6MP0fU7kR7g9/0zX+98gn+zdMa33+V94yv5K2p0
# L2ev0Ov9oAwDLmHHXD9TYJa2sglVIrHfr45TZI0jXBxNuaSnvcWk4nuGUmpmrRo7
# YIc/X07Q8mvAeTYqkqJRQwJ208EAAeecqD7DKc/kIxqAEypYsxZ1mhp5rjq8/t9Y
# phh5HlucqSdwnCbn0toQ/Gh3niIwgXE/kMoZV8dSrPfXB9KWH/dbqKGCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADJZE0W2xp9sxUAAAAAAMkwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxOVowIwYJ
# KoZIhvcNAQkEMRYEFNlEGxPS8P+IOqBpiGrP6BENJsv+MA0GCSqGSIb3DQEBBQUA
# BIIBABE+haCo6hsqaEn/aVFSRDibdVg7e4TVqTTOxIrxebq1Rd8Wwycd7kqrPz0x
# JcRIK5I2J3WEKoTI3kS794j7Fqp5Ro1TXGOVa8j+fdR19Wt1H5ikgRtJi3RkvI6V
# z8vgXrcimUhNWeFCuERjh7rUQ9AB/rR64Z6tekrr9qUOwa9ljmtnpWcmuwlvYf6c
# dCQdBWcCRrg3PNke85tQUibNJgDUoSuFuILE36VOgPygR0i8api7RdEvwR0bLz+i
# Jiggc4RmgLdMmEbcfn1LNwCz2ZuCeqM4+icTf9T70pCGRWEP36LRsaB5IOod5/yx
# 4FFAfSndJx7DYikbKsm/QrHGLkI=
# SIG # End signature block
