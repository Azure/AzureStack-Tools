# Azure Stack

These tools are meant for use with **Azure Stack Development Kit** and Integrated Systems running build 2002 and up. For prior builds use AzureRM module supported version here: https://github.com/Azure/AzureStack-Tools/tree/master

## Dependency

To use these tools, obtain Azure Stack compatible Az PowerShell module.
Az module - refer for installation related instructions https://docs.microsoft.com/en-us/azure-stack/operator/powershell-install-az-module

Obtain the tools by cloning the git repository.

```commandline
git clone https://github.com/Azure/AzureStack-Tools.git --recursive
cd AzureStack-Tools
git checkout az
```

Otherwise download the tools as follows:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/az.zip -OutFile az.zip
expand-archive az.zip -DestinationPath . -Force
cd AzureStack-Tools-az
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

GuestOS | FileName	  | Brief Description
------------- | ------------- | -------------
Windows | Windows\Panther\FastCleanup\setupact.log	  | Primary log file for most errors that Windows | occur during the Windows installation process. There are several instances of the Setupact.log Windows | file, depending on what point in the installation process the failure occurs. It is important to Windows | know which version of the Setupact.log file to look at, based on the phase you are in.
Windows | Windows\Panther\UnattendGC\setupact.log	  | High-level list of errors that occurred during the Windows | specialize phase of Setup. The Setuperr.log file does not provide any specific details.
Windows | Windows\Panther\WaSetup.log  | Windows Setup includes the ability to review the Windows Setup Windows | performance events in the Windows Event Log viewer. This enables you to more easily review the Windows | actions that occurred during Windows Setup and to review the performance statistics for different Windows | parts of Windows Setup
Windows | Windows\Panther\WaSetup.xml  | Windows Provisioning Agent log
Windows | Windows\Panther\setupact.log  | Primary log file for most errors that occur during the Windows Windows | installation process. There are several instances of the Setupact.log file, depending on what Windows | point in the installation process the failure occurs. It is important to know which version of Windows | the Setupact.log file to look at, based on the phase you are in.
Windows | Windows\Panther\setuperr.log  | High-level list of errors that occurred during the specialize Windows | phase of Setup. The Setuperr.log file does not provide any specific details
Windows | Windows\Panther\unattend.xml  | Windows Provisioning Agent log
Windows | WindowsAzure\Logs\MonitoringAgent.log  | Windows Guest Agent Monitoring log
Windows | WindowsAzure\Logs\Telemetry.log  | Windows Guest Agent Telemetry service log
Windows | WindowsAzure\Logs\TransparentInstaller.log | Windows Guest Agent installation log. Windows Windows | Installer records errors and events in its own error log and in the Event log. The diagnostic Windows | information that the installer writes to these logs can help users and administrators understand Windows | the cause of a failed installation.
Windows | WindowsAzure\Logs\WaAppAgent.log  | Windows Guest Agent log. To see when an update to the Windows | extension occurred can review the agent logs on the VM. Azure virtual machine (VM) extensions are Windows | small applications that provide post-deployment configuration and automation tasks on Azure VMs. Windows | For example, if a virtual machine requires software installation, anti-virus protection, or to Windows | run a script inside of it, a VM extension can be used
Windows | WindowsAzure\Logs\AgentRuntime.log  | Windows Guest Agent Runtime log
Windows | WindowsAzure\Logs\TransparentInstaller.000.log  | Windows Guest Agent installation log (rollover)
Windows | WindowsAzure\Config\myvm0.1.ExtensionConfig.xml  | XML file containing part of VM’s extension configuration
Linux | /var/lib/waagent/ovf-env.xml  | During provisioning, The Azure platform provides initial data to an instance via an attached CD formatted in UDF. That CD contains a ‘ovf-env.xml’ file that provides configuration/deployment information.
Linux | /var/lib/waagent/provisioned  | This file is just a marker that indicates a VHD has been Linux | provisioned (specialized).  The absence of this file indicates that the VHD is an image Linux | (generalized)
Linux | /var/log/dmesg* | Log file(s) that contain messages from the kernel or device drivers
Linux | /var/log/syslog | Standardized text-based log file(s) containing logging and event information.  
Linux | /var/log/messages | Standardized text-based log file(s) containing logging and event Linux | information.  
Linux | /var/log/waagent.log | Log file for the Azure Linux agent
---
_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._
