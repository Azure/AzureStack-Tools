# AzureStack Canary validator
Canary validator provides a breadth customer experience with the Azure Stack deployment. It tries to exercise the various customer usecases on the deployment. 

Canary can be invoked either as Service Administrator or Tenant Administrator.

# Execute Canary as Service Administrator
```powershell
$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "<Service Admin username>", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1 -ServiceAdminCredentials $ServiceAdminCreds -AADTenantID "<TenantID from Azure Active Directory>" -EnvironmentDomainFQDN "<Azure Stack deployment domain FQDN>" 
```

# Execute Canary as Tenant Administrator
```powershell
$TenantAdminCreds =  New-Object System.Management.Automation.PSCredential "<Service Admin username>", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1 -ServiceAdminCredentials $ServiceAdminCreds -AADTenantID "<TenantID from Azure Active Directory>" -EnvironmentDomainFQDN "<Azure Stack deployment domain FQDN>" -TenantAdminCredentials $TenantAdminCreds
```