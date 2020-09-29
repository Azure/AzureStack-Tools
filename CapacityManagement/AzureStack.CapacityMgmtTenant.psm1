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
        Write-Error "ERROR: CSV file doesn't exist. Please specify the correct file path of the disk CSV file"
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
        [parameter(Mandatory = $true, HelpMessage = "File path to the disk CSV")]
        [string]$CSVFilePath,

        [parameter(Mandatory = $false, HelpMessage = "Export the snapshots list to CSV")]
        [switch]$ExportToCSV,

        [parameter(Mandatory = $false, HelpMessage = "Folder to export snapshots as CSV. If not specified, the candidates would be exported to 'SnapshotsLinkToDisks_{subscription ID}.CSV' under current location")]
        [string]$ExportFolder
    )

    if ($ExportFolder -and !(Test-Path -Path $ExportFolder)) {
        Write-Error "ERROR: File path doesn't exist. Please specify the correct file path to export CSV file"
        return
    }

    $Snapshots = @()
    $ImportDisks = GetDisksFromCSV -CSVFilePath $CSVFilePath
    if ($ImportDisks) {
        $Subscription = $ImportDisks[0].DiskSubscription
        if ((Get-AzureRmContext).Subscription.Id -ne $Subscription) {
            Select-AzureRmSubscription -Subscription $Subscription
        }
        $Snapshots = Get-AzureRmSnapshot | Where-Object {$_.CreationData.SourceResourceId -in $ImportDisks.UserResourceId}
    }
    $Snapshots = $Snapshots  | select `
        @{Name="UserSubscription"; Expression={ $m = $_.Id -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[1] }}, `
        @{Name="SourceDiskResourceGroup"; Expression={ $m = $_.CreationData.SourceResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[2] }}, `
        @{Name="SourceDiskName"; Expression={ $m = $_.CreationData.SourceResourceId -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/.*/(.*)"; $matches[3] }}, `
        @{Name="SnapshotResourceGroup"; Expression={$_.ResourceGroupName}}, `
        @{Name="SnapshotName"; Expression={$_.Name}}, `
        Id
    if ($ExportToCSV) {
        $SubId = (Get-AzureRmContext).Subscription.Id
        $FileName = "SnapshotsLinkToDisks_"+$SubId+".CSV"
        if ($ExportFolder) {
            $FileName = $ExportFolder+"\"+$FileName
        }
        $Snapshots | Export-Csv -Path $FileName
        Write-Host "Exported snapshot list to $FileName"
        return
    }
    return $Snapshots
}

<#
    .SYNOPSIS
    Get unattached disks
#>

function GetUnattachedDisks {
    param (
        [parameter(Mandatory = $false, HelpMessage = "File path to the import disk CSV")]
        [string]$ImportDiskCSV,

        [parameter(Mandatory = $false, HelpMessage = "Query standalone unattached disks (which don't have related snapshots) as migration candidates")]
        [switch]$MigrationCandidates,

        [parameter(Mandatory = $false, HelpMessage = "Export the unattached disks list to CSV")]
        [switch]$ExportToCSV,

        [parameter(Mandatory = $false, HelpMessage = "Folder to export unattached disks as CSV. If not specified, the candidates would be exported to 'UnattachedDisks_{subscription ID}.CSV' or 'UnattachedMigrationCandidates_{subscription ID}.CSV' (if -MigrationCandidates setting turned on) under current location")]
        [string]$ExportFolder
    )
    
    if ($ImportDiskCSV -and !(Test-Path -Path $ImportDiskCSV)) {
        Write-Error "ERROR: Import file doesn't exist. Please specify the correct file path to import disks"
        return
    }
    if ($ExportFolder -and !(Test-Path -Path $ExportFolder)) {
        Write-Error "ERROR: Export folder doesn't exist. Please specify the correct file path to export CSV file"
        return
    }
    if ($MigrationCandidates -and !($ImportDiskCSV)) {
        Write-Error "ERROR: Query unattached standalond disks for migration only supports searching based on CSV exported by cloud operator. Please turn on the 'ImportDiskCSV' option and specify the CSV path"
        return
    }

    $Disks = @()
    if ($ImportDiskCSV) {
        $ImportDisks = GetDisksFromCSV -CSVFilePath $ImportDiskCSV
        if ($ImportDisks) {
            $Subscription = $ImportDisks[0].DiskSubscription
            if ((Get-AzureRmContext).Subscription.Id -ne $Subscription) {
                Select-AzureRmSubscription -Subscription $Subscription
            }
            if ($MigrationCandidates) {
                foreach ($disk in $ImportDisks) {
                    $hasSnapshot = Get-AzureRmSnapshot | Where-Object {$_.CreationData.SourceResourceId -in $disk.UserResourceId}
                    if (!($hasSnapshot)) {
                        $UnattachedDisk = Get-AzureRmDisk | Where-Object {$_.Id -eq $disk.UserResourceId}
                        if ($UnattachedDisk) {
                            $Disks += $UnattachedDisk | select `
                                         @{Name="UserSubscription"; Expression={$disk.DiskSubscription}}, `
                                         @{Name="ResourceGroupName"; Expression={$_.ResourceGroupName}}, `
                                         @{Name="DiskName"; Expression={$_.Name}}, `
                                         @{Name="ActualSizeGb"; Expression={$disk.ActualSizeGb}}, `
                                         @{Name="ProvisionSizeGb"; Expression={$disk.ProvisionSizeGb}}, `
                                         Id
                        }
                    }
                }
            } else {
                foreach ($disk in $ImportDisks) {
                    $UnattachedDisk = Get-AzureRmDisk | Where-Object {$_.Id -eq $disk.UserResourceId}
                    if ($UnattachedDisk) {
                        $Disks += $UnattachedDisk | select `
                                     @{Name="UserSubscription"; Expression={$disk.DiskSubscription}}, `
                                     @{Name="ResourceGroupName"; Expression={$_.ResourceGroupName}}, `
                                     @{Name="DiskName"; Expression={$_.Name}}, `
                                     @{Name="ActualSizeGb"; Expression={$disk.ActualSizeGb}}, `
                                     @{Name="ProvisionSizeGb"; Expression={$disk.ProvisionSizeGb}}, `
                                     Id
                    }
                }
            }
        }
    } else {
        $SubId = (Get-AzureRmContext).Subscription.Id
        $Disks = Get-AzureRmDisk | Where-Object {$_.ManagedBy -eq $null} | select `
            @{Name="UserSubscription"; Expression={$SubId}}, `
            @{Name="ResourceGroupName"; Expression={$_.ResourceGroupName}}, `
            @{Name="DiskName"; Expression={$_.Name}}, `
            @{Name="ActualSizeGb"; Expression={"Unknown"}}, `
            @{Name="ProvisionSizeGb"; Expression={$_.DiskSizeGb}}, `
            Id
    }
    if ($ExportToCSV) {
        $SubId = (Get-AzureRmContext).Subscription.Id
        if ($MigrationCandidates) {
            $FileName = "UnattachedMigrationCandidates_"+$SubId+".CSV"
        } else {
            $FileName = "UnattachedDisks_"+$SubId+".CSV"
        }
        if ($ExportFolder) {
            $FileName = $ExportFolder+"\"+$FileName
        }
        $Disks | Export-Csv -Path $FileName                
        if ($MigrationCandidates) {
            Write-Host "Exported unattached migration candidates list to $FileName"
        } else {
            Write-Host "Exported unattached list to $FileName"
        }                
        return
    }
    return $Disks
}

<#
    .SYNOPSIS
    Get attached disks
#>

function GetAttachedDisks {
    param (
        [parameter(Mandatory = $false, HelpMessage = "File path to the import disk CSV")]
        [string] $ImportDiskCSV,

        [parameter(Mandatory = $false, HelpMessage = "Query standalone attached disks (which don't have related snapshots and were not created from image) which attached to deallocated VMs as migration candidates, and export to CSV")]
        [switch]$MigrationCandidates,

        [parameter(Mandatory = $false, HelpMessage = "Export the attached disks list to CSV")]
        [switch]$ExportToCSV,

        [parameter(Mandatory = $false, HelpMessage = "Folder to export attached disks as CSV. If not specified, the candidates would be exported to 'AttachedDisks_{subscription ID}.CSV' or 'AttachedMigrationCandidates_{subscription ID}.CSV' (if -MigrationCandidates setting turned on) or 'OwnerVMOfAttachedDisks_{subscription ID}.CSV' (if -GroupByVM setting turned on) under current location")]
        [string]$ExportFolder,

        [parameter(Mandatory = $false, HelpMessage = "Query owner VM of queried attached disks")]
        [switch]$GroupByVM
    )
    
    if ($ImportDiskCSV -and !(Test-Path -Path $ImportDiskCSV)) {
        Write-Error "ERROR: Import file doesn't exist. Please specify the correct file path to import disks"
        return
    }
    if ($ExportFolder -and !(Test-Path -Path $ExportFolder)) {
        Write-Error "ERROR: Export folder doesn't exist. Please specify the correct file path to export CSV file"
        return
    }
    if ($MigrationCandidates -and !($ImportDiskCSV)) {
        Write-Error "ERROR: Query attached standalond disks for migration only supports searching based on CSV exported by cloud operator. Please turn on the 'ImportDiskCSV' option and specify the CSV path"
        return
    }

    $Disks = @()
    $MigrationDisks = @()
    $AttachedVMs = @()
    if ($ImportDiskCSV) {
        $ImportDisks = GetDisksFromCSV -CSVFilePath $ImportDiskCSV
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
                            $Disks += $QueryDisk | select `
                                     @{Name="UserSubscription"; Expression={$Subscription}}, `
                                     ResourceGroupName, `
                                     @{Name="DiskName"; Expression={$_.Name}}, `
                                     @{Name="ActualSizeGb"; Expression={$disk.ActualSizeGb}}, `
                                     @{Name="ProvisionSizeGb"; Expression={$disk.ProvisionSizeGb}}, `
                                     @{Name="OwnerVMResourceGroup";Expression={ $m = $_.ManagedBy -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[2] }}, `
                                     @{Name="OwnerVMName";Expression={ $m = $_.ManagedBy -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)/(.*)"; $matches[4] }}, `
                                     Id, `
                                     ManagedBy
                        }
                        "Copy"
                        {
                            $SourceSnapshotExist = Get-AzureRmSnapshot | Where-Object {$_.Id -eq $creationData.SourceResourceId}
                            if (!($snapshotExist)) {
                                $Disks += $QueryDisk | select `
                                     @{Name="UserSubscription"; Expression={$Subscription}}, `
                                     ResourceGroupName, `
                                     @{Name="DiskName"; Expression={$_.Name}}, `
                                     @{Name="ActualSizeGb"; Expression={$disk.ActualSizeGb}}, `
                                     @{Name="ProvisionSizeGb"; Expression={$disk.ProvisionSizeGb}}, `
                                     @{Name="OwnerVMResourceGroup";Expression={ $m = $_.ManagedBy -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[2] }}, `
                                     @{Name="OwnerVMName";Expression={ $m = $_.ManagedBy -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)/(.*)"; $matches[4] }}, `
                                     Id, `
                                     ManagedBy
                            }
                        }
                    }
                }
            }
            $AttachedVMGroup = $Disks | Group-Object -Property ManagedBy | select `
                @{Name="VMSubscription";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[1] }}, `
                @{Name="VMResourceGroup";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[2] }}, `
                @{Name="VMName";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)/(.*)"; $matches[4] }}, `
                @{Name="VMId"; Expression={$_.Name}}, `
                @{Name="ImpactedDiskCount";Expression={ $_.Count }}
            foreach ($VM in $AttachedVMGroup) {
                $CheckVm = Get-AzureRmVM -ResourceGroupName $VM.VMResourceGroup -Name $VM.VMName -Status
                if ($CheckVm) {
                    $AttachedVMs += $VM | select `
                        VMSubscription,
                        VMResourceGroup,
                        VMName,
                        VMId,
                        ImpactedDiskCount,
                        @{Name="VMStatus";Expression={ $CheckVm.Statuses.DisplayStatus[1] }}
                } else {
                    $AttachedVMs += $VM | select `
                        VMSubscription,
                        VMResourceGroup,
                        VMName,
                        VMId,
                        ImpactedDiskCount,
                        @{Name="VMStatus";Expression={ "Removed" }}
                }
            }

            if ($MigrationCandidates) {
                foreach ($VM in $AttachedVMs) {
                    if ("VM deallocated" -eq $VM.VMStatus) {
                        $MigrateTemp = ($Disks | Where-Object {$_.ManagedBy -eq $VM.VMId})
                        $MigrationDisks += $MigrateTemp
                    }
                }
                $Disks = $MigrationDisks
            }
        }
    } else {
        $SubId = (Get-AzureRmContext).Subscription.Id
        $Disks = Get-AzureRmDisk | Where-Object {$_.ManagedBy -ne $null} | select `
            @{Name="UserSubscription"; Expression={$SubId}}, `
            ResourceGroupName, `
            @{Name="DiskName"; Expression={$_.Name}}, `
            @{Name="ActualSizeGb"; Expression={"Unknown"}}, `
            @{Name="ProvisionSizeGb"; Expression={$_.DiskSizeGb}}, `
            @{Name="OwnerVMResourceGroup";Expression={ $m = $_.ManagedBy -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[2] }}, `
            @{Name="OwnerVMName";Expression={ $m = $_.ManagedBy -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)/(.*)"; $matches[4] }}, `
            Id, `
            ManagedBy
        $AttachedVMs = $Disks | Group-Object -Property ManagedBy | select `
            @{Name="VMSubscription";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[1] }}, `
            @{Name="VMResourceGroup";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)"; $matches[2] }}, `
            @{Name="VMName";Expression={ $m = $_.Name -match "/subscriptions/(.*)/resourceGroups/(.*)/providers/Microsoft.Compute/(.*)/(.*)"; $matches[4] }}, `
            @{Name="VMId"; Expression={$_.Name}}, `
            @{Name="ImpactedDiskCount";Expression={ $_.Count }}
    }

    if ($ExportToCSV) {
        $SubId = (Get-AzureRmContext).Subscription.Id
        if ($MigrationCandidates) {
            $FileName = "AttachedMigrationCandidates_"+$SubId+".CSV"
            $OutputMsg = "Exported attached migration candidates list to $FileName"
        } else {
            if ($GroupByVM) {
                $FileName = "OwnerVMOfAttachedDisks_"+$SubId+".CSV"
                $OutputMsg = "Exported owner VMs of attached disks to $FileName"
            } else {
                $FileName = "AttachedDisks_"+$SubId+".CSV"
                $OutputMsg = "Exported attached disks list to $FileName"
            }
        }
        if ($ExportFolder) {
            $FileName = $ExportFolder+"\"+$FileName
        }
        if ($GroupByVM) {
            $AttachedVMs | Export-Csv -Path $FileName           
        } else {
            $Disks | Export-Csv -Path $FileName           
        }
        
        Write-Host $OutputMsg               
        return
    }
    if ($GroupByVM) {
        return $AttachedVMs
    } else {
        return $Disks
    }
}

<#
    .SYNOPSIS
    Import a CSV and remove all snapshots listed in the CSV
#>

function RemoveSnapshotsInCSV {
    param (
        [parameter(Mandatory = $true, HelpMessage = "File path to the snapshots CSV")]
        [string]$CSVFilePath
    )
      
    if (!($CSVFilePath) -or !(Test-Path -Path $CSVFilePath)) {
        Write-Error "ERROR: File doesn't exist. Please specify the correct file path to import snapshots"
        return
    }
    $ImportSnapshots = GetDisksFromCSV -CSVFilePath $CSVFilePath
    if ($ImportSnapshots) {
        $Subscription = $ImportSnapshots[0].UserSubscription
        if ((Get-AzureRmContext).Subscription.Id -ne $Subscription) {
            Select-AzureRmSubscription -Subscription $Subscription
        }
        foreach ($snapshot in $ImportSnapshots) {
            Remove-AzureRmSnapshot -ResourceGroupName $snapshot.SnapshotResourceGroup -SnapshotName $snapshot.SnapshotName -Verbose -Confirm:$false -Force
        }
        Write-Host "Removed all snapshots in $CSVFilePath"
    }
}


<#
    .SYNOPSIS
    Import a CSV and remove all managed disks listed in the CSV
#>

function RemoveDisksInCSV {
    param (
        [parameter(Mandatory = $true, HelpMessage = "File path to the disks CSV")]
        [string]$CSVFilePath
    )
      
    if (!($CSVFilePath) -or !(Test-Path -Path $CSVFilePath)) {
        Write-Error "ERROR: File doesn't exist. Please specify the correct file path to import disks"
        return
    }
    $ImportDisks = GetDisksFromCSV -CSVFilePath $CSVFilePath
    if ($ImportDisks) {
        $Subscription = $ImportDisks[0].UserSubscription
        if ((Get-AzureRmContext).Subscription.Id -ne $Subscription) {
            Select-AzureRmSubscription -Subscription $Subscription
        }
        foreach ($disk in $ImportDisks) {
            Remove-AzureRmDisk -ResourceGroupName $disk.ResourceGroupName -DiskName $disk.DiskName -Verbose -Confirm:$false -Force
        }
        Write-Host "Removed all disks in $CSVFilePath"
    }
}


<#
    .SYNOPSIS
    Import a CSV and deallocate all VMs listed in the CSV
#>

function DeallocateVMsInCSV {
    param (
        [parameter(Mandatory = $true, HelpMessage = "File path to the VM CSV")]
        [string]$CSVFilePath
    )
      
    if (!($CSVFilePath) -or !(Test-Path -Path $CSVFilePath)) {
        Write-Error "ERROR: File doesn't exist. Please specify the correct file path to import VMs"
        return
    }
    $ImportVMs = GetDisksFromCSV -CSVFilePath $CSVFilePath
    if ($ImportVMs) {
        $Subscription = $ImportVMs[0].VMSubscription
        if ((Get-AzureRmContext).Subscription.Id -ne $Subscription) {
            Select-AzureRmSubscription -Subscription $Subscription
        }
        foreach ($vm in $ImportVMs) {
            Stop-AzureRmVM -ResourceGroupName $vm.VMResourceGroup -Name $vm.VMName -Verbose -Confirm:$false -Force
        }
        Write-Host "Deallocated all VMs in $CSVFilePath"
    }
}
