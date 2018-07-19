# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#

This module contains utility functions for working with registration resources
#>


<#

.SYNOPSIS

Uses the current Azure Powershell context to retrieve registration resources in Azure from the default resource group
and with the default resource name (if $AzureStackStampCloudId is provided)

#>
function Get-AzureRegistrationResource{
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [String] $AzureStackStampCloudId,

    [Parameter(Mandatory = $false)]
    [String] $ResourceGroupName = "AzureStack",

    [Parameter(Mandatory = $false)]
    [String] $ResourceName = "AzureStack"
)

    $VerbosePreference     = "Continue"
    $ErrorActionPreference = "Stop"

    Write-Verbose "Searching for registration resource using the provided parameters"
    $registrationResources = Find-AzureRmResource -ResourceNameContains $ResourceName -ResourceType 'Microsoft.AzureStack/registrations' -ResourceGroupNameEquals $ResourceGroupName
    $registrations = @()
    foreach ($resource in $registrationResources)
    {
        $resource = Get-AzureRmResource -ResourceId $resource.ResourceId
        if($AzureStackStampCloudId)
        {
            if ($resource.Properties.CloudId -eq $AzureStackStampCloudId)
            {
                Write-Verbose "Registration resource found:`r`n$(ConvertTo-Json $resource)"
                return $resource
            }
        }
        else
        {
            $registrations += $resource
        }
    }

    if ($registrations.Count -gt 0)
    {
        Write-Verbose "Registrations: $registrations"
    }
    else
    {
        Write-Verbose "Registration resource(s) could not be located with the provided parameters."
    }
}


<#

.SYNOPSIS

If the context is set to the Azure Stack environment administrator this will retrieve the activation record in the Azure Stack
if it has been created via successful registration run. 

#>
function Get-AzureStackActivationRecord{

    $currentContext = Get-AzureRmContext
    $contextDetails = @{
        Account          = $currentContext.Account
        Environment      = $currentContext.Environment
        Subscription     = $currentContext.Subscription
        Tenant           = $currentContext.Tenant
    }

    if (-not($currentContext.Subscription))
    {
        Write-Verbose "Current Azure context:`r`n$(ConvertTo-Json $ContextDetails)"
        Throw "Current Azure context is not currently set. Please call Login-AzureRmAccount to set the Powershell context to Azure Stack service administrator."
    }

    $subscriptions = Get-AzureRmSubscription
    if ($subscriptions.Count -eq 1)
    {
        if ($subscriptions.Name -eq 'Default Provider Subscription')
        {
            try
            {
                $activation = Get-AzureRmResource -ResourceId "/subscriptions/$($subscriptions.Id)/resourceGroups/azurestack-activation/providers/Microsoft.AzureBridge.Admin/activations/default"
                return $activation
            }
            catch
            {
                Write-Warning "Activation record not found. Please register your Azure Stack with Azure: `r`nhttps://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register`r`n$_"
            }
        }
        else
        {
            Write-Warning "Unable to retrieve activation record using the current Azure Powershell context."
        }
    }
    else
    {
        foreach ($sub in $subscriptions)
        {
            try
            {
                Get-AzureRmResource -ResourceId "/subscriptions/$($sub.Id)/resourceGroups/azurestack-activation/providers/Microsoft.AzureBridge.Admin/activations/default"
            }
            catch
            {
                Write-Warning "Activation record not found. $_"
            }
        }
    }
}


<#

.SYNOPSIS

Sets the current azure powershell context to that of the Azure Stack environment administrator

#>
function Set-AzureStackPowershellContext{
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ServiceAdminUsername,

    [Parameter(Mandatory = $true)]
    [String] $ServiceAdminPassword,

    [Parameter(Mandatory = $true)]
    [String] $ExternalDomain,

    [Parameter(Mandatory = $true)]
    [String] $ArmEndpoint,

    [Parameter(Mandatory = $false)]
    [String] $AadTenantId
)

    

    $endpoints = Get-ResourceManagerMetaDataEndpoints -ArmEndpoint $ArmEndpoint

    $aadAuthorityEndpoint = $endpoints.authentication.loginEndpoint
    $aadResource = $endpoints.authentication.audiences[0]
    $galleryEndpoint =$endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint

    $azureEnvironmentParams = @{
        Name                                     = "AzureStack"
        ActiveDirectoryEndpoint                  = $($aadAuthorityEndpoint.TrimEnd("/") + "/")
        ActiveDirectoryServiceEndpointResourceId = $aadResource
        ResourceManagerEndpoint                  = $ArmEndpoint
        GalleryEndpoint                          = $galleryEndpoint
        GraphEndpoint                            = $graphEndpoint
        GraphAudience                            = $graphEndpoint
        AzureKeyVaultDnsSuffix                   = "adminvault.$ExternalDomain".ToLowerInvariant()
        EnableAdfsAuthentication                 = $aadAuthorityEndpoint.TrimEnd("/").EndsWith("/adfs", [System.StringComparison]::OrdinalIgnoreCase)
    }

    $environment = Add-AzureRmEnvironment @azureEnvironmentParams
    $environment = Get-AzureRmEnvironment -Name "AzureStack"

    $Credential = New-Object System.Management.Automation.PSCredential ($ServiceAdminUsername,(ConvertTo-SecureString -String $ServiceAdminPassword -AsPlainText -Force))

    if ($AadTenantId)
    {
        Add-AzureRmAccount -Environment $environment -Credential $Credential -TenantId $AadTenantId
    }
    else
    {
        Add-AzureRmAccount -Environment $environment -Credential $Credential
    }

    $adminSubscription = Get-AzureRmSubscription -SubscriptionName "Default Provider Subscription"
    Set-AzureRmContext -SubscriptionId $adminSubscription.SubscriptionId
}

################################################################
# Helper Functions
################################################################

<#

.SYNOPSIS

Gets the resource manager endpoints for use in the Set-AzureStackPowershellContext function

#>
function Get-ResourceManagerMetaDataEndpoints{
param
(
    [Parameter(Mandatory=$true)]
    [String] $ArmEndpoint
)

    $endpoints = Invoke-RestMethod -Method Get -Uri "$($ArmEndpoint.TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -Verbose
    Write-Verbose -Message "Endpoints: $(ConvertTo-Json $endpoints)" -Verbose

    Write-Output $endpoints
}

Export-ModuleMember Get-AzureRegistrationResource
Export-ModuleMember Get-AzureStackActivationRecord
Export-ModuleMember Set-AzureStackPowershellContext
