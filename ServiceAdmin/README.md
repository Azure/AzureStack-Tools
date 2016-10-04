# Azure Stack Service Administration

Instructions below are relative to the .\ServiceAdmin folder of the [AzureStack-Tools repo](..\).

```powershell
Import-Module .\AzureStack.ServiceAdmin.psm1
```

## Create default plan and quota for tenants

```powershell
$serviceAdminPassword = ConvertTo-SecureString "<Azure Stack service admin password in AAD>" -AsPlainText -Force
$serviceAdmin = New-Object System.Management.Automation.PSCredential -ArgumentList "<myadmin>@<mydirectory>.onmicrosoft.com", $serviceAdminPassword

New-AzureStackTenantOfferAndQuotas -ServiceAdminCredential $serviceAdmin
```

Tenants can now see the "default" offer available to them and can subscribe to it. The offer includes unlimited compute, network, storage and key vault usage. 

