# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0
#requires -Modules AzureRM.Profile, VpnClient, AzureRM.AzureStackAdmin

<#
    .SYNOPSIS
    Registers all providers on the all subscription
#>
function Register-AllAzureRmProvidersOnAllSubscriptions {
    foreach($s in (Get-AzureRmSubscription)) {
        Select-AzureRmSubscription -SubscriptionId $s.SubscriptionId | Out-Null
        Write-Progress $($s.SubscriptionId + " : " + $s.SubscriptionName)
    Register-AllAzureRmProviders
}
}

Export-ModuleMember Register-AllAzureRmProvidersOnAllSubscriptions

<#
    .SYNOPSIS
    Registers all providers on the newly created subscription
#>
function Register-AllAzureRmProviders {
    Get-AzureRmResourceProvider -ListAvailable | Register-AzureRmResourceProvider -Force
}

Export-ModuleMember Register-AllAzureRmProviders

<#
    .SYNOPSIS
    Obtains Aazure Active Directory tenant that was used when deploying the Azure Stack instance
#>
function Get-AzureStackAadTenant {
    param (
        [parameter(mandatory=$true, HelpMessage="Azure Stack One Node host address or name such as '1.2.3.4'")]
        [string] $HostComputer,        
        [Parameter(HelpMessage="The Domain suffix of the environment VMs")]
        [string] $DomainSuffix = 'azurestack.local',
        [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
        [string] $User = "administrator",
        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )

    $Domain = $DomainSuffix

    $UserCred = "$Domain\$User"
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $UserCred, $Password

    Write-Verbose "Remoting to the Azure Stack host $HostComputer..." -Verbose
    return Invoke-Command -ComputerName "$HostComputer" -Credential $credential -ScriptBlock `
        {            
        Write-Verbose "Retrieving Azure Stack configuration..." -Verbose
        $configFile = Get-ChildItem -Path C:\EceStore -Recurse | Where-Object {-not $_.PSIsContainer} | Sort-Object Length -Descending | Select-Object -First 1
        $customerConfig = [xml] (Get-Content -Path $configFile.FullName)

        $Parameters = $customerConfig.CustomerConfiguration
        $fabricRole = $Parameters.Role.Roles.Role | Where-Object {$_.Id -eq "Fabric"}
        $allFabricRoles = $fabricRole.Roles.ChildNodes
        $idProviderRole = $allFabricRoles | Where-Object {$_.Id -eq "IdentityProvider"}
        $idProviderRole.PublicInfo.AADTenant.Id
    }
}

Export-ModuleMember Get-AzureStackAadTenant

<#
    .SYNOPSIS
    Adds Azure Stack environment to use with AzureRM command-lets when targeting Azure Stack
#>
function Add-AzureStackAzureRmEnvironment {
    param (
        [Parameter(mandatory=$true, HelpMessage="The Admin ARM endpoint of the Azure Stack Environment")]
        [string] $ArmEndpoint,
        [parameter(mandatory=$true, HelpMessage="Azure Stack environment name for use with AzureRM commandlets")]
        [string] $Name
    )

    if(!$ARMEndpoint.Contains('https://')){
        if($ARMEndpoint.Contains('http://')){
            $ARMEndpoint = $ARMEndpoint.Substring(7)
            $ARMEndpoint = 'https://' + $ARMEndpoint

        }else{
            $ARMEndpoint = 'https://' + $ARMEndpoint
        }
    }

    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")

    $Domain = ""
    try {
        $uriARMEndpoint = [System.Uri] $ArmEndpoint
        $i = $ArmEndpoint.IndexOf('.')
        $Domain = ($ArmEndpoint.Remove(0,$i+1)).TrimEnd('/')
    }
    catch {
        Write-Error "The specified ARM endpoint was invalid"
    }

    $ResourceManagerEndpoint = $ArmEndpoint 
    $stackdomain = $Domain         

    Write-Verbose "Retrieving endpoints from the $ResourceManagerEndpoint..." -Verbose
    $endpoints = Invoke-RestMethod -Method Get -Uri "$($ResourceManagerEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -ErrorAction Stop

    $AzureKeyVaultDnsSuffix="vault.$($stackdomain)".ToLowerInvariant()
    $AzureKeyVaultServiceEndpointResourceId= $("https://vault.$stackdomain".ToLowerInvariant())
    $StorageEndpointSuffix = ($stackdomain).ToLowerInvariant()
    $aadAuthorityEndpoint = $endpoints.authentication.loginEndpoint

    $azureEnvironmentParams = @{
        Name                                     = $Name
        ActiveDirectoryEndpoint                  = $endpoints.authentication.loginEndpoint.TrimEnd('/') + "/"
        ActiveDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
        ResourceManagerEndpoint                  = $ResourceManagerEndpoint
        GalleryEndpoint                          = $endpoints.galleryEndpoint
        GraphEndpoint                            = $endpoints.graphEndpoint
        GraphAudience                            = $endpoints.graphEndpoint
        StorageEndpointSuffix                    = $StorageEndpointSuffix
        AzureKeyVaultDnsSuffix                   = $AzureKeyVaultDnsSuffix
        AzureKeyVaultServiceEndpointResourceId   = $AzureKeyVaultServiceEndpointResourceId
        EnableAdfsAuthentication                 = $aadAuthorityEndpoint.TrimEnd("/").EndsWith("/adfs", [System.StringComparison]::OrdinalIgnoreCase)
    }

    $armEnv = Get-AzureRmEnvironment -Name $Name
    if($armEnv -ne $null) {
        Write-Verbose "Updating AzureRm environment $Name" -Verbose
        Remove-AzureRmEnvironment -Name $Name -Force | Out-Null
    }
    else {
        Write-Verbose "Adding AzureRm environment $Name" -Verbose
    }
            
    return Add-AzureRmEnvironment @azureEnvironmentParams
}

Export-ModuleMember Add-AzureStackAzureRmEnvironment

<#
    .SYNOPSIS
    Obtains Azure Stack NAT address from the Azure Stack One Node instance
#>
function Get-AzureStackNatServerAddress {
    param (    
        [parameter(mandatory=$true, HelpMessage="Azure Stack One Node host address or name such as '1.2.3.4'")]
        [string] $HostComputer,
        [Parameter(HelpMessage="The Domain suffix of the environment VMs")]
        [string] $DomainSuffix = 'azurestack.local',
        [parameter(HelpMessage="NAT computer name in this Azure Stack Instance")]
        [string] $natServer = "mas-bgpnat01",
        [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
        [string] $User = "administrator",
        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )

    $Domain = $DomainSuffix

    $UserCred = "$Domain\$User"
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $UserCred, $Password

    $nat = "$natServer.$Domain"

    Write-Verbose "Remoting to the Azure Stack host $HostComputer..." -Verbose
    return Invoke-Command -ComputerName "$HostComputer" -Credential $credential -ScriptBlock `
        { 
        Write-Verbose "Remoting to the Azure Stack NAT server $using:nat..." -Verbose
        Invoke-Command -ComputerName "$using:nat"  -Credential $using:credential -ScriptBlock `
                { 
            Write-Verbose "Obtaining external IP..." -Verbose
            Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | ForEach-Object { $_.IPv4Address.IPAddress }
        }
    } 
}

Export-ModuleMember Get-AzureStackNatServerAddress

<#
    .SYNOPSIS
    Add VPN connection to an Azure Stack instance
#>
function Add-AzureStackVpnConnection {
    param (
        [parameter(HelpMessage="Azure Stack VPN Connection Name such as 'my-poc'")]
        [string] $ConnectionName = "azurestack",
	
        [parameter(mandatory=$true, HelpMessage="External IP of the Azure Stack NAT VM such as '1.2.3.4'")]
        [string] $ServerAddress,

        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )

    $existingConnection = Get-VpnConnection -Name $ConnectionName -ErrorAction Ignore
    if ($existingConnection -ne $null) {
        Write-Verbose "Updating Azure Stack VPN connection named $ConnectionName" -Verbose
        rasdial $ConnectionName /d
        Remove-VpnConnection -name $ConnectionName -Force -ErrorAction Ignore
    }
    else {
        Write-Verbose "Creating Azure Stack VPN connection named $ConnectionName" -Verbose
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    $connection = Add-VpnConnection -Name $ConnectionName -ServerAddress $ServerAddress -TunnelType L2tp -EncryptionLevel Required -AuthenticationMethod MSChapv2 -L2tpPsk $PlainPassword -Force -RememberCredential -PassThru -SplitTunneling 
    
    Write-Verbose "Adding routes to Azure Stack VPN connection named $ConnectionName" -Verbose
    Add-VpnConnectionRoute -ConnectionName $ConnectionName -DestinationPrefix 192.168.102.0/27 -RouteMetric 2 -PassThru | Out-Null
    Add-VpnConnectionRoute -ConnectionName $ConnectionName -DestinationPrefix 192.168.105.0/27 -RouteMetric 2 -PassThru | Out-Null

    return $connection
}

Export-ModuleMember Add-AzureStackVpnConnection

<#
    .SYNOPSIS
    Connects to Azure Stack via VPN
#>
function Connect-AzureStackVpn {
    param (
        [parameter(HelpMessage="Azure Stack VPN Connection Name such as 'my-poc'")]
        [string] $ConnectionName = "azurestack",
        [Parameter(HelpMessage="The Domain suffix of the environment VMs")]
        [string] $DomainSuffix = 'azurestack.local',
        [parameter(HelpMessage="Certificate Authority computer name in this Azure Stack Instance")]
        [string] $Remote = "mas-ca01",
        [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
        [string] $User = "administrator",
        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )    
    
    $Domain = $DomainSuffix
    
    Write-Verbose "Connecting to Azure Stack VPN using connection named $ConnectionName..." -Verbose

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Connecting using legacy command. Need to use domainless cred. Domain will be assumed on the other end.
    rasdial $ConnectionName $User $PlainPassword

    $azshome = "$env:USERPROFILE\Documents\$ConnectionName"

    Write-Verbose "Connection-specific files will be saved in $azshome" -Verbose

    New-Item $azshome -ItemType Directory -Force | Out-Null

    $UserCred = "$Domain\$User"
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $UserCred, $Password

    Write-Verbose "Retrieving Azure Stack Root Authority certificate..." -Verbose
    $cert = Invoke-Command -ComputerName "$Remote.$Domain" -ScriptBlock { Get-ChildItem cert:\currentuser\root | where-object {$_.Subject -eq "CN=AzureStackCertificationAuthority, DC=AzureStack, DC=local"} } -Credential $credential

    if($cert -ne $null) {
        if($cert.GetType().IsArray) {
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

Export-ModuleMember Connect-AzureStackVpn

<#
    .SYNOPSIS
    Retrieve the admin token and subscription ID needed to make REST calls directly to Azure Resource Manager
#>
function Get-AzureStackAdminSubTokenHeader {
    param (
        [parameter(mandatory=$true, HelpMessage="Name of the Azure Stack Environment")]
        [string] $EnvironmentName,
	
        [parameter(mandatory=$true, HelpMessage="TenantID of Identity Tenant")]
        [string] $tenantID,

        [parameter(HelpMessage="Credentials to retrieve token header for")]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [parameter(HelpMessage="Name of the Administrator subscription")]
        [string] $subscriptionName = "Default Provider Subscription"
    )
    
    $azureStackEnvironment = Get-AzureRmEnvironment -Name $EnvironmentName -ErrorAction SilentlyContinue
    if($azureStackEnvironment -ne $null) {
        $ARMEndpoint = $azureStackEnvironment.ResourceManagerUrl
    }
    else {
        Write-Error "The Azure Stack Admin environment with the name $EnvironmentName does not exist. Create one with Add-AzureStackAzureRmEnvironment." -ErrorAction Stop
    }

    if(-not $azureStackCredentials){
        $azureStackCredentials = Get-Credential
    }

    try{
        Invoke-RestMethod -Method Get -Uri "$($ARMEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -ErrorAction Stop | Out-Null
    }catch{
        Write-Error "The specified ARM endpoint: $ArmEndpoint is not valid for this environment. Please make sure you are using the correct administrator ARM endpoint for this environment." -ErrorAction Stop
    }

    $authority = $azureStackEnvironment.ActiveDirectoryAuthority
    $activeDirectoryServiceEndpointResourceId = $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId

    Login-AzureRmAccount -EnvironmentName $EnvironmentName -TenantId $tenantID -Credential $azureStackCredentials | Out-Null

    try {
        $subscription = Get-AzureRmSubscription -SubscriptionName $subscriptionName 
    }
    catch {
        Write-Error "Verify that the login credentials are for the administrator and that the specified ARM endpoint: $ArmEndpoint is the valid administrator ARM endpoint for this environment." -ErrorAction Stop
    }

    $subscription | Select-AzureRmSubscription | Out-Null

    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"

    $savedWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue' 

    $adminToken = Get-AzureStackToken `
    -Authority $authority `
    -Resource $activeDirectoryServiceEndpointResourceId `
    -AadTenantId $tenantID `
    -ClientId $powershellClientId `
    -Credential $azureStackCredentials 

    $WarningPreference = $savedWarningPreference

    $headers = @{ Authorization = ("Bearer $adminToken") }
    
    return $subscription.SubscriptionId, $headers
}

Export-ModuleMember Get-AzureStackAdminSubTokenHeader

function Get-AADTenantGUID () {
    param(
        [parameter(mandatory=$true, HelpMessage="AAD Directory Tenant <myaadtenant.onmicrosoft.com>")]
        [string] $AADTenantName = "",
        [parameter(mandatory=$false, HelpMessage="Azure Cloud")]
        [ValidateSet("AzureCloud","AzureChinaCloud","AzureUSGovernment","AzureGermanCloud")]
        [string] $AzureCloud = "AzureCloud"
    )
    $ADauth = (Get-AzureRmEnvironment -Name $AzureCloud).ActiveDirectoryAuthority
    $endpt = "{0}{1}/.well-known/openid-configuration" -f $ADauth, $AADTenantName
    $OauthMetadata = (Invoke-WebRequest -UseBasicParsing $endpt).Content | ConvertFrom-Json
    $AADid = $OauthMetadata.Issuer.Split('/')[3]
    $AADid
} 

Export-ModuleMember Get-AADTenantGUID

function Get-DirectoryTenantID () {
    [CmdletBinding(DefaultParameterSetName='AzureActiveDirectory')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ADFS')]
        [switch] $ADFS,

        [parameter(mandatory=$true,ParameterSetName='AzureActiveDirectory', HelpMessage="AAD Directory Tenant <myaadtenant.onmicrosoft.com>")]
        [string] $AADTenantName = "",

        [Parameter(Mandatory=$true, ParameterSetName='ADFS')]
        [Parameter(Mandatory=$true, ParameterSetName='AzureActiveDirectory')]
        [string] $EnvironmentName
    )
    
    $ADauth = (Get-AzureRmEnvironment -Name $EnvironmentName).ActiveDirectoryAuthority
    if($ADFS -eq $true){
        if(-not (Get-AzureRmEnvironment -Name $EnvironmentName).EnableAdfsAuthentication){
            Write-Error "This environment is not configured to do ADFS authentication." -ErrorAction Stop
        }
        return $(Invoke-RestMethod $("{0}/.well-known/openid-configuration" -f $ADauth.TrimEnd('/'))).issuer.TrimEnd('/').Split('/')[-1]
    }else{
        $endpt = "{0}{1}/.well-known/openid-configuration" -f $ADauth, $AADTenantName
        $OauthMetadata = (Invoke-WebRequest -UseBasicParsing $endpt).Content | ConvertFrom-Json
        $AADid = $OauthMetadata.Issuer.Split('/')[3]
        $AADid
    }
} 

Export-ModuleMember Get-DirectoryTenantID

# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUda6KysD+Znhd/q1F/GzLWNsJ
# J32gghhlMIIEwzCCA6ugAwIBAgITMwAAAMlkTRbbGn2zFQAAAAAAyTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODU0
# WhcNMTgwOTA3MTc1ODU0WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkIxQjctRjY3Ri1GRUMyMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAotVXnfm6iRvJ
# s2GZXZXB2Jr9GoHX3HNAOp8xF/cnCE3fyHLwo1VF+TBQvObTTbxxdsUiqJ2Ew8DL
# jW8dolC9WqrPuP9Wj0gJNAdhnAYjtZN5fYEoGIsHBtuR3k+UxD2W7VWfjPDTY2zH
# e44WzfDvL2aXL2fomH73B7cx7YjT/7Du7vSdAHbr7SEdIyGJ5seMa+Y9MBJI48wZ
# A9CSnTGTFvhMXCYJuoR6Xc34A0EdHiTzfxY2tEWSiw5Xr+Oottc4IIHksNttYMgw
# HCu+tKqUlDkq5EdELh067r2Mv+OVkUkDQnLd1Vh/bP+yz92NKw7THQDYN7/4MTD2
# faNVsutryQIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFB7ZK3kpWqMOy6M4tybE49oI
# BMpsMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBACvoEvJ84B3DuFj+SDfpkM3OCxYon2F4wWTOQmpDmTwysrQ0
# grXhxNqMVL7QRKk34of1uvckfIhsjnckTjkaFJk/bQc8n5wwTzCKJ3T0rV/Vasoh
# MbGm4y3UYEh9nflmKbPpNhps20EeU9sdNIkxsrpQsPwk59wv13STtUjywuTvpM5s
# 1dQOIiUWrAMR14ZzOSBA7kgWI+UEj5iaGYOczxD+wH+07llzwlIC4TyRXtgKFuMF
# AONNNYUedbi6oOX7IPo0hb5RVPuVqAFxT98xIheJXNod9lf2JLhGD+H/pXnkZJRr
# VjJFcuJeEAnYAe7b97+BfhbPgv8V9FIAwqTxgxIwggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TCCBhEwggP5
# oAMCAQICEzMAAACOh5GkVxpfyj4AAAAAAI4wDQYJKoZIhvcNAQELBQAwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xNjExMTcyMjA5MjFaFw0xODAy
# MTcyMjA5MjFaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQh9RCK36d2cZ61KLD4xWS
# 0lOdlRfJUjb6VL+rEK/pyefMJlPDwnO/bdYA5QDc6WpnNDD2Fhe0AaWVfIu5pCzm
# izt59iMMeY/zUt9AARzCxgOd61nPc+nYcTmb8M4lWS3SyVsK737WMg5ddBIE7J4E
# U6ZrAmf4TVmLd+ArIeDvwKRFEs8DewPGOcPUItxVXHdC/5yy5VVnaLotdmp/ZlNH
# 1UcKzDjejXuXGX2C0Cb4pY7lofBeZBDk+esnxvLgCNAN8mfA2PIv+4naFfmuDz4A
# lwfRCz5w1HercnhBmAe4F8yisV/svfNQZ6PXlPDSi1WPU6aVk+ayZs/JN2jkY8fP
# AgMBAAGjggGAMIIBfDAfBgNVHSUEGDAWBgorBgEEAYI3TAgBBggrBgEFBQcDAzAd
# BgNVHQ4EFgQUq8jW7bIV0qqO8cztbDj3RUrQirswUgYDVR0RBEswSaRHMEUxDTAL
# BgNVBAsTBE1PUFIxNDAyBgNVBAUTKzIzMDAxMitiMDUwYzZlNy03NjQxLTQ0MWYt
# YmM0YS00MzQ4MWU0MTVkMDgwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1
# ApUwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEF
# BQcBAQRVMFMwUQYIKwYBBQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNV
# HRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBEiQKsaVPzxLa71IxgU+fKbKhJ
# aWa+pZpBmTrYndJXAlFq+r+bltumJn0JVujc7SV1eqVHUqgeSxZT8+4PmsMElSnB
# goSkVjH8oIqRlbW/Ws6pAR9kRqHmyvHXdHu/kghRXnwzAl5RO5vl2C5fAkwJnBpD
# 2nHt5Nnnotp0LBet5Qy1GPVUCdS+HHPNIHuk+sjb2Ns6rvqQxaO9lWWuRi1XKVjW
# kvBs2mPxjzOifjh2Xt3zNe2smjtigdBOGXxIfLALjzjMLbzVOWWplcED4pLJuavS
# Vwqq3FILLlYno+KYl1eOvKlZbiSSjoLiCXOC2TWDzJ9/0QSOiLjimoNYsNSa5jH6
# lEeOfabiTnnz2NNqMxZQcPFCu5gJ6f/MlVVbCL+SUqgIxPHo8f9A1/maNp39upCF
# 0lU+UK1GH+8lDLieOkgEY+94mKJdAw0C2Nwgq+ZWtd7vFmbD11WCHk+CeMmeVBoQ
# YLcXq0ATka6wGcGaM53uMnLNZcxPRpgtD1FgHnz7/tvoB3kH96EzOP4JmtuPe7Y6
# vYWGuMy8fQEwt3sdqV0bvcxNF/duRzPVQN9qyi5RuLW5z8ME0zvl4+kQjOunut6k
# LjNqKS8USuoewSI4NQWF78IEAA1rwdiWFEgVr35SsLhgxFK1SoK3hSoASSomgyda
# Qd691WZJvAuceHAJvDCCB3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEx
# MB4XDTExMDcwODIwNTkwOVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUg
# U2lnbmluZyBQQ0EgMjAxMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AKvw+nIQHC6t2G6qghBNNLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL
# 8DjCmQawyDnVARQxQtOJDXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/X
# llnKYBoF6WZ26DJSJhIv56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5k
# NXimoGMPLdNAk/jj3gcN1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJ
# Xtjt7UORg9l7snuGG9k+sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4
# ftKdgCz1TlaRITUlwzluZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgo
# tswnKDglmDlKNs98sZKuHCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0Xpb
# L9Uj43BdD1FGd7P4AOG8rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy
# 5yTfv0aZxe/CHFfbg43sTUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9
# Z4DmimJ4X7IvhNdXnFy/dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4
# IFgsE11glZo+TzOE2rCIF96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQ
# BgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUw
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0f
# BFMwUTBPoE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcB
# AQRSMFAwTgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kv
# Y2VydHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGX
# MIGUMIGRBgkrBgEEAYI3LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcC
# AjA0HjIgHQBMAGUAZwBhAGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUA
# bgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFj
# kplCln3SeQyQwWVfLiw++MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtG
# UFXYDJJ80hpLHPM8QotS0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32m
# kHSDjfTLJgJGKsKKELukqQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr
# 3vw70L01724lruWvJ+3Q3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYK
# wsatruWy2dsViFFFWDgycScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6C
# PxNNZgvAs0314Y9/HG8VfUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX
# 0O5dY0HjWwechz4GdwbRBrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADW
# oUa9WfOXpQlLSBCZgB/QACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9r
# t0uX4ut1eBrs6jeZeRhL/9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGd
# Vk5Pv4BXIqF4ETIheu9BCrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9
# bW1qyVJzEw16UM0xggTlMIIE4QIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5n
# IFBDQSAyMDExAhMzAAAAjoeRpFcaX8o+AAAAAACOMAkGBSsOAwIaBQCggfkwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFA2BfsP48NE3PMEokEirLzYGx/3NMIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEAKrY45qOhHzmJLspJD2AZuSXcadYoev8E
# 1xmsMf46Mf3kG3o5ypfgCklvv0G8cmabhnOiLtXzxpJir4c2TFeJOCEgHm/aK/sm
# /pZn+oER9LoRC4+FcDSKT6YYQU7wz3FO/P0mag57PO0/jpgB/324MVTfcxYdM6/A
# dpmowQ5lFiL9cuteMYdxqUCFFLYK9pdMYt7x1qr/B6in0hPgMFR6Qa80lL/w+W6G
# CCDf8M5PkMaCW6GQdIypdBDgMS8fvSskFHWR0WqtxfQX+MU6maYCmPbvX5rMOE17
# lVEEpSENGmW23pvV5kEyVUQIQQUz2MDzq67usZkVgBsEdsVKjXn00qGCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADJZE0W2xp9sxUAAAAAAMkwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxNFowIwYJ
# KoZIhvcNAQkEMRYEFLdjkdfTPRuu03/lDikP6ra6JOW5MA0GCSqGSIb3DQEBBQUA
# BIIBADQ48abfGNeTelELamO0GNINRo3b7xqFiKMeZ0MiWKh4/FBEqPYFn52LHH52
# OW1w/wjYFffh386Q1lFB7zp+hl31/uLrQOomEBguwyrqBjkNiD+FhIjS7b+nA0QW
# h+PY1TxYzpLltJOgQrzzeNQAH7F/d5V0Ut9fjuuFWqGjfYpTM+eJ9qUdqsZOO3iw
# /6LTMPk/5L8ledIlV5eEQPSr03jz3FzkuuFoqJFDl8dL8StmZuRbpD9ds3L63X5h
# 4Anuk9DvIr6X2FoCx7re6lwKMEQC8PF4/vaEzkL9IeqpxOJI15s7/Dl0XarHrZ2Y
# AIn8v3GNtl8BUcPOMeEG0stjIDs=
# SIG # End signature block
