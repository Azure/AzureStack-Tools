// Place your settings in this file to overwrite the default settings
{
    "workbench.colorTheme": "Abyss"
}

As a prerequisite, make sure that you installed the correct PowerShell modules and versions:

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

Then make sure the following modules are imported:

```powershell
Import-Module ..\Connect\AzureStack.Connect.psm1
Import-Module ..\Identity\AzureStack.Identity.psm1
```

## Getting the directory tenant identifier from the Identity System

This function is used to get the Directory Tenant Guid. This method works for both AAD and AD FS.

```powershell
$directoryTenantId = Get-AzsDirectoryTenantIdentifier -Authority "<DirectoryTenantUrl>"
```

An example of an authority for AAD is `https://login.windows.net/microsoft.onmicrosoft.com`
and for AD FS is `https://adfs.local.azurestack.external/adfs`.

## Updating the Azure Stack AAD Home Directory (after installing updates or new Resource Providers)

After installing updates or hotfixes to Azure Stack, new features may be introduced which require new permissions to be
granted to one or more identity applications. Granting these permissions requires administrative access to the
home directory, so it cannot be done automatically.

### Install PowerShell for Azure Stack

Use the latest PowerShell module for Azure Stack to register with Azure.
If the latest version is not already installed, see [install PowerShell for Azure Stack](https://docs.microsoft.com/azure-stack/operator/azure-stack-powershell-install).

### Download Azure Stack tools

The Azure Stack tools GitHub repository contains PowerShell modules that support Azure Stack functionality, including updating permissions on Azure AD. During the registration process, you must import and use the **AzureStack.Connect** and **AzureStack.Identity** PowerShell modules, found in the Azure Stack tools repository, to update the permissions on Azure AD for the Azure stack stamp.

To ensure that you are using the latest version, delete any existing versions of the Azure Stack tools, then [download the latest version from GitHub](https://docs.microsoft.com/azure-stack/operator/azure-stack-powershell-download) before proceeding.

### Updating Azure AD tenant permissions

You should now be able to update the permissions which should clear the alert. Run the following commands from the **Azurestack-tools-master/identity** folder:

```powershell
Import-Module ..\Connect\AzureStack.Connect.psm1
Import-Module ..\Identity\AzureStack.Identity.psm1

$adminResourceManagerEndpoint = "https://adminmanagement.<region>.<domain>"

# This is the primary tenant Azure Stack is registered to:
$homeDirectoryTenantName = "<homeDirectoryTenant>.onmicrosoft.com"

Update-AzsHomeDirectoryTenant -AdminResourceManagerEndpoint $adminResourceManagerEndpoint `
   -DirectoryTenantName $homeDirectoryTenantName -Verbose
```

The script prompts you for administrative credentials on the Azure AD tenant, and takes several minutes to run. The alert should clear after you have run the cmdlet.

## Enabling AAD Multi-Tenancy in Azure Stack

Allowing users and service principals from multiple AAD directory tenants to sign in and create resources on Azure Stack.
There are two personas involved in implementing this scenario.

1. The Administrator of the Azure Stack installation
1. The Directory Tenant Administrator of the directory that needs to be onboarded to Azure Stack

### Azure Stack Administrator

#### Step 1: Onboard the Guest Directory Tenant to Azure Stack

This step will let Azure Resource manager know that it can accept users and service principals from the guest directory tenant.

```powershell
$adminARMEndpoint = "https://adminmanagement.<region>.<domain>"
$azureStackDirectoryTenant = "<homeDirectoryTenant>.onmicrosoft.com" # this is the primary tenant Azure Stack is registered to
$guestDirectoryTenantToBeOnboarded = "<guestDirectoryTenant>.onmicrosoft.com" # this is the new tenant that needs to be onboarded to Azure Stack
$location = "local"

Register-AzsGuestDirectoryTenant -AdminResourceManagerEndpoint $adminARMEndpoint `
    -DirectoryTenantName $azureStackDirectoryTenant `
    -GuestDirectoryTenantName $guestDirectoryTenantToBeOnboarded `
    -ResourceGroupName "system.local" `
    -Location $location
```

With this step, the work of the Azure Stack administrator is done.

### Guest Directory Tenant Administrator

#### Step 2: Registering Azure Stack applications with the Guest Directory

Execute the following cmdlet as the administrator of the directory that needs to be onboarded, replacing ```$guestDirectoryTenantName``` with your directory domain name

```powershell
$tenantARMEndpoint = "https://management.<region>.<domain>"
$guestDirectoryTenantName = "<guestDirectoryTenant>.onmicrosoft.com" # this is the new tenant that needs to be onboarded to Azure Stack

Register-AzsWithMyDirectoryTenant -TenantResourceManagerEndpoint $tenantARMEndpoint `
    -DirectoryTenantName $guestDirectoryTenantName
```

## Retrieve Azure Stack Identity Health Report 

Execute the following cmdlet as the Azure Stack administrator.

```powershell

$AdminResourceManagerEndpoint = "https://adminmanagement.<region>.<domain>"
$DirectoryName = "<homeDirectoryTenant>.onmicrosoft.com"
$healthReport = Get-AzsHealthReport -AdminResourceManagerEndpoint $AdminResourceManagerEndpoint -DirectoryTenantName $DirectoryName
Write-Host "Healthy directories: "
$healthReport.directoryTenants | Where status -EQ 'Healthy' | Select -Property tenantName,tenantId,status | ft


Write-Host "Unhealthy directories: "
$healthReport.directoryTenants | Where status -NE 'Healthy' | Select -Property tenantName,tenantId,status | ft
```
