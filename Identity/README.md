# Azure Stack Identity

```powershell
Install-Module -Name 'AzureRm.Bootstrapper' -Scope CurrentUser
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
$directoryTenantId = Get-DirectoryTenantIdentifier -Authority "<DirectoryTenantUrl>"
```

An example of an authority for AAD is `https://login.windows.net/microsoft.onmicrosoft.com`
and for AD FS is `https://adfs.local.azurestack.external/adfs`.

## Creating a Service Principal in a disconnected (AD FS) topology

You can create a Service Principal by executing the following command after importing the Identity module

```powershell
$servicePrincipal = New-ADGraphServicePrincipal -DisplayName "<YourServicePrincipalName>" -AdminCredential $(Get-Credential) -Verbose
```

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

#### Pre-Requisite: Populate Azure Resource Manager with AzureStack Applications

- This step is a temporary workaround and needed only  for the TP3 (March) release of Azure Stack
- Execute this cmdlet as the **Azure Stack Service Administrator**, from the Console VM or the DVM replacing ```$azureStackDirectoryTenant``` with the directory tenant that Azure Stack is registered to and ```$guestDirectoryTenant``` with the directory that needs to be onboarded to Azure Stack.

__NOTE:__ This cmd needs to be run **only once** throughout the entire life cycle of that Azure Stack installation. You do **not** have to run this step every time you need to add a new directory.

```powershell
$adminARMEndpoint = "https://adminmanagement.<region>.<domain>"
$azureStackDirectoryTenant = "<homeDirectoryTenant>.onmicrosoft.com"
$guestDirectoryTenantToBeOnboarded = "<guestDirectoryTenant>.onmicrosoft.com"

Publish-AzureStackApplicationsToARM -AdminResourceManagerEndpoint $adminARMEndpoint `
    -DirectoryTenantName $azureStackDirectoryTenant
```

#### Step 1: Onboard the Guest Directory Tenant to Azure Stack

This step will let Azure Resource manager know that it can accept users and service principals from the guest directory tenant.

```powershell
$adminARMEndpoint = "https://adminmanagement.<region>.<domain>"
$azureStackDirectoryTenant = "<homeDirectoryTenant>.onmicrosoft.com" # this is the primary tenant Azure Stack is registered to
$guestDirectoryTenantToBeOnboarded = "<guestDirectoryTenant>.onmicrosoft.com" # this is the new tenant that needs to be onboarded to Azure Stack

Register-GuestDirectoryTenantToAzureStack -AdminResourceManagerEndpoint $adminARMEndpoint `
    -DirectoryTenantName $azureStackDirectoryTenant -GuestDirectoryTenantName $guestDirectoryTenantToBeOnboarded
```

With this step, the work of the Azure Stack administrator is done.

### Guest Directory Tenant Administrator

The following steps need to be completed by the **Directory Tenant Administrator** of the directory that needs to be onboarded to Azure Stack.

#### Step 2: Providing UI-based consent to Azure Stack Portal and ARM

- This is an important step. Open up a web browser, and go to `https://portal.<region>.<domain>/guest/signup/<guestDirectoryName>`. Note that this is the directory tenant that needs to be onboarded to Azure Stack. 
- This will take you to an AAD sign in page where you need to enter your credentials and click on 'Accept' on the consent screen.

#### Step 3: Registering Azure Stack applications with the Guest Directory

Execute the following cmdlet as the administrator of the directory that needs to be onboarded, replacing ```$guestDirectoryTenantName``` with your directory domain name

```powershell
$tenantARMEndpoint = "https://management.<region>.<domain>"
$guestDirectoryTenantName = "<guestDirectoryTenant>.onmicrosoft.com" # this is the new tenant that needs to be onboarded to Azure Stack

Register-AzureStackWithMyDirectoryTenant -TenantResourceManagerEndpoint $tenantARMEndpoint `
    -DirectoryTenantName $guestDirectoryTenantName -Verbose -Debug
```
