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

        # Indicates that the script should prompt the user to input a credential with which to acquire an access token targeting Graph.
        [Parameter(ParameterSetName='Credential_AAD')]
        [Parameter(ParameterSetName='Credential_ADFS')]
        [switch] $PromptForUserCredential,

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
        [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment', 'AzureGermanCloud', 'CustomCloud', 'ADFS')]
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
        [string] $GraphFqdn,

        [Parameter(Mandatory=$false, ParameterSetName='Credential_AAD')]
        [Parameter(Mandatory=$false, ParameterSetName='RefreshToken_AAD')]
        [Parameter(Mandatory=$false, ParameterSetName='ServicePrincipal_AAD')]
        [string] $CustomCloudARMEndpoint
    )

    if ($Environment -eq 'ADFS')
    {
        throw 'To initialize this module for use with an ADFS system, specify the "AdfsFqdn" and "GraphFqdn" parameters, and omit the "Environment" parameter.'
    }

    if ($AdfsFqdn)
    {
        $Environment = 'ADFS'
        Write-Warning "Parameters for ADFS have been specified; please note that only a subset of Graph APIs are available to be used in conjuction with ADFS."
    }

    $CustomCloudProps = ''
    if ($Environment -eq 'CustomCloud')
    {
        if(!$CustomCloudARMEndpoint){ throw "CustomCloudARMEndpoint is a required parameter for Environment CustomCloud" }
        Write-Verbose "Getting Custom Cloud properties for given ARM Endpoint '$CustomCloudARMEndpoint'" -Verbose
        $CustomCloudProps = Get-Endpoints -CloudARMEndpoint $CustomCloudARMEndpoint
    }

    if ($PromptForUserCredential)
    {
        $UserCredential = Get-Credential -Message "Please provide a credential used to access Graph. Must support non-interactive authentication flows."
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

                LoginEndpoint = [Uri]"https://login.microsoftonline.com/$DirectoryTenantId"
                GraphEndpoint = [Uri]"https://graph.windows.net/$DirectoryTenantId"

                LoginBaseEndpoint = [Uri]"https://login.microsoftonline.com/"
                GraphBaseEndpoint = [Uri]"https://graph.windows.net/"

                FederationMetadataEndpoint = [Uri]"https://login.microsoftonline.com/$DirectoryTenantId/federationmetadata/2007-06/federationmetadata.xml"
                OpenIdMetadata             = [Uri]"https://login.microsoftonline.com/$DirectoryTenantId/.well-known/openid-configuration"

                AadPermissions = [HashTable]@{
                    AccessDirectoryAsSignedInUser      = "a42657d6-7f20-40e3-b6f0-cee03008a62a"
                    EnableSignOnAndReadUserProfiles    = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
                    ReadAllGroups                      = "6234d376-f627-4f0f-90e0-dff25c5211a3"
                    ReadAllUsersBasicProfile           = "cba73afc-7f69-4d86-8450-4978e04ecd1a"
                    ReadAllUsersFullProfile            = "c582532d-9d9e-43bd-a97c-2667a28ce295"
                    ReadDirectoryData                  = "5778995a-e1bf-45b8-affa-663a9f3f4d04"
                    ManageAppsThatThisAppCreatesOrOwns = "824c81eb-e3f8-4ee6-8f6d-de7f50d565b7"
                }
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

                AadPermissions = [HashTable]@{
                    AccessDirectoryAsSignedInUser      = "a42657d6-7f20-40e3-b6f0-cee03008a62a"
                    EnableSignOnAndReadUserProfiles    = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
                    ReadAllGroups                      = "6234d376-f627-4f0f-90e0-dff25c5211a3"
                    ReadAllUsersBasicProfile           = "cba73afc-7f69-4d86-8450-4978e04ecd1a"
                    ReadAllUsersFullProfile            = "c582532d-9d9e-43bd-a97c-2667a28ce295"
                    ReadDirectoryData                  = "5778995a-e1bf-45b8-affa-663a9f3f4d04"
                    ManageAppsThatThisAppCreatesOrOwns = "b55274d3-3582-44e3-83ae-ed7873d1111d" # This permission is different than in 'AzureCloud'
                }
            }
        }

        'AzureUSGovernment'
        {
            @{
                GraphVersion  = "1.6"
                GraphResource = "https://graph.windows.net/"

                IssuerTemplate = "https://sts.windows.net/{0}/"

                LoginEndpoint = [Uri]"https://login.microsoftonline.us/$DirectoryTenantId"
                GraphEndpoint = [Uri]"https://graph.windows.net/$DirectoryTenantId"

                LoginBaseEndpoint = [Uri]"https://login.microsoftonline.us/"
                GraphBaseEndpoint = [Uri]"https://graph.windows.net/"

                FederationMetadataEndpoint = [Uri]"https://login.microsoftonline.us/$DirectoryTenantId/federationmetadata/2007-06/federationmetadata.xml"
                OpenIdMetadata             = [Uri]"https://login.microsoftonline.us/$DirectoryTenantId/.well-known/openid-configuration"

                AadPermissions = [HashTable]@{
                    AccessDirectoryAsSignedInUser      = "a42657d6-7f20-40e3-b6f0-cee03008a62a"
                    EnableSignOnAndReadUserProfiles    = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
                    ReadAllGroups                      = "6234d376-f627-4f0f-90e0-dff25c5211a3"
                    ReadAllUsersBasicProfile           = "cba73afc-7f69-4d86-8450-4978e04ecd1a"
                    ReadAllUsersFullProfile            = "c582532d-9d9e-43bd-a97c-2667a28ce295"
                    ReadDirectoryData                  = "5778995a-e1bf-45b8-affa-663a9f3f4d04"
                    ManageAppsThatThisAppCreatesOrOwns = "824c81eb-e3f8-4ee6-8f6d-de7f50d565b7"
                }
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

                AadPermissions = [HashTable]@{
                    AccessDirectoryAsSignedInUser      = "a42657d6-7f20-40e3-b6f0-cee03008a62a"
                    EnableSignOnAndReadUserProfiles    = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
                    ReadAllGroups                      = "6234d376-f627-4f0f-90e0-dff25c5211a3"
                    ReadAllUsersBasicProfile           = "cba73afc-7f69-4d86-8450-4978e04ecd1a"
                    ReadAllUsersFullProfile            = "c582532d-9d9e-43bd-a97c-2667a28ce295"
                    ReadDirectoryData                  = "5778995a-e1bf-45b8-affa-663a9f3f4d04"
                    ManageAppsThatThisAppCreatesOrOwns = "824c81eb-e3f8-4ee6-8f6d-de7f50d565b7"
                }
            }
        }

        'ADFS'
        {
            @{
                GraphVersion  = "2016-01-01"
                GraphResource = "https://$GraphFqdn/"

                IssuerTemplate = "https://$AdfsFqdn/adfs/{0}/"

                LoginEndpoint = [Uri]"https://$AdfsFqdn/adfs"
                GraphEndpoint = [Uri]"https://$GraphFqdn/$DirectoryTenantId"

                LoginBaseEndpoint = [Uri]"https://$AdfsFqdn/adfs/"
                GraphBaseEndpoint = [Uri]"https://$GraphFqdn/"

                FederationMetadataEndpoint = [Uri]"https://$AdfsFqdn/federationmetadata/2007-06/federationmetadata.xml"
                OpenIdMetadata             = [Uri]"https://$AdfsFqdn/adfs/$DirectoryTenantId/.well-known/openid-configuration"
            }
        }

                
        'CustomCloud'
        {
            @{
                GraphVersion  = "1.6"
                GraphResource = $CustomCloudProps.Graph

                IssuerTemplate = Get-IssuerTemplate -LoginUri $CustomCloudProps.Login -DirectoryTenantId $DirectoryTenantId

                LoginEndpoint = [Uri]($CustomCloudProps.Login.TrimEnd('/')+"/$DirectoryTenantId")
                GraphEndpoint = [Uri]($CustomCloudProps.Graph.TrimEnd('/')+"/$DirectoryTenantId")

                LoginBaseEndpoint = [Uri]$CustomCloudProps.Login
                GraphBaseEndpoint = [Uri]$CustomCloudProps.Graph

                FederationMetadataEndpoint = [Uri]($CustomCloudProps.Login.TrimEnd('/')+"/$DirectoryTenantId/federationmetadata/2007-06/federationmetadata.xml")
                OpenIdMetadata             = [Uri]($CustomCloudProps.Login.TrimEnd('/')+"/$DirectoryTenantId/.well-known/openid-configuration")

                AadPermissions = [HashTable]@{
                    AccessDirectoryAsSignedInUser      = "a42657d6-7f20-40e3-b6f0-cee03008a62a"
                    EnableSignOnAndReadUserProfiles    = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
                    ReadAllGroups                      = "6234d376-f627-4f0f-90e0-dff25c5211a3"
                    ReadAllUsersBasicProfile           = "cba73afc-7f69-4d86-8450-4978e04ecd1a"
                    ReadAllUsersFullProfile            = "c582532d-9d9e-43bd-a97c-2667a28ce295"
                    ReadDirectoryData                  = "5778995a-e1bf-45b8-affa-663a9f3f4d04"
                    ManageAppsThatThisAppCreatesOrOwns = "824c81eb-e3f8-4ee6-8f6d-de7f50d565b7"
                }
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
            VisualStudioCode            = [pscustomobject]@{ Id = "aebc6443-996d-45c2-90f0-388ff96faa56" }
            AzureCLI                    = [pscustomobject]@{ Id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46" }
        }

        AadPermissionScopes = [HashTable]@{
            AccessDirectoryAsSignedInUser      = "Directory.AccessAsUser.All"
            EnableSignOnAndReadUserProfiles    = "User.Read"
            ReadAllGroups                      = "Group.Read.All"
            ReadAllUsersBasicProfile           = "User.ReadBasic.All"
            ReadAllUsersFullProfile            = "User.Read.All"
            ReadDirectoryData                  = "Directory.Read.All"
            ManageAppsThatThisAppCreatesOrOwns = "Application.ReadWrite.OwnedBy"
        }
    }

    $Script:GraphEnvironment = [pscustomobject]$graphEnvironmentTemplate
    Write-Verbose "Graph Environment initialized: client-request-id: $($Script:GraphEnvironment.User.ClientRequestId)" -Verbose

    # Attempt to log-in the user
    if ($UserCredential -or $RefreshToken -or ($ClientId -and $ClientCertificate))
    {
        Update-GraphAccessToken -Verbose
    }
}


<#
.Synopsis
   Builds graph and login endpoints for a given CloudARMEndpoint
#>
function Get-Endpoints([string] $CloudARMEndpoint)
{
    $fullUri = $CloudARMEndpoint.TrimEnd('/')+"/metadata/endpoints?api-version=2015-01-01"
    $response = Invoke-RestMethod -Uri $fullUri -ErrorAction Stop -UseBasicParsing -TimeoutSec 30 -Verbose

    $EndpointProperties = @{
        Graph = $response.graphEndpoint
        Login = $response.authentication.loginEndpoint
    }

    return $EndpointProperties
}

<#
.Synopsis
   Retrieves Issuer Template for a given LoginUri
#>
function Get-IssuerTemplate([string] $LoginUri, [string] $DirectoryTenantId){

    $loginConfigurationUri = "$($LoginUri.TrimEnd('/'))/$DirectoryTenantId/.well-known/openid-configuration"
    $response = Invoke-RestMethod -Uri $loginConfigurationUri -ErrorAction Stop -UseBasicParsing -TimeoutSec 30 -Verbose
    $issuerTemplate = ($response.issuer -split "$DirectoryTenantId")[0].TRimEnd('/') + "/{0}/"
    if([string]::IsNullOrEmpty($issuerTemplate)) { throw "Error in retrieving issuer template for LoginUri: $LoginUri" }
    Write-Verbose "IssuerTemplate: $issuerTemplate" -Verbose
    return $issuerTemplate

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
        $response      = Invoke-WebRequest -UseBasicParsing -Uri $Script:GraphEnvironment.OpenIdMetadata -Verbose -TimeoutSec 90 -ErrorAction Stop
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
        $params = @{
            ClientCertificate = $ClientCertificate
            ClientId          = $ClientId
            Audience          = "$($Script:GraphEnvironment.LoginEndpoint)".Trim('/') + '/oauth2/token'
        }
        $jwt = New-SelfSignedJsonWebToken @params

        $requestBody += @{
            client_id             = $ClientId
            grant_type            = 'client_credentials'
            client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
            client_assertion      = $jwt
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
    $Script:GraphEnvironment.User.RefreshToken          = if ($response.refresh_token) { ConvertTo-SecureString $response.refresh_token -AsPlainText -Force } else { $Script:GraphEnvironment.User.RefreshToken }
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

        # The OCP Session Key used to route subsequent requests
        [Parameter()]
        [string] $SessionKey = $Global:GraphAPI_LastResponse.Headers.'ocp-aad-session-key',

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

    # Add session key header if present to route subsequent requests to the same replica
    if ($SessionKey)
    {
        $graphApiRequest.Headers['ocp-aad-session-key'] = $SessionKey
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
        $Global:GraphAPI_LastResponse = Invoke-WebRequest @graphApiRequest -UseBasicParsing -TimeoutSec 90 -ErrorAction Stop
        $response = $Global:GraphAPI_LastResponse.Content | ConvertFrom-Json
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
        # Preserve most-recent OCP session key
        if (-not $Global:GraphAPI_LastResponse.Headers.'ocp-aad-session-key')
        {
            $Global:GraphAPI_LastResponse.Headers.'ocp-aad-session-key' = $SessionKey
        }

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
            $nextLinkQueryParams = [regex]::Unescape($response."odata.nextLink".Split('?', [System.StringSplitOptions]::RemoveEmptyEntries)[1])
            $query = [System.Web.HttpUtility]::ParseQueryString($nextLinkQueryParams)
            foreach ($key in $query.Keys)
            {
                $queryParams[$key] = $query[$key]
            }

            # Note: sometimes, the next link URL is relative, and other times it is absolute!
            $absoluteOrRelativeAddress = $response."odata.nextLink".Split('?', [System.StringSplitOptions]::RemoveEmptyEntries)[0].TrimStart('/')

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
                $Global:GraphAPI_LastResponse = Invoke-WebRequest @graphApiRequest -UseBasicParsing -TimeoutSec 90 -ErrorAction Stop
                $response = $Global:GraphAPI_LastResponse.Content | ConvertFrom-Json
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

        # Preserve most-recent OCP session key
        if (-not $Global:GraphAPI_LastResponse.Headers.'ocp-aad-session-key')
        {
            $Global:GraphAPI_LastResponse.Headers.'ocp-aad-session-key' = $SessionKey
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

    if ($AppId)
    {
        $application = Invoke-GraphApi -ApiPath "applicationsByAppId/$AppId" -ErrorAction Stop
        Write-Output $application
    }
    else
    {
        $filter = if ($AppUri) {"identifierUris/any(i:i eq '$AppUri')"} else {"displayName eq '$DisplayName'"}
        $response = Invoke-GraphApi -ApiPath "applications" -QueryParameters @{ '$filter' = $filter } -ErrorAction Stop
        Write-Output $response.value
    }
}

<#
.Synopsis
   Gets an existing Graph application object (returns an error if the application is not found).
#>
function Get-GraphApplication
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
        [string] $AppId
    )

    $application = Find-GraphApplication @PSBoundParameters
    if (-not $application)
    {
        Write-Error "Application with identifier '${AppUri}${AppId}' not found"
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

        # Create a service principal for the application (if one doesn't already exist)
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
            $primaryServicePrincipal = Get-GraphObjectWithRetry -GetScript $getScript -MaxAttempts 10 -DelayInSecondsBetweenAttempts 5 -MinimumDelayInSeconds 5
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
        [string[]] $Tags = @(),

        # Indicates whether to keep or remove existing tags on the service principal. True by default.
        [Switch] $PreserveExistingTags = $true
    )

    $params = if ($ApplicationId) { @{ ApplicationId = $ApplicationId } } else { @{ ApplicationIdentifierUri = $ApplicationIdentifierUri } }
    $servicePrincipal = Get-GraphApplicationServicePrincipal @params

    $existingTags = $servicePrincipal.tags
    if (-not $PreserveExistingTags)
    {
        Write-Verbose "Removing existing tags from service principal: ($($existingTags -join ', '))" -Verbose
        $existingTags = [string[]]@()
    }

    $updatedTags  = New-Object System.Collections.Generic.HashSet[string](,[string[]]$existingTags)
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

    # https://msdn.microsoft.com/en-us/library/azure/ad/graph/api/entity-and-complex-type-reference#oauth2permissiongrant-entity

    # Ensure the application service principals exist in the directory tenant

    $clientApplicationServicePrincipal = if ($ClientApplicationId)
    {
        Initialize-GraphApplicationServicePrincipal -ApplicationId $ClientApplicationId -ErrorAction Stop
    }
    else
    {
        Get-GraphApplicationServicePrincipal -ApplicationIdentifierUri $ClientApplicationIdentifierUri -ErrorAction Stop
    }

    $resourceApplicationServicePrincipal = if ($ResourceApplicationId)
    {
        Initialize-GraphApplicationServicePrincipal -ApplicationId $ResourceApplicationId -ErrorAction Stop
    }
    else
    {
        Get-GraphApplicationServicePrincipal -ApplicationIdentifierUri $ResourceApplicationIdentifierUri -ErrorAction Stop
    }

    # Note: value=Invalid characters found in scope. Allowed characters are %x20 / %x21 / %x23-5B / %x5D-7E
    $scopesToGrant = $Scope.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)

    # Note: the permission grants do not expire, but we must provide an expiration date to the API
    $queryParameters = @{
        '$filter' = "resourceId eq '$($resourceApplicationServicePrincipal.objectId)' and clientId eq '$($clientApplicationServicePrincipal.objectId)'"
        '$top'    = '500' # Note - there is an issue with this API if you use a large page size and the result set is large as well
    }
    $existingGrant = (Invoke-GraphApi -ApiPath oauth2PermissionGrants -QueryParameters $queryParameters).Value | Select -First 1

    if (-not $existingGrant)
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

        Write-Verbose "Sleeping for 3 seconds to allow the permission grant to propagate..." -Verbose
        Start-Sleep -Seconds 3
    }
    else
    {
        Write-Verbose "Existing OAuth2PermissionGrant found: $(ConvertTo-Json $existingGrant)" -Verbose

        $existingScopes = $existingGrant.scope.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        $missingScopes  = $scopesToGrant | Where { $_ -inotin $existingScopes }

        if ($missingScopes.Count)
        {
            $fullScopes = $existingGrant.scope += (' ' + [string]::Join(' ', $missingScopes))
            Write-Verbose "Updating OAuth2PermissionGrant scopes to include missing scopes '$([string]::Join(' ', $missingScopes))' to client application service principal '$($clientApplicationServicePrincipal.appDisplayName)' on behalf of resource application '$($resourceApplicationServicePrincipal.appDisplayName)'. Full Scopes will include: '$fullScopes'" -Verbose
            $response = Invoke-GraphApi -Method Patch -ApiPath "oauth2PermissionGrants/$($existingGrant.objectId)" -Body (ConvertTo-Json ([pscustomobject]@{ scope = $fullScopes }))
        }
        else
        {
            Write-Verbose "OAuth2Permission '$Scope' already granted to client application service principal '$($clientApplicationServicePrincipal.appDisplayName)' on behalf of resource application '$($resourceApplicationServicePrincipal.appDisplayName)'. Full Scopes: '$($existingGrant.scope)'" -Verbose
        }

    }
}

<#
.Synopsis
   Idempotently creates an application role assignment for an application service principal against another application service principal in Graph with the specified properties (service principals are created if they do not exist).
#>
function Initialize-GraphAppRoleAssignment
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

        # The identifier of the app role permission to grant.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $RoleId,

        # The type of the service principal to with the permission will be granted (e.g. 'ServicePrincipal' [default value]).
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('ServicePrincipal', 'User', 'Group')]
        [string] $PrincipalType = 'ServicePrincipal'
    )

    # https://msdn.microsoft.com/en-us/library/azure/ad/graph/api/entity-and-complex-type-reference#approleassignment-entity

    # Ensure the application service principals exist in the directory tenant

    $clientApplicationServicePrincipal = if ($ClientApplicationId)
    {
        Initialize-GraphApplicationServicePrincipal -ApplicationId $ClientApplicationId -ErrorAction Stop
    }
    else
    {
        Get-GraphApplicationServicePrincipal -ApplicationIdentifierUri $ClientApplicationIdentifierUri -ErrorAction Stop
    }

    $resourceApplicationServicePrincipal = if ($ResourceApplicationId)
    {
        Initialize-GraphApplicationServicePrincipal -ApplicationId $ResourceApplicationId -ErrorAction Stop
    }
    else
    {
        Get-GraphApplicationServicePrincipal -ApplicationIdentifierUri $ResourceApplicationIdentifierUri -ErrorAction Stop
    }

    $existingAssignments = (Invoke-GraphApi -ApiPath "servicePrincipals/$($clientApplicationServicePrincipal.objectId)/appRoleAssignedTo").value
    $existingAssignment  = $existingAssignments |
        Where id -EQ $RoleId |
        Where resourceId -EQ $resourceApplicationServicePrincipal.objectId

    if (-not $existingAssignment)
    {
        Write-Verbose "Granting AppRoleAssignment '$RoleId' to application service principal '$($clientApplicationServicePrincipal.appDisplayName)' on behalf of application '$($resourceApplicationServicePrincipal.appDisplayName)'..." -Verbose
        $response = Invoke-GraphApi -Method Post -ApiPath "servicePrincipals/$($clientApplicationServicePrincipal.objectId)/appRoleAssignments" -Body (ConvertTo-Json ([pscustomobject]@{
            principalId   = $clientApplicationServicePrincipal.objectId
            principalType = $PrincipalType
            resourceId    = $resourceApplicationServicePrincipal.objectId
            id            = $RoleId
        }))
    }
    else
    {
        Write-Verbose "AppRoleAssignment '$RoleId' already granted to client application service principal '$($clientApplicationServicePrincipal.appDisplayName)' on behalf of resource application '$($resourceApplicationServicePrincipal.appDisplayName)'." -Verbose
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

    # Ensure the application service principal exists in the directory tenant
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
   Creates a new representation of a permission exposed by a resource application and grantable to a client application.
#>
function New-GraphPermissionDescription
{
    [CmdletBinding(DefaultParameterSetName='ClientAppId_ResourceAppId')]
    param
    (
        # The application identifier of the client application.
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_ResourceAppId')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_ResourceIdentifierUri')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_Resource')]
        [ValidateNotNullOrEmpty()]
        [string] $ClientApplicationId,

        # The application identifier URI of the client application.
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_ResourceAppId')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_ResourceIdentifierUri')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_Resource')]
        [ValidateNotNullOrEmpty()]
        [string] $ClientApplicationIdentifierUri,

        # The object reprsentation client application service principal.
        [Parameter(Mandatory=$true, ParameterSetName='Client_ResourceAppId')]
        [Parameter(Mandatory=$true, ParameterSetName='Client_ResourceIdentifierUri')]
        [Parameter(Mandatory=$true, ParameterSetName='Client_Resource')]
        [pscustomobject] $ClientApplicationServicePrincipal,

        # The application identifier of the resource application.
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_ResourceAppId')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_ResourceAppId')]
        [Parameter(Mandatory=$true, ParameterSetName='Client_ResourceAppId')]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceApplicationId,

        # The application identifier URI of the resource application.
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_ResourceIdentifierUri')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_ResourceIdentifierUri')]
        [Parameter(Mandatory=$true, ParameterSetName='Client_ResourceIdentifierUri')]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceApplicationIdentifierUri,

        # The object reprsentation resource application service principal.
        [Parameter(Mandatory=$true, ParameterSetName='ClientAppId_Resource')]
        [Parameter(Mandatory=$true, ParameterSetName='ClientIdentifierUri_Resource')]
        [Parameter(Mandatory=$true, ParameterSetName='Client_Resource')]
        [pscustomobject] $ResourceApplicationServicePrincipal,

        # The type of the permission.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Application', 'Delegated')]
        [string] $PermissionType,

        # The identifier of the permission.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $PermissionId,

        # Indicates whether the permission has been granted (consented).
        [Parameter()]
        [ValidateNotNull()]
        [switch] $IsConsented,

        # Indicates whether the current permission consent status should be queried.
        [Parameter()]
        [ValidateNotNull()]
        [switch] $LookupConsentStatus
    )

    # Lookup / initialize client service principal
    $ClientApplicationServicePrincipal = if ($ClientApplicationServicePrincipal)
    {
        $ClientApplicationServicePrincipal
    }
    elseif ($ClientApplicationId)
    {
        Initialize-GraphApplicationServicePrincipal -ApplicationId $ClientApplicationId -ErrorAction Stop
    }
    else
    {
        Get-GraphApplicationServicePrincipal -ApplicationIdentifierUri $ClientApplicationIdentifierUri -ErrorAction Stop
    }

    # Lookup / initialize resource service principal
    $ResourceApplicationServicePrincipal = if ($ResourceApplicationServicePrincipal)
    {
        $ResourceApplicationServicePrincipal
    }
    elseif ($ResourceApplicationId)
    {
        Initialize-GraphApplicationServicePrincipal -ApplicationId $ResourceApplicationId -ErrorAction Stop
    }
    else
    {
        Get-GraphApplicationServicePrincipal -ApplicationIdentifierUri $ResourceApplicationIdentifierUri -ErrorAction Stop
    }

    $permissionProperties = [ordered]@{
        clientApplicationId            = $ClientApplicationServicePrincipal.appId
        clientApplicationDisplayName   = $ClientApplicationServicePrincipal.appDisplayName
        resourceApplicationId          = $ResourceApplicationServicePrincipal.appId
        resourceApplicationDisplayName = $ResourceApplicationServicePrincipal.appDisplayName
    }

    $permissionProperties += [ordered]@{
        isConsented    = $IsConsented
        permissionType = $PermissionType
        permissionId   = $PermissionId
    }

    switch ($PermissionType)
    {
        'Application'
        {
            $appRole = $ResourceApplicationServicePrincipal.appRoles | Where id -EQ $PermissionId
            $permissionProperties += [ordered]@{
                permissionName        = $appRole.value
                permissionDisplayName = $appRole.displayName
                permissionDescription = $appRole.description
            }

            if ($LookupConsentStatus)
            {
                $existingAppRoleAssignments = (Invoke-GraphApi -ApiPath "servicePrincipals/$($ClientApplicationServicePrincipal.objectId)/appRoleAssignedTo").value
                $permissionProperties.isConsented = if ($existingAppRoleAssignments | Where id -EQ $PermissionId) {$true} else {$false}
            }
        }

        'Delegated'
        {
            $oAuth2Permission = $ResourceApplicationServicePrincipal.oauth2Permissions | Where id -EQ $PermissionId
            $permissionProperties += [ordered]@{
                permissionName        = $oAuth2Permission.value
                permissionDisplayName = $oAuth2Permission.adminConsentDisplayName
                permissionDescription = $oAuth2Permission.adminConsentDescription
            }

            if ($LookupConsentStatus)
            {
                $queryParameters = @{
                    '$filter' = "resourceId eq '$($ResourceApplicationServicePrincipal.objectId)' and clientId eq '$($ClientApplicationServicePrincipal.objectId)'"
                    '$top'    = '500' # Note - there is an issue with this API if you use a large page size and the result set is large as well
                }
                $existingOAuth2PermissionGrants = (Invoke-GraphApi -ApiPath oauth2PermissionGrants -QueryParameters $queryParameters).Value
		$exists = $existingOAuth2PermissionGrants | Where { "$($_.scope)".Split(' ') -contains $oAuth2Permission.value } | Select -First 1
                $permissionProperties.isConsented = if ($exists) {$true} else {$false}
            }
        }
    }

    Write-Output ([pscustomobject]$permissionProperties)
}

<#
.Synopsis
   Gets all permissions which have been granted to the specified application. If the application was created in the current directory tenant, also returns permissions which have not been consented but which are advertised as "required" in the application's manifest.
#>
function Get-GraphApplicationPermissions
{
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param
    (
        # The application identifier for which all consented permissions should be retrieved.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('appId')]
        [string] $ApplicationId
    )

    # Ensure the application service principal exists in the directory tenant
    $applicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $ApplicationId -ErrorAction Stop

    # Identify which permissions have already been granted
    $existingAppRoleAssignments = (Invoke-GraphApi -ApiPath "servicePrincipals/$($applicationServicePrincipal.objectId)/appRoleAssignedTo" -ErrorAction Stop).value
    
    # Note - there is an issue with the oauth2PermissionGrants API when using an OData filter querying for a resourceId; if the resulting collection is greater than 1000 members, the API call will return with status 200 but the response will include a malformed JSON odata error message
    # Note - there is an issue with the oauth2PermissionGrants API; any client which has more than 100 permissions will only have the first 100 permissions returned
    # Note - there is an issue with the oauth2PermissionGrants API if you use a large page size and the result set is large as well
    $existingClientOAuth2PermissionGrants = @()
    try
    {
        $existingClientOAuth2PermissionGrants = (Invoke-GraphApi -ApiPath oauth2PermissionGrants -QueryParameters @{ '$filter' = "clientId eq '$($applicationServicePrincipal.objectId)'"; '$top' = '500' } -ErrorAction Stop).Value
    }
    catch
    {
        Write-Warning "An issue occurred trying to lookup OAuth2PermissionGrants where application '$ApplicationId' is a client; Omitting this class of permissions from resulting data; Error: $_"
    }

    $existingResourceOAuth2PermissionGrants = @()
    try
    {
        $existingResourceOAuth2PermissionGrants = (Invoke-GraphApi -ApiPath oauth2PermissionGrants -QueryParameters @{ '$filter' = "resourceId eq '$($applicationServicePrincipal.objectId)'"; '$top' = '500' } -ErrorAction Stop).Value
    }
    catch
    {
        Write-Warning "An issue occurred trying to lookup OAuth2PermissionGrants where application '$ApplicationId' is a resource; Omitting this class of permissions from resulting data; Error: $_"
    }

    # Build a representation of each permission which has been granted
    $permissions = @()
    foreach ($existingAppRoleAssignment in $existingAppRoleAssignments)
    {
        $permissionParams = @{
            ClientApplicationServicePrincipal   = $applicationServicePrincipal
            ResourceApplicationServicePrincipal = Invoke-GraphApi -ApiPath "directoryObjects/$($existingAppRoleAssignment.resourceId)" -ErrorAction Stop
            PermissionType                      = 'Application'
            PermissionId                        = $existingAppRoleAssignment.id
            IsConsented                         = $true
        }
        $permissions += New-GraphPermissionDescription @permissionParams
    }
    foreach ($existingOAuth2PermissionGrant in $existingClientOAuth2PermissionGrants)
    {
        $permissionParams = @{
            ClientApplicationServicePrincipal   = $applicationServicePrincipal
            ResourceApplicationServicePrincipal = Invoke-GraphApi -ApiPath "directoryObjects/$($existingOAuth2PermissionGrant.resourceId)" -ErrorAction Stop
            PermissionType                      = 'Delegated'
            IsConsented                         = $true
        }
        foreach ($scope in $existingOAuth2PermissionGrant.scope.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
        {
            $oAuth2Permission = $permissionParams.ResourceApplicationServicePrincipal.oauth2Permissions | Where value -EQ $scope
            $permissions += New-GraphPermissionDescription @permissionParams -PermissionId $oAuth2Permission.id
        }
    }
    foreach ($existingOAuth2PermissionGrant in $existingResourceOAuth2PermissionGrants)
    {
        $permissionParams = @{
            ClientApplicationServicePrincipal   = Invoke-GraphApi -ApiPath "directoryObjects/$($existingOAuth2PermissionGrant.clientId)" -ErrorAction Stop
            ResourceApplicationServicePrincipal = $applicationServicePrincipal
            PermissionType                      = 'Delegated'
            IsConsented                         = $true
        }
        foreach ($scope in $existingOAuth2PermissionGrant.scope.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
        {
            $oAuth2Permission = $permissionParams.ResourceApplicationServicePrincipal.oauth2Permissions | Where value -EQ $scope
            $permissions += New-GraphPermissionDescription @permissionParams -PermissionId $oAuth2Permission.id
        }
    }

    # Attempt to get unconsented permissions if we can access the application object (e.g. if the application exists in the same directory in which we are currently authenticated)
    if (($application = Find-GraphApplication -AppId $ApplicationId))
    {
        foreach ($requiredResource in $application.requiredResourceAccess)
        {
            $permissionParams = @{
                ClientApplicationServicePrincipal   = $applicationServicePrincipal
                ResourceApplicationServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $requiredResource.resourceAppId
                IsConsented                         = $false
            }
            foreach ($resourceAccess in $requiredResource.resourceAccess)
            {
                $relatedConsentedPermissions = $permissions | Where resourceApplicationId -EQ $requiredResource.resourceAppId | Where permissionId -EQ $resourceAccess.id
                # $resourceAccess.type is one of: 'Role', 'Scope', 'Role,Scope', or 'Scope,Role'
                if ($resourceAccess.type -ilike '*Role*')
                {
                    if (-not ($relatedConsentedPermissions | Where permissionType -EQ 'Application'))
                    {
                        $permissions += New-GraphPermissionDescription @permissionParams -PermissionType Application -PermissionId $resourceAccess.id
                    }
                    else
                    {
                        Write-Verbose "Application permission '$($resourceAccess.id)' of type 'AppRoleAssignment' already consented for application '$($applicationServicePrincipal.appDisplayName)' ('$ApplicationId')."
                    }
                }
                if ($resourceAccess.type -ilike '*Scope*')
                {
                    if (-not ($relatedConsentedPermissions | Where permissionType -EQ 'Delegated'))
                    {
                        $permissions += New-GraphPermissionDescription @permissionParams -PermissionType Delegated -PermissionId $resourceAccess.id
                    }
                    else
                    {
                        Write-Verbose "Application permission '$($resourceAccess.id)' of type 'OAuth2PermissionGrant' already consented for application '$($applicationServicePrincipal.appDisplayName)' ('$ApplicationId')."
                    }
                }
            }
        }
    }
    else
    {
        Write-Verbose "Unable to retrieve application with appId '$ApplicationId' and will be unable to retrieve information on any additional required permissions which have not been consented." -Verbose
    }

    if (-not $permissions.Count)
    {
        if ($application)
        {
            Write-Verbose "Application '$($applicationServicePrincipal.appDisplayName)' ('$ApplicationId') does not have any consented permissions, nor does it advertise any additional required permissions in its application manifest." -Verbose
        }
        else
        {
            Write-Verbose "Application '$($applicationServicePrincipal.appDisplayName)' ('$ApplicationId') does not have any consented permissions in the current directory tenant." -Verbose
        }
    }

    Write-Output $permissions
}

<#
.Synopsis
   Grants a permission to a graph application. Use the 'New-GraphApplicationPermission' or 'Get-GraphApplicationPermissions' cmdlets to create an instance of the permission object or to see its structure.
#>
function Grant-GraphApplicationPermission
{
    [CmdletBinding()]
    param
    (
        # The graph permission description object.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject] $PermissionDescription
    )
    process
    {
        Write-Verbose "Granting permission '$($PermissionDescription.permissionName)' ($($PermissionDescription.PermissionId)) exposed by application '$($PermissionDescription.resourceApplicationDisplayName)' ($($PermissionDescription.resourceApplicationId)) of type '$($PermissionDescription.PermissionType)' to application '$($PermissionDescription.clientApplicationDisplayName)' ($($PermissionDescription.clientApplicationId))" -Verbose
        $params = @{ ClientApplicationId = $PermissionDescription.clientApplicationId; ResourceApplicationId = $PermissionDescription.resourceApplicationId }
        switch ($PermissionDescription.permissionType)
        {
            'Application' { Initialize-GraphAppRoleAssignment     @params -RoleId $PermissionDescription.permissionId   -Verbose }
            'Delegated'   { Initialize-GraphOAuth2PermissionGrant @params -Scope  $PermissionDescription.permissionName -Verbose }
        }
    }
}

<#
.Synopsis
   Grants all permissions required by an application which are specified in the application manifest. Only applies to the home directory of the application.
#>
function Grant-GraphApplicationPermissions
{
    [CmdletBinding()]
    param
    (
        # The application identifier for which all required permissions should be granted.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationId
    )
    # Ensure the application can be retrieved in the current directory tenant
    $application = Get-GraphApplication -AppId $ApplicationId -ErrorAction Stop
    $permissions = Get-GraphApplicationPermissions -ApplicationId $ApplicationId

    # Optimization / workaround for AzureChinaCloud where PATCH OAuth2PermissionGrant API has some issues
    # To mitigate we group into one permission grant with all scopes in a single POST call
    if ((Get-GraphEnvironmentInfo).Environment -eq 'AzureChinaCloud')
    {
        Write-Verbose "Grouping OAuth2PermissionGrants to avoid PATCH call..." -Verbose
        $groupedPermissions  = @($permissions | Where permissionType -EQ Application)
        $groupedPermissions += @($permissions | Where permissionType -EQ Delegated |
            Group clientApplicationId | ForEach { $_.Group | Group resourceApplicationId | ForEach {
                $params = @{
                    ClientApplicationId   = $_.Group[0].ClientApplicationId
                    ResourceApplicationId = $_.Group[0].ResourceApplicationId
                    PermissionType        = $_.Group[0].PermissionType
                    PermissionId          = $_.Group.PermissionName -join ' '
                    IsConsented           = $false
                    LookupConsentStatus   = $false
                }
                $permission = New-GraphPermissionDescription @params
                $permission.permissionName        = $permission.PermissionId
                $permission.permissionDisplayName = 'Aggregate Permission'
                $permission.permissionDescription = 'Aggregate Permission'
                Write-Output $permission
            }
        })
        $permissions = $groupedPermissions | Where {$_}
    }

    foreach ($permission in $permissions)
    {
        if ($permission.isConsented)
        {
            Write-Verbose "Permission '$($permission.permissionName)' ($($permission.PermissionId)) exposed by application '$($permission.resourceApplicationDisplayName)' ($($permission.resourceApplicationId)) of type '$($permission.PermissionType)' has already been granted to application '$($permission.clientApplicationDisplayName)' ($($permission.clientApplicationId))" -Verbose
        }
        else
        {
            Grant-GraphApplicationPermission -PermissionDescription $permission
        }
    }
}

<#
.Synopsis
   Writes a representation of the specified Graph permission descriptions to the current PowerShell host console window.
#>
function Show-GraphApplicationPermissionDescriptions
{
    [CmdletBinding()]
    param
    (
        # The graph permission description object.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject[]] $PermissionDescription,

        # The text display to use above the permission descriptions.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $DisplayHeader = 'Microsoft Azure Stack - Required Directory Permissions',

        # The text display to use below the permission descriptions.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $DisplayFooter = '(X) = Permission granted, ( ) = Permission not granted',

        # Indicates that any duplicate permissions should be filtered-out from the display.
        [Parameter()]
        [Switch] $FilterDuplicates = $true
    )
    begin
    {
        $permissions = @()
    }
    process
    {
        foreach ($permission in $PermissionDescription)
        {
            if ($FilterDuplicates -and ($permissions |
                    Where clientApplicationId   -EQ $permission.clientApplicationId |
                    Where resourceApplicationId -EQ $permission.resourceApplicationId |
                    Where permissionId          -EQ $permission.permissionId |
                    Where permissionType        -EQ $permission.permissionType))
            {
                continue
            }

            $permissions += $permission
        }
    }
    end
    {
        <# Writes a textual consent display to the console similar to this:
        +--------------------------------------------------------+
        | Microsoft Azure Stack - Required Directory Permissions |
        +--------------------------------------------------------+
        | Access Azure Stack                                     |
        |   (X) Delegated to: Microsoft Azure Stack              |
        |                                                        |
        | Access the directory as the signed-in user             |
        |   (X) Delegated to: Azure Stack                        |
        |                                                        |
        | Read all users' basic profiles                         |
        |   (X) Delegated to: Azure Stack                        |
        |                                                        |
        | Read all users' full profiles                          |
        |   (X) Delegated to: Azure Stack                        |
        |                                                        |
        | Read directory data                                    |
        |   (X) Granted to:   Azure Stack                        |
        |   (X) Granted to:   Azure Stack - Policy               |
        |   (X) Delegated to: Azure Stack                        |
        |   (X) Delegated to: Microsoft Azure Stack              |
        |                                                        |
        | Sign in and read user profile                          |
        |   (X) Delegated to: Azure Stack                        |
        |   (X) Delegated to: Microsoft Azure Stack              |
        |                                                        |
        +--------------------------------------------------------+
        | (X) = Permission granted, ( ) = Permission not granted |
        +--------------------------------------------------------+
        #>

        $header = $DisplayHeader
        $footer = $DisplayFooter

        $lines = @()
        foreach ($permissionGroup in @($permissions | Sort resourceApplicationDisplayName, permissionDisplayName | Group permissionId))
        {
            $lines += "{0}" -f $permissionGroup.Group[0].permissionDisplayName
            foreach ($permission in @($permissionGroup.Group | Sort permissionType, clientApplicationDisplayName))
            {
                $lines += "  {0} {1} {2}" -f @(
                    ($consentDisplay = if ($permission.isConsented) {'(X)'} else {'( )'})
                    ($typeDisplay = switch ($permission.permissionType) { 'Application' { 'Granted to:  ' }; 'Delegated' { 'Delegated to:' } })
                    $permission.clientApplicationDisplayName
                )
            }
            $lines += ''
        }

        $max = (($lines + @($header, $footer)) | Measure Length -Maximum).Maximum
        $div = '+-{0}-+' -f (New-Object string('-', $max))

        $lines = @(
            $div
            '| {0} |' -f "$header".PadRight($max)
            $div
            $lines | ForEach { '| {0} |' -f "$_".PadRight($max) }
            $div
            '| {0} |' -f "$footer".PadRight($max)
            $div
        )

        foreach ($line in $lines)
        {
            Write-Host $line
        }
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

        # The client certificates used to authenticate with graph as the application / service principal.
        [Parameter(ParameterSetName='Cert')]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]] $ClientCertificate = @(),

        # The thumbprint of the client certificate used to authenticate with graph as the application / service principal.
        [Parameter(ParameterSetName='Thumbprint')]
        [ValidateNotNull()]
        [ValidatePattern('^([0-9A-Fa-f]{2})*$')]
        [string] $ClientCertificateThumbprint = $null,

        # The set of AAD permissions required directly by the application in the context of its service principal.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'ReadDirectoryData',
            'ManageAppsThatThisAppCreatesOrOwns'
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
            'VisualStudioCode',
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

        # Indicates that the application service principal should have all declared application permissions consented-to. True by default.
        [Parameter()]
        [Switch] $ConsentToAppPermissions = $true,

        # Indicates that any existing client certificates associated to this application should be removed. False by default.
        [Parameter()]
        [Switch] $RemoveExistingClientCertificates
    )

    if ($ClientCertificateThumbprint)
    {
        $ClientCertificate += Get-Item "Cert:\LocalMachine\My\$ClientCertificateThumbprint" -ErrorAction Stop
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
    $requestBody['keyCredentials@odata.type'] = "Collection(Microsoft.DirectoryServices.KeyCredential)"
    $requestBody['keyCredentials'] = @(@($existingApplication.keyCredentials) | Where { $_ -ne $null })
    if ($RemoveExistingClientCertificates)
    {
        $requestBody['keyCredentials'] = @()
    }
    foreach ($cert in $ClientCertificate)
    {
        $customKeyIdentifier = [Convert]::ToBase64String($cert.GetCertHash())
        if (-not (@($requestBody['keyCredentials']) | Where customKeyIdentifier -EQ $customKeyIdentifier))
        {
            Write-Verbose "Adding new key credentials to application using client certificate '$($cert.Subject)' ($($cert.Thumbprint))" -Verbose

            $requestBody['keyCredentials'] += @(,([pscustomobject]@{
                keyId               = [Guid]::NewGuid()
                type                = "AsymmetricX509Cert"
                usage               = "Verify"
                customKeyIdentifier = $customKeyIdentifier
                value               = [Convert]::ToBase64String($cert.GetRawCertData())
                startDate           = $cert.NotBefore.ToUniversalTime().ToString('o')
                endDate             = $cert.NotAfter.ToUniversalTime().ToString('o')
            }))
        }
        else
        {
            Write-Verbose "Key credentials already exist on application for client certificate '$($cert.Subject)' ($($cert.Thumbprint))" -Verbose
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
                
                if (-not $requestBody['requiredResourceAccess'])
                {
                    $requestBody['requiredResourceAccess@odata.type'] = "Collection(Microsoft.DirectoryServices.RequiredResourceAccess)"
                    $requestBody['requiredResourceAccess'] = @(@($existingApplication.requiredResourceAccess) | Where { $_ -ne $null })
                }
                
                $existingRequiredResourceAccess.resourceAccess += ,$aadPermission
            }
            else
            {
                Write-Verbose "Permission ($($aadPermission.id)) already advertised on AAD application ($($existingRequiredResourceAccess.resourceAppId))" -Verbose
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
        Start-Sleep -Seconds 5 # Delay between PATCH and GET to mitigate replication delay issues
        $application = Get-GraphApplication -AppUri $IdentifierUri
    }
    else
    {
        # Note: the post response does not always contain the accurate application state, so make a GET call to ensure it is accurate
        Write-Verbose "Creating application in AAD..." -Verbose
        $inaccurateResponse = Invoke-GraphApi -Method Post -ApiPath 'applications' -Body $requestBodyAsJson -ErrorAction Stop
        $application = Get-GraphObjectWithRetry -GetScript {Find-GraphApplication -AppUri $IdentifierUri} -MaxAttempts 10 -DelayInSecondsBetweenAttempts 5 -MinimumDelayInSeconds 5
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
        
		Start-Sleep -Seconds 5 # Delay between PATCH and GET to mitigate replication delay issues

        $application = Get-GraphApplication -AppUri $IdentifierUri
    }

    # Create a service principal for the application (if one doesn't already exist)
    $primaryServicePrincipal = Initialize-GraphApplicationServicePrincipal -ApplicationId $application.appId -Tags $Tags

    # "Consent" to application permissions
    if ($ConsentToAppPermissions)
    {
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

        Grant-GraphApplicationPermissions -ApplicationId $application.appId
    }

    # Return the application in its final (current) state
    Get-GraphApplication -AppUri $IdentifierUri | Write-Output
}

<#
.Synopsis
   Creates or updates an application in Graph with an implicit service principal and the specified properties.
#>
function Initialize-GraphApplicationOwner
{
    [CmdletBinding(DefaultParameterSetName='ById')]
    param
    (
        # The application identifier.
        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationId,

        # The application identifier URI.
        [Parameter(Mandatory=$true, ParameterSetName='ByUri')]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationIdentifierUri,

        # The identifier of the object (user, service principal, etc.) to which ownership of the target application should be granted.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $OwnerObjectId
    )

    # Lookup the target objects
    $params      = if ($ApplicationId) {@{ AppId = $ApplicationId }} else {@{ AppUri = $ApplicationIdentifierUri }}
    $application = Get-GraphApplication @params -ErrorAction Stop
    $owner       = Invoke-GraphApi -ApiPath "directoryObjects/$OwnerObjectId" -ErrorAction Stop

    # Lookup the existing owners and grant ownership if not already granted
    $owners = (Invoke-GraphApi -Method Get -ApiPath "applications/$($application.objectId)/owners" -ErrorAction Stop).value
    if ($owners | Where objectId -EQ $OwnerObjectId)
    {
        Write-Verbose "Object '$($owner.objectId)' of type '$($owner.objectType)' is already an owner of the application '$($application.displayName)' ($($application.appId))" -Verbose
    }
    else
    {
        Write-Verbose "Granting ownership of application '$($application.displayName)' ($($application.appId)) to object '$($owner.objectId)' of type '$($owner.objectType)'." -Verbose
        Invoke-GraphApi -Method Post -ApiPath "applications/$($application.objectId)/`$links/owners" -Verbose -ErrorAction Stop -Body (ConvertTo-Json ([pscustomobject]@{
            url = '{0}/directoryObjects/{1}' -f $Script:GraphEnvironment.GraphEndpoint.AbsoluteUri.TrimEnd('/'), $OwnerObjectId
        }))
    }
}

<#
.Synopsis
   Updates the set of client certificates (key credentials) usable by an application in Graph.
#>
function Set-GraphApplicationClientCertificates
{
    [CmdletBinding(DefaultParameterSetName='ById')]
    param
    (
        # The application identifier.
        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationId,

        # The application identifier URI.
        [Parameter(Mandatory=$true, ParameterSetName='ByUri')]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationIdentifierUri,

        # The client certificates used to authenticate with graph as the application / service principal.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]] $ClientCertificate = @()
    )

    # Lookup the target application
    $params      = if ($ApplicationId) {@{ AppId = $ApplicationId }} else {@{ AppUri = $ApplicationIdentifierUri }}
    $application = Get-GraphApplication @params -ErrorAction Stop

    # Initialize the application key credentials with which it can authenticate
    $requestBody = @{
        'keyCredentials@odata.type' = 'Collection(Microsoft.DirectoryServices.KeyCredential)'
        'keyCredentials'            = @()
    }

    foreach ($cert in $ClientCertificate)
    {
        $customKeyIdentifier = [Convert]::ToBase64String($cert.GetCertHash())
        if (-not (@($requestBody['keyCredentials']) | Where customKeyIdentifier -EQ $customKeyIdentifier))
        {
            Write-Verbose "Adding key credential for application using client certificate '$($cert.Subject)' ($($cert.Thumbprint))" -Verbose

            $requestBody['keyCredentials'] += @(,([pscustomobject]@{
                keyId               = [Guid]::NewGuid()
                type                = "AsymmetricX509Cert"
                usage               = "Verify"
                customKeyIdentifier = $customKeyIdentifier
                value               = [Convert]::ToBase64String($cert.GetRawCertData())
                startDate           = $cert.NotBefore.ToUniversalTime().ToString('o')
                endDate             = $cert.NotAfter.ToUniversalTime().ToString('o')
            }))
        }
        else
        {
            Write-Verbose "Key credentials already added to application for client certificate '$($cert.Subject)' ($($cert.Thumbprint))" -Verbose
        }
    }

    $requestBodyAsJson = $requestBody | ConvertTo-Json -Depth 10
    $apiPath           = "applications/$($application.objectId)"
    
    Write-Verbose "Updating key credentials on application '$($application.displayName)' ($($application.appId))..." -Verbose
    $noResponse = Invoke-GraphApi -Method Patch -ApiPath $apiPath -Body $requestBodyAsJson -Verbose -ErrorAction Stop
}

<#
.Synopsis
   Creates a new self-signed Json Web Token to use as a client assertion or in other Graph API calls.
#>
function New-SelfSignedJsonWebToken
{
    [CmdletBinding()]
    param
    (
        # The client certificate used to sign the token.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate,

        # The client ID (appId) for the token.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClientId,

        # The target audience for the token.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Audience,

        # The number of seconds relative to the current UTC datetime before which the token will be invalid. Default is -90 (90 seconds ago from 'now').
        [Parameter()]
        [int] $NotBeforeSecondsRelativeToNow = -90,

        # The number of seconds relative to the current UTC datetime until which the token will be valid. Default is 3600 (one hour from 'now').
        [Parameter()]
        [int] $ExpirationSecondsRelativeToNow = 3600
    )

    function ConvertTo-Base64UrlEncode([byte[]]$bytes) { [System.Convert]::ToBase64String($bytes).Replace('/','_').Replace('+','-').Trim('=') }

    $tokenHeaders = [ordered]@{
        alg = 'RS256'
        x5t = ConvertTo-Base64UrlEncode $ClientCertificate.GetCertHash()
    }

    $currentUtcDateTimeInSeconds = ([datetime]::UtcNow - [datetime]'1970-01-01 00:00:00').TotalSeconds

    $tokenClaims = [ordered]@{
        aud = $Audience
        exp = [long]($currentUtcDateTimeInSeconds + $ExpirationSecondsRelativeToNow)
        iss = $ClientId
        jti = [guid]::NewGuid().ToString()
        nbf = [long]($currentUtcDateTimeInSeconds + $NotBeforeSecondsRelativeToNow)
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
    # Furthermore, the private key is likely not marked as exportable, so we cannot "simply" instantiate a new RSACryptoServiceProvider instance.
    # We must first create new CSP parameters with a "better" cryptographic service provider that supports SHA256, and use those parameters
    # to instantiate a "better" RSACryptoServiceProvider which also supports SAH256. Failure to do this will result in the following error:
    # "Exception calling "CreateSignature" with "1" argument(s): "Invalid algorithm specified."
    # It may be possible to bypass this issue of the certificate is generated with the "correct" cryptographic service provider, but if the certificate
    # was created by a CA or if the provider type was not the "correct" type, then this workaround must be used.
    # Note - this assumes certificate is installed in the local machine store.
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

    return ($tokenParts -join '.')
}

<#
.Synopsis
   Adds a new client certificate to a graph application / service principal if it is not already added.
#>
function Add-GraphApplicationClientCertificate
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        # The application identifier.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationId,

        # A client certificate used to authenticate with graph as the application / service principal.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $CurrentClientCertificate,

        # The new client certificate to add to be used to authenticate with graph as the application / service principal.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]] $NewClientCertificate
    )

    # https://msdn.microsoft.com/en-us/Library/Azure/Ad/Graph/api/functions-and-actions#AddKey

    $application = Invoke-GraphApi -ApiPath "applicationsByAppId/$ApplicationId" -ErrorAction Stop

    $jwt = $null

    foreach ($newCert in $NewClientCertificate)
    {
        $customKeyIdentifier = [Convert]::ToBase64String($newCert.GetCertHash())
        if (($keyCredential = $application.keyCredentials | Where customKeyIdentifier -EQ $customKeyIdentifier))
        {
            Write-Verbose "Application '$($application.displayName)' ($ApplicationId) already has certificate '$($newCert.Thumbprint)' added under keyId '$($keyCredential.keyId)' and customKeyIdentifier '$customKeyIdentifier'" -Verbose
            Write-Verbose "keyCredential: $(ConvertTo-Json $keyCredential -Depth 4)"
            Write-Output $keyCredential.keyId
            continue
        }

        if (-not $jwt)
        {
            $params = @{
                ClientCertificate = $CurrentClientCertificate
                ClientId          = $ApplicationId

                # Audience needs to be AAD Graph SPN
                Audience = (Get-GraphEnvironmentInfo).Applications.WindowsAzureActiveDirectory.Id

                # The token lifespan should not exceed 10 minutes. Where token lifespan is the difference between EXP and NBF claims.
                NotBeforeSecondsRelativeToNow  = -90
                ExpirationSecondsRelativeToNow = 500
            }
            $jwt = New-SelfSignedJsonWebToken @params
        }

        $params = @{
            Method  = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
            ApiPath = "applicationsByAppId/$ApplicationId/addKey"
            Body    = (ConvertTo-Json -Depth 4 -Compress ([pscustomobject]@{
                keyCredential = @{
                    type                = "AsymmetricX509Cert"
                    usage               = "Verify"
                    customKeyIdentifier = $customKeyIdentifier
                    value               = [Convert]::ToBase64String($newCert.GetRawCertData())
                    startDate           = $newCert.NotBefore.ToUniversalTime().ToString('o')
                    endDate             = $newCert.NotAfter.ToUniversalTime().ToString('o')
                }
                proof = "Bearer $jwt"
            }))
        }

        $response = Invoke-GraphApi @params -ErrorAction Stop
        $keyId    = $response.value[0].keyId
        Write-Verbose "Response: $(ConvertTo-Json $response -Depth 4)"
        Write-Verbose "Client certificate added to application '$($application.displayName)' ($ApplicationId) with thumbprint '$($newCert.Thumbprint)' under keyId '$keyId' and customKeyIdentifier '$customKeyIdentifier'" -Verbose
        Write-Output $keyId
    }
}

<#
.Synopsis
   Removes a client certificate from a graph application / service principal based on the associated keyId.
#>
function Remove-GraphApplicationClientCertificate
{
    [CmdletBinding()]
    param
    (
        # The application identifier.
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationId,

        # A client certificate used to authenticate with graph as the application / service principal.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $CurrentClientCertificate,

        # The client certificate to remove from the application to no-longer be used to authenticate with graph as the application / service principal.
        # If no certificate is provided, all certificates will be removed except for the one used to authenticate.
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificateToRemove = $null
    )

    # https://msdn.microsoft.com/en-us/Library/Azure/Ad/Graph/api/functions-and-actions#removeKey

    $application = Invoke-GraphApi -ApiPath "applicationsByAppId/$ApplicationId" -ErrorAction Stop

    if ($ClientCertificateToRemove)
    {
        $customKeyIdentifier = [Convert]::ToBase64String($ClientCertificateToRemove.GetCertHash())
        if (-not ($keyCredential = $application.keyCredentials | Where customKeyIdentifier -EQ $customKeyIdentifier))
        {
            Write-Verbose "Application '$($application.displayName)' ($ApplicationId) does not have certificate '$($ClientCertificateToRemove.Thumbprint)' added under customKeyIdentifier '$customKeyIdentifier' or has already had this certificate ." -Verbose
            return
        }
        $keyCredentialsToRemove = @($keyCredential)
    }
    else
    {
        $customKeyIdentifier = [Convert]::ToBase64String($CurrentClientCertificate.GetCertHash())
        $keyCredentialsToRemove = $application.keyCredentials | Where customKeyIdentifier -NE $customKeyIdentifier
    }

    if (-not $keyCredentialsToRemove.Count)
    {
        Write-Verbose "Application '$($application.displayName)' ($ApplicationId) does not have any certificates besides '$($CurrentClientCertificate.Thumbprint)' added under customKeyIdentifier '$customKeyIdentifier' which cannot be removed." -Verbose
        return
    }

    $params = @{
        ClientCertificate = $CurrentClientCertificate
        ClientId          = $ApplicationId

        # Audience needs to be AAD Graph SPN
        Audience = (Get-GraphEnvironmentInfo).Applications.WindowsAzureActiveDirectory.Id

        # The token lifespan should not exceed 10 minutes. Where token lifespan is the difference between EXP and NBF claims.
        NotBeforeSecondsRelativeToNow  = -90
        ExpirationSecondsRelativeToNow = 500
    }
    $jwt = New-SelfSignedJsonWebToken @params
    
    foreach ($keyCredential in $keyCredentialsToRemove)
    {
        $params = @{
            Method  = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
            ApiPath = "applicationsByAppId/$ApplicationId/removeKey"
            Body    = (ConvertTo-Json -Depth 4 -Compress ([pscustomobject]@{
                keyId = $keyCredential.keyId
                proof = "Bearer $jwt"
            }))
        }

        $noResponse = Invoke-GraphApi @params -ErrorAction Stop
        Write-Verbose "Removed client certificate on application '$($application.displayName)' ($ApplicationId) with thumbprint '$($ClientCertificateToRemove.Thumbprint)' under keyId '$($keyCredential.keyId)' and customKeyIdentifier '$($keyCredential.customKeyIdentifier)' [$($keyCredential.startDate) - $($keyCredential.endDate)]" -Verbose
    }
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
    'Get-Endpoints'
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
    'Initialize-GraphAppRoleAssignment'
    'Initialize-GraphDirectoryRoleMembership'
    'New-GraphPermissionDescription'
    'Get-GraphApplicationPermissions'
    'Grant-GraphApplicationPermission'
    'Grant-GraphApplicationPermissions'
    'Show-GraphApplicationPermissionDescriptions'
    'Initialize-GraphApplication'
    'Initialize-GraphApplicationOwner'
    'Set-GraphApplicationClientCertificates'
    'New-SelfSignedJsonWebToken'
    'Add-GraphApplicationClientCertificate'
    'Remove-GraphApplicationClientCertificate'
    #'ConvertTo-QueryString'
)
