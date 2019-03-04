Tenant Log collection tool

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
Content Cell  | Content Cell
	
	
	
	
	
	
