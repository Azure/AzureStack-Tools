# Tools for using Azure and Azure Stack

To use these tools, obtain Azure Stack compatible Azure PowerShell module and CLI. Unless you've installed from other sources, one way to do it is to obtain from public package repositories as follows. Note that both of these could still be used to operate against Azure as well as Azure Stack, but may lack some of the latest Azure features.

For PowerShell, install the following:

```powershell
Install-Module -Name AzureRM -RequiredVersion 1.2.8 -Scope CurrentUser
Install-Module -Name AzureStack
```

```
npm install azure-cli@0.9.18
```

Obtain the tools by cloning the git repo.

```
git clone https://github.com/Azure/AzureStack-Tools.git --recursive
cd AzureStack-Tools
```

Otherwise download the tools as follows

```powershell
invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/master.zip -OutFile master.zip
expand-archive master.zip -DestinationPath . -Force
cd AzureStack-Tools-master
```
Instructions below are relative to the root of the repo.

## [Azure Resource Manager policy for Azure Stack](Policy)

Constrains Azure subscription to the capabilities available in the Azure Stack.
- Apply Azure Stack policy to Azure subscriptions and resource groups

## [Deployment of Azure Stack](Deployment)

Helps prepare for Azure Stack deployment.
-	Prepare to Deploy (boot from VHD)
-	Prepare to Redeploy (boot back to original/base OS)

## [Connecting to Azure Stack](Connect)

Connect to an Azure Stack instance from your personal computer/laptop.
- Connect via VPN to an Azure Stack installation
- Configure Azure Stack PowerShell environment
- Prepare new subscriptions for use in PowerShell and CLI

## [Azure Stack Service Administration](ServiceAdmin)

Manage plans and subscriptions in Azure Stack.
- Add default (unlimited) plans and quotas so that tenants can create new subscriptions

## [Azure Stack Compute Administration](ComputeAdmin)

Manage compute (VM) service in Azure Stack.
- Add VM Image to the Azure Stack Marketplace

## [Azure Stack Infrastructure Administration](Infrastructure)

Manage Azure Stack Infrastructure
- Get Infrastructure resolve
- Get Infrastructure Virtual machines
- Get Storage Capacity
- Get Storage Shares
- Get Scale Unit
- Get Node
- Get Logical network
- Get Alert
- Close Alert
- Get Update Region Summary
- Get Update
- Apply Update
- Get Update run

## [AzureRM Template Validator](TemplateValidator)

Validate Azure ARM Template Capabilities
- resources - Types, Location, Apiversion
- Compute Capabilities - extensions, images, sizes
- Storage Capabilities - skus

---
_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._
