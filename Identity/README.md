# Azure Stack Identity

```powershell
Install-Module -Name 'AzureRm.Bootstrapper' -Scope CurrentUser
Install-AzureRmProfile -profile '2017-03-09-profile' -Force -Scope CurrentUser
Install-Module -Name AzureStack -RequiredVersion 1.2.9 -Scope CurrentUser
```
Then make sure the following modules are imported:

```powershell
Import-Module ..\Connect\AzureStack.Connect.psm1
Import-Module .\AzureStack.Identity.psm1
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
