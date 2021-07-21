# Monitor and manage Azure Stack Hub Storage Capacity
The Azure Stack Hub storage service partitions the available storage into separate volumes that are allocated to hold system and tenant data. Object store volumes hold tenant data. Tenant data includes blobs, tables, queues, databases, and related metadata stores. When 90% (and then 95%) of the available space in a volume is used, the system raises alerts in the Azure Stack Hub administrator portal. Cloud operators should review available storage capacity and plan to rebalance the content. The storage service stops working when a disk is 100% used and no additional alerts are raised. To learn more about Azure Stack storage capacity concepts and management process, see [Manage storage capacity for Azure Stack Hub](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-manage-storage-shares).

Instructions below are relative to the .\CapacityManagement folder of the [AzureStack-Tools repo](..).
## Monitor volume capacity and performance
To monitor volume capacity and performance, use Create-AzSStorageDashboard.ps1 in the .\CapacityManagement\DashboardGenerator. This tool is used to generate Capacity Dashboard json, and import the json to Azure Stack Admin portal to show volumes performance and capacity.
To check volume capacity usage, use:

```powershell
.\Create-AzSStorageDashboard.ps1 -capacityOnly $true -volumeType object
```

There would be a json file named starts with “DashboardVolumeObjStore” under the folder of dashboard generator. Sign in to the Azure Stack Hub administrator portal and upload the json in Dashboard page. Once the json is uploaded, you would be directed to the new capacity dashboard. Each volume has a corresponding chart in the dashboard. By checking the volume capacity metrics, the cloud operator understands how much a volume’s capacity is utilized, and which resource type is taking most of the space usage. To learn more, see [Manage storage capacity for Azure Stack Hub](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-manage-storage-shares).
