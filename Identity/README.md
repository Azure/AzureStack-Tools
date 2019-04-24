// Place your settings in this file to overwrite the default settings
{
    "workbench.colorTheme": "Abyss"
}

As a prerequisite, make sure that you installed the correct PowerShell modules and versions:

For Azure stack 1901 or later

```powershell
Install-Module -Name AzureRM -RequiredVersion 2.4.0
Install-Module -Name AzureStack -RequiredVersion 1.7.0
```

For all other azure stack versions, please follow the instructions at https://aka.ms/azspsh for the needed azure powershell

```

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
granted to one or more identity applications. Granting these permissions requires Administrative access to the
home directory, and so it cannot be done automatically.

```powershell
$adminResourceManagerEndpoint = "https://adminmanagement.<region>.<domain>"
$homeDirectoryTenantName = "<homeDirectoryTenant>.onmicrosoft.com" # this is the primary tenant Azure Stack is registered to

Update-AzsHomeDirectoryTenant -AdminResourceManagerEndpoint $adminResourceManagerEndpoint `
    -DirectoryTenantName $homeDirectoryTenantName -Verbose
```

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