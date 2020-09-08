# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
    .SYNOPSIS
    Import disks from CSV
#>

function GetDisksFromCSV {
    param (
        [parameter(Mandatory = $true, HelpMessage = "File path to the disk CSV")]
        [string]$CSVFilePath
    )
    
    if (!($CSVFilePath) -or !(Test-Path -Path $CSVFilePath)) {
        throw "ERROR: CSV file doesn't exist. Please specify the correct file path of the disk CSV file"
        return
    } else {
        $Disks = Import-Csv -Path $CSVFilePath
    }
    return $Disks
}

<#
    .SYNOPSIS
    Get snapshots linked to input disks
#>

function GetSnapshotsLinkToDisks {
    param (
        [parameter(Mandatory = $false, HelpMessage = "Import disks from CSV extracted by Cloud Operator")]
        [switch] $ImportDiskCSV,

        [parameter(Mandatory = $false, HelpMessage = "File path to the disk CSV")]
        [string]$CSVFilePath
    )

    $Snapshots = @()
    if ($ImportDiskCSV) {
        $ImportDisks = GetDisksFromCSV -CSVFilePath $CSVFilePath
        if ($ImportDisks) {
            $Subscription = $ImportDisks[0].DiskSubscription
            if ((Get-AzureRmContext).Subscription.Id -ne $Subscription) {
                Select-AzureRmSubscription -Subscription $Subscription
            }
            $Snapshots = Get-AzureRmSnapshot | Where-Object {$_.CreationData.SourceResourceId -in $ImportDisks.UserResourceId}
        }
    } else {
        $Snapshots = Get-AzureRmSnapshot
    }
    $Snapshots = $Snapshots  | select `
        ResourceGroupName, `
        @{Name="SnapshotName"; Expression={$_.Name}}, `
        @{Name="SourceDiskName"; Expression={ $m = $_.CreationData.SourceResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[3] }}, `
        Id
    return $Snapshots
}

<#
    .SYNOPSIS
    Get unattached disks
#>

function GetUnattachedDisks {
    param (
        [parameter(Mandatory = $false, HelpMessage = "Import disks from CSV extracted by Cloud Operator")]
        [switch] $ImportDiskCSV,

        [parameter(Mandatory = $false, HelpMessage = "File path to the disk CSV")]
        [string]$CSVFilePath,

        [parameter(Mandatory = $false, HelpMessage = "Query standalone unattached disks (which don't have related snapshots) as migration candidates and export to CSV")]
        [switch]$MigrationCandidates,

        [parameter(Mandatory = $false, HelpMessage = "File path to export migration candidates as CSV. If not specified, the candidates would be exported to '{subscription ID}_UnattachedMigrationCandidates.CSV' under current location")]
        [string]$ExportFolder
    )

    $Disks = @()
    if ($ImportDiskCSV) {
        $ImportDisks = GetDisksFromCSV -CSVFilePath $CSVFilePath
        if ($ImportDisks) {
            $Subscription = $ImportDisks[0].DiskSubscription
            if ((Get-AzureRmContext).Subscription.Id -ne $Subscription) {
                Select-AzureRmSubscription -Subscription $Subscription
            }
            if ($MigrationCandidates) {
                foreach ($disk in $ImportDisks) {
                    $hasSnapshot = Get-AzureRmSnapshot | Where-Object {$_.CreationData.SourceResourceId -in $disk.UserResourceId}
                    if (!($hasSnapshot)) {
                        $Disks += $disk
                    }
                }
                
                $SubId = (Get-AzureRmContext).Subscription.Id
                $FileName = "\"+$SubId+"_UnattachedMigrationCandidates.CSV"
                if ($ExportFolder) {
                    if (!(Test-Path -Path $ExportFolder)) {
                        throw "ERROR: File path doesn't exist. Please specify the correct file path to export CSV file"
                    } else {
                        $FileName = $ExportFolder+$FileName
                    }
                }
                $Disks | Export-Csv -Path $FileName
            } else {
                foreach ($disk in $ImportDisks) {
                    $UnattachedDisk = Get-AzureRmDisk | Where-Object {$_.Id -eq $disk.UserResourceId}
                    if ($UnattachedDisk) {
                        $undisk = New-Object PsObject -Property @{ ResourceGroupName = $UnattachedDisk.ResourceGroupName ; DiskName = $UnattachedDisk.Name ; ActualSizeGb = $disk.ActualSizeGb ; ProvisionSizeGb = $disk.ProvisionSizeGb}
                        $Disks += $undisk
                    }
                }
            }
        }
    } else {
        if ($MigrationCandidates) {
            throw "ERROR: Query unattached standalond disks for migration only supports searching based on CSV exported by cloud operator. Please turn on the 'ImportDiskCSV' option and specify the CSV path"
        }
        $Disks = Get-AzureRmDisk | Where-Object {$_.ManagedBy -eq $null}
    }
    return $Disks
}

<#
    .SYNOPSIS
    Get attached disks
#>

function GetAttachedDisks {
    param (
        [parameter(Mandatory = $false, HelpMessage = "Import disks from CSV extracted by Cloud Operator")]
        [switch] $ImportDiskCSV,

        [parameter(Mandatory = $false, HelpMessage = "File path to the disk CSV")]
        [string]$CSVFilePath,

        [parameter(Mandatory = $false, HelpMessage = "Query standalone attached disks (which don't have related snapshots and were not created from image) which attached to deallocated VMs as migration candidates, and export to CSV")]
        [switch]$MigrationCandidates,

        [parameter(Mandatory = $false, HelpMessage = "File path to export migration candidates as CSV. If not specified, the candidates would be exported to '{subscription ID}_AttachedMigrationCandidates.CSV' under current location")]
        [string]$ExportFolder,

        [parameter(Mandatory = $false, HelpMessage = "Query owner VM of queried attached disks")]
        [switch]$GroupByVM
    )

    $Disks = @()
    $MigrationDisks = @()
    if ($ImportDiskCSV) {
        $ImportDisks = GetDisksFromCSV -CSVFilePath $CSVFilePath
        if ($ImportDisks) {
            $Subscription = $ImportDisks[0].DiskSubscription
            if ((Get-AzureRmContext).Subscription.Id -ne $Subscription) {
                Select-AzureRmSubscription -Subscription $Subscription
            }
            foreach ($disk in $ImportDisks) {
                $hasSnapshot = Get-AzureRmSnapshot | Where-Object {$_.CreationData.SourceResourceId -in $disk.UserResourceId}
                if (!($hasSnapshot)) {
                    $QueryDisk = Get-AzureRmDisk | Where-Object {$_.Id -eq $disk.UserResourceId}
                    $creationData = $QueryDisk.CreationData
                    switch ($creationData.CreateOption)
                    {
                        "Empty"
                        {
                            $Disks += $QueryDisk
                        }
                        "Copy"
                        {
                            $SourceSnapshotExist = Get-AzureRmSnapshot | Where-Object {$_.Id -eq $creationData.SourceResourceId}
                            if (!($snapshotExist)) {
                                $Disks += $QueryDisk
                            }
                        }
                    }
                }
            }
            $AttachedVMs = $Disks | Group-Object -Property ManagedBy | select `
                @{Name="VMSubscription";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[1] }}, `
                @{Name="VMResourceGroup";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[2] }}, `
                @{Name="VMName";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)/(.*)"; $matches[4] }}, `
                @{Name="VMId"; Expression={$_.Name}}, `
                @{Name="ImpactedDiskCount";Expression={ $_.Count }}
            if ($MigrationCandidates) {
                foreach ($VM in $AttachedVMs) {
                    $CheckVm = Get-AzureRmVM -ResourceGroupName $VM.VMResourceGroup -Name $VM.VMName -Status
                    if ($CheckVm) {
                        if ("VM deallocated" -eq $CheckVm.Statuses.DisplayStatus[1]) {
                            $MigrateTemp = ($Disks | Where-Object {$_.ManagedBy -eq $VM.VMId})
                            $MigrationDisks += ($ImportDisks | Where-Object {$_.UserResourceId -in $MigrateTemp.Id})
                        }
                    } else {
                        $MigrateTemp = ($Disks | Where-Object {$_.ManagedBy -eq $VM.VMId})
                        $MigrationDisks += ($ImportDisks | Where-Object {$_.UserResourceId -in $MigrateTemp.Id})
                    }
                }
                $Disks = $MigrationDisks
                
                $SubId = (Get-AzureRmContext).Subscription.Id
                $FileName = "\"+$SubId+"_AttachedMigrationCandidates.CSV"
                if ($ExportFolder) {
                    if (!(Test-Path -Path $ExportFolder)) {
                        throw "ERROR: File path doesn't exist. Please specify the correct file path to export CSV file"
                    } else {
                        $FileName = $ExportFolder+$FileName
                    }
                }
                $Disks | Export-Csv -Path $FileName
            }
        }
    } else {
        if ($MigrationCandidates) {
            throw "ERROR: Query attached standalond disks for migration only supports searching based on CSV exported by cloud operator. Please turn on the 'ImportDiskCSV' option and specify the CSV path"
        }
        $Disks = Get-AzureRmDisk | Where-Object {$_.ManagedBy -ne $null}
        $AttachedVMs = $Disks | Group-Object -Property ManagedBy | select `
            @{Name="VMSubscription";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[1] }}, `
            @{Name="VMResourceGroup";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[2] }}, `
            @{Name="VMName";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)/(.*)"; $matches[4] }}, `
            @{Name="VMId"; Expression={$_.Name}}, `
            @{Name="ImpactedDiskCount";Expression={ $_.Count }}
    }
    if ($GroupByVM) {
        return $AttachedVMs
    } else {
        return $Disks
    }
}
