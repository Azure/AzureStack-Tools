# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information. 

<# 
 
.SYNOPSIS 
 
Prepare the host to boot from the Azure Stack virtual harddisk. 
 
.DESCRIPTION 
 
PrepareBootFromVHD updates the boot configuration with an Azure Stack entry. 
It will verify if the disk that hosts the CloudBuilder.vhdx contains the required free disk space, Optionally copy drivers and an unattend.xml that does not require KVM access.

 
.PARAMETER CloudBuilderDiskPath  
 
Path to the CloudBuilder.vhdx. This parameter is mandatory.

.PARAMETER DriverPath  
 
This optional parameter allows you to add additional drivers for the host in the virtual harddisk. Specify the path that contains the drivers and all its content wil be copied the to CloudBuilder.vhdx.
 
.PARAMETER ApplyUnattend 
 
ApplyUnattend is a switch parameter. If this parameter is specified, the configuration of the Operating System is automated. 
After the host reboots to the CloudBuilder.vhdx, the Operating System is automatically configured and you can connect to the host with RDP without KVM requirement.
If this parameter is specified, you will be prompted for an local administrator password that is used for the unattend.xml.
If this parameter is not specified, a minimal unattend.xml is used to enable Remote Desktop. KVM is required to configure the Operating System when booting from vs.vhdx for the first time.

.PARAMETER AdminPassword  
 
The AdminPassword parameter is only used when the ApplyUnnatend parameter is set. The Password requires minimal 6 characters.
 
.EXAMPLE 
 
Prepare the host to boot from CloudBuilder.vhdx. This requires KVM access to the host for configuring the Operating System.
.\PrepareBootFromVHD.ps1 -CloudBuilderPath c:\CloudBuilder.vhdx -DriverPath c:\VhdDrivers
 
.EXAMPLE  
 
Prepare the host to boot from CloudBuilder.vhdx. The Operating System is automatically configured with an unattend.xml.
.\PrepareBootFromVHD.ps1 -CloudBuilderPath c:\CloudBuilder.vhdx -ApplyUnattend
  
.NOTES 
 
You will need at least (120GB - Size of the CloudBuilder.vhdx file) of free disk space on the disk that contains the CloudBuilder.vhdx.
 
#>

[CmdletBinding()]
Param     (
    [Parameter(Mandatory=$true)]
    [String]$CloudBuilderDiskPath,

    [Parameter(Mandatory=$false)]
    [string[]]$DriverPath = $null,

    [Parameter(Mandatory = $false)]
    [switch]$ApplyUnattend,

    [Parameter(Mandatory = $false)]
    [String]$AdminPassword,

    [Parameter(Mandatory = $false)]
    [String]$VHDLanguage = "en-US"
    )

$error.Clear()

#region Allow for manual override of PS (replace $PSScriptRoot with a path)
$currentPath = $PSScriptRoot
# $currentPath = 'C:\ForRTMBuilds'
# $CloudBuilderDiskPath = 'C:\CloudBuilder.vhdx'
#endregion

#region Check parameters and prerequisites

if (-not (Test-Path -Path $CloudBuilderDiskPath)) {
    Write-Host "Can't find CloudBuilder.vhdx." -ForegroundColor Red
    Exit
}

if ((Get-DiskImage -ImagePath $CloudBuilderDiskPath).Attached) {
    Write-Host "CloudBuilder.vhdx is already mounted." -ForegroundColor Red
    Exit
}

# Validate the CloudBuilder.vhdx is in a physical disk   
$cbhDriveLetter = (Get-Item $CloudBuilderDiskPath).PSDrive.Name

if (-not $cbhDriveLetter) {
    Write-Host "The given CloudBuilder.vhdx path is not a local path." -ForegroundColor Red
    Exit
}
else {
    $hostDisk = Get-Partition -DriveLetter $cbhDriveLetter | Get-Disk
    if ($hostDisk.Model -match 'Virtual Disk') {
        Write-Host "The CloudBuilder.vhdx is in a virtual hard disk, please place it in a physical disk." -ForegroundColor Red
        Exit
    }
}

if ($ApplyUnattend) {
    # Check if unattend_NoKVM.xml is downloaded
    $unattendRawFile = Join-Path $currentPath 'unattend_NoKVM.xml'
    if (-not (Test-Path $unattendRawFile)) {
        Write-Host "-ApplyUnattend is specified, but unattend_NoKVM.xml is not downloaded to the same directory of this script." -ForegroundColor Red
        Exit
    }

    # Check Admin password for unattend
    if(-not $AdminPassword) {
        while ($SecureAdminPassword.Length -le 6) {
            [System.Security.SecureString]$SecureAdminPassword = read-host 'Password for the local administrator account of the Azure Stack host. Requires 6 characters minimum' -AsSecureString
        }
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureAdminPassword)
        $AdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        Write-Host "The following password will be configured for the local administrator account of the Azure Stack host:"
        Write-Host $AdminPassword -ForegroundColor Cyan
    }
}

# Validate disk space for expanding cloudbuilder.vhdx
$cbhDiskSize = [math]::truncate((get-volume -DriveLetter $cbhDriveLetter).Size / 1GB)
$cbhDiskRemaining = [math]::truncate((get-volume -DriveLetter $cbhDriveLetter).SizeRemaining / 1GB)
$cbDiskSize = [math]::truncate((Get-Item $CloudBuilderDiskPath).Length / 1GB)
$cbDiskSizeReq = 120
if (($cbDiskSizeReq - $cbDiskSize) -ge $cbhDiskRemaining) {
    Write-Host 'Error: Insufficient disk space' -BackgroundColor Red
    Write-Host 'Cloudbuilder.vhdx is placed on' ((Get-Item $CloudBuilderDiskPath).PSDrive.Root) -ForegroundColor Yellow
    Write-Host 'When you boot from CloudBuilder.vhdx the virtual hard disk will be expanded to its full size of' $cbDiskSizeReq 'GB.' -ForegroundColor Yellow
    Write-Host ((Get-Item $CloudBuilderDiskPath).PSDrive.Root) 'does not contain enough free space.' -ForegroundColor Yellow
    Write-Host 'You need' ($cbDiskSizeReq - $cbDiskSize) 'GB of free disk space for a succesfull boot from CloudBuilder.vhdx, but' ((Get-Item $CloudBuilderDiskPath).PSDrive.Root) 'only has' $cbhDiskRemaining 'GB remaining.' -ForegroundColor Yellow
    Write-Host 'Ensure Cloudbuilder.vhdx is placed on a local disk that contains enough free space and rerun this script.' -ForegroundColor Yellow
    Write-Host 'Exiting..' -ForegroundColor Yellow
    Exit
}
#endregion

#region Prepare Azure Stack virtual harddisk

Write-Host "Preparing Azure Stack virtual harddisk"
$cbdisk = Mount-DiskImage -ImagePath $CloudBuilderDiskPath -PassThru | Get-DiskImage | Get-Disk    
$partitions = $cbdisk | Get-Partition | Sort-Object -Descending -Property Size
$CBDriveLetter = $partitions[0].DriveLetter

# ApplyUnattend
if($ApplyUnattend) {
    Write-Host "Apply unattend.xml with given password and language" -ForegroundColor Cyan
    $UnattendedFile = Get-Content ($currentPath + '\unattend_NoKVM.xml')
    $UnattendedFile = ($UnattendedFile).Replace('%productkey%', '74YFP-3QFB3-KQT8W-PMXWJ-7M648')
    $UnattendedFile = ($UnattendedFile).Replace('%locale%', $VHDLanguage)
    $UnattendedFile = ($UnattendedFile).Replace('%adminpassword%', $AdminPassword)
    $UnattendedFile | Out-File ($CBDriveLetter+":\unattend.xml") -Encoding ascii
}
else {
# Apply defautl unattend.xml if it exists
    $defaultUnattend = Join-Path $currentPath 'Unattend.xml'
    if (Test-Path $defaultUnattend) {
        Write-Host "Apply default unattend.xml to disable IE-ESC and enable remote desktop" -ForegroundColor Cyan
        Copy-Item $defaultUnattend -Destination ($CBDriveLetter + ':\') -Force
    }
}

# Add drivers
if (-not $DriverPath) {
    Write-Host "Apply given drivers" -ForegroundColor Cyan
    foreach ($subdirectory in $DriverPath) {
        Add-WindowsDriver -Driver $subdirectory -Path "$($CBDriveLetter):\" -Recurse
    }
}
#endregion

#region Configure boot options

# Remove boot from previous deployment
$bootOptions = bcdedit /enum  | Select-String 'path' -Context 2,1
$bootOptions | ForEach {
    if ((($_.Context.PreContext[1] -replace '^device +') -like '*CloudBuilder.vhdx*') `
        -and ((($_.Context.PostContext[0] -replace '^description +') -eq 'AzureStack TP2') `
              -or (($_.Context.PostContext[0] -replace '^description +') -eq 'Azure Stack'))) {
        Write-Host 'The boot configuration contains an existing CloudBuilder.vhdx entry' -ForegroundColor Cyan
        Write-Host 'Description:' ($_.Context.PostContext[0] -replace '^description +') -ForegroundColor Cyan
        Write-Host 'Device:' ($_.Context.PreContext[1] -replace '^device +') -ForegroundColor Cyan
        Write-Host 'Removing the old entry'
        $BootID = '"' + ($_.Context.PreContext[0] -replace '^identifier +') + '"'
        Write-Host 'bcdedit /delete' $BootID -ForegroundColor Yellow
        bcdedit /delete $BootID
    }
}

# Add boot entry for CloudBuilder.vhdx
Write-Host 'Creating new boot entry for CloudBuilder.vhdx' -ForegroundColor Cyan
Write-Host 'Running command: bcdboot' $CBDriveLetter':\Windows' -ForegroundColor Yellow
bcdboot $CBDriveLetter':\Windows'

$bootOptions = bcdedit /enum  | Select-String 'path' -Context 2,1
$bootOptions | ForEach {
    if ((($_.Context.PreContext[1] -replace '^device +') -eq ('partition='+$CBDriveLetter+':') `
         -or (($_.Context.PreContext[1] -replace '^device +') -like '*CloudBuilder.vhdx*')) `
        -and (($_.Context.PostContext[0] -replace '^description +') -ne 'Azure Stack')) {
        Write-Host 'Updating description for the boot entry' -ForegroundColor Cyan
        Write-Host 'Description:' ($_.Context.PostContext[0] -replace '^description +') -ForegroundColor Cyan
        Write-Host 'Device:' ($_.Context.PreContext[1] -replace '^device +') -ForegroundColor Cyan
        $BootID = '"' + ($_.Context.PreContext[0] -replace '^identifier +') + '"'
        Write-Host 'bcdedit /set' $BootID 'description "Azure Stack"' -ForegroundColor Yellow
        bcdedit /set $BootID description "Azure Stack"
    }
}
#endregion

if(-not $error) {
    Write-Host "Restart computer to boot from Azure Stack virtual harddisk" -ForegroundColor Cyan
    ### Restart Computer ###
    Restart-Computer -Confirm
}
else {
    Write-Host "Fail to prepare CloudBuilder.vhdx. Errors: $($error)" -ForegroundColor Red
}
# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUuQicUlNJcHM+XZ3iMxTZjHZu
# IbCgghhlMIIEwzCCA6ugAwIBAgITMwAAAMlkTRbbGn2zFQAAAAAAyTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODU0
# WhcNMTgwOTA3MTc1ODU0WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkIxQjctRjY3Ri1GRUMyMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAotVXnfm6iRvJ
# s2GZXZXB2Jr9GoHX3HNAOp8xF/cnCE3fyHLwo1VF+TBQvObTTbxxdsUiqJ2Ew8DL
# jW8dolC9WqrPuP9Wj0gJNAdhnAYjtZN5fYEoGIsHBtuR3k+UxD2W7VWfjPDTY2zH
# e44WzfDvL2aXL2fomH73B7cx7YjT/7Du7vSdAHbr7SEdIyGJ5seMa+Y9MBJI48wZ
# A9CSnTGTFvhMXCYJuoR6Xc34A0EdHiTzfxY2tEWSiw5Xr+Oottc4IIHksNttYMgw
# HCu+tKqUlDkq5EdELh067r2Mv+OVkUkDQnLd1Vh/bP+yz92NKw7THQDYN7/4MTD2
# faNVsutryQIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFB7ZK3kpWqMOy6M4tybE49oI
# BMpsMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBACvoEvJ84B3DuFj+SDfpkM3OCxYon2F4wWTOQmpDmTwysrQ0
# grXhxNqMVL7QRKk34of1uvckfIhsjnckTjkaFJk/bQc8n5wwTzCKJ3T0rV/Vasoh
# MbGm4y3UYEh9nflmKbPpNhps20EeU9sdNIkxsrpQsPwk59wv13STtUjywuTvpM5s
# 1dQOIiUWrAMR14ZzOSBA7kgWI+UEj5iaGYOczxD+wH+07llzwlIC4TyRXtgKFuMF
# AONNNYUedbi6oOX7IPo0hb5RVPuVqAFxT98xIheJXNod9lf2JLhGD+H/pXnkZJRr
# VjJFcuJeEAnYAe7b97+BfhbPgv8V9FIAwqTxgxIwggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TCCBhEwggP5
# oAMCAQICEzMAAACOh5GkVxpfyj4AAAAAAI4wDQYJKoZIhvcNAQELBQAwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xNjExMTcyMjA5MjFaFw0xODAy
# MTcyMjA5MjFaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQh9RCK36d2cZ61KLD4xWS
# 0lOdlRfJUjb6VL+rEK/pyefMJlPDwnO/bdYA5QDc6WpnNDD2Fhe0AaWVfIu5pCzm
# izt59iMMeY/zUt9AARzCxgOd61nPc+nYcTmb8M4lWS3SyVsK737WMg5ddBIE7J4E
# U6ZrAmf4TVmLd+ArIeDvwKRFEs8DewPGOcPUItxVXHdC/5yy5VVnaLotdmp/ZlNH
# 1UcKzDjejXuXGX2C0Cb4pY7lofBeZBDk+esnxvLgCNAN8mfA2PIv+4naFfmuDz4A
# lwfRCz5w1HercnhBmAe4F8yisV/svfNQZ6PXlPDSi1WPU6aVk+ayZs/JN2jkY8fP
# AgMBAAGjggGAMIIBfDAfBgNVHSUEGDAWBgorBgEEAYI3TAgBBggrBgEFBQcDAzAd
# BgNVHQ4EFgQUq8jW7bIV0qqO8cztbDj3RUrQirswUgYDVR0RBEswSaRHMEUxDTAL
# BgNVBAsTBE1PUFIxNDAyBgNVBAUTKzIzMDAxMitiMDUwYzZlNy03NjQxLTQ0MWYt
# YmM0YS00MzQ4MWU0MTVkMDgwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1
# ApUwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEF
# BQcBAQRVMFMwUQYIKwYBBQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNV
# HRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBEiQKsaVPzxLa71IxgU+fKbKhJ
# aWa+pZpBmTrYndJXAlFq+r+bltumJn0JVujc7SV1eqVHUqgeSxZT8+4PmsMElSnB
# goSkVjH8oIqRlbW/Ws6pAR9kRqHmyvHXdHu/kghRXnwzAl5RO5vl2C5fAkwJnBpD
# 2nHt5Nnnotp0LBet5Qy1GPVUCdS+HHPNIHuk+sjb2Ns6rvqQxaO9lWWuRi1XKVjW
# kvBs2mPxjzOifjh2Xt3zNe2smjtigdBOGXxIfLALjzjMLbzVOWWplcED4pLJuavS
# Vwqq3FILLlYno+KYl1eOvKlZbiSSjoLiCXOC2TWDzJ9/0QSOiLjimoNYsNSa5jH6
# lEeOfabiTnnz2NNqMxZQcPFCu5gJ6f/MlVVbCL+SUqgIxPHo8f9A1/maNp39upCF
# 0lU+UK1GH+8lDLieOkgEY+94mKJdAw0C2Nwgq+ZWtd7vFmbD11WCHk+CeMmeVBoQ
# YLcXq0ATka6wGcGaM53uMnLNZcxPRpgtD1FgHnz7/tvoB3kH96EzOP4JmtuPe7Y6
# vYWGuMy8fQEwt3sdqV0bvcxNF/duRzPVQN9qyi5RuLW5z8ME0zvl4+kQjOunut6k
# LjNqKS8USuoewSI4NQWF78IEAA1rwdiWFEgVr35SsLhgxFK1SoK3hSoASSomgyda
# Qd691WZJvAuceHAJvDCCB3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEx
# MB4XDTExMDcwODIwNTkwOVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUg
# U2lnbmluZyBQQ0EgMjAxMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AKvw+nIQHC6t2G6qghBNNLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL
# 8DjCmQawyDnVARQxQtOJDXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/X
# llnKYBoF6WZ26DJSJhIv56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5k
# NXimoGMPLdNAk/jj3gcN1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJ
# Xtjt7UORg9l7snuGG9k+sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4
# ftKdgCz1TlaRITUlwzluZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgo
# tswnKDglmDlKNs98sZKuHCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0Xpb
# L9Uj43BdD1FGd7P4AOG8rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy
# 5yTfv0aZxe/CHFfbg43sTUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9
# Z4DmimJ4X7IvhNdXnFy/dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4
# IFgsE11glZo+TzOE2rCIF96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQ
# BgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUw
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0f
# BFMwUTBPoE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcB
# AQRSMFAwTgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kv
# Y2VydHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGX
# MIGUMIGRBgkrBgEEAYI3LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcC
# AjA0HjIgHQBMAGUAZwBhAGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUA
# bgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFj
# kplCln3SeQyQwWVfLiw++MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtG
# UFXYDJJ80hpLHPM8QotS0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32m
# kHSDjfTLJgJGKsKKELukqQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr
# 3vw70L01724lruWvJ+3Q3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYK
# wsatruWy2dsViFFFWDgycScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6C
# PxNNZgvAs0314Y9/HG8VfUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX
# 0O5dY0HjWwechz4GdwbRBrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADW
# oUa9WfOXpQlLSBCZgB/QACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9r
# t0uX4ut1eBrs6jeZeRhL/9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGd
# Vk5Pv4BXIqF4ETIheu9BCrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9
# bW1qyVJzEw16UM0xggTlMIIE4QIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5n
# IFBDQSAyMDExAhMzAAAAjoeRpFcaX8o+AAAAAACOMAkGBSsOAwIaBQCggfkwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFG+Vq3SEEN4bx7/R7Gx1ax934kKWMIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEAyoBJW/ddelZdvJdQi/jWtk3I0OwCd3G6
# 41t4G5V13h4SPisOe8VvUUUxJPwJDvTuXr/oBN/AXD3lv3UBu0z1diAl6PpadLzD
# uBO4vRxEOtFiTd4Ma48pl6YrbXzERl7I6EaqnnvOcBd+uiEV1phoJoRWjmjMDT0z
# ZVPtuSlz7tycC0gp4xanWgg3KkwyUGR5RMWfKrsx5Lqnvp/UxWgYoH1TP2w2QOZM
# SkvXRHaJuWauY7FMBaVbg69+AtdOzBPWusup6y9ut8PejvavEQ8sJAGXC08s+osM
# 9JgDrgx/csbwrD2deJPCELBd7JjAqsv5z9SsXkRpQEPIPXfvK46JN6GCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADJZE0W2xp9sxUAAAAAAMkwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxNlowIwYJ
# KoZIhvcNAQkEMRYEFPWN+rut6s0QQGx83fJMiPBaNMMOMA0GCSqGSIb3DQEBBQUA
# BIIBAJDOukpDe2korvw42pMzrHTI4egr0AzLBatgs1NgR26CtwjOSeR5cM35XQJE
# QYb8Z4Ave44CL4wUljxNlDhgEIaOvrTDy0rPJGW2D9lEnPuYND8qLl3R84krXAsf
# vFQIc9ZycEc9a+P4i/jVFivwkFODi5R+4fooIWtla2JSEwjazxYm9nPOF7DZJ5Ce
# IGQroeg3zxPUhLoW/XiqJ7EWAh6dCTCBXk3UMk9RpJZMudx4NnI2FhFla0nX659S
# qRjV7DBJlyMMGpJYYvbp9c7VUv6nkHCkn9XIByobWYiuEx2HBO+Btn4KTlD52z1u
# EZ4LQywA70u8DB/CWkm/9WiePvc=
# SIG # End signature block
