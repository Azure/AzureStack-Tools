<#
.SYNOPSIS
	Built to be run on the HLH, DVM, or Jumpbox from an administrative powershell session the script uses seven methods to find the privileged endpoint virtual machines. The script connects to selected privileged endpoint and runs Get-AzureStackLog with supplied parameters. If no parameters are supplied the script will default to prompting user via GUI for needed parameters.
.DESCRIPTION
	The script will use one of the below seven methods; Gather requested logs, Transcript, and AzureStackStampInformation.json. The script will also save AzureStackStampInformation.json in %ProgramData% and in created log folder. AzureStackStampInformation.json in %ProgramData% allows future runs to have ERCS IP information populated at beginning of script.
	
	Methods:
	Check %ProgramData% for AzureStackStampInformation.json
	Prompt user for AzureStackStampInformation.json
	Prompt user for install prefix and check connection to privileged endpoint virtual machine(s)
	Install and/or load AD powershell module and check for computernames that match ERCS
	Install and/or load DNS powershell module and check for A records in all zones that that match ERCS
	Prompt user for tenant portal and based of the IP address of the portal find the likely IP(s) of privileged endpoint virtual machine(s)
	Prompt user for manual entry of IP address of a privileged endpoint virtual machine
.PARAMETER FromDate
    Specifies starting time frame for data search.  If parameter is not specified, script will default to 4 hours from current time. Format must be in one of the 3 formats: 
    (get-date).AddHours(-4)
    "MM/DD/YYYY HH:MM"
    "MM/DD/YYYY"
.PARAMETER ToDate
    Specifies ending time frame for data search. If parameter is not specified, script will default to current time. Format must be in one of the 3 formats: 
    (get-date).AddHours(-1)
    "MM/DD/YYYY HH:MM"
    "MM/DD/YYYY"
.PARAMETER Scenario
	Built for future use 
.PARAMETER FilterByRole
    Specifies parameter to filter log collection. Valid formats are comma separated values. List of possible switches http://aka.ms/AzureStack/Diagnostics
.PARAMETER ErcsName
    Specifies privileged endpoint virtual machine name or IP address to use. Example: AzS-ERCS01 or 192.168.200.255
.PARAMETER AzSCredentials
	Specifies credentials the script will use to connect to Azure Stack privileged endpoint. Format must be in one of the 2 formats:
	(Get-Credential -Message "Azure Stack credentials")
	(Get-Credential)
.PARAMETER LocalShareCred
	Specifies credentials the script will use to build a local share Format must be in one of the 2 formats:
	(Get-Credential -Message "Local share credentials" -UserName $env:USERNAME)
	(Get-Credential)
.PARAMETER InStamp
	Specifies if script is running on Azure Stack machine such as Azure Stack Development Kit deployment or DVM.
	Yes
	No
.PARAMETER StampTimeZone
	Specifies timezone id for Azure Stack stamp. Format must be in one of the 2 formats:
	(Get-TimeZone -Name "US Eastern*").id
	"Pacific Standard Time"
.PARAMETER IncompleteDeployment
	Specifies if Azure Stack Deployment is incomplete. Only for use in Azure Stack Development Kit deployment or DVM
	Yes
	No
.PARAMETER TranscriptPath
	Network share for saving transcripts. Must be in format \\IpAddress\Folder
	"\\1.2.3.4\folder"
.PARAMETER TranscriptShareCred
	Specifies credentials the script will use to build a local share Format must be in one of the 2 formats:
	(Get-Credential -Message "Transcript Share Credentials")
	(Get-Credential)
.EXAMPLE
 .\ERCS_AzureStackLogs.ps1 -FromDate (get-date).AddHours(-4) -ToDate (get-date) -FilterByRole VirtualMachines,BareMetal -ErcsName AzS-ERCS01 -AzSCredentials (Get-Credential -Message "Azure Stack credentials") -LocalShareCred (get-credential -Message "Local share credentials" -UserName $env:USERNAME) -InStamp No -StampTimeZone "Pacific Standard Time" -IncompleteDeployment No -TranscriptPath "\\1.2.3.4\folder" -TranscriptShareCred (Get-Credential -Message "Transcript Share Credentials")
#>

Param(
	[Parameter(Mandatory=$false,HelpMessage="Valid formats 'MM/DD/YYYY' or 'MM/DD/YYYY HH:MM'")]
    [ValidateScript({$_ -lt (get-date)})]
    [DateTime] $FromDate,
	[Parameter(Mandatory=$false,HelpMessage="Valid formats are: in 'MM/DD/YYYY' or 'MM/DD/YYYY HH:MM'")]
    [DateTime] $ToDate,
	[Parameter(Mandatory=$false,HelpMessage="Valid formats are: in '(Get-TimeZone -Name 'US Eastern*').id' or 'Pacific Standard Time'")]
    [String] $StampTimeZone,
	[Parameter(Mandatory=$false,HelpMessage="Valid choices are: Service Fabric, Storage, Networking, Identity, Patch & Update, Compute, Backup")]
    [ValidateSet("Service Fabric", "Storage", "Networking", "Identity", "Patch & Update", "Compute", "Backup")]
    [string] $Scenario,
    [Parameter(Mandatory=$false,HelpMessage="FilterByRole parameter to filter log collection. Valid formats are comma separated values.")]
    [string[]]$FilterByRole,
	[Parameter(Mandatory=$false,HelpMessage="ERCS machine name or IP Address, Example: AzS-ERCS01 or 192.168.200.255")]
    [string]$ErcsName,
	[Parameter(Mandatory=$false,HelpMessage="Credentials the script will use to connect to Azure Stack privileged endpoint")]
    [PSCredential]$AzSCredentials,
	[Parameter(Mandatory=$false,HelpMessage="Credentials the script will use to build a local share")]
    [PSCredential]$LocalShareCred,
	[Parameter(Mandatory=$false,HelpMessage="Script is running on Azure Stack machine such as Azure Stack Development Kit deployment or DVM? Valid formats are: Yes or No")]
    [ValidateSet("Yes", "No")]
    [String] $InStamp,
	[Parameter(Mandatory=$false,HelpMessage="Has Deployment Completed? Valid formats are: Yes or No")]
    [ValidateSet("Yes", "No")]
    [String] $IncompleteDeployment,
	[Parameter(Mandatory=$false,HelpMessage="Path to external transcript share. Example: \\1.2.3.4\folder")]
	[String] $TranscriptPath,
	[Parameter(Mandatory=$false,HelpMessage="Credentials the script will use to connect to the transcript share")]
    [PSCredential]$TranscriptShareCred
)

#warn if running in the ISE do to .net ui rendering 
 if ($psise -ne $null)
 {
	Write-Host "`n `t[WARN] Script should not be run from PowerShell ISE" -ForegroundColor Yellow
	Read-Host -Prompt "`tPress Enter to continue"
 }

#Run as Admin
$ScriptPath = $script:MyInvocation.MyCommand.Path

# Check to see if we are in FullLanguage
$LanguageMode = $ExecutionContext.SessionState.LanguageMode

#load .net assembly 
Add-Type -AssemblyName System.DirectoryServices.AccountManagement

# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

# Get the security principal for the administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

# Check to see if we are currently running as an administrator
if($myWindowsPrincipal.IsInRole($adminRole))
	{
    # We are running as an administrator, so change the title to indicate this
    Write-Host "`n[SUCCESS] Script must be run from an Administrative Powershell Session `n" -ForegroundColor Green
	}
else
	{
    # We are not running as an administrator so stop.
		Write-Host "`n `t [ERROR] Script must be run from an Administrative Powershell Session" -ForegroundColor Red
		Write-Host "`n Press any key to continue ...`n"
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		exit
	}

# Check to see if we are currently running in FullLanguage
if($LanguageMode -eq "FullLanguage")
	{
    # We are running in FullLanguage
    Write-Host "`n[SUCCESS] Script is running in FullLanguage Powershell Mode`n" -ForegroundColor Green
	}
else
	{
    # We are not running in FullLanguage so stop.
		Write-Host "`n `t [ERROR] Script must be run in FullLanguage Powershell Mode" -ForegroundColor Red
		Write-Host "`n `tFor more information run `"Get-Help about_Language_Modes`" "
		Write-Host "`n Press any key to continue ...`n"
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		exit
	}
	
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
#    ERCS_AzureStackLogs
#  
# VERSION:  
#    1.7.0  
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
"    ERCS_AzureStackLogs.ps1 " | Write-Host -ForegroundColor Yellow 
"" | Write-Host -ForegroundColor Yellow 
" VERSION: " | Write-Host -ForegroundColor Yellow 
"    1.7.0" | Write-Host -ForegroundColor Yellow 
""  | Write-Host -ForegroundColor Yellow 
"------------------------------------------------------------------------------ " | Write-Host -ForegroundColor Yellow 
"" | Write-Host -ForegroundColor Yellow 
"`n This script SAMPLE is provided and intended only to act as a SAMPLE ONLY," | Write-Host -ForegroundColor Yellow 
" and is NOT intended to serve as a solution to any known technical issue."  | Write-Host -ForegroundColor Yellow 
"`n By executing this SAMPLE AS-IS, you agree to assume all risks and responsibility associated."  | Write-Host -ForegroundColor Yellow 
 
$ErrorActionPreference = "SilentlyContinue" 
$ContinueAnswer = Read-Host "`n Do you wish to proceed at your own risk? (Y/N)" 
If ($ContinueAnswer -ne "Y") { Write-Host "`n Exiting." -ForegroundColor Red;Exit } 

#Start Up WinRm we need it later 
$winrm = Get-Service -Name winrm
If ($winrm)
{
    If($winrm.StartType -ne "Automatic")
    {
    #Start Up WinRm we need it later 
    Write-Host "`n[INFO] Configuring Windows PowerShell for remoting" -ForegroundColor Green
    $PSRemoting = Invoke-Command -ComputerName localhost -ScriptBlock {Enable-PSRemoting -Force} -AsJob
        while((get-job -Id $PSRemoting.id).State -eq "Running")
        {
	        $PSRper = (Get-Random -Minimum 5 -Maximum 80); Start-Sleep -Milliseconds 1500
	        Write-Progress -Activity "Please wait while Powershell Remoting is setup on $($env:COMPUTERNAME)" -PercentComplete $PSRper
        }

        if((get-job -Id $PSRemoting.id).State -eq "Completed")
        {
	        Write-Progress -Activity "Please wait while Powershell Remoting is setup on $($env:COMPUTERNAME)" -Status "Ready" -Completed
        }
    }
}

#clear var $ip
$IP = $null
Clear-Host

#Temp Firewall rule for access to PEP and SMB to allow file transfer from PEP
Try
{
    $FWruletest = Get-NetFirewallRule -Group "AzureStack_ERCS" -ErrorAction SilentlyContinue
    If(!($FWruletest))
    {
    $firewall = New-NetFirewallRule -Name "AzureStack Firewall PEP rule" -DisplayName "AzureStack PEP Access Firewall rule" -Description "Allow Outbound Access to Remote Powershell" -Group "AzureStack_ERCS" -Enabled True -Action Allow -Profile Any -Direction Outbound -Protocol TCP -RemotePort 5985
	$SMB = New-NetFirewallRule -Name "AzureStack Firewall SMB rule" -DisplayName "AzureStack SMB Access Firewall rule" -Description "Allow inbound Access to SMB Powershell" -Group "AzureStack_ERCS" -Enabled True -Action Allow -Profile Any -Direction Inbound -Protocol TCP -LocalPort 445
    }
    If($firewall.PrimaryStatus -eq "OK")
        {Write-Host "`n `t[INFO] Created firewall rules to allow access to AzureStack" -ForegroundColor Green}
}
catch 
{
    Write-Host "`n`t`t[Error] Exception caught: $_" -ForegroundColor Red
    Write-Host "`n Press any key to continue ...`n"
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

#Test for Module
function load_module($name)
{
    if (-not(Get-Module -Name $name))
    {
        if (Get-Module -ListAvailable | Where-Object { $_.name -eq $name })
        {
            Import-Module $name  

            return $true
        }
        else
        {   
            return $false
        }
    }
    else
    {
        return $true
    }
}

#ERCS input check
if ($ErcsName)
{
	if(!($IP))
	{
		$global:progresspreference ="SilentlyContinue"
		$ercstest = Test-NetConnection -port 5985 -ComputerName $ErcsName
		If ($ercstest.TcpTestSucceeded -eq "True"){$IP = $ercstest.RemoteAddress.IPAddressToString}
		$global:progresspreference ="Continue"
	}
}

#AutoAzureStackStampInformation
If(!($IP))
{
	If ((Test-Path -Path "$($Env:ProgramData)\AzureStackStampInformation.json") -eq $true)
	{
	Write-Host "`n `t[INFO] Loaded AzureStackStampInformation.json from ProgramData" -ForegroundColor Green
	$FoundJSONFile = Get-Content -Raw -Path "$($Env:ProgramData)\AzureStackStampInformation.json" | ConvertFrom-Json
	[string]$FoundDomainFQDN = $FoundJSONFile.DomainFQDN
	[array]$ERCSIPS = $FoundJSONFile.EmergencyConsoleIPAddresses
	$StampTimeZone = $FoundJSONFile.Timezone
	$FoundSelERCSIP  = $FoundJSONFile.EmergencyConsoleIPAddresses | Out-GridView -Title "Please Select Emergency Console IP Address" -PassThru
	$IP = $FoundSelERCSIP
	}
	If ((Test-Path -Path "$($Env:ProgramData)\AzureStackStampInformation.json") -eq $false)
	{
        if ((Test-Path -Path "$($env:SystemDrive)\CloudDeployment\Logs\AzureStackStampInformation.json") -eq $true)
        {
        Write-Host "`n `t[INFO] Loaded AzureStackStampInformation.json from CloudDeployment" -ForegroundColor Green
	    $FoundJSONFile = Get-Content -Raw -Path "$($env:SystemDrive)\CloudDeployment\Logs\AzureStackStampInformation.json" | ConvertFrom-Json
	    [string]$FoundDomainFQDN = $FoundJSONFile.DomainFQDN
	    [array]$ERCSIPS = $FoundJSONFile.EmergencyConsoleIPAddresses
	    $StampTimeZone = $FoundJSONFile.Timezone
	    $FoundSelERCSIP  = $FoundJSONFile.EmergencyConsoleIPAddresses | Out-GridView -Title "Please Select Emergency Console IP Address" -PassThru
	    $IP = $FoundSelERCSIP
        }
    }
}

#Sel AzureStackStampInformation
if(!($IP))
{
	#region .NET
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
	$JSONMainForm.ShowIcon = $false
	$result = $JSONMainForm.ShowDialog()
	#endregion .NET
	switch ($result)
	    {
	        "Yes" {    
	            Add-Type -AssemblyName System.Windows.Forms
	            $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
	            InitialDirectory = $env:SystemDrive
	            Filter = 'JSON File (*.json)|*.json'
	                }
	                [void]$FileBrowser.ShowDialog()
	            $JSONFile = Get-Content -Raw -Path $FileBrowser.FileNames | ConvertFrom-Json
                If($JSONFile)
	                {
                    Write-Host "`n `t[INFO] Loaded $($FileBrowser.FileNames)" -ForegroundColor Green
					Write-Host "`n `t[INFO] Saving AzureStackStampInformation to $($Env:ProgramData)" -ForegroundColor Green
					$JSONFile | ConvertTo-Json | Out-File -FilePath "$($Env:ProgramData)\AzureStackStampInformation.json" -Force
					[string]$FoundDomainFQDN = $JSONFile.DomainFQDN
					[array]$ERCSIPS = $JSONFile.EmergencyConsoleIPAddresses
					$StampTimeZone = $JSONFile.Timezone
	                $selERCSIP = $ERCSIPS | Out-GridView -Title "Please Select Emergency Console IPAddress" -PassThru
	                $IP = $selERCSIP
                    }
	          }
	        "No" {Write-Host "`n `t[INFO] No AzureStackStampInformation.json file loaded" -ForegroundColor White}
	    }
}

#ERCs Prefix check
if(!($IP))
{
    function Read-InputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText)
    {
        Add-Type -AssemblyName Microsoft.VisualBasic
        return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $WindowTitle, $DefaultText)
    }

    Write-Host "`n`t[Prompt] for prefix name" -ForegroundColor  White
    $AzSPrefix = Read-InputBoxDialog -Message "Please enter Azure Stack install prefix:" -WindowTitle "Azure Stack prefix" -DefaultText "AzS"

    If($AzSPrefix)
    {
        [Array]$GuessERCSName += $AzSPrefix + "-ERCS01"
        [Array]$GuessERCSName += $AzSPrefix + "-ERCS02"
        [Array]$GuessERCSName += $AzSPrefix + "-ERCS03"
    }


    ForEach ($GuessERCName in $GuessERCSName)
        {
		$global:progresspreference ="SilentlyContinue"
        $GuessName = Test-NetConnection -port 5985 -ComputerName $GuessERCName -WarningAction SilentlyContinue
        If ($GuessName.TcpTestSucceeded -eq "True")
            {
            [Array]$ListeningNames += $GuessName.RemoteAddress.IPAddressToString
            }
        }
	$global:progresspreference ="Continue"
    $selName = $ListeningNames |Out-GridView -PassThru -Title "Select Emergency Recovery Console Session"
    $IP = $selName
}

#InStamp Check 
if($InStamp -eq "Yes"){$CheckADSK = 1}
if (!($InStamp))
{
	#region .NET
	[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
	$OnStampForm = New-Object -TypeName System.Windows.Forms.Form
	[System.Windows.Forms.Label]$OnStampLabel = $null
	[System.Windows.Forms.Button]$OnStampYes = $null
	[System.Windows.Forms.Button]$OnStampNo = $null
	[System.Windows.Forms.Button]$button1 = $null

	$OnStampLabel = New-Object -TypeName System.Windows.Forms.Label
	$OnStampYes = New-Object -TypeName System.Windows.Forms.Button
	$OnStampNo = New-Object -TypeName System.Windows.Forms.Button
	$OnStampForm.SuspendLayout()
	#
	#OnStampLabel
	#
	$OnStampLabel.AutoSize = $true
	$OnStampLabel.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,22)
	$OnStampLabel.Name = 'OnStampLabel'
	$OnStampLabel.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(270,13)
	$OnStampLabel.TabIndex = 0
	$OnStampLabel.Text = 'Are you running script from the ASDK or DVM machine?'
	$OnStampLabel.TextAlign = [System.Drawing.ContentAlignment]::TopCenter
	$OnStampLabel.add_Click($OnStampLabel_Click)
	#
	#OnStampYes
	#
	$OnStampYes.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(62,55)
	$OnStampYes.Name = 'OnStampYes'
	$OnStampYes.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
	$OnStampYes.TabIndex = 1
	$OnStampYes.Text = 'Yes'
	$OnStampYes.UseVisualStyleBackColor = $true
	$OnStampYes.DialogResult = [System.Windows.Forms.DialogResult]::Yes
	#
	#OnStampNo
	#
	$OnStampNo.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(143,55)
	$OnStampNo.Name = 'OnStampNo'
	$OnStampNo.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
	$OnStampNo.TabIndex = 2
	$OnStampNo.Text = 'No'
	$OnStampNo.UseVisualStyleBackColor = $true
	$OnStampNo.DialogResult = [System.Windows.Forms.DialogResult]::No
	#
	#OnStampForm
	#
	$OnStampForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(298,99)
	$OnStampForm.Controls.Add($OnStampNo)
	$OnStampForm.Controls.Add($OnStampYes)
	$OnStampForm.Controls.Add($OnStampLabel)
	$OnStampForm.Name = 'OnStampForm'
	$OnStampForm.Text = 'On Stamp Prompt'
	$OnStampForm.add_Load($MainForm_Load)
	$OnStampForm.ResumeLayout($false)
	$OnStampForm.AcceptButton = $OnStampNo
	$OnStampForm.PerformLayout()
	Add-Member -InputObject $OnStampForm -Name base -Value $base -MemberType NoteProperty
	Add-Member -InputObject $OnStampForm -Name OnStampLabel -Value $OnStampLabel -MemberType NoteProperty
	Add-Member -InputObject $OnStampForm -Name OnStampYes -Value $OnStampYes -MemberType NoteProperty
	Add-Member -InputObject $OnStampForm -Name OnStampNo -Value $OnStampNo -MemberType NoteProperty
	Add-Member -InputObject $OnStampForm -Name button1 -Value $button1 -MemberType NoteProperty
	$OnStampForm.Topmost = $True
	$OnStampForm.StartPosition = "CenterScreen"
    $OnStampForm.MaximizeBox = $false
    $OnStampForm.FormBorderStyle = 'Fixed3D'
	$OnStampForm.ShowIcon = $false
	$ASDKQuestion = $OnStampForm.ShowDialog()
	#endregion .NET
	if ($ASDKQuestion -eq [System.Windows.Forms.DialogResult]::yes)
	{
	Write-Host "`n `t[INFO] Using Azure Stack Development Kit or DVM" -ForegroundColor Green
	$CheckADSK = 1
	}
}

#Manual Entry
if(!($IP))
{
	$GuessERCSIP = $null
	$ERCSIPAddress = (Test-Connection $env:computername -count 1).IPv4Address.IPAddressToString
	$ERCSIPSplit = $ERCSIPAddress.split(".")
	$GuessERCSIP += $ERCSIPSplit[0] + "." + $ERCSIPSplit[1] + "." + $ERCSIPSplit[2] + "." + "x"

	#region .NET
	[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
	$ERCSIPMain = New-Object -TypeName System.Windows.Forms.Form
	[System.Windows.Forms.Label]$ERCSIPLabel = $null
	[System.Windows.Forms.TextBox]$ERCSIPTextBox = $null
	[System.Windows.Forms.Button]$ERCSIPCancel = $null
	[System.Windows.Forms.Button]$ERCSIPOK = $null
	[System.Windows.Forms.Button]$button1 = $null
	$ERCSIPLabel = New-Object -TypeName System.Windows.Forms.Label
	$ERCSIPTextBox = New-Object -TypeName System.Windows.Forms.TextBox
	$ERCSIPCancel = New-Object -TypeName System.Windows.Forms.Button
	$ERCSIPOK = New-Object -TypeName System.Windows.Forms.Button
	$ERCSIPMain.SuspendLayout()
	#
	#ERCSIPLabel
	#
	$ERCSIPLabel.AutoSize = $true
	$ERCSIPLabel.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(17,22)
	$ERCSIPLabel.Name = 'ERCSIPLabel'
	$ERCSIPLabel.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(250,13)
	$ERCSIPLabel.TabIndex = 0
	$ERCSIPLabel.Text = 'Enter IP address of a Privileged End Point machine:'
	#
	#ERCSIPTextBox
	#
	$ERCSIPTextBox.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(20,52)
	$ERCSIPTextBox.Name = 'textBox1'
	$ERCSIPTextBox.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(249,20)
	$ERCSIPTextBox.TabIndex = 1
	$ERCSIPTextBox.Text = $GuessERCSIP
	#
	#ERCSIPCancel
	#
	$ERCSIPCancel.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(58,96)
	$ERCSIPCancel.Name = 'ERCSIPCancel'
	$ERCSIPCancel.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
	$ERCSIPCancel.TabIndex = 2
	$ERCSIPCancel.Text = 'Cancel'
	$ERCSIPCancel.UseVisualStyleBackColor = $true
	$ERCSIPCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	#
	#ERCSIPOK
	#
	$ERCSIPOK.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(153,96)
	$ERCSIPOK.Name = 'ERCSIPOK'
	$ERCSIPOK.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
	$ERCSIPOK.TabIndex = 3
	$ERCSIPOK.Text = 'OK'
	$ERCSIPOK.UseVisualStyleBackColor = $true
	$ERCSIPOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
	#
	#ERCSIPMain
	#
	$ERCSIPMain.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(291,131)
	$ERCSIPMain.Controls.Add($ERCSIPOK)
	$ERCSIPMain.Controls.Add($ERCSIPCancel)
	$ERCSIPMain.Controls.Add($ERCSIPTextBox)
	$ERCSIPMain.Controls.Add($ERCSIPLabel)
	$ERCSIPMain.Name = 'ERCSIPMain'
	$ERCSIPMain.ResumeLayout($false)
	$ERCSIPMain.PerformLayout()
	Add-Member -InputObject $ERCSIPMain -Name base -Value $base -MemberType NoteProperty
	Add-Member -InputObject $ERCSIPMain -Name ERCSIPLabel -Value $ERCSIPLabel -MemberType NoteProperty
	Add-Member -InputObject $ERCSIPMain -Name ERCSIPTextBox -Value $ERCSIPTextBox -MemberType NoteProperty
	Add-Member -InputObject $ERCSIPMain -Name ERCSIPCancel -Value $ERCSIPCancel -MemberType NoteProperty
	Add-Member -InputObject $ERCSIPMain -Name ERCSIPOK -Value $ERCSIPOK -MemberType NoteProperty
	Add-Member -InputObject $ERCSIPMain -Name button1 -Value $button1 -MemberType NoteProperty
	$ERCSIPMain.AcceptButton = $ERCSIPOK
	$ERCSIPMain.Topmost = $True
	$ERCSIPMain.StartPosition = "CenterScreen"
	$ERCSIPMain.MaximizeBox = $false
	$ERCSIPMain.FormBorderStyle = 'Fixed3D'
	$ERCSIPMain.ShowIcon = $false
	$ERCSIPMan = $ERCSIPMain.ShowDialog()
	#endregion .NET

		if ($ERCSIPMan -eq [System.Windows.Forms.DialogResult]::OK)
		{
			$global:progresspreference ="SilentlyContinue"
			if(!($ERCSIPTextBox.Text -match "x"))
			{
				Write-Host "`n `t[INFO] Testing connectivity to $($ERCSIPTextBox.Text)" -ForegroundColor Green
				$ERCSIPUserEntry = Test-NetConnection -port 5985 -ComputerName $ERCSIPTextBox.Text -InformationLevel Quiet
					if($ERCSIPUserEntry -eq $true)
					{
						Write-Host "`tSuccess"
						$IP = $ERCSIPTextBox.Text
					}
			}
			else
			{
				Write-Host "`n `t[INFO] Unable to find ip address of Emergency Recovery Console Session via manual entry" -ForegroundColor  DarkYellow
			}
			$global:progresspreference ="Continue"
		}
}

#Get Stamp Timezone
If (!($StampTimeZone))
{
$SelCurrentTimeZone = [system.timezoneinfo]::GetSystemTimeZones() | Out-GridView -PassThru -Title "Select AzureStack Stamp installed timezone"
[String]$StampTimeZone = $SelCurrentTimeZone.Id
	If ($StampTimeZone -eq $null)
	{
	Write-Host "`n Press any key to continue ...`n"
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
	}
}

#Search for ERCS
if(!($IP))
{
	#region .NET Search
	[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
	$SearchMainForm = New-Object -TypeName System.Windows.Forms.Form
	[System.Windows.Forms.Label]$SearchLabel = $null
	[System.Windows.Forms.Button]$SearchNo = $null
	[System.Windows.Forms.Button]$SearchYes = $null
	[System.Windows.Forms.Button]$button1 = $null

	$SearchLabel = New-Object -TypeName System.Windows.Forms.Label
	$SearchNo = New-Object -TypeName System.Windows.Forms.Button
	$SearchYes = New-Object -TypeName System.Windows.Forms.Button
	$SearchMainForm.SuspendLayout()
	#
	#SearchLabel
	#
	$SearchLabel.AutoSize = $true
	$SearchLabel.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,38)
	$SearchLabel.Name = 'SearchLabel'
	$SearchLabel.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(295,13)
	$SearchLabel.TabIndex = 0
	$SearchLabel.Text = 'Install powershell modules to search for Privileged End Point?'
	#
	#SearchYes
	#
	$SearchYes.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(70,87)
	$SearchYes.Name = 'SearchYes'
	$SearchYes.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
	$SearchYes.TabIndex = 1
	$SearchYes.Text = 'Yes'
	$SearchYes.UseVisualStyleBackColor = $true
	$SearchYes.DialogResult = [System.Windows.Forms.DialogResult]::Yes
	#
	#SearchNo
	#
	$SearchNo.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(174,87)
	$SearchNo.Name = 'SearchNo'
	$SearchNo.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
	$SearchNo.TabIndex = 2
	$SearchNo.Text = 'No'
	$SearchNo.UseVisualStyleBackColor = $true
	$SearchNo.DialogResult = [System.Windows.Forms.DialogResult]::No
	#
	#SearchMainForm
	#
	$SearchMainForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(330,138)
	$SearchMainForm.Controls.Add($SearchYes)
	$SearchMainForm.Controls.Add($SearchNo)
	$SearchMainForm.Controls.Add($SearchLabel)
	$SearchMainForm.Name = 'SearchMainForm'
	$SearchMainForm.ResumeLayout($false)
	$SearchMainForm.AcceptButton = $SearchYes
	$SearchMainForm.PerformLayout()
	Add-Member -InputObject $SearchMainForm -Name base -Value $base -MemberType NoteProperty
	Add-Member -InputObject $SearchMainForm -Name SearchLabel -Value $SearchLabel -MemberType NoteProperty
	Add-Member -InputObject $SearchMainForm -Name SearchNo -Value $SearchNo -MemberType NoteProperty
	Add-Member -InputObject $SearchMainForm -Name SearchYes -Value $SearchYes -MemberType NoteProperty
	Add-Member -InputObject $SearchMainForm -Name button1 -Value $button1 -MemberType NoteProperty
	$SearchMainForm.Topmost = $True
	$SearchMainForm.StartPosition = "CenterScreen"
	$SearchMainForm.MaximizeBox = $false
	$SearchMainForm.FormBorderStyle = 'Fixed3D'
	$SearchMainForm.ShowIcon = $false
	$SearchQuestion = $SearchMainForm.ShowDialog()


	if ($SearchQuestion -eq [System.Windows.Forms.DialogResult]::No)
	{$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown");exit}
	if ($SearchQuestion -eq [System.Windows.Forms.DialogResult]::Yes)
	{

			#AD Query
		if(!($IP))
		{
			#AD Query
			if(!($IP))
			{
			$moduleName = $null
			$moduleName = "ActiveDirectory"
			#inform the user of that we are doing
			Write-Host "`n`t[INFO] Checking for AD powershell module" -ForegroundColor Green

			try 
			{
				if (load_module $moduleName)
				{
					Write-Host "`n`t[Info] Loaded $($moduleName)" -ForegroundColor Green
				}
				else
				{
					Write-Host "`n`t`t[Warning] Failed to load $($moduleName)" -ForegroundColor Yellow
					Write-Host "`n`t[Info] Installing module $($moduleName)" -ForegroundColor Gray
					Install-WindowsFeature -Name RSAT-AD-PowerShell
					$ADModule = 1
					Try
					{
						if (load_module $moduleName)
						{
							Write-Host "`n`t`t[Info] Loaded $($moduleName)" -ForegroundColor White
						}
					}
					catch 
					{
					Write-Host "`n`t[Error] Exception caught: $_" -ForegroundColor Red
					Write-Host "`n Press any key to continue ...`n"
					$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
					exit
					}
				}
			}
			catch 
			{
				Write-Host "`n`t`t[Error] Exception caught: $_" -ForegroundColor Red
				Write-Host "`n Press any key to continue ...`n"
				$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
				exit
			}

			#go get the computers and find ECR machines
			$ERCSNames = $null
			$ERCIPInfo = $null
			$selERC = $null
			Write-Host "`n`t[Info] Querying for Emergency Recovery Console Session with AD" -ForegroundColor Green
			[Array] $ERCSNames = Get-ADComputer -Filter 'ObjectClass -eq "Computer"' | where {$_.name -like "*-Ercs*"} | Select -Expand Name
			foreach ($name in $ERCSNames)
				{
					$ERCName = Resolve-DnsName -name $name | select Name, Ipaddress
					[array]$ERCIPInfo += $ERCName
				}
		
			#pick Emergency Recovery Console Session	
			$selERC = $ERCIPInfo | Out-GridView -PassThru -Title "Select Emergency Recovery Console Session"
			$IP = $selERC.ipaddress
			}
			else
				{
			Write-Host "`n`t[INFO] Unable to find ip address of Emergency Recovery Console Session via AD" -ForegroundColor  DarkYellow
			}
		}

		#DNS QUERY
		if(!($IP))
		{
			#DNS QUERY A records
			if(!($IP))
																																																																{
			try 
			{
				$moduleName = $null
				$moduleName = "DnsServer"
				#inform the user of that we are doing
				Write-Host "`n`t[INFO] Checking for DNS powershell module" -ForegroundColor White
	    
				if (load_module $moduleName)
				{
					Write-Host "`n`t[INFO] Loaded $($moduleName)" -ForegroundColor Green
				}
				else
				{
					Write-Host "`n`t`t[Warning] Failed to load $($moduleName)" -ForegroundColor Yellow
					Write-Host "`n`t[INFO] Installing module $($moduleName)" -ForegroundColor Gray
					Install-WindowsFeature -Name RSAT-DNS-Server
					$DNSModule = 1
					Try
					{
						if (load_module $moduleName)
						{
							Write-Host "`n`t`t[INFO] Loaded $($moduleName)" -ForegroundColor White
						}
					}
					catch 
					{
					Write-Host "`n`t[Error] Exception caught: $_" -ForegroundColor Red
					Write-Host "`n Press any key to continue ...`n"
					$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
					exit
					}
				}
			}
			catch 
			{
				Write-Host "`n`t`t[Error] Exception caught: $_" -ForegroundColor Red
				Write-Host "`n Press any key to continue ...`n"
				$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
				exit
			}
			Write-Host "`n`t[INFO] Looking for Emergency Recovery Console Session via DNS"
			$DnsServers = $null
			$server = $null
			$Zones = $null
			$Zone = $null
			$ErcServers = $null
			$ERCSSERVER = $null
			Write-Host "`n`t[INFO] Querying for Emergency Recovery Console Session A records" -ForegroundColor White
			[array]$DnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object –ExpandProperty ServerAddresses
			$DnsServers = $DnsServers | select -uniq
			ForEach ($server in $DnsServers)
				{
					$Zones = @(Get-DnsServerZone -ComputerName $server)
					ForEach ($Zone in $Zones)
					{
					[array]$ERCSSERVER= Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName -ComputerName $server -RRType "A" | select HostName,RecordType,Timestamp,TimeToLive,@{Name='RecordData';Expression={$_.RecordData.IPv4Address.ToString()}} | where {$_.Hostname -like "*-ERCS*"} 
					[array]$ErcServers += $ERCSSERVER
					}
				}
			$nodupERCs = $ErcServers | Sort-Object -Property RecordData -Unique
			$SelErcServers = $nodupERCs | Select-Object HostName, RecordData | Out-GridView -PassThru -Title "Select Emergency Recovery Console Session"
			$IP = $SelErcServers.RecordData
			}
			# look for forwarders then change out the IP addresses to likly ERCS ip addresses then test connection 
			if (!($IP))
				{
					Write-host "`n`t[INFO] Unable to locate via DNS A record search." -ForegroundColor White
					Write-host "`n`t[INFO] Searching for AzureStack.local zones" -ForegroundColor White

					[array]$DNSServers=Get-DNSClientServerAddress -AddressFamily IPv4 | ?{$_.ServerAddresses -ne $null} | Select ServerAddresses -Unique
						foreach ($DNSServer in $DNSServers)
						{
							[array]$AzSDNSSvrs+= get-dnsserverzone -computername $($DNSServer.ServerAddresses) | ?{$_.ZoneName -like "*azurestack.local"} 
						}
						If ($AzSDNSSvrs.ZoneType -contains "Forwarder")
						{
							foreach($AzSDNSSvr in $AzSDNSSvrs.MasterServers)
							{
								[array]$IPArrays+=(($AzSDNSSvr.IPAddressToString -split "\.")[0..2]) -join "."
							}
						$IPArrays = $IPArrays| select -Unique
						foreach($iparray in $IPArrays)
						{
							[Array]$GuessERCS += $IPArray + "." + "225"
							[Array]$GuessERCS += $IPArray + "." + "226"
							[Array]$GuessERCS += $IPArray + "." + "227"
						}
								ForEach ($ERCTest in $GuessERCS)
								{
									$global:progresspreference ="SilentlyContinue"
									$DNSGuessName = Test-NetConnection -port 5985 -ComputerName $ERCTest
										If ($GuessName.TcpTestSucceeded -eq "True")
										{
											[Array]$DNSListeningNames += $DNSGuessName.RemoteAddress.IPAddressToString
										}
           
								}
							$global:progresspreference ="Continue"
							$DNSselName = $DNSListeningNames |Out-GridView -PassThru -Title "Select Emergency Recovery Console Session"
							$IP = $DNSselName
						}
					else
						{
							Write-Host "`n`t[INFO] Unable to find ip address of Emergency Recovery Console Session via DNS" -ForegroundColor  White
						}
				}		

		}

		#BestguessIP
		if(!($IP))
		{
			function Read-InputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText)
			{
				Add-Type -AssemblyName Microsoft.VisualBasic
				return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $WindowTitle, $DefaultText)
			}

			Write-Host "`n`t[Prompt] for Azure Stack Portal"
			$AzSPortal = Read-InputBoxDialog -Message "Please enter Azure Stack Portal:" -WindowTitle "Azure Stack Portal" -DefaultText "http://portal.local.azurestack.external"

			$Tenant = ($AzSPortal -split "//")[-1] 

			$portal= Test-NetConnection -Port 443 -ComputerName $Tenant

			If ($portal.TcpTestSucceeded -eq "True")
			{
				$octet = $portal.Remoteaddress.IPAddressToString
				$occarr = $octet.split(".")
				[Array]$GuessERCS += $occarr[0] + "." + $occarr[1] + "." + $occarr[2] + "." + "225"
				[Array]$GuessERCS += $occarr[0] + "." + $occarr[1] + "." + $occarr[2] + "." + "226"
				[Array]$GuessERCS += $occarr[0] + "." + $occarr[1] + "." + $occarr[2] + "." + "227"
				[Array]$GuessERCS += $occarr[0] + "." + $occarr[1] + "." + "200" + "." + "225" #for devkit
			}

			ForEach ($GuessERC in $GuessERCS)
				{
				 $global:progresspreference ="SilentlyContinue"
				$GuessIP = Test-NetConnection -port 5985 -ComputerName $GuessERC
				If ($GuessIP.TcpTestSucceeded -eq "True")
					{
					[Array]$Listeningips += $GuessIP.RemoteAddress.IPAddressToString
					}
				}
			$global:progresspreference ="Continue"
			$selIP = $Listeningips |Out-GridView -PassThru -Title "Select Emergency Recovery Console Session"
			$IP = $selIP
		}
	}
	#endregion .NET Search
}

#Do Work
if($IP)
{

	function Convert-AZSServerTime
	(
	[parameter( Mandatory=$true)]            
	  [ValidateNotNullOrEmpty()]            
	  [datetime]$DateTime
	)  
	{
		$strCurrentTimeZone = $StampTimeZone
		$ToTimeZoneObj  = [system.timezoneinfo]::GetSystemTimeZones() | Where-Object {$_.id -eq $strCurrentTimeZone}
		$TargetZoneTime = [system.timezoneinfo]::ConvertTime($datetime, $ToTimeZoneObj) 
		$TargetZoneTime
	}

	Try
	{
		 Write-Host "`n `t[INFO] Using $($IP)" -ForegroundColor Green
		#Add this machine to trusted Hosts 
		$CurrentTrustedHost=(get-item WSMan:\localhost\Client\TrustedHosts).Value
		if($CurrentTrustedHost.Contains("*")){
			Write-Host "`n `t[WARNING] TrustedHosts contains a wildcard character" -ForegroundColor Yellow
		}
		elseif($CurrentTrustedHost -notcontains $IP)
		{
			if($CurrentTrustedHost -notlike $null)
			{
				$IPDiff= Compare-Object -ReferenceObject "$($IP)" -DifferenceObject ($CurrentTrustedHost -split ",") -IncludeEqual -PassThru
				$IPs=($IPDiff -join ",")
			}
			else
			{
				$IPs = $IP
			}
			Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$($IPs)" -Force
		}
		#gethostip
        $global:progresspreference ="SilentlyContinue"
		Write-Host "`n `t[INFO] Testing connectivity to $($IP)" -ForegroundColor Green
		$testconnect = Test-NetConnection -port 5985 -ComputerName $IP
		If ($testconnect.TcpTestSucceeded -eq "True")
		    {
				Write-Host "`tSuccess"
				If ($IncompleteDeployment -ne "Yes")
				{
				$remoteip = $testconnect.RemoteAddress.IPAddressToString
				$share = $testconnect.SourceAddress.IPAddress
				$myname = whoami
                $date = Get-Date -format MM-dd-hhmm
                $foldername = "-AzureStackLogs"
                $sharename = $date + $foldername
                If (!(Test-Path "$($Env:SystemDrive)\$($sharename)")) {$folder = New-Item -Path "$($Env:SystemDrive)\$($sharename)" -ItemType directory} 
                $foldershare= New-SMBShare –Name $sharename –Path "$($Env:SystemDrive)\$($sharename)" -FullAccess $myname
                If($foldershare){[string]$ShareINFO = "\\$($share)\$sharename"}
				}
			}
		Else
			{
                $global:progresspreference ="Continue"
  				Write-Host "`n `t[ERROR] Cannot connect to Emergency Recovery Console Session to $($remoteip) from $($share)" -ForegroundColor Red
				Write-Host "`n Press any key to continue ...`n"
				$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
				exit
			}
		$global:progresspreference ="Continue"
		#username to connect to AzureStack form
		if($AzSCredentials) {$mySecureCredentials = $AzSCredentials}
		if(!($AzSCredentials))
		{
			if(!($FoundDomainFQDN))
			{
			#region .NET
			[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
			[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
			$DomainForm = New-Object -TypeName System.Windows.Forms.Form
			[System.Windows.Forms.Button]$DomainOK = $null
			[System.Windows.Forms.TextBox]$Domaintextbox = $null
			[System.Windows.Forms.Label]$label1 = $null
			[System.Windows.Forms.Button]$button1 = $null
			
			$Domaintextbox = New-Object -TypeName System.Windows.Forms.TextBox
			$DomainOK = New-Object -TypeName System.Windows.Forms.Button
			$label1 = New-Object -TypeName System.Windows.Forms.Label
			$DomainForm.SuspendLayout()
			#
			#Domaintextbox
			#
			$Domaintextbox.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,45)
			$Domaintextbox.Name = 'Domaintextbox'
			$Domaintextbox.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(233,20)
			$Domaintextbox.TabIndex = 0
			$Domaintextbox.Text = 'AzureStack'
			#
			#DomainOK
			#
			$DomainOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
			$DomainOK.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(251,43)
			$DomainOK.Name = 'DomainOK'
			$DomainOK.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
			$DomainOK.TabIndex = 1
			$DomainOK.Text = 'OK'
			$DomainOK.UseVisualStyleBackColor = $true
			#
			#label1
			#
			$label1.AutoSize = $true
			$label1.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,19)
			$label1.Name = 'label1'
			$label1.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(233,13)
			$label1.TabIndex = 2
			$label1.Text = 'What is the AzureStack Internal Domain Name?'
			$label1.add_Click($label1_Click)
			#
			#DomainForm
			#
			$DomainForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(331,74)
			$DomainForm.Controls.Add($label1)
			$DomainForm.Controls.Add($DomainOK)
			$DomainForm.Controls.Add($Domaintextbox)
			$DomainForm.Name = 'DomainForm'
			$DomainForm.Text = 'AzureStack Domain Prompt'
			$DomainForm.add_Load($DomainForm_Load)
			$DomainForm.ResumeLayout($false)
			$DomainForm.PerformLayout()
			Add-Member -InputObject $DomainForm -Name base -Value $base -MemberType NoteProperty
			Add-Member -InputObject $DomainForm -Name DomainOK -Value $DomainOK -MemberType NoteProperty
			Add-Member -InputObject $DomainForm -Name Domaintextbox -Value $Domaintextbox -MemberType NoteProperty
			Add-Member -InputObject $DomainForm -Name label1 -Value $label1 -MemberType NoteProperty
			Add-Member -InputObject $DomainForm -Name button1 -Value $button1 -MemberType NoteProperty
			$DomainForm.Topmost = $True
			$DomainForm.StartPosition = "CenterScreen"
			$DomainForm.MaximizeBox = $false
			$DomainForm.FormBorderStyle = 'Fixed3D'
			$DomainForm.ShowIcon = $false
			[System.Object]$userinputdomain = $null
			$userinputdomain = $DomainForm.ShowDialog()
			#endregion .NET
			if ($userinputdomain -eq [System.Windows.Forms.DialogResult]::OK)
				{
					$FoundDomainFQDN = $Domaintextbox.Text
				}
			}
			if($FoundDomainFQDN)
			{
			$UserFoundDomainFQDN = ($FoundDomainFQDN + "\")
			}
			Write-Host "`n`t[PROMPT] Select a username for connecting to AzureStack PEP" -ForegroundColor Green
			#region .NET
			[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
			[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
			$UserForm = New-Object -TypeName System.Windows.Forms.Form
			[System.Windows.Forms.ComboBox]$comboBox1 = $null
			[System.Windows.Forms.Button]$ok = $null
			[System.Windows.Forms.Button]$button1 = $null

			$comboBox1 = New-Object -TypeName System.Windows.Forms.ComboBox
			$ok = New-Object -TypeName System.Windows.Forms.Button
			$UserForm.SuspendLayout()
			#
			#comboBox1
			#
			$comboBox1.FormattingEnabled = $true
			$comboBox1.Items.AddRange("$($UserFoundDomainFQDN)CloudAdmin")
			if($CheckADSK -eq 1) { $comboBox1.Items.AddRange("$($UserFoundDomainFQDN)AzureStackAdmin") }
			$comboBox1.Items.AddRange("User Input")
			$comboBox1.SelectedIndex = 0
			$comboBox1.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,29)
			$comboBox1.Name = 'comboBox1'
			$comboBox1.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(226,21)
			$comboBox1.TabIndex = 0
			#
			#ok
			#
			$ok.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(255,29)
			$ok.Name = 'ok'
			$ok.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
			$ok.TabIndex = 1
			$ok.Text = 'Ok'
			$ok.UseVisualStyleBackColor = $true
			$ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
			#
			#UserForm
			#
			$UserForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(344,74)
			$UserForm.Controls.Add($ok)
			$UserForm.Controls.Add($comboBox1)
			$UserForm.Name = 'UserForm'
			$UserForm.Text = 'Username for AzureStack'
			$UserForm.add_Load($MainForm_Load)
			$UserForm.ResumeLayout($false)
			Add-Member -InputObject $UserForm -Name base -Value $base -MemberType NoteProperty
			Add-Member -InputObject $UserForm -Name comboBox1 -Value $comboBox1 -MemberType NoteProperty
			Add-Member -InputObject $UserForm -Name ok -Value $ok -MemberType NoteProperty
			Add-Member -InputObject $UserForm -Name button1 -Value $button1 -MemberType NoteProperty
			$UserForm.Topmost = $True
			$UserForm.StartPosition = "CenterScreen"
			$UserForm.MaximizeBox = $false
			$UserForm.FormBorderStyle = 'Fixed3D'
			$UserForm.ShowIcon = $false
			$AzsUser = $UserForm.ShowDialog()
			#endregion .NET
			if ($AzsUser -eq [System.Windows.Forms.DialogResult]::OK)
			{
			Write-Host "`tSelected $($comboBox1.SelectedItem)" -ForegroundColor White
				If($comboBox1.SelectedItem -eq "User Input")
				{$selAzSUser = $null}else{[string]$selAzSUser = $comboBox1.SelectedItem} 
			}
			#Username and password colection
			Write-Host "`n`t[PROMPT] Enter credential to connect to AzureStack PEP" -ForegroundColor Green
			$mySecureCredentials = Get-Credential -Message "Azure Stack credentials" -UserName $selAzSUser 
		}
		#localShareUserINFO
		if(!($LocalShareCred))
		{
			$name = whoami
			$localComputer = (gwmi Win32_ComputerSystem).Name
			$LocalShareCred = Get-Credential -UserName $name -Message "Local share credentials"
			$localusername = $LocalShareCred.username 
			$localpassword = $LocalShareCred.GetNetworkCredential().password 
			$LocalUsers = ("$localComputer"+"$localusername")
			$localCurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName 
			$localdomain = New-Object System.DirectoryServices.DirectoryEntry($localCurrentDomain,$localusername,$localpassword) 
			$localmachine = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
			$localval = $localmachine.ValidateCredentials($localusername, $localpassword)
 
			if (($localdomain.name -eq $null) -and ($localval -eq $false))
			{ 
			Write-Host "`n`t[ERROR] Authentication failed for $($localusername)" -ForegroundColor Red
			Write-Host "`n Press any key to continue ...`n"
			$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
			exit
			} 
			else 
			{ 
			Write-Host "`n `t[INFO] Successfully authenticated as $($localusername)" -ForegroundColor Green
			} 
		}
		#form for start question
		if (!($FromDate))
		{   
			#region .NET
			[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
			[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
			$TimeForm = New-Object -TypeName System.Windows.Forms.Form
			[System.Windows.Forms.DateTimePicker]$StartTimePicker = $null
			[System.Windows.Forms.Label]$Start = $null
			[System.Windows.Forms.Label]$24Hour = $null
			[System.Windows.Forms.Label]$Occur = $null
			[System.Windows.Forms.Button]$TimeOk = $null
			[System.Windows.Forms.Button]$timecancel = $null
			[System.Windows.Forms.Button]$button1 = $null
			$StartTimePicker = New-Object -TypeName System.Windows.Forms.DateTimePicker
			$Start = New-Object -TypeName System.Windows.Forms.Label
			$24Hour = New-Object -TypeName System.Windows.Forms.Label
			$Occur = New-Object -TypeName System.Windows.Forms.Label
			$TimeOk = New-Object -TypeName System.Windows.Forms.Button
			$timecancel = New-Object -TypeName System.Windows.Forms.Button
			$TimeForm.SuspendLayout()
			#
			#StartTimePicker
			#
			$StartTimePicker.CustomFormat = 'MMMMdd, yyyy  |  HH:mm'
			$StartTimePicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
			$StartTimePicker.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(76,58)
			$StartTimePicker.Name = 'StartTimePicker'
			$StartTimePicker.ShowUpDown = $true
			$StartTimePicker.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(165,20)
			$StartTimePicker.TabIndex = 0
			$StartTimePicker.Value = (get-date).AddHours(-4)
			$StartTimePicker.MaxDate = (get-date).AddHours(-1)
			#
			#Start
			#
			$Start.AutoSize = $true
			$Start.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,62)
			$Start.Name = 'Start'
			$Start.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(58,13)
			$Start.TabIndex = 2
			$Start.Text = 'Start Time:'
			#
			#24Hour
			#
			$24Hour.AutoSize = $true
			$24Hour.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(103,95)
			$24Hour.Name = '24Hour'
			$24Hour.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(138,13)
			$24Hour.TabIndex = 4
			$24Hour.Text = '** All times in 24 hour format'
			#
			#Occur
			#
			$Occur.AutoSize = $true
			$Occur.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,25)
			$Occur.Name = 'Occur'
			$Occur.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(127,13)
			$Occur.TabIndex = 5
			$Occur.Text = 'When did the issue start?'
			#
			#TimeOk
			#
			$TimeOk.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(162,131)
			$TimeOk.Name = 'TimeOk'
			$TimeOk.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(96,28)
			$TimeOk.TabIndex = 6
			$TimeOk.Text = 'Ok'
			$TimeOk.UseVisualStyleBackColor = $true
			$TimeOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
			#
			#timecancel
			#
			$timecancel.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(15,131)
			$timecancel.Name = 'timecancel'
			$timecancel.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(99,28)
			$timecancel.TabIndex = 7
			$timecancel.Text = 'Cancel'
			$timecancel.UseVisualStyleBackColor = $true
			$timecancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
			#
			#TimeForm
			#
			$TimeForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(270,180)
			$TimeForm.Controls.Add($timecancel)
			$TimeForm.Controls.Add($TimeOk)
			$TimeForm.Controls.Add($Occur)
			$TimeForm.Controls.Add($24Hour)
			$TimeForm.Controls.Add($Start)
			$TimeForm.Controls.Add($StartTimePicker)
			$TimeForm.Name = 'TimeForm'
			$TimeForm.Text = 'Issue occurrence'
			$TimeForm.ResumeLayout($false)
			$TimeForm.PerformLayout()
			Add-Member -InputObject $TimeForm -Name base -Value $base -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name StartTimePicker -Value $StartTimePicker -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name Start -Value $Start -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name 24Hour -Value $24Hour -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name Occur -Value $Occur -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name TimeOk -Value $TimeOk -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name timecancel -Value $timecancel -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name button1 -Value $button1 -MemberType NoteProperty
			$TimeForm.Topmost = $True
			$TimeForm.StartPosition = "CenterScreen"
			$TimeForm.MaximizeBox = $false
			$TimeForm.FormBorderStyle = 'Fixed3D'
			$TimeForm.ShowIcon = $false
			$timeresult = $TimeForm.ShowDialog()
			#endregion .NET
			if ($timeresult -eq [System.Windows.Forms.DialogResult]::Cancel){$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown");exit}
			if ($timeresult -eq [System.Windows.Forms.DialogResult]::OK)
			{
				[DateTime]$FromDate = $StartTimePicker.Value
				if($FromDate -lt (get-date))
				{
				Write-Host "`n`t[INFO] When should tracing Start?" -ForegroundColor Green
				Write-Host "`tSelected   $($FromDate)"
				$AzSFromDate = Convert-AZSServerTime -DateTime $FromDate
				Write-Host "`tStamp Time $($AzSFromDate)" -ForegroundColor Gray
				}
				else
				{
				Write-Host "`n`t[ERROR] Date entry incorrect" -ForegroundColor Red
				Write-Host "`n Press any key to continue ...`n"
				$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
				exit	
				}
			}
		}
		if (!($ToDate))
		{
			#region .NET
			[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
			[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
			$TimeForm = New-Object -TypeName System.Windows.Forms.Form
			[System.Windows.Forms.Label]$24Hour = $null
			[System.Windows.Forms.Label]$Occur = $null
			[System.Windows.Forms.Button]$TimeOk = $null
			[System.Windows.Forms.Button]$timecancel = $null
			[System.Windows.Forms.DateTimePicker]$EndTimePicker = $null
			[System.Windows.Forms.Label]$End = $null
			[System.Windows.Forms.Button]$button1 = $null
			$24Hour = New-Object -TypeName System.Windows.Forms.Label
			$Occur = New-Object -TypeName System.Windows.Forms.Label
			$TimeOk = New-Object -TypeName System.Windows.Forms.Button
			$timecancel = New-Object -TypeName System.Windows.Forms.Button
			$EndTimePicker = New-Object -TypeName System.Windows.Forms.DateTimePicker
			$End = New-Object -TypeName System.Windows.Forms.Label
			$TimeForm.SuspendLayout()
			#
			#24Hour
			#
			$24Hour.AutoSize = $true
			$24Hour.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(103,102)
			$24Hour.Name = '24Hour'
			$24Hour.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(138,13)
			$24Hour.TabIndex = 4
			$24Hour.Text = '** All times in 24 hour format'
			#
			#Occur
			#
			$Occur.AutoSize = $true
			$Occur.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,25)
			$Occur.Name = 'Occur'
			$Occur.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(125,13)
			$Occur.TabIndex = 5
			$Occur.Text = 'When did the issue end?'
			#
			#TimeOk
			#
			$TimeOk.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(162,138)
			$TimeOk.Name = 'TimeOk'
			$TimeOk.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(96,23)
			$TimeOk.TabIndex = 6
			$TimeOk.Text = 'Ok'
			$TimeOk.UseVisualStyleBackColor = $true
			$TimeOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
			#
			#timecancel
			#
			$timecancel.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(15,138)
			$timecancel.Name = 'timecancel'
			$timecancel.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(99,23)
			$timecancel.TabIndex = 7
			$timecancel.Text = 'Cancel'
			$timecancel.UseVisualStyleBackColor = $true
			$timecancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
			#
			#EndTimePicker
			#
			$EndTimePicker.CustomFormat = 'MMMMdd, yyyy  |  HH:mm'
			$EndTimePicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
			$EndTimePicker.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(82,59)
			$EndTimePicker.Name = 'EndTimePicker'
			$EndTimePicker.ShowUpDown = $true
			$EndTimePicker.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(165,20)
			$EndTimePicker.TabIndex = 1
			$EndTimePicker.Value = (get-date)
			$EndTimePicker.MaxDate = (get-date)
			$EndTimePicker.MinDate = $StartTimePicker.Value.AddHours(1)
			#
			#End
			#
			$End.AutoSize = $true
			$End.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(18,63)
			$End.Name = 'End'
			$End.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(55,13)
			$End.TabIndex = 3
			$End.Text = 'End Time:'
			#
			#TimeForm
			#
			$TimeForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(270,181)
			$TimeForm.Controls.Add($timecancel)
			$TimeForm.Controls.Add($TimeOk)
			$TimeForm.Controls.Add($Occur)
			$TimeForm.Controls.Add($24Hour)
			$TimeForm.Controls.Add($End)
			$TimeForm.Controls.Add($EndTimePicker)
			$TimeForm.Name = 'TimeForm'
			$TimeForm.Text = 'Issue occurrence'
			$TimeForm.ResumeLayout($false)
			$TimeForm.PerformLayout()
			Add-Member -InputObject $TimeForm -Name base -Value $base -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name 24Hour -Value $24Hour -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name Occur -Value $Occur -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name TimeOk -Value $TimeOk -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name timecancel -Value $timecancel -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name EndTimePicker -Value $EndTimePicker -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name End -Value $End -MemberType NoteProperty
			Add-Member -InputObject $TimeForm -Name button1 -Value $button1 -MemberType NoteProperty
			$TimeForm.Topmost = $True
			$TimeForm.StartPosition = "CenterScreen"
			$TimeForm.MaximizeBox = $false
			$TimeForm.FormBorderStyle = 'Fixed3D'
			$TimeForm.ShowIcon = $false
			$timeresult = $TimeForm.ShowDialog()
			#endregion .NET
        	if ($timeresult -eq [System.Windows.Forms.DialogResult]::Cancel){$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown");exit}
			if ($timeresult -eq [System.Windows.Forms.DialogResult]::OK)
			{
				[DateTime]$ToDate = $EndTimePicker.Value
				if($ToDate -gt ($FromDate))
				{
				Write-Host "`n`t[INFO] When should tracing Stop?" -ForegroundColor Green
				Write-Host "`tSelected   $($ToDate)"
				$AzSToDate = Convert-AZSServerTime -DateTime $ToDate
				Write-Host "`tStamp Time $($AzSToDate)"  -ForegroundColor Gray
				}
				else
				{
				Write-Host "`n`t[ERROR] Date entry incorrect" -ForegroundColor Red
				Write-Host "`n Press any key to continue ...`n"
				$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
				exit	
				}
			}
		}
        #Set the time out here to account for timezones changes Convert-AZSServerTime will make
        if($AzSFromDate){$FromDate = $AzSFromDate}
        if($AzSToDate){$ToDate = $AzSToDate}
		# filter by role form
		If(!($FilterByRole))
		{
			Write-Host "`n`t[PROMPT] What should be collected?" -ForegroundColor Green
			#region .NET
			[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
			[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
			$MainForm = New-Object -TypeName System.Windows.Forms.Form
			[System.Windows.Forms.CheckedListBox]$checkedListBox1 = $null
			[System.Windows.Forms.Button]$buttonselect = $null
			[System.Windows.Forms.Button]$buttondefault = $null
			[System.Windows.Forms.Button]$button1 = $null
			[System.Windows.Forms.Label]$label1 = $null
			[System.Windows.Forms.Label]$label2 = $null
			[System.Object]$selLogCollection = $null

			$checkedListBox1 = New-Object -TypeName System.Windows.Forms.CheckedListBox
			$buttonselect = New-Object -TypeName System.Windows.Forms.Button
			$buttondefault = New-Object -TypeName System.Windows.Forms.Button
			$label1 = New-Object -TypeName System.Windows.Forms.Label
			$label2 = New-Object -TypeName System.Windows.Forms.Label
			$MainForm.SuspendLayout()
			#
			#checkedListBox1
			#
			$checkedListBox1.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,12)
			$checkedListBox1.Items.AddRange("ACS")
			$checkedListBox1.Items.AddRange("ACSBlob")
			$checkedListBox1.Items.AddRange("ACSFabric")
			$checkedListBox1.Items.AddRange("ACSFrontEnd")
			$checkedListBox1.Items.AddRange("ACSMetrics")
			$checkedListBox1.Items.AddRange("ACSMigrationService")
			$checkedListBox1.Items.AddRange("ACSMonitoringService")
			$checkedListBox1.Items.AddRange("ACSSettingsService")
			$checkedListBox1.Items.AddRange("ACSTableMaster")
			$checkedListBox1.Items.AddRange("ACSTableServer")
			$checkedListBox1.Items.AddRange("ACSWac")
			$checkedListBox1.Items.AddRange("ADFS")
			$checkedListBox1.Items.AddRange("ASAppGateway")
			$checkedListBox1.Items.AddRange("AzureBridge")
			$checkedListBox1.Items.AddRange("AzurePackConnector")
			$checkedListBox1.Items.AddRange("AzureStackBitlocker **")
			$checkedListBox1.Items.AddRange("BareMetal")
			$checkedListBox1.Items.AddRange("BGP *")
			$checkedListBox1.Items.AddRange("BRP")
			$checkedListBox1.Items.AddRange("CA")
			$checkedListBox1.Items.AddRange("Cloud")
			$checkedListBox1.Items.AddRange("Compute **")
			$checkedListBox1.Items.AddRange("CPI")
			$checkedListBox1.Items.AddRange("CRP")
			$checkedListBox1.Items.AddRange("DatacenterIntegration")
			$checkedListBox1.Items.AddRange("DeploymentMachine **")
			$checkedListBox1.Items.AddRange("Domain")
			$checkedListBox1.Items.AddRange("ECE")
			$checkedListBox1.Items.AddRange("ExternalDNS")
			$checkedListBox1.Items.AddRange("Fabric")
			$checkedListBox1.Items.AddRange("FabricRing")
			$checkedListBox1.Items.AddRange("FabricRingServices")
			$checkedListBox1.Items.AddRange("FRP")
			$checkedListBox1.Items.AddRange("Gallery")
			$checkedListBox1.Items.AddRange("Gateway")
			$checkedListBox1.Items.AddRange("HealthMonitoring")
			$checkedListBox1.Items.AddRange("HRP")
			$checkedListBox1.Items.AddRange("IBC")
			$checkedListBox1.Items.AddRange("IdentityProvider")
			$checkedListBox1.Items.AddRange("iDns")
			$checkedListBox1.Items.AddRange("InfraServiceController")
			$checkedListBox1.Items.AddRange("Infrastructure")
			$checkedListBox1.Items.AddRange("KeyVaultAdminResourceProvider")
			$checkedListBox1.Items.AddRange("KeyVaultControlPlane")
			$checkedListBox1.Items.AddRange("KeyVaultDataPlane")
			$checkedListBox1.Items.AddRange("KeyVaultInternalControlPlane")
			$checkedListBox1.Items.AddRange("KeyVaultInternalDataPlane")
			$checkedListBox1.Items.AddRange("KeyVaultNamingService")
			$checkedListBox1.Items.AddRange("MonitoringAgent")
			$checkedListBox1.Items.AddRange("NC")
			$checkedListBox1.Items.AddRange("NonPrivilegedAppGateway")
			$checkedListBox1.Items.AddRange("NRP")
			$checkedListBox1.Items.AddRange("OEM **")
			$checkedListBox1.Items.AddRange("PXE **")
			$checkedListBox1.Items.AddRange("POC *")
			$checkedListBox1.Items.AddRange("SeedRing")
			$checkedListBox1.Items.AddRange("SeedRingServices")
			$checkedListBox1.Items.AddRange("SLB")
			$checkedListBox1.Items.AddRange("SlbVips")
			$checkedListBox1.Items.AddRange("SQL")
			$checkedListBox1.Items.AddRange("SRP")
			$checkedListBox1.Items.AddRange("Storage")
			$checkedListBox1.Items.AddRange("StorageAccounts")
			$checkedListBox1.Items.AddRange("StorageController")
			$checkedListBox1.Items.AddRange("Tenant")
			$checkedListBox1.Items.AddRange("TraceCollector")
			$checkedListBox1.Items.AddRange("URP")
			$checkedListBox1.Items.AddRange("UsageBridge")
			$checkedListBox1.Items.AddRange("VirtualMachines")
			$checkedListBox1.Items.AddRange("WAS")
			$checkedListBox1.Items.AddRange("WASBootstrap")
			$checkedListBox1.Items.AddRange("WASPUBLIC")
			$checkedListBox1.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(260,214)
			$checkedListBox1.TabIndex = 0
			#
			#buttonselect
			#
			$buttonselect.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,262)
			$buttonselect.Name = 'buttonselect'
			$buttonselect.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(121,23)
			$buttonselect.TabIndex = 1
			$buttonselect.Text = 'Selected Item(s)'
			$buttonselect.UseVisualStyleBackColor = $true
			$buttonselect.DialogResult = [System.Windows.Forms.DialogResult]::OK
			#
			#buttondefault
			#
			$buttondefault.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(139,262)
			$buttondefault.Name = 'buttondefault'
			$buttondefault.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(133,23)
			$buttondefault.TabIndex = 2
			$buttondefault.Text = 'All Logs'
			$buttondefault.UseVisualStyleBackColor = $true
			$buttondefault.DialogResult = [System.Windows.Forms.DialogResult]::Ignore
			#
			#label1
			#
			$label1.AutoSize = $true
			$label1.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(9,229)
			$label1.Name = 'label1'
			$label1.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(67,13)
			$label1.TabIndex = 3
			$label1.Text = '* ASDK Only'
			$label1.add_Click($label1_Click)
			#
			#label2
			#
			$label2.AutoSize = $true
			$label2.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(9,242)
			$label2.Name = 'label2'
			$label2.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(88,13)
			$label2.TabIndex = 4
			$label2.Text = '** MutiNode Only'
			#
			#MainForm
			#
			$MainForm.AcceptButton = $buttondefault
			$MainForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(284,289)
			$MainForm.Controls.Add($label2)
			$MainForm.Controls.Add($label1)
			$MainForm.Controls.Add($buttondefault)
			$MainForm.Controls.Add($buttonselect)
			$MainForm.Controls.Add($checkedListBox1)
			$MainForm.Name = 'MainForm'
			$MainForm.Text = 'Log collection'
			$MainForm.ResumeLayout($false)
			$MainForm.AcceptButton = $buttondefault
			$MainForm.PerformLayout()
			Add-Member -InputObject $MainForm -Name base -Value $base -MemberType NoteProperty
			Add-Member -InputObject $MainForm -Name checkedListBox1 -Value $checkedListBox1 -MemberType NoteProperty
			Add-Member -InputObject $MainForm -Name buttonselect -Value $buttonselect -MemberType NoteProperty
			Add-Member -InputObject $MainForm -Name buttondefault -Value $buttondefault -MemberType NoteProperty
			Add-Member -InputObject $MainForm -Name button1 -Value $button1 -MemberType NoteProperty
			Add-Member -InputObject $MainForm -Name label1 -Value $label1 -MemberType NoteProperty
			Add-Member -InputObject $MainForm -Name label2 -Value $label2 -MemberType NoteProperty
			Add-Member -InputObject $MainForm -Name selLogCollection -Value $selLogCollection -MemberType NoteProperty
			$MainForm.Topmost = $True
			$MainForm.StartPosition = "CenterScreen"
			$MainForm.MaximizeBox = $false
            $MainForm.FormBorderStyle = 'Fixed3D'
			$MainForm.ShowIcon = $false
			$LogCollection = $MainForm.ShowDialog()
			#region .NET
			 if ($LogCollection -eq [System.Windows.Forms.DialogResult]::OK)
			 {
			 [string[]]$FilterByRole = ((($checkedListBox1.CheckedItems -replace "[*]").Trim()) | Select-Object -Unique)
			  Write-Host "`tSelected $($FilterByRole) for log collection" -ForegroundColor White
			  $UserFilterByRole = $FilterByRole
			  #makeing sure we get Test-AzureStack output
				if($FilterByRole -notcontains "SeedRing")
				{
					$FilterByRole += "SeedRing"
				}
			 }
			 if ($LogCollection -eq [System.Windows.Forms.DialogResult]::Ignore)
			 {
			 Write-Host "`tSelected default role log collection" -ForegroundColor White
			 $defaultLogCollection = $true
			 }
			$maxtimespan = new-timespan -Days 0 -Hours 7 -Minutes 59 -Seconds 0
			if (($defaultLogCollection -eq $true) -and (($ToDate - $FromDate) -ge $maxtimespan))
			{
				If ($IncompleteDeployment -ne "Yes"){Write-Host "`t[WARNING] Log truncation probable" -ForegroundColor Yellow}
			}
		}
		If($IncompleteDeployment -eq "Yes")
		{ 
			$checkdiag = test-path -Path "$($env:SystemDrive)\CloudDeployment\AzureStackDiagnostics\Microsoft.AzureStack.Diagnostics.DataCollection\Microsoft.AzureStack.Diagnostics.DataCollection.psm1"
			if($checkdiag -eq $true)
			{
				Import-Module "$($env:SystemDrive)\CloudDeployment\AzureStackDiagnostics\Microsoft.AzureStack.Diagnostics.DataCollection\Microsoft.AzureStack.Diagnostics.DataCollection.psm1" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 
				$AzSDig = Get-Module -Name Microsoft.AzureStack.Diagnostics.DataCollection
			}
				if ($AzSDig.Name -eq "Microsoft.AzureStack.Diagnostics.DataCollection")
				{
					$incompletedeploymentdate = Get-Date -format MM-dd-hhmm
					$incompletedeploymentfoldername = "-IncompleteDeployment_AzureStackLogs"
					$incompletedeploymentsharename = $incompletedeploymentdate + $incompletedeploymentfoldername
					If (!(Test-Path "$($Env:SystemDrive)\$($incompletedeploymentsharename)")) {$incompletedeploymentfolder = New-Item -Path "$($Env:SystemDrive)\$($incompletedeploymentsharename)" -ItemType directory} 
					Get-AzureStackLogs -OutputPath $incompletedeploymentfolder.FullName -FilterByRole $FilterByRole -FromDate $FromDate -ToDate $ToDate
				}
				Else
				{
					Write-Host "`n[Error] unable to load Microsoft.AzureStack.Diagnostics.DataCollection: $_" -ForegroundColor Red
					$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
					exit
				}
				#remotepowershell
				$s = New-PSSession -ComputerName $IP -ConfigurationName PrivilegedEndpoint -Credential $mySecureCredentials
				Try
				{
				Write-Host "`n `t[INFO] Getting Azure Stack stamp information" -ForegroundColor Green
				Invoke-Command -Session $s -ScriptBlock {Get-AzureStackStampInformation -WarningAction SilentlyContinue} -OutVariable StampInformation -WarningAction SilentlyContinue | Out-Null
                Invoke-Command -Session $s -ScriptBlock {Get-VirtualDisk -CimSession S-Cluster} -OutVariable ClusterDiskInformation -WarningAction SilentlyContinue | Out-Null
				Invoke-Command -Session $s -ScriptBlock {Get-VirtualDisk -CimSession S-Cluster | Get-StorageJob } -OutVariable ActiveStorageRepairs -WarningAction SilentlyContinue | Out-Null
				Write-Host "`n `t[INFO] Saving AzureStackStampInformation to $($Env:ProgramData)" -ForegroundColor Green
				#overwriting AzureStackStampInformation keep the latest info JSON (StampVersion)
				$StampInformation | ConvertTo-Json | Out-File -FilePath "$($Env:ProgramData)\AzureStackStampInformation.json" -Force
				Write-Host "`n `t[INFO] Saving AzureStackStampInformation to $($Env:SystemDrive)\$($incompletedeploymentsharename)" -ForegroundColor Green
				$StampInformation | ConvertTo-Json | Out-File -FilePath "$($Env:SystemDrive)\$($incompletedeploymentsharename)\AzureStackStampInformation.json" -Force
                $ClusterDiskInformation | Out-File -FilePath "$($Env:SystemDrive)\$($incompletedeploymentsharename)\ClusterVirtualDiskInfo.txt" -Force
				}
				catch
				{
					Write-Host "`n[Error] unable to connect to PEP: $_" -ForegroundColor Red
				}
				#zip files
				try
				{
				Write-Host "`n`t[INFO] Compressing gathered files"  -ForegroundColor Green
				$zipdate = $incompletedeploymentdate
				if((Test-Path -Path $Env:SystemDrive\CloudDeployment\Logs) -eq $true)
				{Compress-Archive -Path (Get-ChildItem -Path $Env:SystemDrive\CloudDeployment\Logs).FullName -CompressionLevel Optimal -DestinationPath "$Env:SystemDrive\$incompletedeploymentsharename\$($zipdate)_CloudDeploymentLogs_archive.zip" -Force}
				if((Test-Path -Path $Env:SystemDrive\MASLogs) -eq $true)
				{Compress-Archive -Path (Get-ChildItem -Path $Env:SystemDrive\MASLogs).FullName -CompressionLevel Optimal -DestinationPath "$Env:SystemDrive\$incompletedeploymentsharename\$($zipdate)_MASLogs_archive.zip" -Force}
				Compress-Archive -Path (Get-ChildItem -Path $Env:SystemDrive\$incompletedeploymentsharename).FullName -CompressionLevel Optimal -DestinationPath "$Env:SystemDrive\$incompletedeploymentsharename\$($zipdate)_AzureStackLogs_archive.zip" -Force
				Write-Host "`tFile created: $Env:SystemDrive\$incompletedeploymentsharename\$($zipdate)_AzureStackLogs_archive.zip" -ForegroundColor White
				Invoke-Item $incompletedeploymentfolder.FullName
				Write-Host "`n `t[INFO] Opening $($incompletedeploymentfolder.FullName)" -ForegroundColor Green
				}
				catch
				{
				Write-Host "`n`t`t[WARN] Did not create a archive" -ForegroundColor Yellow
				}
			#cleanup
			exit
		}
		#setting remotepowershell options
		$switch = $true
		If($switch)
			{
				$switch = "Get-AzureStackLog -OutputSharePath `$using:ShareINFO -OutputShareCredential `$using:LocalShareCred -ErrorAction Stop "
				$Howto = "Get-AzureStackLog -OutputSharePath `"$($ShareINFO)`" -OutputShareCredential `$using:cred "
			}
		If($FromDate)
			{
				$switch += "-FromDate `$using:fromDate "
				$Howto += "-FromDate `"$($FromDate)`" "
			}
		If($ToDate)		
			{
				$switch += "-ToDate `$using:ToDate "
				$Howto += "-ToDate `"$($ToDate)`" "
			}
		#future use		
		Switch($Scenario)
			{
			"Service Fabric"	{<#$FilterByRole += "Something1","Something2","Something3","Something4","ETC"#>}
			"Storage"			{<#$FilterByRole += "Something1","Something2","Something3","Something4","ETC"#>}
			"Networking"		{<#$FilterByRole += "Something1","Something2","Something3","Something4","ETC"#>}
			"Identity"			{<#$FilterByRole += "Something1","Something2","Something3","Something4","ETC"#>}
			"Patch & Update"	{<#$FilterByRole += "Something1","Something2","Something3","Something4","ETC"#>}
			"Compute"			{<#$FilterByRole += "Something1","Something2","Something3","Something4","ETC"#>}
			"Backup"			{<#$FilterByRole += "Something1","Something2","Something3","Something4","ETC"#>}
			}
		If($FilterByRole)
			{
				$switch += "-FilterByRole `$using:FilterByRole "
				$Howto += "-FilterByRole `"$($UserFilterByRole)`" "
			}
		
		Write-Host "`n"
	    Write-Host -NoNewline " `t[INFO] Running:" -ForegroundColor White
        Write-Host -NoNewline " Enter-PSSession -ComputerName $($IP) -ConfigurationName PrivilegedEndpoint -Credential `$cred" -ForegroundColor Green

		#remotepowershell
		$s = New-PSSession -ComputerName $IP -ConfigurationName PrivilegedEndpoint -Credential $mySecureCredentials
		#run Test-AzureStack
		Try
		{
			Invoke-Command -Session $s -ScriptBlock {get-command -Name Test-AzureStack} -OutVariable TestAzS -InformationAction SilentlyContinue -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | out-null
			If($TestAzS.ModuleName -eq "Microsoft.AzureStack.Diagnostics.Validator")
			{
				$testJob = Invoke-Command -Session $s -ScriptBlock {Test-AzureStack -DoNotDeployTenantVm} -AsJob -InformationAction SilentlyContinue
				Write-Host "`n"
				Write-Host -NoNewline " `t[INFO] Running:" -ForegroundColor White
				Write-Host -NoNewline " Test-AzureStack" -ForegroundColor Green
       				while((get-job -Id $testJob.id).State -eq "Running")
				{
					$per = (Get-Random -Minimum 5 -Maximum 80); Start-Sleep -Milliseconds 1500
					Write-Progress -Activity "Please wait while script runs functionality testing on the stamp" -PercentComplete $per
				}
			}
		}
		catch
		{
			Write-Host "`n[Error] unable to run Test-AzureStack on PEP: $_" -ForegroundColor Red
		}

	    Write-Host "`n"
        Write-Host -NoNewline " `t[INFO] Running:" -ForegroundColor White
        Write-Host -NoNewline " $($Howto)" -ForegroundColor Green
		Write-Host "`n"

		Try
		{
			#do stuff on the remote machine
			$ScriptBlock = [scriptblock]::Create($switch)
			$Job = Invoke-Command -Session $s -ScriptBlock $ScriptBlock -AsJob
			while((get-job -Id $job.id).State -eq "Running")
			{
			  $per = (Get-Random -Minimum 5 -Maximum 80); Start-Sleep -Milliseconds 1500
			  Write-Progress -Activity "Please wait while Get-AzureStackLog is running on $($IP)" -PercentComplete $per
			}
			if((get-job -Id $job.id).State -eq "Failed")
			{
				Write-Progress -Activity "Please wait while Get-AzureStackLog is running on $($IP)" -Status "Ready" -Completed
				Write-Host "`n `t[INFO] Getting Azure Stack stamp information" -ForegroundColor Green
				Invoke-Command -Session $s -ScriptBlock {Get-AzureStackStampInformation -WarningAction SilentlyContinue} -OutVariable StampInformation -WarningAction SilentlyContinue | Out-Null
                Invoke-Command -Session $s -ScriptBlock {Get-VirtualDisk -CimSession S-Cluster} -OutVariable ClusterDiskInformation -WarningAction SilentlyContinue | Out-Null
				Invoke-Command -Session $s -ScriptBlock {Get-VirtualDisk -CimSession S-Cluster | Get-StorageJob } -OutVariable ActiveStorageRepairs -WarningAction SilentlyContinue | Out-Null
			}
			if((get-job -Id $job.id).State -eq "Completed")
			{
				Write-Progress -Activity "Please wait while Get-AzureStackLog is running on $($IP)" -Status "Ready" -Completed
				Write-Host "`n `t[INFO] Getting Azure Stack stamp information" -ForegroundColor Green
				Invoke-Command -Session $s -ScriptBlock {Get-AzureStackStampInformation -WarningAction SilentlyContinue} -OutVariable StampInformation -WarningAction SilentlyContinue | Out-Null
                Invoke-Command -Session $s -ScriptBlock {Get-VirtualDisk -CimSession S-Cluster} -OutVariable ClusterDiskInformation -WarningAction SilentlyContinue | Out-Null
				Invoke-Command -Session $s -ScriptBlock {Get-VirtualDisk -CimSession S-Cluster | Get-StorageJob } -OutVariable ActiveStorageRepairs -WarningAction SilentlyContinue | Out-Null
			}
			#output of files from the PEP
			if($StampInformation)
			{
				Write-Host "`n `t[INFO] Saving AzureStackStampInformation to $($Env:ProgramData)" -ForegroundColor Green
				#overwriting AzureStackStampInformation keep the latest info JSON (StampVersion)
				$StampInformation | ConvertTo-Json | Out-File -FilePath "$($Env:ProgramData)\AzureStackStampInformation.json" -Force
				Write-Host "`n `t[INFO] Saving AzureStackStampInformation to $($Env:SystemDrive)\$($sharename)" -ForegroundColor Green
				$StampInformation | ConvertTo-Json | Out-File -FilePath "$($Env:SystemDrive)\$($sharename)\AzureStackStampInformation.json" -Force
                $ClusterDiskInformation | Out-File -FilePath "$($Env:SystemDrive)\$($sharename)\ClusterVirtualDiskInfo.txt" -Force
			}
			if($CheckADSK -ne 1)
			{
				# output for transcript mutinode
				try
				{
				Write-Host "`n `t[INFO] Getting Azure Stack transcript" -ForegroundColor Green
				Invoke-Command -Session $s -ScriptBlock {Close-PrivilegedEndpoint -TranscriptsPathDestination $using:ShareINFO -Credential $using:LocalShareCred -ErrorAction SilentlyContinue -WarningAction SilentlyContinue} -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
				}
				catch [System.Management.Automation.RemoteException]
				{
					Write-Host "`n`t`t[Error] Exception caught: $_" -ForegroundColor Red
				}
			}
			else
			{
				Try
				{
				# output for transcript ASDK
				Write-Host "`n `t[INFO] Getting Azure Stack transcript" -ForegroundColor Green
				Invoke-Command -Session $s -ScriptBlock {Close-PrivilegedEndpoint -TranscriptsPathDestination "\\127.0.0.1\C`$" -WarningAction SilentlyContinue} -WarningAction SilentlyContinue
				$Transcript = Get-ChildItem -Path "\\$($IP)\C`$" | Where {($_.Name -like "Transcripts_*")} | sort -Descending -Property CreationTime | select -first 1
				#copy the transcript to share 
				Copy-Item -Path $Transcript.FullName -Destination $ShareINFO -Force
				#test to make sure the transcript is copied
				$localtranscript = Test-Path -Path "$($shareinfo)\$($Transcript.Name)"
				if ($localtranscript -eq $true) {Remove-Item -Path $Transcript.FullName -Force}
				}
				catch [System.Management.Automation.RemoteException]
				{
					Write-Host "`n`t`t[Error] Exception caught: $_" -ForegroundColor Red
				}
			}
		}
		finally
		{
			Remove-PSSession $s
		}
		#get files for user
		$Files = Get-ChildItem -Path "$($Env:SystemDrive)\$($sharename)" | Where {(($_.attributes -eq 'directory') -and ($_.Name -like "AzureStackLogs-*"))} | sort -Descending -Property CreationTime | select -first 1
       
		#get the validation report
		if($testJob)
		{
			try
			{
				Add-Type -Assembly System.IO.Compression.FileSystem
				$seedringzip = Get-ChildItem -Path "$($Files.FullName)" | Where {($_.Name -like "SeedRing-*.zip")} | sort -Descending -Property CreationTime | select -first 1
				$zip = [IO.Compression.ZipFile]::OpenRead($seedringzip.FullName)
				$Valreportdir  = "$($Env:SystemDrive)\$($sharename)\"
				$ValidationReport = $zip.Entries | where {$_.Name -like 'AzureStack_Validation_Summary_*.HTML'} | sort -Descending -Property LastWriteTime | select -first 1
				$ValidationReport | foreach {[IO.Compression.ZipFileExtensions]::ExtractToFile( $_, $Valreportdir + $_.Name) }
				$zip.Dispose()
			}
			catch [System.Exception]
			{
				Write-Host "`n`t`t[Error] Exception caught: $_" -ForegroundColor Red
			}
		}

		#look at output AzureStackLog_Output for issues
		$stacklog = Get-ChildItem -Path "$($Files.FullName)" | Where {($_.Name -like "Get-AzureStackLog_Output*")} | sort -Descending -Property CreationTime | select -first 1
		$stacklogerr = Select-String -Path $stacklog.FullName -Pattern "TerminatingError"
		$stacklogeerrdisk = Select-String -Path $stacklog.FullName -Pattern "There is not enough space on the disk."
		$stacklogeerrcode = Select-String -Path $stacklog.FullName -Pattern "0x85200001"
		if($stacklog)
		{
			Write-Host "`n`t[INFO] Reviewing Get-AzureStackLog_Output.log for known issues" -ForegroundColor Green
					if(!($stacklogerr))
					{
						Write-Host "`tNo issues found" -ForegroundColor White
					}
		}
		else
		{
			Write-Host "`t`t[ERROR] Get-AzureStackLog_Output.log file not found. Likely missing log files" -ForegroundColor Red
		}
		if($stacklogerr)
		{
			Write-Host "`t`t[ERROR] Get-AzureStackLog_Output.log has an terminating error" -ForegroundColor Red
		}
		if ($stacklogeerrdisk -and $stacklogerr)
		{
			Write-Host "`t`t`tERCS VM does not have enough space on the disk. Try lowering the log collection time."
		}
		if ($stacklogeerrcode -and $stacklogerr)
		{
			Write-Host "`t`t`t0x85200001"
		}

        #look at cluster disk state
        $ErrorClustervdisk = 0
        Write-Host "`n`t[INFO] Checking Vitual Disk state"  -ForegroundColor Green
         foreach ($clusterdisk in $ClusterDiskInformation)
         {
             if ($clusterdisk.HealthStatus -ne 0)
             {
             Write-Host "`t[ERROR] $($clusterdisk.FriendlyName) is not healthy" -ForegroundColor Red
             $ErrorClustervdisk += 1
             }
         }
        switch ($ErrorClustervdisk)
        {
            '0' {Write-Host "`tNo issues found" -ForegroundColor White}
            '1' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '2' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '3' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '4' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '5' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '6' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '7' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '8' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '9' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '10' {Write-Host "`n`t[INFO] In the PEP run 'Get-VirtualDisk -CimSession S-Cluster | Repair-VirtualDisk'" -ForegroundColor Yellow}
            '11' {Write-Host "`n`t[INFO] Likely Node missing from cluster" -ForegroundColor Yellow}
            Default {Write-Host "`t[ERROR] Unexpected disk number"}
        }
		If ($ActiveStorageRepairs)
			{
			 Write-Host "`n`t[WARNING] VirtualDisk repairs in progress" -ForegroundColor Yellow
			 Write-Host "$($ActiveStorageRepairs)"
			}
		if(!($TranscriptPath))
		{
			#region .NET
			[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
			[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
			$TranscriptMainForm = New-Object -TypeName System.Windows.Forms.Form
			[System.Windows.Forms.Label]$transcriptlabel = $null
			[System.Windows.Forms.Button]$transcriptbuttonY = $null
			[System.Windows.Forms.Button]$transcriptbuttonN = $null
			[System.Windows.Forms.Button]$button1 = $null
			$transcriptlabel = New-Object -TypeName System.Windows.Forms.Label
			$transcriptbuttonY = New-Object -TypeName System.Windows.Forms.Button
			$transcriptbuttonN = New-Object -TypeName System.Windows.Forms.Button
			$TranscriptMainForm.SuspendLayout()
			#
			#transcriptlabel
			#
			$transcriptlabel.AutoSize = $true
			$transcriptlabel.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(10,36)
			$transcriptlabel.Name = 'transcriptlabel'
			$transcriptlabel.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(252,13)
			$transcriptlabel.TabIndex = 0
			$transcriptlabel.Text = 'Upload AzureStack transcripts to an external share?'
			$transcriptlabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
			#
			#transcriptbuttonY
			#
			$transcriptbuttonY.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(60,78)
			$transcriptbuttonY.Name = 'transcriptbuttonY'
			$transcriptbuttonY.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
			$transcriptbuttonY.TabIndex = 1
			$transcriptbuttonY.Text = 'Yes'
			$transcriptbuttonY.UseVisualStyleBackColor = $true
			$transcriptbuttonY.DialogResult = [System.Windows.Forms.DialogResult]::Yes
			#
			#transcriptbuttonN
			#
			$transcriptbuttonN.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(141,78)
			$transcriptbuttonN.Name = 'transcriptbuttonN'
			$transcriptbuttonN.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
			$transcriptbuttonN.TabIndex = 2
			$transcriptbuttonN.Text = 'No'
			$transcriptbuttonN.UseVisualStyleBackColor = $true
			$transcriptbuttonN.DialogResult = [System.Windows.Forms.DialogResult]::No
			#
			#TranscriptMainForm
			#
			$TranscriptMainForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(274,126)
			$TranscriptMainForm.Controls.Add($transcriptbuttonN)
			$TranscriptMainForm.Controls.Add($transcriptbuttonY)
			$TranscriptMainForm.Controls.Add($transcriptlabel)
			$TranscriptMainForm.Name = 'TranscriptMainForm'
			$TranscriptMainForm.ResumeLayout($false)
			$TranscriptMainForm.PerformLayout()
			Add-Member -InputObject $TranscriptMainForm -Name base -Value $base -MemberType NoteProperty
			Add-Member -InputObject $TranscriptMainForm -Name transcriptlabel -Value $transcriptlabel -MemberType NoteProperty
			Add-Member -InputObject $TranscriptMainForm -Name transcriptbuttonY -Value $transcriptbuttonY -MemberType NoteProperty
			Add-Member -InputObject $TranscriptMainForm -Name transcriptbuttonN -Value $transcriptbuttonN -MemberType NoteProperty
			Add-Member -InputObject $TranscriptMainForm -Name button1 -Value $button1 -MemberType NoteProperty
			$TranscriptMainForm.Topmost = $True
			$TranscriptMainForm.StartPosition = "CenterScreen"
			$TranscriptMainForm.MaximizeBox = $false
			$TranscriptMainForm.FormBorderStyle = 'Fixed3D'
			$TranscriptMainForm.ShowIcon = $false
			$Transcriptresult = $TranscriptMainForm.ShowDialog()
			#endregion .NET

			Write-Host "`n `t[INFO] Upload AzureStack transcripts to an external share" -ForegroundColor Green
			switch ($Transcriptresult)
			{
				"Yes" {Write-Host "`tSelected Yes"; $MoveTranscript = 1}
				"No"  {Write-Host "`tSelected No"}
			}

			if ($MoveTranscript -eq 1)
			{
				function Read-InputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText)
				{
					Add-Type -AssemblyName Microsoft.VisualBasic
					return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $WindowTitle, $DefaultText)
				}
					[String]$TranscriptPath = Read-InputBoxDialog -Message "Please enter path to Transcript Share. `n`nExample: \\SomeIPAddress\folder" -WindowTitle "Transcript Share" -DefaultText "\\1.2.3.4\folder"
			}
		}
		if (($TranscriptPath) -and ($TranscriptPath -ne "\\1.2.3.4\folder"))
		{
			try
			{
				If(($TranscriptPath) -and (!($TranscriptShareCred))) {$TranscriptShareCred = Get-Credential -Message "TranscriptShareUser" -UserName $name}
				$ERCSSHAREDRIVE = new-psdrive -PSProvider FileSystem -Name ERCSSHARE -Root $TranscriptPath -Credential $TranscriptShareCred
				$Transcriptfilepath = (Get-ChildItem -OutVariable Transcriptname -Include Transcripts_* -Path $Env:SystemDrive\$sharename -Recurse).FullName
				Copy-Item -Path $Transcriptfilepath -Destination "$($ERCSSHAREDRIVE.Name):" -Force
				if((Test-Path -Path "$($ERCSSHAREDRIVE.Name):\$($Transcriptname.name)") -eq $true)
				{
					Write-Host "`n `t[INFO] $($Transcriptname.name) copied to $($TranscriptPath)" -ForegroundColor Green
				}
				else
				{
				Write-Host "`n `t[WARNING] Unable to reach $($TranscriptPath)\$($Transcriptname.name) files may not have been copied" -ForegroundColor Yellow
				}
			}
			catch [System.Exception]
			{
				Write-Host "`n`t`t[Error] Exception caught: $_" -ForegroundColor Red
			}
			finally
			{
				Remove-PSDrive -Name ERCSSHARE -Force
			}
		}
		if($Files)
		{
			try
			{
            Write-Host "`n`t[INFO] Compressing gathered files"  -ForegroundColor Green
            $zipdate = $date
			Compress-Archive -Path (Get-ChildItem -Exclude Transcripts_* -Path $Env:SystemDrive\$sharename).FullName -CompressionLevel Optimal -DestinationPath "$Env:SystemDrive\$sharename\$($zipdate)_AzureStackLogs_archive.zip" -Force
			Write-Host "`tFile created: $Env:SystemDrive\$sharename\$($zipdate)_AzureStackLogs_archive.zip" -ForegroundColor White
			Invoke-Item $Files.Parent.FullName
			Write-Host "`n `t[INFO] Opening $($Files.Parent.FullName)" -ForegroundColor Green
			}
			catch
			{
			Write-Host "`n`t`t[WARN] Did not create a archive" -ForegroundColor Yellow
			}
		}
	}
	catch [System.Management.Automation.ValidationMetadataException]
	{
		Write-Host "`n`t[ERROR] Incorrect password supplied, Access is denied" -ForegroundColor Red
	}
	catch [System.Management.Automation.RemoteException]
	{
		Write-Host "`n`t[ERROR] Incorrect password supplied, Access is denied" -ForegroundColor Red
	}
	catch [System.Exception]
	{
	    Write-Host "`n`t`t[Error] Exception caught: $_" -ForegroundColor Red
		Write-Host "`n Press any key to continue ...`n"
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		exit
	}
	finally
	{
    Remove-SmbShare -Name $sharename -Force
	Write-Host "`n`t[INFO] Removing script created firewall rules"
	Remove-NetFirewallRule -Group "AzureStack_ERCS"
	if($DNSModule -eq 1) {Write-Host "`n`t[INFO] Removing script installed Powershell DNS Module" -ForegroundColor Green; Uninstall-WindowsFeature -Name RSAT-DNS-Server -Remove -WarningAction SilentlyContinue | out-null}
	if($ADModule -eq 1) {Write-Host "`n`t[INFO] Removing script installed Powershell AD Module" -ForegroundColor Green; Uninstall-WindowsFeature -Name RSAT-AD-PowerShell -Remove -WarningAction SilentlyContinue | out-null}
	Write-Host "`n `tPress any key to continue ...`n"
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit	
	}
}
else
{
	Write-Host "`n`t[INFO] Unable to find ip address of Emergency Recovery Console Session" -ForegroundColor Red
	Write-Host "`n Press any key to continue ...`n"
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}