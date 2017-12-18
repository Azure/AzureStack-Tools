# Registration

The functions in this module allow you to perform the steps of registering your Azure Stack with your Azure subscription. Additional details can be found in the [documentation](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register).

These functions can be run on any machine that can invoke-command on the Privileged Endpoint. As a prerequisite, make sure that you have, and are an owner of, an Azure subscription and that you have installed the correct version of Azure Powershell as outlined here: [Install Powershell for Azure Stack](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install)

Once you have downloaded this module, open an elevated instance of Powershell ISE and run the functions contained:

To register with Azure and enable marketplace syndication and usage data reporting:
```powershell
Import-Module "<path to RegisterWithAzure.psm1>" -Force -Verbose
Set-AzsRegistration -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $privilegedEndpoint -BillingModel PayAsYouUse
```

To remove the existing registration resource and disable marketplace syndication and usage data reporting:
```powershell
Remove-AzsRegistration -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $privilegedEndpoint
```

To switch the existing registration to a new subscription or directory:
```powershell
# Remove the existing registration
Remove-AzsRegistration -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $privilegedEndpoint 
# Set the Azure Powershell context to the appropriate subscription
Set-AzureRmContext -SubscriptionId "<new subscription to register>"
# Register with the new subscription
Set-AzsRegistration -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $privilegedEndpoint -BillingModel PayAsYouUse
```

You must be logged into the appropriate Azure Powershell context that you wish to be used for registration of your Azure Stack environment

If you are registering in an internet-disconnected scenario you can run these functions:

```powershell
# Perform this function on the AzureStack Environment
Get-AzsRegistrationToken -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development -TokenOutputFilePath "C:\Temp\RegistrationToken.txt"
# Copy the registration token from the TokenOutputFilePath and pass it to this function on the Azure / Internet connected machine
Register-AzsEnvironment -RegistrationToken $yourRegistrationToken
# To UnRegister you must have either the registration token originally used or the registration resource name
UnRegister-AzsEnvironment -RegistrationName "AzureStack-cb1e5061-1d93-4836-81ea-3b74a1db857a"
```
