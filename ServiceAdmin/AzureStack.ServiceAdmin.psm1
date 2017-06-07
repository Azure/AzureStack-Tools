# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0

<#
    .SYNOPSIS
    Creates "default" tenant offer with unlimited quotas across Compute, Network, Storage and KeyVault services.
#>
function New-AzSTenantOfferAndQuotas
{
    param (
        [parameter(HelpMessage="Name of the offer to be made advailable to tenants")]
        [string] $Name ="default",
        [Parameter(HelpMessage="If this parameter is not specified all quotas are assigned. Provide a sub selection of quotas in this parameter if you do not want all quotas assigned.")]
        [ValidateSet('Compute','Network','Storage','KeyVault','Subscriptions',IgnoreCase =$true)]
        [array] $ServiceQuotas,
        [parameter(HelpMessage="Azure Stack region in which to define plans and quotas")]
        [string] $Location = "local"
    )

    Write-Verbose "Creating quotas..." -Verbose
    $Quotas = @()
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Compute')){ $Quotas += New-AzSComputeQuota -Location $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Network')){ $Quotas += New-AzSNetworkQuota -Location $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Storage')){ $Quotas += New-AzSStorageQuota -Location $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'KeyVault')){ $Quotas += Get-AzSKeyVaultQuota -Location $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Subscriptions')){ $Quotas += Get-AzSSubscriptionsQuota -Location $Location }

    Write-Verbose "Creating resource group for plans and offers..." -Verbose
    if (Get-AzureRmResourceGroup -Name $Name -ErrorAction SilentlyContinue)
    {        
        Remove-AzureRmResourceGroup -Name $Name -Force -ErrorAction Stop
    }
    New-AzureRmResourceGroup -Name $Name -Location $Location -ErrorAction Stop

    Write-Verbose "Creating plan..." -Verbose
    $plan = New-AzureRMPlan -Name $Name -DisplayName $Name -ArmLocation $Location -ResourceGroup $Name -QuotaIds $Quotas

    Write-Verbose "Creating public offer..." -Verbose
    $offer = New-AzureRMOffer -Name $Name -DisplayName $Name -State Public -BasePlanIds @($plan.Id) -ArmLocation $Location -ResourceGroup $Name

    return $offer
}

Export-ModuleMember New-AzSTenantOfferAndQuotas

function New-AzSStorageQuota
{
    param(
        [string] $Name                  = "default",
        [int] $CapacityInGb             = 1000,
        [int] $NumberOfStorageAccounts  = 2000,
        [string] $Location              = $null
    )
    
    $Location = Get-AzSLocation -Location $Location
    $ApiVersion = "2015-12-01-preview"
    $ResourceType = "Microsoft.Storage.Admin/locations/quotas"
    $ResourceName = "{0}/{1}" -f $Location, $Name

    $Properties = New-Object PSObject -Property @{  
       "capacityInGb" = $CapacityInGb
       "numberOfStorageAccounts" = $NumberOfStorageAccounts
    }

    New-AzSServiceQuota -ResourceName $ResourceName -ResourceType $ResourceType -ApiVersion $ApiVersion -Properties $Properties
}

function New-AzSComputeQuota
{
    param(
        [string] $Name         = "default",
        [int] $VmCount         = 1000,
        [int] $MemoryLimitMB   = 1048576,
        [int] $CoresLimit      = 1000,
        [string] $Location     = $null
    )

    $Location = Get-AzSLocation -Location $Location
    $ApiVersion = "2015-12-01-preview"
    $ResourceType = "Microsoft.Compute.Admin/locations/quotas"
    $ResourceName = "{0}/{1}" -f $Location, $Name

    $Properties = New-Object PSObject -Property @{  
       "virtualMachineCount" = $VmCount
       "memoryLimitMB" = $MemoryLimitMB
       "coresLimit" = $CoresLimit
    }
    
    New-AzSServiceQuota -ResourceName $ResourceName -ResourceType $ResourceType -ApiVersion $ApiVersion -Properties $Properties
}

function New-AzSNetworkQuota
{
    param(
        [string] $Name                        = "default",
        [int] $PublicIpsPerSubscription       = 500,
        [int] $VNetsPerSubscription           = 500,
        [int] $GatewaysPerSubscription        = 10,
        [int] $ConnectionsPerSubscription     = 20,
        [int] $LoadBalancersPerSubscription   = 500,
        [int] $NicsPerSubscription            = 1000,
        [int] $SecurityGroupsPerSubscription  = 500,
        [string] $Location                    = $null
    ) 
    
    $Location = Get-AzSLocation -Location $Location
    $ApiVersion = "2015-06-15"
    $ResourceType = "Microsoft.Network.Admin/locations/quotas"
    $ResourceName = "{0}/{1}" -f $Location, $Name

    $Properties = New-Object PSObject -Property @{  
        "maxPublicIpsPerSubscription" = $PublicIpsPerSubscription
            "maxVnetsPerSubscription" = $VNetsPerSubscription
            "maxVirtualNetworkGatewaysPerSubscription" = $GatewaysPerSubscription
            "maxVirtualNetworkGatewayConnectionsPerSubscription" = $ConnectionsPerSubscription
            "maxLoadBalancersPerSubscription" = $LoadBalancersPerSubscription
            "maxNicsPerSubscription" = $NicsPerSubscription
            "maxSecurityGroupsPerSubscription" = $SecurityGroupsPerSubscription
    }
    
    New-AzSServiceQuota -ResourceName $ResourceName -ResourceType $ResourceType -ApiVersion $ApiVersion -Properties $Properties
}

function Get-AzSSubscriptionsQuota
{
    param(
        [string] $Location = $null
    )

    $Location = Get-AzSLocation -Location $Location
    $ApiVersion = "2015-11-01"
    $ResourceType = "Microsoft.Subscriptions.Admin/locations/quotas"

    Get-AzSServiceQuota -ResourceName $Location -ResourceType $ResourceType -ApiVersion $ApiVersion
}

function Get-AzSKeyVaultQuota
{
    param(  
        [string] $Location = $null
    )
    
    $Location = Get-AzSLocation -Location $Location
    $ApiVersion = "2014-04-01-preview"
    $ResourceType = "Microsoft.Keyvault.Admin/locations/quotas"

    Get-AzSServiceQuota -ResourceName $Location -ResourceType $ResourceType -ApiVersion $ApiVersion
}

function Get-AzSLocation
{
    param(
        [string] $Location
    )

    if($null -ne $Location -and '' -ne $Location)
    {
        return $Location
    }

    $locationResource = Get-AzureRmManagedLocation
    return $locationResource.Name
}


function New-AzSServiceQuota
{
    param(
        [string] $ResourceName,
        [string] $ResourceType,
        [string] $ApiVersion,
        [PSObject] $Properties
    )
        
    $serviceQuota = New-AzureRmResource -ResourceName $ResourceName -ResourceType $ResourceType -ApiVersion $ApiVersion -Properties $Properties
    $serviceQuota.ResourceId
}

function Get-AzSServiceQuota
{
    param(
        [string] $ResourceName,
        [string] $ResourceType,
        [string] $ApiVersion
    )
    
    $serviceQuota = Get-AzureRmResource -ResourceName $ResourceName  -ApiVersion $ApiVersion -ResourceType $ResourceType
    $serviceQuota.ResourceId
}