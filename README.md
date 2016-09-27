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
This allows your client computer to become part of the Azure Stack One Node network system and therefore resolve [https://portal.azurestack.local](https://portal.azurestack.local), api.azurestack.local, *.blob.azurestack.local and so on. 

The tool will also download root certificate of the targeted Azure Stack One Node instance locally to your client computer. 
This will ensure that SSL sites of the target Azure Stack installation are trusted by your client when accessed from the browser or from the command-line tools.

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
Set-Item wsman:\localhost\Client\TrustedHosts -Value "<Azure Stack host address>" -Concatenate 
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

AzureRM cmdlets can be targeted at multiple Azure clouds such as Azure China, Government, and Azure Stack.
To target your Azure Stack instance, an AzureRM environment needs to be registered as follows.

```powershell
Add-AzureStackAzureRmEnvironment -AadTenant "<mydirectory>.onmicrosoft.com"
```

The AadTenant parameter above specifies the directory that was used when deploying Azure Stack. 
If you do not remember the directory, you could retrieve it as follows. 
Note that Azure Stack One Node host needs to be added to TrustedHosts as described in the VPN section above.

```powershell
$AadTenant = Get-AzureStackAadTenant -HostComputer "<Azure Stack host address>" -Password $Password
Add-AzureStackAzureRmEnvironment -AadTenant $AadTenant
``` 

After registering AzureRM environment cmdlets can be easily targeted at your Azure Stack instance. For example:

```powershell
Add-AzureRmAccount -EnvironmentName AzureStack -TenantId $AadTenant
```

You will be prompted for the account login including two factor authentication if it is enabled in your organization. You can also login with a service pricipal using appropriate parameters of the Add-AzureRmAccount cmdlet.

If the account you are logging in with comes from the same Azure Active Directory tenant as the one used when deploying Azure Stack, then you can omit the TenantId parameter above.

### Register Azure RM Providers on new subscriptions

If you are intending to use newly created subscriptions via PowerShell, CLI or direct API calls before deploying any templates or using the Portal, you need to ensure that resource providers are registered on the subscription.
To register providers on the current subscription, do the following.

```powershell
Register-AllAzureRmProviders
```

To register all resource providers on all your subscriptions after logging in using Add-AzureRmAccount do the following. Note that this can take a while.

```powershell
Register-AllAzureRmProvidersOnAllSubscriptions
```

These registrations are idempotent and can be run multiple times. If provider has already been registered, it will simply be reported in the output.

## Azure Stack Service Administration

```powershell
Import-Module .\ServiceAdmin\AzureStack.ServiceAdmin.psm1
```

### Create default plan and quota for tenants

```powershell
$serviceAdminPassword = (ConvertTo-SecureString "<Azure Stack service admin password in AAD>" -AsPlainText -Force)
$serviceAdmin = New-Object System.Management.Automation.PSCredential -ArgumentList "<myadmin>@<mydirectory>.onmicrosoft.com", $serviceAdminPassword

New-AzureStackTenantOfferAndQuotas -ServiceAdminCredential $serviceAdmin
```

Tenants can now see the "default" offer available to them and can subscribe to it. The offer includes unlimited compute, network, storage and key vault usage. 

## Deployment of Azure Stack

### Azure Stack TP2 Support Files

To easily download the Azure Stack TP2 support files from this repository, run the following PowerShell script from your POC machine:

```powershell
# Variables
$Uri = 'https://raw.githubusercontent.com/Azure/AzureStack-Tools/master/Deployment/'
$LocalPath = 'c:\AzureStack_TP2_SupportFiles'

# Create folder
New-Item $LocalPath -type directory

# Download files
Invoke-WebRequest ($uri + 'BootMenuNoKVM.ps1') -OutFile ($LocalPath + '\BootMenuNoKVM.ps1')
Invoke-WebRequest ($uri + 'PrepareBootFromVHD.ps1') -OutFile ($LocalPath + '\PrepareBootFromVHD.ps1')
Invoke-WebRequest ($uri + 'Unattend.xml') -OutFile ($LocalPath + '\Unattend.xml')
Invoke-WebRequest ($uri + 'unattend_NoKVM.xml') -OutFile ($LocalPath + '\unattend_NoKVM.xml')
```

### Prepare to Deploy (boot from VHD)

This tool allows you to easily prepare your Azure Stack Technical Preview deployment, by preparing the host to boot from the provided Azure Stack Technical Preview virtual harddisk (CloudBuilder.vhdx).

PrepareBootFromVHD updates the boot configuration with an **AzureStack TP2** entry. 
It will verify if the disk that hosts the CloudBuilder.vhdx contains the required free disk space, and optionally copy drivers and an unattend.xml that does not require KVM access.

You will need at least (120GB - Size of the CloudBuilder.vhdx file) of free disk space on the disk that contains the CloudBuilder.vhdx.

#### PrepareBootFromVHD.ps1 Execution

There are five parameters for this script:
  - **CloudBuilderDiskPath** (required) – path to the CloudBuilder.vhdx on the HOST
  - **DriverPath** (optional) – allows you to add additional drivers for the host in the virtual HD 
  - **ApplyUnattend** (optional) – switch parameter, if specified, the configuration of the OS is automated, and the user will be prompted for the AdminPassword to configure at boot (requires provided accompanying file **unattend_NoKVM.xml**)
    - If you do not leverage this parameter, the generic **unattend.xml** file is used without further customization
  - **AdminPassword** (optional) – only used when the **ApplyUnattend** parameter is set, requires a minimum of 6 characters
  - **VHDLanguage** (optional) – specifies the VHD language, defaulted to “en-US”

```powershell
.\Deployment\PrepareBootFromVHD.ps1 -CloudBuilderDiskPath C:\CloudBuilder.vhdx -ApplyUnattend
```

If you execute this exact command, you will be prompted to enter the **AdminPassword** parameter.

During execution of this script, you will have visibility to the **bcdedit** command execution and output.

When the script execution is complete, you will be asked to confirm reboot.
If there are other users logged in, this command will fail, run the following command to continue:
```powershell
Restart-Computer -Force
```

#### HOST Reboot

If you used **ApplyUnattend** and provided an **AdminPassword** during the execution of the PrepareBootFromVHD.ps1 script, you will not need KVM to access the HOST once it completes its reboot cycle.

Of course, you may still need KVM (or some other kind of alternate connection to the HOST other than RDP) if you meet one of the following:
  - You chose not to use **ApplyUnattend**
    -  It will automatically run Windows Setup as the VHD OS is prepared. When asked, provide your country, language, keyboard, and other preferences.
  - Something goes wrong in the reboot/customization process, and you are not able to RDP to the HOST after some time.

### Prepare to Redeploy (boot back to original/base OS)

This tool allows you to easily initiate a redeployment of your Azure Stack Technical Preview deployment, by presenting you with the boot OS options, and the choice to boot back into the original/base OS (away from the previously created **AzureStack TP2**).

BootMenuNoKVM updates the boot configuration with the original/base entry, and then prompts to reboot the host.
Because the default boot entry is set with this script, no KVM or manual selection of the boot entry is required as the machine restarts.

#### BootMenuNoKVM.ps1 Execution

There are no parameters for this script, but it must be executed in an elevated PowerShell console.

```powershell
.\BootMenuNoKVM.ps1
```

During execution of this script, you will be prompted to choose the default OS to boot back into after restart. This will become your new default OS, just like **AzureStack TP2** became the new default OS during deployment.

When the script execution is complete, you will be asked to confirm reboot.
If there are other users logged in, this command will fail, run the following command to continue:
```powershell
Restart-Computer -Force
```

#### HOST Reboot

Because you are choosing the new default OS to boot into, you will not need KVM to access the HOST once it completes its reboot cycle. It will boot into the OS you chose during the execution of the script.

Once the HOST is rebooted back to the original/base OS, you will need to DELETE the previous/existing CloudBuilder.vhdx file, and then copy down a new one to begin redeployment.

## Azure Stack Compute Administration

```powershell
Import-Module .\ComputeAdmin\AzureStack.ComputeAdmin.psm1
```

###Add a VM image to the Marketplace with PowerShell

1. Prepare a Windows or Linux operating system virtual hard disk image in VHD format (not VHDX).
    -   For Windows images, the article [Upload a Windows VM image to Azure for Resource Manager deployments](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-upload-image/) contains image preparation instructions in the **Prepare the VHD for upload** section.
    -   For Linux images, follow the steps to
        prepare the image or use an existing Azure Stack Linux image as described in
        the article [Deploy Linux virtual machines on Azure
        Stack](https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/).

2. Add the VM image by invoking the Add-VMImage cmdlet. 
	-  Include the publisher, offer, SKU, and version for the VM image. These parameters are used by Azure Resource Manager templates that reference the VM image.
	-  Specify osType as Windows or Linux.
	-  Include your Azure Active Directory tenant ID in the form *<mydirectory>*.onmicrosoft.com.
	-  The following is an example invocation of the script:
	
```powershell
Add-VMImage -publisher "Canonical" -offer "UbuntuServer" -sku "14.04.3-LTS" -version "1.0.0" -osType Linux -osDiskLocalPath 'C:\Users\<me>\Desktop\UbuntuServer.vhd' -tenantID <mydirectory>.onmicrosoft.com
```

Note: The cmdlet requests credentials for adding the VM image. Provide the administrator Azure Active Directory credentials, such as *<Admin Account>*@*<mydirectory>*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Uploads the local VHD to a newly created temporary storage account
- Adds the VM image to the VM image repository
- Creates a Marketplace item

To verify that the command ran successfully, go to Marketplace in the portal, and then verify that the VM image is available in the **Virtual Machines** category.


---
_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._
