# The Marketplace Toolkit for Microsoft Azure Stack

The Marketplace Toolkit for Microsoft Azure Stack provides service administrators and application developers with a UI to create and upload marketplace items to the Microsoft Azure Stack marketplace.

## Features

The toolkit allows you to 
- Create and publish a solution for the marketplace. This accepts any main ARM template and allows you to define the tenant deployment experience, by creating steps, re-assigning and re-ordering parameters.
- Create and publish an extension for the marketplace. This creates a marketplace item for a VM Extension template that will surface on the extension tab of a deployed virtual machine.
- Publish an existing package. If you have an existing marketplace item package (.azpkg file), the publish wizard enables an easy wizard to publish the package to the marketplace.

## Requirements

To use the Marketplace Toolkit for Microsoft Azure Stack script you require:

- This script
- The gallerypackager executable (http://www.aka.ms/azurestackmarketplaceitem)
- Access as Azure Stack administrator to the Azure Stack environment. This is only required if you want to publish the generated package to the marketplace. For this you will also need to install the current PowerShell modules to support Azure Stack on the machine that runs this script (https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install).

## Download the Marketplace Toolkit
To  download the Azure Stack Marketplace Toolkit from this repository, run the following PowerShell script:

```PowerShell
# Variables
$Uri = 'https://raw.githubusercontent.com/Azure/AzureStack-Tools/master/Marketplace/'
$LocalPath = 'c:\AzureStack_Marketplace'

# Create folder
New-Item $LocalPath -Type directory

# Files
$files = @(
    '40.png',
    '90.png',
    '115.png',
    '255.png',
    '533.png',
    'MarketplaceToolkit.ps1',
    'MarketplaceToolkit_parameters.ps1'
)

# Download files 
$files | foreach { Invoke-WebRequest ($uri + $_) -OutFile ($LocalPath + '\' + $_) }  
```

## Create a marketplace item

Start the Marketplace Toolkit in a PowerShell session.

``` PowerShell
cd c:\AzureStack_Marketplace
.\MarketplaceToolkit.ps1
```
From the dashboard you can select a solution, an extension or publish an existing .azpkg file. Select solution. 

- Step one of the wizard will gather the text details for the marketplace item and the icons that will show up in the marketplace. Sample icons can be found in c:\AzureStack_Marketplace. Clicking preview UI Experience gives an idea of what the marketplace item will look like in Azure Stack. Optionally you can select a parameter file to populate the fields. This is useful when you want to reuse values for multiple marketplace items. c:\AzureStack_Marketplace contains an example parameter file called MarketplaceToolkit_parameters.ps1.
- Step two of the wizard specifies the ARM template for the marketplace item and the path of the gallerypackager executable. Browse for the ARM template. The deployment wizard tree view lists the parameters from the selected ARM. All parameters are listed on the basics step of the deployment wizard. You can add a new step by typing in the name of the step and click add. The new step is added to the tree view. If you select a parameter in the tree view the Details blade allows you to move the parameter up, down or move it to a different step. These changes are reflected in the tree view. You can only remove a step if there are no parameters assigned to it. The basics step cannot be removed. When the customization is finalized you can create the .azpkg file by selecting create (ensure you have specified the path to the gallerypackager.exe). The .azpkg file is generated and stored in the mydocuments folder. You can now close the wizard if you do not have access to an Azure Stack environment as Service Administrator or your Azure Stack environment is using ADFS for authentication.
- Step three of the wizard provides an job to publish the marketplace item just created, to the marketplace. Specify the Azure AD credentials for your Azure Stack environment. The Admin API endpoint needs to be configured as FQDN (e.g.  adminmanagement.local.azurestack.external). Both the AzureAD username and the Admin API endpoint can be configured in the parameter file. When you click publish, a background job is started that will publish the .azpkg file to the Azure Stack Marketplace.

The VM extension on the dashboard is used to create a marketplace item for a VM Extension. This marketplace item will be visible in the Add extension tab on an existing VM in Azure Stack. The process to create an extension item is similar to a creating a solution, with the following exceptions:

- The category for an extension is not specified.
- The ARM template for an extension has two required parameters. vmName and Location. The UI will prevent you from selecting an ARM template if these two parameters are not present.
- You cannot specify additional deployment wizard steps. A VM extension consists of a single blade.

## Limitations

- The current version of the script only supports Azure AD for directly publishing an package to the marketplace. We are working on adding support for ADFS. When you are using ADFS you can still create the marketplace item package with the tool, but publishing the package to the marketplace is a manual process in PowerShell. 

## Improvements

The Marketplace Toolkit for Microsoft Azure Stack is based on PowerShell and the Windows Presentation Foundation. It is published in this public repository so you can make improvements to it by submitting a pull request.
