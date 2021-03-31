# Copyright (c) Microsoft Corporation. All rights reserved.

<#
This module contains the function to verify expected hash of the file specified in the provided path.
#>

function Verify-Hash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ExpectedHash,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]
        $FilePath
    )

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $actualHash = (Get-FileHash -Path $FilePath).Hash
    Write-Host "$fileName expected hash: $ExpectedHash"
    if ($ExpectedHash -eq $actualHash)
    {
        Write-Host "SUCCESS: $fileName file hash matches."
    }
    else
    {
        Write-Error "ERROR: $fileName file hash does not match! It isn't safe to use it, please download it again. Actual hash: $actualHash."
    }
}
