# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#Prepare volume path
$ScaleUnit = (Get-AzsScaleUnit)[0]
$StorageSubSystem = (Get-AzsStorageSubSystem -ScaleUnit $ScaleUnit.Name)[0]
$SubSystemName = $StorageSubSystem.Name
$LocationPath = $SubSystemName.Split("/")[2]
$LocationPath = $LocationPath.Substring($LocationPath.IndexOf(".")+1)
$LocationPath = "\\SU1FileServer."+$LocationPath+"\SU1_"


<#
    .SYNOPSIS
    Query the volume with least available capacity
#>

function GetMigrationSource {

    $Volumes = (Get-AzsVolume -ScaleUnit $ScaleUnit.Name -StorageSubSystem $StorageSubSystem.Name | Where-Object {$_.VolumeLabel -Like "ObjStore_*"})
    $Volume  = ($Volumes | Sort-Object RemainingCapacityGB)[0]
    return $Volume.VolumeLabel
}

<#
    .SYNOPSIS
    Prepare the volume need to be managed for further analytic
#>

function PrepareMigrationSource {
    param (
        [parameter(Mandatory = $false, HelpMessage = "Volume which need to be free space, If this parameter isn't specified, the volume with least available capacity would be selected by default")]
        [string] $VolumeLabel
    )

    if ($VolumeLabel) {
        if ($VolumeLabel -cnotmatch '^ObjStore_([1-9]|1[0-6])$') {
            throw "ERROR: Source Volume should follow the expression pattern 'ObjStore_X', x is a number ranged from 1 to 16"
            return
        }
        else {
            $MigrationSource = $LocationPath+$VolumeLabel
        }
    } else {
        $VolumeLabel = GetMigrationSource
        $MigrationSource = $LocationPath+$VolumeLabel
    }
    return $MigrationSource
}

<#
    .SYNOPSIS
    Get unattached managed disks and export to CSVs
#>

function GetUnattchedDisks {
    param (
        [parameter(Mandatory = $false, HelpMessage = "Volume which need to be free space, If this parameter isn't specified, the volume with least available capacity would be selected by default")]
        [string] $VolumeLabel,

        [parameter(Mandatory = $false, HelpMessage = "Group the unattached disks by user subscription")]
        [switch]$GroupBySubscription,

        [parameter(Mandatory = $false, HelpMessage = "Export the unattached disk list to CSVs, each user subscription would be exported to a separate CSV file")]
        [switch]$ExportToCSV,

        [parameter(Mandatory = $false, HelpMessage = "File path to export the unattached disk list. If not specified, all CSVs would be exported to 'UnattachedDisks' folder under current location")]
        [string]$ExportFolder
    )
    
    $MigrationSource = PrepareMigrationSource -VolumeLabel $VolumeLabel
    $UnattachedDisks = Get-AzsDisk -Status Recommended -SharePath $MigrationSource -Count 1000 | where {$_.DiskType -eq 'Disk'} | select `
      Status, 
      @{Name="DiskSubscription";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[1] }}, `
      @{Name="DiskResourceGroup";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[2] }}, `
      @{Name="DiskName";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[3] }}, `
      ProvisionSizeGB, `
      ActualSizeGB
    if ($GroupBySubscription) {
        $UnattachedDisks = $UnattachedDisks | Group-Object -Property DiskSubscription | select  @{n="Subscription";e={$_.name}}, @{n="DiskCount";e={$_.count}}, @{n="TotalSize";e={($_.Group | Measure-Object -Property ActualSizeGB -Sum).Sum}} | sort TotalSize -Descending
    }
    if ($ExportToCSV) {
        if (!($GroupBySubscription)) {
            throw "ERROR: Export to CSV file only works when 'GroupBySubscription' option is turned on"
        }
        if ($ExportFolder) {
            $folderName = $ExportFolder+"\UnattachedDisks"
        } else {
            $folderName = "UnattachedDisks"
        }
        if (!(Test-Path -Path $folderName))
        {
            New-Item ($folderName) -ItemType Directory | Out-Null
        }
        foreach ($Sub in $UnattachedDisks) {
            $FileName = $folderName+"\Unattached_("+$Sub.DiskCount+")"+$Sub.Subscription+".csv"
            Get-AzsDisk -Status Recommended -SharePath $MigrationSource -Count 1000 -UserSubscriptionId $Sub.Subscription | where {$_.DiskType -eq 'Disk'} | Select `
                Status, 
                @{Name="DiskSubscription";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[1] }}, `
                @{Name="DiskResourceGroup";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[2] }}, `
                @{Name="DiskName";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[3] }}, `
                UserResourceId,
                ActualSizeGb,
                ProvisionSizeGB | Export-Csv -Path $FileName
        }
    }
    return $UnattachedDisks
}

<#
    .SYNOPSIS
    Get attached managed disks and export to CSVs
#>

function GetAttchedDisks {
    param (
        [parameter(Mandatory = $false, HelpMessage = "Volume which need to be free space, If this parameter isn't specified, the volume with least available capacity would be selected by default")]
        [string] $VolumeLabel,

        [parameter(Mandatory = $false, HelpMessage = "Group the unattached disks by user subscription")]
        [switch]$GroupBySubscription,

        [parameter(Mandatory = $false, HelpMessage = "Export the unattached disk list to CSVs, each user subscription would be exported to a separate CSV file")]
        [switch]$ExportToCSV,

        [parameter(Mandatory = $false, HelpMessage = "File path to export the unattached disk list. If not specified, all CSVs would be exported to 'AttachedDisks' folder under current location")]
        [string]$ExportFolder
    )
    
    $MigrationSource = PrepareMigrationSource -VolumeLabel $VolumeLabel
    $AttachedDisks = Get-AzsDisk -status all -SharePath $MigrationSource -Count 1000 | where {$_.status -in @("OnlineMigration","Attached","Reserved")} | select `
      Status, 
      DiskType, 
      @{Name="Volume";Expression={ $m = $_.SharePath -match "\\\\.*\\(.*)"; $matches[1] }}, `
      @{Name="OwnerSubscription";Expression={ $m = $_.ManagedBy -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[1] }}, `
      @{Name="OwnerResourceGroup";Expression={ $m = $_.ManagedBy -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[2] }}, `
      @{Name="OwnerName";Expression={ $m = $_.ManagedBy -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[3] }}, `
      @{Name="DiskSnapshotName";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[3] }}, `
      @{Name="DiskSnapshotResourceGroup";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[2] }}, `
      ProvisionSizeGB, `
      ActualSizeGB, `
      DiskSku
    if ($GroupBySubscription) {
        $AttachedDisks = $AttachedDisks | Group-Object -Property OwnerSubscription | select @{n="DiskCount";e={$_.count}}, @{n="TotalSize";e={($_.Group | Measure-Object -Property ActualSizeGB -Sum).Sum}}, @{n="OwnerSubscription";e={$_.name}} | sort TotalSize -Descending
    }
    if ($ExportToCSV) {
        if (!($GroupBySubscription)) {
            throw "ERROR: Export to CSV file only works when 'GroupBySubscription' option is turned on"
        }
        if ($ExportFolder) {
            $folderName = $ExportFolder+"\AttachedDisks"
        } else {
            $folderName = "AttachedDisks"
        }
        if (!(Test-Path -Path $folderName))
        {
            New-Item ($folderName) -ItemType Directory | Out-Null
        }
        foreach ($Sub in $AttachedDisks) {
            $FileName = $folderName+"\Attached_("+$Sub.DiskCount+")"+$Sub.OwnerSubscription+".csv"
            Get-AzsDisk -Status all -SharePath $MigrationSource -UserSubscriptionId $Sub.OwnerSubscription -Count 1000 | where {($_.DiskType -eq 'Disk') -and ($_.status -in @("OnlineMigration","Attached","Reserved"))} | Select `
                Status, 
                @{Name="DiskSubscription";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[1] }}, `
                @{Name="DiskResourceGroup";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[2] }}, `
                @{Name="DiskName";Expression={ $m = $_.UserResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[3] }}, `
                UserResourceId,
                ActualSizeGb,
                ProvisionSizeGB | Export-Csv -Path $FileName
        }
    }
    return $AttachedDisks
}

<#
    .SYNOPSIS
    Import disk migration candidates from CSV generated from tenant owner
#>

function ImportDiskMigrationCandidates {
    param (
        [parameter(Mandatory = $true, HelpMessage = "File path to the disk migration candidates CSV generated by tenant owner")]
        [string]$CSVFilePath,

        [parameter(Mandatory = $true, HelpMessage = "The migration type of disk, including 'Attached' and 'Unattached'")]
        [ValidateSet('Attached','Unattached')]
        [string]$MigrationType
    )

    $MigrationCandidateId = Import-Csv -Path $CSVFilePath
    $MigrationCandidateDisk = @()
    $FilterStatus = "all"
    if ($MigrationType -eq "Unattached") {
        $FilterStatus = "Recommended"
    }
    if ($MigrationCandidateId) {
        $MigrationCandidateDisk = Get-AzsDisk -Status $FilterStatus -UserSubscriptionId $MigrationCandidateId[0].Subscription -Count 1000 | Where-Object {$_.UserResourceId -in $MigrationCandidateId.UserResourceId}
    }
    return $MigrationCandidateDisk
}