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
