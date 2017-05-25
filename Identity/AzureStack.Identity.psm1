# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
.Synopsis
    Get the Guid of the directory tenant
.DESCRIPTION
    This function fetches the OpenID configuration metadata from the identity system and parses the Directory TenantID out of it. 
    Azure Stack AD FS is configured to be a single tenanted identity system with a TenantID.
.EXAMPLE
    Get-DirectoryTenantIdentifier -authority https://login.windows.net/microsoft.onmicrosoft.com
.EXAMPLE
    Get-DirectoryTenantIdentifier -authority https://adfs.local.azurestack.external/adfs
#>
function Get-DirectoryTenantIdentifier {
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            Position = 0)]
        $Authority
    )

    return $(Invoke-RestMethod $("{0}/.well-known/openid-configuration" -f $authority.TrimEnd('/'))).issuer.TrimEnd('/').Split('/')[-1]
}

<#
   .Synopsis
      This function is used to create a Service Principal on teh AD Graph
   .DESCRIPTION
      The command creates a certificate in the cert store of the local user and uses that certificate to create a Service Principal in the Azure Stack Stamp Active Directory.
   .EXAMPLE
      $servicePrincipal = New-ADGraphServicePrincipal -DisplayName "mySPApp" -AdminCredential $(Get-Credential) -Verbose
   .EXAMPLE
      $servicePrincipal = New-ADGraphServicePrincipal -DisplayName "mySPApp" -AdminCredential $(Get-Credential) -DeleteAndCreateNew -Verbose
   #>
function New-ADGraphServicePrincipal {
    [CmdletBinding()]
    Param
    (
        # Display Name of the Service Principal
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [Parameter(Mandatory = $true,
            Position = 0)]
        $DisplayName,

        # Adfs Machine name
        [Parameter(Mandatory = $true , Position = 1)]
        [string]
        $AdfsMachineName = "mas-adfs01.azurestack.local",

        # Domain Administrator Credential to create Service Principal
        [Parameter(Mandatory = $true,
            Position = 2)]
        [System.Management.Automation.PSCredential]
        $AdminCredential,

        # Switch to delete existing Service Principal with Provided Display Name and recreate
        [Parameter(Mandatory = $false)]
        [switch]
        $DeleteAndCreateNew
    )

    Write-Verbose "Creating a Certificate for the Service Principal.."
    $clientCertificate = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject "CN=$DisplayName" -KeySpec KeyExchange
    $scriptBlock = {
        param ([string] $DisplayName, [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate, [bool] $DeleteAndCreateNew)
        $VerbosePreference = "Continue"
        $ErrorActionPreference = "stop"

        Import-Module 'ActiveDirectory' -Verbose:$false 4> $null

        # Application Group Name
        $applicationGroupName = $DisplayName + "-AppGroup"
        $applicationGroupDescription = "Application group for $DisplayName"
        $shellSiteDisplayName = $DisplayName
        $shellSiteRedirectUri = "https://localhost/".ToLowerInvariant()
        $shellSiteApplicationId = [guid]::NewGuid().ToString()
        $shellSiteClientDescription = "Client for $DisplayName"
        $defaultTimeOut = New-TimeSpan -Minutes 5

        if ($DeleteAndCreateNew) {
            $applicationGroup = Get-GraphApplicationGroup -ApplicationGroupName $applicationGroupName -Timeout $defaultTimeOut
            Write-Verbose $applicationGroup
            if ($applicationGroup) {
                Write-Warning -Message "Deleting existing application group with name '$applicationGroupName'."
                Remove-GraphApplicationGroup -TargetApplicationGroup $applicationGroup -Timeout $defaultTimeOut
            }
        }

        Write-Verbose -Message "Creating new application group with name '$applicationGroupName'."
        $applicationParameters = @{
            Name = $applicationGroupName
            Description = $applicationGroupDescription
            ClientType = 'Confidential'
            ClientId = $shellSiteApplicationId
            ClientDisplayName = $shellSiteDisplayName
            ClientRedirectUris = $shellSiteRedirectUri
            ClientDescription = $shellSiteClientDescription
            ClientCertificates = $ClientCertificate
        }
        $defaultTimeOut = New-TimeSpan -Minutes 10
        $applicationGroup = New-GraphApplicationGroup @applicationParameters -PassThru -Timeout $defaultTimeOut

        Write-Verbose -Message "Shell Site ApplicationGroup: $($applicationGroup | ConvertTo-Json)"
        return [pscustomobject]@{
            ObjectId = $applicationGroup.Identifier
            ApplicationId = $applicationParameters.ClientId
            Thumbprint = $ClientCertificate.Thumbprint
        }
    }
    $domainAdminSession = New-PSSession -ComputerName $AdfsMachineName -Credential $AdminCredential -Authentication Credssp -Verbose
    $output = Invoke-Command -Session $domainAdminSession -ScriptBlock $scriptBlock -ArgumentList @($DisplayName, $ClientCertificate, $DeleteAndCreateNew.IsPresent) -Verbose -ErrorAction Stop
    Write-Verbose "AppDetails: $(ConvertTo-Json $output -Depth 2)"   
    return $output
}

# Helper Functions

function Initialize-AzureRmEnvironment([string]$EnvironmentName, [string] $ResourceManagerEndpoint, [string] $DirectoryTenantName) {
    $endpoints = Invoke-RestMethod -Method Get -Uri "$($ResourceManagerEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -Verbose
    Write-Verbose -Message "Endpoints: $(ConvertTo-Json $endpoints)" -Verbose

    # resolve the directory tenant ID from the name
    $directoryTenantId = (New-Object uri(Invoke-RestMethod "$($endpoints.authentication.loginEndpoint.TrimEnd('/'))/$DirectoryTenantName/.well-known/openid-configuration").token_endpoint).AbsolutePath.Split('/')[1]

    $azureEnvironmentParams = @{
        Name = $EnvironmentName
        ActiveDirectoryEndpoint = $endpoints.authentication.loginEndpoint.TrimEnd('/') + "/"
        ActiveDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
        AdTenant = $directoryTenantId
        ResourceManagerEndpoint = $ResourceManagerEndpoint
        GalleryEndpoint = $endpoints.galleryEndpoint
        GraphEndpoint = $endpoints.graphEndpoint
        GraphAudience = $endpoints.graphEndpoint
    }

    Remove-AzureRmEnvironment -Name $EnvironmentName -Force -ErrorAction Ignore | Out-Null
    $azureEnvironment = Add-AzureRmEnvironment @azureEnvironmentParams
    $azureEnvironment = Get-AzureRmEnvironment -Name $EnvironmentName
    
    return $azureEnvironment
}

function Resolve-AzureEnvironment([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureStackEnvironment) {
    $azureEnvironment = Get-AzureRmEnvironment |
        Where GraphEndpointResourceId -EQ $azureStackEnvironment.GraphEndpointResourceId |
        Where Name -In @('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment', 'AzureGermanCloud')

    # Differentiate between AzureCloud and AzureUSGovernment
    if ($azureEnvironment.Count -ge 2) {
        $name = if ($azureStackEnvironment.ActiveDirectoryAuthority -eq 'https://login-us.microsoftonline.com/') { 'AzureUSGovernment' } else { 'AzureCloud' }
        $azureEnvironment = $azureEnvironment | Where Name -EQ $name
    }

    return $azureEnvironment
}

function Initialize-AzureRmUserAccount([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureEnvironment, [string] $SubscriptionName, [string] $SubscriptionId) {
    # Prompts the user for interactive login flow
    $azureAccount = Add-AzureRmAccount -EnvironmentName $azureEnvironment.Name -TenantId $azureEnvironment.AdTenant
    
    if ($SubscriptionName) {
        Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
    }
    elseif ($SubscriptionId) {
        Select-AzureRmSubscription -SubscriptionId $SubscriptionId  | Out-Null
    }

    return $azureAccount
}

function Get-IdentityApplicationData {
    # Import and read application data
    Write-Host "Loading identity application data..."
    $xmlData = [xml](Get-ChildItem -Path C:\EceStore -Recurse -Force -File | Sort Length | Select -Last 1 | Get-Content | Out-String)
    $xmlIdentityApplications = $xmlData.SelectNodes('//IdentityApplication')

    return $xmlIdentityApplications
}

function Resolve-GraphEnvironment([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureEnvironment) {
    $graphEnvironment = switch ($azureEnvironment.ActiveDirectoryAuthority) {
        'https://login.microsoftonline.com/' { 'AzureCloud'        }
        'https://login.chinacloudapi.cn/' { 'AzureChinaCloud'   }
        'https://login-us.microsoftonline.com/' { 'AzureUSGovernment' }
        'https://login.microsoftonline.de/' { 'AzureGermanCloud'  }

        Default { throw "Unsupported graph resource identifier: $_" }
    }

    return $graphEnvironment
}

function Get-AzureRmUserRefreshToken([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureEnvironment, [string]$directoryTenantId) {
    # Prompts the user for interactive login flow
    $azureAccount = Add-AzureRmAccount -EnvironmentName $azureEnvironment.Name -TenantId $directoryTenantId

    # Retrieve the refresh token
    $tokens = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()
    $refreshToken = $tokens |
        Where Resource -EQ $azureEnvironment.ActiveDirectoryServiceEndpointResourceId |
        Where IsMultipleResourceRefreshToken -EQ $true |
        Where DisplayableId -EQ $azureAccount.Context.Account.Id |
        Select -ExpandProperty RefreshToken |
        ConvertTo-SecureString -AsPlainText -Force

    return $refreshToken
}

<#
    .Synopsis
    Adds a Guest Directory Tenant to Azure Stack.
    .DESCRIPTION
    Running this cmdlet will add the specified directory tenant to the Azure Stack whitelist.    
    .EXAMPLE
    $adminARMEndpoint = "https://adminmanagement.local.azurestack.external"
    $azureStackDirectoryTenant = "<homeDirectoryTenant>.onmicrosoft.com"
    $guestDirectoryTenantToBeOnboarded = "<guestDirectoryTenant>.onmicrosoft.com"

    Register-GuestDirectoryTenantToAzureStack -AdminResourceManagerEndpoint $adminARMEndpoint -DirectoryTenantName $azureStackDirectoryTenant -GuestDirectoryTenantName $guestDirectoryTenantToBeOnboarded
#>
function Register-GuestDirectoryTenantToAzureStack {
    [CmdletBinding()]
    param
    (
        # The endpoint of the Azure Stack Resource Manager service.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateScript( {$_.Scheme -eq [System.Uri]::UriSchemeHttps})]
        [uri] $AdminResourceManagerEndpoint,

        # The name of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantName,

        # The name of the guest Directory Tenant which is to be onboarded.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $GuestDirectoryTenantName,

        # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNull()]
        [string] $SubscriptionId = $null,

        # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNull()]
        [string] $SubscriptionName = $null,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName = 'system',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Location = 'local'
    )
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    # Install-Module AzureRm -RequiredVersion '1.2.8'
    Import-Module 'AzureRm.Profile' -Force -Verbose:$false 4> $null

    # Initialize the Azure PowerShell module to communicate with Azure Stack. Will prompt user for credentials.
    $azureEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStackAdmin' -ResourceManagerEndpoint $AdminResourceManagerEndpoint -DirectoryTenantName $DirectoryTenantName
    $azureAccount = Initialize-AzureRmUserAccount -azureEnvironment $azureEnvironment -SubscriptionName $SubscriptionName -SubscriptionId $SubscriptionId

    # resolve the guest directory tenant ID from the name
    $guestDirectoryTenantId = (New-Object uri(Invoke-RestMethod "$($azureEnvironment.ActiveDirectoryAuthority.TrimEnd('/'))/$GuestDirectoryTenantName/.well-known/openid-configuration").token_endpoint).AbsolutePath.Split('/')[1]

    # Add (or update) the new directory tenant to the Azure Stack deployment
    $params = @{
        ApiVersion = '2015-11-01' # needed if using "latest" / later version of Azure Powershell
        ResourceType = "Microsoft.Subscriptions.Admin/directoryTenants"
        ResourceGroupName = $ResourceGroupName
        ResourceName = $GuestDirectoryTenantName
        Location = $Location
        Properties = @{ tenantId = $guestDirectoryTenantId }
    }
    $directoryTenant = New-AzureRmResource @params -Force -Verbose -ErrorAction Stop
    Write-Verbose -Message "Directory Tenant onboarded: $(ConvertTo-Json $directoryTenant)" -Verbose
}

<#
    .Synopsis
    Publishes the list of applications to the Azure Stack ARM. 
    .DESCRIPTION
        
    .EXAMPLE
    $adminARMEndpoint = "https://adminmanagement.local.azurestack.external"
    $azureStackDirectoryTenant = "<homeDirectoryTenant>.onmicrosoft.com"
    $guestDirectoryTenantToBeOnboarded = "<guestDirectoryTenant>.onmicrosoft.com"

    Publish-AzureStackApplicationsToARM -AdminResourceManagerEndpoint $adminARMEndpoint -DirectoryTenantName $azureStackDirectoryTenant    
#>
function Publish-AzureStackApplicationsToARM {
    [CmdletBinding()]
    param
    (
        # The endpoint of the Azure Stack Resource Manager service.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateScript( {$_.Scheme -eq [System.Uri]::UriSchemeHttps})]
        [uri] $AdminResourceManagerEndpoint,

        # The name of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantName,

        # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [Parameter()]
        [ValidateNotNull()]
        [string] $SubscriptionId = $null,

        # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [Parameter()]
        [ValidateNotNull()]
        [string] $SubscriptionName = $null,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName = 'system',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Location = 'local',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path -Path $_ -PathType Container -ErrorAction Stop})]
        [string] $InfrastructureSharePath = '\\SU1FileServer\SU1_Infrastructure_1'
    )
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    # Install-Module AzureRm -RequiredVersion '1.2.8'
    Import-Module 'AzureRm.Profile' -Force -Verbose:$false 4> $null
    Write-Warning "This script is intended to work only with the initial TP3 release of Azure Stack and will be deprecated."
 
    # Initialize the Azure PowerShell module to communicate with Azure Stack. Will prompt user for credentials.
    $azureEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStackAdmin' -ResourceManagerEndpoint $AdminResourceManagerEndpoint -DirectoryTenantName $DirectoryTenantName   
    $azureAccount = Initialize-AzureRmUserAccount -azureEnvironment $azureEnvironment -SubscriptionName $SubscriptionName -SubscriptionId $SubscriptionId

    # Register each identity application for future onboarding.
    $xmlIdentityApplications = Get-IdentityApplicationData
    foreach ($xmlIdentityApplication in $xmlIdentityApplications) {
        $applicationData = Get-Content -Path ($xmlIdentityApplication.ConfigPath.Replace('{Infrastructure}', $InfrastructureSharePath)) | Out-String | ConvertFrom-Json

        # Note - 'Admin' applications do not need to be registered for replication into a new directory tenant
        if ($xmlIdentityApplication.Name.StartsWith('Admin', [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "Skipping registration of Admin application: $('{0}.{1}' -f $xmlIdentityApplication.Name, $xmlIdentityApplication.DisplayName)"
            continue
        }

        # Advertise any necessary OAuth2PermissionGrants for the application
        $oauth2PermissionGrants = @()
        foreach ($applicationFriendlyName in $xmlIdentityApplication.OAuth2PermissionGrants.FirstPartyApplication.FriendlyName) {
            $oauth2PermissionGrants += [pscustomobject]@{
                Resource = $applicationData.ApplicationInfo.appId
                Client = $applicationData.GraphInfo.Applications."$applicationFriendlyName".Id
                ConsentType = 'AllPrincipals'
                Scope = 'user_impersonation'
            }
        }

        $params = @{
            ApiVersion = '2015-11-01' # needed if using "latest" / later version of Azure Powershell
            ResourceType = "Microsoft.Subscriptions.Providers/applicationRegistrations"
            ResourceGroupName = $ResourceGroupName
            ResourceName = '{0}.{1}' -f $xmlIdentityApplication.Name, $xmlIdentityApplication.DisplayName
            Location = $Location
            Properties = @{
                "objectId" = $applicationData.ApplicationInfo.objectId
                "appId" = $applicationData.ApplicationInfo.appId
                "oauth2PermissionGrants" = $oauth2PermissionGrants
                "directoryRoles" = @()
                "tags" = @()
            }
        }

        # Advertise 'ReadDirectoryData' workaround for applications which require this permission of type 'Role'
        if ($xmlIdentityApplication.AADPermissions.ApplicationPermission.Name -icontains 'ReadDirectoryData') {
            $params.Properties.directoryRoles = @('Directory Readers')
        }

        # Advertise any specified tags required for application integration scenarios
        if ($xmlIdentityApplication.tags) {
            $params.Properties.tags += $xmlIdentityApplication.tags
        }

        $registeredApplication = New-AzureRmResource @params -Force -Verbose -ErrorAction Stop
        Write-Verbose -Message "Identity application registered: $(ConvertTo-Json $registeredApplication)" -Verbose
    }
}

<#
.Synopsis
Consents to the given Azure Stack instance within the callers's Azure Directory Tenant.
.DESCRIPTION
Consents to the given Azure Stack instance within the callers's Azure Directory Tenant. This is needed to propagate Azure Stack applications into the user's directory tenant. 
.EXAMPLE
$tenantARMEndpoint = "https://management.local.azurestack.external"
$myDirectoryTenantName = "<guestDirectoryTenant>.onmicrosoft.com"

Register-AzureStackWithMyDirectoryTenant -TenantResourceManagerEndpoint $tenantARMEndpoint `
    -DirectoryTenantName $myDirectoryTenantName -Verbose -Debug
#>
function Register-AzureStackWithMyDirectoryTenant {
    [CmdletBinding()]
    param
    (
        # The endpoint of the Azure Stack Resource Manager service.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateScript( {$_.Scheme -eq [System.Uri]::UriSchemeHttps})]
        [uri] $TenantResourceManagerEndpoint,

        # The name of the directory tenant being onboarded.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantName
    )

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    # Install-Module AzureRm -RequiredVersion '1.2.8'
    Import-Module 'AzureRm.Profile' -Force -Verbose:$false 4> $null
    Import-Module "$PSScriptRoot\GraphAPI\GraphAPI.psm1"       -Force -Verbose:$false 4> $null

    # Initialize the Azure PowerShell module to communicate with the Azure Resource Manager corresponding to their home Graph Service. Will prompt user for credentials.
    $azureStackEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStack' -ResourceManagerEndpoint $TenantResourceManagerEndpoint -DirectoryTenantName $DirectoryTenantName
    $azureEnvironment = Resolve-AzureEnvironment $azureStackEnvironment
    $refreshToken = Get-AzureRmUserRefreshToken $azureEnvironment $azureStackEnvironment.AdTenant

    # Initialize the Graph PowerShell module to communicate with the correct graph service
    $graphEnvironment = Resolve-GraphEnvironment $azureEnvironment
    Initialize-GraphEnvironment -Environment $graphEnvironment -DirectoryTenantId $DirectoryTenantName -RefreshToken $refreshToken

    # Authorize the Azure Powershell module to act as a client to call the Azure Stack Resource Manager in the onboarded tenant
    Initialize-GraphOAuth2PermissionGrant -ClientApplicationId (Get-GraphEnvironmentInfo).Applications.PowerShell.Id -ResourceApplicationIdentifierUri $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId

    # Call Azure Stack Resource Manager to retrieve the list of registered applications which need to be initialized in the onboarding directory tenant
    $armAccessToken = (Get-GraphToken -Resource $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId -UseEnvironmentData).access_token
    $applicationRegistrationParams = @{
        Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        Headers = @{ Authorization = "Bearer $armAccessToken" }
        Uri = "$($TenantResourceManagerEndpoint.ToString().TrimEnd('/'))/applicationRegistrations?api-version=2014-04-01-preview"
    }
    $applicationRegistrations = Invoke-RestMethod @applicationRegistrationParams | Select -ExpandProperty value

    # Initialize each registered application in the onboarding directory tenant
    foreach ($applicationRegistration in $applicationRegistrations) {
        # Initialize the service principal for the registered application, updating any tags as necessary
        $applicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $applicationRegistration.appId
        if ($applicationRegistration.tags) {
            Update-GraphApplicationServicePrincipalTags -ApplicationId $applicationRegistration.appId -Tags $applicationRegistration.tags
        }

        # Initialize the necessary oauth2PermissionGrants for the registered application
        foreach ($oauth2PermissionGrant in $applicationRegistration.oauth2PermissionGrants) {
            $oauth2PermissionGrantParams = @{
                ClientApplicationId = $oauth2PermissionGrant.client
                ResourceApplicationId = $oauth2PermissionGrant.resource
                Scope = $oauth2PermissionGrant.scope
            }
            Initialize-GraphOAuth2PermissionGrant @oauth2PermissionGrantParams
        }

        # Initialize the necessary directory role membership(s) for the registered application
        foreach ($directoryRole in $applicationRegistration.directoryRoles) {
            Initialize-GraphDirectoryRoleMembership -ApplicationId $applicationRegistration.appId -RoleDisplayName $directoryRole
        }
    }
}

# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUKHq4YImy22YKBhnTL8GU8FTF
# MyugghhlMIIEwzCCA6ugAwIBAgITMwAAAMlkTRbbGn2zFQAAAAAAyTANBgkqhkiG
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
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFN/48Q6HQPLmTLY5gCD4AjOxumjDMIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEAoFYS7pQTV0Kuux/uFX+4f0I3S/R43soF
# Ys4VRT3UBvaw6O/GWPzBcia7QuvhPlbH9O0OWXjekz5PzO8sdlEmAp/W/uHOdWCb
# cDcz6ihc4YJ0klMq460BucLGfVlFlFtSYLeFOmPWorV1ayCmeer4vsJYwiOIFKU1
# 525YSqC440foS+PzwB+NvT7HeoAL+u6ySi0OurNcHVtoPYoeJOLUOKtbXJpBGWdQ
# JQ5qhNdVO8oNojsVsgaIV5La0gXKqnqv43NDCagq/yCok1AvNzH8PmmF+o8xaG9Z
# NwE0SjKhwE92AdFHWqNQrLEnyeaOMREfhqX/U/vfU2cZVH8RYQhRf6GCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADJZE0W2xp9sxUAAAAAAMkwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxN1owIwYJ
# KoZIhvcNAQkEMRYEFFonG+sErm/35uLERm4xqHGCXNUwMA0GCSqGSIb3DQEBBQUA
# BIIBABHRZoEgK037ONL0UMU94cCSA0CX6wX2aM+hMpRTmdXrtnSicTtfEzgt0rx1
# 606n4JFz9duttKyYCrOF6jkzjF1n/pKdHO8us8AiGVMdZHHGNHbZft1rNhwebhe/
# C5aY0+RnNclQ/noUpYgNgcDxJnYmykwK4/TvWSNyjsZbPQgFKluDun6yV590ei8U
# 3NMRKEVh0bxTVHP36oYs0+fAe+RyfWk4aLKVAvkr+mXcN9uwivfSz5hReetJ/UkZ
# OB7WGhfn2q7mhFjflVo5c4He4tWkTYaqHr23MCy3pJDvX5a0UcUuaUMP5RHlLoOR
# 9/eZ+TdyUFNlYm6CVbHMOPoTMfE=
# SIG # End signature block
