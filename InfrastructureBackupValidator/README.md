# Backup Validation
(To be updated further)

The purpose of this new backup validator tool is to remove the ASDK dependency and provide customers a standalone tool which they can use to validate Azure Stack Hub infrastructure backup content (offers, plans, quotas, user subscriptions, storage accounts).

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
$results = Validate-AszBackup -BackupStorePath \\server\backupshare -BackupStoreCredential $ShareCredential -BackupID $BackupID `
  -DecryptionCertPath $DecryptionCertPath -DecryptionCertPassword $DecryptionCertPasswdSecureString `
  -SQLServerInstanceName $SQLServerInstanceName -SQLCredential $SQLCredential -TempFolder "D:\validtool\testfolder"
```
