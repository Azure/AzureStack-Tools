<#
.SYNOPSIS

TDB

.NOTES

You need to have Global Admin permissions in the given directory tenant in order to be able to successfully perform the import oepration.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="TBD")]
    [string]$ResourceManager = "https://management.local.azurestack.external/",

    [Parameter(Mandatory=$false, HelpMessage="TBD")]
    [string]$ActiveDirectoryTenant = "redmarker.onmicrosoft.com",

    [Parameter(Mandatory=$false, HelpMessage="Azure environment name.")]
    [String]$Environment = "AzureCloud"
)

# auto-discovery helper
function AutoDiscovery() {
    # Load auto-discovery endpoints from Resource Manager and inject Resource Manager uri into the data received,
    # so we have all the endpoints in the same collection.
    return Invoke-RestMethod -Uri "$($ResourceManager)/metadata/endpoints?api-version=1.0"
}

# Load auto-discovery endpoints from Resource Manager
$endpoints = AutoDiscovery

$my_environment = @{
    'AzureCloud' = @{
        'Microsoft.Graph' = @{
            QueryString = @{ "api-version" = "1.6" }
            Resource = "https://graph.windows.net/"
            Endpoint = "https://graph.windows.net/$ActiveDirectoryTenant/"
            AuthSession = @{}
        };

        'Microsoft.AzureActiveDirectory' = @{
            Headers = @{ }
            Endpoint = "https://login.windows.net/$ActiveDirectoryTenant"
        };
    }
    'MyAzureStack' = @{
        'Microsoft.ResourceManager' = @{
            Headers = @{ }
            QueryString = @{ "api-version" = "2014-04-01-preview" }
            Endpoint = $ResourceManager
            Resource = $endpoints.authentication.audiences[0]
            AuthSession = @{}
        };
    }
}

<#
.Synopsis
   Formats the provided query string parameters into a URL-encoded query string format.
#>
function ConvertTo-QueryString
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [HashTable] $QueryParameters = @{}
    )

    $query = [System.Web.HttpUtility]::ParseQueryString("?")
    $QueryParameters.GetEnumerator() | ForEach { $query.Add($_.Key, $_.Value) }
    Write-Output $query.ToString()
}

function Set-AuthSession
{
    [CmdletBinding()]
    param($Service, $Session)
    # pin the session
    $Service.AuthSession = $Session
    # update headers
    $Service.Headers += @{
        "Authorization" = ("Bearer {0}" -f $Session.access_token)
    }
}

function ConnectTo-Service()
{
    [CmdletBinding()]
    param(
        # The user credential with which to acquire an access token targeting Graph.
        [ValidateNotNull()]
        [pscredential] $SignInAs,

        [ValidateNotNull()]
        $Service,

        [ValidateNotNull()]
        $Via
    )
    # initial setup of the payload
    $requestBody = @{
        client_id = "1950a258-227b-4e31-a9cf-717495945fc2"
        scope     = "openid"
        resource  = $Service.Resource
    }

    # configure the request as user credentials flow
    if ($SignInAs)
    {
        $requestBody += @{
            grant_type = "password"
            username   = $SignInAs.UserName
            password   = $SignInAs.GetNetworkCredential().Password
        }

        Write-Verbose "Attempting to acquire a token for resource '$($requestBody.resource)' using a user credential '$($requestBody.username)'"
    }

    # Build request headers
    $headers = @{ "User-Agent" = "Microsoft AzureStack Graph PowerShell" }

    # Initialize the request parameters
    $request = @{
        Method      = "POST"
        Uri         = "{0}/oauth2/token" -f $Via.Endpoint.TrimEnd("/")
        Headers     = $headers
        ContentType = "application/x-www-form-urlencoded"
        Body        = ConvertTo-QueryString $requestBody
    }

    # Make the API call, and auto-follow / aggregate next-link responses
    try
    {
        # invoke & parse
        $response = Invoke-WebRequest @request -UseBasicParsing -ErrorAction Stop
        $session = $response.Content | ConvertFrom-Json
        # save auth session for the given service
        Set-AuthSession -Service $Service -Session $session
    }
    catch
    {
        # In the case of errors, there is no response returned to caller (even when error action is set to ignore, continue, etc.) so we extract the response from the thrown exception (if there is one)
        $traceResponse = $_.Exception.Response | Select Method,ResponseUri,StatusCode,StatusDescription,IsFromCache,LastModified | ConvertTo-Json

        # Trace the message to verbose stream as well in case error is not traced in same file as other verbose logs
        $traceMessage = "An error occurred while trying to make a graph API call: $_`r`n`r`nAdditional details: $traceResponse"
        Write-Verbose "ERROR: $traceMessage"

        throw New-Object System.InvalidOperationException($traceMessage)
    }
}

function GetFrom-Service()
{
    [CmdletBinding()]
    param($Service, $Path)

    # build request headers
    $headers = $Service.Headers
    $headers += @{ "User-Agent" = "Microsoft AzureStack Graph PowerShell" }
    # build query string
    $queryString = ConvertTo-QueryString $Service.QueryString

    # Initialize the request parameters
    $request = @{
        Method      = "GET"
        Uri         = "{0}/{1}?{2}" -f $Service.Endpoint.TrimEnd("/"), $Path.TrimStart("/"), $queryString
        Headers     = $headers
        ContentType = "application/json"
    }

    # Make the API call, and auto-follow / aggregate next-link responses
    try
    {
        $response = Invoke-WebRequest @request -UseBasicParsing -ErrorAction Stop
        return $response.Content | ConvertFrom-Json
    }
    catch
    {
        # In the case of errors, there is no response returned to caller (even when error action is set to ignore, continue, etc.) so we extract the response from the thrown exception (if there is one)
        $traceResponse = $_.Exception.Response | Select Method,ResponseUri,StatusCode,StatusDescription,IsFromCache,LastModified | ConvertTo-Json

        # Trace the message to verbose stream as well in case error is not traced in same file as other verbose logs
        $traceMessage = "An error occurred while trying to make a graph API call: $_`r`n`r`nAdditional details: $traceResponse"
        Write-Verbose "ERROR: $traceMessage"

        throw New-Object System.InvalidOperationException($traceMessage)
    }
}

function PostTo-Service
{
    [CmdletBinding()]
    param($Service, $Path, $Content)

    # build request headers
    $headers = $Service.Headers
    $headers += @{ "User-Agent" = "Microsoft AzureStack Graph PowerShell" }
    # build query string

    # build query string
    $queryString = ConvertTo-QueryString $Service.QueryString

    # Initialize the request parameters
    $request = @{
        Method      = "POST"
        Uri         = "{0}/{1}?{2}" -f $Service.Endpoint.TrimEnd("/"), $Path.TrimStart("/"), $queryString
        Headers     = $headers
        ContentType = "application/json"
        Body = (ConvertTo-Json -Depth 9 $Content)
    }

    # Make the API call, and auto-follow / aggregate next-link responses
    try
    {
        $response = Invoke-WebRequest @request -UseBasicParsing -ErrorAction Stop
        return $response.Content | ConvertFrom-Json
    }
    catch
    {
        # In the case of errors, there is no response returned to caller (even when error action is set to ignore, continue, etc.) so we extract the response from the thrown exception (if there is one)
        $traceResponse = $_.Exception.Response | Select Method,ResponseUri,StatusCode,StatusDescription,IsFromCache,LastModified | ConvertTo-Json

        # Trace the message to verbose stream as well in case error is not traced in same file as other verbose logs
        $traceMessage = "An error occurred while trying to make a graph API call: $_`r`n`r`nAdditional details: $traceResponse"
        Write-Verbose "ERROR: $traceMessage"

        throw New-Object System.InvalidOperationException($traceMessage)
    }
}

function Find-ServicePrincipal
{
    [CmdletBinding()]
    param($Service, $ApplicationId, $ServicePrincipal)
    # cloning service is a MUST, so that we preserve the original object from
    # errorneous state changes, if that happens.
    $graphService = $Service.Clone()
    # build query string
    if ($ApplicationId) {
        $graphService.QueryString += @{ '$filter' = "appId eq '$ApplicationId'" }
    } elseif ($ServicePrincipal) {
        $graphService.QueryString += @{ '$filter' = "servicePrincipalNames/any(c:c eq '$($ServicePrincipal.Resource)')" }
    }
    # try to find service principal
    GetFrom-Service -Service $graphService -Path "/servicePrincipals"
}

function New-OAuth2PermissionGrant
{
    [CmdletBinding()]
    param($Service, $To, $For, $Scope)
    # cloning service is a MUST
    $graphService = $Service.Clone()
    # build json payload
    $oauthPermissionGrant = @{
        "odata.type" = "Microsoft.DirectoryServices.OAuth2PermissionGrant";
        "consentType" = "AllPrincipals";
        "scope" = $Scope;
        "clientId" = $To.objectId;
        "resourceId" = $For.objectId;
        "startTime" = [DateTime]::UtcNow.ToString("o")
        "expiryTime" = [DateTime]::UtcNow.AddYears(1).ToString("o")
    }

    PostTo-Service -Service $graphService -Path "/oauth2PermissionGrants" -Content $oauthPermissionGrant
}

function Find-OAuth2PermissionGrant
{
    [CmdletBinding()]
    param($Service, $To, $For)

    $graphService = $Service.Clone()
    # Query string
    $graphService.QueryString += @{
        '$filter' = "resourceId eq '$($For.objectId)' and clientId eq '$($To.objectId)'"
        '$top'    = '999'
    }

    GetFrom-Service -Service $graphService -Path "/oauth2PermissionGrants"
}

function New-ServicePrincipal
{
    [CmdletBinding()]
    param($Service, $Application)
    # cloning service is a MUST
    $graphService = $Service.Clone()
    # Instantiate and register service principal in the target tenant
    $principal = @{
        "odata.type" = "Microsoft.DirectoryServices.ServicePrincipal";
        "accountEnabled" = "true";
        "appId" = $Application.appId;
        "tags@odata.type" = "Collection(Edm.String)";
        "tags" = @("WindowsAzureActiveDirectoryIntegratedApp")
    }
    #
    PostTo-Service -Service $graphService -Path "/servicePrincipals" -Content $principal
}

function Find-DirectoryReadersMembership
{
    [CmdletBinding()]
    param($Service, $ServicePrincipal)

    # lookup Directory Readers role
    $foundRole = GetFrom-Service `
        -Service $Service `
        -Path "directoryRoles" | 
        Select-Object -ExpandProperty "value" | 
            Where-Object { $_.displayName -eq "Directory Readers" }
    # Get all role members
    $members = GetFrom-Service `
        -Service $Service `
        -Path "directoryRoles/$($foundRole.objectId)/members" | 
        Select-Object -ExpandProperty "value"
    # Return either a service principal or nothing
    $members | Where-Object { $_.objectId -ieq $ServicePrincipal.objectId }
}

function New-DirectoryReadersMembership
{
    [CmdletBinding()]
    param($Service, $ServicePrincipal)

    # lookup Directory Readers role
    $foundRole = GetFrom-Service `
        -Service $Service `
        -Path "directoryRoles" | 
        Select-Object -ExpandProperty "value" | 
            Where-Object { $_.displayName -eq "Directory Readers" }

    # "directoryRoles/$roleObjectId/`$links/members"
    $membership = @{
        url = '{0}/directoryObjects/{1}' -f $Service.Endpoint.TrimEnd('/'), $ServicePrincipal.objectId
    }

    PostTo-Service `
        -Service $Service `
        -Path "directoryRoles/$($foundRole.objectId)/`$links/members" `
        -Content $membership
}

if (-not $me)
{
    $me = Get-Credential -Message "TODO: Need '$ActiveDirectoryTenant' administrator's credentials..."
}

ConnectTo-Service `
    -SignInAs $me `
    -Service $my_environment.AzureCloud.'Microsoft.Graph' `
    -Via $my_environment.AzureCloud.'Microsoft.AzureActiveDirectory'

# find Azure PowerShell service principal
$to = Find-ServicePrincipal `
    -Service $my_environment.AzureCloud.'Microsoft.Graph' `
    -ApplicationId "1950a258-227b-4e31-a9cf-717495945fc2" | Select-Object -ExpandProperty "value"
# find Resource Manager service principal
$for = Find-ServicePrincipal `
    -Service $my_environment.AzureCloud.'Microsoft.Graph' `
    -ServicePrincipal $my_environment.MyAzureStack.'Microsoft.ResourceManager' | Select-Object -ExpandProperty "value"

# not found azure psh - create it.
if (-not $to)
{
    $to = New-ServicePrincipal `
                -Service $my_environment.AzureCloud.'Microsoft.Graph' `
                -Application @{ appId = '1950a258-227b-4e31-a9cf-717495945fc2' }
}

# grant Azure PowerShell permissions to access Microsoft.AzureStack.ResourceManager
$foundObject = Find-OAuth2PermissionGrant `
    -Service $my_environment.AzureCloud.'Microsoft.Graph' `
    -To $to `
    -For $for | Select-Object -ExpandProperty "value"
if (-not $foundObject)
{
    New-OAuth2PermissionGrant `
        -Service $my_environment.AzureCloud.'Microsoft.Graph' `
        -To $to `
        -For $for `
        -Scope "user_impersonation"
}

ConnectTo-Service `
    -SignInAs $me `
    -Service $my_environment.MyAzureStack.'Microsoft.ResourceManager' `
    -Via $my_environment.AzureCloud.'Microsoft.AzureActiveDirectory'

# fetch all app registrations
$applicationRegistrations = GetFrom-Service `
    -Service $my_environment.MyAzureStack.'Microsoft.ResourceManager' `
    -Path "/applicationRegistrations" | Select-Object -ExpandProperty "value"

# create new service principals
foreach($applicationRegistration in $applicationRegistrations)
{
    # First, we try to find the service principal
    $servicePrincipal = Find-ServicePrincipal `
        -Service $my_environment.AzureCloud.'Microsoft.Graph' `
        -ApplicationId $applicationRegistration.appId | Select-Object -ExpandProperty "value"
    
    # Make a new service only if it doesn't already exist
    if (-not $servicePrincipal)
    {
        $servicePrincipal = New-ServicePrincipal `
            -Service $my_environment.AzureCloud.'Microsoft.Graph' `
            -Application $applicationRegistration
    }

    # Loop thru the list of permissions defined in the registration manifest
    foreach($permissionGrant in $applicationRegistration.oauth2PermissionGrants)
    {
        # Lookup resource
        $resource = Find-ServicePrincipal `
            -Service $my_environment.AzureCloud.'Microsoft.Graph' `
            -ApplicationId $permissionGrant.Resource | Select-Object -ExpandProperty "value"
        # Lookup client
        $client = Find-ServicePrincipal `
            -Service $my_environment.AzureCloud.'Microsoft.Graph' `
            -ApplicationId $permissionGrant.Client | Select-Object -ExpandProperty "value"
        # Make a new service principal (client) only if it doesn't already exist
        if (-not $client)
        {
            $client = New-ServicePrincipal `
                -Service $my_environment.AzureCloud.'Microsoft.Graph' `
                -Application @{ appId = $permissionGrant.Client }
        }

        # Lookup permission grant
        $ppi = Find-OAuth2PermissionGrant `
            -Service $my_environment.AzureCloud.'Microsoft.Graph' `
            -To $client `
            -For $resource | Select-Object -ExpandProperty "value"
        # Match attributes to ensure we do not miss something important
        if ($ppi)
        {
            # Match permission consent type
            if ($ppi.consentType -ieq $permissionGrant.ConsentType)
            {
                # Match permission scope
                if ($ppi.scope.Contains($permissionGrant.Scope))
                {
                    # This permission grant perfectly matches everything we have in the registration manifest
                    continue
                }
            }
        }
        # Simply create a new permission grant
        New-OAuth2PermissionGrant `
            -Service $my_environment.AzureCloud.'Microsoft.Graph' `
            -To $client `
            -For $resource `
            -Scope $permissionGrant.Scope
    }

    # Loop thru the list of directory roles defined in the registration manifest
    foreach($directoryRole in $applicationRegistration.directoryRoles)
    {
        # Explicit role membership
        if ($directoryRole -ieq 'Directory Readers')
        {
            # Lookup if the service principal is already a member of the role
            $member = Find-DirectoryReadersMembership `
                -Service $my_environment.AzureCloud.'Microsoft.Graph' `
                -ServicePrincipal $servicePrincipal
            # 
            if (-not $member)
            {
                # Grant membership in "Directory Readers" role
                New-DirectoryReadersMembership `
                    -Service $my_environment.AzureCloud.'Microsoft.Graph' `
                    -ServicePrincipal $servicePrincipal
            }
        }
    }
}