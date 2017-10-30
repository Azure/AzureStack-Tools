#------------------------------------------------------------------------------  
#  
# Copyright © 2017 Microsoft Corporation.  All rights reserved.  
#  
# THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED “AS IS” WITHOUT  
# WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT  
# LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS  
# FOR A PARTICULAR PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR   
# RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.  
#  
#------------------------------------------------------------------------------  
#  
# PowerShell Source Code  
#  
# NAME:  
#    AzS_PS_Environment
#  
# VERSION:  
#    1.0.2
#  
#------------------------------------------------------------------------------ 
 
"------------------------------------------------------------------------------ " | Write-Host -ForegroundColor Yellow 
""  | Write-Host -ForegroundColor Yellow 
" Copyright © 2017 Microsoft Corporation.  All rights reserved. " | Write-Host -ForegroundColor Yellow 
""  | Write-Host -ForegroundColor Yellow 
" THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED `“AS IS`” WITHOUT " | Write-Host -ForegroundColor Yellow 
" WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT " | Write-Host -ForegroundColor Yellow 
" LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS " | Write-Host -ForegroundColor Yellow 
" FOR A PARTICULAR PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR  " | Write-Host -ForegroundColor Yellow 
" RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER. " | Write-Host -ForegroundColor Yellow 
"------------------------------------------------------------------------------ " | Write-Host -ForegroundColor Yellow 
""  | Write-Host -ForegroundColor Yellow 
" PowerShell Source Code " | Write-Host -ForegroundColor Yellow 
""  | Write-Host -ForegroundColor Yellow 
" NAME: " | Write-Host -ForegroundColor Yellow 
"    AzS_PS_Environment.ps1 " | Write-Host -ForegroundColor Yellow 
"" | Write-Host -ForegroundColor Yellow 
" VERSION: " | Write-Host -ForegroundColor Yellow 
"    1.0.1" | Write-Host -ForegroundColor Yellow 
""  | Write-Host -ForegroundColor Yellow 
"------------------------------------------------------------------------------ " | Write-Host -ForegroundColor Yellow 
"" | Write-Host -ForegroundColor Yellow 
"`n This script SAMPLE is provided and intended only to act as a SAMPLE ONLY," | Write-Host -ForegroundColor Yellow 
" and is NOT intended to serve as a solution to any known technical issue."  | Write-Host -ForegroundColor Yellow 
"`n By executing this SAMPLE AS-IS, you agree to assume all risks and responsibility associated."  | Write-Host -ForegroundColor Yellow 
 
$ErrorActionPreference = "SilentlyContinue" 
$ContinueAnswer = Read-Host "`n Do you wish to proceed at your own risk? (Y/N)" 
If ($ContinueAnswer -ne "Y") { Write-Host "`n Exiting." -ForegroundColor Red;Exit }

#ISE check
 if ($psise -ne $null)
 {
	Write-Host "`n `t[WARN] Script should not be run from PowerShell ISE" -ForegroundColor Yellow
	Read-Host -Prompt "`tPress Enter to continue"
 }

#globalVar
$global:Toolspath ="C:\AzureStackTools\AzureStack-Tools-master"

#regionPS
    Write-host "`n[INFO] Checking for required Powershell modules" -ForegroundColor Yellow
    if(!(Get-InstalledModule -Name azurestack))
    {
    #install profiles in the correct order
    Write-Host "`t`n[Info] Installation of required powershell modules" -ForegroundColor Yellow
    Write-Host "`t`n[Prompt] Please approve to all prompts" -ForegroundColor Yellow
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted  
    Install-Module -Name AzureStack -RequiredVersion 1.2.11 -Scope CurrentUser -AllowClobber -Force
    Install-Module -Name 'AzureRm.Bootstrapper' -Scope CurrentUser -AllowClobber -Force
    Install-AzureRmProfile -profile '2017-03-09-profile' -Force -Scope CurrentUser
    }
#endregionPS


#regionTools
If ((Test-Path -Path "$($Toolspath)\Support\ERCS_Logs\ERCS_AzureStackLogs.ps1") -eq $false)
{
    [void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
    [void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
    $TOOLSMainForm = New-Object -TypeName System.Windows.Forms.Form
    [System.Windows.Forms.Label]$TOOLSlabel = $null
    [System.Windows.Forms.Button]$TOOLSYbutton = $null
    [System.Windows.Forms.Button]$TOOLSNbutton = $null
    [System.Windows.Forms.Button]$button1 = $null

    $TOOLSlabel = New-Object -TypeName System.Windows.Forms.Label
    $TOOLSYbutton = New-Object -TypeName System.Windows.Forms.Button
    $TOOLSNbutton = New-Object -TypeName System.Windows.Forms.Button
    $TOOLSMainForm.SuspendLayout()
    #
    #TOOLSlabel
    #
    $TOOLSlabel.AutoSize = $true
    $TOOLSlabel.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(48,38)
    $TOOLSlabel.Name = 'TOOLSlabel'
    $TOOLSlabel.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(263,13)
    $TOOLSlabel.TabIndex = 0
    $TOOLSlabel.Text = 'Do you need to download and install AzureStackTools'
    #
    #TOOLSYbutton
    #
    $TOOLSYbutton.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(51,78)
    $TOOLSYbutton.Name = 'TOOLSYbutton'
    $TOOLSYbutton.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
    $TOOLSYbutton.TabIndex = 1
    $TOOLSYbutton.Text = 'Yes'
    $TOOLSYbutton.UseVisualStyleBackColor = $true
    $TOOLSYbutton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    #
    #TOOLSNbutton
    #
    $TOOLSNbutton.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(236,78)
    $TOOLSNbutton.Name = 'TOOLSNbutton'
    $TOOLSNbutton.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
    $TOOLSNbutton.TabIndex = 2
    $TOOLSNbutton.Text = 'No'
    $TOOLSNbutton.UseVisualStyleBackColor = $true
    $TOOLSNbutton.DialogResult = [System.Windows.Forms.DialogResult]::No
    #
    #TOOLSMainForm
    #
    $TOOLSMainForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(369,133)
    $TOOLSMainForm.Controls.Add($TOOLSNbutton)
    $TOOLSMainForm.Controls.Add($TOOLSYbutton)
    $TOOLSMainForm.Controls.Add($TOOLSlabel)
    $TOOLSMainForm.Name = 'TOOLSMainForm'
    $TOOLSMainForm.ResumeLayout($false)
    $TOOLSMainForm.PerformLayout()
    Add-Member -InputObject $TOOLSMainForm -Name base -Value $base -MemberType NoteProperty
    Add-Member -InputObject $TOOLSMainForm -Name TOOLSlabel -Value $TOOLSlabel -MemberType NoteProperty
    Add-Member -InputObject $TOOLSMainForm -Name TOOLSYbutton -Value $TOOLSYbutton -MemberType NoteProperty
    Add-Member -InputObject $TOOLSMainForm -Name TOOLSNbutton -Value $TOOLSNbutton -MemberType NoteProperty
    Add-Member -InputObject $TOOLSMainForm -Name button1 -Value $button1 -MemberType NoteProperty
    $TOOLSMainForm.Topmost = $True
    $TOOLSMainForm.StartPosition = "CenterScreen"
    $TOOLSMainForm.MaximizeBox = $false
    $TOOLSMainForm.FormBorderStyle = 'Fixed3D'
    $TOOLSresult = $TOOLSMainForm.ShowDialog()

    If($TOOLSresult -eq [System.Windows.Forms.DialogResult]::No)
    {
        Add-Type -AssemblyName System.Windows.Forms
        $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $FolderBrowser.Description = 'Select the AzureStack-Tools-master folder'
        $FolderBrowser.SelectedPath = 'C:\’
        $FolderBrowser.ShowNewFolderButton = $false
        $result = $FolderBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
        if ($result -eq [Windows.Forms.DialogResult]::OK){
            $global:Toolspath = $null
            $global:Toolspath = $FolderBrowser.SelectedPath
        }
        else {
            exit
        }
    }

    If($TOOLSresult -eq [System.Windows.Forms.DialogResult]::Yes)
    {
    $LocalPath = "C:\AzureStackTools\"
    if(!(Test-Path -Path $LocalPath))
        {
        New-Item $LocalPath -Type directory -Force
        invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/master.zip -OutFile "$($LocalPath)master.zip"
        expand-archive "$($LocalPath)master.zip" -DestinationPath $LocalPath -Force
        }
        else
        {
        Remove-Item $LocalPath -Force -Recurse
        New-Item $LocalPath -Type directory -Force
        invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/master.zip -OutFile "$($LocalPath)master.zip"
        expand-archive "$($LocalPath)master.zip" -DestinationPath $LocalPath -Force
        }
    }



    function global:AzSLoadTools
    {
        [Environment]::SetEnvironmentVariable("MASPath", "$($Toolspath)")
        cd $Env:MASPath

        $Folders=@()
        $Folders += Get-ChildItem | Where {$_.attributes -eq 'directory'}

           foreach ($Folder in $Folders)
           {
                   if (Get-ChildItem -Name $Folder -include *.psm1)
               {
                   Import-Module $Toolspath\Connect\AzureStack.Connect.psm1 
                   Import-Module $Toolspath\$Folder\$(Get-ChildItem -Name $Folder -include *.psm1) -WarningAction SilentlyContinue
               }
           }
    }
}

#endregionTools

#show Info made from the script
Write-host "`n[INFO] `$EnvInfo variable created" -ForegroundColor Yellow
Write-host "`t `tAvailable command: '`$EnvInfo' to view stamp endpoints`n"
Write-host -NoNewline "[INFO] AzSLoadTools Module created" -ForegroundColor Yellow
Write-Host -NoNewline " (Administrative Powershell Only)" -ForegroundColor Red
Write-host "`n`t `tAvailable command: 'AzSLoadTools' to load AzureStack tool modules"
Write-host "`n[INFO] AzureStackAdmin AzureRmEnvironment created" -ForegroundColor Yellow
Write-host "`t `tRun 'Get-AzureRmEnvironment -Name AzureStackAdmin' to see environment "
Write-host "`n[INFO] AzureStackUser AzureRmEnvironment created" -ForegroundColor Yellow
Write-host "`t `tRun 'Get-AzureRmEnvironment -Name AzureStackUser' to see environment "
