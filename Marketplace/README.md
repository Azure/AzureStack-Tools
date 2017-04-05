# Azure Stack Marketplace Administration
Instructions below are relative to the .\Marketplace folder of the [AzureStack-Tools repo](..).

Make sure you have the following module prerequisites installed:

```powershell
Install-Module -Name 'AzureRm.Bootstrapper' -Scope CurrentUser
Install-AzureRmProfile -profile '2017-03-09-profile' -Force -Scope CurrentUser
Install-Module -Name AzureStack -RequiredVersion 1.2.9 -Scope CurrentUser
```
The scripts require that you obtain the GUID value of your Directory Tenant. If you know the non-GUID form of the Azure Active Directory Tenant used to deploy your Azure Stack instance, you can retrieve the GUID value with the following:

```powershell
$aadTenant = Get-AADTenantGUID -AADTenantName "<myaadtenant>.onmicrosoft.com" 
```

Otherwise, it can be retrieved directly from your Azure Stack deployment. This method can also be used for AD FS. First, add your host to the list of TrustedHosts:
```powershell
Set-Item wsman:\localhost\Client\TrustedHosts -Value "<Azure Stack host address>" -Concatenate
```
Then execute the following:
```powershell
$Password = ConvertTo-SecureString "<Admin password provided when deploying Azure Stack>" -AsPlainText -Force
$aadTenant = Get-AzureStackAadTenant  -HostComputer <Host IP Address> -Password $Password
```

# Samples to add / get / remove gallery items from local directory

$azureStackCredentials= New-Object System.Management.Automation.PSCredential("administrator.onmicrosoft.com", (ConvertTo-SecureString "somepassword" -AsPlainText -Force))

$gipath = "C:\Temp\Microsoft.MySqlHostingServer.0.1.0.azpkg"
$giName = 'Microsoft.MySqlHostingServer.0.1.0'
$armEndpoint = "https://adminmanagement.local.azurestack.external"
 
Add-GalleryItem -galleryItemLocalPath $gipath -tenantID $aadTenant -location 'local' -azureStackCredentials $azureStackCredentials -armEndpoint $ArmEndpoint
Get-GalleryItem -GalleryItemName $giName -tenantID $aadTenant
Remove-GalleryItem -GalleryItemName $giName -tenantID $aadTenant 

# Samples to add / get / remove provider gallery items from local directory

Add-ProviderGalleryItem -galleryItemLocalPath $gipath -tenantID $aadTenant -location 'local' -azureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint -providerNameSpace 'Microsoft.MySqlAdapter.Admin' -providerLocation 'local'
Get-ProviderGalleryItem -galleryItemId $giName -tenantID $aadTenant -azureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint
Remove-ProviderGalleryItem -galleryItemId $giName -tenantID $aadTenant -azureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint