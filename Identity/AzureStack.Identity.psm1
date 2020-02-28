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
        # The Authority of the identity system, e.g. "https://login.windows.net/microsoft.onmicrosoft.com"
        [Parameter(Mandatory = $true,
            Position = 0)]
        $Authority
    )

    return $(Invoke-RestMethod $("{0}/.well-known/openid-configuration" -f $authority.TrimEnd('/'))).issuer.TrimEnd('/').Split('/')[-1]
}

<#
   .Synopsis
      This function is used to create a Service Principal on the AD Graph in an AD FS topology
   .DESCRIPTION
      The command creates a certificate in the cert store of the local user and uses that certificate to create a Service Principal in the Azure Stack Stamp Active Directory.
   .EXAMPLE
      $servicePrincipal = New-AzsAdGraphServicePrincipal -DisplayName "myapp12" -AdminCredential $(Get-Credential) -Verbose
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

        # PEP Machine name        
        [string]
        $ERCSMachineName = "Azs-ERCS01",

        # Domain Administrator Credential to create Service Principal
        [Parameter(Mandatory = $true,
            Position = 2)]
        [System.Management.Automation.PSCredential]
        $AdminCredential
    )
    $ApplicationGroupName = $DisplayName
    $computerName = $ERCSMachineName
    $cloudAdminCredential = $AdminCredential
    $domainAdminSession = New-PSSession -ComputerName $computerName  -Credential $cloudAdminCredential -configurationname privilegedendpoint  -Verbose
    $GraphClientCertificate = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject "CN=$ApplicationGroupName" -KeySpec KeyExchange
    $graphRedirectUri = "https://localhost/".ToLowerInvariant()
    $ApplicationName = $ApplicationGroupName
    $application = Invoke-Command -Session $domainAdminSession -Verbose -ErrorAction Stop  `
        -ScriptBlock { New-GraphApplication -Name $using:ApplicationName  -ClientRedirectUris $using:graphRedirectUri -ClientCertificates $using:GraphClientCertificate }
    
    return $application
}

<#
   .Synopsis
      This function is used to initialize an Azure Resource Manager Environment for a given EnvironmentName and its ResourceManagerEndpoint 
   .DESCRIPTION
      Add an AzureRmEnvironment with a given EnvironmentName or retrieves an existing one 
   .EXAMPLE
      $azureEnvironment = Initialize-AzureRmEnvironment -EnvironmentName "AzureStack" -ResourceManagerEndpoint "https://adminmanagement.redmond.ext-v.masd.stbtest.microsoft.com"
#>
function Initialize-AzureRmEnvironment {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $EnvironmentName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $ResourceManagerEndpoint
    )
    $azureEnvironment = Add-AzureRmEnvironment -Name $EnvironmentName -ARMEndpoint $ResourceManagerEndpoint -ErrorAction Ignore
    $azureEnvironment = Get-AzureRmEnvironment -Name $environmentName -ErrorAction Stop
    return $azureEnvironment
}

<#
   .Synopsis
      This function is used to initialize an Azure Resource Manager Account for a given DirectoryTenant within a given AzureEnvironment
   .DESCRIPTION
      Create an Azure Resource Manager Account and select given subscription
   .EXAMPLE
      $azureAccount = Initialize-AzureRmUserAccount -AzureEnvironment $azureEnvironment -DirectoryTenantName "azurestacktest.onmicrosoft.com"
#>
function Initialize-AzureRmUserAccount {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$AzureEnvironment,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $DirectoryTenantName,

        # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [Parameter()]
        [String] $SubscriptionId = $null,

        # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [Parameter()]
        [String] $SubscriptionName = $null,

        [Parameter()]
        [PSCredential] $AutomationCredential = $null
    )
    # resolve the directory tenant ID from the name
    $directoryTenantId = (New-Object uri(Invoke-RestMethod "$($AzureEnvironment.ActiveDirectoryAuthority.TrimEnd('/'))/$DirectoryTenantName/.well-known/openid-configuration").token_endpoint).AbsolutePath.Split('/')[1]
    $params = @{
        EnvironmentName = $AzureEnvironment.Name
        TenantId        = $directoryTenantId
    }
    if ($AutomationCredential) { $params += @{ Credential = $AutomationCredential } }

    # Prompts the user for interactive login flow if automation credential is not specified
    $azureAccount = Add-AzureRmAccount @params

    if ($SubscriptionName) {
        Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
    } elseif ($SubscriptionId) {
        Select-AzureRmSubscription -SubscriptionId $SubscriptionId | Out-Null
    }

    return $azureAccount
}

function Get-RefreshToken {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$AzureEnvironment,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $DirectoryTenantName,

        [Parameter()]
        [PSCredential] $AutomationCredential = $null
    )

    $ErrorActionPreference='Stop'

    $authority = $AzureEnvironment.ActiveDirectoryAuthority.TrimEnd('/') + "/$DirectoryTenantName"
    $context = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new(
        $authority,
        ($validateAuthority=$true),
        [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::new())

    $result = if($automationCredential){
        $context.AcquireToken(
            ($resource=$AzureEnvironment.GraphEndpointResourceId),
            ($clientId='1950a258-227b-4e31-a9cf-717495945fc2'),
            ($userCredential=[Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential]::new($AutomationCredential.UserName, $AutomationCredential.Password)))
    } else {
        $context.AcquireToken(
            ($resource=$AzureEnvironment.GraphEndpointResourceId),
            ($clientId='1950a258-227b-4e31-a9cf-717495945fc2'),
            ($redirectUri='urn:ietf:wg:oauth:2.0:oob'))
    }
    return ($result.RefreshToken | ConvertTo-SecureString -AsPlainText -Force)
}

function Resolve-GraphEnvironment {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$ActiveDirectoryAuthority
    )
    $graphEnvironment = switch ($ActiveDirectoryAuthority) {
        'https://login.microsoftonline.com/' { 'AzureCloud' }
        'https://login.chinacloudapi.cn/' { 'AzureChinaCloud' }
        'https://login-us.microsoftonline.com/' { 'AzureUSGovernment' }
        'https://login.microsoftonline.us/' { 'AzureUSGovernment' }
        'https://login.microsoftonline.de/' { 'AzureGermanCloud' }
        Default { 'CustomCloud' }
    }
    return $graphEnvironment
}

function Get-ArmAccessToken([Microsoft.Azure.Commands.Profile.Models.PSAzureEnvironment]$azureStackEnvironment) {
    $armAccessToken = $null
    $attempts = 0
    $maxAttempts = 12
    $delayInSeconds = 5
    do {
        try {
            $attempts++
            $armAccessToken = (Get-GraphToken -Resource $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId -UseEnvironmentData -ErrorAction Stop).access_token
        }
        catch {
            if ($attempts -ge $maxAttempts) {
                throw
            }
            Write-Verbose "Error attempting to acquire ARM access token: $_`r`n$($_.Exception)" -Verbose
            Write-Verbose "Delaying for $delayInSeconds seconds before trying again... (attempt $attempts/$maxAttempts)" -Verbose
            Start-Sleep -Seconds $delayInSeconds
        }
    }
    while (-not $armAccessToken)

    return $armAccessToken
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
        [ValidateScript( { $_.Scheme -eq [System.Uri]::UriSchemeHttps })]
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
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Location,

        # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNull()]
        [string] $SubscriptionId = $null,

        # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [ValidateNotNull()]
        [string] $SubscriptionName = $null,

        # The name of the resource group in which the directory tenant registration resource should be created (resource group must already exist).
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName = $null,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    Import-Module 'AzureRm.Profile' -Verbose:$false 4> $null

    # Initialize the Azure PowerShell module to communicate with Azure Stack. Will prompt user for credentials.
    $azureEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStackAdmin' -ResourceManagerEndpoint $AdminResourceManagerEndpoint
    $azureAccount = Initialize-AzureRmUserAccount -AzureEnvironment $azureEnvironment -DirectoryTenantName $DirectoryTenantName -SubscriptionId $SubscriptionId -SubscriptionName $SubscriptionName -AutomationCredential $AutomationCredential

    foreach ($directoryTenantName in $GuestDirectoryTenantName) {
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
        
        # Check if resource group exists, create it if it doesn't
        $rg = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue
        if ($rg -eq $null) {
            New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue | Out-Null
        }
        
        $directoryTenant = New-AzureRmResource @params -Force -Verbose -ErrorAction Stop
        Write-Verbose -Message "Directory Tenant onboarded: $(ConvertTo-Json $directoryTenant)" -Verbose
    }
}

<#
.Synopsis
Gets the health report of identity application in the Azure Stack home and guest directories
.DESCRIPTION
Gets the health report for Azure Stack identity applications in the home directory as well as guest directories of Azure Stack. Any directories with an unhealthy status need to have their permissions updated.
.EXAMPLE
$adminResourceManagerEndpoint = "https://adminmanagement.local.azurestack.external"
$homeDirectoryTenantName = "<homeDirectoryTenant>.onmicrosoft.com"

Get-AzsHealthReport -AdminResourceManagerEndpoint $adminResourceManagerEndpoint `
    -DirectoryTenantName $homeDirectoryTenantName -Verbose
#>

function Get-AzsHealthReport {
    [CmdletBinding()]
    param
    (
        # The endpoint of the Azure Stack Resource Manager service.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateScript( { $_.Scheme -eq [System.Uri]::UriSchemeHttps })]
        [uri] $AdminResourceManagerEndpoint,

        # The name of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantName,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    # Install-Module AzureRm
    Import-Module 'AzureRm.Profile' -Verbose:$false 4> $null
    Import-Module "$PSScriptRoot\GraphAPI\GraphAPI.psm1" -Verbose:$false 4> $null

    function Invoke-Main {
        # Initialize the Azure PowerShell module to communicate with the Azure Resource Manager in the public cloud corresponding to the Azure Stack Graph Service. Will prompt user for credentials.
        Write-Host "Authenticating user..."
        $azureStackEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStackAdmin' -ResourceManagerEndpoint $AdminResourceManagerEndpoint
        $refreshToken = Get-RefreshToken -AzureEnvironment $azureStackEnvironment -DirectoryTenantName $DirectoryTenantName -AutomationCredential $AutomationCredential

        # Initialize the Graph PowerShell module to communicate with the correct graph service
        $graphEnvironment = Resolve-GraphEnvironment -ActiveDirectoryAuthority $azureStackEnvironment.ActiveDirectoryAuthority
        Initialize-GraphEnvironment -Environment $graphEnvironment -DirectoryTenantId $DirectoryTenantName -RefreshToken $refreshToken -CustomCloudARMEndpoint $AdminResourceManagerEndpoint

        # Call Azure Stack Resource Manager to retrieve the list of registered applications which need to be initialized in the onboarding directory tenant
        Write-Host "Acquiring an access token to communicate with Resource Manager..."
        $armAccessToken = Get-ArmAccessToken $azureStackEnvironment
        
        $defaultProviderSubscription = Get-AzureRmSubscription -SubscriptionName "Default Provider Subscription"
        $healthReportUrl = "$($AdminResourceManagerEndpoint.AbsoluteUri)/subscriptions/$($defaultProviderSubscription.SubscriptionId)/providers/Microsoft.Subscriptions.Admin/checkIdentityHealth?api-version=2018-05-01"
        $headers = @{ "Authorization" = "Bearer $armAccessToken" }

        $healthReport = (Invoke-WebRequest -Headers $headers -Uri $healthReportUrl -Method Post -UseBasicParsing -TimeoutSec 40).Content | ConvertFrom-Json

        return $healthReport
    }

    $logFile = Join-Path -Path $PSScriptRoot -ChildPath "$DirectoryTenantName.$(Get-Date -Format MM-dd_HH-mm-ss_ms).log"
    Write-Verbose "Logging additional information to log file '$logFile'" -Verbose

    $logStartMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Beginning invocation of '$($MyInvocation.InvocationName)' with parameters: $(ConvertTo-Json $PSBoundParameters -Depth 4)"
    $logStartMessage >> $logFile

    try {
        # Redirect verbose output to a log file
        Invoke-Main 4>> $logFile

        $logEndMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Script completed successfully."
        $logEndMessage >> $logFile
    }
    catch {
        $logErrorMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Script terminated with error: $_`r`n$($_.Exception)"
        $logErrorMessage >> $logFile
        Write-Warning "An error has occurred; more information may be found in the log file '$logFile'" -WarningAction Continue
        throw
    }
}

<#
.Synopsis
Consents to any missing permissions for Azure Stack identity applications in the home directory of Azure Stack.
.DESCRIPTION
Consents to any missing permissions for Azure Stack identity applications in the home directory of Azure Stack. This is needed to complete the "installation" of new Resource Provider identity applications in Azure Stack. 
.EXAMPLE
$adminResourceManagerEndpoint = "https://adminmanagement.local.azurestack.external"
$homeDirectoryTenantName = "<homeDirectoryTenant>.onmicrosoft.com"

Update-AzsHomeDirectoryTenant -AdminResourceManagerEndpoint $adminResourceManagerEndpoint `
    -DirectoryTenantName $homeDirectoryTenantName -Verbose
#>

function Update-AzsHomeDirectoryTenant {
    [CmdletBinding()]
    param
    (
        # The endpoint of the Azure Stack Resource Manager service.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateScript( { $_.Scheme -eq [System.Uri]::UriSchemeHttps })]
        [uri] $AdminResourceManagerEndpoint,

        # The name of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantName,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    Import-Module 'AzureRm.Profile' -Verbose:$false 4> $null
    Import-Module "$PSScriptRoot\GraphAPI\GraphAPI.psm1" -Verbose:$false 4> $null

    function Invoke-Main {
        # Initialize the Azure PowerShell module to communicate with the Azure Resource Manager in the public cloud corresponding to the Azure Stack Graph Service. Will prompt user for credentials.
        Write-Host "Authenticating user..."
        $azureStackEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStackAdmin' -ResourceManagerEndpoint $AdminResourceManagerEndpoint
        $refreshToken = Get-RefreshToken -AzureEnvironment $azureStackEnvironment -DirectoryTenantName $DirectoryTenantName -AutomationCredential $AutomationCredential

        # Initialize the Graph PowerShell module to communicate with the correct graph service
        $graphEnvironment = Resolve-GraphEnvironment -ActiveDirectoryAuthority $azureStackEnvironment.ActiveDirectoryAuthority
        Initialize-GraphEnvironment -Environment $graphEnvironment -DirectoryTenantId $DirectoryTenantName -RefreshToken $refreshToken -CustomCloudARMEndpoint $AdminResourceManagerEndpoint

        # Call Azure Stack Resource Manager to retrieve the list of registered applications which need to be initialized in the onboarding directory tenant
        Write-Host "Acquiring an access token to communicate with Resource Manager..."
        $armAccessToken = Get-ArmAccessToken $azureStackEnvironment

        Write-Host "Looking-up the registered identity applications which need to be installed in your directory..."
        $applicationRegistrationParams = @{
            Method  = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
            Headers = @{ Authorization = "Bearer $armAccessToken" }
            Uri     = "$($AdminResourceManagerEndpoint.ToString().TrimEnd('/'))/applicationRegistrations?api-version=2014-04-01-preview"
        }
        $applicationRegistrations = Invoke-RestMethod @applicationRegistrationParams | Select -ExpandProperty value

        # Identify which permissions have already been granted to each registered application and which additional permissions need to be granted
        $permissions = @()
        $count = 0
        foreach ($applicationRegistration in $applicationRegistrations) {
            # Initialize the service principal for the registered application
            $count++
            $applicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $applicationRegistration.appId
            Write-Host "Installing Application... ($($count) of $($applicationRegistrations.Count)): $($applicationServicePrincipal.appId) '$($applicationServicePrincipal.appDisplayName)'"

            # WORKAROUND - the recent Azure Stack update has a missing permission registration; temporarily "inject" this permission registration into the returned data
            if ($applicationServicePrincipal.servicePrincipalNames | Where { $_ -like 'https://deploymentprovider.*/*' }) {
                Write-Verbose "Adding missing permission registrations for application '$($applicationServicePrincipal.appDisplayName)' ($($applicationServicePrincipal.appId))..." -Verbose

                $graph = Get-GraphApplicationServicePrincipal -ApplicationId (Get-GraphEnvironmentInfo).Applications.WindowsAzureActiveDirectory.Id

                $applicationRegistration.appRoleAssignments = @(
                    [pscustomobject]@{
                        resource = (Get-GraphEnvironmentInfo).Applications.WindowsAzureActiveDirectory.Id
                        client   = $applicationRegistration.appId
                        roleId   = $graph.appRoles | Where value -EQ 'Directory.Read.All' | Select -ExpandProperty id
                    },

                    [pscustomobject]@{
                        resource = (Get-GraphEnvironmentInfo).Applications.WindowsAzureActiveDirectory.Id
                        client   = $applicationRegistration.appId
                        roleId   = $graph.appRoles | Where value -EQ 'Application.ReadWrite.OwnedBy' | Select -ExpandProperty id
                    }
                )
            }

            # Initialize the necessary tags for the registered application
            if ($applicationRegistration.tags) {
                Update-GraphApplicationServicePrincipalTags -ApplicationId $applicationRegistration.appId -Tags $applicationRegistration.tags
            }

            # Lookup the permission consent status for the *application* permissions (either to or from) which the registered application requires
            foreach ($appRoleAssignment in $applicationRegistration.appRoleAssignments) {
                $params = @{
                    ClientApplicationId   = $appRoleAssignment.client
                    ResourceApplicationId = $appRoleAssignment.resource
                    PermissionType        = 'Application'
                    PermissionId          = $appRoleAssignment.roleId
                }
                $permissions += New-GraphPermissionDescription @params -LookupConsentStatus
            }

            # Lookup the permission consent status for the *delegated* permissions (either to or from) which the registered application requires
            foreach ($oauth2PermissionGrant in $applicationRegistration.oauth2PermissionGrants) {
                $resourceApplicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $oauth2PermissionGrant.resource
                foreach ($scope in $oauth2PermissionGrant.scope.Split(' ')) {
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

        # Trace the permission status
        Write-Verbose "Current permission status: $($permissions | ConvertTo-Json -Depth 4)" -Verbose

        $permissionFile = Join-Path -Path $PSScriptRoot -ChildPath "$DirectoryTenantName.permissions.json"
        $permissionContent = $permissions | Select -Property * -ExcludeProperty isConsented | ConvertTo-Json -Depth 4 | Out-String
        $permissionContent > $permissionFile

        # Display application status to user
        $permissionsByClient = $permissions | Select *, @{n = 'Client'; e = { '{0} {1}' -f $_.clientApplicationId, $_.clientApplicationDisplayName } } | Sort clientApplicationDisplayName | Group Client
        $readyApplications = @()
        $pendingApplications = @()
        foreach ($client in $permissionsByClient) {
            if ($client.Group.isConsented -Contains $false) {
                $pendingApplications += $client
            }
            else {
                $readyApplications += $client
            }
        }

        Write-Host ""
        if ($readyApplications) {
            Write-Host "Applications installed and configured:"
            Write-Host "`t$($readyApplications.Name -join "`r`n`t")"
        }
        if ($readyApplications -and $pendingApplications) {
            Write-Host ""
        }
        if ($pendingApplications) {
            Write-Host "Applications waiting to be configured:"
            Write-Host "`t$($pendingApplications.Name -join "`r`n`t")"
        }
        Write-Host ""

        # Grant any missing permissions for registered applications
        if ($permissions | Where isConsented -EQ $false | Select -First 1) {
            Write-Host "Configuring applications... (this may take up to a few minutes to complete)"
            Write-Host ""
            $permissions | Where isConsented -EQ $false | Grant-GraphApplicationPermission
        }

        Write-Host "All applications installed and configured! Your home directory '$DirectoryTenantName' has been successfully updated to be used with Azure Stack!"
        Write-Host ""
        Write-Host "A more detailed description of the applications installed and with what permissions they have been configured can be found in the file '$permissionFile'."
        Write-Host "Run this script again at any time to check the status of the Azure Stack applications in your directory."
        Write-Warning "If your Azure Stack Administrator installs new services or updates in the future, you may need to run this script again."
    }

    $logFile = Join-Path -Path $PSScriptRoot -ChildPath "$DirectoryTenantName.$(Get-Date -Format MM-dd_HH-mm-ss_ms).log"
    Write-Verbose "Logging additional information to log file '$logFile'" -Verbose

    $logStartMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Beginning invocation of '$($MyInvocation.InvocationName)' with parameters: $(ConvertTo-Json $PSBoundParameters -Depth 4)"
    $logStartMessage >> $logFile

    try {
        # Redirect verbose output to a log file
        Invoke-Main 4>> $logFile

        $logEndMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Script completed successfully."
        $logEndMessage >> $logFile
    }
    catch {
        $logErrorMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Script terminated with error: $_`r`n$($_.Exception)"
        $logErrorMessage >> $logFile
        Write-Warning "An error has occurred; more information may be found in the log file '$logFile'" -WarningAction Continue
        throw
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
        [ValidateScript( { $_.Scheme -eq [System.Uri]::UriSchemeHttps })]
        [uri] $TenantResourceManagerEndpoint,

        # The name of the directory tenant being onboarded.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantName,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    Import-Module 'AzureRm.Profile' -Verbose:$false 4> $null
    Import-Module "$PSScriptRoot\GraphAPI\GraphAPI.psm1" -Verbose:$false 4> $null

    function Invoke-Main {
        # Initialize the Azure PowerShell module to communicate with the Azure Resource Manager in the public cloud corresponding to the Azure Stack Graph Service. Will prompt user for credentials.
        Write-Host "Authenticating user..."
        $azureStackEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStack' -ResourceManagerEndpoint $TenantResourceManagerEndpoint
        $refreshToken = Get-RefreshToken -AzureEnvironment $azureStackEnvironment -DirectoryTenantName $DirectoryTenantName -AutomationCredential $AutomationCredential

        # Initialize the Graph PowerShell module to communicate with the correct graph service
        $graphEnvironment = Resolve-GraphEnvironment -ActiveDirectoryAuthority $azureStackEnvironment.ActiveDirectoryAuthority
        Initialize-GraphEnvironment -Environment $graphEnvironment -DirectoryTenantId $DirectoryTenantName -RefreshToken $refreshToken -CustomCloudARMEndpoint $TenantResourceManagerEndpoint

        # Initialize the service principal for the Azure Stack Resource Manager application
        Write-Host "Installing Resource Manager in your directory ('$DirectoryTenantName')..."
        $resourceManagerServicePrincipal = Initialize-ResourceManagerServicePrincipal

        # Authorize the Azure Powershell module to act as a client to call the Azure Stack Resource Manager in the onboarding directory tenant
        Write-Host "Authorizing the Azure PowerShell module to communicate with Resource Manager in your directory..."
        Initialize-GraphOAuth2PermissionGrant -ClientApplicationId (Get-GraphEnvironmentInfo).Applications.PowerShell.Id -ResourceApplicationIdentifierUri $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId

        # Call Azure Stack Resource Manager to retrieve the list of registered applications which need to be initialized in the onboarding directory tenant
        Write-Host "Acquiring an access token to communicate with Resource Manager... (this may take up to a few minutes to complete)"
        $armAccessToken = Get-ArmAccessToken $azureStackEnvironment

        Write-Host "Looking-up the registered identity applications which need to be installed in your directory..."
        $applicationRegistrationParams = @{
            Method  = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
            Headers = @{ Authorization = "Bearer $armAccessToken" }
            Uri     = "$($TenantResourceManagerEndpoint.ToString().TrimEnd('/'))/applicationRegistrations?api-version=2014-04-01-preview"
        }
        $applicationRegistrations = Invoke-RestMethod @applicationRegistrationParams | Select -ExpandProperty value

        # Identify which permissions have already been granted to each registered application and which additional permissions need to be granted
        $permissions = @()
        $count = 0
        foreach ($applicationRegistration in $applicationRegistrations) {
            # Initialize the service principal for the registered application
            $count++
            $applicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $applicationRegistration.appId
            Write-Host "Installing Application... ($($count) of $($applicationRegistrations.Count)): $($applicationServicePrincipal.appId) '$($applicationServicePrincipal.appDisplayName)'"

            # Initialize the necessary tags for the registered application
            if ($applicationRegistration.tags) {
                Update-GraphApplicationServicePrincipalTags -ApplicationId $applicationRegistration.appId -Tags $applicationRegistration.tags
            }

            # Lookup the permission consent status for the *application* permissions (either to or from) which the registered application requires
            foreach ($appRoleAssignment in $applicationRegistration.appRoleAssignments) {
                $params = @{
                    ClientApplicationId   = $appRoleAssignment.client
                    ResourceApplicationId = $appRoleAssignment.resource
                    PermissionType        = 'Application'
                    PermissionId          = $appRoleAssignment.roleId
                }
                $permissions += New-GraphPermissionDescription @params -LookupConsentStatus
            }

            # Lookup the permission consent status for the *delegated* permissions (either to or from) which the registered application requires
            foreach ($oauth2PermissionGrant in $applicationRegistration.oauth2PermissionGrants) {
                $resourceApplicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $oauth2PermissionGrant.resource
                foreach ($scope in $oauth2PermissionGrant.scope.Split(' ')) {
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

        # Trace the permission status
        Write-Verbose "Current permission status: $($permissions | ConvertTo-Json -Depth 4)" -Verbose

        $permissionFile = Join-Path -Path $PSScriptRoot -ChildPath "$DirectoryTenantName.permissions.json"
        $permissionContent = $permissions | Select -Property * -ExcludeProperty isConsented | ConvertTo-Json -Depth 4 | Out-String
        $permissionContent > $permissionFile

        # Display application status to user
        $permissionsByClient = $permissions | Select *, @{n = 'Client'; e = { '{0} {1}' -f $_.clientApplicationId, $_.clientApplicationDisplayName } } | Sort clientApplicationDisplayName | Group Client
        $readyApplications = @()
        $pendingApplications = @()
        foreach ($client in $permissionsByClient) {
            if ($client.Group.isConsented -Contains $false) {
                $pendingApplications += $client
            }
            else {
                $readyApplications += $client
            }
        }

        Write-Host ""
        if ($readyApplications) {
            Write-Host "Applications installed and configured:"
            Write-Host "`t$($readyApplications.Name -join "`r`n`t")"
        }
        if ($readyApplications -and $pendingApplications) {
            Write-Host ""
        }
        if ($pendingApplications) {
            Write-Host "Applications waiting to be configured:"
            Write-Host "`t$($pendingApplications.Name -join "`r`n`t")"
        }
        Write-Host ""

        # Grant any missing permissions for registered applications
        if ($permissions | Where isConsented -EQ $false | Select -First 1) {
            Write-Host "Configuring applications... (this may take up to a few minutes to complete)"
            Write-Host ""
            $permissions | Where isConsented -EQ $false | Grant-GraphApplicationPermission
        }

        Write-Host "All applications installed and configured! Your directory '$DirectoryTenantName' has been successfully onboarded and can now be used with Azure Stack!"
        Write-Host ""
        Write-Host "A more detailed description of the applications installed and with what permissions they have been configured can be found in the file '$permissionFile'."
        Write-Host "Run this script again at any time to check the status of the Azure Stack applications in your directory."
        Write-Warning "If your Azure Stack Administrator installs new services or updates in the future, you may need to run this script again."
    }

    function Initialize-ResourceManagerServicePrincipal {
        $identityInfo = Invoke-RestMethod -Method Get -Uri "$($TenantResourceManagerEndpoint.ToString().TrimEnd('/'))/metadata/identity?api-version=2015-01-01" -Verbose
        Write-Verbose -Message "Resource Manager identity information: $(ConvertTo-Json $identityInfo)" -Verbose

        $resourceManagerServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $identityInfo.applicationId -Verbose

        return $resourceManagerServicePrincipal
    }

    $logFile = Join-Path -Path $PSScriptRoot -ChildPath "$DirectoryTenantName.$(Get-Date -Format MM-dd_HH-mm-ss_ms).log"
    Write-Verbose "Logging additional information to log file '$logFile'" -Verbose

    $logStartMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Beginning invocation of '$($MyInvocation.InvocationName)' with parameters: $(ConvertTo-Json $PSBoundParameters -Depth 4)"
    $logStartMessage >> $logFile

    try {
        # Redirect verbose output to a log file
        Invoke-Main 4>> $logFile

        $logEndMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Script completed successfully."
        $logEndMessage >> $logFile
    }
    catch {
        $logErrorMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Script terminated with error: $_`r`n$($_.Exception)"
        $logErrorMessage >> $logFile
        Write-Warning "An error has occurred; more information may be found in the log file '$logFile'" -WarningAction Continue
        throw
    }
}

<#
.Synopsis
Removes a Guest Directory Tenant from Azure Stack.
.DESCRIPTION
Running this cmdlet will remove the specified directory tenant from the Azure Stack whitelist.
Ensure an Admin of the directory tenant has already run "Unregister-AzsWithMyDirectoryTenant" or they will be unable to
complete that cleanup of their directory tenant (this cmdlet will remove the permissions they need to query Azure Stack to determine what to delete).
.EXAMPLE
$adminARMEndpoint = "https://adminmanagement.local.azurestack.external"
$azureStackDirectoryTenant = "<homeDirectoryTenant>.onmicrosoft.com"
$guestDirectoryTenantToBeOnboarded = "<guestDirectoryTenant>.onmicrosoft.com"

Unregister-AzsGuestDirectoryTenant -AdminResourceManagerEndpoint $adminARMEndpoint -DirectoryTenantName $azureStackDirectoryTenant -GuestDirectoryTenantName $guestDirectoryTenantToBeOnboarded
#>

function Unregister-AzsGuestDirectoryTenant {
    [CmdletBinding()]
    param
    (
        # The endpoint of the Azure Stack Resource Manager service.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateScript( { $_.Scheme -eq [System.Uri]::UriSchemeHttps })]
        [uri] $AdminResourceManagerEndpoint,

        # The name of the home Directory Tenant in which the Azure Stack Administrator subscription resides.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantName,

        # The name of the guest Directory Tenant which is to be decommissioned.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $GuestDirectoryTenantName,

        # The name of the resource group in which the directory tenant resource was created.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName = $null,

        # The identifier of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [Parameter()]
        [ValidateNotNull()]
        [string] $SubscriptionId = $null,

        # The display name of the Administrator Subscription. If not specified, the script will attempt to use the set default subscription.
        [Parameter()]
        [ValidateNotNull()]
        [string] $SubscriptionName = $null,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    $ResourceManagerEndpoint = $AdminResourceManagerEndpoint

    Import-Module 'AzureRm.Profile' -Verbose:$false 4> $null

    function Invoke-Main {
        Write-DecommissionImplicationsWarning

        # Initialize the Azure PowerShell module to communicate with Azure Stack. Will prompt user for credentials.
        $azureEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStackAdmin' -ResourceManagerEndpoint $AdminResourceManagerEndpoint
        $azureAccount = Initialize-AzureRmUserAccount -AzureEnvironment $azureEnvironment -DirectoryTenantName $DirectoryTenantName -SubscriptionId $SubscriptionId -SubscriptionName $SubscriptionName -AutomationCredential $AutomationCredential

        # Remove the new directory tenant to the Azure Stack deployment
        $params = @{
            ResourceId = "/subscriptions/$($azureAccount.Context.Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Subscriptions.Admin/directoryTenants/$GuestDirectoryTenantName"
            ApiVersion = '2015-11-01'
        }
        $output = Remove-AzureRmResource @params -Force -Verbose -ErrorAction Stop
        Write-Verbose -Message "Directory Tenant decommissioned: $($params.ResourceId)" -Verbose
    }

    function Write-DecommissionImplicationsWarning {
        $params = @{
            Message       = ''
            WarningAction = 'Inquire'
        }
        $params.Message += 'You are removing a directory tenant from your Azure Stack deployment.'
        $params.Message += ' Users in this directory will be unable to access or manage any existing subscriptions (access to any existing resources may be impaired if they require identity integration).'
        $params.Message += " Additionally, you should first ensure that an Administrator of the directory '$directoryTenantName' has completed their decommissioning process before removing this access"
        $params.Message += ' (they will need to query your Azure Stack deployment to see which identities need to be removed from their directory).'

        if ($AutomationCredential) {
            $params.WarningAction = 'Continue'
        }
        else {
            $params.Message += " Would you like to proceed?"
        }

        Write-Warning @params
    }

    Invoke-Main
}

<#
.Synopsis
Removes the installed Azure Stack identity applications and their permissions within the callers's Azure Directory Tenant.
.DESCRIPTION
Removes the installed Azure Stack identity applications and their permissions within the callers's Azure Directory Tenant.
.EXAMPLE
$tenantARMEndpoint = "https://management.local.azurestack.external"
$myDirectoryTenantName = "<guestDirectoryTenant>.onmicrosoft.com"

Unregister-AzsWithMyDirectoryTenant -TenantResourceManagerEndpoint $tenantARMEndpoint `
    -DirectoryTenantName $myDirectoryTenantName -Verbose -Debug
#>

function Unregister-AzsWithMyDirectoryTenant {
    [CmdletBinding()]
    param
    (
        # The endpoint of the Azure Stack Resource Manager service.
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateScript( { $_.Scheme -eq [System.Uri]::UriSchemeHttps })]
        [uri] $TenantResourceManagerEndpoint,

        # The name of the directory tenant being onboarded.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantName,

        # Optional: A credential used to authenticate with Azure Stack. Must support a non-interactive authentication flow. If not provided, the script will prompt for user credentials.
        [Parameter()]
        [ValidateNotNull()]
        [pscredential] $AutomationCredential = $null
    )

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    $ResourceManagerEndpoint = $TenantResourceManagerEndpoint
    
    Import-Module 'AzureRm.Profile' -Verbose:$false 4> $null
    Import-Module "$PSScriptRoot\GraphAPI\GraphAPI.psm1" -Verbose:$false 4> $null
    
    function Invoke-Main {
        Write-DecommissionImplicationsWarning
    
        # Initialize the Azure PowerShell module to communicate with the Azure Resource Manager in the public cloud corresponding to the Azure Stack Graph Service. Will prompt user for credentials.
        Write-Host "Authenticating user..."
        $azureStackEnvironment = Initialize-AzureRmEnvironment -EnvironmentName 'AzureStack' -ResourceManagerEndpoint $TenantResourceManagerEndpoint
        $refreshToken = Get-RefreshToken -AzureEnvironment $azureStackEnvironment -DirectoryTenantName $DirectoryTenantName -AutomationCredential $AutomationCredential
    
        # Initialize the Graph PowerShell module to communicate with the correct graph service
        $graphEnvironment = Resolve-GraphEnvironment -ActiveDirectoryAuthority $azureStackEnvironment.ActiveDirectoryAuthority
        Initialize-GraphEnvironment -Environment $graphEnvironment -DirectoryTenantId $DirectoryTenantName -RefreshToken $refreshToken -CustomCloudARMEndpoint $TenantResourceManagerEndpoint
    
        # Call Azure Stack Resource Manager to retrieve the list of registered applications which need to be removed from the directory tenant
        Write-Host "Acquiring an access token to communicate with Resource Manager... (if you already decommissioned this directory you may get an error here which you can ignore)"
        $armAccessToken = (Get-GraphToken -Resource $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId -UseEnvironmentData -ErrorAction Stop).access_token
    
        Write-Host "Looking-up the registered identity applications which need to be uninstalled from your directory..."
        $applicationRegistrationParams = @{
            Method  = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
            Headers = @{ Authorization = "Bearer $armAccessToken" }
            Uri     = "$($ResourceManagerEndpoint.ToString().TrimEnd('/'))/applicationRegistrations?api-version=2014-04-01-preview"
        }
        $applicationRegistrations = Invoke-RestMethod @applicationRegistrationParams | Select -ExpandProperty value
    
        # Delete the service principals for the registered applications
        foreach ($applicationRegistration in $applicationRegistrations) {
            if (($applicationServicePrincipal = Get-GraphApplicationServicePrincipal -ApplicationId $applicationRegistration.appId -ErrorAction Continue)) {
                Write-Verbose "Uninstalling service principal: $(ConvertTo-Json $applicationServicePrincipal)" -Verbose
                Remove-GraphObject -objectId $applicationServicePrincipal.objectId
                Write-Host "Application '$($applicationServicePrincipal.appId)' ($($applicationServicePrincipal.appDisplayName)) was successfully uninstalled from your directory."
            }
            else {
                Write-Host "Application '$($applicationRegistration.appId)' is not installed or was already successfully uninstalled from your directory."
            }
        }
    
        Write-Host "All Azure Stack applications have been uninstalled! Your directory '$DirectoryTenantName' has been successfully decommissioned and can no-longer be used with Azure Stack."
    }
    
    function Write-DecommissionImplicationsWarning {
        $params = @{
            Message       = ''
            WarningAction = 'Inquire'
        }
        $params.Message += 'You are removing access from an Azure Stack deployment to your directory tenant.'
        $params.Message += ' Users in your directory will be unable to access or manage any existing subscriptions in the Azure Stack deployment (access to any existing resources may be impaired if they require identity integration).'
    
        if ($AutomationCredential) {
            $params.WarningAction = 'Continue'
        }
        else {
            $params.Message += " Would you like to proceed?"
        }
    
        Write-Warning @params
    }
    
    $logFile = Join-Path -Path $PSScriptRoot -ChildPath "$DirectoryTenantName.$(Get-Date -Format MM-dd_HH-mm-ss_ms).log"
    Write-Verbose "Logging additional information to log file '$logFile'" -Verbose
    
    $logStartMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Beginning invocation of '$($MyInvocation.InvocationName)' with parameters: $(ConvertTo-Json $PSBoundParameters -Depth 4)"
    $logStartMessage >> $logFile
    
    try {
        # Redirect verbose output to a log file
        Invoke-Main 4>> $logFile
    
        $logEndMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Script completed successfully."
        $logEndMessage >> $logFile
    }
    catch {
        $logErrorMessage = "[$(Get-Date -Format 'hh:mm:ss tt')] - Script terminated with error: $_`r`n$($_.Exception)"
        $logErrorMessage >> $logFile
        Write-Warning "An error has occurred; more information may be found in the log file '$logFile'" -WarningAction Continue
        throw
    }
}

Export-ModuleMember -Function @(
    "Register-AzsGuestDirectoryTenant",
    "Update-AzsHomeDirectoryTenant",
    "Register-AzsWithMyDirectoryTenant",
    "Unregister-AzsGuestDirectoryTenant",
    "Unregister-AzsWithMyDirectoryTenant",
    "Get-AzsDirectoryTenantidentifier",
    "Get-AzsHealthReport",
    "New-AzsADGraphServicePrincipal"
)
