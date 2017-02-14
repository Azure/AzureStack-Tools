# Azure Stack Compute Administration
Instructions below are relative to the .\ComputeAdmin folder of the [AzureStack-Tools repo](..).

```powershell
Import-Module .\AzureStack.ComputeAdmin.psm1
```

Note: This module also requires that you have imported the AzureStack.Connect module.

```powershell
Import-Module ..\Connect\AzureStack.Connect.psm1
```

##Add a VM image to the Marketplace with PowerShell

1. Prepare a Windows or Linux operating system virtual hard disk image in VHD format (not VHDX).
    -   For Windows images, the article [Upload a Windows VM image to Azure for Resource Manager deployments](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-upload-image/) contains image preparation instructions in the **Prepare the VHD for upload** section.
    -   For Linux images, follow the steps to
        prepare the image or use an existing Azure Stack Linux image as described in
        the article [Deploy Linux virtual machines on Azure
        Stack](https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/).

2. Add the VM image by invoking the Add-VMImage cmdlet. 
	-  Include the publisher, offer, SKU, and version for the VM image. These parameters are used by Azure Resource Manager templates that reference the VM image.
	-  Specify osType as Windows or Linux.
	-  Include your Azure Active Directory tenant ID in the form *&lt;mydirectory&gt;*.onmicrosoft.com.
	-  The following is an example invocation of the script:
	
```powershell
Add-VMImage -publisher "Canonical" -offer "UbuntuServer" -sku "14.04.3-LTS" -version "1.0.0" -osType Linux -osDiskLocalPath 'C:\Users\<me>\Desktop\UbuntuServer.vhd' -tenantID <mydirectory>.onmicrosoft.com
```

Note: The cmdlet requests credentials for adding the VM image. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Uploads the local VHD to a newly created temporary storage account
- Adds the VM image to the VM image repository
- Creates a Marketplace item

To verify that the command ran successfully, go to Marketplace in the portal, and then verify that the VM image is available in the **Virtual Machines** category.

##Remove a VM Image with PowerShell
Run the below command to remove an uploaded VM image. After removal, tenants will no longer be able to deploy virtual machines with this image.

```powershell
Remove-VMImage -publisher "Canonical" -offer "UbuntuServer" -sku "14.04.3-LTS" -version "1.0.0" -osType Linux -tenantID <mydirectory>.onmicrosoft.com
```

Note: This cmdlet does not remove any Marketplace item created as part of uploading a VM Image. These Marketplace items will need to be removed separately.