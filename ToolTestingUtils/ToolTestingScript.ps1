param (    
    [parameter(mandatory=$true, HelpMessage="Azure Stack One Node host address or name such as '1.2.3.4'")]
    [string] $HostComputer,
    [parameter(HelpMessage="Domain FQDN of this Azure Stack Instance")]
    [string] $Domain = "azurestack.local",
    [parameter(HelpMessage="NAT computer name in this Azure Stack Instance")]
    [string] $natServer = "MAS-BGPNAT01",
    [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
    [string] $AdminUser = "administrator",
    [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
    [securestring] $AdminPassword,
    [parameter(mandatory=$true, HelpMessage="The AAD service admin user name of this Azure Stack Instance")]
    [string] $AadServiceAdmin,
    [parameter(mandatory=$true, HelpMessage="AAD Service Admin password used to deploy this Azure Stack instance")]
    [securestring] $AadServiceAdminPassword
)

# Set environment varibles to pass along testing variables
$global:HostComputer = $HostComputer
$global:Domain = $Domain
$global:natServer = $natServer
$global:AdminUser = $AdminUser
$global:AdminPassword = $AdminPassword
$global:AadServiceAdmin = $AadServiceAdmin
$global:AadServiceAdminPassword = $AadServiceAdminPassword

$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "$env:AadServiceAdmin", ($AadServiceAdminPassword)
$global:AzureStackLoginCredentials = $ServiceAdminCreds

$global:VPNConnectionName = "AzureStackTestVPN"

#Start running tests in correct order
Set-Location ..\Connect
Invoke-Pester 
Set-Location ..\ComputeAdmin
Invoke-Pester
Set-Location ..\ToolTestingUtils\

#Disconnect and Remove VPN Connection
Write-Verbose "Disconnecting and removing vpn connection"
rasdial $global:VPNConnectionName /d
Remove-VpnConnection -Name $global:VPNConnectionName

