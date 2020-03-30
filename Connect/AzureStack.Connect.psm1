# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Modules Az.Accounts, VpnClient

<#
    .SYNOPSIS
    Add VPN connection to an Azure Stack instance
#>

function Add-AzsVpnConnection {
    param (
        [parameter(HelpMessage = "Azure Stack VPN Connection Name such as 'my-poc'")]
        [string] $ConnectionName = "Azure Stack",

        [parameter(mandatory = $true, HelpMessage = "External IP of the Azure Stack NAT VM such as '1.2.3.4'")]
        [string] $ServerAddress,

        [parameter(mandatory = $true, HelpMessage = "Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )

    $existingConnection = Get-VpnConnection -Name $ConnectionName -ErrorAction Ignore
    if ($existingConnection) {
        Write-Verbose "Updating Azure Stack VPN connection named $ConnectionName" -Verbose
        rasdial $ConnectionName /d
        Remove-VpnConnection -name $ConnectionName -Force -ErrorAction Ignore
    }
    else {
        Write-Verbose "Creating Azure Stack VPN connection named $ConnectionName" -Verbose
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    $connection = Add-VpnConnection -Name $ConnectionName -ServerAddress $ServerAddress -TunnelType L2tp -EncryptionLevel Required -AuthenticationMethod Eap -L2tpPsk $PlainPassword -Force -RememberCredential -PassThru -SplitTunneling 
    
    Write-Verbose "Adding routes to Azure Stack VPN connection named $ConnectionName" -Verbose
    Add-VpnConnectionRoute -ConnectionName $ConnectionName -DestinationPrefix 192.168.102.0/24 -RouteMetric 2 -PassThru | Out-Null
    Add-VpnConnectionRoute -ConnectionName $ConnectionName -DestinationPrefix 192.168.105.0/27 -RouteMetric 2 -PassThru | Out-Null

    return $connection
}

Export-ModuleMember -Function 'Add-AzsVpnConnection'

<#
    .SYNOPSIS
    Connects to Azure Stack via VPN
#>

function Connect-AzsVpn {
    param (
        [parameter(HelpMessage = "Azure Stack VPN Connection Name such as 'my-poc'")]
        [string] $ConnectionName = "Azure Stack",
        [parameter(HelpMessage = "Administrator user name of this Azure Stack Instance")]
        [string] $User = "administrator",
        [parameter(mandatory = $true, HelpMessage = "Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password,
        [parameter(HelpMessage = "Indicate whether to retrieve and trust certificates from the environment after establishing a VPN connection")]
        [bool] $RetrieveCertificates = $true
    )    
    
    Write-Verbose "Connecting to Azure Stack VPN using connection named $ConnectionName..." -Verbose

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Connecting using legacy command. Need to use domainless cred. Domain will be assumed on the other end.
    rasphone $ConnectionName

    $azshome = "$env:USERPROFILE\Documents\$ConnectionName"

    if ($RetrieveCertificates) {
        Write-Verbose "Connection-specific files will be saved in $azshome" -Verbose

        New-Item $azshome -ItemType Directory -Force | Out-Null

        $hostIP = (Get-VpnConnection -Name $ConnectionName).ServerAddress

        $UserCred = ".\$User"
        $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $UserCred, $Password

        Write-Verbose "Retrieving Azure Stack Root Authority certificate..." -Verbose
        $cert = Invoke-Command -ComputerName "$hostIP" -ScriptBlock { Get-ChildItem cert:\currentuser\root | where-object {$_.Subject -like "*AzureStackSelfSignedRootCert*"} } -Credential $credential

        if ($cert) {
            if ($cert.GetType().IsArray) {
                $cert = $cert[0] # take any that match the subject if multiple certs were deployed
            }

            $certFilePath = "$azshome\CA.cer"

            Write-Verbose "Saving Azure Stack Root certificate in $certFilePath..." -Verbose

            Export-Certificate -Cert $cert -FilePath $certFilePath -Force | Out-Null

            Write-Verbose "Installing Azure Stack Root certificate for the current user..." -Verbose
            
            Write-Progress "LOOK FOR CERT ACCEPTANCE PROMPT ON YOUR SCREEN!"

            Import-Certificate -CertStoreLocation cert:\currentuser\root -FilePath $certFilePath
        }
        else {
            Write-Error "Certificate has not been retrieved!"
        }
    }

}

Export-ModuleMember -Function 'Connect-AzsVpn'

<#
    .SYNOPSIS
    Connecting to your environment requires that you obtain the value of your Directory Tenant ID. 
    For **Azure Active Directory** environments provide your directory tenant name.
#>

function Get-AzsDirectoryTenantId () {
    [CmdletBinding(DefaultParameterSetName = 'AzureActiveDirectory')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ADFS')]
        [switch] $ADFS,

        [parameter(mandatory = $true, ParameterSetName = 'AzureActiveDirectory', HelpMessage = "AAD Directory Tenant <myaadtenant.onmicrosoft.com>")]
        [string] $AADTenantName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ADFS')]
        [Parameter(Mandatory = $true, ParameterSetName = 'AzureActiveDirectory')]
        [string] $EnvironmentName
    )
    
    $ADauth = (Get-AzEnvironment -Name $EnvironmentName).ActiveDirectoryAuthority
    if ($ADFS -eq $true) {
        if (-not (Get-AzEnvironment -Name $EnvironmentName).EnableAdfsAuthentication) {
            Write-Error "This environment is not configured to do ADFS authentication." -ErrorAction Stop
        }
        return $(Invoke-RestMethod $("{0}/.well-known/openid-configuration" -f $ADauth.TrimEnd('/'))).issuer.TrimEnd('/').Split('/')[-1]
    }
    else {
        $endpt = "{0}{1}/.well-known/openid-configuration" -f $ADauth, $AADTenantName
        $OauthMetadata = (Invoke-WebRequest -UseBasicParsing $endpt).Content | ConvertFrom-Json
        $AADid = $OauthMetadata.Issuer.Split('/')[3]
        $AADid
    }
} 

Export-ModuleMember Get-AzsDirectoryTenantId
