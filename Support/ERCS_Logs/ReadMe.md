# ​ERCS_AzureStackLogs​.ps1  #

![](https://github.com/Azure/AzureStack-Tools/blob/vnext/Support/ERCS_Logs/Media/ERCS.gif?raw=true)

 Built to be run on the HLH, DVM, or Jumpbox from an administrative powershell session the script uses seven methods to find the privileged endpoint virtual machines. The script connects to selected privileged endpoint and runs Get-AzureStackLog with supplied parameters. If no parameters are supplied the script will default to prompting user via GUI for needed parameters.


 The script will use one of the below seven methods; Gather requested logs, Transcript, and AzureStackStampInformation.json. The script will also save AzureStackStampInformation.json in %ProgramData% and in created log folder. AzureStackStampInformation.json in %ProgramData% allows future runs to have ERCS IP information populated at beginning of script.
 
##  Methods: ##
-  Check %ProgramData% for AzureStackStampInformation.json
-  Prompt user for AzureStackStampInformation.json
-  Prompt user for install prefix and check connection to privileged endpoint virtual machine(s)
-  Install and/or load AD powershell module and check for computernames that match ERCS
-  Install and/or load DNS powershell module and check for A records in all zones that that match ERCS
-  Prompt user for tenant portal and based of the IP address of the portal find the likely IP(s) of privileged endpoint virtual machine(s)
-  Prompt user for manual entry of IP address of a privileged endpoint virtual machine

## FromDate ##
Specifies starting time frame for data search.  If parameter is not specified, script will default to 4 hours from current time. Format must be in one of the 3 formats: 

- (get-date).AddHours(-4)
- "MM/DD/YYYY HH:MM"
- "MM/DD/YYYY"


## ToDate ##
Specifies ending time frame for data search. If parameter is not specified, script will default to current time. Format must be in one of the 3 formats: 

- (get-date).AddHours(-1)
- "MM/DD/YYYY HH:MM"
- "MM/DD/YYYY"

## FilterByRole ##
Specifies parameter to filter log collection. Valid formats are comma separated values. List of possible switches http://aka.ms/AzureStack/Diagnostics

## ErcsName ##
Specifies privileged endpoint virtual machine name or IP address to use. Example: AzS-ERCS01 or 192.168.200.255

## AzSCredentials ##
Specifies credentials the script will use to connect to Azure Stack privileged endpoint. Format must be in one of the 2 formats:

- (Get-Credential -Message "Azure Stack Credentials")
- (Get-Credential)

## ShareCred ##
Specifies credentials the script will use to build a local share Format must be in one of the 2 formats:

- (Get-Credential -Message "Local Share Credentials" -UserName $env:USERNAME)
- (Get-Credential)

## InStamp ##
Specifies if script is running on Azure Stack machine such as Azure Stack Development Kit deployment or DVM.

- Yes
- No

## StampTimeZone ##
Specifies timezone id for Azure Stack stamp. Format must be in one of the 2 formats:

- (Get-TimeZone -Name "US Eastern*").id
- "Pacific Standard Time"

## IncompleteDeployment ##
Specifies if Azure Stack Deployment is incomplete. Only for use in Azure Stack Development Kit deployment or DVM

- Yes
- No

## Example Use ##
	.\ERCS_AzureStackLogs.ps1 -FromDate (get-date).AddHours(-4) -ToDate (get-date) -FilterByRole VirtualMachines,BareMetal -ErcsName AzS-ERCS01 -AzSCredentials (Get-Credential -Message "Azure Stack Credentials") -ShareCred (get-credential -Message "Local Share Credentials" -UserName $env:USERNAME) -InStamp No -StampTimeZone "Pacific Standard Time" -IncompleteDeployment No
