# Azure Stack Compute Administration
![Adding an image in an ADFS environment](/ComputeAdmin/ComputeAdmin.gif)


Instructions below are relative to the .\ComputeAdmin folder of the [AzureStack-Tools repo](..).

Make sure you have the following module prerequisites installed:

```powershell
Install-Module -Name 'AzureRm.Bootstrapper'
Install-AzureRmProfile -profile '2017-03-09-profile' -Force
Install-Module -Name AzureStack -RequiredVersion 1.2.11
```

Then make sure the following modules are imported:

```powershell
Import-Module .\AzureStack.ComputeAdmin.psm1
```

## Add PowerShell environment

You will need to login to your Azure Stack Administrator environment. To create an administrator environment use the below. The ARM endpoint below is the administrator default for a one-node environment.

```powershell
Add-AzureRMEnvironment -Name "AzureStackAdmin" -ArmEndpoint "https://adminmanagement.local.azurestack.external"
```

Then login:

```powershell
Login-AzureRmAccount -EnvironmentName "AzureStackAdmin" 
```
----
If you are **not** using your home directory tenant, you will need to supply the tenant ID to your login command. You may find it easiest to obtain using the Connect tool. For **Azure Active Directory** environments provide your directory tenant name:

```powershell
$TenantID = Get-AzsDirectoryTenantId -AADTenantName "<mydirectorytenant>.onmicrosoft.com" -EnvironmentName AzureStackAdmin
```

For **ADFS** environments use the following:

```powershell
$TenantID = Get-AzsDirectoryTenantId -ADFS -EnvironmentName AzureStackAdmin
```
## Add the WS2016 Evaluation VM Image 

The New-AzsServer2016VMImage allows you to add a Windows Server 2016 Evaluation VM Image to your Azure Stack Marketplace.

As a prerequisite, you need to obtain the Windows Server 2016 Evaluation ISO which can be found [here](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2016).

An example usage is the following:

```powershell

$ISOPath = "<Path to ISO>"
New-AzsServer2016VMImage -ISOPath $ISOPath
```

This command may show a **popup prompt that can be ignored** without issue.

To ensure that the Windows Server 2016 VM Image has the latest cumulative update, provide the -IncludeLatestCU parameter.

Please note that to use this image for some Quick Start templates, you may need to make use of the -Net35 parameter to install .NET Framework 3.5 into the image.

## Add a VM image to the Marketplace with PowerShell

1. Prepare a Windows or Linux operating system virtual hard disk image in VHD format (not VHDX).

    - For Windows images, the article [Upload a Windows VM image to Azure for Resource Manager deployments](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-upload-image/) contains image preparation instructions in the **Prepare the VHD for upload** section.
    - For Linux images, follow the steps to
        prepare the image or use an existing Azure Stack Linux image as described in
        the article [Deploy Linux virtual machines on Azure
        Stack](https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/).

1. Add the VM image by invoking the Add-AzsVMImage cmdlet.

    - Include the publisher, offer, SKU, and version for the VM image. These parameters are used by Azure Resource Manager templates that reference the VM image.
    - Specify osType as Windows or Linux.
    - The following is an example invocation of the script:

```powershell
Add-AzsVMImage -publisher "Canonical" -offer "UbuntuServer" -sku "14.04.3-LTS" -version "1.0.0" -osType Linux -osDiskLocalPath 'C:\Users\<me>\Desktop\UbuntuServer.vhd'
```

The command does the following:

- Authenticates to the Azure Stack environment
- Uploads the local VHD to a newly created temporary storage account
- Adds the VM image to the VM image repository
- Creates a Marketplace item

To verify that the command ran successfully, go to Marketplace in the portal, and then verify that the VM image is available in the **Virtual Machines** category.

## Remove a VM Image with PowerShell

Run the below command to remove an uploaded VM image. After removal, tenants will no longer be able to deploy virtual machines with this image.

```powershell
Remove-AzsVMImage -publisher "Canonical" -offer "UbuntuServer" -sku "14.04.3-LTS" -version "1.0.0"
```

Note: This cmdlet will remove the associated Marketplace item unless the -KeepMarketplaceItem parameter is specified.

## VM Scale Set gallery item

VM Scale Set allows deployment of multi-VM collections. To add a gallery item with VM Scale Set:

1. Add evaluation Windows Server 2016 image using New-AzsServer2016VMImage as described above.

1. For linux support, download Ubuntu Server 16.04 and add it using Add-AzsVMImage with the following parameters -publisher "Canonical" -offer "UbuntuServer" -sku "16.04-LTS"

1. Add VM Scale Set gallery item as follows

```powershell
$Arm = "<AzureStack administrative Azure Resource Manager endpoint URL>"
$Location = "<The location name of your AzureStack Environment>"

Add-AzureRMEnvironment -Name AzureStackAdmin -ArmEndpoint $Arm

$Password = ConvertTo-SecureString -AsPlainText -Force "<your AzureStack admin user password>"
$User = "<your AzureStack admin user name>"
$Creds =  New-Object System.Management.Automation.PSCredential $User, $Password

$AzsEnv = Get-AzureRmEnvironment AzureStackAdmin
$AzsEnvContext = Add-AzureRmAccount -Environment $AzsEnv -Credential $Creds
Select-AzureRmProfile -Profile $AzsEnvContext

Select-AzureRmSubscription -SubscriptionName "Default Provider Subscription"

Add-AzsVMSSGalleryItem -Location $Location

To remove VM Scale Set gallery item run the following command:

```powershell

Remove-AzsVMSSGalleryItem

```

Note that gallery item is not removed immediately. You could run the above command several times to determine when the item is actually gone.
