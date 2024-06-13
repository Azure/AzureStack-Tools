@{
    # Root module of this module.
    RootModule = 'Unprotect-AzsBackup.psm1'    

    # Version number of this module.
    moduleVersion = '1.0.0.0'
    
    # Author of this module
    Author = 'Microsoft Corporation'
    
    # Company or vendor of this module
    CompanyName = 'Microsoft Corporation'
    
    # Copyright statement for this module
    Copyright = '(c) Microsoft Corporation. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'The Unprotect-AzsBackup module contains required functions for backup decryption.'
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Functions to export from this module
    FunctionsToExport = 'Unprotect-AzsBackup'
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
    
        PSData = @{
    
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Backup', 'Decrypt')
    
            # A URL to the license for this module.
            # LicenseUri = ''
    
            # ReleaseNotes of this module
            # ReleaseNotes = ''
    
        } # End of PSData hashtable
    
    } # End of PrivateData hashtable
}
    