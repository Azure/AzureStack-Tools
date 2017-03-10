# Copyright (c) Microsoft Corporation. All rights reserved.
# {FileName} {Version} {DateTime}
# {BuildRepo} {BuildBranch} {BuildType}-{BuildArchitecture}

#requires -Version 4.0
#requires -Module AzureRM.Profile
#requires -Module AzureRM.Resources

<#
.SYNOPSIS
    Initializes the Azure PowerShell environment for use with an Azure Stack Environment.
#>
[CmdletBinding(DefaultParameterSetName='UserCredential')]
param
(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string] $Name = 'AzureStack',

    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [ValidateScript({ $_.Scheme -eq [System.Uri]::UriSchemeHttps })]
    [System.Uri] $ResourceManagerEndpoint,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $DirectoryTenantId,

    [Parameter(Mandatory=$true, ParameterSetName='UserCredential')]
    [ValidateNotNull()]
    [PSCredential] $Credential,

    [Parameter(Mandatory=$true, ParameterSetName='ServicePrincipal')]
    [ValidateNotNullOrEmpty()]
    [string] $ApplicationId,

    [Parameter(Mandatory=$true, ParameterSetName='ServicePrincipal')]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^([0-9A-Fa-f]{2})*$')]
    [string] $CertificateThumbprint,

    # Optional subscription to select as the active / default subscription.
    [Parameter(Mandatory=$false, ParameterSetName='ServicePrincipal')]
    [ValidateNotNullOrEmpty()]
    [string] $SubscriptionId
)

if (($azureEnvironment = Get-AzureRmEnvironment | Where Name -EQ $Name))
{
    Write-Verbose -Message "Azure Environment '$Name' already initialized" -Verbose
}
else
{
    $endpoints = Invoke-RestMethod -Method Get -Uri "$($ResourceManagerEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -Verbose
    Write-Verbose -Message "Endpoints: $(ConvertTo-Json $endpoints)" -Verbose

    $azureEnvironmentParams = @{
        Name                                     = $Name
        ActiveDirectoryEndpoint                  = $endpoints.authentication.loginEndpoint.TrimEnd('/') + "/"
        ActiveDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
        AdTenant                                 = $DirectoryTenantId
        ResourceManagerEndpoint                  = $ResourceManagerEndpoint
        GalleryEndpoint                          = $endpoints.galleryEndpoint
        GraphEndpoint                            = $endpoints.graphEndpoint
        GraphAudience                            = $endpoints.graphEndpoint
        EnableAdfsAuthentication                 = $endpoints.authentication.loginEndpoint.TrimEnd("/").EndsWith("/adfs", [System.StringComparison]::OrdinalIgnoreCase)
    }

    $azureEnvironment = Add-AzureRmEnvironment @azureEnvironmentParams
    $azureEnvironment = Get-AzureRmEnvironment $azureEnvironmentParams.Name
}

$azureAccountParams = @{
    Environment = $azureEnvironment
    TenantId    = $DirectoryTenantId
}

if ($Credential)
{
    $azureAccountParams += @{ Credential = $Credential }
}
else
{
    $azureAccountParams += @{
        ServicePrincipal      = $true
        ApplicationId         = $ApplicationId
        CertificateThumbprint = $CertificateThumbprint
    }
}

$azureAccount = Add-AzureRmAccount @azureAccountParams -Verbose

if ($SubscriptionId)
{
    $subscription = Select-AzureRmSubscription -SubscriptionId $SubscriptionId -TenantId $DirectoryTenantId -Verbose -ErrorAction Stop
    Write-Verbose "Using account: $(ConvertTo-Json $subscription)" -Verbose
}
else
{
    Write-Verbose "Using account: $(ConvertTo-Json $azureAccount.Context)" -Verbose
}
