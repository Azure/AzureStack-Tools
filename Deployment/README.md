# Azure Stack Development Kit installer

The Azure Stack Development Kit installer provides a UI with the following features

- Prepare the SafeOS for deployment
- Prepare the Azure Stack Development Kit Installation
- Rerun and Gather Logs
- Reboot to SafeOS

![](https://github.com/1RedOne/AzureStack-Tools/blob/master/Deployment/ScreenShot.png?raw=true)

To install the Azure Stack Development Kit you require

- A physical server that meets the requirements
- The latest cloudbuilder.vhdx
- The asdk-installer.ps1 script

## Download the Azure Stack Development Kit installer

To easily download the Azure Stack Development Kit installer from this repository, run the following PowerShell script from your SafeOS host:

```powershell
# Variables
$Uri = 'https://raw.githubusercontent.com/Azure/AzureStack-Tools/master/Deployment/asdk-installer.ps1'
$LocalPath = 'c:\AzureStack_Installer'

# Create folder
New-Item $LocalPath -Type directory

# Download file
Invoke-WebRequest $uri -OutFile ($LocalPath + '\' + 'asdk-installer.ps1')
```

## Prepare the SafeOS for deployment

The installer script can be used to prepare your host for the deployment of the Azure Stack Development Kit. After you have downloaded the cloudbuilder.vhdx, run the script on the server you would like to deploy to.

Select the cloudbuilder.vhdx and optionally specify a path to a folder containing drivers for the host.
The host can be configured with the following options:
 - **Local administrator password** - If you uncheck this option the host will prompt for a password during the oobe setup when rebooting to the cloudbuilder.vhdx. Not specifying a local administrator password requires KVM access to the host to specify the password during boot.
 - **Computer name** - You can specify the name for the Azure Stack Development Kit host. The name needs to comply with FQDN requirements and cannot be longer than 15 characters. If you do not select the option, Windows generates a computername during OOBE.
 - **Static IP Configuration** If the Azure Stack development kit needs to be configured with a static IP address, select this option. The installer will prompt for the networking interface and copy the current values for use in the cloudbuilder.vhdx during reboot. You can override the values that where copied if needed. If you do not select this option the network interfaces will be configured with DHCP when rebooted into the cloudbuilder.vhdx

 A job will perform the following actions:

  - Verify if the disk containing the cloudbuilder.vhdx has **enough space** to expand the disk. You will need at least (120GB - Size of the cloudBuilder.vhdx file) of free disk space on the disk that contains the cloudBuilder.vhdx.
  - Remove previous **Azure Stack** boot entries .
  - **Mount** the cloudbuilder.vhdx.
  - Add **bootfiles** to the Operating System disk.
  - Updates the boot configuration with an **Azure Stack** entry for the virtual hard disk and sets it to the default value.
  - Adds an **unattend** file to the Operating System on the mounted virtual hard disk, based on the selections made in the wizard.
  - Adds **drivers** to the operating system, if that option was selected during the wizard.

When the job is completed you finalize the wizard to reboot into the cloudbuilder.vhdx. If you have enabled the local administrator password and have connectivity to the IP address (either the static one specified or based on DHCP), you can remote into the host with RDP after the OOBE completes.

## Prepare the Azure Stack Development Kit installation

Once the host has succesfully completed booting from the cloudbuilder.vhdx, logon to the host as administrator and start the same installation script again. The installer script was originally stored on c:\AzureStack_Installer. After the reboot into cloudbuilder.vhdx the SafeOS system disk is presented as a datadisk in the Operating System of the Azure Stack Development Kit host OS. Browse for the script and execute it by righclicking it and select Run with PowerShell. Or browse to the path in a PowerShell session and run; 

```powershell
.\asdk-installer.ps1
```

Click install to start the deployment wizard. Select the preferred identity provider for your Azure Stack Development Kit deployment.

 - **Azure Cloud** : Azure Active Directory
 - **ADFS** : Local ADFS instance as part of the installation

If you selected Azure Cloud, specify the Azure Active Directory tenant (e.g. azurestack.onmicrosoft.com). 

Submit the local administrator password. This value submitted has to match the current configured local administrator password.

In the network interface screen, select the adapter that will be used for the Azure Stack Development Kit. Ensure you have access to the IP address as all other adapters will be disabled by the installer.

The network configuration screen allows you to specify the settings for the BGPNAT vm. The default settings uses DHCP for the BGPNAT vm. You can set it to static, but only use this parameter if DHCP can’t assign a valid IP address for Azure Stack to access the Internet. A static IP address needs to be specified with the subnetmask length (e.g. 10.0.0.5/24). Optionally you can specify the TimeServer, DNS Server and VLAN ID.

The summary screen displays the PowerShell script that will be executed. Click deploy start the deployment of the Azure Stack Development Kit.

> Note: When you have selected Azure Cloud as the identity provider, you will be prompted 2 to 3 minutes after the deployment has started. Please ensure you submit your Azure AD credentials.

## Rerun and gather logs

If during the installation an error occures, you can start the installer script to rerun the installation from where it failed. After 3 failed reruns the installer script will gather the logs for support purposes and stores them in c:\AzureStackLogs

If the installation completed succesfully, but you ran into an issue that requires you to gather the log files, you can run the same installer script. The installer will present you with the option to gather the logs and store them in c:\AzureStackLogs

## Reboot

The installer script allows you to easily initiate a reboot to the SafeOS to start a redeployment of your Azure Stack Development Kit. Start the installer script and select Reboot. You will be presented with the current boot options. Select the entry for the SafeOS and select Reboot. This creates a onetime override in the boot order. The SafeOS boot entry will be select automatically. The next reboot the boot configuration will resume its normal order and the host will boot into the cloudbuilder.vhdx again.

### Note
The Azure Stack Development Kit installer script is based on PowerShell and the Windows Presentation Foundation. It is published in this public repository so you can make improvements to it by submitting a pull request.
