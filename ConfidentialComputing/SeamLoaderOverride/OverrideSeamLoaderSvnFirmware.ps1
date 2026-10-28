# Copyright (c) Microsoft Corporation. All rights reserved.

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("read", "write", "apply", "remove")]
    [string]$Operation,
    
    [Parameter(Mandatory = $false)]
    [byte[]]$Value
    )

# Validate that Value is provided for write operations
if ("write" -eq $Operation -and
    (-not $PSBoundParameters.ContainsKey("Value") -or $null -eq $Value -or $Value.Length -eq 0)) {
    Write-Error "Value parameter is required for write operations"
    exit 1
}

# Value is only supported for write operations
if ("write" -ne $Operation -and $PSBoundParameters.ContainsKey("Value")) {
    Write-Error "Value parameter is only supported for write operations"
    exit 1
}

Add-Type -TypeDefinition @'
 using System;
 using System.Runtime.InteropServices;
 using System.Text;

 public class UEFIMethods
 {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern UInt32 GetFirmwareEnvironmentVariable(string lpName, string lpGuid, [Out] Byte[] lpBuffer, UInt32 nSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern UInt32 SetFirmwareEnvironmentVariable(string lpName, string lpGuid, Byte[] lpBuffer, UInt32 nSize);
 }
'@

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class NtDll
{
    [DllImport("ntdll.dll", EntryPoint="RtlAdjustPrivilege")]
    public static extern int RtlAdjustPrivilege(
        UInt32 Privilege,
        [MarshalAs(UnmanagedType.U1)] bool Enable,
        [MarshalAs(UnmanagedType.U1)] bool CurrentThread,
        [MarshalAs(UnmanagedType.U1)] ref bool Enabled);
}
"@

<#
.SYNOPSIS
Enables or disables a privilege for the current process.

.DESCRIPTION
Calls RtlAdjustPrivilege for the specified privilege and optionally returns
whether the privilege was enabled before the call.

.PARAMETER Privilege
The numeric identifier of the privilege to adjust.

.PARAMETER Enable
Specifies whether to enable or disable the privilege.

.PARAMETER PreviouslyEnabled
An optional reference that receives the privilege's state before the call.

.OUTPUTS
System.Int32. The NTSTATUS value returned by RtlAdjustPrivilege.
#>
function Set-Privilege {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 64)]
        [uint32]$Privilege,
        [Parameter(Mandatory = $true)]
        [bool]$Enable,
        [Parameter(Mandatory = $false)]
        [ref]$PreviouslyEnabled
    )
    $wasEnabled = $false
    $result = [NtDll]::RtlAdjustPrivilege($Privilege, $Enable, $false, [ref]$wasEnabled)
    if ($null -ne $PreviouslyEnabled) {
        $PreviouslyEnabled.Value = $wasEnabled
    }
    return $result
}

<#
.SYNOPSIS
Sets a UEFI firmware environment variable.

.DESCRIPTION
Writes a byte array to the specified UEFI firmware variable. If the native
operation fails, the function writes the associated Win32 error with a
Win32Exception containing the native error code.

.PARAMETER VariableName
The name of the UEFI firmware variable.

.PARAMETER Namespace
The GUID string identifying the variable's UEFI namespace.

.PARAMETER Value
The byte array to write to the UEFI firmware variable.

.OUTPUTS
System.UInt32. A nonzero value indicates success; zero indicates failure.
#>
function Set-FirmwareEnvironmentVariable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VariableName,
        [Parameter(Mandatory = $true)]
        [string]$Namespace,
        [Parameter(Mandatory = $true)]
        [byte[]]$Value
    )
    $Size = $Value.Length
    $result = [UEFIMethods]::SetFirmwareEnvironmentVariable($VariableName, $Namespace, $Value, $Size)
    if ($result -eq 0) {
        $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $exception = [System.ComponentModel.Win32Exception]::new($lastError)
        Write-Error -Exception $exception -Message "Failed to set firmware environment variable. Win32 Error: $lastError"
    }

    return $result
}

<#
.SYNOPSIS
Removes a UEFI firmware environment variable.

.DESCRIPTION
Deletes the specified UEFI firmware variable by setting its value size to zero.
If the native operation fails, the function writes the associated Win32 error
with a Win32Exception containing the native error code.

.PARAMETER VariableName
The name of the UEFI firmware variable.

.PARAMETER Namespace
The GUID string identifying the variable's UEFI namespace.

.OUTPUTS
System.UInt32. A nonzero value indicates success; zero indicates failure.
#>
function Remove-FirmwareEnvironmentVariable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VariableName,
        [Parameter(Mandatory = $true)]
        [string]$Namespace
    )
    $result = [UEFIMethods]::SetFirmwareEnvironmentVariable($VariableName, $Namespace, $null, 0)
    if ($result -eq 0) {
        $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $exception = [System.ComponentModel.Win32Exception]::new($lastError)
        Write-Error -Exception $exception -Message "Failed to remove firmware environment variable. Win32 Error: $lastError"
    }

    return $result
}

<#
.SYNOPSIS
Gets a UEFI firmware environment variable.

.DESCRIPTION
Reads the specified UEFI firmware variable into a byte array. If the native
operation fails, the function writes the associated Win32 error with a
Win32Exception containing the native error code and returns null.

.PARAMETER VariableName
The name of the UEFI firmware variable.

.PARAMETER Namespace
The GUID string identifying the variable's UEFI namespace.

.PARAMETER BufferSize
The number of bytes to allocate for the native read buffer.

.OUTPUTS
System.Byte[]. The firmware variable data, or null if the read fails.
#>
function Get-FirmwareEnvironmentVariable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VariableName,
        [Parameter(Mandatory = $true)]
        [string]$Namespace,
        [Parameter(Mandatory = $false)]
        [uint32]$BufferSize = 1024
    )
    
    # Create buffer to hold the variable data
    $buffer = New-Object byte[] $BufferSize
    
    # Call the Windows API
    $bytesReturned = [UEFIMethods]::GetFirmwareEnvironmentVariable($VariableName, $Namespace, $buffer, $BufferSize)
    
    if ($bytesReturned -eq 0) {
        $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $exception = [System.ComponentModel.Win32Exception]::new($lastError)
        Write-Error -Exception $exception -Message "Failed to get firmware environment variable. Win32 Error: $lastError"
        return $null
    }
    
    # Resize buffer to actual data size
    $returnData = New-Object byte[] $bytesReturned
    [Array]::Copy($buffer, $returnData, $bytesReturned)
    
    return $returnData
}

# SE_SYSTEM_ENVIRONMENT_PRIVILEGE (SeSystemEnvironmentPrivilege) is required to access UEFI firmware variables.
$SystemEnvironmentPrivilege = [uint32]22

# Enable privilege
$privilegeWasEnabled = $false
$result = Set-Privilege -Privilege $SystemEnvironmentPrivilege -Enable $true -PreviouslyEnabled ([ref]$privilegeWasEnabled)
if ($result -ne 0) {
    Write-Error "Failed to enable privilege. Error code: $result"
    exit 1
}

$VariableName = "VAR_UEFI_SEAM_LOADER_SVN"
$Namespace = '{ffe88134-0c2f-4f69-a9ac-d8f5ad185e23}'
$OverrideValue = [byte]255

try {
    switch ($Operation) {
        # Apply the SEAM Loader SVN firmware override.
        "apply" {
            Write-Host "Applying the SEAM Loader SVN firmware override..."
            $result = Set-FirmwareEnvironmentVariable -VariableName $VariableName -Namespace $Namespace -Value ([byte[]]@($OverrideValue))
            if ($result -ne 0) {
                Write-Host "SEAM Loader SVN firmware override applied successfully."
                Write-Host "Variable: $VariableName"
                Write-Host "Value: $OverrideValue"
            } else {
                exit 1
            }
        }

        # Remove the SEAM Loader SVN firmware override.
        "remove" {
            Write-Host "Removing the SEAM Loader SVN firmware override..."
            $result = Remove-FirmwareEnvironmentVariable -VariableName $VariableName -Namespace $Namespace
            if ($result -ne 0) {
                Write-Host "SEAM Loader SVN firmware override removed successfully."
                Write-Host "Variable: $VariableName"
            } else {
                exit 1
            }
        }

        "write" {
            Write-Host "Writing firmware environment variable '$VariableName'..."
            $result = Set-FirmwareEnvironmentVariable -VariableName $VariableName -Namespace $Namespace -Value $Value
            if ($result -ne 0) {
                Write-Host "Firmware environment variable set successfully."
                Write-Host "Variable: $VariableName"
                Write-Host "Value: $Value"
            } else {
                exit 1
            }
        }
        
        "read" {
            Write-Host "Reading firmware environment variable '$VariableName'..."
            $retrievedValue = Get-FirmwareEnvironmentVariable -VariableName $VariableName -Namespace $Namespace
            if ($null -ne $retrievedValue) {
                Write-Host "Firmware environment variable retrieved successfully."
                Write-Host "Variable: $VariableName"
                Write-Host "Value: $retrievedValue"
            } else {
                Write-Error "Failed to retrieve firmware environment variable."
                exit 1
            }
        }
    }
}
finally {
    # Restore the privilege to its original state
    $result = Set-Privilege -Privilege $SystemEnvironmentPrivilege -Enable $privilegeWasEnabled
    if ($result -ne 0) {
        Write-Error "Failed to restore privilege state. Error code: $result"
        exit 1
    }
}