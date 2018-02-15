# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#

This module contains utility functions for working with registration resources
#>

function Get-AzureRegistrationResource{
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
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
foreach ($resource in $registrationResources)
{
    $resource = Get-AzureRmResource -ResourceId $resource.ResourceId
    if ($resource.Properties.CloudId -eq $AzureStackStampCloudId)
    {
        Write-Verbose "Registration resource found:`r`n$(ConvertTo-Json $resource)"
        return $resource
    }
}

Write-Verbose "Resource could not be located with the provided parameters."

}

function Get-AzureStackActivationRecord{
param(
    [Parameter(Mandatory = $true)]
    [String] $AzureStackStampCloudId,

    [Parameter(Mandatory = $false)]
    [String] $ResourceGroupName = "AzureStack",

    [Parameter(Mandatory = $false)]
    [String] $ResourceName = "AzureStack"
)
}

Export-ModuleMember Get-AzureRegistrationResource
Export-ModuleMember Get-AzureStackActivationRecord