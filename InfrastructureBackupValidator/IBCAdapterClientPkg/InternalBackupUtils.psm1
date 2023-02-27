##
##  <copyright file="InternalBackupUtils.psm1" company="Microsoft">
##    Copyright (C) Microsoft. All rights reserved.
##  </copyright>
##

Import-Module "$PSScriptRoot\Out-ErrorMessage.psm1"
$backupInfoFileName = "InternalBackupInfo.xml"
$RetentionLockExpiration = [TimeSpan]::FromMinutes(30)
$PickupLockExpiration = [TimeSpan]::FromMinutes(30)
<#
.SYNOPSIS
    Exclusively open lock file $Path\$Name.

.PARAMETER Path
    Parent directory of lockfile.

.PARAMETER Name
    Lock file name.

.PARAMETER Timeout
    Timeout of opening operation.

.OUTPUTS
    FileStream of lock file. Return $null if times out.
#>
function Open-LockFile
{
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [parameter(Mandatory = $false)]
        [timespan]
        $Timeout = [timespan]::FromSeconds(120)
    )

    $null = New-Item $Path -ItemType Directory -Force -ErrorAction SilentlyContinue
    $timeoutDate = $(Get-Date).Add($Timeout)
    While ( $(Get-Date) -le $timeoutDate)
    {
        try
        {
            $res = [System.IO.File]::Open(
                $(Join-Path $(Convert-Path $Path) "$Name.lock"), 
                [System.IO.FileMode]::OpenOrCreate,
                [System.IO.FileAccess]::ReadWrite, 
                [System.IO.FileShare]::None)

            return $res
        }
        catch 
        {
            Write-Warning "Open lock file failed: `n$(Out-ErrorMessage $_)"
        }

        # Typical lock holding time is 20 ms wait 100 ms for it to finish.
        $null = Start-Sleep -Milliseconds 100
    }
    
    # lock timeout
    return $null
}

<#
.SYNOPSIS
    Close lock file $Path\$Name.

.INPUTS
    Lock file FileStream.
#>
function Close-LockFile
{
    param(
        [parameter(
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [System.IO.FileStream]
        $pipelineInput
    )

    $pipelineInput.Close()
}

<#
.SYNOPSIS
    Try to acquire lock.

.PARAMETER Path
    Parent directory of lockfile.

.PARAMETER Name
    Lock file name.

.PARAMETER Id
    Id of owner.

.PARAMETER Timeout
    Lock is automaticly released after this timeout.

.OUTPUTS
    $true for successful acquisition. Return $false if lock is acquired by other process.
#>
function TryLock-BcdrMutex 
{
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9]+$')]
        [string]
        $Name,

        [string]
        $Id = $(New-Guid).ToString(),
        
        [timespan]
        $Expiration = [TimeSpan]::FromMinutes(1)
    )

    $ErrorActionPreference = "Stop"
    
    $lock = Open-LockFile -Path $Path -Name $Name
    if ($null -eq $lock) 
    {
        return $false
    }

    try
    {
        if ( -not $(CheckLockValid -Lock $lock))
        {
            $t = $(Get-Date).ToUniversalTime()
            $lockInfo = @{
                MachineName = $env:ComputerName
                Pid         = $PID
                Id          = $Id
                LockTime    = $t
                ExpiredTime = $t + $Expiration
            } | ConvertTo-Json -Compress
            $lock.Position = 0
            $writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList @($lock, [System.Text.Encoding]::UTF8, 4096, $true)
            try
            {
                $writer.Write($lockInfo)
                $writer.Flush()
            }
            finally
            {
                $writer.Dispose()
            }
            return $true
        }
        else
        {
            return $false    
        }
    }
    catch
    {
        Write-Warning "TryLock-BcdrMutex failed: `n$(Out-ErrorMessage $_)"
        return $false
    }
    finally
    {
        $null = $lock | Close-LockFile
    }
}

<#
.SYNOPSIS
    Release lock.

.PARAMETER Path
    Parent directory of lockfile.

.PARAMETER Name
    Lock file name.

.PARAMETER Id
    Id of owner.
#>
function Unlock-BcdrMutex 
{
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9]+$')]
        [string]
        $Name,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Id
    )

    $lock = Open-LockFile -Path $Path -Name $Name
    if ($null -eq $lock)
    {
        throw "Open-LockFile failed, can not unlock bcdr mutex."
    }
    try
    {
        $lock.SetLength(0)
    }
    finally
    {
        $null = $lock | Close-LockFile
    }
}

<#
.SYNOPSIS
    Validate the lock file.

.PARAMETER Lock
    FileStream of lock file.

.OUTPUTS
    $false if lock file is empty, corrupt, expired or owner process is already died. Otherwise, $true.
#>
function CheckLockValid
{
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.IO.FileStream]
        $Lock
    )

    $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList @($Lock, [System.Text.Encoding]::UTF8, $true, 4096, $true)
    try
    {
        $lockstr = $reader.ReadToEnd()
        $lockinfo = $lockstr | ConvertFrom-Json
        if ($null -eq $lockinfo -or $null -eq $lockinfo.ExpiredTime -or $null -eq $lockinfo.MachineName)
        {
            Write-Verbose "[CheckLockValid] Lock file empty: $lockstr"
            return $false
        }
        elseif ($($lockinfo.ExpiredTime.ToUniversalTime()) -lt $($(Get-Date).ToUniversalTime()))
        {
            Write-Warning "[CheckLockValid] Lock expired"
            return $false
        }
        elseif ($env:ComputerName -eq $lockinfo.MachineName -and $($null -eq $lockinfo.Pid -or $null -eq $(Get-Process -Id $lockinfo.Pid)))
        {
            Write-Warning "[CheckLockValid] Process $($lockinfo.Pid) exited unexpectedly"
            return $false
        }
        else
        {
            Write-Verbose "[CheckLockValid] Process $($lockinfo.Pid) on $($lockinfo.MachineName) is still running"
            return $true
        }
    }
    catch
    {
        Write-Warning "[CheckLockValid] Lock invalid: `n$(Out-ErrorMessage $_)"
        return $false
    }
    finally
    {
        $reader.Dispose()
    }
}

<#
.SYNOPSIS
    Read internal backup information.

.PARAMETER Path
    Path of InternalBackupInfo.xml file.

.OUTPUTS
    Internal backup info. Return $null for failed backup.
#>
function Read-SucceededInternalBackupInfo
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    $backupInfo = Join-Path $Path $backupInfoFileName
    if (-not $(Test-Path $backupInfo))
    {
        return $null
    }

    $info = [xml]$(Get-Content $backupInfo)
    if ("Succeeded" -ne $info.InternalBackupInfo.Status)
    {
        return $null
    }
    else
    {
        return New-Object -TypeName PSObject -Property @{
            BackupDataVersion = $info.InternalBackupInfo.BackupDataVersion
            BackupId          = $info.InternalBackupInfo.BackupId
            Status            = $info.InternalBackupInfo.Status
            CreatedDateTime   = $(Get-Date $info.InternalBackupInfo.CreatedDateTime)
            TimeTakenToCreate = $info.InternalBackupInfo.TimeTakenToCreate
        }
    }
}

<#
.SYNOPSIS
    Remove backup folder

.PARAMETER Path
    Backup folder to be removed.
#>
function Remove-BackupFolder
{
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Path
    )

    $lockParam = @{
        Path = $Path
        Name = "read"
        Id   = "Remove_" + $env:ComputerName
    }

    Write-Verbose "Removing $Path"
    if (-not $(TryLock-BcdrMutex @lockParam -Expiration $RetentionLockExpiration))
    {
        Write-Warning "Skip removing of $Path"
        return
    }

    try
    {
        if (Test-Path -PathType Leaf "$Path\$backupInfoFileName")
        {
            Remove-Item -Force -Confirm:$false  "$Path\$backupInfoFileName" -ErrorAction Stop
        }
        else
        {
            Write-Warning "Backup info not exists. Remove backup file."
        }
    }
    catch
    {
        Write-Warning "Remove backup $Path failed: `n$(Out-ErrorMessage $_)"
    }
    finally
    {
        Unlock-BcdrMutex @lockParam
    }

    try
    {
        Write-Verbose "Removing backup $Path"
        Remove-Item $Path -Force -Recurse -Confirm:$false -ErrorAction Stop
    }
    catch
    {
        Write-Warning "Remove backup failed, try removing with renaming: `n$(Out-ErrorMessage $_)"
        try
        {
            $parentPath = Split-Path $Path -Parent
            $tempPath = Join-Path $parentPath $($(New-Guid).ToString())
            Write-Verbose "Moving $Path to $tempPath"
            Move-Item $Path $tempPath -Force
            Write-Verbose "Removing $tempPath"
            Remove-Item $tempPath -Force -Recurse -Confirm:$false -ErrorAction Stop
        }
        catch
        {
            Write-Warning "Removing with renaming failed too: `n$(Out-ErrorMessage $_)"
        }
    }
}

<#
.SYNOPSIS
    Get infomation of last succeeded internal backup.

.PARAMETER InternalBackupRootPath
    Backup store path.
#>
function Get-LastSucceededInternalBackupInfo
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InternalBackupRootPath
    )

    $dirs = Get-ChildItem -Directory $InternalBackupRootPath
    $lastSuccessBackup = $dirs | Where-Object {
        $null -ne $(Read-SucceededInternalBackupInfo $_.FullName)
    } | Sort-Object CreationTime | Select-Object -Last 1

    return $lastSuccessBackup
}

<#
.SYNOPSIS
    Remove old backups and always keep at least one success backup.

.PARAMETER InternalBackupRootPath
    Backup store path.

.PARAMETER RetentionPeriod
    Remove backup taken before this limit.

.PARAMETER SizeThreshold
    Remove old backup to keep total size of backup under this limit.
#>
function Remove-RetiredBackup 
{
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InternalBackupRootPath,

        [TimeSpan]
        $RetentionPeriod = [TimeSpan]::MaxValue,

        [long]
        $SizeThreshold = [long]::MaxValue
    )
    
    $lastSuccessBackup = Get-LastSucceededInternalBackupInfo -InternalBackupRootPath $InternalBackupRootPath
    $dirs = Get-ChildItem -Directory $InternalBackupRootPath
    if ($RetentionPeriod -ne [timespan]::MaxValue)
    {
        $dirs `
        | Where-Object CreationTimeUtc -lt $(Get-Date).ToUniversalTime().Add(-$RetentionPeriod) `
        | Where-Object Name -ne $lastSuccessBackup.Name `
        | ForEach-Object {
            Remove-BackupFolder $($_.FullName)
        }
    }

    $totalSize = $(Get-ChildItem $InternalBackupRootPath -Recurse | Measure-Object -Property Length -Sum).Sum
    $dirs = Get-ChildItem -Directory $InternalBackupRootPath `
    | Where-Object Name -ne $lastSuccessBackup.Name `
    | Sort-Object CreationTimeUtc

    foreach ($dir in $dirs)
    {
        if ($totalSize -gt $SizeThreshold)
        {
            $removedSize = $(Get-ChildItem $dir.FullName -Recurse | Measure-Object -Property Length -Sum).Sum
            Remove-BackupFolder $($dir.FullName)
            $totalSize = $totalSize - $removedSize
        }
        else
        {
            break
        }
    }
}

<#
.SYNOPSIS
    Wait powershell background job to finish and kill it if times out.

.INPUTS
    Job to wait.

.PARAMETER TimeoutInSec
    Kill job after this timeout.
#>
function Wait-JobWithTimeout
{
    param(
        [System.Management.Automation.Job]
        [parameter(
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [ValidateNotNull()]
        $Job,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [int]
        $TimeoutInSec
    )

    Wait-Job -Job $Job -Timeout $TimeoutInSec
    if ($(Get-Job -Id $Job.Id).State -eq "Running")
    {
        Write-Warning "Job time out."
    }

    $Job | Stop-Job
    $Job | Receive-Job
    $Job | Remove-Job
}

<#
.SYNOPSIS
    This is a helper function for internal backup runner.
    It makes sure only one backup at a time and handles backup retention for backup runner.

.PARAMETER ScriptBlock
    Script block to trigger backup.

.PARAMETER Config
    Backup runner configuration.
#>
function Invoke-RunnerBackupScriptBlock
{
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]
        $ScriptBlock,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSObject]
        $Config,

        [switch]
        $NoTranscript
    )

    $ErrorActionPreference = "Stop"
    $WarningPreference = "Continue"
    $VerbosePreference = "Continue"
    $SessionName = $Config.BackupName
    if (-not $NoTranscript.IsPresent)
    {
        $null = Start-Transcript "$env:SystemDrive\MASLogs\Runner_$($SessionName)_$([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')).log" -Append
    }

    try 
    {
        $Path = [regex]::Replace($Config.BackupLocation, "{([^}]*)}", "\\$($Config.FileServerName)\$($Config.StorageServerPrefix)_`$1") + "\Temp\$SessionName"
        $RetentionPeriodInMinutes = $Config.RetentionPeriodInMinutes
        Write-Verbose "Backup path: $Path"
        $backupId = New-Guid
        $null = New-Item $(Join-Path $Path "Backup") -ItemType Directory -Force -ErrorAction SilentlyContinue
        $lockParam = @{
            Path = $Path
            Name = $SessionName
            Id   = "Backup" + $env:ComputerName
        }

        # acquire lock
        Write-Verbose "Try acquiring lock."
        if (-not $(TryLock-BcdrMutex @lockParam -Expiration $([TimeSpan]::FromSeconds($Config.TimeoutInSec))))
        {
            Write-Verbose "Backup running skip."
            return
        }
        Write-Verbose "Lock acquired."

        try
        {
            $InternalBackupRootPath = Join-Path $Path "Backup"
            $lastSuccessBackup = Get-LastSucceededInternalBackupInfo -InternalBackupRootPath $InternalBackupRootPath

            # Skip backup if a successful backup exists within interval.
            # Invoke-RunnerBackupScriptBlock can be call with a smaller interval than BackupInteval.
            if ($null -ne $lastSuccessBackup.CreationTimeUtc -and $null -ne $Config.BackupInterval)
            {
                $gap = $(Get-Date).ToUniversalTime() - $lastSuccessBackup.CreationTimeUtc
                $backupInterval = [timespan] $Config.BackupInterval
                Write-Verbose "Last success backup: $($lastSuccessBackup.Name), gap: $gap"
                if ($gap -lt $backupInterval)    # $gap -lt $null -> $false
                {
                    Write-Verbose "Skip backup because last backup is new enough"
                    return
                }
            }

            # Retention
            Remove-RetiredBackup -InternalBackupRootPath $InternalBackupRootPath -RetentionPeriod $([TimeSpan]::FromMinutes($RetentionPeriodInMinutes))

            # trigger backup
            $startTime = $(Get-Date).ToUniversalTime()
            
            $backupResult = "Failed"
            try
            {
                Invoke-Command -ScriptBlock $ScriptBlock -ErrorAction Stop -WarningAction Continue -Verbose -ArgumentList @($Config, $InternalBackupRootPath, $backupId)
                $backupResult = "Succeeded"
            }
            catch
            {
                Write-Warning "Invoke backup runner failed: `n$(Out-ErrorMessage $_)"
                Remove-Item -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue "$InternalBackupRootPath\$backupId\*"
            }

            $endTime = $(Get-Date).ToUniversalTime()
            $TimeTakenToCreate = $endTime - $startTime
            Write-Verbose "Write backup info"
            "<?xml version=""1.0""?>
<InternalBackupInfo xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"">
    <BackupDataVersion>1.0.0</BackupDataVersion>
    <BackupId>$backupId</BackupId>
    <Status>$backupResult</Status>
    <CreatedDateTime>$($endTime.ToString("o"))</CreatedDateTime>
    <TimeTakenToCreate>$([System.Xml.XmlConvert]::ToString($TimeTakenToCreate))</TimeTakenToCreate>
</InternalBackupInfo>" | Out-File $InternalBackupRootPath\$backupId\$backupInfoFileName -ErrorAction SilentlyContinue

            # Retention
            Remove-RetiredBackup -InternalBackupRootPath $InternalBackupRootPath -SizeThreshold $([long]$Config.SizeThresholdInMB * 1024 * 1024)
        }
        finally
        {
            Unlock-BcdrMutex @lockParam
        }
    }
    catch
    {
        Write-Warning "Invoke-RunnerBackupScriptBlock failed with exception: `n$(Out-ErrorMessage $_)"
        throw
    }
    finally
    {
        if (-not $NoTranscript.IsPresent)
        {
            $null = Stop-Transcript
        }
    }
}

<#
.SYNOPSIS
    Copy last success backup to infrastucture backup staging area.

.PARAMETER InternalBackupRoot
    Root folder of internal backup.

.PARAMETER StagingAreaPath
    Staging area of infrastructure backup.

.PARAMETER BackupId
    Infrastructure backup ID.
#>
function Copy-RunnerBackupToStagingArea
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InternalBackupRoot,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StagingAreaPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Guid]
        $BackupId
    )
    
    $ErrorActionPreference = 'Stop'

    $backupIdStr = $BackupId.ToString()
    $destPath = "$StagingAreaPath\Backup\$backupIdStr"
    New-Item $destPath -ItemType Directory -Force
    $lastSuccessBackup = Get-ChildItem -Directory $InternalBackupRoot `
        | Foreach-Object { Read-SucceededInternalBackupInfo $_.FullName } `
        | Where-Object { $null -ne $_ } `
        | Sort-Object { Get-Date $_.CreatedDateTime } `
        | Select-Object -Last 1

    if ($null -eq $lastSuccessBackup)
    {
        throw "Can not find any success backup."
    }

    $lastSuccessBackupPath = $(Join-Path $InternalBackupRoot $lastSuccessBackup.BackupId)
    Write-Verbose "using backup $lastSuccessBackupPath"
    $lockParam = @{
        Path = $lastSuccessBackupPath
        Name = "read"
        Id   = "Pickup_" + $env:ComputerName
    }
    $lockFileName = "$($lockParam.Name).lock"
    $failedFiles = @()
    try
    {
        # lock backup to avoid it being deleted by retention
        if (-not $(TryLock-BcdrMutex @lockParam -Expiration $PickupLockExpiration))
        {
            throw "Last success backup is being deleted."
        }

        $null = Get-ChildItem $lastSuccessBackupPath -Exclude @($backupInfoFileName, $lockFileName) `
        | Foreach-Object {
            $sourceName = $_.FullName
            $destName = Join-Path $(Convert-Path $destPath) $_.Name
            try
            {
                Copy-Item $sourceName $destName -Recurse -ErrorAction Stop
            }
            catch
            {
                Write-Warning "Copy file $sourceName failed: $_"
                $failedFiles += $sourceName
            }
        }

        if ($failedFiles.Count -ne 0)
        {
            throw "Copying of following files failed: $failedFiles"
        }
    }
    finally
    {
        $null = Unlock-BcdrMutex @lockParam
    }

    return Read-SucceededInternalBackupInfo -Path $lastSuccessBackupPath
}

Export-ModuleMember -Function Wait-JobWithTimeout
Export-ModuleMember -Function TryLock-BcdrMutex
Export-ModuleMember -Function Unlock-BcdrMutex
Export-ModuleMember -Function Remove-RetiredBackup
Export-ModuleMember -Function Copy-RunnerBackupToStagingArea
Export-ModuleMember -Function Invoke-RunnerBackupScriptBlock
# SIG # Begin signature block
# MIInlgYJKoZIhvcNAQcCoIInhzCCJ4MCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA8aoEUsVRaGaSz
# AlLYSgboZtLf/o/AjTKqqjeXf6CJ4aCCDXYwggX0MIID3KADAgECAhMzAAACy7d1
# OfsCcUI2AAAAAALLMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjIwNTEyMjA0NTU5WhcNMjMwNTExMjA0NTU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC3sN0WcdGpGXPZIb5iNfFB0xZ8rnJvYnxD6Uf2BHXglpbTEfoe+mO//oLWkRxA
# wppditsSVOD0oglKbtnh9Wp2DARLcxbGaW4YanOWSB1LyLRpHnnQ5POlh2U5trg4
# 3gQjvlNZlQB3lL+zrPtbNvMA7E0Wkmo+Z6YFnsf7aek+KGzaGboAeFO4uKZjQXY5
# RmMzE70Bwaz7hvA05jDURdRKH0i/1yK96TDuP7JyRFLOvA3UXNWz00R9w7ppMDcN
# lXtrmbPigv3xE9FfpfmJRtiOZQKd73K72Wujmj6/Su3+DBTpOq7NgdntW2lJfX3X
# a6oe4F9Pk9xRhkwHsk7Ju9E/AgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUrg/nt/gj+BBLd1jZWYhok7v5/w4w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzQ3MDUyODAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAJL5t6pVjIRlQ8j4dAFJ
# ZnMke3rRHeQDOPFxswM47HRvgQa2E1jea2aYiMk1WmdqWnYw1bal4IzRlSVf4czf
# zx2vjOIOiaGllW2ByHkfKApngOzJmAQ8F15xSHPRvNMmvpC3PFLvKMf3y5SyPJxh
# 922TTq0q5epJv1SgZDWlUlHL/Ex1nX8kzBRhHvc6D6F5la+oAO4A3o/ZC05OOgm4
# EJxZP9MqUi5iid2dw4Jg/HvtDpCcLj1GLIhCDaebKegajCJlMhhxnDXrGFLJfX8j
# 7k7LUvrZDsQniJZ3D66K+3SZTLhvwK7dMGVFuUUJUfDifrlCTjKG9mxsPDllfyck
# 4zGnRZv8Jw9RgE1zAghnU14L0vVUNOzi/4bE7wIsiRyIcCcVoXRneBA3n/frLXvd
# jDsbb2lpGu78+s1zbO5N0bhHWq4j5WMutrspBxEhqG2PSBjC5Ypi+jhtfu3+x76N
# mBvsyKuxx9+Hm/ALnlzKxr4KyMR3/z4IRMzA1QyppNk65Ui+jB14g+w4vole33M1
# pVqVckrmSebUkmjnCshCiH12IFgHZF7gRwE4YZrJ7QjxZeoZqHaKsQLRMp653beB
# fHfeva9zJPhBSdVcCW7x9q0c2HVPLJHX9YCUU714I+qtLpDGrdbZxD9mikPqL/To
# /1lDZ0ch8FtePhME7houuoPcMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGXYwghlyAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAALLt3U5+wJxQjYAAAAAAsswDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIE1SDabzOUVIGrN20fMvh2m5
# D44gvXx6yaAWsh4wjvyuMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAnhib2ombagpAAZy94vU5GA8XqyLahAkHBbkEmgWojEeIHN6bhWrYvjvE
# 0wo+5/dR/js7i5ceVKaDAVKT0sIounLd2eOpP9bF0bgka1+DJPmnpmK0vkA3SrcK
# A0Mf/9aG/LT9sYl3bgzw5g/EJT8K8ax/n+CHFdX7ItrBcfLTIQA/uLZnA0urAGC2
# fMLX/84KgcIo/DnvX4r98AhDYTSAsvhbe7ju7P1KeAapc2HOlSLPRLqgJyZaRU8s
# FkjEvCg3raMibopMuTPJkmgClIn4GDoWkL8tyQzxAC2QxetSW8/SRiZT7kwU9TTI
# qnlv3exc/Qbdembsu9FDmxpNQZ04KaGCFwAwghb8BgorBgEEAYI3AwMBMYIW7DCC
# FugGCSqGSIb3DQEHAqCCFtkwghbVAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsq
# hkiG9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCCGFBgC3pgCvHcDxvne+mSZKBkhFSvkc5lxyWC4hKuh/gIGY7/xLtIg
# GBMyMDIzMDIxMDA1NDMyMi45MjdaMASAAgH0oIHQpIHNMIHKMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4QTgyLUUz
# NEYtOUREQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCC
# EVcwggcMMIIE9KADAgECAhMzAAABwvp9hw5UU0ckAAEAAAHCMA0GCSqGSIb3DQEB
# CwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTIyMTEwNDE5MDEy
# OFoXDTI0MDIwMjE5MDEyOFowgcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMx
# JjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjhBODItRTM0Ri05RERBMSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEAtfEJvPKOSFn3petp9wco29/UoJmDDyHpmmpRruRVWBF3
# 7By0nvrszScOV/K+LvHWWWC4S9cme4P63EmNhxTN/k2CgPnIt/sDepyACSkya4uk
# qc1sT2I+0Uod0xjy9K2+jLH8UNb9vM3yH/vCYnaJSUqgtqZUly82pgYSB6tDeZIY
# cQoOhTI+M1HhRxmxt8RaAKZnDnXgLdkhnIYDJrRkQBpIgahtExtTuOkmVp2y8YCo
# FPaUhUD2JT6hPiDD7qD7A77PLpFzD2QFmNezT8aHHhKsVBuJMLPXZO1k14j0/k68
# DZGts1YBtGegXNkyvkXSgCCxt3Q8WF8laBXbDnhHaDLBhCOBaZQ8jqcFUx8ZJSXQ
# 8sbvEnmWFZmgM93B9P/JTFTF6qBVFMDd/V0PBbRQC2TctZH4bfv+jyWvZOeFz5yl
# tPLRxUqBjv4KHIaJgBhU2ntMw4H0hpm4B7s6LLxkTsjLsajjCJI8PiKi/mPKYERd
# mRyvFL8/YA/PdqkIwWWg2Tj5tyutGFtfVR+6GbcCVhijjy7l7otxa/wYVSX66Lo0
# alaThjc+uojVwH4psL+A1qvbWDB9swoKla20eZubw7fzCpFe6qs++G01sst1SaA0
# GGmzuQCd04Ue1eH3DFRDZPsN+aWvA455Qmd9ZJLGXuqnBo4BXwVxdWZNj6+b4P8C
# AwEAAaOCATYwggEyMB0GA1UdDgQWBBRGsYh76V41aUCRXE9WvD++sIfGajAfBgNV
# HSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBU
# aW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwG
# CCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRz
# L01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNV
# HRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IC
# AQARdu3dCkcLLPfaJ3rR1M7D9jWHvneffkmXvFIJtqxHGWM1oqAh+bqxpI7HZz2M
# eNhh1Co+E9AabOgj94Sp1seXxdWISJ9lRGaAAWzA873aTB3/SjwuGqbqQuAvUzBF
# CO40UJ9anpavkpq/0nDqLb7XI5H+nsmjFyu8yqX1PMmnb4s1fbc/F30ijaASzqJ+
# p5rrgYWwDoMihM5bF0Y0riXihwE7eTShak/EwcxRmG3h+OT+Ox8KOLuLqwFFl1si
# TeQCp+YSt4J1tWXapqGJDlCbYr3Rz8+ryTS8CoZAU0vSHCOQcq12Th81p7QlHZv9
# cTRDhZg2TVyg8Gx3X6mkpNOXb56QUohI3Sn39WQJwjDn74J0aVYMai8mY6/WOurK
# MKEuSNhCiei0TK68vOY7sH0XEBWnRSbVefeStDo94UIUVTwd2HmBEfY8kfryp3Rl
# A9A4FvfUvDHMaF9BtvU/pK6d1CdKG29V0WN3uVzfYETJoRpjLYFGq0MvK6QVMmuN
# xk3bCRfj1acSWee14UGjglxWwvyOfNJe3pxcNFOd8Hhyp9d4AlQGVLNotaFvopgP
# LeJwUT3dl5VaAAhMwvIFmqwsffQy93morrprcnv74r5g3ejC39NYpFEoy+qmzLW1
# jFa1aXE2Xb/KZw2yawqldSp0Hu4VEkjGxFNc+AztIUWwmTCCB3EwggVZoAMCAQIC
# EzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBS
# b290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoX
# DTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC
# 0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VG
# Iwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP
# 2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/P
# XfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361
# VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwB
# Sru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9
# X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269e
# wvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDw
# wvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr
# 9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+e
# FnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAj
# BgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+n
# FV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEw
# PwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9j
# cy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3
# FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAf
# BgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0Nl
# ckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4Swf
# ZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTC
# j/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu
# 2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/
# GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3D
# YXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbO
# xnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqO
# Cb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I
# 6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0
# zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaM
# mdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNT
# TY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggLOMIICNwIBATCB+KGB0KSBzTCByjEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046OEE4Mi1FMzRGLTlEREExJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAMp1N1VLhPMvWXEoZfmF4apZlnRUoIGD
# MIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEF
# BQACBQDnkAGvMCIYDzIwMjMwMjEwMDczNTExWhgPMjAyMzAyMTEwNzM1MTFaMHcw
# PQYKKwYBBAGEWQoEATEvMC0wCgIFAOeQAa8CAQAwCgIBAAICJkUCAf8wBwIBAAIC
# EbYwCgIFAOeRUy8CAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAK
# MAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOBgQBQOzfVNRSk
# 9EwM719WBtKwIxl84u2bSrQ/B1/G8HeqCUcEXJiO5WHAOZn8kQ28Z+xamj4+7fiX
# XpS6ftBqkpUP3CQj8KFg0DxAiefTweGqUcr5sb/A5uQmIkIEUrg7d7WMy6usNw96
# BM2y9eLF0x9+PsNOwBCc7Enfdlb2aPJJwzGCBA0wggQJAgEBMIGTMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABwvp9hw5UU0ckAAEAAAHCMA0GCWCG
# SAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZI
# hvcNAQkEMSIEIIfLqKnfE5rU7s8be6idRJZOTpYoUdcWUI7iA/rIgl6kMIH6Bgsq
# hkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgypNgW8fpsMV57r0F5beUuiEVOVe4Bdma
# O+e28mGDUBYwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAcL6fYcOVFNHJAABAAABwjAiBCA2YXOAZN3FpAfixP+aAVgGkxNXERjJ1k+C
# dHST+EZBhTANBgkqhkiG9w0BAQsFAASCAgB4aOsYDZDqKuI0tDap3/PaXdeCS/kS
# kUGjlEh8HUVKCzsAatfuCAyW8W+JurdIqNLMcaWpomiTCWbGolhd+4Tk7TjuCUAj
# HwC9d71MlQe5937I02Fi+wHIlHQd6b8W/EPAl1CcmcgxsWcMjP61ePl2eApJ8j0k
# yD7RSv9SGjkSYxf43TjxUAQwdrwQ3q9wuu+3aulu/6ql+GxD3f6k8+gedhUBq1Rb
# IkZPNyHB9EHoEqx5Bu9Yj9Y3AP+Wq+1O0+QEWN61tDjcLw5Bq5nAkB6QJdwdiOTV
# R7heebSfFctF8YGmMuB2tBW+QvEa+gtHMzhNVowduJ7TyJFS0Z1XRmGJzssPBi7G
# Z751+jK/bqaRVhL6uz8zjheFckswNVw6iHW4pczRTfnGCfZHNFc4yeT1VG8SRD8r
# xctJydTHkZUPimHjQdgstu6DrNSnDAcQntwNzbXnKm/vW7p5scfdPlYHBflYLc02
# KSY9mXXblV89S608g2JYzxjgWGoWQYteWcCsq4zSWcdZg1phi2WI/N+W2dCua8y2
# lBW9D1ZdVeWgRmFdTq0J1M1/cXT5rXJoHb6blxD8BdzB1bakn68z9lrVSJOHWjYZ
# FqjAEbZ35eQ0J5VVGVGxOrMUlYTJRACA8hqdWjAq/ZnaK+3htioUfUYlj72B7m4y
# Z7rSWIJmfJv3+Q==
# SIG # End signature block
