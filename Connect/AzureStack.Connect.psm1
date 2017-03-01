# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0
#requires -Modules AzureRM.Profile, VpnClient, AzureStack

<#
    .SYNOPSIS
    Registers all providers on the all subscription
#>
function Register-AllAzureRmProvidersOnAllSubscriptions
{
    foreach($s in (Get-AzureRmSubscription))
    {
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
function Register-AllAzureRmProviders
{
    Get-AzureRmResourceProvider -ListAvailable | Register-AzureRmResourceProvider -Force
}

Export-ModuleMember Register-AllAzureRmProviders

<#
    .SYNOPSIS
    Obtains Aazure Active Directory tenant that was used when deploying the Azure Stack instance
#>
function Get-AzureStackAadTenant
{
    param (
        [parameter(mandatory=$true, HelpMessage="Azure Stack One Node host address or name such as '1.2.3.4'")]
	    [string] $HostComputer,        
        [Parameter(HelpMessage="The Admin ARM endpoint of the Azure Stack Environment")]
        [string] $ArmEndpoint = 'https://api.local.azurestack.external',
        [Parameter(HelpMessage="The Domain suffix of the environment VMs")]
        [string] $DomainSuffix = 'azurestack.local',
        [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
        [string] $User = "administrator",
        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )
    
    $Domain = ""
    try {
        $uriARMEndpoint = [System.Uri] $ArmEndpoint
        $Domain = $ArmEndpoint.Split(".")[-2] + '.' + $ArmEndpoint.Split(".")[-1]
    }
    catch {
        Write-Error "The specified ARM endpoint was invalid"
    }

    if($DomainSuffix){
        $Domain = $DomainSuffix
    }

    $UserCred = "$Domain\$User"
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $UserCred, $Password

    Write-Verbose "Remoting to the Azure Stack host $HostComputer..." -Verbose
    return Invoke-Command -ComputerName "$HostComputer" -Credential $credential -ScriptBlock `
        {            
            Write-Verbose "Retrieving Azure Stack configuration..." -Verbose
            $configFile = Get-ChildItem -Path C:\EceStore -Recurse | ?{-not $_.PSIsContainer} | sort Length -Descending | select -First 1
            $customerConfig = [xml] (Get-Content -Path $configFile.FullName)

            $Parameters = $customerConfig.CustomerConfiguration
            $fabricRole = $Parameters.Role.Roles.Role | ?{$_.Id -eq "Fabric"}
            $allFabricRoles = $fabricRole.Roles.ChildNodes
            $idProviderRole = $allFabricRoles | ?{$_.Id -eq "IdentityProvider"}
            $idProviderRole.PublicInfo.AADTenant.Id
        }
}

Export-ModuleMember Get-AzureStackAadTenant

<#
    .SYNOPSIS
    Adds Azure Stack environment to use with AzureRM command-lets when targeting Azure Stack
#>
function Add-AzureStackAzureRmEnvironment
{
    param (
        [parameter(mandatory=$true, HelpMessage="AAD Tenant name or ID used when deploying Azure Stack such as 'mydirectory.onmicrosoft.com'")]
	    [string] $AadTenant,
        [Parameter(HelpMessage="The Admin ARM endpoint of the Azure Stack Environment")]
        [string] $ArmEndpoint = 'https://api.local.azurestack.external',
        [parameter(HelpMessage="Azure Stack environment name for use with AzureRM commandlets")]
        [string] $Name = "AzureStack"
    )

    $Domain = ""
    try {
        $uriARMEndpoint = [System.Uri] $ArmEndpoint
        $Domain = $ArmEndpoint.Split(".")[-3] + '.' + $ArmEndpoint.Split(".")[-2] + '.' + $ArmEndpoint.Split(".")[-1] 
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
        AdTenant                                 = $AadTenant
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
    if($armEnv -ne $null)
    {
        Write-Verbose "Updating AzureRm environment $Name" -Verbose
        Remove-AzureRmEnvironment -Name $Name | Out-Null
    }
    else
    {
        Write-Verbose "Adding AzureRm environment $Name" -Verbose
    }
        
    return Add-AzureRmEnvironment @azureEnvironmentParams
}

Export-ModuleMember Add-AzureStackAzureRmEnvironment

<#
    .SYNOPSIS
    Obtains Azure Stack NAT address from the Azure Stack One Node instance
#>
function Get-AzureStackNatServerAddress
{
    param (    
        [parameter(mandatory=$true, HelpMessage="Azure Stack One Node host address or name such as '1.2.3.4'")]
	    [string] $HostComputer,
        [Parameter(HelpMessage="The Admin ARM endpoint of the Azure Stack Environment")]
        [string] $ArmEndpoint = 'https://api.local.azurestack.external',
        [Parameter(HelpMessage="The Domain suffix of the environment VMs")]
        [string] $DomainSuffix = 'azurestack.local',
        [parameter(HelpMessage="NAT computer name in this Azure Stack Instance")]
        [string] $natServer = "mas-bgpnat01",
        [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
        [string] $User = "administrator",
        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )

    $Domain = ""
    try {
        $uriARMEndpoint = [System.Uri] $ArmEndpoint
        $Domain = $ArmEndpoint.Split(".")[-2] + '.' + $ArmEndpoint.Split(".")[-1]
    }
    catch {
        Write-Error "The specified ARM endpoint was invalid"
    }

    if($DomainSuffix){
        $Domain = $DomainSuffix
    }

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
                    Get-NetIPConfiguration | ? { $_.IPv4DefaultGateway -ne $null } | foreach { $_.IPv4Address.IPAddress }
                }
        } 
}

Export-ModuleMember Get-AzureStackNatServerAddress

<#
    .SYNOPSIS
    Add VPN connection to an Azure Stack instance
#>
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

    $existingConnection = Get-VpnConnection -Name $ConnectionName -ErrorAction Ignore
    if ($existingConnection -ne $null) {
        Write-Verbose "Updating Azure Stack VPN connection named $ConnectionName" -Verbose
        rasdial $ConnectionName /d
        Remove-VpnConnection -name $ConnectionName -Force -ErrorAction Ignore
    }
    else
    {
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
function Connect-AzureStackVpn
{
    param (
	    [parameter(HelpMessage="Azure Stack VPN Connection Name such as 'my-poc'")]
	    [string] $ConnectionName = "azurestack",
        [Parameter(HelpMessage="The Admin ARM endpoint of the Azure Stack Environment")]
        [string] $ArmEndpoint = 'https://api.local.azurestack.external',
        [Parameter(HelpMessage="The Domain suffix of the environment VMs")]
        [string] $DomainSuffix = 'azurestack.local',
        [parameter(HelpMessage="Certificate Authority computer name in this Azure Stack Instance")]
        [string] $Remote = "mas-ca01",
        [parameter(HelpMessage="Administrator user name of this Azure Stack Instance")]
        [string] $User = "administrator",
        [parameter(mandatory=$true, HelpMessage="Administrator password used to deploy this Azure Stack instance")]
        [securestring] $Password
    )    

    $Domain = ""
    try {
        $uriARMEndpoint = [System.Uri] $ArmEndpoint
        $Domain = $ArmEndpoint.Split(".")[-2] + '.' + $ArmEndpoint.Split(".")[-1]
    }
    catch {
        Write-Error "The specified ARM endpoint was invalid"
    }

    
    if($DomainSuffix){
        $Domain = $DomainSuffix
    }
    
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

    if($cert -ne $null)
    {
        if($cert.GetType().IsArray)
        {
            $cert = $cert[0] # take any that match the subject if multiple certs were deployed
        }

        $certFilePath = "$azshome\CA.cer"

        Write-Verbose "Saving Azure Stack Root certificate in $certFilePath..." -Verbose

        Export-Certificate -Cert $cert -FilePath $certFilePath -Force | Out-Null

        Write-Verbose "Installing Azure Stack Root certificate for the current user..." -Verbose
        
        Write-Progress "LOOK FOR CERT ACCEPTANCE PROMPT ON YOUR SCREEN!"

	    Import-Certificate -CertStoreLocation cert:\currentuser\root -FilePath $certFilePath
    }
    else
    {
        Write-Error "Certificate has not been retrieved!"
    }
}

Export-ModuleMember Connect-AzureStackVpn

<#
    .SYNOPSIS
    Retrieve the admin token and subscription ID needed to make REST calls directly to Azure Resource Manager
#>
function Get-AzureStackAdminSubTokenHeader
{
    param (
	    [parameter(HelpMessage="Name of the Azure Stack Environment")]
	    [string] $EnvironmentName = "AzureStack",
	
	    [parameter(mandatory=$true, HelpMessage="TenantID of Identity Tenant")]
	    [string] $tenantID,

        [parameter(HelpMessage="Credentials to retrieve token header for")]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(HelpMessage="The administration ARM endpoint of the Azure Stack Environment")]
        [string] $ArmEndpoint = 'https://api.local.azurestack.external'
    )

    if(-not $azureStackCredentials){
        $azureStackCredentials = Get-Credential
    }
    
    $Domain = ""
    try {
        $uriARMEndpoint = [System.Uri] $ArmEndpoint
        $Domain = $ArmEndpoint.Split(".")[-2] + '.' + $ArmEndpoint.Split(".")[-1]
    }
    catch {
        Write-Error "The specified ARM endpoint was invalid"
    }

    $subscriptionName = "Default Provider Subscription"

    if (-not (Get-AzureRmEnvironment -Name AzureStack -ErrorAction SilentlyContinue)){
        Add-AzureStackAzureRmEnvironment -AadTenant $tenantID -ArmEndpoint $ArmEndpoint | Out-Null
    }

    $azureStackEnvironment = Get-AzureRmEnvironment -Name AzureStack -ErrorAction SilentlyContinue
    $authority = $azureStackEnvironment.ActiveDirectoryAuthority
    $activeDirectoryServiceEndpointResourceId = $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId

    Login-AzureRmAccount -EnvironmentName "AzureStack" -TenantId $tenantID -Credential $azureStackCredentials | Out-Null

    $subscription = Get-AzureRmSubscription -SubscriptionName $subscriptionName 
    $subscription | Select-AzureRmSubscription | Out-Null

    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"

    $adminToken = Get-AzureStackToken `
    -Authority $authority `
    -Resource $activeDirectoryServiceEndpointResourceId `
    -AadTenantId $tenantID `
    -ClientId $powershellClientId `
    -Credential $azureStackCredentials

    $headers = @{ Authorization = ("Bearer $adminToken") }
    
    return $subscription.SubscriptionId, $headers
}

Export-ModuleMember Get-AzureStackAdminSubTokenHeader

function Get-AADTenantGUID ()
{
    param(
        [parameter(mandatory=$true, HelpMessage="AAD Directory Tenant <myaadtenant.onmicrosoft.com>")]
	    [string] $AADTenantName = ""
    )
    $OauthMetadata = (wget -UseBasicParsing "https://login.microsoftonline.com/$AADTenantName/v2.0/.well-known/openid-configuration").Content | ConvertFrom-Json
    $AADid = $OauthMetadata.Issuer.Split('/')[3]
    $AADid
}

Export-ModuleMember Get-AADTenantGUID
