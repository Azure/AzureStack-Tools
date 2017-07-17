# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
.Synopsis
    Get the Guid of the directory tenant
.DESCRIPTION
    This function fetches the OpenID configuration metadata from the identity system and parses the Directory TenantID out of it. 
    Azure Stack AD FS is configured to be a single tenanted identity system with a TenantID.
.EXAMPLE
    Get-AzsDirectoryTenantIdentifier -authority https://login.windows.net/microsoft.onmicrosoft.com
.EXAMPLE
    Get-AzsDirectoryTenantIdentifier -authority https://adfs.local.azurestack.external/adfs
#>

function Get-AzsDirectoryTenantidentifier {
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
      $servicePrincipal = New-AzsAdGraphServicePrincipal -DisplayName "mySPApp" -AdminCredential $(Get-Credential) -Verbose
   .EXAMPLE
      $servicePrincipal = New-AzsAdGraphServicePrincipal -DisplayName "mySPApp" -AdminCredential $(Get-Credential) -DeleteAndCreateNew -Verbose
   #>

function New-AzsAdGraphServicePrincipal {
    [CmdletBinding()]
    Param
    (
        # Display Name of the Service Principal
        [ValidatePattern("[a-zA-Z0-9-]{3,}")]
        [Parameter(Mandatory = $true,
            Position = 0)]
        $DisplayName,

        # Adfs Machine name
        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $AdfsMachineName,

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
            Name               = $applicationGroupName
            Description        = $applicationGroupDescription
            ClientType         = 'Confidential'
            ClientId           = $shellSiteApplicationId
            ClientDisplayName  = $shellSiteDisplayName
            ClientRedirectUris = $shellSiteRedirectUri
            ClientDescription  = $shellSiteClientDescription
            ClientCertificates = $ClientCertificate
        }
        $defaultTimeOut = New-TimeSpan -Minutes 10
        $applicationGroup = New-GraphApplicationGroup @applicationParameters -PassThru -Timeout $defaultTimeOut

        Write-Verbose -Message "Shell Site ApplicationGroup: $($applicationGroup | ConvertTo-Json)"
        return [pscustomobject]@{
            ObjectId      = $applicationGroup.Identifier
            ApplicationId = $applicationParameters.ClientId
            Thumbprint    = $ClientCertificate.Thumbprint
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
        Name                                     = $EnvironmentName
        ActiveDirectoryEndpoint                  = $endpoints.authentication.loginEndpoint.TrimEnd('/') + "/"
        ActiveDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
        AdTenant                                 = $directoryTenantId
        ResourceManagerEndpoint                  = $ResourceManagerEndpoint
        GalleryEndpoint                          = $endpoints.galleryEndpoint
        GraphEndpoint                            = $endpoints.graphEndpoint
        GraphAudience                            = $endpoints.graphEndpoint
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

function Initialize-AzureRmUserAccount([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureEnvironment, [string] $SubscriptionName, [string] $SubscriptionId, [pscredential] $AutomationCredential) {
    
    $params = @{
        EnvironmentName = $azureEnvironment.Name
        TenantId        = $azureEnvironment.AdTenant
    }

    if ($AutomationCredential)
    {
        $params += @{ Credential = $AutomationCredential }
    }

    # Prompts the user for interactive login flow if automation credential is not specified
    $azureAccount = Add-AzureRmAccount @params

    if ($SubscriptionName)
    {
        Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
    }
    elseif ($SubscriptionId)
    {
        Select-AzureRmSubscription -SubscriptionId $SubscriptionId  | Out-Null
    }

    return $azureAccount
}

function Resolve-GraphEnvironment([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureEnvironment)
{
    $graphEnvironment = switch ($azureEnvironment.ActiveDirectoryAuthority) {
        'https://login.microsoftonline.com/' { 'AzureCloud'        }
        'https://login.chinacloudapi.cn/' { 'AzureChinaCloud'   }
        'https://login-us.microsoftonline.com/' { 'AzureUSGovernment' }
        'https://login.microsoftonline.de/' { 'AzureGermanCloud'  }

        Default { throw "Unsupported graph resource identifier: $_" }
    }

    return $graphEnvironment
}

function Get-AzureRmUserRefreshToken([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureEnvironment, [string]$directoryTenantId, [pscredential]$AutomationCredential)
{
    $params = @{
        EnvironmentName = $azureEnvironment.Name
        TenantId        = $directoryTenantId
    }

    if ($AutomationCredential)
    {
        $params += @{ Credential = $AutomationCredential }
    }

    # Prompts the user for interactive login flow if automation credential is not specified
    $azureAccount = Add-AzureRmAccount @params

    # Retrieve the refresh token
    $tokens = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()
    $refreshToken = $tokens |
        Where Resource -EQ $azureEnvironment.ActiveDirectoryServiceEndpointResourceId |
        Where IsMultipleResourceRefreshToken -EQ $true |
        Where DisplayableId -EQ $azureAccount.Context.Account.Id |
        Sort ExpiresOn |
        Select -Last 1 -ExpandProperty RefreshToken |
        ConvertTo-SecureString -AsPlainText -Force

    return $refreshToken
}

# Exposed Functions

<#
    .Synopsis
    Adds a Guest Directory Tenant to Azure Stack.
    .DESCRIPTION
    Running this cmdlet will add the specified directory tenant to the Azure Stack whitelist.    
    .EXAMPLE
    $adminARMEndpoint = "https://adminmanagement.local.azurestack.external"
    $azureStackDirectoryTenant = "<homeDirectoryTenant>.onmicrosoft.com"
    $guestDirectoryTenantToBeOnboarded = "<guestDirectoryTenant>.onmicrosoft.com"

    Register-AzsGuestDirectoryTenant -AdminResourceManagerEndpoint $adminARMEndpoint -DirectoryTenantName $azureStackDirectoryTenant -GuestDirectoryTenantName $guestDirectoryTenantToBeOnboarded
#>

function Register-AzsGuestDirectoryTenant {
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

        # The names of the guest Directory Tenants which are to be onboarded.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $GuestDirectoryTenantName,

        # The location of your Azure Stack deployment.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Location,

        # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNull()]
        [string] $SubscriptionId = $null,

        # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNull()]
        [string] $SubscriptionName = $null,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName = 'system.local',

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    # Install-Module AzureRm -RequiredVersion '1.2.8'
    Import-Module 'AzureRm.Profile' -Force -Verbose:$false 4> $null

    # Initialize the Azure PowerShell module to communicate with Azure Stack. Will prompt user for credentials.
    $azureEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStackAdmin' -ResourceManagerEndpoint $AdminResourceManagerEndpoint -DirectoryTenantName $DirectoryTenantName
    $azureAccount = Initialize-AzureRmUserAccount -azureEnvironment $azureEnvironment -SubscriptionName $SubscriptionName -SubscriptionId $SubscriptionId -AutomationCredential $AutomationCredential

    foreach ($directoryTenantName in $GuestDirectoryTenantName)
    {
        # Resolve the guest directory tenant ID from the name
        $directoryTenantId = (New-Object uri(Invoke-RestMethod "$($azureEnvironment.ActiveDirectoryAuthority.TrimEnd('/'))/$directoryTenantName/.well-known/openid-configuration").token_endpoint).AbsolutePath.Split('/')[1]

        # Add (or update) the new directory tenant to the Azure Stack deployment
        $params = @{
            ApiVersion        = '2015-11-01'
            ResourceType      = "Microsoft.Subscriptions.Admin/directoryTenants"
            ResourceGroupName = $ResourceGroupName
            ResourceName      = $directoryTenantName
            Location          = $Location
            Properties        = @{ tenantId = $directoryTenantId }
        }
        $directoryTenant = New-AzureRmResource @params -Force -Verbose -ErrorAction Stop
        Write-Verbose -Message "Directory Tenant onboarded: $(ConvertTo-Json $directoryTenant)" -Verbose
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

Register-AzsWithMyDirectoryTenant -TenantResourceManagerEndpoint $tenantARMEndpoint `
    -DirectoryTenantName $myDirectoryTenantName -Verbose -Debug
#>

function Register-AzsWithMyDirectoryTenant {
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
        [string] $DirectoryTenantName,

        # Optional: The identifier (GUID) of the Resource Manager application. Pass this parameter to skip the need to complete the guest signup flow via the portal.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceManagerApplicationId,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    # Install-Module AzureRm -RequiredVersion '1.2.8'
    Import-Module 'AzureRm.Profile' -Force -Verbose:$false 4> $null
    Import-Module "$PSScriptRoot\GraphAPI\GraphAPI.psm1" -Force -Verbose:$false 4> $null

    # Initialize the Azure PowerShell module to communicate with the Azure Resource Manager corresponding to their home Graph Service. Will prompt user for credentials.
    $azureStackEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStack' -ResourceManagerEndpoint $TenantResourceManagerEndpoint -DirectoryTenantName $DirectoryTenantName
    $azureEnvironment = Resolve-AzureEnvironment $azureStackEnvironment
    $refreshToken = Get-AzureRmUserRefreshToken -azureEnvironment $azureEnvironment -directoryTenantId $azureStackEnvironment.AdTenant -AutomationCredential $AutomationCredential

    # Initialize the Graph PowerShell module to communicate with the correct graph service
    $graphEnvironment = ResolveGraphEnvironment $azureEnvironment
    Initialize-GraphEnvironment -Environment $graphEnvironment -DirectoryTenantId $DirectoryTenantName -RefreshToken $refreshToken

    # Initialize the service principal for the Azure Stack Resource Manager application (allows us to acquire a token to ARM). If not specified, the sign-up flow must be completed via the Azure Stack portal first.
    if ($ResourceManagerApplicationId)
    {
        $resourceManagerServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $ResourceManagerApplicationId
    }

    # Authorize the Azure Powershell module to act as a client to call the Azure Stack Resource Manager in the onboarding directory tenant
    Initialize-GraphOAuth2PermissionGrant -ClientApplicationId (Get-GraphEnvironmentInfo).Applications.PowerShell.Id -ResourceApplicationIdentifierUri $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId
    Write-Host "Delaying for 15 seconds to allow the permission for Azure PowerShell to be initialized..."
    Start-Sleep -Seconds 15

    # Authorize the Azure Powershell module to act as a client to call the Azure Stack Resource Manager in the onboarded tenant
    Initialize-GraphOAuth2PermissionGrant -ClientApplicationId (Get-GraphEnvironmentInfo).Applications.PowerShell.Id -ResourceApplicationIdentifierUri $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId

    # Call Azure Stack Resource Manager to retrieve the list of registered applications which need to be initialized in the onboarding directory tenant
    $armAccessToken = (Get-GraphToken -Resource $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId -UseEnvironmentData).access_token
    $applicationRegistrationParams = @{
        Method  = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        Headers = @{ Authorization = "Bearer $armAccessToken" }
        Uri     = "$($TenantResourceManagerEndpoint.ToString().TrimEnd('/'))/applicationRegistrations?api-version=2014-04-01-preview"
    }
    $applicationRegistrations = Invoke-RestMethod @applicationRegistrationParams | Select-Object -ExpandProperty value

    # Identify which permissions have already been granted to each registered application and which additional permissions need consent
    $permissions = @()
    foreach ($applicationRegistration in $applicationRegistrations)
    {
        # Initialize the service principal for the registered application
        $applicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $applicationRegistration.appId

        # Initialize the necessary tags for the registered application
        if ($applicationRegistration.tags)
        {
            Update-GraphApplicationServicePrincipalTags -ApplicationId $applicationRegistration.appId -Tags $applicationRegistration.tags
        }

        # Lookup the permission consent status for the application permissions (either to or from) that the registered application requires
        foreach($appRoleAssignment in $applicationRegistration.appRoleAssignments)
        {
            $params = @{
                ClientApplicationId   = $appRoleAssignment.client
                ResourceApplicationId = $appRoleAssignment.resource
                PermissionType        = 'Application'
                PermissionId          = $appRoleAssignment.roleId
            }
            $permissions += New-GraphPermissionDescription @params -LookupConsentStatus
        }

        # Lookup the permission consent status for the delegated permissions (either to or from) that the registered application requires
        foreach($oauth2PermissionGrant in $applicationRegistration.oauth2PermissionGrants)
        {
            $resourceApplicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $oauth2PermissionGrant.resource
            foreach ($scope in $oauth2PermissionGrant.scope.Split(' '))
            {
                $params = @{
                    ClientApplicationId                 = $oauth2PermissionGrant.client
                    ResourceApplicationServicePrincipal = $resourceApplicationServicePrincipal
                    PermissionType                      = 'Delegated'
                    PermissionId                        = ($resourceApplicationServicePrincipal.oauth2Permissions | Where value -EQ $scope).id
                }
                $permissions += New-GraphPermissionDescription @params -LookupConsentStatus
            }
        }
    }

    # Show the user a display of the required permissions
    $permissions | Show-GraphApplicationPermissionDescriptions

    if ($permissions | Where isConsented -EQ $false | Select -First 1)
    {
        # Grant the required permissions to the corresponding applications
        $permissions | Where isConsented -EQ $false | Grant-GraphApplicationPermission
    }

    Write-Host "`r`nAll permissions required for registered Azure Stack applications or scenarios have been granted!" -ForegroundColor Green
}

Export-ModuleMember -Function @(
    "Register-AzsWithMyDirectoryTenant",
    "Register-AzsGuestDirectoryTenant",
    "Get-AzsDirectoryTenantidentifier",
    "New-AzsADGraphServicePrincipal"
)