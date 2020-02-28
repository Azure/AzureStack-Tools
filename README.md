
# Azure Stack

These tools are meant for use with **Azure Stack Development Kit** and Integrated Systems

## AzureStack-Tools Release/Tags Notification(s)

Please follow the below instructions to make sure you are using the right version of AzureStack-Tools repo:
- Tools for Azure Stack - ASDK or Integrated Systems running a build prior to 1901 can be found here
    https://github.com/Azure/AzureStack-Tools/releases/tag/PRE-1901
    
- Tools for Azure Stack - ASDK or Integrated Systems running a build prior to 1811 can be found here
    https://github.com/Azure/AzureStack-Tools/releases/tag/PRE-1811

- Tools for Azure Stack - ASDK or Integrated Systems running a build prior to 1804 can be found here
    https://github.com/Azure/AzureStack-Tools/releases/tag/PRE-1804

## Tools for using Azure and Azure Stack

To use these tools, obtain Azure Stack compatible Azure PowerShell module. Unless you've installed from other sources, one way to do it is to obtain from public package repositories as follows. Note that both of these could still be used to operate against Azure as well as Azure Stack, but may lack some of the latest Azure features.

For PowerShell, install the following:

For Azure Stack 1904 to 1907

Install the AzureRM.BootStrapper module. Select Yes when prompted to install NuGet
Install-Module -Name AzureRM.BootStrapper

Install and import the API Version Profile required by Azure Stack into the current PowerShell session.
Use-AzureRmProfile -Profile 2019-03-01-hybrid -Force
Install-Module -Name AzureStack -RequiredVersion 1.7.2

For Azure stack 1901 to 1903

```powershell
Install-Module -Name AzureRM -RequiredVersion 2.4.0
Install-Module -Name AzureStack -RequiredVersion 1.7.1
```

For all other azure stack versions, please follow the instructions at https://aka.ms/azspsh for the needed azure powershell


Obtain the tools by cloning the git repository.

```commandline
# For Azure Stack builds/releases 1811 and later:
git clone https://github.com/Azure/AzureStack-Tools.git --recursive
cd AzureStack-Tools
```

```commandline
# For Azure Stack builds/releases prior to 1811:
git clone --branch PRE-1811 https://github.com/Azure/AzureStack-Tools --recursive
cd AzureStack-Tools
```

Otherwise download the tools as follows:

```powershell
# For Azure Stack builds/releases 1811 and later:
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/master.zip -OutFile master.zip
expand-archive master.zip -DestinationPath . -Force
cd AzureStack-Tools-master
```

```powershell
# For Azure Stack builds/releases prior to 1811:
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/PRE-1811.zip -OutFile PRE-1811.zip
expand-archive PRE-1811.zip -DestinationPath . -Force
cd AzureStack-Tools-PRE-1811
```

Instructions below are relative to the root of the repo.

## [Azure Resource Manager policy for Azure Stack](Policy)

Constrains Azure subscription to the capabilities available in the Azure Stack.

- Apply Azure Stack policy to Azure subscriptions and resource groups

## [Deployment of Azure Stack Development Kit ](Deployment)

Helps prepare for ASDK deployment.

- Prepare to Deploy (boot from VHD)
- Prepare to Redeploy (boot back to original/base OS)

## [Connecting to Azure Stack](Connect)

Connect to an Azure Stack ASDK instance from your personal computer/laptop.

- Connect via VPN to an Azure Stack installation

## [Setting up Identity for Azure Stack](Identity)

Create and manage identity related objects and configurations for Azure Stack

## [AzureRM Template Validator](TemplateValidator)

Validate Azure ARM Template Capabilities

- resources - Types, Location, Apiversion
- Compute Capabilities - extensions, images, sizes
- Storage Capabilities - skus

## Tenant Log collection tool

FileName	  | Brief Description
------------- | -------------
Windows\Panther\FastCleanup\setupact.log	  | Primary log file for most errors that occur during the Windows installation process. There are several instances of the Setupact.log file, depending on what point in the installation process the failure occurs. It is important to know which version of the Setupact.log file to look at, based on the phase you are in.
Windows\Panther\UnattendGC\setupact.log	  | High-level list of errors that occurred during the specialize phase of Setup. The Setuperr.log file does not provide any specific details.
Windows\Panther\WaSetup.log  | Windows Setup includes the ability to review the Windows Setup performance events in the Windows Event Log viewer. This enables you to more easily review the actions that occurred during Windows Setup and to review the performance statistics for different parts of Windows Setup
Windows\Panther\WaSetup.xml  | Windows Provisioning Agent log
Windows\Panther\setupact.log  | Primary log file for most errors that occur during the Windows installation process. There are several instances of the Setupact.log file, depending on what point in the installation process the failure occurs. It is important to know which version of the Setupact.log file to look at, based on the phase you are in.
Windows\Panther\setuperr.log  | High-level list of errors that occurred during the specialize phase of Setup. The Setuperr.log file does not provide any specific details
Windows\Panther\unattend.xml  | Windows Provisioning Agent log
WindowsAzure\Logs\MonitoringAgent.log  | Windows Guest Agent Monitoring log
WindowsAzure\Logs\Telemetry.log  | Windows Guest Agent Telemetry service log
WindowsAzure\Logs\TransparentInstaller.log | Windows Guest Agent installation log. Windows Installer records errors and events in its own error log and in the Event log. The diagnostic information that the installer writes to these logs can help users and administrators understand the cause of a failed installation.
WindowsAzure\Logs\WaAppAgent.log  | Windows Guest Agent log. To see when an update to the extension occurred can review the agent logs on the VM. Azure virtual machine (VM) extensions are small applications that provide post-deployment configuration and automation tasks on Azure VMs. For example, if a virtual machine requires software installation, anti-virus protection, or to run a script inside of it, a VM extension can be used
WindowsAzure\Logs\AgentRuntime.log  | Windows Guest Agent Runtime log
WindowsAzure\Logs\TransparentInstaller.000.log  | Windows Guest Agent installation log (rollover)
WindowsAzure\Config\myvm0.1.ExtensionConfig.xml  | XML file containing part of VM’s extension configuration
\var\lib\waagent\ovf-env.xml  | During provisioning, The Azure platform provides initial data to an instance via an attached CD formatted in UDF. That CD contains a ‘ovf-env.xml’ file that provides configuration/deployment information. 
\var\lib\waagent\provisioned  | This file is just a marker that indicates a VHD has been provisioned (specialized).  The absence of this file indicates that the VHD is an image (generalized)
\var\log\dmesg* | Log file(s) that contain messages from the kernel or device drivers
\var\log\syslog  | Standardized text-based log file(s) containing logging and event information.  
\var\log\messages | Standardized text-based log file(s) containing logging and event information.  
\var\log\waagent.log	  | Log file for the Azure Linux agent
---
_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._
