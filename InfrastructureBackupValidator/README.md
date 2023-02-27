# Backup Validation

The purpose of this new backup validator tool is to remove the ASDK dependency and provide customers a standalone tool which they can use to validate Azure Stack Hub infrastructure backup content (offers, plans, quotas, user subscriptions).

### Prerequisites
1. A local SQL server pre-installed (for example, SQL Express)

2. Available connection to the backup share

### Syntax
Validate-AszBackup

### Description
Gets Azure Stack backup, reads cloud resources contained within the backup and lists those

### Parameters
| Parameter | Required | Description |
| :----: | :----: | :----: |
| BackupStorePath | Mandatory | URL path to the backup share |
| BackupStoreCredential | Mandatory | Credential object with permission to access the share |
| BackupID | Mandatory | Specific Backup to validate |
| DecryptionCertPath | Mandatory | Path to the decryption certificate |
| Decryptioncertpassword | Mandatory | Backup Certificate encryption password |
| TempFolder | Mandatory | Path to a local temp folder |
| SQLServerInstanceName | Optional | The local SQL server instance name, default to localhost\SQLEXPRESS |
| SQLCredential | Optional | Credential object with permission to access the SQL server, default will use Windows Authentication |

### Return value
A hashtable containing retrieved resources.

Keys: ComputeQuota, NetworkQuota, StorageQuota, Offer, Subscription, Plan.

Values: Arrays of corresponding resources.

### Example
```powershell
# Import module BackupValidationTool
Import-module $path_to_the_tool\BackupValidationTool.psd1 -Force
# Credentials required to access the share where Azure Stack Hub is storing the Backups
$ShareCredential = Get-Credential
# Backup ID that you want to validate. You can get the Id from the list of Backups in the Portal
$backupID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx"
# This is the path where the certificate for the Backups have been exported as .pfx file.
$DecryptionCertPath = "C:\temp\ExportedBackupCert.pfx" 
# Name of the SQL Sever Instance. If using default Instance Name “localhost\SQLEXPRESS” then this parameter can be skipped.
$SQLServerInstanceName = "Computer1"
# this is the password asssigned to the certificate used for backups after exporting it as .pfx with the public keys. It is not the thumbrpint of the certificate.
$Encrypted = Get-Credential
# This is the credential with permission to access the SQL server. if using Windows Authentication, this parameter can be skipped.
$SQLCredential = Get-Credential
# This is the temp folder used to validate the Backup.
$tempfolder = "c:\tempbackup"
# Validate Backup: A hashtable containing retrieved resources will be returned; An HTML report "BackupValidationReport.htm" will be generated under $tempfolder.
$results = $results = Validate-AszBackup -BackupStorePath \\10.0.0.2\ashbackup -BackupStoreCredential $ShareCredential `
	-BackupID $BackupID -DecryptionCertPath $DecryptionCertPath -DecryptionCertPassword $Encrypted.Password `
	-SQLServerInstanceName $SQLServerInstanceName -SQLCredential $SQLCredential -TempFolder $tempfolder
```
