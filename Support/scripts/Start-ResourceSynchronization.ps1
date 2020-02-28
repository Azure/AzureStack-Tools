<#
# Copyright (c) Microsoft Corporation. All rights reserved.
.SYNOPSIS
    This script initiates a resource synchronization job in the backend, fixing the documented known issue where the Storage Account Overview does not load within Azure Stack portals (both Admin and User portals) for Storage accounts created with "apiVersion": "2015-06-15".
    
.DESCRIPTION
    Created to be run on the HLH, DVM, ASDK HOST or Jumpbox from an administrative powershell session.
    Start-ResourceSynchronization.ps1 must be run after the user has logged in as the Service Admin to the Default Provider Subscription within their Azure Stack subscription.

    Applies to: Azure Stack Integraded System and ASDK
    Relevant build(s): 1802
	
    It can be run without any parameters - if done so, it will initiate the resource synchronization on the Default Provider Subscription as well as any available User Subscriptions.
    NOTE: A warning will be thrown (-WarningAction Inquire) if more than 10 subscriptions exist, as there could be a performance impact during the execution of the resource synchronization agianst all the user subscriptions at once.
          Alternatively, the script can be run one subscription at a time, leveraging the optional SubscriptionId parameter.
	
.PARAMETER SubscriptionId
    OPTIONAL [Guid] parameter specifying a single subscription to run the resource synchronization against.
    Use this option for targeted subscription resource synchronization.

.EXAMPLE
    .\Start-ResourceSynchronization.ps1

.EXAMPLE
    .\Start-ResourceSynchronization.ps1 -SubscriptionId 9b291bc8-fdef-4f88-bf81-8a0a53d4c2c5

.NOTES
    The following are the prerequisite steps to be completed before running Start-ResourceSynchronization.ps1

    1. Install Azure and Azure Stack PowerShell (leverage current documented guidance for supported versions)
    2. Add an Azure Stack Environment (leverave current documented guidance for adding an adminmanagement environment)
        Example: Add-AzureRmEnvironment -Name AzureStackAdmin -ARMEndpoint "https://adminmanagement.local.azurestack.external"
    3. Login as the Service Admin to the Azure Stack environment (for Azure Stack environments deployed with AAD, identify the TenantID)
        Example: Login-AzureRmAccount -Environment AzureStackAdmin -TenantId 9b291bc8-fdef-4f88-bf81-8a0a53d4c2c5
    
    Within the same PS session, Start-ResourceSynchronization.ps1 can now be run

.LINK
    https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install

.LINK
    https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-configure-admin

.LINK
    https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-update-1802

.LINK
    https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-asdk-release-notes#build-201803021
#>

[CmdletBinding()]
param
(
    [Guid] $SubscriptionId
)

function IsNotNullOrEmptyString([Object]$Obj) { return ($Obj -ne $null) -and ($Obj.ToString() -ne "") }

Import-Module AzureRM.Profile
Import-Module AzureRM.AzureStackAdmin

$adminSubscription = (Get-AzureRmSubscription -SubscriptionName "Default Provider Subscription" -ErrorAction Stop).SubscriptionId

$subscriptions = @($adminSubscription)

if (IsNotNullOrEmptyString $SubscriptionId)
{
    $subscriptions += $SubscriptionId
}
else
{
    $userSubscriptions = (Get-AzsUserSubscription | Select-Object -ExpandProperty SubscriptionId)
    $subscriptions += $userSubscriptions
}

$subscriptions = $subscriptions | Select-Object -Unique

if ($subscriptions.Count -gt 10)
{
    Write-Warning "You have more than 10 subscriptions. Synchronizing all these subscriptions might cause performance degradation during the resynchronization period." -WarningAction Inquire
}

Write-Host "Starting resource synchronization job"

$subscriptions | ForEach-Object {
    $resourceId = "/subscriptions/$adminSubscription/providers/Microsoft.Resources.Admin/subscriptions/$_/providers/Microsoft.Storage"

    $params = @{
        Action = "SynchronizeResources"
        ApiVersion = "2015-01-01"
        ResourceId = $resourceId
    }
    Invoke-AzureRmResourceAction @params -Force

    Start-Sleep -Seconds 20
}

Write-Host "Resource synchronization job started."