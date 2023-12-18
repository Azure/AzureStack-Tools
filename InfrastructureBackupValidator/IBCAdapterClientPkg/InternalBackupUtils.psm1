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
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA8aoEUsVRaGaSz
# AlLYSgboZtLf/o/AjTKqqjeXf6CJ4aCCDXYwggX0MIID3KADAgECAhMzAAADTrU8
# esGEb+srAAAAAANOMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMwMzE2MTg0MzI5WhcNMjQwMzE0MTg0MzI5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDdCKiNI6IBFWuvJUmf6WdOJqZmIwYs5G7AJD5UbcL6tsC+EBPDbr36pFGo1bsU
# p53nRyFYnncoMg8FK0d8jLlw0lgexDDr7gicf2zOBFWqfv/nSLwzJFNP5W03DF/1
# 1oZ12rSFqGlm+O46cRjTDFBpMRCZZGddZlRBjivby0eI1VgTD1TvAdfBYQe82fhm
# WQkYR/lWmAK+vW/1+bO7jHaxXTNCxLIBW07F8PBjUcwFxxyfbe2mHB4h1L4U0Ofa
# +HX/aREQ7SqYZz59sXM2ySOfvYyIjnqSO80NGBaz5DvzIG88J0+BNhOu2jl6Dfcq
# jYQs1H/PMSQIK6E7lXDXSpXzAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUnMc7Zn/ukKBsBiWkwdNfsN5pdwAw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMDUxNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAD21v9pHoLdBSNlFAjmk
# mx4XxOZAPsVxxXbDyQv1+kGDe9XpgBnT1lXnx7JDpFMKBwAyIwdInmvhK9pGBa31
# TyeL3p7R2s0L8SABPPRJHAEk4NHpBXxHjm4TKjezAbSqqbgsy10Y7KApy+9UrKa2
# kGmsuASsk95PVm5vem7OmTs42vm0BJUU+JPQLg8Y/sdj3TtSfLYYZAaJwTAIgi7d
# hzn5hatLo7Dhz+4T+MrFd+6LUa2U3zr97QwzDthx+RP9/RZnur4inzSQsG5DCVIM
# pA1l2NWEA3KAca0tI2l6hQNYsaKL1kefdfHCrPxEry8onJjyGGv9YKoLv6AOO7Oh
# JEmbQlz/xksYG2N/JSOJ+QqYpGTEuYFYVWain7He6jgb41JbpOGKDdE/b+V2q/gX
# UgFe2gdwTpCDsvh8SMRoq1/BNXcr7iTAU38Vgr83iVtPYmFhZOVM0ULp/kKTVoir
# IpP2KCxT4OekOctt8grYnhJ16QMjmMv5o53hjNFXOxigkQWYzUO+6w50g0FAeFa8
# 5ugCCB6lXEk21FFB1FdIHpjSQf+LP/W2OV/HfhC3uTPgKbRtXo83TZYEudooyZ/A
# Vu08sibZ3MkGOJORLERNwKm2G7oqdOv4Qj8Z0JrGgMzj46NFKAxkLSpE5oHQYP1H
# tPx1lPfD7iNSbJsP6LiUHXH1MIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGZ8wghmbAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAANOtTx6wYRv6ysAAAAAA04wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIE1SDabzOUVIGrN20fMvh2m5
# D44gvXx6yaAWsh4wjvyuMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEA2St0tdGGnh9Zli60q3IS5Wy2hi0CI7tHIqb6XNPO/26EFgce/2RxepHg
# NYUxRniL6UIruxNZtEqdR0ABQEZtLXpIdYnq6P0rGiaAPHKZ3szQToXqmAo+z2XZ
# 6yZ9RRulSFObLKIaUwKFTGOLmCHKjGxC8FawAooxGM5dH0OjHQ4yL6Rzfqqpk5zh
# ItCnqZ62yBkFnTNKi7Sy9Oun5GRvEqh4UmpK0PrulsegRC+X1t4XIucqS1ts0CQR
# aRtX43FyjIJPPJZpOUfOMvu9EHb0dVShH4XhwfF/G6uex1RsrC8uQ+cUUAfjEF1E
# A5e7Nm764KEkQ8B3J2iGJRv4VpT2VqGCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBp1tYtfkXpQ56wCZ4jU1yNdvhQ4S+w4yySD87JlzJaZQIGZUK6Y0KN
# GBMyMDIzMTExMzA3MTM0NS4wNDZaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNO
# OjA4NDItNEJFNi1DMjlBMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIReDCCBycwggUPoAMCAQICEzMAAAHajtXJWgDREbEAAQAAAdowDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjMx
# MDEyMTkwNjU5WhcNMjUwMTEwMTkwNjU5WjCB0jELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjowODQyLTRC
# RTYtQzI5QTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJOQBgh2tVFR1j8jQA4NDf8b
# cVrXSN080CNKPSQo7S57sCnPU0FKF47w2L6qHtwm4EnClF2cruXFp/l7PpMQg25E
# 7X8xDmvxr8BBE6iASAPCfrTebuvAsZWcJYhy7prgCuBf7OidXpgsW1y8p6Vs7sD2
# aup/0uveYxeXlKtsPjMCplHkk0ba+HgLho0J68Kdji3DM2K59wHy9xrtsYK+X9er
# bDGZ2mmX3765aS5Q7/ugDxMVgzyj80yJn6ULnknD9i4kUQxVhqV1dc/DF6UBeuzf
# ukkMed7trzUEZMRyla7qhvwUeQlgzCQhpZjz+zsQgpXlPczvGd0iqr7lACwfVGog
# 5plIzdExvt1TA8Jmef819aTKwH1IVEIwYLA6uvS8kRdA6RxvMcb//ulNjIuGceyy
# kMAXEynVrLG9VvK4rfrCsGL3j30Lmidug+owrcCjQagYmrGk1hBykXilo9YB8Qyy
# 5Q1KhGuH65V3zFy8a0kwbKBRs8VR4HtoPYw9z1DdcJfZBO2dhzX3yAMipCGm6Smv
# mvavRsXhy805jiApDyN+s0/b7os2z8iRWGJk6M9uuT2493gFV/9JLGg5YJJCJXI+
# yxkO/OXnZJsuGt0+zWLdHS4XIXBG17oPu5KsFfRTHREloR2dI6GwaaxIyDySHYOt
# vIydla7u4lfnfCjY/qKTAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUoXyNyVE9ZhOV
# izEUVwhNgL8PX0UwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBALmDVdTtuI0jAEt4
# 1O2OM8CU237TGMyhrGr7FzKCEFaXxtoqk/IObQriq1caHVh2vyuQ24nz3TdOBv7r
# cs/qnPjOxnXFLyZPeaWLsNuARVmUViyVYXjXYB5DwzaWZgScY8GKL7yGjyWrh78W
# JUgh7rE1+5VD5h0/6rs9dBRqAzI9fhZz7spsjt8vnx50WExbBSSH7rfabHendpeq
# bTmW/RfcaT+GFIsT+g2ej7wRKIq/QhnsoF8mpFNPHV1q/WK/rF/ChovkhJMDvlqt
# ETWi97GolOSKamZC9bYgcPKfz28ed25WJy10VtQ9P5+C/2dOfDaz1RmeOb27Kbeg
# ha0SfPcriTfORVvqPDSa3n9N7dhTY7+49I8evoad9hdZ8CfIOPftwt3xTX2RhMZJ
# CVoFlabHcvfb84raFM6cz5EYk+x1aVEiXtgK6R0xn1wjMXHf0AWlSjqRkzvSnRKz
# FsZwEl74VahlKVhI+Ci9RT9+6Gc0xWzJ7zQIUFE3Jiix5+7KL8ArHfBY9UFLz4sn
# boJ7Qip3IADbkU4ZL0iQ8j8Ixra7aSYfToUefmct3dM69ff4Eeh2Kh9NsKiiph58
# 9Ap/xS1jESlrfjL/g/ZboaS5d9a2fA598mubDvLD5x5PP37700vm/Y+PIhmp2fTv
# uS2sndeZBmyTqcUNHRNmCk+njV3nMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
# mQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNh
# dGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1
# WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjK
# NVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhg
# fWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJp
# rx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/d
# vI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka9
# 7aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKR
# Hh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9itu
# qBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyO
# ArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItb
# oKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6
# bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6t
# AgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQW
# BBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacb
# UzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYz
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnku
# aHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIA
# QwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2
# VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwu
# bWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEw
# LTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/q
# XBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6
# U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVt
# I1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis
# 9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTp
# kbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0
# sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138e
# W0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJ
# sWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7
# Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0
# dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQ
# tB1VM1izoXBm8qGCAtQwggI9AgEBMIIBAKGB2KSB1TCB0jELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxh
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjow
# ODQyLTRCRTYtQzI5QTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAQqIfIYljHUbNoY0/wjhXRn/sSA2ggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOj7uKQwIhgPMjAyMzExMTMwNDQ4MzZaGA8yMDIzMTExNDA0NDgzNlowdDA6Bgor
# BgEEAYRZCgQBMSwwKjAKAgUA6Pu4pAIBADAHAgEAAgIBYjAHAgEAAgISqjAKAgUA
# 6P0KJAIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAID
# B6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAC0wIED0ScS8Gb0r3tGo
# ElIKFGOlRWfTNU06PtLc5CIDO+l1Um1B1+IeYjdhIlOJnRmTeXmXz4+8/r3VP9XM
# iCUqlQWi6S/OvpMDcCzivpIPQdXIo8Sr7Di3lF0sE3P85tTaUvAxVaqvze4q8tHO
# spKB5TFoVKpaM682Chd1ihHVMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTACEzMAAAHajtXJWgDREbEAAQAAAdowDQYJYIZIAWUDBAIB
# BQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQx
# IgQg5LocpUmON6W0zdA3hv8+e3py1kzMUssZRNk+Kl42wQEwgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCAipaNpYsDvnqTe95Dj1C09020I5ljibrW/ndICOxg9
# xjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB2o7V
# yVoA0RGxAAEAAAHaMCIEIAPGASDXQaR+/wRJpR5yz6T24kPw999Oq0Vp4fBkxnhO
# MA0GCSqGSIb3DQEBCwUABIICAGxlyM9O3whRxhL2OUMSShgvtE7gOmByiyXplmWl
# 2zIsvbcgIJddgQQL6vymRLM/tUt/N+6BCMb9HH/yQkUG0Yik2glfBSJQojexWmlq
# rBgSNTxg5Uj48bsnJtzwOcQavJoE5T59eaLkxoo2izZKjDgHe7QOKsHLIn5TExXo
# lmBemzkK8KK3ZgvG2KM2sk6Fht5TcXgdck0I0aOBUnB17QvJXUAt+2DWV/w5KDH+
# gZjjpjF/+TOd0hSLh21fMS5OglJwjwi8l2lLvDoGvYzOQH4r3rA6i9uM97scpAE6
# ovY8eWLjBnENLfB3kHeZGBaK4V80+h5P4+Msws7kzAPbK9KmszxBQLpqTR1blzp4
# OJQCLGvpgy6BzT8CygkblvydWczCkEkFw34hyA/wklrYIdXT/X16eGwd4/UcDkLy
# FJJz9ZdXZjkVDSftTJwBv4859IT9Zyme/5rpyV/Y62rs+qvQ+giL9mjY+nJ4rfUe
# PqnGcgBD0WUets866CqF6lJgVbpQJn0MigZK0nM9NUc8BN6fIzKGoHHRp0/9H5ov
# 6JgZB0Z0J6481OnIPlyoQ8hjlsvysIQ+CyG5NHgYNY3DPyMj8MFx8f9k8DeCMbFP
# mkVoDgQ+EfXqRxo/dubGDcmfgLdLELPPiq7PzzKUeOs58VWTBKfV4BQBs9Bsbr4A
# b5p1
# SIG # End signature block
