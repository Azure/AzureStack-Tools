# Deployment of Azure Stack

Instructions below are relative to the .\Deployment folder of the [AzureStack-Tools repo](..).

## Azure Stack TP3 Support Files

To easily download the Azure Stack TP3 support files from this repository, run the following PowerShell script from your POC machine:

```powershell
# Variables
$Uri = 'https://raw.githubusercontent.com/Azure/AzureStack-Tools/master/Deployment/'
$LocalPath = 'c:\AzureStack_TP3_SupportFiles'

# Create folder
New-Item $LocalPath -Type directory

# Download files
'BootMenuNoKVM.ps1', 'PrepareBootFromVHD.ps1', 'Unattend.xml', 'unattend_NoKVM.xml' | foreach { Invoke-WebRequest ($uri + $_) -OutFile ($LocalPath + '\' + $_) } 
```

## Prepare to Deploy (boot from VHD)

This tool allows you to easily prepare your Azure Stack Technical Preview deployment, by preparing the host to boot from the provided Azure Stack Technical Preview virtual harddisk (CloudBuilder.vhdx).

PrepareBootFromVHD updates the boot configuration with an **Azure Stack** entry. 
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
Restart-Computer -Force
```

### HOST Reboot

If you used **ApplyUnattend** and provided an **AdminPassword** during the execution of the PrepareBootFromVHD.ps1 script, you will not need KVM to access the HOST once it completes its reboot cycle.

Of course, you may still need KVM (or some other kind of alternate connection to the HOST other than RDP) if you meet one of the following:
  - You chose not to use **ApplyUnattend**
    -  It will automatically run Windows Setup as the VHD OS is prepared. When asked, provide your country, language, keyboard, and other preferences.
  - Something goes wrong in the reboot/customization process, and you are not able to RDP to the HOST after some time.

## Prepare to Redeploy (boot back to original/base OS)

This tool allows you to easily initiate a redeployment of your Azure Stack Technical Preview deployment, by presenting you with the boot OS options, and the choice to boot back into the original/base OS (away from the previously created **Azure Stack**).

BootMenuNoKVM updates the boot configuration with the original/base entry, and then prompts to reboot the host.
Because the default boot entry is set with this script, no KVM or manual selection of the boot entry is required as the machine restarts.

### BootMenuNoKVM.ps1 Execution

There are no parameters for this script, but it must be executed in an elevated PowerShell console.

```powershell
.\BootMenuNoKVM.ps1
```

During execution of this script, you will be prompted to choose the default OS to boot back into after restart. This will become your new default OS, just like **Azure Stack** became the new default OS during deployment.

When the script execution is complete, you will be asked to confirm reboot.
If there are other users logged in, this command will fail, run the following command to continue:
```powershell
Restart-Computer -Force
```

### HOST Reboot

Because you are choosing the new default OS to boot into, you will not need KVM to access the HOST once it completes its reboot cycle. It will boot into the OS you chose during the execution of the script.

Once the HOST is rebooted back to the original/base OS, you will need to DELETE the previous/existing CloudBuilder.vhdx file, and then copy down a new one to begin redeployment.
