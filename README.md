
# Azure Stack

These tools are meant for use with **Azure Stack Development Kit** and Integrated Systems

## Import Notification

Tools for Azure Stack - ASDK or Integrated Systems running a build prior to 1804 can be found here
https://github.com/Azure/AzureStack-Tools/releases/tag/PRE-1804

## Tools for using Azure and Azure Stack

To use these tools, obtain Azure Stack compatible Azure PowerShell module. Unless you've installed from other sources, one way to do it is to obtain from public package repositories as follows. Note that both of these could still be used to operate against Azure as well as Azure Stack, but may lack some of the latest Azure features.

For PowerShell, install the following:


```powershell
Install-Module -Name 'AzureRm.Bootstrapper'
Install-AzureRmProfile -profile '2017-03-09-profile' -Force
Install-Module -Name AzureStack -RequiredVersion 1.4.0
```

Obtain the tools by cloning the git repository.

```commandline
git clone https://github.com/Azure/AzureStack-Tools.git --recursive
cd AzureStack-Tools
```

Otherwise download the tools as follows:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/master.zip -OutFile master.zip
expand-archive master.zip -DestinationPath . -Force
cd AzureStack-Tools-master
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

---
_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._
