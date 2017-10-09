# Registration

The functions in this module allow you to perform the steps of registering your Azure Stack with your Azure subscription. Additional details can be found in the [documentation](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register).

These functions must be run from the Host machine. As a prerequisite, make sure that you have an Azure subscription and that you have installed the correct version of Azure Powershell as outlined here: [Install Powershell for Azure Stack](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install)

Once you have downloaded this module, open an elevated instance of Powershell ISE and run the functions contained:

To register with Azure and enable marketplace syndication and usage data reporting:
```powershell
Import-Module "<path to RegisterWithAzure.psm1>" -Force -Verbose
Add-AzsRegistration -CloudAdminCredential $cloudAdminCredential -AzureDirectoryTenantName $azureDirectoryTenantName  -AzureSubscriptionId $azureSubscriptionId -PrivilegedEndpoint $privilegedEndpoint -BillingModel PayAsYouUse
```

To switch the existing registration to a new subscription or directory:
```powershell
Set-AzsRegistrationSubscription -CloudAdminCredential $cloudAdminCredential -AzureDirectoryTenantName $azureDirectoryTenantName -NewAzureDirectoryTenantName $NewDirectoryTenantName -CurrentAzureSubscriptionId $azureSubscriptionId -NewAzureSubscriptionId $NewAzureSubscriptionId -PrivilegedEndpoint $privilegedEndpoint -BillingModel PayAsYouUse
```

To remove the existing registration resource and disable marketplace syndication and usage data reporting:
```powershell
Remove-AzsRegistration -CloudAdminCredential $cloudAdminCredential -AzureDirectoryTenantName $azureDirectoryTenantName  -AzureSubscriptionId $azureSubscriptionId -PrivilegedEndpoint $privilegedEndpoint -BillingModel PayAsYouUse
```

If you are not logged into an Azure account during your powershell session you will be prompted for your Azure credentials before registration completes.
