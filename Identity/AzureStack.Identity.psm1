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
function Get-DirectoryTenantIdentifier
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                    Position=0)]
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
   function New-ADGraphServicePrincipal
   {
       [CmdletBinding()]
       Param
       (
           # Display Name of the Service Principal
           [Parameter(Mandatory=$true,
                      Position=0)]
           [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
           $DisplayName,
   
           # Adfs Machine name
           [Parameter(Mandatory=$false,
                      Position=1)]
           [string]
           $AdfsMachineName = "mas-adfs01.azurestack.local",

		   # Domain Administrator Credential to create Service Principal
           [Parameter(Mandatory=$true,
                      Position=2)]
           [System.Management.Automation.PSCredential]
           $AdminCredential,

           # Switch to delete existing Service Principal with Provided Display Name and recreate
           [Parameter(Mandatory=$false)]
           [switch]
           $DeleteAndCreateNew
       )
       Write-Verbose "Creating a Certificate for the Service Principal.."
       $clientCertificate = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject "CN=$DisplayName" -KeySpec KeyExchange
       $scriptBlock = {
            param ([string] $DisplayName, [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate, [bool] $DeleteAndCreateNew)
            $VerbosePreference="Continue"
            $ErrorActionPreference = "stop"

            Import-Module 'ActiveDirectory' -Verbose:$false 4> $null

            # Application Group Name
            $applicationGroupName = $DisplayName+"-AppGroup"
            $applicationGroupDescription = "Application group for $DisplayName"
            $shellSiteDisplayName = $DisplayName
            $shellSiteRedirectUri = "https://localhost/".ToLowerInvariant()
            $shellSiteApplicationId = [guid]::NewGuid().ToString()
            $shellSiteClientDescription = "Client for $DisplayName"
            $defaultTimeOut = New-TimeSpan -Minutes 5

            if($DeleteAndCreateNew)
            {
                $applicationGroup = Get-GraphApplicationGroup -ApplicationGroupName $applicationGroupName -Timeout $defaultTimeOut
                Write-Verbose $applicationGroup
                if ($applicationGroup)
                {
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