# Tools for using Azure and Azure Stack

To use these tools, obtain Azure Stack compatible Azure PowerShell module and CLI. Unless you've installed from other sources, one way to do it is to obtain from public package repositories as follows. Note that both of these could still be used to operate against Azure as well as Azure Stack, but may lack some of the latest Azure features.

```powershell
Install-Module -Name AzureRm -RequiredVersion 1.2.6 -Scope CurrentUser
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

## [Deployment of Azure Stack](Deployment)

Helps perpare for Azure Stack deployment.

## [Connecting to Azure Stack](Connect)

Connect to an Azure Stack instance from your personal computer/laptop.

## [Azure Stack Service Administration](ServiceAdmin)

Manage plans and subscriptions in Azure Stack.

## [Azure Stack Compute Administration](ComputeAdmin)

Manage compute (VM) service in Azure Stack.

---
_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._
