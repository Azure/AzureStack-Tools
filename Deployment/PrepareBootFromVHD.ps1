# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information. 

<# 
 
.SYNOPSIS 
 
Prepare the host to boot from the Azure Stack virtual harddisk. 
 
.DESCRIPTION 
 
PrepareBootFromVHD updates the boot configuration with an Azure Stack entry. 
It will verify if the disk that hosts the CloudBuilder.vhdx contains the required free disk space, Optionally copy drivers and an unattend.xml that does not require KVM access.

 
.PARAMETER CloudBuilderDiskPath  
 
Path to the CloudBuilder.vhdx. This parameter is mandatory.

.PARAMETER DriverPath  
 
This optional parameter allows you to add additional drivers for the host in the virtual harddisk. Specify the path that contains the drivers and all its content wil be copied the to CloudBuilder.vhdx.
 
.PARAMETER ApplyUnattend 
 
ApplyUnattend is a switch parameter. If this parameter is specified, the configuration of the Operating System is automated. 
After the host reboots to the CloudBuilder.vhdx, the Operating System is automatically configured and you can connect to the host with RDP without KVM requirement.
If this parameter is specified, you will be prompted for an local administrator password that is used for the unattend.xml.
If this parameter is not specified, a minimal unattend.xml is used to enable Remote Desktop. KVM is required to configure the Operating System when booting from vs.vhdx for the first time.

.PARAMETER AdminPassword  
 
The AdminPassword parameter is only used when the ApplyUnnatend parameter is set. The Password requires minimal 6 characters.
 
.EXAMPLE 
 
Prepare the host to boot from CloudBuilder.vhdx. This requires KVM access to the host for configuring the Operating System.
.\PrepareBootFromVHD.ps1 -CloudBuilderPath c:\CloudBuilder.vhdx -DriverPath c:\VhdDrivers
 
.EXAMPLE  
 
Prepare the host to boot from CloudBuilder.vhdx. The Operating System is automatically configured with an unattend.xml.
.\PrepareBootFromVHD.ps1 -CloudBuilderPath c:\CloudBuilder.vhdx -ApplyUnattend
  
.NOTES 
 
You will need at least (120GB - Size of the CloudBuilder.vhdx file) of free disk space on the disk that contains the CloudBuilder.vhdx.
 
#>

[CmdletBinding()]
Param     (
    [Parameter(Mandatory=$true)]
    [String]$CloudBuilderDiskPath,

    [Parameter(Mandatory=$false)]
    [string[]]$DriverPath = $null,

    [Parameter(Mandatory = $false)]
    [switch]$ApplyUnattend,

    [Parameter(Mandatory = $false)]
    [String]$AdminPassword,

    [Parameter(Mandatory = $false)]
    [String]$VHDLanguage = "en-US"
    )

$error.Clear()

#region Allow for manual override of PS (replace $PSScriptRoot with a path)
$currentPath = $PSScriptRoot
# $currentPath = 'C:\ForRTMBuilds'
# $CloudBuilderDiskPath = 'C:\CloudBuilder.vhdx'
#endregion

#region Check parameters and prerequisites

if (-not (Test-Path -Path $CloudBuilderDiskPath)) {
    Write-Host "Can't find CloudBuilder.vhdx." -ForegroundColor Red
    Exit
}

if ((Get-DiskImage -ImagePath $CloudBuilderDiskPath).Attached) {
    Write-Host "CloudBuilder.vhdx is already mounted." -ForegroundColor Red
    Exit
}

# Validate the CloudBuilder.vhdx is in a physical disk   
$cbhDriveLetter = (Get-Item $CloudBuilderDiskPath).PSDrive.Name

if (-not $cbhDriveLetter) {
    Write-Host "The given CloudBuilder.vhdx path is not a local path." -ForegroundColor Red
    Exit
}
else {
    $hostDisk = Get-Partition -DriveLetter $cbhDriveLetter | Get-Disk
    if ($hostDisk.Model -match 'Virtual Disk') {
        Write-Host "The CloudBuilder.vhdx is in a virtual hard disk, please place it in a physical disk." -ForegroundColor Red
        Exit
    }
}

if ($ApplyUnattend) {
    # Check if unattend_NoKVM.xml is downloaded
    $unattendRawFile = Join-Path $currentPath 'unattend_NoKVM.xml'
    if (-not (Test-Path $unattendRawFile)) {
        Write-Host "-ApplyUnattend is specified, but unattend_NoKVM.xml is not downloaded to the same directory of this script." -ForegroundColor Red
        Exit
    }

    # Check Admin password for unattend
    if(-not $AdminPassword) {
        while ($SecureAdminPassword.Length -le 6) {
            [System.Security.SecureString]$SecureAdminPassword = read-host 'Password for the local administrator account of the Azure Stack host. Requires 6 characters minimum' -AsSecureString
        }
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureAdminPassword)
        $AdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        Write-Host "The following password will be configured for the local administrator account of the Azure Stack host:"
        Write-Host $AdminPassword -ForegroundColor Cyan
    }
}

# Validate disk space for expanding cloudbuilder.vhdx
$cbhDiskSize = [math]::truncate((get-volume -DriveLetter $cbhDriveLetter).Size / 1GB)
$cbhDiskRemaining = [math]::truncate((get-volume -DriveLetter $cbhDriveLetter).SizeRemaining / 1GB)
$cbDiskSize = [math]::truncate((Get-Item $CloudBuilderDiskPath).Length / 1GB)
$cbDiskSizeReq = 120
if (($cbDiskSizeReq - $cbDiskSize) -ge $cbhDiskRemaining) {
    Write-Host 'Error: Insufficient disk space' -BackgroundColor Red
    Write-Host 'Cloudbuilder.vhdx is placed on' ((Get-Item $CloudBuilderDiskPath).PSDrive.Root) -ForegroundColor Yellow
    Write-Host 'When you boot from CloudBuilder.vhdx the virtual hard disk will be expanded to its full size of' $cbDiskSizeReq 'GB.' -ForegroundColor Yellow
    Write-Host ((Get-Item $CloudBuilderDiskPath).PSDrive.Root) 'does not contain enough free space.' -ForegroundColor Yellow
    Write-Host 'You need' ($cbDiskSizeReq - $cbDiskSize) 'GB of free disk space for a succesfull boot from CloudBuilder.vhdx, but' ((Get-Item $CloudBuilderDiskPath).PSDrive.Root) 'only has' $cbhDiskRemaining 'GB remaining.' -ForegroundColor Yellow
    Write-Host 'Ensure Cloudbuilder.vhdx is placed on a local disk that contains enough free space and rerun this script.' -ForegroundColor Yellow
    Write-Host 'Exiting..' -ForegroundColor Yellow
    Exit
}
#endregion

#region Prepare Azure Stack virtual harddisk

Write-Host "Preparing Azure Stack virtual harddisk"
$cbdisk = Mount-DiskImage -ImagePath $CloudBuilderDiskPath -PassThru | Get-DiskImage | Get-Disk    
$partitions = $cbdisk | Get-Partition | Sort-Object -Descending -Property Size
$CBDriveLetter = $partitions[0].DriveLetter

# ApplyUnattend
if($ApplyUnattend) {
    Write-Host "Apply unattend.xml with given password and language" -ForegroundColor Cyan
    $UnattendedFile = Get-Content ($currentPath + '\unattend_NoKVM.xml')
    $UnattendedFile = ($UnattendedFile).Replace('%productkey%', '74YFP-3QFB3-KQT8W-PMXWJ-7M648')
    $UnattendedFile = ($UnattendedFile).Replace('%locale%', $VHDLanguage)
    $UnattendedFile = ($UnattendedFile).Replace('%adminpassword%', $AdminPassword)
    $UnattendedFile | Out-File ($CBDriveLetter+":\unattend.xml") -Encoding ascii
}
else {
# Apply defautl unattend.xml if it exists
    $defaultUnattend = Join-Path $currentPath 'Unattend.xml'
    if (Test-Path $defaultUnattend) {
        Write-Host "Apply default unattend.xml to disable IE-ESC and enable remote desktop" -ForegroundColor Cyan
        Copy-Item $defaultUnattend -Destination ($CBDriveLetter + ':\') -Force
    }
}

# Add drivers
if (-not $DriverPath) {
    Write-Host "Apply given drivers" -ForegroundColor Cyan
    foreach ($subdirectory in $DriverPath) {
        Add-WindowsDriver -Driver $subdirectory -Path "$($CBDriveLetter):\" -Recurse
    }
}
#endregion

#region Configure boot options

# Remove boot from previous deployment
$bootOptions = bcdedit /enum  | Select-String 'path' -Context 2,1
$bootOptions | ForEach {
    if ((($_.Context.PreContext[1] -replace '^device +') -like '*CloudBuilder.vhdx*') `
        -and ((($_.Context.PostContext[0] -replace '^description +') -eq 'AzureStack TP2') `
              -or (($_.Context.PostContext[0] -replace '^description +') -eq 'Azure Stack'))) {
        Write-Host 'The boot configuration contains an existing CloudBuilder.vhdx entry' -ForegroundColor Cyan
        Write-Host 'Description:' ($_.Context.PostContext[0] -replace '^description +') -ForegroundColor Cyan
        Write-Host 'Device:' ($_.Context.PreContext[1] -replace '^device +') -ForegroundColor Cyan
        Write-Host 'Removing the old entry'
        $BootID = '"' + ($_.Context.PreContext[0] -replace '^identifier +') + '"'
        Write-Host 'bcdedit /delete' $BootID -ForegroundColor Yellow
        bcdedit /delete $BootID
    }
}

# Add boot entry for CloudBuilder.vhdx
Write-Host 'Creating new boot entry for CloudBuilder.vhdx' -ForegroundColor Cyan
Write-Host 'Running command: bcdboot' $CBDriveLetter':\Windows' -ForegroundColor Yellow
bcdboot $CBDriveLetter':\Windows'

$bootOptions = bcdedit /enum  | Select-String 'path' -Context 2,1
$bootOptions | ForEach {
    if ((($_.Context.PreContext[1] -replace '^device +') -eq ('partition='+$CBDriveLetter+':') `
         -or (($_.Context.PreContext[1] -replace '^device +') -like '*CloudBuilder.vhdx*')) `
        -and (($_.Context.PostContext[0] -replace '^description +') -ne 'Azure Stack')) {
        Write-Host 'Updating description for the boot entry' -ForegroundColor Cyan
        Write-Host 'Description:' ($_.Context.PostContext[0] -replace '^description +') -ForegroundColor Cyan
        Write-Host 'Device:' ($_.Context.PreContext[1] -replace '^device +') -ForegroundColor Cyan
        $BootID = '"' + ($_.Context.PreContext[0] -replace '^identifier +') + '"'
        Write-Host 'bcdedit /set' $BootID 'description "Azure Stack"' -ForegroundColor Yellow
        bcdedit /set $BootID description "Azure Stack"
    }
}
#endregion

if(-not $error) {
    Write-Host "Restart computer to boot from Azure Stack virtual harddisk" -ForegroundColor Cyan
    ### Restart Computer ###
    Restart-Computer -Confirm
}
else {
    Write-Host "Fail to prepare CloudBuilder.vhdx. Errors: $($error)" -ForegroundColor Red
}