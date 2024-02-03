#------------------------------------------------------------------
# <copyright file="Unprotect-AzsBackup.psm1" company="Microsoft Corp.">
#     Copyright (c) Microsoft Corp. All rights reserved.
# </copyright>
#------------------------------------------------------------------

#Requires -Version 5

function Unprotect-AzsBackupFile {
    param (
        [string]
        $SourcePath,
        [string]
        $DestinationPath,
        [byte[]]
        $EncKey,
        [byte[]]
        $MacKey
    )
    
    $ErrorActionPreference = "Stop"
    
    Write-Verbose "[$($MyInvocation.MyCommand)] Decryption started: Source: $SourcePath, Destinantion $DestinationPath"
    $source = New-Object System.IO.FileStream -ArgumentList @($SourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
    try {
        # Read header
        $null = $source.Seek(0, [System.IO.SeekOrigin]::Begin)
        $header = Read-SymmetricEncryptionHeader -Stream $source

        # Check auth tag
        $null = $source.Seek($header["headerLength"], [System.IO.SeekOrigin]::Begin)
        $authTag = Get-AuthTag -Stream $source -Key $MacKey -Algorithm $header["AuthAlgType"]

        if ($null -ne $(Compare-Object $authTag  $header["authTag"])) {
            throw "Encrypted data checksum mismatch."
        }
        Write-Verbose "[$($MyInvocation.MyCommand)] Auth tag check passed"

        # Get decryptor
        $decryptor = Initialize-SymmetricDecryptor -Key $EncKey -IvBytes $header["IvBytes"] -Algorithm $header["EncAlgType"]

        # Start decryption
        $null = $source.Seek($header["headerLength"], [System.IO.SeekOrigin]::Begin)
        $destination = New-Object System.IO.FileStream -ArgumentList @($DestinationPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Write)
        try {
            $cryptoStream = New-Object System.Security.Cryptography.CryptoStream -ArgumentList @($source, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Read)
            Write-Verbose "[$($MyInvocation.MyCommand)] Decryption started"
            $null = $cryptoStream.CopyToAsync($destination).GetAwaiter().GetResult()
            Write-Verbose "[$($MyInvocation.MyCommand)] Decryption completed"
        } catch {
            throw $_
        } finally {
            $null = $destination.Flush($true);
            $null = $destination.Dispose()
        }
    } catch {
        throw $_
    } finally {
        $null = $source.Dispose()
    }
    
    Write-Verbose "[$($MyInvocation.MyCommand)] Decryption finished: Source: $SourcePath, Destinantion $DestinationPath"
}

function Unprotect-AzsBackupWrappedKey {
    param(
        [string]
        $WrappedKey,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Cert
    )

    $ErrorActionPreference = "Stop"

    # first 32 byte (256 bits) of the binary is encryption key, the rest is MAC (Message Authentication Code) key.
    # In Azurestack, we use 256 bits mac key.
    $encKeyLength = 32
    $macKeyLength = 32
    [System.Security.Cryptography.RSA] $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Cert)
    $bytesEncrypted = [System.Convert]::FromBase64String($WrappedKey)
    try {
        $bytesDecrypted = $rsa.Decrypt($bytesEncrypted, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)
    }
    catch {
        # Retry with OaepSHA1 if decryption with OaepSHA256 fails
        $bytesDecrypted = $rsa.Decrypt($bytesEncrypted, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA1)
    }
    [string] $UnwrappedKey = [System.Text.Encoding]::UTF8.GetString($bytesDecrypted)
    $bytesCompactKey = [System.Convert]::FromBase64String($UnwrappedKey)
    
    $macKeyLength = $($bytesCompactKey.Length - $encKeyLength)
    $encKey = New-Object byte[] $encKeyLength
    $macKey = New-Object byte[] $($bytesCompactKey.Length - $encKeyLength)
    Write-Verbose "[$($MyInvocation.MyCommand)] EncKey length: $($encKey.Length * 8) bits, MacKey length: $($macKey.Length * 8) bits"
    if ($macKey.Length -ne $macKeyLength) {
        Write-Warning "[$($MyInvocation.MyCommand)] Mackey should be 256 bits long"
    }
    
    [System.Buffer]::BlockCopy($bytesCompactKey, 0, $encKey, 0, $encKeyLength)
    [System.Buffer]::BlockCopy($bytesCompactKey, $encKeyLength, $macKey, 0, $macKeyLength)
    return $encKey, $macKey
}

function Read-SymmetricEncryptionHeader {
    param(
        [System.IO.FileStream]
        $Stream
    )

    $ErrorActionPreference = "Stop"
    $SymmetricEncryptionHeaderMagicNumber = 1

    $reader = New-Object System.IO.BinaryReader -ArgumentList $Stream
    # header tag or version
    [int16] $headerTag = $reader.ReadInt16()
    # 
    if ($headerTag -ne $SymmetricEncryptionHeaderMagicNumber)
    {
        throw "Encrypted data is corrupted or not supported."
    }

    # encryption algorithm type
    [int16] $EncAlgType = $reader.ReadInt16();
    # authentication algorithm type
    [int16] $AuthAlgType = $reader.ReadInt16();
    # IV length
    [int16] $IVLength = $reader.ReadInt16();
    # authentication tag length
    [int16] $authTagLength = $reader.ReadInt16();
    # Initialization vector (IV)
    [byte[]] $IvBytes = $reader.ReadBytes($IVLength);
    # authentication tag content.
    [byte[]]$authTag = $reader.ReadBytes($authTagLength);
    # headerLength = 5 * size of Int16 + size of IV + size of auth tag
    [int16] $headerLength = 5 * 2 + $IVLength + $authTagLength

    return @{
        "EncAlgType" = $EncAlgType
        "AuthAlgType" = $AuthAlgType
        "IvBytes" = $IvBytes
        "authTag" = $authTag
        "headerLength" = $headerLength
    }
}

function Initialize-SymmetricDecryptor {
    param(
        [byte[]]
        $Key,
        [Byte[]]
        $IvBytes,
        [int16]
        $Algorithm
    )

    $ErrorActionPreference = "Stop"
    
    if ($Algorithm -ne 0){
        throw "Unsupported encryption algorithm: $Algorithm"
    }

    Write-Verbose "[$($MyInvocation.MyCommand)] Encryption algorithm: AES-256 (CBC) with PKCS7 padding"
    $alg = New-Object System.Security.Cryptography.AesCryptoServiceProvider -Property @{
        "Mode" = [System.Security.Cryptography.CipherMode]::CBC
        "Padding" = [System.Security.Cryptography.PaddingMode]::PKCS7
    }

    return $alg.CreateDecryptor($Key, $IvBytes)
}

function Get-AuthTag {
    param(
        [System.IO.FileStream]
        $Stream,
        [byte[]]
        $Key,
        [int16]
        $Algorithm
    )

    $ErrorActionPreference = "Stop"

    if ($Algorithm -ne 0){
        throw "Unsupported authentication algorithm: $Algorithm"
    }

    Write-Verbose "[$($MyInvocation.MyCommand)] Authentication algorithm: HMAC-SHA512 with key length $($Key.Length * 8) bits"
    $alg = [System.Security.Cryptography.HMAC]::Create("HMACSHA512")
    $alg.Key = $Key

    return $alg.ComputeHash($stream)
}

function Unprotect-AzsBackup {
    <#
    .SYNOPSIS
        Decrypt Azurestack infrastructure backup
    .PARAMETER BackupSnapshotZip
        The zip file of the backup snapshot
    .PARAMETER Destination
        The destinantion of decrypted backup file
    .PARAMETER Certificate
        The .pfx file contains private key to decrypt backup
    .PARAMETER CertificatePassphrase
        The Passphrase for certificate
    .PARAMETER ShareCrendential
        The crendential for backup share
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupSnapshotZip,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Certificate,

        [Parameter(Mandatory=$false)]
        [SecureString] $CertificatePassphrase = $null,

        [Parameter(Mandatory=$false)]
        [PSCredential] $ShareCrendential = $null
    )

    $ErrorActionPreference = "Stop"

    if ($null -eq $CertificatePassphrase)
    {
        $CertificatePassphrase = Read-Host -Prompt "Enter password" -AsSecureString
    }

    Write-Verbose "[$($MyInvocation.MyCommand)] Mapping remote fileshare to PSdrive"

    $BackupPath = [System.IO.Path]::GetDirectoryName($BackupSnapshotZip)

    Write-Verbose "[$($MyInvocation.MyCommand)] Loading certificate"

    try
    {
        $certBytes = [System.IO.File]::ReadAllBytes($Certificate)
    }
    catch
    {
        throw "Unable to read certificate file: $_"
    }

    $rawPassphrase = $(New-Object PSCredential " ",$CertificatePassphrase).GetNetworkCredential().Password

    try
    {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($certBytes, $rawPassphrase)
    }
    catch [System.Management.Automation.MethodInvocationException]
    {
        throw "[$($MyInvocation.MyCommand)] Unable to load certificate. Passphrase is incorrect or the certificate is corrupted."
    }

    Write-Verbose "[$($MyInvocation.MyCommand)] Cert info: $cert"

    $snapshotMetadata = $BackupSnapshotZip.Replace(".zip", ".xml")
    if (!(Test-Path $BackupSnapshotZip) -or !(Test-Path $snapshotMetadata))
    {
        throw "Can not find valid backup"
    }

    [xml]$snapshot = Get-Content $snapshotMetadata
    $wrappedKey = $(Select-Xml -Xml $snapshot -XPath "/BackupSnapshot/EncryptedBackupEncryptionKey").Node.InnerText
    $certThumprint = $(Select-Xml -Xml $snapshot -XPath "/BackupSnapshot/EncryptionCertThumbprint").Node.InnerText
    $backupStatus = $(Select-Xml -Xml $snapshot -XPath "/BackupSnapshot/SnapshotProperties/BackupStatus").Node.InnerText

    if ($backupStatus -ne "Succeeded")
    {
        Write-Warning "[$($MyInvocation.MyCommand)] Backup file status is $backupStatus."
    }

    Write-Verbose "[$($MyInvocation.MyCommand)] Wrapped key : $wrappedKey"

    if ($cert.Thumbprint -ne $certThumprint)
    {
        throw "Decryption key is not the same as encryption key: Thumbprint mismatch"
    }

    $keys = Unprotect-AzsBackupWrappedKey -WrappedKey $wrappedKey -Cert $cert
    $zip = Get-ChildItem $BackupSnapshotZip
    $destinationFilePath = Join-Path $Destination $zip.Name
    Unprotect-AzsBackupFile -SourcePath $BackupSnapshotZip -DestinationPath $destinationFilePath -EncKey $keys[0] -MacKey $keys[1]
    Expand-Archive -Path $destinationFilePath -DestinationPath $Destination -Force
    Remove-Item -Force -Confirm:$false $destinationFilePath -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Unprotect-AzsBackup
