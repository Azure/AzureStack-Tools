# Azure Stack Identity


```powershell
Install-Module -Name AzureRM -RequiredVersion 1.2.8 -Scope CurrentUser
Install-Module -Name AzureStack
```
Then make sure the following modules are imported:

```powershell
Import-Module ..\Connect\AzureStack.Connect.psm1
Import-Module ..\Identity\AzureStack.Identity.psm1
```

You can create a Service Principal by executing the following command after importing the Identity Module

```powershell
$servicePrincipal = New-ADGraphServicePrincipal -DisplayName "myServicePrincipal" -AdminCredential $(Get-Credential) -Verbose
```

After the Service Principal is created, you should open your Azure Stack Portal to provide the appropriate level of RBAC to it. You can do this from the Access Control (IAM) tab of any resource. After the RBAC is given, you can login using the service principal as follows:

```powershell
Add-AzureRmAccount -EnvironmentName AzureStack-Tenant -ServicePrincipal -CertificateThumbprint $servicePrincipal.Thumbprint -ApplicationId $servicePrincipal.ApplicationId -TenantId "<yourTenantId>"
```