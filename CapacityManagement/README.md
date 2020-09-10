# Monitor and manage Azure Stack Hub Storage Capacity
The Azure Stack Hub storage service partitions the available storage into separate volumes that are allocated to hold system and tenant data. Object store volumes hold tenant data. Tenant data includes blobs, tables, queues, databases, and related metadata stores. When 90% (and then 95%) of the available space in a volume is used, the system raises alerts in the Azure Stack Hub administrator portal. Cloud operators should review available storage capacity and plan to rebalance the content. The storage service stops working when a disk is 100% used and no additional alerts are raised. To learn more about Azure Stack storage capacity concepts and management process, see [Manage storage capacity for Azure Stack Hub](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-manage-storage-shares).

Instructions below are relative to the .\CapacityManagement folder of the [AzureStack-Tools repo](..).
## Monitor volume capacity and performance
To monitor volume capacity and performance, use Create-AzSStorageDashboard.ps1 in the .\CapacityManagement\AzureStack-VolumesPerformanceDashboard-Generator. This tool is used to generate Capacity Dashboard json, and import the json to Azure Stack Admin portal to show volumes performance and capacity.
To check volume capacity usage, use:

```powershell
.\Create-AzSStorageDashboard.ps1 -capacityOnly $true -volumeType object
```

There would be a json file named starts with “DashboardVolumeObjStore” under the folder of dashboard generator. Sign in to the Azure Stack Hub administrator portal and upload the json in Dashboard page. Once the json is uploaded, you would be directed to the new capacity dashboard. Each volume has a corresponding chart in the dashboard. By checking the volume capacity metrics, the cloud operator understands how much a volume’s capacity is utilized, and which resource type is taking most of the space usage. To learn more, see [Manage storage capacity for Azure Stack Hub](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-manage-storage-shares).

##  Free up space of a volume
To free up space of a specific volume by cleaning and migrating storage resources, both cloud operator and tenant owner need to be involved in the workflow. The workflow can be divided into two stages: delete/migrate unattached managed disks, migrate attached managed disks.
If you are a cloud operator, use Capacity Management module:
```powershell
Import-Module ".\AzureStack.CapacityMgmt.psm1"
```

If you are a tenant owner, use Tenant Capacity Management module:
```powershell
Import-Module ".\AzureStack.CapacityMgmtTenant.psm1"
```

>[!TIP]  
> The [role] information before each step indicates whether cloud operator or tenant owner should perform the action of this step

### Delete/migrate unattached managed disks
1. [Cloud operator] Identify the volume of which capacity need to be freed up, and specify the volume label (with the format as 'ObjStore_X') as the migration source. You can aslo use *GetMigrationSource* to get the most used volume.

```powershell
$VolumeLabel = GetMigrationSource
```
2. [Cloud operator] List all unattached managed disks stored on volume X grouped by user subscription, and export the list to CSV files. The CSV files would be stored within "UnattachedDisks" folder under the file path provided with *-ExportFolder* parameter (if not specified, "UnattachedDisks" folder would be generated under current location). And each user subscription would have a corresponding CSV file named as "Unattached_({DiskCount}){SubscriptionId}.csv".

```powershell
GetUnattachedDisks -VolumeLabel $VolumeLabel -GroupBySubscription -ExportToCSV -ExportFolder "D:\CapacityManagement"
```

Once the unattached disk list CSVs are exported, the cloud operator should contact the tenant owner of each impacted user subscription and pass the corresponding generated CSV file to do the disk cleaning. To get the contact information of a specific user subscription, please use [get-azsusersubscription](https://docs.microsoft.com/en-us/powershell/module/azs.subscriptions.admin/get-azsusersubscription).

3. [Tenant owner] Query all managed snapshots created from unattached managed disks provided by the cloud operator, and export the result list to CSV file named as "SnapshotsLinkToDisks_{SubscriptionId}.CSV" under the file path provided with *-ExportFolder* parameter (if not specified, result CSV file would be placed under current location).

```powershell
GetSnapshotsLinkToDisks -CSVFilePath 'D:\CapacityManagement\UnattachedDisks\Unattached_({DiskCount}){SubscriptionId}.csv' -ExportToCSV -ExportFolder D:\CapacityManagement
```

Once the CSV file is exported, tenant owner should review the list, and remove all snapshots which still need to be kept in Azure Stack Hub from the list in CSV file.

>[!TIP]  
> To avoid misoperation, you can save the CSV file as "DeleteSnapshots.CSV", and make sure it only contains the snapshots need to be deleted.

4. [Tenant owner] Clean the unnecessary managed snapshots from Azure Stack Hub with the "DeleteSnapshots.CSV" edited in step 3.

```powershell
RemoveSnapshotsInCSV -CSVFilePath D:\CapacityManagement\DeleteSnapshots.CSV
```

5. [Tenant owner] Query unattached managed disks based on list CSV provided by cloud operator, and export the result list to CSV file named as "UnattachedDisks_{SubscriptionId}.CSV" under the file path provided with *-ExportFolder* parameter (if not specified, result CSV file would be placed under current location).

```powershell
GetUnattachedDisks -ImportDiskCSV 'D:\CapacityManagement\UnattachedDisks\Unattached_({DiskCount}){SubscriptionId}.csv' -ExportToCSV -ExportFolder D:\CapacityManagement
```

Once the CSV file is exported, tenant owner should review the list, and remove all managed disks which still need to be kept in Azure Stack Hub from the list in CSV file.

>[!TIP]  
> To avoid misoperation, you can save the CSV file as "DeleteDisks.CSV", and make sure it only contains the managed disks need to be deleted.

6. [Tenant owner] Clean the unnecessary managed disks from Azure Stack Hub with the "DeleteDisks.CSV" edited in step 5.

```powershell
RemoveDisksInCSV -CSVFilePath D:\CapacityManagement\DeleteDisks.CSV
```

7. [Tenant ower] Query all standalone unattached managed disks (which don't have related managed snapshots) on volume X as the migration candidates, and export the result list to CSV file named as "UnattachedMigrationCandidates_{SubscriptionId}.CSV" under the file path provided with *-ExportFolder* parameter (if not specified, result CSV file would be placed under current location).

```powershell
GetUnattachedDisks -ImportDiskCSV 'D:\CapacityManagement\UnattachedDisks\Unattached_({DiskCount}){SubscriptionId}.csv' -MigrationCandidates -ExportToCSV -ExportFolder D:\CapacityManagement
```

Once the migration candidates CSV is exported, provide the CSV to cloud operator.

8. [Cloud operator] Import the managed disk list generated by tenant owner in step 7 as disk migration candidates, and run managed disk offline migration.

```powershell
$MigrationDisk = ImportDiskMigrationCandidates -MigrationType Unattached -CSVFilePath D:\CapacityManagement\UnattachedMigrationCandidates_{SubscriptionId}.CSV
$MigrationTarget = GetMigrationTarget
$JobName = "MigratingUnattachedDisk"
Start-AzsDiskMigrationJob -Disks $MigrationDisk -TargetShare $MigrationTarget -Name $JobName
```

For more detail about disk offline migration, please see [Migrate a managed disk between volumes](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-manage-storage-shares#migrate-a-managed-disk-between-volumes)

### Migrate attached managed disks.
1. [Cloud operator] List all attached managed disks stored on volume X grouped by user subscription, and export the list to CSV files. The CSV files would be stored within "AttachedDisks" folder under the file path provided with *-ExportFolder* parameter (if not specified, "AttachedDisks" folder would be generated under current location). And each user subscription would have a corresponding CSV file named as "Attached_({DiskCount}){SubscriptionId}.csv".

```powershell
GetAttachedDisks -VolumeLabel $VolumeLabel -GroupBySubscription -ExportToCSV -ExportFolder "D:\CapacityManagement"
```

Once the attached disk list CSVs are exported, the cloud operator should contact the tenant owner of each impacted user subscription and pass the corresponding generated CSV file to do the disk migration preparation. To get the contact information of a specific user subscription, please use [get-azsusersubscription](https://docs.microsoft.com/en-us/powershell/module/azs.subscriptions.admin/get-azsusersubscription).

2. [Tenant owner] Query all managed snapshots created from attached managed disks provided by the cloud operator, and export the result list to CSV file named as "SnapshotsLinkToDisks_{SubscriptionId}.CSV" under the file path provided with *-ExportFolder* parameter (if not specified, result CSV file would be placed under current location).

```powershell
GetSnapshotsLinkToDisks -CSVFilePath 'D:\CapacityManagement\AttachedDisks\Attached_({DiskCount}){SubscriptionId}.csv' -ExportToCSV -ExportFolder D:\CapacityManagement
```

Once the CSV file is exported, tenant owner should review the list, and remove all snapshots which still need to be kept in Azure Stack Hub from the list in CSV file.

>[!TIP]  
> To avoid misoperation, you can save the CSV file as "DeleteSnapshots.CSV", and make sure it only contains the snapshots need to be deleted.

3. [Tenant owner] Clean the unnecessary managed snapshots from Azure Stack Hub with the "DeleteSnapshots.CSV" edited in step 2.

```powershell
RemoveSnapshotsInCSV -CSVFilePath D:\CapacityManagement\DeleteSnapshots.CSV
```

4. [Tenant owner] Query the VMs who own the attached managed disks based on list CSV provided by cloud operator, and export the result list to CSV file named as "OwnerVMOfAttachedDisks_{SubscriptionId}.CSV" under the file path provided with *-ExportFolder* parameter (if not specified, result CSV file would be placed under current location).

```powershell
GetAttachedDisks -ImportDiskCSV 'D:\CapacityManagement\AttachedDisks\Attached_({DiskCount}){SubscriptionId}.csv' -GroupByVM -ExportToCSV -ExportFolder D:\CapacityManagement
```

Once the CSV file is exported, tenant owner should review the list to check whether the VM can be deallocated, and remove all VMs which can't be deallocated from the list in CSV file.

>[!TIP]  
> To avoid misoperation, you can save the CSV file as "StopVM.CSV", and make sure it only contains the VMs need to be deallocated.

5. [Tenant owner] Deallocate VMs for offline migration with the "StopVM.CSV" edited in step 4.

```powershell
DeallocateVMsInCSV -CSVFilePath D:\CapacityManagement\StopVM.CSV
```

6. [Tenant ower] Query all standalone reserved managed disks (which weren't created from image or existing snapshot, and don't have related managed snapshots) on volume X as the migration candidates, and export the result list to CSV file named as "AttachedMigrationCandidates_{SubscriptionId}.CSV" under the file path provided with *-ExportFolder* parameter (if not specified, result CSV file would be placed under current location).

```powershell
GetAttachedDisks -ImportDiskCSV 'D:\CapacityManagement\AttachedDisks\Attached_({DiskCount}){SubscriptionId}.csv' -MigrationCandidates -ExportToCSV -ExportFolder D:\CapacityManagement
```

Once the migration candidates CSV is exported, provide the CSV to cloud operator.

7. [Cloud operator] Import the managed disk list generated by tenant owner in step 6 as disk migration candidates, and run managed disk offline migration.

```powershell
$MigrationDisk = ImportDiskMigrationCandidates -MigrationType Attached -CSVFilePath D:\CapacityManagement\AttachedMigrationCandidates_df1b02be-0841-4d55-8f7b-cbe45ef4b5b9.CSV
$MigrationTarget = GetMigrationTarget
$JobName = "MigratingAttachedDisk"
New-AzsDiskMigrationJob -Disks $MigrationDisk -TargetShare $MigrationTarget -Name $JobName
```

For more detail about disk offline migration, please see [Migrate a managed disk between volumes](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-manage-storage-shares#migrate-a-managed-disk-between-volumes)
