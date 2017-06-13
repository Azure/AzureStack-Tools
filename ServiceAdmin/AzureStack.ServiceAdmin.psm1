# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0

<#
    .SYNOPSIS
    Creates "default" tenant offer with unlimited quotas across Compute, Network, Storage and KeyVault services.
#>
function Add-AzSTenantOfferAndQuota
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
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Compute')) {
        Write-Verbose "Creating compute quota..."
        $Quotas += Add-AzSComputeQuota -Location $Location 
    }

    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Network')) {
        Write-Verbose "Creating network quota..."
        $Quotas += Add-AzSNetworkQuota -Location $Location 
    }

    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Storage')) {
        Write-Verbose "Creating storage quota..."
        $Quotas += Add-AzSStorageQuota -Location $Location 
    }

    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'KeyVault')) {
        Write-Verbose "Get default key vault quota..."
        $Quotas += Get-AzSKeyVaultQuota -Location $Location 
    }

    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Subscriptions')) {
        Write-Verbose "Creating subscription quota..."
        $Quotas += Get-AzSSubscriptionsQuota -Location $Location 
    }
    
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

Export-ModuleMember Add-AzSTenantOfferAndQuotas

function Add-AzSStorageQuota
{
    param(
        [string] $Name                  = "default",
        [int] $CapacityInGb             = 1000,
        [int] $NumberOfStorageAccounts  = 2000,
        [string] $Location              = $null
    )
    
    $Location = Get-AzSLocation -Location $Location    

    $params = @{
        ResourceName = "{0}/{1}" -f $Location, $Name
        ResourceType = "Microsoft.Storage.Admin/locations/quotas"
        ApiVersion = "2015-12-01-preview"
        Properties = @{  
            capacityInGb = $CapacityInGb
            numberOfStorageAccounts = $NumberOfStorageAccounts
        }
    }

    New-AzSServiceQuota @params
}

function Add-AzSComputeQuota
{
    param(
        [string] $Name         = "default",
        [int] $VmCount         = 1000,
        [int] $MemoryLimitMB   = 1048576,
        [int] $CoresLimit      = 1000,
        [string] $Location     = $null
    )

    $Location = Get-AzSLocation -Location $Location    
    
    $params = @{
        ResourceName = "{0}/{1}" -f $Location, $Name
        ResourceType = "Microsoft.Compute.Admin/locations/quotas"
        ApiVersion = "2015-12-01-preview"
        Properties = @{
            virtualMachineCount = $VmCount
            memoryLimitMB = $MemoryLimitMB
            coresLimit = $CoresLimit
        }
    }
    
    New-AzSServiceQuota @params
}

function Add-AzSNetworkQuota
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
    
    $params = @{
        ResourceName = "{0}/{1}" -f $Location, $Name
        ResourceType = "Microsoft.Network.Admin/locations/quotas"
        ApiVersion = "2015-06-15"
        Properties = @{
            maxPublicIpsPerSubscription = $PublicIpsPerSubscription
            maxVnetsPerSubscription = $VNetsPerSubscription
            maxVirtualNetworkGatewaysPerSubscription = $GatewaysPerSubscription
            maxVirtualNetworkGatewayConnectionsPerSubscription = $ConnectionsPerSubscription
            maxLoadBalancersPerSubscription = $LoadBalancersPerSubscription
            maxNicsPerSubscription = $NicsPerSubscription
            maxSecurityGroupsPerSubscription = $SecurityGroupsPerSubscription
        }
    }
    
    New-AzSServiceQuota @params
}

function Get-AzSSubscriptionsQuota
{
    param(
        [string] $Location = $null
    )

    $Location = Get-AzSLocation -Location $Location

    $params = @{
        ResourceName = $Location
        ResourceType = "Microsoft.Subscriptions.Admin/locations/quotas"
        ApiVersion = "2015-11-01"
    }

    Get-AzSServiceQuota @params
}

function Get-AzSKeyVaultQuota
{
    param(  
        [string] $Location = $null
    )
    
    $Location = Get-AzSLocation -Location $Location
    
    $params = @{
        ResourceName = $Location
        ResourceType = "Microsoft.Keyvault.Admin/locations/quotas"
        ApiVersion = "2014-04-01-preview"
    }

    Get-AzSServiceQuota @params
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
        
    $serviceQuota = New-AzureRmResource -ResourceName $ResourceName -ResourceType $ResourceType -ApiVersion $ApiVersion -Properties $Properties -Force
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