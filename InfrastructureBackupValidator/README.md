# Backup Validation
(To be updated further)

The purpose of this new backup validator tool is to remove the ASDK dependency and provide customers a standalone tool which they can use to validate Azure Stack Hub infrastructure backup content (offers, plans, quotas, user subscriptions, storage accounts).

### Prerequisites
1. A local SQL server pre-installed (for example, SQL Express)

2. Available connection to the backup share

3. Download and install NuGet package "Microsoft.AzureStack.Fabric.Backup.IBCAdapterClient"

### Syntax
Validate-AszBackup

### Description
Get Azure Stack backup, reads cloud resources contained within the backup and lists those

### Parameters
| Parameter | Required | Description |
| :----: | :----: | :----: |
| BackupStorePath | Mandatory | URL path to the backup share |
| BackupStoreCredential | Mandatory | Credential object with permission to access the share |
| BackupID | Mandatory | Specific Backup to validate |
| DecryptionCertPath | Mandatory | Path to the decryption certificate |
| Decryptioncertpassword | Mandatory | Backup Certificate encryption password |
| SQLServerInstanceName | Optional | The local SQL server instance name, default to localhost\SQLEXPRESS |
| SQLCredential | Optional | Credential object with permission to access the SQL server, default will use Windows Authentication |
| TempFolder | Optional | Path to a local temp folder, default to $env:TEMP |

### Return value
A hashtable containing retrieved resources.

Keys: ComputeQuota, NetworkQuota, StorageQuota, StorageAccount, Offer, Subscription, Plan.

Values: Arrays of corresponding resources.

### Example
```powershell
# 1. Import module Unprotect-AzsBackup to do backup decryption
Import-module $path_to_the_tool\Unprotect-AzsBackup.psm1 -Force
# 2. Import IBC client cmdlets for getting backup chain
Import-Module -Name $path_to_the_installed_package\content\IBCAdapterClientPkg\Microsoft.AzureStack.Fabric.Backup.Common.Client.Cmdlets.psd1
# 3. Import module Validate-AszBackup
Import-module $path_to_the_tool\BackupValidationTool.psm1 -Force
# 4. Validate Backup
$results = Validate-AszBackup -BackupStorePath \\server\backupshare -BackupStoreCredential $ShareCredential -BackupID $BackupID `
  -DecryptionCertPath $DecryptionCertPath -DecryptionCertPassword $DecryptionCertPasswdSecureString `
  -SQLServerInstanceName $SQLServerInstanceName -SQLCredential $SQLCredential -TempFolder $TempFolder
```
