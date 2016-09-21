function Get-AzureStackNatServerAddress
{
    param (    
        [parameter(mandatory=$true, HelpMessage="Azure Stack One Node host address or name such as '1.2.3.4'")]
	    [string] $HostComputer,
        [parameter(HelpMessage="Domain FQDN of this Azure Stack Instance")]
        [string] $Domain = "azurestack.local",
        [parameter(HelpMessage="NAT computer name in this Azure Stack Instance")]
        [string] $natServer = "mas-bgpnat01",
        [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
        [string] $User = "administrator",
        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )

    $UserCred = "$Domain\$User"
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $UserCred, $Password

    Invoke-Command -ComputerName "$HostComputer" -Credential $credential -ScriptBlock `
        { 
            Invoke-Command -ComputerName "$using:natServer.$using:Domain" -Credential $using:credential -ScriptBlock `
                { 
                    Get-NetIPConfiguration | ? { $_.IPv4DefaultGateway -ne $null } | foreach { $_.IPv4Address.IPAddress }
                }
        } 
}

Export-ModuleMember Get-AzureStackNatServerAddress

function Add-AzureStackVpnConnection
{
    param (
	    [parameter(HelpMessage="Azure Stack VPN Connection Name such as 'my-poc'")]
	    [string] $ConnectionName = "azurestack",
	
	    [parameter(mandatory=$true, HelpMessage="External IP of the Azure Stack NAT VM such as '1.2.3.4'")]
	    [string] $ServerAddress,

        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )

    "Creating Azure Stack VPN connection named $ConnectionName"
    $existingConnection = Get-VpnConnection -Name $ConnectionName -ErrorAction Ignore
    if ($existingConnection -ne $null) {
        rasdial $ConnectionName /d
        Remove-VpnConnection -name $ConnectionName -Force -ErrorAction Ignore
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    Add-VpnConnection -Name $ConnectionName -ServerAddress $ServerAddress -TunnelType L2tp -EncryptionLevel Required -AuthenticationMethod MSChapv2 -L2tpPsk $PlainPassword -Force -RememberCredential -PassThru -SplitTunneling 
    Add-VpnConnectionRoute -ConnectionName $ConnectionName -DestinationPrefix 192.168.102.0/27 -RouteMetric 2 -PassThru
    Add-VpnConnectionRoute -ConnectionName $ConnectionName -DestinationPrefix 192.168.105.0/27 -RouteMetric 2 -PassThru
}

Export-ModuleMember Add-AzureStackVpnConnection

function Connect-AzureStackVpn
{
    param (
	    [parameter(HelpMessage="Azure Stack VPN Connection Name such as 'my-poc'")]
	    [string] $ConnectionName = "azurestack",
        [parameter(HelpMessage="Domain FQDN of this Azure Stack Instance")]
        [string] $Domain = "azurestack.local",
        [parameter(HelpMessage="Certificate Authority computer name in this Azure Stack Instance")]
        [string] $Remote = "mas-ca01",
        [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
        [string] $User = "administrator",
        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )    

    "Connecting to Azure Stack VPN using connection named $ConnectionName..."

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Connecting using legacy command. Need to use domainless cred. Domain will be assumed on the other end.
    rasdial $ConnectionName $User $PlainPassword

    $azshome = "$env:USERPROFILE\Documents\$ConnectionName"

    "Connection-specific files will be saved in $azshome"

    New-Item $azshome -ItemType Directory -Force

    "`nRetrieving Azure Stack Root Authority certificate..."

    $UserCred = "$Domain\$User"
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $UserCred, $Password

    $cert = Invoke-Command -ComputerName "$Remote.$Domain" -ScriptBlock { Get-ChildItem cert:\currentuser\root | where-object {$_.Subject -eq "CN=AzureStackCertificationAuthority, DC=AzureStack, DC=local"} } -Credential $credential

    if($cert -ne $null)
    {
        if($cert.GetType().IsArray)
        {
            $cert = $cert[0] # take any that match the subject if multiple certs were deployed
        }

        $certFilePath = "$azshome\CA.cer"

        "Saving Azure Stack Root certificate in $certFilePath..."

        Export-Certificate -Cert $cert -FilePath $certFilePath -Force

        "`nInstalling Azure Stack Root certificate for the current user..." 
        
        Write-Progress "LOOK FOR CERT ACCEPTANCE PROMPT ON YOUR SCREEN!"

	    Import-Certificate -CertStoreLocation cert:\currentuser\root -FilePath $certFilePath
    }
    else
    {
        Write-Error "Certificate has not been retrieved!"
    }
}

Export-ModuleMember Connect-AzureStackVpn
