<#
.SYNOPSIS
	Built to be run on the HLH or DVM from an administrative powershell session the script uses seven methods to find the privileged endpoint virtual machines. The script connects to selected privileged endpoint and runs Get-AzureStackLog with supplied parameters. If no parameters are supplied the script will default to prompting user via GUI for needed parameters.
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
.EXAMPLE
.\ERCS_AzureStackLogs.ps1 -FromDate (get-date).AddHours(-4) -ToDate (get-date) -FilterByRole VirtualMachines,BareMetal -ErcsName AzS-ERCS01
#>

Param(
	[Parameter(Mandatory=$false,HelpMessage="Valid formats 'MM/DD/YYYY' or 'MM/DD/YYYY HH:MM'")]
    [ValidateScript({$_ -lt (get-date)})]
    [DateTime] $FromDate,
	[Parameter(Mandatory=$false,HelpMessage="Valid formats are: in 'MM/DD/YYYY' or 'MM/DD/YYYY HH:MM'")]
    [DateTime] $ToDate,
	[Parameter(Mandatory=$false,HelpMessage="Valid choices are: Service Fabric, Storage, Networking, Identity, Patch & Update, Compute, Backup")]
    [ValidateSet("Service Fabric", "Storage", "Networking", "Identity", "Patch & Update", "Compute", "Backup")]
    [string] $Scenario,
    [Parameter(Mandatory=$false,HelpMessage="FilterByRole parameter to filter log collection. Valid formats are comma separated values.")]
    [string[]]$FilterByRole,
	[Parameter(Mandatory=$false,HelpMessage="ERCS machine name or IP Address, Example: AzS-ERCS01 or 192.168.200.255")]
    [string]$ErcsName
)

#Run as Admin
$ScriptPath = $script:MyInvocation.MyCommand.Path

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
#    1.4.8
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
"    ERCS_AzureStackLogs.ps1 " | Write-Host -ForegroundColor Yellow 
"" | Write-Host -ForegroundColor Yellow 
" VERSION: " | Write-Host -ForegroundColor Yellow 
"    1.4.8" | Write-Host -ForegroundColor Yellow 
""  | Write-Host -ForegroundColor Yellow 
"------------------------------------------------------------------------------ " | Write-Host -ForegroundColor Yellow 
"" | Write-Host -ForegroundColor Yellow 
"`n This script SAMPLE is provided and intended only to act as a SAMPLE ONLY," | Write-Host -ForegroundColor Yellow 
" and is NOT intended to serve as a solution to any known technical issue."  | Write-Host -ForegroundColor Yellow 
"`n By executing this SAMPLE AS-IS, you agree to assume all risks and responsibility associated."  | Write-Host -ForegroundColor Yellow 
 
$ErrorActionPreference = "SilentlyContinue" 
$ContinueAnswer = Read-Host "`n Do you wish to proceed at your own risk? (Y/N)" 
If ($ContinueAnswer -ne "Y") { Write-Host "`n Exiting." -ForegroundColor Red;Exit } 

#clear var $ip
$IP = $null
Clear-Host

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
	Write-Host "`n `t[INFO] Load AzureStackStampInformation.json" -ForegroundColor Green
	$FoundJSONFile = Get-Content -Raw -Path "$($Env:ProgramData)\AzureStackStampInformation.json" | ConvertFrom-Json
	$FoundSelERCSIP  = $FoundJSONFile.EmergencyConsoleIPAddresses | Out-GridView -Title "Please Select Emergency Console IP Address" -PassThru
	$IP = $FoundSelERCSIP
	}
}

#Sel AzureStackStampInformation
if(!($IP))
{
	$title = "`n`t`t`t`t`t`t `t[PROMPT]"
	$message = "`t`t`t`t`t`t`t `tDo you have the AzureStackStampInformation.json file?"

	$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
	    "Loads AzureStackStampInformation.json"

	$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
	    "Does not load AzureStackStampInformation.json"

	$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

	$result = $host.ui.PromptForChoice($title, $message, $options, 1) 

	switch ($result)
	    {
	        0 {    
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
                    [array]$ERCSIPS = $JSONFile.EmergencyConsoleIPAddresses
	                $selERCSIP = $ERCSIPS | Out-GridView -Title "Please Select Emergency Console IPAddress" -PassThru
	                $IP = $selERCSIP
                    }
	          }
	        1 {Write-Host "`n `t[INFO] No AzureStackStampInformation.json file loaded" -ForegroundColor White}
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
        $GuessName = Test-NetConnection -port 5985 -ComputerName $GuessERCName
        If ($GuessName.TcpTestSucceeded -eq "True")
            {
            [Array]$ListeningNames += $GuessName.RemoteAddress.IPAddressToString
            }
        }
	$global:progresspreference ="Continue"
    $selName = $ListeningNames |Out-GridView -PassThru -Title "Select Emergency Recovery Console Session"
    $IP = $selName
}

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
		#INFOrm the user of that we are doing
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

#Manual Entry
if(!($IP))
{
    #Manual Entry
    if(!($IP))
    {
	    Write-Host "`n`t[PROMPT] Enter IP Address of Emergency Recovery Console Session" -ForegroundColor White
	    [string]$IP = Read-Host "`n`tInput ERCS ip Address"
    }
    else
    {
        Write-Host "`n`t[INFO] Unable to find ip address of Emergency Recovery Console Session via manual entry" -ForegroundColor  DarkYellow
    }
}

#Do Work
if($IP)
{
	Try
	{
		 Write-Host "`n `t[INFO] Using $($IP)" -ForegroundColor Green
		#Add this machine to trusted Hosts 
		Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$($IP)" -Force

		#gethostip
        $global:progresspreference ="SilentlyContinue"
		Write-Host "`n `t[INFO] Testing connectivity to $($IP)" -ForegroundColor Green
		$testconnect = Test-NetConnection -port 5985 -ComputerName $IP
		If ($testconnect.TcpTestSucceeded -eq "True")
		    {
				Write-Host "`tSuccess"
				$remoteip = $testconnect.RemoteAddress.IPAddressToString
				$share = $testconnect.SourceAddress.IPAddress
				$myname = whoami
                $date = Get-Date -format MM-dd
                $foldername = "-AzureStackLogs"
                $sharename = $date + $foldername
                If (!(Test-Path "$($Env:SystemDrive)\$($sharename)")) {$folder = New-Item -Path "$($Env:SystemDrive)\$($sharename)" -ItemType directory} 
                $foldershare= New-SMBShare –Name $sharename –Path "$($Env:SystemDrive)\$($sharename)" -FullAccess $myname
                If($foldershare){[string]$ShareINFO = "\\$($share)\$sharename"}
			}
		Else
			{
                $global:progresspreference ="Continue"
  				Write-Host "`n `t[ERROR] Cannot connect to Emergency Recovery Console Session to $($remoteip) from $($share)" -ForegroundColor Red
				Write-Host "`n Press any key to continue ...`n"
				$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
				exit
			}
	    #username and password
        $global:progresspreference ="Continue"
	    $user = "azurestack\CloudAdmin"
	    Write-Host "`n`t[PROMPT] Enter password for $($user)"
	    $secpasswd = Read-Host "`n `t`tEnter the password for $($user)" -AsSecureString
	    $mySecureCredentials = New-Object System.Management.Automation.PSCredential ($user, $secpasswd)

	    #ShareUserINFO
	    $name = whoami
	    Write-Host "`n`t[PROMPT] Enter password for $($name)"
	    $currsecpasswd = Read-Host "`n`t`tEnter the password for $($name)" -AsSecureString
	    $shareCred = New-Object System.Management.Automation.PSCredential($name,$currsecpasswd)
        
		#form for start question
	if (!($FromDate))
		{
			#form for questions 
	        Add-Type -AssemblyName System.Windows.Forms
	        Add-Type -AssemblyName System.Drawing

	        $Startform = New-Object Windows.Forms.Form 
	        $Startform.Text = "Start" 
	        $Startform.Size = New-Object Drawing.Size @(200,265) 
	        $Startform.StartPosition = "CenterScreen"

	        $Startcalendar = New-Object System.Windows.Forms.MonthCalendar 
	        $Startcalendar.ShowTodayCircle = $false
	        $Startcalendar.MaxSelectionCount = 1
	        $Startform.Controls.Add($Startcalendar) 


	        # StartTimePicker Label
	        $StartTimePickerLabel = New-Object System.Windows.Forms.Label
	        $StartTimePickerLabel.Text = “Start”
	        $StartTimePickerLabel.Location = “10, 165”
	        $StartTimePickerLabel.Height = 22
	        $StartTimePickerLabel.Width = 60
	        $Startform.Controls.Add($StartTimePickerLabel)

	        # StartTimePicker
	        $StartTimePicker = New-Object System.Windows.Forms.DateTimePicker
	        $StartTimePicker.Location = “70, 165”
	        $StartTimePicker.Width = “90”
			$StartTimePicker.Value = (get-date).AddHours(-4)
	        $StartTimePicker.Format = [windows.forms.datetimepickerFormat]::custom
	        $StartTimePicker.CustomFormat = “HH:mm:ss”
	        $StartTimePicker.ShowUpDown = $TRUE
	        $Startform.Controls.Add($StartTimePicker)

	        $StartOKButton = New-Object System.Windows.Forms.Button
	        $StartOKButton.Location = New-Object System.Drawing.Point(18,195)
	        $StartOKButton.Size = New-Object System.Drawing.Size(75,23)
	        $StartOKButton.Text = "OK"
	        $StartOKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	        $Startform.AcceptButton = $StartOKButton
	        $Startform.Controls.Add($StartOKButton)

	        $StartCancelButton = New-Object System.Windows.Forms.Button
	        $StartCancelButton.Location = New-Object System.Drawing.Point(93,195)
	        $StartCancelButton.Size = New-Object System.Drawing.Size(75,23)
	        $StartCancelButton.Text = "Cancel"
	        $StartCancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	        $Startform.CancelButton = $StartCancelButton
	        $Startform.Controls.Add($StartCancelButton)
	        $Startform.Topmost = $True

	        Write-Host "`n`t[PROMPT] When should tracing start?" -ForegroundColor Green
	        $fromresult = $Startform.ShowDialog() 
	        if ($fromresult -eq [System.Windows.Forms.DialogResult]::OK)
	        {
	            $fromdate = $Startcalendar.SelectionStart
	            $fromthedate = $($fromdate.Date)
	            $fromstarttime = ($fromthedate).Add($StartTimePicker.Value.TimeOfDay)
	            [DateTime]$FromDate = $fromstarttime
	            if($FromDate -lt (get-date))
	            {
	            Write-Host "`tSelected $($FromDate)"
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
		#form for end question	
	if (!($ToDate))
		{
			#form for questions 
	        Add-Type -AssemblyName System.Windows.Forms
	        Add-Type -AssemblyName System.Drawing

	        $Endform = New-Object Windows.Forms.Form 
	        $Endform.Text = "End" 
	        $Endform.Size = New-Object Drawing.Size @(200,265) 
	        $Endform.StartPosition = "CenterScreen"

	        $Endcalendar = New-Object System.Windows.Forms.MonthCalendar 
	        $Endcalendar.ShowTodayCircle = $false
            $Endcalendar.MaxDate = (Get-Date)
	        $Endcalendar.MaxSelectionCount = 1
	        $Endform.Controls.Add($Endcalendar) 


	        # StartTimePicker Label
	        $EndTimePickerLabel = New-Object System.Windows.Forms.Label
	        $EndTimePickerLabel.Text = “Stop”
	        $EndTimePickerLabel.Location = “10, 165”
	        $EndTimePickerLabel.Height = 22
	        $EndTimePickerLabel.Width = 60
	        $Endform.Controls.Add($EndTimePickerLabel)

	        # StartTimePicker
	        $EndTimePicker = New-Object System.Windows.Forms.DateTimePicker
	        $EndTimePicker.Location = “70, 165”
	        $EndTimePicker.Width = “90”
			$EndTimePicker.Value = (get-date)
            $EndTimePicker.MaxDate = (Get-Date)
	        $EndTimePicker.Format = [windows.forms.datetimepickerFormat]::custom
	        $EndTimePicker.CustomFormat = “HH:mm:ss”
	        $EndTimePicker.ShowUpDown = $TRUE
	        $Endform.Controls.Add($EndTimePicker)

	        $StartOKButton = New-Object System.Windows.Forms.Button
	        $StartOKButton.Location = New-Object System.Drawing.Point(18,195)
	        $StartOKButton.Size = New-Object System.Drawing.Size(75,23)
	        $StartOKButton.Text = "OK"
	        $StartOKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	        $Endform.AcceptButton = $StartOKButton
	        $Endform.Controls.Add($StartOKButton)

	        $EndCancelButton = New-Object System.Windows.Forms.Button
	        $EndCancelButton.Location = New-Object System.Drawing.Point(93,195)
	        $EndCancelButton.Size = New-Object System.Drawing.Size(75,23)
	        $EndCancelButton.Text = "Cancel"
	        $EndCancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	        $Endform.CancelButton = $EndCancelButton
	        $Endform.Controls.Add($EndCancelButton)
	        $Endform.Topmost = $True

	        Write-Host "`n`t[PROMPT] When should tracing stop?" -ForegroundColor Green
	        $toresult = $Endform.ShowDialog()
	        if ($toresult -eq [System.Windows.Forms.DialogResult]::OK)
	        {
	            $todate = $Endcalendar.SelectionStart
	            $tothedate = $($todate.Date)
	            $tostarttime = ($tothedate).Add($EndTimePicker.Value.TimeOfDay)
	            [DateTime]$ToDate = $tostarttime
	            if(($FromDate -lt $ToDate) -and ($ToDate -lt (Get-Date)))
	            {
	            Write-Host "`tSelected $($ToDate)"
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
        #setting remotepowershell options
		$switch = $true
		If($switch)
			{
				$switch = "Get-AzureStackLog -OutputSharePath `$using:ShareINFO -OutputShareCredential `$using:shareCred -ErrorAction Stop "
				$Howto = "Get-AzureStackLog -OutputSharePath `"$($ShareINFO)`" -OutputShareCredential `$cred -ErrorAction Stop "
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
				$Howto += "-FilterByRole `"$($FilterByRole)`" "
			}

	    Write-Host "`n `t[INFO] Running Enter-PSSession -ComputerName $($IP) -ConfigurationName PrivilegedEndpoint -Credential `$cred" -ForegroundColor Green
	    Write-Host "`n `t[INFO] Running $($Howto)" -ForegroundColor Green
	    
		#remotepowershell
		
        $s = New-PSSession -ComputerName $IP -ConfigurationName PrivilegedEndpoint -Credential $mySecureCredentials  
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
			Invoke-Command -Session $s -ScriptBlock {Get-AzureStackStampInformation} -OutVariable StampInformation | Out-Null

        }
        if((get-job -Id $job.id).State -eq "Completed")
	    {
            Write-Progress -Activity "Please wait while Get-AzureStackLog is running on $($IP)" -Status "Ready" -Completed
			Write-Host "`n `t[INFO] Getting Azure Stack stamp information" -ForegroundColor Green
			Invoke-Command -Session $s -ScriptBlock {Get-AzureStackStampInformation} -OutVariable StampInformation | Out-Null

        }
		#output Get-AzureStackStampInformation
		if($StampInformation)
		{
			Write-Host "`n `t[INFO] Saving AzureStackStampInformation to $($Env:ProgramData)" -ForegroundColor Green
			$StampInformation | ConvertTo-Json | Out-File -FilePath "$($Env:ProgramData)\AzureStackStampInformation.json" -Force
			Write-Host "`n `t[INFO] Saving AzureStackStampInformation to $($Env:SystemDrive)\$($sharename)" -ForegroundColor Green
			$StampInformation | ConvertTo-Json | Out-File -FilePath "$($Env:SystemDrive)\$($sharename)\AzureStackStampInformation.json" -Force
		}

        # output for transcript
        try
        {
        Write-Host "`n `t[INFO] Getting Azure Stack transcript" -ForegroundColor Green
		Invoke-Command -Session $s -ScriptBlock {Close-PrivilegedEndpoint -TranscriptsPathDestination "\\127.0.0.1\C`$"}
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
        finally
        {
            Remove-PSSession $s
        }
		#get files for user
		$Files = Get-ChildItem -Path "$($Env:SystemDrive)\$($sharename)" | Where {(($_.attributes -eq 'directory') -and ($_.Name -like "AzureStackLogs-*"))} | sort -Descending -Property CreationTime | select -first 1
		Invoke-Item "$($Files.FullName)"
        Write-Host "`n `t[INFO] Opening $($Files.FullName)" -ForegroundColor Green
        
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
						Write-Host "`t`tNo issues found" -ForegroundColor White
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
	Write-Host "`n Press any key to continue ...`n"
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
