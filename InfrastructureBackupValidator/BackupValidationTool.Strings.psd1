ConvertFrom-StringData @'
    ###PSLOC
    # message
    MsgComputeQuota = BackupType: ComputeQuota
    MsgNetworkQuota = BackupType: NetworkQuota
    MsgStorageQuota = BackupType: StorageQuota
    MsgStorageAccount = BackupType: StorageAccount
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

    # error
    ErrorFailToConnectBackupStore = Failed to connect to the backup store '{0}' with provided credential. Exception: {1}
    ErrorFailToConnectSqlServerDefault = Failed to connect to the SQL server '{0}' with Windows Authentication. Exception: {1}
    ErrorFailToConnectSqlServerProvided = Failed to connect to the SQL server '{0}' with provided credential. Exception: {1}
    ErrorFailToFindBackupSnapshots = Failed to find backup repositories: {0}
    ErrorFindMoreThanOneSnapshot = Found more than one snapshots for repository: {0}
    ErrorFailToFindBackupChain = Failed to find backup chain for {0}
    ErrorFailToDecryptSnapshot = Backup decryption failed for snapshot: '{0}'. Exception: {1}
'@
