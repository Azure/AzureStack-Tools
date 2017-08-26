# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.EXAMPLE

.NOTES

#>

[CmdletBinding()]
param(    

    [Parameter(Mandatory=$true)]
    [PSCredential] $CloudAdminCredential,

    [Parameter(Mandatory=$true)]
    [String] $AzureSubscriptionId,

    [Parameter(Mandatory=$true)]
    [String] $AlternateSubscriptionId,

    [Parameter(Mandatory = $true)]
    [String] $JeaComputerName,

    [Parameter(Mandatory = $false)]
    [String] $ResourceGroupName = 'azurestack',

    [Parameter(Mandatory = $false)]
    [String] $RegistrationName,

    [Parameter(Mandatory = $false)]
    [String] $AzureEnvironmentName = "AzureCloud",

    [Parameter(Mandatory=$false)]
    [String] $AzureResourceType = "Microsoft.AzureStack/registrations",

    [Parameter(Mandatory=$false)]
    [String] $AzureStackResourceType = "Microsoft.AzureBridge.Admin/activations"
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

Import-Module C:\Users\AzureStackAdmin\Desktop\Registration\CommonRegistrationActions.psm1 -Force

Resolve-DomainAdminStatus -Verbose
Write-Verbose "Logging in to Azure."
$connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -Verbose

try
{
    $session = Initalize-PrivilegedJeaSession -JeaComputerName $JeaComputerName -CloudAdminCredential $CloudAdminCredential -Verbose
    $stampInfo = Confirm-StampVersion -PSSession $session -Verbose
}
finally
{
    $session | Remove-PSSession
}

$RegistrationName = if ($RegistrationName) { $RegistrationName } else { "AzureStack-$($stampInfo.CloudID)" }
    
$currentAttempt = 0
$maxAttempts = 3
$sleepSeconds = 10
do {
    try{            
        $azureResource = Find-AzureRmResource -ResourceType "Microsoft.AzureStack/registrations" -ResourceGroupNameContains $ResourceGroupName -ResourceNameContains $RegistrationName
        if ($azureResource)
        {
            Write-Verbose "Found registration resource in azure: $(ConvertTo-Json $azureResource)"
            Write-Verbose "Removing resource $($azureresource.Name) from Azure"
            Remove-AzureRmResource -ResourceName $azureResource.Name -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.AzureStack/registrations" -Force -Verbose                
            Write-Verbose "Cleanup successful. Registration resource removed from Azure"
                            
            $role = Get-AzureRmRoleDefinition -Name 'Registration Reader'
            if(-not($role.AssignableScopes -icontains "/subscriptions/$AlternateSubscriptionId"))
            {
                Write-Verbose "Adding alternate subscription Id to scope of custom RBAC role"
                $role.AssignableScopes.Add("/subscriptions/$AlternateSubscriptionId")
                Set-AzureRmRoleDefinition -Role $role
            }
            break
        }
        else
        {
            Write-Warning "Resource not found in Azure, registration may have failed or it may be under another subscription. Cancelling cleanup."
            break
        }
    }
    Catch
    {
        $exceptionMessage = $_.Exception.Message
        Write-Warning "Failed while preparing Azure for new registration: `r`n$exceptionMessage"
        Write-Verbose "Waiting $sleepSeconds seconds and trying again... attempt $currentAttempt of $maxRetries"
        $currentAttempt++
        Start-Sleep -Seconds $sleepSeconds
        if ($currentAttempt -ge $maxRetries)
        {
            Write-Warning "Failed to prepare Azure for new registration on final attempt: `r`n$exceptionMessage"
            break
        }
    }
}while ($currentAttempt -le $maxRetries)
