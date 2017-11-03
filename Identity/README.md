// Place your settings in this file to overwrite the default settings
{
    "workbench.colorTheme": "Abyss"
}nstall-Module -Name 'AzureRm.Bootstrapper' -Scope CurrentUser
Install-AzureRmProfile -profile '2017-03-09-profile' -Force -Scope CurrentUser
Install-Module -Name AzureStack -RequiredVersion 1.2.9 -Scope CurrentUser
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

## Creating a Service Principal in a disconnected (AD FS) topology

You can create a Service Principal by executing the following command after importing the Identity module

```powershell
$servicePrincipal = New-AzsAdGraphServicePrincipal -DisplayName "myapp12" -AdminCredential $(Get-Credential) -Verbose
```
Note: For a Multi node Azure Stack installation you also have to provide the ERCSMachineName parameter to send the request to the Privileged endpoint of your Azure Stack instance.

After the Service Principal is created, you should open your Azure Stack Portal to provide the appropriate level of RBAC to it. You can do this from the Access Control (IAM) tab of any resource. After the RBAC is given, you can login using the service principal as follows:

```powershell
Add-AzureRmAccount -EnvironmentName "<AzureStackEnvironmentName>" -ServicePrincipal -CertificateThumbprint $servicePrincipal.Thumbprint -ApplicationId $servicePrincipal.ApplicationId -TenantId $directoryTenantId
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
