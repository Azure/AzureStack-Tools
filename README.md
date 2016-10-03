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
# Set Variabales
$LocalPath = 'c:\AzureStack_TP2_SupportFiles'
$Api = 'https://api.github.com/repos/Azure/AzureStack-Tools'
$Uri = 'https://raw.githubusercontent.com/Azure/AzureStack-Tools/master/'
$RelPath = ''

# Get the Tree Recursively from the GitHub API
$Master = ConvertFrom-Json (invoke-webrequest ($Api + '/git/trees/master'))
$Content = (ConvertFrom-Json (invoke-webrequest ($Api + '/git/trees/' + $Master.sha + '?recursive=1'))).tree
if ($RelPath){$Content = $Content | where {$_.path -match $RelPath}}

# Create Folders and download files
New-Item $LocalPath -type directory -Force
($Content | where { ($_.type -eq 'tree') -and ($_.path -match $RelPath) }).path | ForEach { New-Item ($LocalPath + '\' + $_) -type directory -Force }
($Content | where { ($_.type -eq 'blob') -and ($_.path -match $RelPath) }).path | ForEach { Invoke-WebRequest ($Uri + $_) -OutFile ($LocalPath + '\' + $_) }
```
Instructions below are relative to the root of the repo.

## [Azure Resource Manager policy for Azure Stack](Policy)

Constrains Azure subscription to the capabilities available in the Azure Stack.
- Apply Azure Stack policy to Azure subscriptions and resource groups

## [Deployment of Azure Stack](Deployment)

Helps perpare for Azure Stack deployment.
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

---
_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._
