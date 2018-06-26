# Offline Marketplace Syndication

When Azure Stack is deployed in disconnect mode (Without Internet connectivity) you can
not use the build in portal feature to syndicate Azure Market place items and make them
available to your users.

This Tool allows you to download Azure Marketplace Items with a machine that has internet connectivity and side load them.
The downloaded items need to be transferred to a machine with has connectivity to the Azure Stack deployment before importing them.

![](demosyndicate.gif)

## Requirements

- Azure Stack RP registered within your Azure Subscription

- Azure Subscription used to register Azure Stack System (Multi Node or ASDK)
- AzureStack 1.3.0 PowerShell needs to be installed

(https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install)

- Optional: For best download performance (Premium Download) Azure Storage Tools are required
(http://aka.ms/downloadazcopy)



## Import the Module
```powershell
Import-Module .\AzureStack.MarketplaceSyndication.psm1
```


## Launch the Tool
```powershell
Sync-AzSOfflineMarketplaceItem -destination c:\donwloadfolder -AzureTenantID "Value" -AzureSubscriptionID "SubsciptionID"

```

## Required Parameters

Parameter: AzureTenantID

Description: Specify the Azure Tenant ID for Authentication. This can be retrieved via Portal using the resource explorer or using PS when doing add-azurermaccount.


Parameter: SubscriptionID

Description: Specify the Azure Subscription ID for Authentication when having multiple subscriptions. This can be retrieved via Portal using the resource explorer or using PS when doing add-azurermaccount.

Parameter: destination

Description: Specify a local destination that has enough free storage available.


## Optional Parameters

Parameter: Cloud

Default: AzureCloud

Description: Once Azure Stack RP is available in other Clouds like Azure China you can specify which one to use


## Importing and publish into disconnected Azure Stack

Once the download has been transferred to a machine that can access Azure Stack, you need to import the VHD and publish the AZPKG file.


## Importing the VHD
For detailed steps to use the Portal see:
https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-add-vm-image

For detailed steps using PowerShell see:
https://docs.microsoft.com/en-us/powershell/module/azs.compute.admin/add-azsplatformimage?view=azurestackps-1.3.0



## Publishing the Gallery Item
For detailed steps using PowerShell see:
https://docs.microsoft.com/en-us/powershell/module/azs.gallery.admin/add-azsgalleryitem?view=azurestackps-1.3.0

## Publishing VM Extensions
https://docs.microsoft.com/en-us/powershell/module/azs.compute.admin/add-azsvmextension?view=azurestackps-1.3.0

