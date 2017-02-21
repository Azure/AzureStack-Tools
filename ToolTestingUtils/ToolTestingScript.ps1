param (    
    [parameter(mandatory=$true, HelpMessage="Azure Stack One Node host address or name such as '1.2.3.4'")]
    [string] $HostComputer,
    [Parameter(HelpMessage="The Admin ARM endpoint of the Azure Stack Environment")]
    [string] $ArmEndpoint = 'https://api.azurestack.local',
    [parameter(HelpMessage="NAT computer name in this Azure Stack Instance")]
    [string] $natServer = "MAS-BGPNAT01",
    [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
    [string] $AdminUser = "administrator",
    [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
    [securestring] $AdminPassword,
    [parameter(mandatory=$true, HelpMessage="The AAD service admin user name of this Azure Stack Instance")]
    [string] $AzureStackServiceAdmin,
    [parameter(mandatory=$true, HelpMessage="AAD Service Admin password used to deploy this Azure Stack instance")]
    [securestring] $AzureStackServiceAdminPassword
)

# Set environment varibles to pass along testing variables
$global:HostComputer = $HostComputer
$global:ArmEndpoint = $ArmEndpoint
$global:natServer = $natServer
$global:AdminUser = $AdminUser
$global:AdminPassword = $AdminPassword
$global:AzureStackServiceAdmin = $AzureStackServiceAdmin
$global:AzureStackServiceAdminPassword = $AzureStackServiceAdminPassword

$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "$global:AzureStackServiceAdmin", ($global:AzureStackServiceAdminPassword)
$global:AzureStackLoginCredentials = $ServiceAdminCreds

$global:VPNConnectionName = "AzureStackTestVPN"

#Start running tests in correct order
Set-Location ..\Connect
Invoke-Pester 
Set-Location ..\ServiceAdmin
Invoke-Pester
Set-Location ..\Infrastructure
Invoke-Pester
Set-Location ..\ComputeAdmin
Invoke-Pester
Set-Location ..\ToolTestingUtils\

#Disconnect and Remove VPN Connection
Write-Verbose "Disconnecting and removing vpn connection"
rasdial $global:VPNConnectionName /d
Remove-VpnConnection -Name $global:VPNConnectionName

