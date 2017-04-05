# Azure Stack Service Administration

Instructions below are relative to the .\ServiceAdmin folder of the [AzureStack-Tools repo](..\).

Make sure you have the following module prerequisites installed:

```powershell
Install-Module -Name 'AzureRm.Bootstrapper' -Scope CurrentUser
Install-AzureRmProfile -profile '2017-03-09-profile' -Force -Scope CurrentUser
Install-Module -Name AzureStack -RequiredVersion 1.2.9 -Scope CurrentUser
```
Then make sure the following modules are imported:

```powershell
Import-Module ..\Connect\AzureStack.Connect.psm1
Import-Module .\AzureStack.ServiceAdmin.psm1
```

Creating quotas/offers/plans requires that you obtain the GUID value of your Directory Tenant. If you know the non-GUID form of the Azure Active Directory Tenant used to deploy your Azure Stack instance, you can retrieve the GUID value with the following:

```powershell
$aadTenant = Get-AADTenantGUID -AADTenantName "<myaadtenant>.onmicrosoft.com" 
```

Otherwise, it can be retrieved directly from your Azure Stack deployment. First, add your host to the list of TrustedHosts:
```powershell
Set-Item wsman:\localhost\Client\TrustedHosts -Value "<Azure Stack host address>" -Concatenate
```
Then execute the following:
```powershell
$Password = ConvertTo-SecureString "<Admin password provided when deploying Azure Stack>" -AsPlainText -Force
$AadTenant = Get-AzureStackAadTenant  -HostComputer <Host IP Address> -Password $Password
```

## Create default plan and quota for tenants

You will need to reference your Azure Stack Administrator environment. To create an administrator environment use the below. The ARM endpoint below is the administrator default for a one-node environment.

```powershell
Add-AzureStackAzureRmEnvironment -Name "AzureStackAdmin" -ArmEndpoint "https://adminmanagement.local.azurestack.external" 
```

```powershell
New-AzSTenantOfferAndQuotas -tenantID $aadTenant -EnvironmentName "AzureStackAdmin"
```

Tenants can now see the "default" offer available to them and can subscribe to it. The offer includes unlimited compute, network, storage and key vault usage. 

