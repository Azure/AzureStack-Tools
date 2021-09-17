
# Azure Stack

These tools are meant for use with **Azure Stack Hub** and Integrated Systems

master branch contains the tools compatible with AzureRm version of azure powershell.
az branch contains the tools compatible with AzureRm version of azure powershell.
We are not changing the default branch master to support Az considering that this would be a breaking change

## Tools for using Azure and Azure Stack

To use these tools, obtain Azure Stack compatible Azure PowerShell module. Unless you've installed from other sources, one way to do it is to obtain from public package repositories as follows. Note that both of these could still be used to operate against Azure as well as Azure Stack, but may lack some of the latest Azure features.

To install supported version of azure powershell, please follow the instructions at https://aka.ms/azspsh 

Obtain the tools by cloning the git repository. Switch to az branch for Az powershell, master is compatible with AzureRM powershell

Or download the tools with the instructions from the documentaion page https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-powershell-download


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
