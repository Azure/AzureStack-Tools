<#
.SYNOPSIS
	Script to setup AzureStack PowerShell Enviroment
.DESCRIPTION
	The script will insure Azure Stack PowerShell modules are running at the proper version. Build AzureStack endpoint environment variables from supplied JSON file. Download and extract AzureStack-Tools-master Toolkit. Builds a function called AzSLoadTools that imports modules in proper order. 

.PARAMETER AzSPathToStampJSON
    Path to AzureStackStampInformation.json file
    "C:\Users\AzureStackAdmin\Desktop\AzureStackStampInformation.json"

.PARAMETER AzSToolsPath
    Path to AzureStack-Tools-master folder 
    "C:\Users\AzureStackAdmin\Desktop\master\AzureStack-Tools-master"

.EXAMPLE
.\AzS-PS-Environment.ps1 -AzSPathToStampJSON "C:\Users\AzureStackAdmin\Desktop\AzureStackStampInformation.json" -AzSToolsPath "C:\Users\AzureStackAdmin\Desktop\master\AzureStack-Tools-master"
#>

Param(
	[Parameter(Mandatory=$false,HelpMessage="Path to AzureStackStampInformation")]
    [String] $AzSPathToStampJSON,
	[Parameter(Mandatory=$false,HelpMessage="Path to AzureStack-Tools-master")]
    [string]$AzSToolsPath
)


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
#    AzS-PoSh-Environment
#  
# VERSION:  
#    1.0.3
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
"    AzS-PoSh-Environment.ps1 " | Write-Host -ForegroundColor Yellow 
"" | Write-Host -ForegroundColor Yellow 
" VERSION: " | Write-Host -ForegroundColor Yellow 
"    1.0.3" | Write-Host -ForegroundColor Yellow 
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

#regionJSON 
    if ($AzSPathToStampJSON)
    {
        If ((Test-Path -Path $AzSPathToStampJSON) -eq $true)
        {
        $JSONFile = Get-Content -Raw -Path $AzSPathToStampJSON | ConvertFrom-Json
        $JSONFile | ConvertTo-Json | Out-File -FilePath "$($Env:ProgramData)\AzureStackStampInformation.json" -Force
        }
    }

    #Check for the JSON
    If ((Test-Path -Path "$($Env:ProgramData)\AzureStackStampInformation.json") -eq $true)
    {
        Write-Host "`n[INFO] Loaded AzureStackStampInformation.json from ProgramData" -ForegroundColor Yellow
        $FoundJSONFile = Get-Content -Raw -Path "$($Env:ProgramData)\AzureStackStampInformation.json" | ConvertFrom-Json
    }
	If ((Test-Path -Path "$($Env:ProgramData)\AzureStackStampInformation.json") -eq $false)
	{
        if ((Test-Path -Path "$($env:SystemDrive)\CloudDeployment\Logs\AzureStackStampInformation.json") -eq $true)
        {
        Write-Host "`n[INFO] Loaded AzureStackStampInformation.json from CloudDeployment" -ForegroundColor Yellow
	    $FoundJSONFile = Get-Content -Raw -Path "$($env:SystemDrive)\CloudDeployment\Logs\AzureStackStampInformation.json" | ConvertFrom-Json
        }
	}

#Go Get the JSON file
if(!($FoundJSONFile))
{
    #region.NET
    [void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
    [void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
    $JSONMainForm = New-Object -TypeName System.Windows.Forms.Form
    [System.Windows.Forms.Label]$Jsonlabel = $null
    [System.Windows.Forms.Button]$JsonYbutton = $null
    [System.Windows.Forms.Button]$JsonNbutton = $null
    [System.Windows.Forms.Button]$button1 = $null

    $Jsonlabel = New-Object -TypeName System.Windows.Forms.Label
    $JsonYbutton = New-Object -TypeName System.Windows.Forms.Button
    $JsonNbutton = New-Object -TypeName System.Windows.Forms.Button
    $JSONMainForm.SuspendLayout()
    #
    #Jsonlabel
    #
    $Jsonlabel.AutoSize = $true
    $Jsonlabel.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(59,42)
    $Jsonlabel.Name = 'Jsonlabel'
    $Jsonlabel.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(248,13)
    $Jsonlabel.TabIndex = 0
    $Jsonlabel.Text = 'Do you have the AzureStackStampInformation.json'
    #
    #JsonYbutton
    #
    $JsonYbutton.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(62,78)
    $JsonYbutton.Name = 'JsonYbutton'
    $JsonYbutton.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
    $JsonYbutton.TabIndex = 1
    $JsonYbutton.Text = 'Yes'
    $JsonYbutton.UseVisualStyleBackColor = $true
    $JsonYbutton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    #
    #JsonNbutton
    #
    $JsonNbutton.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(232,78)
    $JsonNbutton.Name = 'JsonNbutton'
    $JsonNbutton.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
    $JsonNbutton.TabIndex = 2
    $JsonNbutton.Text = 'No'
    $JsonNbutton.UseVisualStyleBackColor = $true
    $JsonNbutton.DialogResult = [System.Windows.Forms.DialogResult]::No
    #
    #JSONMainForm
    #
    $JSONMainForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(369,133)
    $JSONMainForm.Controls.Add($JsonNbutton)
    $JSONMainForm.Controls.Add($JsonYbutton)
    $JSONMainForm.Controls.Add($Jsonlabel)
    $JSONMainForm.Name = 'JSONMainForm'
    $JSONMainForm.ResumeLayout($false)
    $JSONMainForm.PerformLayout()
    Add-Member -InputObject $JSONMainForm -Name base -Value $base -MemberType NoteProperty
    Add-Member -InputObject $JSONMainForm -Name Jsonlabel -Value $Jsonlabel -MemberType NoteProperty
    Add-Member -InputObject $JSONMainForm -Name JsonYbutton -Value $JsonYbutton -MemberType NoteProperty
    Add-Member -InputObject $JSONMainForm -Name JsonNbutton -Value $JsonNbutton -MemberType NoteProperty
    Add-Member -InputObject $JSONMainForm -Name button1 -Value $button1 -MemberType NoteProperty
	$JSONMainForm.Topmost = $True
	$JSONMainForm.StartPosition = "CenterScreen"
    $JSONMainForm.MaximizeBox = $false
    $JSONMainForm.FormBorderStyle = 'Fixed3D'
    $result = $JSONMainForm.ShowDialog()
	#endregion.NET
	switch ($result)
	    {
	        "Yes" {    
	            Add-Type -AssemblyName System.Windows.Forms
	            $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
	            InitialDirectory = $env:SystemDrive
	            Filter = 'JSON File (*.json)|*.json'
	                }
	                [void]$FileBrowser.ShowDialog()
	            $FoundJSONFile = Get-Content -Raw -Path $FileBrowser.FileNames | ConvertFrom-Json
                If($FoundJSONFile)
	                {
                    Write-Host "`n `t[INFO] Loaded $($FileBrowser.FileNames)" -ForegroundColor Green
					Write-Host "`n `t[INFO] Saving AzureStackStampInformation to $($Env:ProgramData)" -ForegroundColor Green
					$FoundJSONFile | ConvertTo-Json | Out-File -FilePath "$($Env:ProgramData)\AzureStackStampInformation.json" -Force
                    }
	          }
	        "No" {
                  Write-Host "`n `t[INFO] No AzureStackStampInformation.json file loaded" -ForegroundColor White;	
                  Write-Host "`n Press any key to continue ...`n"
	              $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	              exit
                  }
	    }
}

#Load the file

If($FoundJSONFile)
{
                        $global:envInfo = @{
                        ExternalFqdn       = $FoundJSONFile.ExternalDomainFQDN
                        DeploymentGuid     = $FoundJSONFile.DeploymentID
                        AdminPortal        = $FoundJSONFile.AdminExternalEndpoints.AdminPortal
                        AdminArm           = $FoundJSONFile.AdminExternalEndpoints.AdminResourceManager
                        TenantPortal       = $FoundJSONFile.TenantExternalEndpoints.TenantPortal
                        TenantArm          = $FoundJSONFile.TenantExternalEndpoints.TenantResourceManager
                        IdTenantName       = $FoundJSONFile.AADTenantName
                        TenantId           = $FoundJSONFile.AADTenantID 
                        AdminArmCertEp     = "$($FoundJSONFile.AdminExternalEndpoints.AdminResourceManager)metadata/authentication?api-version=2015-01-01"
                        TenantArmCertEp    = "$($FoundJSONFile.TenantExternalEndpoints.TenantResourceManager)metadata/authentication?api-version=2015-01-01"
                        TenantPortalConsent= "$($FoundJSONFile.TenantExternalEndpoints.TenantPortal)guest/signup/$($FoundJSONFile.AADTenantName)"
                        AdminPortalConsent = "$($FoundJSONFile.AdminExternalEndpoints.AdminPortal)guest/signup/$($FoundJSONFile.AADTenantName)"
                        AdminArmEndpoints  = (Invoke-RestMethod "$($FoundJSONFile.AdminExternalEndpoints.AdminResourceManager)metadata/endpoints?api-version=1.0")
                        TenantArmEndpoints = (Invoke-RestMethod "$($FoundJSONFile.TenantExternalEndpoints.TenantResourceManager)metadata/endpoints?api-version=1.0")
                    }

                Add-AzureRmEnvironment -Name "AzureStackAdmin" -ArmEndpoint $envInfo.AdminArm | Out-null
                Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint $envInfo.TenantArm | Out-null
}

If($envInfo)
{
    Try
    {
        $TenantId = $envInfo.TenantId
        Write-Host "`n[INFO] - Login to Azure RM" -ForegroundColor Yellow

            function Read-InputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText)
    {
        Add-Type -AssemblyName Microsoft.VisualBasic
        return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $WindowTitle, $DefaultText)
    }

    Write-Host "`n[Prompt] for AzureStack Administrator name" -ForegroundColor Yellow

        [String]$AzSUser = Read-InputBoxDialog -Message "Please enter AzureStack the Admin you use to log into the Administrative portal: `n`n`tUSER@$($envInfo.IdTenantName)" -WindowTitle "Azure Stack Administrative portal user" -DefaultText "​SOMEUSER@$($envInfo.IdTenantName)"
        $cred = Get-Credential -UserName $AzSUser -Message "$($AzSUser) Password"
        $AzSLogin = Login-AzureRmAccount -Credential $cred -TenantId $TenantId -Environment "AzureStackAdmin"
        $azsadmin = $AzSLogin.Context.Account.Id
        if($azsadmin)
            {
			Write-Host "`t$($azsadmin)"
            $location = Get-AzsLocation
            $location = $location.Name
        
            Write-Host "`n[INFO] - Obtaining subscriptions" -ForegroundColor Yellow
            [array] $AllSubs = get-AzureRmSubscription 
            }
        Else
        {
        Write-Host "`n`t`t[Error] Did not login $_" -ForegroundColor Red
		Write-Host "`n Press any key to continue ...`n"
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		exit
        }
    }
    catch [System.Exception]
    {
    	Write-Host "`n`t`t[Error] Wrong Username or Password: $_" -ForegroundColor Red
		Write-Host "`n Press any key to continue ...`n"
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		exit
    }
    If (($AllSubs.count -eq 1) -and ($azsadmin))
    {
        Select-AzureRmSubscription -Subscriptionid $AllSubs.id | Out-Null
        Write-Host "`tSuccess" -ForegroundColor White
    }
    Else
    {
        If (($AllSubs) -and ($azsadmin))
        {
                Write-Host "`tSuccess" -ForegroundColor White

                }
        Else
        {
                Write-Host "`tNo subscriptions found. Exiting." -ForegroundColor Red
                Exit
        }

        Write-Host "`n[SELECTION] - Select the Azure subscription." -ForegroundColor Yellow

        $SelSubName = $AllSubs | Out-GridView -PassThru -Title "Select the Azure subscription"

        If ($SelSubName)
        {
	        #Write sub
	        Write-Host "`tSelection: $($SelSubName.Name)"
		
                $SelSub = $SelSubName.SubscriptionId
                Select-AzureRmSubscription -Subscriptionid $SelSub | Out-Null
		        Write-Host "`tSuccess" -ForegroundColor White
        }
        Else
        {
                Write-Host "`n[ERROR] - No Azure subscription was selected. Exiting." -ForegroundColor Red
                Exit
        } 
    }   
}
#endregionJSON 

#regionTools
If ((Test-Path -Path "$($AzSToolsPath)\Support\ERCS_Logs\ERCS_AzureStackLogs.ps1") -eq $True)
{
    try
    {
        $LocalPath = "C:\AzureStackTools\"
        Write-host "`n[INFO] Copying files to $($LocalPath)" -ForegroundColor Yellow
        New-Item $LocalPath -Type directory -Force | out-null
        Copy-Item -Path $AzSToolsPath -Destination $LocalPath -Recurse | out-null
        Write-Host "`tTools are installed" -ForegroundColor Green
    }
    catch [System.Exception]
    {
        Write-Host "`n`t`t[Error] $_" -ForegroundColor Red
        Write-Host "`n Press any key to continue ...`n"
        $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
}

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
        if ($result -eq [Windows.Forms.DialogResult]::OK)
        {
            try
            {
                $selToolspath = $FolderBrowser.SelectedPath
                $LocalPath = "C:\AzureStackTools\"
                Write-host "`n[INFO] Copying files to $($Toolspath)" -ForegroundColor Yellow
                New-Item $LocalPath -Type directory -Force | out-null
                Copy-Item -Path $selToolspath -Destination $LocalPath -Recurse | out-null
                Write-Host "`tSuccess" -ForegroundColor Green
            }
            catch [System.Exception]
            {
            Write-Host "`n`t`t[Error] $_" -ForegroundColor Red
            Write-Host "`n Press any key to continue ...`n"
            $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
            }

        }
        else
        {
                  Write-Host "`n `t[INFO] No AzureStack-Tools-master file loaded" -ForegroundColor Red;	
                  Write-Host "`n Press any key to continue ...`n"
	              $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	              exit
        }
    }

    If($TOOLSresult -eq [System.Windows.Forms.DialogResult]::Yes)
    {
    $LocalPath = "C:\AzureStackTools\"
    if(!(Test-Path -Path $LocalPath))
        {
        try
            {
            New-Item $LocalPath -Type directory -Force | out-null
            invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/master.zip -OutFile "$($LocalPath)master.zip"
            expand-archive "$($LocalPath)master.zip" -DestinationPath $LocalPath -Force
            }
            catch [System.Exception]
            {
            Write-Host "`n`t`t[Error] $_" -ForegroundColor Red
            Write-Host "`n Press any key to continue ...`n"
            $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
            }
        }
        else
        {
            try
            {
            Remove-Item $LocalPath -Force -Recurse
            New-Item $LocalPath -Type directory -Force | out-null
            invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/master.zip -OutFile "$($LocalPath)master.zip"
            expand-archive "$($LocalPath)master.zip" -DestinationPath $LocalPath -Force
            }
            catch [System.Exception]
            {
            Write-Host "`n`t`t[Error] $_" -ForegroundColor Red
            Write-Host "`n Press any key to continue ...`n"
            $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
            }
        }
    }

#endregionTools
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
        return Get-Module
    }

if($azsadmin)
{
#show Info made from the script
Write-host "`n[INFO] `$EnvInfo variable created" -ForegroundColor Yellow
Write-host "`tAvailable command: '`$EnvInfo' to view stamp endpoints`n"
Write-host -NoNewline "[INFO] AzSLoadTools Module created" -ForegroundColor Yellow
Write-Host -NoNewline " (Administrative Powershell Only)" -ForegroundColor Red
Write-host "`n`tAvailable command: 'AzSLoadTools' to load AzureStack tool modules"
Write-host "`n[INFO] AzureStackAdmin AzureRmEnvironment created" -ForegroundColor Yellow
Write-host "`tRun 'Get-AzureRmEnvironment -Name AzureStackAdmin' to see environment "
Write-host "`n[INFO] AzureStackUser AzureRmEnvironment created" -ForegroundColor Yellow
Write-host "`tRun 'Get-AzureRmEnvironment -Name AzureStackUser' to see environment "
}
