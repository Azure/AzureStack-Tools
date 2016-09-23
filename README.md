# Tools for using Azure and Azure Stack

To use these tools, obtain Azure Stack compatible Azure PowerShell module and CLI. Unless you've installed from other sources, one way to do it is to obtain from public package repositories as follows. Note that both of these could still be used to operate against Azure as well as Azure Stack, but may lack some of the latest Azure features.

```powershell
Install-Module -Name AzureRm -RequiredVersion 1.2.6 -Scope CurrentUser
```

```
npm install azure-cli@0.9.18
```

## Azure Resource Manager policy for Azure Stack

This tool constrains Azure subscription to the capabilities available in the Azure Stack via the [Azure Resource Manager policy](https://azure.microsoft.com/en-us/documentation/articles/resource-manager-policy/).

```powershell
Import-Module .\Policy\AzureStack.Policy.psm1

Login-AzureRmAccount
$s = Select-AzureRmSubscription -SubscriptionName "<sub name>"
$subId = $s.Subscription.SubscriptionId

$policy = New-AzureRmPolicyDefinition -Name AzureStack -Policy (Get-AzureStackRmPolicy)

New-AzureRmPolicyAssignment -Name AzureStack -PolicyDefinition $policy -Scope /subscriptions/$subId
```

To constrain only a particular resource group in your Azure subscription to match the capabilities of Azure Stack, specify the resource group in the scope as below when assigning the policy.

```powershell
#Specify the resource group where you would like to apply the policy
$rgName = 'AzureStack'
New-AzureRmPolicyAssignment -Name AzureStack -PolicyDefinition $policy -Scope /subscriptions/$subID/resourceGroups/$rgName
```

To remove the Azure Stack policy, run this command with the same scope used when the policy was applied:
```powershell
Remove-AzureRmPolicyAssignment -Name AzureStack -Scope /subscriptions/$subId/resourceGroups/$rgName
Remove-AzureRmPolicyAssignment -Name AzureStack -Scope /subscriptions/$subId
```

## Connecting to Azure Stack

This tool allows you to connect to an Azure Stack instance from your personal computer/laptop.

```powershell
Import-Module .\Connect\AzureStack.Connect.psm1
```

### VPN to Azure Stack One Node

You can establish a split tunnel VPN connection to an Azure Stack One Node. 
This allows your client computer to become part of the Azure Stack One Node network system and therefore resolve [https://portal.azurestak.local](https://portal.azurestack.local), api.azurestack.local, *.blob.azurestack.local and so on. 

The tool will wlso download root certificate of the targeted Azure Stack One Node instance locally to your client computer. 
This will esnure that SSL sites of the target Azure Stack installation are trusted by your client when accessed from the browser or from the command-line tools.

Use the admin password provided at the time of the Azure Stack deployment.

```powershell
$Password = (ConvertTo-SecureString "<Admin password provided when deploying Azure Stack>" -AsPlainText -Force)
```

To connect to Azure Stack One Node via VPN, first locate the NAT address of the target installation. 
If you specified static IP of the NAT when deploying Azure Stack One Node, then use it in the connection example below. 
If you did not specify static IP then NAT was configured with DHCP. In that case, obtain NAT IP as follows using IP address of the Azure Stack One Node host (which should be known to you after deployment).  

Since the command below needs to access the Azure Stack One Node host computer via its IP address, it needs to be a trusted host in PowerShell. Run PowerShell as administrator and add TrustedHosts as follows.

```powershell
# Add Azure Stack One Node host to the trusted hosts on your client computer
$hosts = get-item wsman:\localhost\Client\TrustedHosts
set-item wsman:\localhost\Client\TrustedHosts -value ("<Azure Stack host address>, " + $hosts.Value)

# Or simply allow all hosts to be trusted for remote calls (less secure)
set-item wsman:\localhost\Client\TrustedHosts -value *
```

Then obtain NAT IP.

```powershell
$natIp = Get-AzureStackNatServerAddress -HostComputer "<Azure Stack host address>" -Password $Password
```

Then connect your client computer as follows.

```powershell
# Create VPN connection entry for the current user
Add-AzureStackVpnConnection -ServerAddress $natIp -Password $Password

# Connect to the Azure Stack instance. This command can be used multiple times.
Connect-AzureStackVpn -Password $Password
```
### Configure Azure Stack PowerShell Environment

AzureRM command-lets can be targeted at multiple Azure clouds such as Azure China, Government and Azure Stack.
To target your Azure Stack instance, an AzureRM environment needs to be registered as follows.

Note that Azure Stack One Node host needs to be added to TrustedHosts as described in the VPN section above.

```powershell
Add-AzureStackAzureRmEnvironment -HostComputer "<Azure Stack host address>" -Password $Password
``` 

After registering AzureRM environment command-lets can be easily targeted at your Azure Stack instance. For example:

```powershell
Add-AzureRmAccount -EnvironmentName AzureStack
```

## Prepare to Boot from VHD

This tool allows you to easily prepare your Azure Stack Technical Preview deployment, by preparing the host to boot from the provided AzureStack Technical Preview virtual harddisk (CloudBuilder.vhdx).

PrepareBootFromVHD updates the boot configuration with an AzureStack TP2 entry. 
It will verify if the disk that hosts the CloudBuilder.vhdx contains the required free disk space, and optionally copy drivers and an unattend.xml that does not require KVM access.

You will need at least (120GB - Size of the CloudBuilder.vhdx file) of free disk space on the disk that contains the CloudBuilder.vhdx.

### PrepareBootFromVHD.ps1 Execution

There are five parameters for this script:
  - **CloudBuilderDiskPath** (required) – path to the CloudBuilder.vhdx on the HOST
  - **DriverPath** (optional) – allows you to add additional drivers for the host in the virtual HD 
  - **ApplyUnattend** (optional) – switch parameter, if specified, the configuration of the OS is automated, and the user will be prompted for the AdminPassword to configure at boot (requires provided accompanying file **unattend_NoKVM.xml**)
    - If you do not leverage this parameter, the generic **unattend.xml** file is used without further customization
  - **AdminPassword** (optional) – only used when the **ApplyUnattend** parameter is set, requires a minimum of 6 characters
  - **VHDLanguage** (optional) – specifies the VHD language, defaulted to “en-US”

```powershell
.\PrepareBootFromVHD.ps1 -CloudBuilderDiskPath C:\CloudBuilder.vhdx -ApplyUnattend
```

If you execute this exact command, you will be prompted to enter the **AdminPassword** parameter.

During execution of this script, you will have visibility to the **bcdedit** command execution and output.

When the script execution is complete, you will be asked to confirm reboot.
If there are other users logged in, this command will fail, run the following command to continue:
```powershell
Restart-Computer -force
```

### HOST Reboot

If you used **ApplyUnattend** and provided an **AdminPassword** during the execution of the PrepareBootFromVHD.ps1 script, you will not need KVM to access the HOST once it completes its reboot cycle.

Of course, you may still need KVM (or some other kind of alternate connection to the HOST other than RDP) if you meet one of the following:
  - You chose not to use **ApplyUnattend**
    -  It will automatically run Windows Setup as the VHD OS is prepared. When asked, provide your country, language, keyboard, and other preferences.
  - Something goes wrong in the reboot/customization process, and you are not able to RDP to the HOST after some time.

---
_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._

##Add a VM image to the Marketplace with PowerShell

If the VM image VHD is available locally on the console VM (or another externally connected device), use the following steps:

1. Prepare a Windows or Linux operating system virtual hard disk image in VHD format (not VHDX).
    -   For Windows images, the article [Upload a Windows VM image to Azure for Resource Manager deployments](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-upload-image/) contains image preparation instructions in the **Prepare the VHD for upload** section.
    -   For Linux images, follow the steps to
        prepare the image or use an existing Azure Stack Linux image as described in
        the article [Deploy Linux virtual machines on Azure
        Stack](https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/).

2. Clone this repository and then go to the **Marketplace** directory and then the **VMImageUploader** directory.
3. Open PowerShell. Then, in the **VMImageUploader** folder, run the following command:

```powershell
Import-Module .\Add-VMImage.psm1
```

4. Add the VM image by invoking the Add-VMImage cmdlet. Make sure you run the command from the same directory that you imported the module from.
	-  Include the publisher, offer, SKU, and version for the VM image. These parameters are used by Azure Resource Manager templates that reference the VM image.
	-  Specify osType as Windows or Linux.
	-  Include your Azure Active Directory tenant ID in the form *&lt;myaadtenant&gt;*.onmicrosoft.com.
	-  The following is an example invocation of the script:
	
```powershell
Add-VMImage -publisher "Canonical" -offer "UbuntuServer" -sku "14.04.3-LTS" -version "1.0.0" -osType Linux -osDiskLocalPath 'C:\Users\AzureStackAdmin\Desktop\UbuntuServer.vhd' -tenantID <myaadtenant>.onmicrosoft.com
```

Note: The cmdlet requests credentials for adding the VM image. Provide the administrator Azure Active Directory credentials, such as serviceadmin@*&lt;myaadtenant&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Uploads the local VHD to a newly created temporary storage account
- Adds the VM image to the VM image repository
- Creates a Marketplace item

To verify that the command ran successfully, go to Marketplace in the portal, and then verify that the VM image is available in the **Virtual Machines** category.


