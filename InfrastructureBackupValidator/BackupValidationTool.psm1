#requires -Version 5.1
#requires -RunAsAdministrator

### -----------------------------------------
### Strings
### -----------------------------------------
Data Strings
{
# culture="en-US"
ConvertFrom-StringData @'
    # message
    MsgComputeQuota = BackupType: ComputeQuota
    MsgNetworkQuota = BackupType: NetworkQuota
    MsgStorageQuota = BackupType: StorageQuota
    MsgOffer = BackupType: Offer
    MsgSubscription = BackupType: UserSubscription
    MsgPlan = BackupType: Plan

    # progress
    ProgressConnectBackupStore = Connecting to the backup store with provided credential
    ProgressConnectSqlServerDefault = Connecting to the SQL server '{0}' with Windows Authentication
    ProgressConnectSqlServerProvided = Connecting to the SQL server '{0}' with provided credential
    ProgressCreateTmpFolder = Creating a temporary folder {0} under {1}
    ProgressGetBackupSnapshots = Getting required backup snapshots of BackupID {0}
    ProgressDecryptSnapshot = Starting to decrypt snapshot {0}
    ProgressCompletedDecryptionJobs = Decryption took {0} to complete
    ProgressRestoreSubscriptionDb = Restoring subscription DB with {0}

    # warning
    WarningDecryptedBackupDataNotFound = Decrypted backup data for {0}: '{1}' is not found, skip listing those resources

    # error
    ErrorFailToConnectBackupStore = Failed to connect to the backup store '{0}' with provided credential. Exception: {1}
    ErrorFailToConnectSqlServerDefault = Failed to connect to the SQL server '{0}' with Windows Authentication. Exception: {1}
    ErrorFailToConnectSqlServerProvided = Failed to connect to the SQL server '{0}' with provided credential. Exception: {1}
    ErrorFailToFindBackupSnapshots = Failed to find backup snapshots with BackupID {0}
    ErrorFindMoreThanOneSnapshot = Found more than one snapshots for repository: {0}
    ErrorFailToFindBackupChain = Failed to find backup chain for {0}
    ErrorFailToDecryptSnapshot = Backup decryption failed for snapshot: '{0}'. Exception: {1}
    ErrorFailToFindSqlBackupFile = Failed to find SQL backup file: '{0}'. Cannot restore the database.
    ErrorDatabaseMissingItem = Failed to retrieve {0} as {1} with [{2}] value '{3}' is missing in the database.

    # html
    HtmlTitle = Backup Validation Report
    HtmlCrpQuotaHeader = BackupType: ComputeQuota
    HtmlNrpQuotaHeader = BackupType: NetworkQuota
    HtmlSrpQuotaHeader = BackupType: StorageQuota
    HtmlOfferHeader = BackupType: Offer
    HtmlSubscriptionHeader = BackupType: Subscription
    HtmlPlanHeader = BackupType: Plan
    HtmlResourceCount = Count: 

'@
}

# Import localized strings
Import-LocalizedData Strings -FileName BackupValidationTool.Strings.psd1 -ErrorAction SilentlyContinue

### -----------------------------------------
### Constants
### -----------------------------------------
$BackupStoreDriveName = "BackupStore"
$SubscriptionSqlDbName = "Microsoft.AzureStack.Subscriptions"
$SubTmpFolderName = "BackupValidationTmp"
$OutputReportFile = "BackupValidationReport.htm"

$BackupRepoNames = @{
    ComputeQuota = "CRP;Microsoft.Compute.Admin;-;Quota"
    NetworkQuota = "NRP;Microsoft.Network.Admin;-;Quota"
    Storage = "SRP;SRP;-;-"
    Subscription = "WAS;WasService;-;Microsoft.AzureStack.Subscriptions"
}

$JsonFileNames = @{
    ComputeQuota = "CRP-Microsoft.Compute.Admin.json"
    NetworkQuota = "NRP-Microsoft.Network.Admin.json"
    StorageQuota = "SRP-Microsoft.Storage.Admin.json"
    StorageAccount = "Account.json"
}

$StorageBackupSubRepoNames = @{
    Quota = "SRP;Microsoft.Storage.Admin;-;Quota"
    StorageAccount = "SRP;StorageAccount;-;SRP"
}

$SubscriptionSqlBackupFileNames = @{
    BackupFile = "Microsoft.AzureStack.Subscriptions.bak"
    LogFile = "Microsoft.AzureStack.Subscriptions.log"
}

function Decrypt-BackupSnapshot
{
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $SnapshotFullName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $TargetDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        $BackupStoreCredential,

        [Parameter(Mandatory = $true)]
        [ValidateScript({$_ | Test-Path -PathType Leaf})]
        [String]
        $DecryptionCertPath,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [SecureString]
        $DecryptionCertPassword
    )

    $ErrorActionPreference = "Stop"

    try
    {
        $dest = Join-Path $TargetDirectory ($SnapshotFullName -Split "\\")[-2] # sub directory with repo name
        $dest = Join-Path $dest ($SnapshotFullName -Split "\\")[-1] # sub-sub directory with snapshot name
        Write-Verbose ($Strings.ProgressDecryptSnapshot -f $SnapshotFullName) -Verbose
        if (!(Test-Path $dest))
        {
            $null = New-Item $dest -ItemType Directory -Force | Out-Null
        }
        else
        {
            $null = Remove-Item "$dest\*" -Recurse -Force | Out-Null
        }

        $null = Unprotect-AzsBackup `
            -BackupSnapshotZip $SnapshotFullName `
            -Destination $dest `
            -Certificate $DecryptionCertPath `
            -CertificatePassphrase $DecryptionCertPassword `
            -ShareCrendential $BackupStoreCredential | Out-Null
    }
    catch
    {
        throw ($Strings.ErrorFailToDecryptSnapshot -f $SnapshotFullName, $_)
    }
}

function ConvertDictionariesToCustomObjects
{
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [HashTable]
        $Dictionaries
    )

    $ErrorActionPreference = "Stop"

    return @($Dictionaries.Values.GetEnumerator()) | ForEach-Object {
        $props = @{}
        $_.GetEnumerator() | ForEach-Object {
            $props[$_.Key] = $_.Value
        }
    
        [PSCustomObject]$props
    }
}

<#
 .Synopsis
  List the ARM resources extracted from the backup.

 .Description
  - Get the backup chain according to the BackupID
  - Decrypt the required snapshots to local
  - Restore the backup into SQL server
  - Retrieve ARM resources

 .Example
  $resources = Validate-AszBackup -BackupStorePath $backupStorePath -BackupStoreCredential $backupStoreCredential -BackupID $backupID -DecryptionCertPath $decryptionCertPath -DecryptionCertPassword $decryptionCertPassword -TempFolder $tempFolder
  $resources = Validate-AszBackup -BackupStorePath $backupStorePath -BackupStoreCredential $backupStoreCredential -BackupID $backupID -DecryptionCertPath $decryptionCertPath -DecryptionCertPassword $decryptionCertPassword -SQLServerInstanceName $sqlServerInstanceName -SQLCredential $sqlCredential -TempFolder $tempFolder
#>
function Validate-AszBackup
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({$_ | Test-Path -IsValid})]
        [String]
        $BackupStorePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        $BackupStoreCredential,

        [Parameter(Mandatory = $true)]
        [ValidateScript({[System.Guid]::TryParse($_, $([System.Management.Automation.PSReference][System.Guid]::Empty))})]
        [String]
        $BackupID,

        [Parameter(Mandatory = $true)]
        [ValidateScript({$_ | Test-Path -PathType Leaf})]
        [String]
        $DecryptionCertPath,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [SecureString]
        $DecryptionCertPassword,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]
        $SQLServerInstanceName = "localhost\SQLEXPRESS", # Use default SQL Express server instance

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        $SQLCredential,

        [Parameter(Mandatory = $true)]
        [ValidateScript({$_ | Test-Path -PathType Container})]
        [String]
        $TempFolder
    )

    $ErrorActionPreference = "Stop"

    # STEP 1: Connect to the backup store with provided credential
    Write-Verbose $Strings.ProgressConnectBackupStore -Verbose
    try
    {
        $null = New-PSDrive -Name $BackupStoreDriveName -Root $BackupStorePath -Credential $BackupStoreCredential -PSProvider FileSystem | Out-Null
    }
    catch
    {
        throw ($Strings.ErrorFailToConnectBackupStore -f $BackupStorePath, $_)
    }

    Install-Module -Name SqlServer -AllowClobber
    Import-Module SqlServer -DisableNameChecking
    $sqlCommonParams = @{
        ServerInstance = $SQLServerInstanceName
    }

    $sqlRestoreCommonParams = @{
        ServerInstance = $SQLServerInstanceName
    }

    if (!$SQLCredential)
    {
        # STEP 2: Connect to the SQL server with Windows Authentication
        Write-Verbose ($Strings.ProgressConnectSqlServerDefault -f $SQLServerInstanceName) -Verbose
        try
        {
            $sqlInstance = Get-SqlInstance -ServerInstance $SQLServerInstanceName
        }
        catch
        {
            throw ($Strings.ErrorFailToConnectSqlServerDefault -f $SQLServerInstanceName, $_)
        }
    }
    else
    {
        # STEP 2: Connect to the SQL server with provided credential
        Write-Verbose ($Strings.ProgressConnectSqlServerProvided -f $SQLServerInstanceName) -Verbose
        try
        {
            $sqlInstance = Get-SqlInstance -ServerInstance $SQLServerInstanceName -Credential $SQLCredential
            $sqlRestoreCommonParams.SQLCredential = $SQLCredential
	        $sqlCommonParams.Credential = $SQLCredential
        }
        catch
        {
            throw ($Strings.ErrorFailToConnectSqlServerProvided -f $SQLServerInstanceName, $_)
        }
    }

    # STEP 3: Create a tmp folder
    Write-Verbose ($Strings.ProgressCreateTmpFolder -f $SubTmpFolderName, $TempFolder) -Verbose
    $tmpDir = Join-Path $TempFolder $SubTmpFolderName
    $null = Remove-Item $tmpDir -Force -Recurse -ErrorAction Ignore | Out-Null
    $null = New-Item -Type Directory $tmpDir -Force | Out-Null
    
    # STEP 4: Get the list of backup files according to the BackupID
    Write-Verbose ($Strings.ProgressGetBackupSnapshots -f $BackupID) -Verbose
    $backupRoot = Join-Path $BackupStorePath "MASBackup\progressivebackup"
    $backupFiles = (Get-ChildItem -Path $backupRoot -Recurse | ? { $_.Name -match $BackupID -and $_.Name -match ".zip" }).FullName
    $backupRepos = @($BackupRepoNames.Values.GetEnumerator())
    if ($null -eq $backupFiles -or $backupFiles.Count -eq 0)
    {
        throw ($Strings.ErrorFailToFindBackupSnapshots -f $BackupID)
    }

    # It's progressive backup for Subscription, get the backup chain
    # A backup file FullName is like: "$BackupStorePath\MASBackup\progressivebackup\1.2209.0.53\NRP;Microsoft.Network.Admin;-;Quota\202301171931_fa396b1d-1814-4c75-9ddc-fef71cf2ecd1_Full_C.zip"
    # ($_ -Split "\")[-1] would be "202301171931_fa396b1d-1814-4c75-9ddc-fef71cf2ecd1_Full_C.zip" containing the backup ID.
    # ($_ -Split "\")[-2] would be "NRP;Microsoft.Network.Admin;-;Quota" which is the name of the repo.
    # ($_ -Split "\")[-3] would be "1.2209.0.53" which is the name of the backup store, also the stamp version.
    $backupStoreName = ($backupFiles[0] -Split "\\")[-3]
    $backupFiles = @()
    $subscriptionBackups = @()
    foreach ($backupRepo in $backupRepos)
    {
        $backupChain = Get-RepositoryBackupChain -ExternalShare $BackupStorePath `
            -ExternalShareCredential $BackupStoreCredential -ProgressiveBackupStoreName $backupStoreName `
            -RepositoryName $backupRepo -BackupId $BackupID
        $backups = @()
        foreach ($backup in $backupChain)
        {
            $backups += $backup.DataFileName
            if ($backup.DataFileName -match $BackupID)
            {
                break
            }
        }

        if (!$backups)
        {
            throw ($Strings.ErrorFailToFindBackupChain -f ($backupRepo))
        }

        if ($backupRepo -ne $BackupRepoNames.Subscription -and $backups.Count -gt 1)
        {
            throw ($Strings.ErrorFindMoreThanOneSnapshot -f ($backupRepo))
        }

        if ($backupRepo -eq $BackupRepoNames.Subscription)
        {
            $subscriptionBackups = $backups
        }

        $backupFiles += $backups
    }
    

    # STEP 5: Decrypt all required snapshots to the tmpDir
    $start = Get-Date
    foreach ($backupFile in $backupFiles)
    {
        Decrypt-BackupSnapshot -SnapshotFullName $backupFile `
            -TargetDirectory $tmpDir -BackupStoreCredential $BackupStoreCredential `
            -DecryptionCertPath $DecryptionCertPath -DecryptionCertPassword $DecryptionCertPassword
    }

    $end = Get-Date
    $duration = $end - $start
    Write-Verbose ($Strings.ProgressCompletedDecryptionJobs -f $duration) -Verbose

    # STEP 6: Retrieve CRP quotas
    $decryptedFolder = Join-Path $tmpDir $BackupRepoNames.ComputeQuota
    $crpQuotaJsonFile = (Get-ChildItem -Path $decryptedFolder -Recurse | ? { $_.Name -match $JsonFileNames.ComputeQuota }).FullName
    if (!$crpQuotaJsonFile)
    {
        Write-Warning ($Strings.WarningDecryptedBackupDataNotFound -f $BackupRepoNames.ComputeQuota, $JsonFileNames.ComputeQuota)
    }
    else
    {
        $crpQuotas = Get-Content $crpQuotaJsonFile | Out-String | ConvertFrom-Json
        Write-Verbose $Strings.MsgComputeQuota -Verbose
        Write-Host $($crpQuotas | Out-String)
    }

    # STEP 7: Retrieve NRP quotas
    $decryptedFolder = Join-Path $tmpDir $BackupRepoNames.NetworkQuota
    $nrpQuotaJsonFile = (Get-ChildItem -Path $decryptedFolder -Recurse | ? { $_.Name -match $JsonFileNames.NetworkQuota }).FullName
    if (!$nrpQuotaJsonFile)
    {
        Write-Warning ($Strings.WarningDecryptedBackupDataNotFound -f $BackupRepoNames.NetworkQuota, $JsonFileNames.NetworkQuota)
    }
    else
    {
        $nrpQuotas = Get-Content $nrpQuotaJsonFile | Out-String | ConvertFrom-Json
        Write-Verbose $Strings.MsgNetworkQuota -Verbose
        Write-Host $($nrpQuotas | Out-String)
    }

    # STEP 8: Retrieve SRP quotas
    $decryptedFolder = Join-Path $tmpDir $BackupRepoNames.Storage
    $srpQuotaFolder = (Get-ChildItem -Path $decryptedFolder -Recurse | ? { $_.Name -match $StorageBackupSubRepoNames.Quota }).FullName
    if (!$srpQuotaFolder)
    {
        Write-Warning ($Strings.WarningDecryptedBackupDataNotFound -f $BackupRepoNames.Storage, $StorageBackupSubRepoNames.Quota)
    }
    else
    {
        $srpZipFile = (Get-ChildItem -Path $srpQuotaFolder | ? { $_.Name -match ".zip" }).FullName
        if (!$srpZipFile)
        {
            Write-Warning ($Strings.WarningDecryptedBackupDataNotFound -f $StorageBackupSubRepoNames.Quota, "snapshot zip file")
        }
        else
        {
            Expand-Archive -Path $srpZipFile -DestinationPath $srpQuotaFolder
            $srpQuotaJsonFile = (Get-ChildItem -Path $srpQuotaFolder -Recurse | ? { $_.Name -match $JsonFileNames.StorageQuota }).FullName
            if (!$srpQuotaJsonFile)
            {
                Write-Warning ($Strings.WarningDecryptedBackupDataNotFound -f $StorageBackupSubRepoNames.Quota, $JsonFileNames.StorageQuota)
            }
            else
            {
                $srpQuotas = Get-Content $srpQuotaJsonFile | Out-String | ConvertFrom-Json
                Write-Verbose $Strings.MsgStorageQuota -Verbose
                Write-Host $($srpQuotas | Out-String)
            }
        }
    }

    try
    {
        # STEP 9: Restore subscription DB
        foreach ($snapshot in $subscriptionBackups)
        {
            $isFirstSnapshot = $snapshot -eq $subscriptionBackups[0]
            $hasMoreSnapshotsToRestore = $snapshot -ne $subscriptionBackups[$subscriptionBackups.Count -1]
            $decryptedFolder = Join-Path $tmpDir $BackupRepoNames.Subscription
            $decryptedFolder = Join-Path $decryptedFolder ($snapshot -Split "\\")[-1]
            Write-Verbose ($Strings.ProgressRestoreSubscriptionDb -f $decryptedFolder) -Verbose
            $subBackupFile = Join-Path $decryptedFolder $SubscriptionSqlBackupFileNames.BackupFile
            $subLogFile = Join-Path $decryptedFolder $SubscriptionSqlBackupFileNames.LogFile
            if (!(Test-Path -Path $subBackupFile -PathType Leaf))
            {
                throw ($Strings.ErrorFailToFindSqlBackupFile -f $subBackupFile)
            }
            elseif (!(Test-Path -Path $subLogFile -PathType Leaf))
            {
                throw ($Strings.ErrorFailToFindSqlBackupFile -f $subLogFile)
            }

            Restore-SqlDatabase -Database $SubscriptionSqlDbName -BackupFile $subBackupFile `
                -AutoRelocateFile -NoRecovery -ReplaceDatabase:$isFirstSnapshot @sqlRestoreCommonParams
            Restore-SqlDatabase -Database $SubscriptionSqlDbName -BackupFile $subLogFile `
                -RestoreAction Log -AutoRelocateFile -NoRecovery:$hasMoreSnapshotsToRestore @sqlRestoreCommonParams
        }

        # STEP 10: Retrieve offers
        $SQLCmd = "SELECT [Id],[SubscriptionId] FROM [$SubscriptionSqlDbName].[subscriptions.internal].[ResellerSubscriptions]"
        $resellerSubTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $resellerSubcriptions = @{}
        if ($resellerSubTable.Tables.Count -gt 0 -and $null -ne $resellerSubTable.Tables[0].Rows)
        {
            $resellerSubTable.Tables[0].Rows | % { $resellerSubcriptions.Add($_.Id.ToString(), $_.SubscriptionId.ToString()) }
        }

        $SQLCmd = "SELECT [ProvisioningState],[ProvisioningStateName] FROM [$SubscriptionSqlDbName].[subscriptions.internal].[ProvisioningStates]"
        $provisionStateTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $provisioningStates = @{}
        if ($provisionStateTable.Tables.Count -gt 0 -and $null -ne $provisionStateTable.Tables[0].Rows)
        {
            $provisionStateTable.Tables[0].Rows | % { $provisioningStates.Add($_.ProvisioningState.ToString(), $_.ProvisioningStateName.ToString()) }
        }

        $SQLCmd = "SELECT [ResourceManagerType],[ResourceManagerTypeName] FROM [$SubscriptionSqlDbName].[subscriptions.internal].[ResourceManagerTypes]"
        $resourceMgrTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $resourceManagerTypes = @{}
        if ($resourceMgrTable.Tables.Count -gt 0 -and $null -ne $resourceMgrTable.Tables[0].Rows)
        {
            $resourceMgrTable.Tables[0].Rows | % { $resourceManagerTypes.Add($_.ResourceManagerType.ToString(), $_.ResourceManagerTypeName.ToString()) }
        }

        $SQLCmd = "SELECT [Id],[ResellerSubscriptionId],[ResourceGroupName],[ResourceLocation],[Tags],[Name],[DisplayName],[Description],[MaxSubscriptionsPerAccount]
            ,[ProvisioningState],[RoutingResourceManagerType] FROM [$SubscriptionSqlDbName].[subscriptions.internal].[Offers]"
        $offerTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $offers = @{}
        if ($offerTable.Tables.Count -gt 0 -and $null -ne $offerTable.Tables[0].Rows)
        {
            $offerColumnNames = $offerTable.Tables[0].Columns.ColumnName
            foreach ($row in $offerTable.Tables[0].Rows)
            {
                $offerId = ""
                $offer = [ordered] @{}
                foreach ($column in $offerColumnNames)
                {
                    $value = $row[$column].ToString()
                    if ($column -eq "ResellerSubscriptionId")
                    {
                        if (!$resellerSubcriptions.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "offers", "reseller subcription", "Id", $value)
                        }

                        $offer[$column] = $resellerSubcriptions[$value]
                    }
                    elseif ($column -eq "ProvisioningState")
                    {
                        if (!$provisioningStates.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "offers", "provisioning state", "ProvisioningState", $value)
                        }
                        
                        $offer[$column] = $provisioningStates[$value]
                    }
                    elseif ($column -eq "RoutingResourceManagerType")
                    {
                        if (!$resourceManagerTypes.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "offers", "resource manager type", "ResourceManagerType", $value)
                        }
                        
                        $offer[$column] = $resourceManagerTypes[$value]
                    }
                    elseif ($column -eq "Id")
                    {
                        $offerId = $value
                    }
                    else
                    {
                        $offer[$column] = $value
                    }
                }

                $offer["Id"] = "/subscriptions/$($offer["ResellerSubscriptionId"])/resourceGroups/$($offer["ResourceGroupName"])/providers/Microsoft.Subscriptions.Admin/offers/$($offer["Name"])"
                $offers.Add($offerId, $offer)
            }

            Write-Verbose $Strings.MsgOffer -Verbose
            foreach ($offer in $offers.Values)
            {
                Write-Host ($offer | Out-String)
                Write-Host "`n"
            }
        }

        # STEP 11: Retrieve subscriptions
        $SQLCmd = "SELECT [SubscriptionState],[SubscriptionStateName] FROM [$SubscriptionSqlDbName].[subscriptions.internal].[SubscriptionStates]"
        $subStateTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $subscriptionStates = @{}
        if ($subStateTable.Tables.Count -gt 0 -and $null -ne $subStateTable.Tables[0].Rows)
        {
            $subStateTable.Tables[0].Rows | % { $subscriptionStates.Add($_.SubscriptionState.ToString(), $_.SubscriptionStateName.ToString()) }
        }

        $SQLCmd = "SELECT [Id],[ResellerSubscriptionId],[SubscriptionId],[DisplayName],[OfferId],[Owner],[TenantId],[RoutingResourceManagerType],[State],[Tags] FROM [$SubscriptionSqlDbName].[subscriptions.internal].[Subscriptions]"
        $subTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $subscriptions = @{}
        if ($subTable.Tables.Count -gt 0 -and $null -ne $subTable.Tables[0].Rows)
        {
            $subscriptionColumnNames = $subTable.Tables[0].Columns.ColumnName
            foreach ($row in $subTable.Tables[0].Rows)
            {
                $subscriptionId = ""
                $subscription = [ordered] @{}
                foreach ($column in $subscriptionColumnNames)
                {
                    $value = $row[$column].ToString()
                    if ($column -eq "ResellerSubscriptionId")
                    {
                        if (!$resellerSubcriptions.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "subscriptions", "reseller subcription", "Id", $value)
                        }
                        
                        $subscription[$column] = $resellerSubcriptions[$value]
                    }
                    elseif ($column -eq "State")
                    {
                        if (!$subscriptionStates.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "subscriptions", "subscription state", "SubscriptionState", $value)
                        }
                        
                        $subscription[$column] = $subscriptionStates[$value]
                    }
                    elseif ($column -eq "RoutingResourceManagerType")
                    {
                        if (!$resourceManagerTypes.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "subscriptions", "resource manager type", "ResourceManagerType", $value)
                        }
                        
                        $subscription[$column] = $resourceManagerTypes[$value]
                    }
                    elseif ($column -eq "OfferId")
                    {
                        if (!$offers.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "subscriptions", "offer", "Id", $value)
                        }
                        
                        $subscription[$column] = $offers[$value].Id
                    }
                    elseif ($column -eq "Id")
                    {
                        $subscriptionId = $value
                    }
                    else
                    {
                        $subscription[$column] = $value
                    }
                }

                $subscription["Id"] = "/subscriptions/$($subscription["ResellerSubscriptionId"])/providers/Microsoft.Subscriptions.Admin/subscriptions/$($subscription["SubscriptionId"])"
                $subscriptions.Add($subscriptionId, $subscription)
            }

            Write-Verbose $Strings.MsgSubscription -Verbose
            foreach ($subscription in $subscriptions.Values)
            {
                Write-Host ($subscription | Out-String)
                Write-Host "`n"
            }
        }

        # STEP 12: Retrieve plans
        $SQLCmd = "SELECT [PlanId],[ResourceId] FROM [$SubscriptionSqlDbName].[subscriptions.internal].[Quotas]"
        $quotaTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $plan2quota = @{}
        if ($quotaTable.Tables.Count -gt 0 -and $null -ne $quotaTable.Tables[0].Rows)
        {
            foreach ($row in $quotaTable.Tables[0].Rows)
            {
                $planId = $row.PlanId.ToString()
                $resourceId = $row.ResourceId.ToString()
                if ($plan2quota.ContainsKey(($planId)))
                {
                    $plan2quota[$planId] += $resourceId
                }
                else
                {
                    $plan2quota[$planId] = @($resourceId)
                }
            }
        }

        $SQLCmd = "SELECT [PlanLinkType],[PlanLinkTypeName] FROM [$SubscriptionSqlDbName].[subscriptions.internal].[PlanLinkTypes]"
        $planLinkTypeTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $planLinkTypes = @{}
        if ($planLinkTypeTable.Tables.Count -gt 0 -and $null -ne $planLinkTypeTable.Tables[0].Rows)
        {
            $planLinkTypeTable.Tables[0].Rows | % { $planLinkTypes.Add($_.PlanLinkType.ToString(), $_.PlanLinkTypeName.ToString()) }
        }

        $SQLCmd = "SELECT [OfferId],[PlanId],[PlanLinkType] FROM [$SubscriptionSqlDbName].[subscriptions.internal].[PlanLinks]"
        $planLinkTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $plan2offer = @{}
        if ($planLinkTable.Tables.Count -gt 0 -and $null -ne $planLinkTable.Tables[0].Rows)
        {
            foreach ($row in $planLinkTable.Tables[0].Rows)
            {
                $planId = $row.PlanId.ToString()
                if (!$offers.ContainsKey($row.OfferId.ToString()))
                {
                    throw ($Strings.ErrorDatabaseMissingItem -f "plans", "offer", "Id", $row.OfferId.ToString())
                }

                $offerId = $offers[$row.OfferId.ToString()].Id
                if (!$planLinkTypes.ContainsKey($row.PlanLinkType.ToString()))
                {
                    throw ($Strings.ErrorDatabaseMissingItem -f "plans", "plan link type", "PlanLinkType", $row.PlanLinkType.ToString())
                }

                $planLinkType = $planLinkTypes[$row.PlanLinkType.ToString()]
                if ($plan2offer.ContainsKey(($planId)))
                {
                    $plan2offer[$planId][$planLinkType] += $offerId
                }
                else
                {
                    $emptyType2Offer = @{}
                    @($planLinkTypes.Values.GetEnumerator()) | % {
                        $emptyType2Offer[$_] = @()
                    }

                    $plan2offer[$planId] = $emptyType2Offer
                    $plan2offer[$planId][$planLinkType] += $offerId
                }
            }
        }

        $SQLCmd = "SELECT [Id],[ResellerSubscriptionId],[ResourceGroupName],[Tags],[Name],
            [DisplayName],[Description],[ProvisioningState],[RoutingResourceManagerType]
            FROM [$SubscriptionSqlDbName].[subscriptions.internal].[Plans]"
        $planTable = Invoke-Sqlcmd -Database $SubscriptionSqlDbName -Query $SQLCmd -As DataSet @sqlCommonParams
        $plans = @{}
        if ($planTable.Tables.Count -gt 0 -and $null -ne $planTable.Tables[0].Rows)
        {
            $planColumnNames = $planTable.Tables[0].Columns.ColumnName
            foreach ($row in $planTable.Tables[0].Rows)
            {
                $planId = ""
                $plan = [ordered] @{}
                foreach ($column in $planColumnNames)
                {
                    $value = $row[$column].ToString()
                    if ($column -eq "ResellerSubscriptionId")
                    {
                        if (!$resellerSubcriptions.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "plans", "reseller subcription", "Id", $value)
                        }
                        
                        $plan[$column] = $resellerSubcriptions[$value]
                    }
                    elseif ($column -eq "ProvisioningState")
                    {
                        if (!$provisioningStates.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "plans", "provisioning state", "ProvisioningState", $value)
                        }
                        
                        $plan[$column] = $provisioningStates[$value]
                    }
                    elseif ($column -eq "RoutingResourceManagerType")
                    {
                        if (!$resourceManagerTypes.ContainsKey($value))
                        {
                            throw ($Strings.ErrorDatabaseMissingItem -f "plans", "resource manager type", "ResourceManagerType", $value)
                        }
                        
                        $plan[$column] = $resourceManagerTypes[$value]
                    }
                    elseif ($column -eq "Id")
                    {
                        $planId = $value
                    }
                    else
                    {
                        $plan[$column] = $value
                    }
                }

                $plan["Id"] = "/subscriptions/$($plan["ResellerSubscriptionId"])/resourceGroups/$($plan["ResourceGroupName"])/providers/Microsoft.Subscriptions.Admin/plans/$($plan["Name"])"
                $plan["QuotaIds"] = $plan2quota[$planId]
                $plan["Offers"] = $plan2offer[$planId]
                $plans.Add($planId, $plan)
            }

            Write-Verbose $Strings.MsgPlan -Verbose
            foreach ($plan in $plans.Values)
            {
                Write-Host ($plan | Out-String)
                Write-Host "`n"
            }
        }
    }
    finally
    {
        # Remove temp folder
        $null = Remove-Item $tmpDir -Force -Recurse -ErrorAction Ignore | Out-Null
        
        # Drop subscription DB        
        $disconnectScript = @"
DECLARE @DatabaseName nvarchar(50)
SET @DatabaseName = N'$SubscriptionSqlDbName'
DECLARE @SQL varchar(max)
SELECT @SQL = COALESCE(@SQL,'') + 'Kill ' + Convert(varchar, SPId) + ';'
FROM MASTER..SysProcesses
WHERE DBId = DB_ID(@DatabaseName) AND SPId <> @@SPId
--SELECT @SQL
EXEC(@SQL)
"@

        Invoke-Sqlcmd -Query $disconnectScript @sqlCommonParams -ErrorAction Continue
        Invoke-Sqlcmd -Query ('Drop database "{0}"' -f $SubscriptionSqlDbName) @sqlCommonParams -ErrorAction Continue
    }

    # Convert offer, subscription and plan into PSCustomObject
    $offersObj = ConvertDictionariesToCustomObjects -Dictionaries $offers
    $subscriptionsObj = ConvertDictionariesToCustomObjects -Dictionaries $subscriptions
    $plansObj = ConvertDictionariesToCustomObjects -Dictionaries $plans

    # Output results in HTML format to TempFolder
    $crpQuotaHtml = $crpQuotas | ConvertTo-HTML -As List
    $nrpQuotaHtml = $nrpQuotas | ConvertTo-HTML -As List
    $srpQuotaHtml = $srpQuotas | ConvertTo-HTML -As List
    $offerHtml = $offersObj
    $subscriptionHtml = $subscriptionsObj
    $planHtml = $plansObj | ConvertTo-HTML -As List -Property Id, ResellerSubscriptionId, ResourceGroupName, Tags, Name, DisplayName, `
        Description, ProvisioningState, RoutingResourceManagerType, @{Expression = {$_.QuotaIds -join ";   "}}, `
        @{Expression = {$_.Offers.Base -join ";   "}}, @{Expression = {$_.Offers.None -join ";   "}}, @{Expression = {$_.Offers.Addon -join ";   "}}
    ConvertTo-HTML -Body "<h3>$($Strings.HtmlCrpQuotaHeader)</h3> <h3>$($Strings.HtmlResourceCount)$($crpQuotas.Count)</h3> $crpQuotaHtml `
        <h3>$($Strings.HtmlNrpQuotaHeader)</h3> <h3>$($Strings.HtmlResourceCount)$($nrpQuotas.Count)</h3> $nrpQuotaHtml `
        <h3>$($Strings.HtmlSrpQuotaHeader)</h3> <h3>$($Strings.HtmlResourceCount)$($srpQuotas.Count)</h3> $srpQuotaHtml `
        <h3>$($Strings.HtmlOfferHeader)</h3> <h3>$($Strings.HtmlResourceCount)$($offersObj.Count)</h3> $offerHtml `
        <h3>$($Strings.HtmlSubscriptionHeader)</h3> <h3>$($Strings.HtmlResourceCount)$($subscriptionsObj.Count)</h3> $subscriptionHtml `
        <h3>$($Strings.HtmlPlanHeader)</h3> <h3>$($Strings.HtmlResourceCount)$($plansObj.Count)</h3> $planHtml" `
        -Title $Strings.HtmlTitle |  Out-File -FilePath $(Join-Path $TempFolder $OutputReportFile)

    return @{
        ComputeQuota = $crpQuotas
        NetworkQuota = $nrpQuotas
        StorageQuota = $srpQuotas
        Offer = $offersObj
        Subscription = $subscriptionsObj
        Plan = $plansObj
    }
}

Export-ModuleMember -Function Validate-AszBackup