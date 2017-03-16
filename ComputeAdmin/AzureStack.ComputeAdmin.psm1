# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Modules AzureStack.Connect

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
        [string] $ArmEndpoint = 'https://api.local.azurestack.external',

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

    if(!$ARMEndpoint.Contains('https://')){
        if($ARMEndpoint.Contains('http://')){
            $ARMEndpoint = $ARMEndpoint.Substring(7)
            $ARMEndpoint = 'https://' + $ARMEndpoint

        }else{
            $ARMEndpoint = 'https://' + $ARMEndpoint
        }
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
    $VMImageAlreadyAvailable = $false
    if (Get-AzureRmVMImage -Location $location -PublisherName $publisher -Offer $offer -Skus $sku -Version $version -ErrorAction SilentlyContinue) {
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

    if(($pscmdlet.ParameterSetName -eq "VMImageFromLocal") -and (-not $VMImageAlreadyAvailable))
    {
        $storageAccount.PrimaryEndpoints.Blob
        $script:osDiskName = Split-Path $osDiskLocalPath -Leaf
        $script:osDiskBlobURIFromLocal = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName,$osDiskName
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

    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")
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

    if(-not $VMImageAlreadyAvailable){
        Invoke-RestMethod -Method PUT -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $Headers
    }

    $platformImage = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers

    $downloadingStatusCheckCount = 0
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
        Start-Sleep -Seconds 10
        $downloadingStatusCheckCount++
        if($downloadingStatusCheckCount % 30 -eq 0){
            Write-Verbose -Message "Obtaining refreshed token..."
            $subscription, $Headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint)
        }
        $platformImage = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    }

    if($CreateGalleryItem -eq $true -And $platformImage.Properties.ProvisioningState -eq 'Succeeded')
    {
        #reaquire storage account context
        Set-AzureRmCurrentStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName
        $container = Get-AzureStorageContainer -Name $containerName -ErrorAction SilentlyContinue

        $GalleryItem = CreateGalleyItem -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -title $title -description $description 
        $blob = $container| Set-AzureStorageBlobContent  –File $GalleryItem.FullName  –Blob $galleryItem.Name
        $galleryItemURI = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName,$galleryItem.Name

        Add-AzureRMGalleryItem -SubscriptionId $subscription -GalleryItemUri $galleryItemURI -ApiVersion 2015-04-01

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

        [string] $ArmEndpoint = 'https://api.local.azurestack.external'

    )

    if(!$ARMEndpoint.Contains('https://')){
        if($ARMEndpoint.Contains('http://')){
            $ARMEndpoint = $ARMEndpoint.Substring(7)
            $ARMEndpoint = 'https://' + $ARMEndpoint
        }else{
            $ARMEndpoint = 'https://' + $ARMEndpoint
        }
    }

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint)

    $VMImageExists = $false
    if (Get-AzureRmVMImage -Location $location -PublisherName $publisher -Offer $offer -Skus $sku -Version $version -ErrorAction SilentlyContinue -ov images) {
        Write-Verbose "VM Image has been added to Azure Stack - continuing" -Verbose
        $VMImageExists = $true
    }
    else{
        Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}" is not present and will not be removed. Marketplace item may still be removed.' -f $publisher,$offer,$sku) -ErrorAction Stop
    }

    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")
    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/platformImage/publishers/' + $publisher
    $uri = $uri + '/offers/' + $offer + '/skus/' + $sku + '/versions/' + $version + '?api-version=2015-12-01-preview'

    try{
        if($VMImageExists){
            Invoke-RestMethod -Method DELETE -Uri $uri -ContentType 'application/json' -Headers $headers
        }
    }
    catch{
        Write-Error -Message ('Deletion of VM Image with publisher "{0}", offer "{1}", sku "{2}" failed with Error:"{3}.' -f $publisher,$offer,$sku,$Error) -ErrorAction Stop
    }

    if(-not $KeepMarketplaceItem){
        Write-Verbose "Removing the marketplace item for the VM Image." -Verbose
        $name = "$offer$sku"
        #Remove periods so that the offer and sku can be retrieved from the Marketplace Item name
        $name =$name -replace "\.","-"
        Get-AzureRMGalleryItem -ApiVersion 2015-04-01 | Where-Object {$_.Name -contains "$publisher.$name.$version"} | Remove-AzureRMGalleryItem -ApiVersion 2015-04-01
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
        
        [Parameter()]
        [string] $ArmEndpoint = 'https://api.local.azurestack.external',

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

        [switch] $Net35
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

                Mount-DiskImage -ImagePath $VHDPath -Passthru
                $disknum = (Get-DiskImage -ImagePath $VHDPath).Number
                $VHDDriveLetter = (get-disk -number  $disknum| `
                Initialize-Disk -PartitionStyle MBR -PassThru | `
                New-Partition -UseMaximumSize -AssignDriveLetter:$False -IsActive:$true | `
                Format-Volume -Confirm:$false -FileSystem NTFS -force | `
                get-partition | `
                Add-PartitionAccessPath -AssignDriveLetter -PassThru | `
                get-volume).DriveLetter

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
                $retryAttempts = 0;
                while ((Test-Path -Path "$VHDDriveLetter`:\") -and ($retryAttempts -lt 5)) {
                    Write-Verbose -Message "Attempting to dismount the VHD..."
                    Get-DiskImage -ImagePath $VHDPath | Dismount-DiskImage
                    $retryAttempts = $retryAttempts+1;
                    sleep 1
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
    
        $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint -ErrorAction Stop)

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
            ArmEndpoint = $ArmEndpoint
            location = $location
        }
        
        if ($Version -eq 'Core' -or $Version -eq 'Both') {
            
            $sku = "2016-Datacenter-Core"

            #Pre-validate that the VM Image is not already available
            $VMImageAlreadyAvailable = $false
            if (Get-AzureRmVMImage -Location $PublishArguments.location -PublisherName $PublishArguments.publisher -Offer $PublishArguments.offer -Skus $sku -Version $PublishArguments.version -ErrorAction SilentlyContinue) {
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

                if ($CreateGalleryItem)
                {
                    $description = "This evaluation image should not be used for production workloads."
                    Add-VMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -title "Windows Server 2016 Datacenter Core Eval" -description $description -CreateGalleryItem $CreateGalleryItem
                }
                else
                {
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
                if (Get-AzureRmVMImage -Location $PublishArguments.location -PublisherName $PublishArguments.publisher -Offer $PublishArguments.offer -Skus $sku -Version $PublishArguments.version -ErrorAction SilentlyContinue) {
                    $VMImageAlreadyAvailable = $true
                    Write-Verbose -Message ('VM Image with publisher "{0}", offer "{1}", sku "{2}", version "{3}" already is present.' -f $publisher,$offer,$sku,$version) -Verbose -ErrorAction Stop
                }

                if ((!(Test-Path -Path $ImagePath)) -and (!$VMImageAlreadyAvailable)) {
                    Write-Verbose -Message "Creating Server Full Image" -Verbose
                    CreateWindowsVHD @ConvertParams -VHDPath $ImagePath -Edition $FullEdition -ErrorAction Stop -Verbose
                }else{
                    Write-Verbose -Message "Server Full VHD already found."
                }
                if ($CreateGalleryItem)
                {
                    $description = "This evaluation image should not be used for production workloads."
                    Add-VMImage -sku $sku -osDiskLocalPath $ImagePath @PublishArguments -title "Windows Server 2016 Datacenter Eval" -description $description -CreateGalleryItem $CreateGalleryItem
                }
                else
                {
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
        $workdir = '{0}\{1}' -f $env:TEMP, [System.Guid]::NewGuid().ToString()
        New-Item $workdir -ItemType Directory | Out-Null
        $basePath = (Get-Module AzureStack.ComputeAdmin).ModuleBase
        $compressedGalleryItemPath = Join-Path $basePath 'CustomizedVMGalleryItem.azpkg'
        Copy-Item -Path $compressedGalleryItemPath -Destination "$workdir\CustomizedVMGalleryItem.zip"
        $extractedGalleryItemPath = Join-Path $workdir 'galleryItem'
        New-Item -ItemType directory -Path $extractedGalleryItemPath | Out-Null
        expand-archive -Path "$workdir\CustomizedVMGalleryItem.zip" -DestinationPath $extractedGalleryItemPath -Force
        
        $extractedName = 'MarketplaceItem.zip'
        Invoke-WebRequest -Uri http://www.aka.ms/azurestackmarketplaceitem -OutFile "$workdir\MarketplaceItem.zip" 
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

        if (!$title)
        {
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
        if (!$description)
        {
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

