# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
.Synopsis
   Initializes the module with the necessary information to call Graph APIs in a user context.
#>
function Initialize-GraphEnvironment
{
    [CmdletBinding(DefaultParameterSetName='Credential_AAD')]
    param
    (
        # The directory tenant identifier of the primary issuer in which Graph API calls should be made.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $DirectoryTenantId,

        # The user credential with which to acquire an access token targeting Graph.
        [Parameter(ParameterSetName='Credential_AAD')]
        [Parameter(ParameterSetName='Credential_ADFS')]
        [ValidateNotNull()]
        [pscredential] $UserCredential = $null,

        # The refresh token to use to acquire an access token targeting Graph.
        [Parameter(ParameterSetName='RefreshToken_AAD')]
        [Parameter(ParameterSetName='RefreshToken_ADFS')]
        [ValidateNotNull()]
        [SecureString] $RefreshToken = $null,

        # The client identifier (application identifier) of a service principal with which to acquire an access token targeting Graph.
        [Parameter(ParameterSetName='ServicePrincipal_AAD')]
        [ValidateNotNullOrEmpty()]
        [string] $ClientId = $null,

        # The client certificate of a service principal with which to acquire an access token targeting Graph.
        [Parameter(ParameterSetName='ServicePrincipal_AAD')]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate = $null,

        # The name of the supported Cloud Environment in which the target Graph Service is available.
        [Parameter(ParameterSetName='Credential_AAD')]
        [Parameter(ParameterSetName='RefreshToken_AAD')]
        [Parameter(ParameterSetName='ServicePrincipal_AAD')]
        [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment', 'AzureGermanCloud')]
        [string] $Environment = 'AzureCloud',

        # The fully-qualified domain name of the ADFS service (e.g. "adfs.azurestack.local").
        [Parameter(Mandatory=$true, ParameterSetName='Credential_ADFS')]
        [Parameter(Mandatory=$true, ParameterSetName='RefreshToken_ADFS')]
        [ValidateNotNullOrEmpty()]
        [string] $AdfsFqdn,

        # The fully-qualified domain name of the on-premise Graph service (e.g. "graph.azurestack.local").
        [Parameter(Mandatory=$true, ParameterSetName='Credential_ADFS')]
        [Parameter(Mandatory=$true, ParameterSetName='RefreshToken_ADFS')]
        [ValidateNotNullOrEmpty()]
        [string] $GraphFqdn
    )

    if ($AdfsFqdn)
    {
        $Environment = 'ADFS'
        Write-Warning "Parameters for ADFS have been specified; please note that only a subset of Graph APIs are available to be used in conjuction with ADFS."
    }

    if ($UserCredential)
    {
        Write-Verbose "Initializing the module to use Graph environment '$Environment' for user '$($UserCredential.UserName)' in directory tenant '$DirectoryTenantId'." -Verbose
    }
    elseif ($RefreshToken)
    {
        Write-Verbose "Initializing the module to use Graph environment '$Environment' (with refresh token) in directory tenant '$DirectoryTenantId'." -Verbose
    }
    elseif ($ClientId -and $ClientCertificate)
    {
        Write-Verbose "Initializing the module to use Graph environment '$Environment' for service principal '$($ClientId)' in directory tenant '$DirectoryTenantId' with certificate $($ClientCertificate.Thumbprint)." -Verbose
    }
    else
    {
        Write-Warning "A user credential, refresh token, or service principal info was not provided. Graph API calls cannot be made until one is provided. Please run 'Initialize-GraphEnvironment' again with valid credentials."        
    }

    $graphEnvironmentTemplate = @{}
    $graphEnvironmentTemplate += switch ($Environment)
    {
        'AzureCloud'
        {
            @{
                GraphVersion  = "1.6"
                GraphResource = "https://graph.windows.net/"

                IssuerTemplate = "https://sts.windows.net/{0}/"

                LoginEndpoint = [Uri]"https://login.windows.net/$DirectoryTenantId"
                GraphEndpoint = [Uri]"https://graph.windows.net/$DirectoryTenantId"

                LoginBaseEndpoint = [Uri]"https://login.windows.net/"
                GraphBaseEndpoint = [Uri]"https://graph.windows.net/"

                FederationMetadataEndpoint = [Uri]"https://login.windows.net/$DirectoryTenantId/federationmetadata/2007-06/federationmetadata.xml"
                OpenIdMetadata             = [Uri]"https://login.windows.net/$DirectoryTenantId/.well-known/openid-configuration"
            }
        }

        'AzureChinaCloud'
        {
            @{
                GraphVersion  = "1.6"
                GraphResource = "https://graph.chinacloudapi.cn/"

                IssuerTemplate = "https://sts.chinacloudapi.cn/{0}/"

                LoginEndpoint = [Uri]"https://login.chinacloudapi.cn/$DirectoryTenantId"
                GraphEndpoint = [Uri]"https://graph.chinacloudapi.cn/$DirectoryTenantId"

                LoginBaseEndpoint = [Uri]"https://login.chinacloudapi.cn/"
                GraphBaseEndpoint = [Uri]"https://graph.chinacloudapi.cn/"

                FederationMetadataEndpoint = [Uri]"https://login.chinacloudapi.cn/$DirectoryTenantId/federationmetadata/2007-06/federationmetadata.xml"
                OpenIdMetadata             = [Uri]"https://login.chinacloudapi.cn/$DirectoryTenantId/.well-known/openid-configuration"
            }
        }

        'AzureUSGovernment'
        {
            @{
                GraphVersion  = "1.6"
                GraphResource = "https://graph.windows.net/"

                IssuerTemplate = "https://sts.windows.net/{0}/"

                LoginEndpoint = [Uri]"https://login-us.microsoftonline.com/$DirectoryTenantId"
                GraphEndpoint = [Uri]"https://graph.windows.net/$DirectoryTenantId"

                LoginBaseEndpoint = [Uri]"https://login-us.microsoftonline.com/"
                GraphBaseEndpoint = [Uri]"https://graph.windows.net/"

                FederationMetadataEndpoint = [Uri]"https://login-us.microsoftonline.com/$DirectoryTenantId/federationmetadata/2007-06/federationmetadata.xml"
                OpenIdMetadata             = [Uri]"https://login-us.microsoftonline.com/$DirectoryTenantId/.well-known/openid-configuration"
            }
        }

        'AzureGermanCloud'
        {
            @{
                GraphVersion  = "1.6"
                GraphResource = "https://graph.cloudapi.de/"

                IssuerTemplate = "https://sts.microsoftonline.de/{0}/"

                LoginEndpoint = [Uri]"https://login.microsoftonline.de/$DirectoryTenantId"
                GraphEndpoint = [Uri]"https://graph.cloudapi.de/$DirectoryTenantId"

                LoginBaseEndpoint = [Uri]"https://login.microsoftonline.de/"
                GraphBaseEndpoint = [Uri]"https://graph.cloudapi.de/"

                FederationMetadataEndpoint = [Uri]"https://login.microsoftonline.de/$DirectoryTenantId/federationmetadata/2007-06/federationmetadata.xml"
                OpenIdMetadata             = [Uri]"https://login.microsoftonline.de/$DirectoryTenantId/.well-known/openid-configuration"
            }
        }

        'ADFS'
        {
            @{
                GraphVersion  = "2016-01-01"
                GraphResource = "https://$GraphFqdn/"

                IssuerTemplate = "https://$AdfsFqdn/adfs/{0}/"

                LoginEndpoint = [Uri]"https://$AdfsFqdn/adfs/$DirectoryTenantId"
                GraphEndpoint = [Uri]"https://$GraphFqdn/$DirectoryTenantId"

                LoginBaseEndpoint = [Uri]"https://$AdfsFqdn/adfs/"
                GraphBaseEndpoint = [Uri]"https://$GraphFqdn/"

                FederationMetadataEndpoint = [Uri]"https://$AdfsFqdn/federationmetadata/2007-06/federationmetadata.xml"
                OpenIdMetadata             = [Uri]"https://$AdfsFqdn/adfs/$DirectoryTenantId/.well-known/openid-configuration"
            }
        }

        default
        {
            throw New-Object NotImplementedException("Unknown environment type '$Environment'")
        }
    }

    # Note: if this data varies from environment to environment, declare it in switch above
    $graphEnvironmentTemplate += @{
        Environment       = $Environment
        DirectoryTenantId = $DirectoryTenantId

        User = [pscustomobject]@{
            Credential            = $UserCredential
            DirectoryTenantId     = $DirectoryTenantId
            AccessToken           = $null
            RefreshToken          = $RefreshToken
            AccessTokenUpdateTime = $null
            AccessTokenExpiresIn  = $null
            ClientRequestId       = [guid]::NewGuid().ToString()
            ServicePrincipal = [pscustomobject]@{
                ClientId    = $ClientId
                Certificate = $ClientCertificate
            }
        }

        Applications = [pscustomobject]@{
            LegacyPowerShell            = [pscustomobject]@{ Id = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417" }
            PowerShell                  = [pscustomobject]@{ Id = "1950a258-227b-4e31-a9cf-717495945fc2" }
            WindowsAzureActiveDirectory = [pscustomobject]@{ Id = "00000002-0000-0000-c000-000000000000" }
            VisualStudio                = [pscustomobject]@{ Id = "872cd9fa-d31f-45e0-9eab-6e460a02d1f1" }
            AzureCLI                    = [pscustomobject]@{ Id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46" }
        }

        AadPermissions = [HashTable]@{
            AccessDirectoryAsSignedInUser   = "a42657d6-7f20-40e3-b6f0-cee03008a62a"
            EnableSignOnAndReadUserProfiles = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
            ReadAllGroups                   = "6234d376-f627-4f0f-90e0-dff25c5211a3"
            ReadAllUsersBasicProfile        = "cba73afc-7f69-4d86-8450-4978e04ecd1a"
            ReadAllUsersFullProfile         = "c582532d-9d9e-43bd-a97c-2667a28ce295"
            ReadDirectoryData               = "5778995a-e1bf-45b8-affa-663a9f3f4d04"
        }
    }

    if ($AdfsFqdn)
    {
        $graphEnvironmentTemplate.Applications = [pscustomobject]@{}
    }

    $Script:GraphEnvironment = [pscustomobject]$graphEnvironmentTemplate
    Write-Verbose "Graph Environment initialized: client-request-id: $($Script:GraphEnvironment.User.ClientRequestId)"

    # Attempt to log-in the user
    if ($UserCredential -or $RefreshToken -or ($ClientId -and $ClientCertificate))
    {
        Update-GraphAccessToken -Verbose
    }
}

<#
.Synopsis
   Gets the Graph environment information, including endpoints and Graph API version.
#>
function Get-GraphEnvironmentInfo
{
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param
    (
    )

    # Return a cloned copy of the environment data without the user information
    $Script:GraphEnvironment | Select -Property * -ExcludeProperty User | ConvertTo-Json -Depth 10 | ConvertFrom-Json | Write-Output
}

<#
.Synopsis
   Asserts that Initialize-GraphEnvironment has been called in the current runspace.
#>
function Assert-GraphEnvironmentIsInitialized
{
    if (-not $Script:GraphEnvironment -or
        -not ($Script:GraphEnvironment.User.Credential -or
             $Script:GraphEnvironment.User.RefreshToken -or
             ($Script:GraphEnvironment.User.ServicePrincipal.ClientId -and $Script:GraphEnvironment.User.ServicePrincipal.Certificate)))
    {
        throw New-Object InvalidOperationException("The graph environment has not yet been initialized. Please run 'Initialize-GraphEnvironment' with a valid credential or refresh token.")
    }
}

<#
.Synopsis
   Asserts that a connection can be established to the initialized graph environment.
#>
function Assert-GraphConnection
{
    [CmdletBinding()]
    param
    (
    )

    Assert-GraphEnvironmentIsInitialized

    Write-Verbose "Testing connection to graph environment using endpoint '$($Script:GraphEnvironment.OpenIdMetadata)'" -Verbose

    try
    {
        $response      = Invoke-WebRequest -UseBasicParsing -Uri $Script:GraphEnvironment.OpenIdMetadata -Verbose -ErrorAction Stop
        $traceResponse = $response | Select StatusCode,StatusDescription,@{n='Content';e={ConvertFrom-Json $_.Content}} | ConvertTo-Json
        Write-Verbose "Verified a successful connection to the graph service; response received: $traceResponse" -Verbose
    }
    catch
    {
        # In the case of errors, there is no response returned to caller (even when error action is set to ignore, continue, etc.) so we extract the response from the thrown exception (if there is one)
        $traceResponse = $_.Exception.Response | Select Method,ResponseUri,StatusCode,StatusDescription,IsFromCache,LastModified | ConvertTo-Json

        if ($_.Exception.Response.StatusCode -and $_.Exception.Response.StatusCode -lt 500)
        {
            # This means we received a valid response from graph (our connection is good) but there was some other error in the call...
            Write-Warning "An unexpected error response was received while validating a connection to the graph service: $_`r`n`r`nAdditional details: $traceResponse"
        }
        else
        {
            # Trace the message to verbose stream as well in case error is not traced in same file as other verbose logs
            $traceMessage = "An error occurred while trying to verify connection to the graph endpoint '$($Script:GraphEnvironment.OpenIdMetadata)': $_`r`n`r`nAdditional details: $traceResponse"
            Write-Verbose "ERROR: $traceMessage"
            
            throw New-Object System.InvalidOperationException($traceMessage)
        }
    }
}

<#
.Synopsis
   Acquires a token from Graph for the specified resource using the specified or initialized credential or refresh token.
#>
function Get-GraphToken
{
    [CmdletBinding(DefaultParametersetName='Credential')]
    [OutputType([pscustomobject])]
    param
    (
        # The resource for which to acquire a token.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Resource = $Script:GraphEnvironment.GraphResource,

        # The user credential with which to acquire an access token targeting the specified resource.
        [Parameter(Mandatory=$true, ParameterSetName='Credential')]
        [ValidateNotNull()]
        [pscredential] $Credential = $null,

        # The refresh token to use to acquire an access token targeting the specified resource.
        [Parameter(Mandatory=$true, ParameterSetName='RefreshToken')]
        [ValidateNotNullOrEmpty()]
        [SecureString] $RefreshToken = $null,

        # The client identifier (application identifier) of a service principal with which to acquire an access token targeting the specified resource.
        [Parameter(Mandatory=$true, ParameterSetName='ServicePrincipal')]
        [ValidateNotNull()]
        [string] $ClientId = $null,

        # The client certificate of a service principal with which to acquire an access token targeting targeting the specified resource.
        [Parameter(Mandatory=$true, ParameterSetName='ServicePrincipal')]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate = $null,

        # Indicates whether the user credential or refresh token should be used from the initialized environment data.
        [Parameter(Mandatory=$true, ParameterSetName='Environment')]
        [Switch] $UseEnvironmentData
    )

    Assert-GraphConnection

    if ($UseEnvironmentData)
    {
        if ($Script:GraphEnvironment.User.Credential)
        {
            $Credential = $Script:GraphEnvironment.User.Credential
        }
        elseif ($Script:GraphEnvironment.User.RefreshToken)
        {
            $RefreshToken = $Script:GraphEnvironment.User.RefreshToken
        }
        elseif ($Script:GraphEnvironment.User.ServicePrincipal.ClientId -and $Script:GraphEnvironment.User.ServicePrincipal.Certificate)
        {
            $ClientId          = $Script:GraphEnvironment.User.ServicePrincipal.ClientId
            $ClientCertificate = $Script:GraphEnvironment.User.ServicePrincipal.Certificate
        }
    }

    $requestBody = @{ resource = $Resource }

    if ($Credential)
    {
        $requestBody += @{
            client_id  = $Script:GraphEnvironment.Applications.PowerShell.Id
            grant_type = 'password'
            scope      = 'openid'
            username   = $Credential.UserName
            password   = $Credential.GetNetworkCredential().Password
        }

        Write-Verbose "Attempting to acquire a token for resource '$Resource' using a user credential '$($Credential.UserName)'"
    }
    elseif ($RefreshToken)
    {
        $requestBody += @{
            client_id     = $Script:GraphEnvironment.Applications.PowerShell.Id
            grant_type    = 'refresh_token'
            scope         = 'openid'
            refresh_token = (New-Object System.Net.NetworkCredential('refreshToken', $RefreshToken)).Password
        }

        Write-Verbose "Attempting to acquire a token for resource '$Resource' using a refresh token"
    }
    elseif ($ClientId -and $ClientCertificate)
    {
        function ConvertTo-Base64UrlEncode([byte[]]$bytes) { [System.Convert]::ToBase64String($bytes).Replace('/','_').Replace('+','-').Trim('=') }

        $tokenHeaders = [ordered]@{
            alg = 'RS256'
            x5t = ConvertTo-Base64UrlEncode $ClientCertificate.GetCertHash()
        }

        $tokenClaims = [ordered]@{
            aud = "$($Script:GraphEnvironment.LoginEndpoint)".Trim('/') + '/oauth2/token'
            exp = [long](([datetime]::UtcNow - [datetime]'1970-01-01 00:00:00').TotalSeconds + 3600)
            iss = $ClientId
            jti = [guid]::NewGuid().ToString()
            nbf = [long](([datetime]::UtcNow - [datetime]'1970-01-01 00:00:00').TotalSeconds - 90)
            sub = $ClientId
        }

        Write-Verbose "Preparing client assertion with token header: '$(ConvertTo-Json $tokenHeaders -Compress)' and claims: $(ConvertTo-Json $tokenClaims)"

        # Note - we escape the forward slashes ('/') as the ConvertTo-Json cmdlet does not. This may not actually be necessary.
        $tokenParts = @()
        $tokenParts += ConvertTo-Base64UrlEncode ([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $tokenHeaders -Depth 10 -Compress).Replace('/', '\/')))
        $tokenParts += ConvertTo-Base64UrlEncode ([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $tokenClaims -Depth 10 -Compress).Replace('/', '\/')))

        $sha256Hash = ''
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try
        {
            $sha256Hash = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($tokenParts -join '.'))
        }
        finally
        {
            if ($sha256) { $sha256.Dispose(); $sha256 = $null }
        }

        # Note - the default instance of the RSACryptoServiceProvider instantiated on the client certificate may only support SHA1.
        # E.g. Even when "$($ClientCertificate.SignatureAlgorithm.FriendlyName)" evaluates to "sha256RSA", the value of
        # "$($ClientCertificate.PrivateKey.SignatureAlgorithm)" may evaulate to "http://www.w3.org/2000/09/xmldsig#rsa-sha1".
        # Furthermore, the private key is not marked as exportable, so we cannot "simply" instantiate a new RSACryptoServiceProvider instance.
        # We must first create new CSP parameters with a "better" cryptographic service provider that supports SHA256, and use those parameters
        # to instantiate a "better" RSACryptoServiceProvider which also supports SAH256. Failure to do this will result in the following error:
        # "Exception calling "CreateSignature" with "1" argument(s): "Invalid algorithm specified."
        # It may be possible to bypass this issue of the certificate is generated with the "correct" cryptographic service provider, but if the certificate
        # was created by a CA or if the provider type was not the "correct" type, then this workaround must be used.
        $csp = New-Object System.Security.Cryptography.CspParameters(
            ($providerType=24),
            ($providerName='Microsoft Enhanced RSA and AES Cryptographic Provider'),
            $ClientCertificate.PrivateKey.CspKeyContainerInfo.KeyContainerName)
        $csp.Flags = [System.Security.Cryptography.CspProviderFlags]::UseMachineKeyStore

        $signatureBytes = $null
        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider($csp)
        try
        {
            $signatureBytes = $rsa.SignHash($sha256Hash, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        }
        finally
        {
            if ($rsa) { $rsa.Dispose(); $rsa = $null }
        }

        $tokenParts += ConvertTo-Base64UrlEncode $signatureBytes

        $requestBody += @{
            client_id             = $ClientId
            grant_type            = 'client_credentials'
            client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
            client_assertion      = $tokenParts -join '.'
        }

        Write-Verbose "Attempting to acquire a token for resource '$Resource' using a service principal credential (id='$($ClientId)', thumbprint='$($ClientCertificate.Thumbprint)')"
    }
    else
    {
        throw New-Object InvalidOperationException("A valid user credential or refresh token is required to acquire a token from Graph service. Please run 'Initialize-GraphEnvironment' with a valid user credential or refresh token, or try the command again with one of the necessary values.")
    }

    $loginUserRequest = @{
        Method       = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
        BaseEndpoint = $Script:GraphEnvironment.LoginEndpoint
        ApiPath      = 'oauth2/token'
        ContentType  = "application/x-www-form-urlencoded"
        Body         = ConvertTo-QueryString $requestBody
    }

    $response = Invoke-GraphApi @loginUserRequest -UpdateGraphAccessTokenIfNecessary:$false
    Write-Output $response
}

<#
.Synopsis
   Updates the user Graph access token using the configured Graph Environment details.
#>
function Update-GraphAccessToken
{
    [CmdletBinding()]
    param
    (
    )

    # Attempt to log-in the user
    $response = Get-GraphToken -UseEnvironmentData

    $Script:GraphEnvironment.User.AccessToken           = $response.access_token
    $Script:GraphEnvironment.User.RefreshToken          = if ($response.refresh_token) { ConvertTo-SecureString $response.refresh_token -AsPlainText -Force } else { $null }
    $Script:GraphEnvironment.User.AccessTokenUpdateTime = [DateTime]::UtcNow
    $Script:GraphEnvironment.User.AccessTokenExpiresIn  = $response.expires_in
}

<#
.Synopsis
   Makes an API call to the graph service.
#>
function Invoke-GraphApi
{
    [CmdletBinding()]
    param
    (
        # The request method.
        [Parameter()]
        [ValidateNotNull()]
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get,

        # The API path to call.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ApiPath,

        # The (additional) query parameters to include in the request.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [HashTable] $QueryParameters = @{},

        # The custom (additional) headers to include in the request.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [HashTable] $CustomHeaders = @{},

        # The base endpoint of the Graph service to call.
        [Parameter()]
        [ValidateNotNull()]
        [Uri] $BaseEndpoint = $Script:GraphEnvironment.GraphEndpoint,

        # The content type of the request.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ContentType = "application/json",

        # The body of the request.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Body = $null,

        # Indicates whether the Graph access token should be automatically refreshed if it is close to or has already expired (true by default).
        [Switch] $UpdateGraphAccessTokenIfNecessary = $true,

        # Indicates whether responses containing "OData NextLinks" should be automatically called and aggregated (true by default).
        [Switch] $AggregateNextLinkData = $true
    )

    Assert-GraphEnvironmentIsInitialized

    if ($UpdateGraphAccessTokenIfNecessary)
    {
        $secondsSinceTokenWasLastUpdated = [DateTime]::UtcNow.Subtract($Script:GraphEnvironment.User.AccessTokenUpdateTime).TotalSeconds
        if ($secondsSinceTokenWasLastUpdated -gt ($Script:GraphEnvironment.User.AccessTokenExpiresIn - 90))
        {
            Write-Verbose "Updating graph access token"
            Update-GraphAccessToken
        }
    }

    # Initialize the request parameters
    $graphApiRequest = @{
        Method      = $Method
        Uri         = '{0}/{1}' -f $BaseEndpoint.AbsoluteUri.TrimEnd('/'), $ApiPath.Trim('/')
        Headers     = @{
            "User-Agent"        = "Microsoft AzureStack Graph PowerShell"
            "client-request-id" = $Script:GraphEnvironment.User.ClientRequestId
        }
        ContentType = $ContentType
    }

    # Set the authorization header if we already have an access token
    if ($Script:GraphEnvironment.User.AccessToken)
    {
        $graphApiRequest.Headers["Authorization"] = "Bearer $($Script:GraphEnvironment.User.AccessToken)"
    }

    # Apply any custom headers specified by the caller (overriding defaults)
    foreach ($header in $CustomHeaders.GetEnumerator())
    {
        $graphApiRequest.Headers[$header.Key] = $header.Value
    }

    # Initialize the query string parameters
    $queryParams = @{ 'api-version' = $Script:GraphEnvironment.GraphVersion }

    # Apply any custom query parameters specified by the caller (overriding defaults)
    foreach ($queryParam in $QueryParameters.GetEnumerator())
    {
        $queryParams[$queryParam.Key] = $queryParam.Value
    }

    $graphApiRequest.Uri += '?{0}' -f (ConvertTo-QueryString $queryParams)

    if ($Body)
    {
        $graphApiRequest['Body'] = $Body
    }

    # Make the API call, and auto-follow / aggregate next-link responses
    try
    {
        $response = (Invoke-WebRequest @graphApiRequest -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
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

    if ((-not $response."odata.nextLink") -or (-not $AggregateNextLinkData))
    {
        Write-Output $response
    }
    else
    {
        $originalResponse = $response | Select -Property * -ExcludeProperty "odata.nextLink"

        while ($response."odata.nextLink")
        {
            # Delay briefly between nextlink calls as they can overwhelm the proxy and / or AAD...
            Start-Sleep -Milliseconds 100

            # Note: the next link URI cannot be used directly as it does not preserve all the query parameters (such as API version)

            # Initialize the query string parameters
            $queryParams = @{ 'api-version' = $Script:GraphEnvironment.GraphVersion }

            # Apply any custom query parameters specified by the caller (overriding defaults)
            foreach ($queryParam in $QueryParameters.GetEnumerator())
            {
                $queryParams[$queryParam.Key] = $queryParam.Value
            }

            # Apply the next link query params (overriding others as applicable)
            $nextLinkQueryParams = [regex]::Unescape($response."odata.nextLink".Split('?')[1])
            $query = [System.Web.HttpUtility]::ParseQueryString($nextLinkQueryParams)
            foreach ($key in $query.Keys)
            {
                $queryParams[$key] = $query[$key]
            }

            # Note: sometimes, the next link URL is relative, and other times it is absolute!
            $absoluteOrRelativeAddress = $response."odata.nextLink".Split('?')[0].TrimStart('/')

            $graphApiRequest.Uri = if ($absoluteOrRelativeAddress.StartsWith("https"))
            {
                '{0}?{1}' -f @($absoluteOrRelativeAddress, (ConvertTo-QueryString $queryParams))
            }
            else
            {
                '{0}/{1}?{2}' -f @(
                    $BaseEndpoint.AbsoluteUri.TrimEnd('/'),
                    $absoluteOrRelativeAddress,
                    (ConvertTo-QueryString $queryParams))
            }

            try
            {
                $response = (Invoke-WebRequest @graphApiRequest -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
                $originalResponse.Value += @($response.Value)
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

        Write-Output $originalResponse
    }
}

<#
.Synopsis
   Gets the verified domain of the currently-configured directory tenant.
#>
function Get-GraphDefaultVerifiedDomain
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
    )

    $tenant = Invoke-GraphApi -ApiPath "tenantDetails" -ErrorAction Stop
    $verifiedDomain = $tenant.value.verifiedDomains | Where initial -EQ $true | Select -First 1
    Write-Output $verifiedDomain.name
}

<#
.Synopsis
   Attempts to find an existing Graph application object, or returns null if no such application can be found.
#>
function Find-GraphApplication
{
    [CmdletBinding(DefaultParameterSetName='ByUri')]
    [OutputType([pscustomobject])]
    param
    (
        # The application identifier URI.
        [Parameter(Mandatory=$true, ParameterSetName='ByUri')]
        [ValidateNotNullOrEmpty()]
        [string] $AppUri,

        # The application identifer.
        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [string] $AppId,

        # The application display name.
        [Parameter(Mandatory=$true, ParameterSetName='ByDisplayName')]
        [ValidateNotNullOrEmpty()]
        [string] $DisplayName
    )

    $filter = if ($DisplayName) {"displayName eq '$DisplayName'"} elseif($AppUri) {"identifierUris/any(i:i eq '$AppUri')"} else {"appId eq '$AppId'"}
    $response = Invoke-GraphApi -ApiPath "applications()" -QueryParameters @{ '$filter' = $filter } -ErrorAction Stop
    Write-Output $response.value
}

<#
.Synopsis
   Gets an existing Graph application object (returns an error if the application is not found).
#>
function Get-GraphApplication
{
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param
    (
        # The application identifier URI.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $AppUri
    )

    $application = Find-GraphApplication -AppUri $AppUri
    if (-not $application)
    {
        Write-Error "Application with identifier '$AppUri' not found"
    }
    else
    {
        Write-Output $application
    }
}

<#
.Synopsis
   Removes the specified object from the Graph directory.
#>
function Remove-GraphObject
{
    [CmdletBinding()]
    param
    (
        # The identifier of the object to remove.
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $objectId
    )
    process
    {
        $null = Invoke-GraphApi -Method Delete -ApiPath "directoryObjects/$objectId" -ErrorAction Stop
    }
}

<#
.Synopsis
   Attempts to find one or more existing Graph applications and service principals, by searching for service principals with a particular tag.
#>
function Find-GraphApplicationDataByServicePrincipalTag
{
    [CmdletBinding(DefaultParameterSetName='StartsWith')]
    param
    (
        # A string used to filter for application service principals that contain a tag that satifies the ODATA filter startswith '$StartsWith'.
        [Parameter(Mandatory=$true, ParameterSetName='StartsWith')]
        [string] $StartsWith = $null,

        # A string used to filter for application service principals that contain a tag that satifies the ODATA filter tag eq '$Equals'.
        [Parameter(Mandatory=$true, ParameterSetName='Equals')]
        [string] $Equals = $null,

        # Indicates whether application lookup should be skipped (and only to return the service principal data).
        [Parameter()]
        [Switch] $SkipApplicationLookup
    )

    $filter = if ($StartsWith) {"tags/any(tag:startswith(tag, '$StartsWith'))"} else {"tags/any(t:t eq '$Equals')"}

    $message = "Looking for service principals with filter '$filter'..."
    Write-Verbose $message
    Write-Progress -Activity $message
    $matchedServicePrincipals = (Invoke-GraphApi -ApiPath 'servicePrincipals()' -QueryParameters @{ '$filter' = $filter } -ErrorAction Stop).value
    Write-Verbose "Matched $(@($matchedServicePrincipals).Length) service principals using filter '$filter'"
    Write-Progress -Activity $message -Completed

    if ($SkipApplicationLookup)
    {
        @($matchedServicePrincipals) | ForEach { [pscustomobject]@{ ServicePrincipal = $_ } } | Write-Output
        return
    }

    $progress = 0
    $start    = Get-Date
    foreach ($matchedServicePrincipal in @($matchedServicePrincipals))
    {
        $progress++
        $elapsedSeconds  = ((Get-Date) - $start).TotalSeconds
        $progressRatio   = $progress / @($matchedServicePrincipals).Length
        $progressParams  = @{
            Activity         = "Looking-up AAD application objects"
            Status           = "Looking up application ($progress/$(@($matchedServicePrincipals).Length)) with appId='$($matchedServicePrincipal.appId)'"
            PercentComplete  = [Math]::Min(100, 100 * $progressRatio)
            SecondsRemaining = [Math]::Max(1, ($elapsedSeconds / $progressRatio) - $elapsedSeconds) # If it took 1 min for 10 items, and we have 100 items, it will likely take 10 minutes. Re-calculate this extrapolation on each iteration.
        }
        Write-Progress @progressParams

        $matchedApplication = Find-GraphApplication -AppId $matchedServicePrincipal.appId

        Write-Output ([pscustomobject]@{
            Application      = $matchedApplication
            ServicePrincipal = $matchedServicePrincipal
        })
    }

    Write-Progress -Activity "Looking-up AAD application objects" -Completed
}

<#
.Synopsis
   Attempts to retrieve a non-null graph object with a limited number of attempts.
#>
function Get-GraphObjectWithRetry
{
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param
    (
        # The script to run which should return an object. If the script throws an exception, the retry will NOT be performed. If the script returns any non-null value, it is considered successful, and the result will be returned.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ScriptBlock] $GetScript,

        # The maximum number of attempts to make before return null.
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaxAttempts,

        # The delay in seconds between each subsequent attempt at running the script.
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $DelayInSecondsBetweenAttempts,

        # The minimal delay in seconds that the script should sleep before returning successfully (if a fatal error is encountered, delay is not enforced).
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MinimumDelayInSeconds = 0
    )

    $result     = $null
    $attempts   = 0
    $totalDelay = 0

    do
    {
        $attempts++
        $message = if ($attempts -le 1) {'Attempting to retrieve graph object'} else {"[RETRY] Attempting to retrieve graph object (attempt $attempts of $MaxAttempts)"}
        Write-Verbose $message
        $result = & $GetScript

        if ((-not $result) -and ($attempts -lt $MaxAttempts))
        {
            Write-Verbose "[RETRY] Attempt $attempts failed, delaying for $DelayInSecondsBetweenAttempts seconds before retry..." -Verbose
            Start-Sleep -Seconds $DelayInSecondsBetweenAttempts
            $totalDelay += $DelayInSecondsBetweenAttempts
        }
    }
    while ((-not $result) -and ($attempts -lt $MaxAttempts))

    $remainingDelay = $MinimumDelayInSeconds - $totalDelay
    if ($remainingDelay -gt 0)
    {
        Write-Verbose "Delaying for an additional $remainingDelay seconds to ensure minimum delay of $MinimumDelayInSeconds seconds is achieved..." -Verbose
        Start-Sleep -Seconds $remainingDelay
    }

    Write-Output $result
}

<#
.Synopsis
   Gets an existing Graph application service principal object (returns an error if the application service principal object is not found).
#>
function Get-GraphApplicationServicePrincipal
{
    [CmdletBinding(DefaultParameterSetName='ByApplicationId')]
    [OutputType([pscustomobject])]
    param
    (
        # The application identifier.
        [Parameter(Mandatory=$true, ParameterSetName='ByApplicationId')]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationId,

        # The application identifier URI.
        [Parameter(Mandatory=$true, ParameterSetName='ByApplicationIdentifierUri')]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationIdentifierUri
    )

    $filter = if ($ApplicationId) { "appId eq '$ApplicationId'" } else { "servicePrincipalNames/any(c:c eq '$ApplicationIdentifierUri')" }

    $servicePrincipal = (Invoke-GraphApi -ApiPath servicePrincipals -QueryParameters @{ '$filter' = $filter }).value

    if (-not $servicePrincipal)
    {
        Write-Error "Application service principal with identifier '${ApplicationId}${ApplicationIdentifierUri}' not found"
    }
    else
    {
        Write-Output $servicePrincipal
    }
}

<#
.Synopsis
   Idempotently creates an application service principal in Graph with the specified properties.
#>
function Initialize-GraphApplicationServicePrincipal
{
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param
    (
        # The application identifier.
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('appId')]
        [string] $ApplicationId,

        # Optional: Tags to include in the application service principal.
        [Parameter()]
        [string[]] $Tags = @()
    )
    process
    {
        $getScript = { (Invoke-GraphApi -ApiPath servicePrincipals -QueryParameters @{ '$filter' = "appId eq '$ApplicationId'" }).value }

        # Create a service principal for the application (if one doesn't already exist) # TODO: support update tags
        if (-not ($primaryServicePrincipal = & $getScript))
        {
            Write-Verbose "Creating service principal for application '$ApplicationId' in AAD..." -Verbose
            $servicePrincipalRequestBody = @{
                'odata.type'   = 'Microsoft.DirectoryServices.ServicePrincipal'
                accountEnabled = $true
                appId          = $ApplicationId
            }

            if ($Tags.Count -gt 0)
            {
                $servicePrincipalRequestBody += @{
                    'tags@odata.type' = 'Collection(Edm.String)'
                    tags = $Tags
                }
            }

            # Note: we poll for the object after creating it to avoid issues with replication delay
            $primaryServicePrincipal = Invoke-GraphApi -Method Post -ApiPath servicePrincipals -Body (ConvertTo-Json $servicePrincipalRequestBody)
            $primaryServicePrincipal = Get-GraphObjectWithRetry -GetScript $getScript -MaxAttempts 10 -DelayInSecondsBetweenAttempts 10 -MinimumDelayInSeconds 5
        }
        else
        {
            Write-Verbose "Service principal for application '$ApplicationId' already created in AAD directory tenant." -Verbose
            if ($Tags)
            {
                Update-GraphApplicationServicePrincipalTags -ApplicationId $ApplicationId -Tags $Tags
            }
        }

        Write-Output $primaryServicePrincipal
    }
}

<#
.Synopsis
   Updates the tags on an existing application service principal.
#>
function Update-GraphApplicationServicePrincipalTags
{
    [CmdletBinding(DefaultParameterSetName='ByApplicationId')]
    [OutputType([pscustomobject])]
    param
    (
        # The application identifier.
        [Parameter(Mandatory=$true, ParameterSetName='ByApplicationId')]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationId,

        # The application identifier URI.
        [Parameter(Mandatory=$true, ParameterSetName='ByApplicationIdentifierUri')]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationIdentifierUri,

        # Additional tags to include in the application service principal (if not already present).
        [Parameter(Mandatory=$true)]
        [string[]] $Tags = @()
    )

    $params = if ($ApplicationId) { @{ ApplicationId = $ApplicationId } } else { @{ ApplicationIdentifierUri = $ApplicationIdentifierUri } }
    $servicePrincipal = Get-GraphApplicationServicePrincipal @params

    $updatedTags = New-Object System.Collections.Generic.HashSet[string](,[string[]]$servicePrincipal.tags)
    foreach ($tag in $Tags)
    {
        if ($updatedTags.Add($tag))
        {
            Write-Verbose "Adding new tag to service principal: '$tag'"
        }
        else
        {
            Write-Verbose "Tag already present on service principal: '$tag'"
        }
    }

    Invoke-GraphApi -Method Patch -ApiPath "servicePrincipals/$($ServicePrincipal.objectId)" -Body (ConvertTo-Json ([pscustomobject]@{
        'tags@odata.type' = 'Collection(Edm.String)'
        tags = $updatedTags
    }))
}

<#
.Synopsis
   Idempotently creates an OAuth2Permission grant for an application service principal against another application service principal in Graph with the specified properties (service principals are created if they do not exist).
#>
function Initialize-GraphOAuth2PermissionGrant
{
    [CmdletBinding(DefaultParameterSetName='ClientAppId_ResourceAppId')]
    param
    (
        # The application identifier of the client application.
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_ResourceAppId')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_ResourceIdentifierUri')]
        [ValidateNotNullOrEmpty()]
        [string] $ClientApplicationId,

        # The application identifier URI of the client application.
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_ResourceAppId')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_ResourceIdentifierUri')]
        [ValidateNotNullOrEmpty()]
        [string] $ClientApplicationIdentifierUri,

        # The application identifier of the resource application.
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_ResourceAppId')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_ResourceAppId')]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceApplicationId,

        # The application identifier URI of the resource application.
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_ResourceIdentifierUri')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_ResourceIdentifierUri')]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceApplicationIdentifierUri,

        # The scope of the permission to grant (e.g. 'user_impersonation' [default value]).
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Scope = 'user_impersonation',

        # The consent type of the permission to grant (e.g. 'AllPrincipals' [default value]).
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('AllPrincipals', 'Principal')]
        [string] $ConsentType = 'AllPrincipals'
    )

    # Ensure the application service principals exist in the directory tenant

    $clientApplicationServicePrincipal = if ($ClientApplicationId)
    {
        Initialize-GraphApplicationServicePrincipal -ApplicationId $ClientApplicationId
    }
    else
    {
        Get-GraphApplicationServicePrincipal -ApplicationIdentifierUri $ClientApplicationIdentifierUri
    }

    $resourceApplicationServicePrincipal = if ($ResourceApplicationId)
    {
        Initialize-GraphApplicationServicePrincipal -ApplicationId $ResourceApplicationId
    }
    else
    {
        Get-GraphApplicationServicePrincipal -ApplicationIdentifierUri $ResourceApplicationIdentifierUri
    }
    
    # TODO: Do we need to support updating expired permission grants? The documentation appears to say these properties should be ignored: "https://msdn.microsoft.com/en-us/library/azure/ad/graph/api/entity-and-complex-type-reference#oauth2permissiongrant-entity"
    $queryParameters = @{
        '$filter' = "resourceId eq '$($resourceApplicationServicePrincipal.objectId)' and clientId eq '$($clientApplicationServicePrincipal.objectId)'"
        '$top'    = '999'
    }
    if (-not (Invoke-GraphApi -ApiPath oauth2PermissionGrants -QueryParameters $queryParameters).Value)
    {
        Write-Verbose "Granting OAuth2Permission '$Scope' to application service principal '$($clientApplicationServicePrincipal.appDisplayName)' on behalf of application '$($resourceApplicationServicePrincipal.appDisplayName)'..." -Verbose
        $response = Invoke-GraphApi -Method Post -ApiPath oauth2PermissionGrants -Body (ConvertTo-Json ([pscustomobject]@{
            'odata.type' = 'Microsoft.DirectoryServices.OAuth2PermissionGrant'
            clientId     = $clientApplicationServicePrincipal.objectId
            resourceId   = $resourceApplicationServicePrincipal.objectId
            consentType  = $ConsentType
            scope        = $Scope
            startTime    = [DateTime]::UtcNow.ToString('o')
            expiryTime   = [DateTime]::UtcNow.AddYears(1).ToString('o')
        }))
    }
    else
    {
        Write-Verbose "OAuth2Permission '$Scope' already granted to client application service principal '$($clientApplicationServicePrincipal.appDisplayName)' on behalf of resource application '$($resourceApplicationServicePrincipal.appDisplayName)'." -Verbose
    }
}

<#
.Synopsis
   Idempotently grants an application service principal membership to a directory role to (service principal is created if it do not exist).
#>
function Initialize-GraphDirectoryRoleMembership
{
    [CmdletBinding()]
    param
    (
        # The application identifier to which role membership should be granted.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationId,

        # The display name of the role to which the application should be granted membership.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Directory Readers')]
        [string] $RoleDisplayName
    )

    # Ensure the application service principal exist in the directory tenant
    $applicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $ApplicationId

    # https://msdn.microsoft.com/en-us/Library/Azure/Ad/Graph/api/directoryroles-operations#AddDirectoryRoleMembers

    # Lookup the object id of the directory role in the directory tenant (note - these reference role templates)
    $roles        = Invoke-GraphApi -ApiPath directoryRoles
    $roleObjectId = $roles.value | Where displayName -EQ $RoleDisplayName | Select -First 1 -ExpandProperty objectId
    Write-Verbose "Existing Directory Roles: $(ConvertTo-Json $roles.value)" -Verbose

    # If the directory readers role does not exist, we need to "activate it"
    if (-not $roleObjectId)
    {
        $roleTemplates  = Invoke-GraphApi -ApiPath directoryRoleTemplates
        $roleTemplateId = $roleTemplates.value | Where displayName -EQ $RoleDisplayName | Select -First 1 -ExpandProperty objectId
        Write-Verbose "Existing Directory Role Templates: $(ConvertTo-Json $roleTemplates.value)" -Verbose

        Write-Verbose "Creating directory role '$RoleDisplayName' ($($roleTemplateId))..." -Verbose
        $response = Invoke-GraphApi -Method Post -ApiPath directoryRoles -Body (ConvertTo-Json ([pscustomobject]@{
            roleTemplateId = $roleTemplateId
        }))

        $roleObjectId = $response.objectId
    }

    # Lookup the existing memberships of the service principal; if the application service principal is not already a member of the directory role, grant it role membership
    $apiPath  = "servicePrincipals/$($applicationServicePrincipal.objectId)/getMemberObjects"
    $response = Invoke-GraphApi -Method Post -ApiPath $apiPath -Body (ConvertTo-Json ([pscustomobject]@{
        securityEnabledOnly = $false
    }))
    
    if ($response.value -icontains $roleObjectId)
    {
        Write-Verbose "Membership already granted to directory role '$RoleDisplayName' ($($roleObjectId)) for application service principal '$($applicationServicePrincipal.appDisplayName)'." -Verbose
    }
    else
    {
        Write-Verbose "Granting membership to directory role '$RoleDisplayName' ($($roleObjectId)) for application service principal '$($applicationServicePrincipal.appDisplayName)'..." -Verbose
        $apiPath  = "directoryRoles/$roleObjectId/`$links/members"
        $response = Invoke-GraphApi -Method Post -ApiPath $apiPath -Body (ConvertTo-Json ([pscustomobject]@{
            url = '{0}/directoryObjects/{1}' -f $Script:GraphEnvironment.GraphEndpoint.AbsoluteUri.TrimEnd('/'), $applicationServicePrincipal.objectId
        }))
    }
}

<#
.Synopsis
   Creates or updates an application in Graph with an implicit service principal and the specified properties.
#>
function Initialize-GraphApplication
{
    [CmdletBinding(DefaultParameterSetName='Cert')]
    [OutputType([pscustomobject])]
    param
    (
        # The display name of the application.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $DisplayName,

        # The homepage address of the application.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $Homepage,

        # The reply address(es) of the application.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ReplyAddress,

        # The application identifier URI.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentifierUri,

        # The client certificate used to authenticate with graph as the application / service principal.
        [Parameter(ParameterSetName='Cert')]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate = $null,

        # The thumbprint of the client certificate used to authenticate with graph as the application / service principal.
        [Parameter(ParameterSetName='Thumbprint')]
        [ValidateNotNull()]
        [ValidatePattern('^([0-9A-Fa-f]{2})*$')]
        [string] $ClientCertificateThumbprint = $null,

        # The set of AAD permissions required directly by the application in the context of its service principal.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'ReadDirectoryData'
        )]
        [String[]] $ApplicationAadPermissions = @(),

        # The set of delegated AAD permissions required by the application in the context of the signed-in user.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'AccessDirectoryAsSignedInUser',
            'EnableSignOnAndReadUserProfiles',
            'ReadAllGroups',
            'ReadAllUsersBasicProfile',
            'ReadAllUsersFullProfile',
            'ReadDirectoryData'
        )]
        [String[]] $DelegatedAadPermissions = @(),

        # A collection of Application Identifier URIs to which delegated resource access (on behalf of the signed-in user - "user_impersonation") is required by / should be granted to the initialized application.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]] $ResourceAccessByAppUris = @(),

        # The first-party applications to which the "user_impersonation" OAuth2 permission should be granted.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'LegacyPowerShell',
            'PowerShell',
            'VisualStudio',
            'AzureCLI'
        )]
        [string[]] $OAuth2PermissionGrants = @(),

        # A collection of Application Identifier URIs for which a service principal should be initialized and to which the "user_impersonation" OAuth2 permission should be granted.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $OAuth2PermissionGrantsByAppUris = @(),

        # A collection of Application Identifier URIs for known client applications which should be associated to this application.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $KnownClientApplicationsByAppUris = @(),

        # Tags to include in the application service principal.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Tags = @(),

        # Indicates that the application should be deleted and re-created (if it already exists).
        [Parameter()]
        [Switch] $DeleteAndCreateNew,

        # Indicates that the application should be available to other tenants (multi-tenanted). True by default.
        [Parameter()]
        [Switch] $AvailableToOtherTenants = $true,

        # Indicates that the application service principal should be given membership in the directory readers role to activate the role permission ReadDirectoryData. True by default.
        [Parameter()]
        [Switch] $UseDirectoryReadersRolePermission = $true
    )

    if ($ClientCertificateThumbprint)
    {
        $ClientCertificate = Get-Item "Cert:\LocalMachine\My\$ClientCertificateThumbprint" -ErrorAction Stop
    }

    if (($existingApplication = Find-GraphApplication -AppUri $IdentifierUri -ErrorAction Stop))
    {
        if ($DeleteAndCreateNew)
        {
            # Very special case of updating multi-tenanted application before removing them
            if ($existingApplication.availableToOtherTenants)
            {
                Write-Verbose "Disable multi-tenancy before removing the application..." -Verbose
                $existingApplication.availableToOtherTenants = $false
                $apiPath = "directoryObjects/$($existingApplication.objectId)/Microsoft.DirectoryServices.Application"
                $requestBodyAsJson =  @{ availableToOtherTenants = $false } | ConvertTo-Json -Depth 10
                $noContentResponse = Invoke-GraphApi -Method Patch -ApiPath $apiPath -Body $requestBodyAsJson -ErrorAction Stop
            }

            Write-Warning "Existing application identified by '$IdentifierUri' with id '$($existingApplication.ObjectId)' found. Deleting application..."
            $existingApplication | Remove-GraphObject -ErrorAction Stop
            $existingApplication = $null

            while (Find-GraphApplication -AppUri $IdentifierUri -ErrorAction Stop -Verbose)
            {
                Write-Verbose "Waiting for graph application to be deleted..." -Verbose
                Start-Sleep -Seconds 1
            }
        }
        else
        {
            Write-Verbose "An existing application with identifier '$IdentifierUri' was found. This application will be updated accordingly." -Verbose
        }
    }
    else
    {
        Write-Verbose "Existing application with identifier '$IdentifierUri' not found. A new one will be created." -Verbose
    }

    ##
    ##

    # Initialize the request body
    $requestBody = @{
        "odata.type"          = "Microsoft.DirectoryServices.Application"
        displayName           = $DisplayName
        groupMembershipClaims = "SecurityGroup" # Note: Possible values are "null" => means No Claims, "SecurityGroup" => means 'SG and Azure AD roles' and "All" => means "SG + DL + Azure AD roles"

        # Initialize the application identifiers, preserving any that already exist, and idempotently adding the specified URI into the collection
        "identifierUris@odata.type" = "Collection(Edm.String)"
        identifierUris              = @(@($existingApplication.identifierUris) + @($IdentifierUri) | Select -Unique | Where { $_ -ne $null })
    }

    # Enable multi-tenancy if applicable
    if ($AvailableToOtherTenants)
    {
        if ("$($existingApplication.availableToOtherTenants)" -ieq 'false')
        {
            Write-Warning "Existing application with identifier '$IdentifierUri' was previously created with configuration 'availableToOtherTenants = false'. Updating configuration to 'availableToOtherTenants = true'." -ErrorAction Stop
        }

        $requestBody += @{
            availableToOtherTenants = $true
        }
    }

    # Initialize the application reply URLs, preserving any that already exist, and idempotently adding the specified URI into the collection
    if ($ReplyAddress.Count -gt 0)
    {
        $requestBody += @{
            "replyUrls@odata.type" = "Collection(Edm.String)"
            replyUrls              = @(@($existingApplication.replyUrls) + $ReplyAddress | Select -Unique | Where { $_ -ne $null })
        }
    }

    if ($Homepage)
    {
        $requestBody['homepage'] = $Homepage
    }

    # Initialize the application key credentials with which it can authenticate
    if ($ClientCertificate)
    {
        $customKeyIdentifier = [Convert]::ToBase64String($ClientCertificate.GetCertHash())
        if (-not (@($existingApplication.keyCredentials) | Where customKeyIdentifier -EQ $customKeyIdentifier))
        {
            Write-Verbose "Adding new key credentials to application using client certificate '$($ClientCertificate.Subject)' ($($ClientCertificate.Thumbprint))" -Verbose

            $requestBody['keyCredentials@odata.type'] = "Collection(Microsoft.DirectoryServices.KeyCredential)"
            $requestBody['keyCredentials'] = @(@($existingApplication.keyCredentials) | Where { $_ -ne $null })

            $requestBody['keyCredentials'] += @(@{
                keyId               = [Guid]::NewGuid()
                type                = "AsymmetricX509Cert"
                usage               = "Verify"
                customKeyIdentifier = $customKeyIdentifier
                value               = [Convert]::ToBase64String($ClientCertificate.GetRawCertData())
                startDate           = $ClientCertificate.NotBefore.ToUniversalTime().ToString('o')
                endDate             = $ClientCertificate.NotAfter.ToUniversalTime().ToString('o')
            })
        }
        else
        {
            Write-Verbose "Key credentials already exist on application for client certificate '$($ClientCertificate.Subject)' ($($ClientCertificate.Thumbprint))" -Verbose
        }
    }

    # Initialize required AAD permissions
    $aadPermissions   = @()
    $rolePermissions  = New-Object System.Collections.Generic.HashSet[string](,[string[]]$ApplicationAadPermissions)
    $scopePermissions = New-Object System.Collections.Generic.HashSet[string](,[string[]]$DelegatedAadPermissions)
    $allPermissions   = New-Object System.Collections.Generic.HashSet[string](,[string[]]($rolePermissions + $scopePermissions))
    foreach ($permissionName in $allPermissions)
    {
        $permissionType = ''
        if ($rolePermissions.Contains($permissionName))  { $permissionType += 'Role,' }
        if ($scopePermissions.Contains($permissionName)) { $permissionType += 'Scope' }

        $aadPermissions += [pscustomobject]@{
            id   = $Script:GraphEnvironment.AadPermissions[$permissionName]
            type = $permissionType.Trim(',')
        }
    }

    if ($aadPermissions.Count -gt 0)
    {
        if (-not ($existingRequiredResourceAccess = @($existingApplication.requiredResourceAccess) | Where resourceAppId -EQ $Script:GraphEnvironment.Applications.WindowsAzureActiveDirectory.Id))
        {
            $existingRequiredResourceAccess = @{
                "resourceAccess@odata.type" = "Collection(Microsoft.DirectoryServices.ResourceAccess)"
                resourceAppId  = $Script:GraphEnvironment.Applications.WindowsAzureActiveDirectory.Id
                resourceAccess = @()
            }

            if (-not $requestBody['requiredResourceAccess'])
            {
                $requestBody['requiredResourceAccess@odata.type'] = "Collection(Microsoft.DirectoryServices.RequiredResourceAccess)"
                $requestBody['requiredResourceAccess'] = @(@($existingApplication.requiredResourceAccess) | Where { $_ -ne $null })
            }

            $requestBody['requiredResourceAccess'] += ,$existingRequiredResourceAccess
        }

        foreach ($aadPermission in $aadPermissions)
        {
            if (-not ($existingRequiredResourceAccess.resourceAccess | Where id -EQ $aadPermission.id))
            {
                Write-Verbose "Adding permission ($($aadPermission.id)) on AAD application ($($existingRequiredResourceAccess.resourceAppId))" -Verbose
                $existingRequiredResourceAccess.resourceAccess += ,$aadPermission
            }
            else
            {
                Write-Verbose "Permission ($($aadPermission.id)) already granted on AAD application ($($existingRequiredResourceAccess.resourceAppId))" -Verbose
            }
        }
    }

    # Initialize required permissions for other applications
    $permissionValue = 'user_impersonation'
    foreach ($appUri in $ResourceAccessByAppUris)
    {
        if (-not ($existingResourceApplication = Find-GraphApplication -AppUri $appUri))
        {
            Write-Error "Application '$appUri' does not exist. Unable to grant resource access for permission '$permissionValue' for this application to the target application."
            continue
        }

        if (-not ($existingRequiredResourceAccess = @($existingApplication.requiredResourceAccess) | Where resourceAppId -EQ $existingResourceApplication.appId))
        {
            $existingRequiredResourceAccess = @{
                "resourceAccess@odata.type" = "Collection(Microsoft.DirectoryServices.ResourceAccess)"
                resourceAppId  = $existingResourceApplication.appId
                resourceAccess = @()
            }

            if (-not $requestBody['requiredResourceAccess'])
            {
                $requestBody['requiredResourceAccess@odata.type'] = "Collection(Microsoft.DirectoryServices.RequiredResourceAccess)"
                $requestBody['requiredResourceAccess'] = @(@($existingApplication.requiredResourceAccess) | Where { $_ -ne $null })
            }

            $requestBody['requiredResourceAccess'] += ,$existingRequiredResourceAccess
        }

        if (-not ($permissionId = $existingResourceApplication.oauth2Permissions | Where Value -EQ $permissionValue | Select -First 1 -ExpandProperty Id))
        {
            Write-Error "OAuth2Permission for '$permissionValue' does not exist on application '$appUri' ($($existingResourceApplication.appId)) and cannot be granted to this application ($IdentifierUri)'."
            continue
        }

        if (-not ($existingRequiredResourceAccess.resourceAccess | Where id -EQ $permissionId))
        {
            Write-Verbose "Adding OAuth2 Permission for this application ('$($IdentifierUri)') to application '$appUri' ($($existingResourceApplication.appId))." -Verbose
            $existingRequiredResourceAccess.resourceAccess += ,@{
                id   = $permissionId
                type = "Scope"
            }
        }
        else
        {
            Write-Verbose "OAuth2 Permission for this application ('$($IdentifierUri)') already granted to application '$appUri' ($($existingResourceApplication.appId))." -Verbose
        }
    }

    # Initialize KnownClientApplications
    foreach ($appUri in $KnownClientApplicationsByAppUris)
    {
        if (-not ($clientApplication = Find-GraphApplication -AppUri $appUri))
        {
            Write-Error "Application '$appUri' does not exist. Unable to reference known client application relationship for this application to the target application."
            continue
        }

        if (-not $requestBody['knownClientApplications'])
        {
            $requestBody['knownClientApplications'] = @(@($existingApplication.knownClientApplications) | Where { $_ -ne $null })
        }

        if ($requestBody['knownClientApplications'] -inotcontains $clientApplication.appId)
        {
            Write-Verbose "Known client application '$appUri' ($($clientApplication.appId)) added to this application ('$($IdentifierUri)')" -Verbose
            $requestBody['knownClientApplications'] += $clientApplication.appId
        }
        else
        {
            Write-Verbose "Known client application '$appUri' ($($clientApplication.appId)) already added to this application ('$($IdentifierUri)')" -Verbose
        }
    }

    # Create or update the application
    $requestBodyAsJson = $requestBody | ConvertTo-Json -Depth 10

    if ($existingApplication)
    {
        Write-Verbose "Updating application in AAD..." -Verbose
        $apiPath = "directoryObjects/$($existingApplication.objectId)/Microsoft.DirectoryServices.Application"
        $noContentResponse = Invoke-GraphApi -Method Patch -ApiPath $apiPath -Body $requestBodyAsJson -ErrorAction Stop
        $application = Get-GraphApplication -AppUri $IdentifierUri
    }
    else
    {
        # Note: the post response does not always contain the accurate application state, so make a GET call to ensure it is accurate
        Write-Verbose "Creating application in AAD..." -Verbose
        $inaccurateResponse = Invoke-GraphApi -Method Post -ApiPath 'applications' -Body $requestBodyAsJson -ErrorAction Stop
        $application = Get-GraphObjectWithRetry -GetScript {Find-GraphApplication -AppUri $IdentifierUri} -MaxAttempts 10 -DelayInSecondsBetweenAttempts 10 -MinimumDelayInSeconds 20
    }

    # If the application does not have the user_impersonation permission, update it to include this permission
    # Note: this is a workaround to address the behavior in AzureChinaCloud which does not automatically include this permission
    if (-not $application.oauth2Permissions.value -icontains 'user_impersonation')
    {
        $requestBody['oauth2Permissions'] += @([pscustomobject]@{
            adminConsentDescription = "Allow the application to access $($application.DisplayName) on behalf of the signed-in user."
            adminConsentDisplayName = "Access $($application.DisplayName)"
            id                      = [guid]::NewGuid().ToString()
            isEnabled               = $true
            type                    = 'User'
            userConsentDescription  = "Allow the application to access $($application.DisplayName) on your behalf."
            userConsentDisplayName  = "Access $($application.DisplayName)"
            value                   = 'user_impersonation'
        })

        # Note: we must exclude the key credentials from the patch request, or null-out the key values. I haven't tried all possible combinations of which properties must be included wich cant be omitted, but I cannot just send the patch request with the update OAuth2Permissions.
        # {"odata.error":{"code":"Request_BadRequest","message":{"lang":"en","value":"Existing credential with KeyId '0d330a36-d042-41d9-b4bb-cdbb26be0595' must be sent back with null value."},"values":[{"item":"PropertyName","value":"keyCredentials"},{"item":"PropertyErrorCode","value":"KeyValueMustBeNull"}]}}
        $requestBody.Remove('keyCredentials')
        $requestBody.Remove('keyCredentials@odata.type')
        $patchRequestBodyAsJson = $requestBody | ConvertTo-Json -Depth 10

        Write-Warning "Application does not include the oauth2permission 'user_impersonation'! Updating application to include this permission..."
        $apiPath = "directoryObjects/$($application.objectId)/Microsoft.DirectoryServices.Application"
        $noContentResponse = Invoke-GraphApi -Method Patch -ApiPath $apiPath -Body $patchRequestBodyAsJson -ErrorAction Stop
        $application = Get-GraphApplication -AppUri $IdentifierUri
    }

    # Create a service principal for the application (if one doesn't already exist)
    $primaryServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $application.appId -Tags $Tags

    # Initialize OAuth2Permission grants to other (first-party) applications
    foreach ($applicationName in $OAuth2PermissionGrants)
    {
        $params = @{
            ClientApplicationId   = $Script:GraphEnvironment.Applications."$applicationName".Id
            ResourceApplicationId = $application.appId
        }

        Initialize-GraphOAuth2PermissionGrant @params
    }

    # Initialize OAuth2Permission grants to other (non-first-party) applications
    foreach ($applicationUri in $OAuth2PermissionGrantsByAppUris)
    {
        if (-not ($targetApplication = Find-GraphApplication -AppUri $applicationUri))
        {
            Write-Error "Application '$applicationUri' does not exist. Unable to grant OAuth2Permissions for this application to the target application."
            continue
        }

        $params = @{
            ClientApplicationId   = $targetApplication.appId
            ResourceApplicationId = $application.appId
        }

        Initialize-GraphOAuth2PermissionGrant @params
    }

    # Initialize directory role membership
    if ($UseDirectoryReadersRolePermission -and ($ApplicationAadPermissions -icontains 'ReadDirectoryData'))
    {
        $params = @{
            ApplicationId   = $application.appId
            RoleDisplayName = 'Directory Readers'
        }

        Initialize-GraphDirectoryRoleMembership @params
    }

    # Return the application in its final (current) state
    Get-GraphApplication -AppUri $IdentifierUri | Write-Output
}

[System.Reflection.Assembly]::LoadWithPartialName('System.Web') | Out-Null

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

Export-ModuleMember -Function @(
    'Initialize-GraphEnvironment'
    'Get-GraphEnvironmentInfo'
    #'Assert-GraphEnvironmentIsInitialized'
    #'Assert-GraphConnection'
    'Get-GraphToken'
    'Update-GraphAccessToken'
    'Invoke-GraphApi'
    'Get-GraphDefaultVerifiedDomain'
    'Find-GraphApplication'
    'Get-GraphApplication'
    'Remove-GraphObject'
    'Find-GraphApplicationDataByServicePrincipalTag'
    #'Get-GraphObjectWithRetry'
    'Get-GraphApplicationServicePrincipal'
    'Initialize-GraphApplicationServicePrincipal'
    'Update-GraphApplicationServicePrincipalTags'
    'Initialize-GraphOAuth2PermissionGrant'
    'Initialize-GraphDirectoryRoleMembership'
    'Initialize-GraphApplication'
    #'ConvertTo-QueryString'
)

# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHBmqbDjBpWK5Vts77VuqQti5
# M8GgghhlMIIEwzCCA6ugAwIBAgITMwAAAMlkTRbbGn2zFQAAAAAAyTANBgkqhkiG
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
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFGt4byt23CPSZe1aZbReSdbn/Yf/MIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEALgf6fiKiXVkDQ3DLpiHRU7QiG1IVP10T
# 71JoT0c2a7ed9mS/tKrCdCoN/MXgSQDgZg1J0vRRFBPYhJUItB5KSAtcdPoT7W0N
# 3LdQ0LirvoX8A4jj4wEuBDJXCwM21jFXJKaQFu0S8hX55LoeH9xWbJ3c1iREZncU
# RAzvjP44JmjuWv4E5a3RXorMdMRX7rkMxQsJqnt603coAjuo4c81Zrs9xENyX4/e
# tvkBwrkHPxsVtzF5zh1cwQyr/ZuTvQwP+vM0+cmmwRGJrqHJcYfri8H4nH05Bi02
# GPG3KmuzK5yJLD/acKydsGDq24VG48kgoRKYwIbRUQD6+YEkNaL8/qGCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADJZE0W2xp9sxUAAAAAAMkwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxOVowIwYJ
# KoZIhvcNAQkEMRYEFFWPSWAonnYqDBNhvBs9+UmB2RqcMA0GCSqGSIb3DQEBBQUA
# BIIBAGzd/6P0AOMSlNUm97DjXrojKejH+qFgZERBKCyBlJ/URhy4SFVZu3mrOUgH
# 1epCC6J/6z3IwQEp5psO6xji4a8E4DTJdIbUsdPlpyo20tvAGMa+GAVw7uY8SrAL
# Nl3IZqZNhUtv1igdBBHL9hJx0/wzoNMUMoHzTVsLSHM5Ff7gvH7ZJYwjL33QbgdM
# QeINZavp6ba1cjdyXn4q+A2h35nRroDCByJB0533lTRK24pwgF0Bw7pbliVl09j4
# vPY5fS/u2dAwOptxirxEeR6bsaXGjVcHmaqO0XhodaKxhmF3gRcX6eziU9P3iSPZ
# pBbnC9rM+UNSD8WrCTOo/52nlu4=
# SIG # End signature block
