# Azure Stack Compute Administration
Instructions below are relative to the .\ComputeAdmin folder of the [AzureStack-Tools repo](..).

Make sure you have the following module prerequisites installed:

```powershell
Install-Module -Name AzureRM -RequiredVersion 1.2.8 -Scope CurrentUser
Install-Module -Name AzureStack -RequiredVersion 1.2.8 -Scope CurrentUser
```
Then make sure the following modules are imported:

```powershell
Import-Module ..\Connect\AzureStack.Connect.psm1
Import-Module .\AzureStack.ComputeAdmin.psm1
```

Adding a VM Image requires that you obtain the GUID value of your Directory Tenant. If you know the non-GUID form of the Azure Active Directory Tenant used to deploy your Azure Stack instance, you can retrieve the GUID value with the following:

```powershell
$aadTenant = Get-AADTenantGUID -AADTenantName "<myaadtenant>.onmicrosoft.com" 
```

Otherwise, it can be retrieved directly from your Azure Stack deployment. First, add your host to the list of TrustedHosts:
```powershell
Set-Item wsman:\localhost\Client\TrustedHosts -Value "<Azure Stack host address>" -Concatenate
```
Then execute the following:
```powershell
$Password = ConvertTo-SecureString "<Admin password provided when deploying Azure Stack>" -AsPlainText -Force
$AadTenant = Get-AzureStackAadTenant  -HostComputer <Host IP Address> -Password $Password
```

##Add the WS2016 Evaluation VM Image 

The New-Server2016VMImage allows you to add a Windows Server 2016 Evaluation VM Image to your Azure Stack Marketplace. 

As a prerequisite, you need to obtain the Windows Server 2016 Evaluation ISO which can be found [here](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2016).

An example usage is the following:
```powershell
$ISOPath = "<Path to ISO>"
New-Server2016VMImage -ISOPath $ISOPath -TenantId $aadTenant  
```

To ensure that the Windows Server 2016 VM Image has the latest cumulative update, provide the -IncludeLatestCU parameter.

Please note that to use this image for **installing additional Azure Stack services**, you will need to make use of the -Net35 parameter to install .NET Framework 3.5 into the image.

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
Add-VMImage -publisher "Canonical" -offer "UbuntuServer" -sku "14.04.3-LTS" -version "1.0.0" -osType Linux -osDiskLocalPath 'C:\Users\<me>\Desktop\UbuntuServer.vhd' -tenantID <GUID AADTenant>
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
Remove-VMImage -publisher "Canonical" -offer "UbuntuServer" -sku "14.04.3-LTS" -version "1.0.0" -osType Linux -tenantID <GUID AADTenant>
```

Note: This cmdlet will remove the associated Marketplace item unless the -KeepMarketplaceItem parameter is specified.
