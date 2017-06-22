# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0

<#
    .SYNOPSIS
    Creates "default" tenant offer with unlimited quotas across Compute, Network, Storage and KeyVault services.
#>

function Add-AzsStorageQuota {
    param(
        [string] $Name = "default",
        [int] $CapacityInGb = 1000,
        [int] $NumberOfStorageAccounts = 2000,
        [string] $Location = $null
    )
    
    $Location = Get-AzsLocation -Location $Location    

    $params = @{
        ResourceName = "{0}/{1}" -f $Location, $Name
        ResourceType = "Microsoft.Storage.Admin/locations/quotas"
        ApiVersion   = "2015-12-01-preview"
        Properties   = @{  
            capacityInGb            = $CapacityInGb
            numberOfStorageAccounts = $NumberOfStorageAccounts
        }
    }

    New-AzsServiceQuota @params
}

function Add-AzsComputeQuota {
    param(
        [string] $Name = "default",
        [int] $VmCount = 1000,
        [int] $MemoryLimitMB = 1048576,
        [int] $CoresLimit = 1000,
        [string] $Location = $null
    )

    $Location = Get-AzsLocation -Location $Location    
    
    $params = @{
        ResourceName = "{0}/{1}" -f $Location, $Name
        ResourceType = "Microsoft.Compute.Admin/locations/quotas"
        ApiVersion   = "2015-12-01-preview"
        Properties   = @{
            virtualMachineCount = $VmCount
            memoryLimitMB       = $MemoryLimitMB
            coresLimit          = $CoresLimit
        }
    }
    
    New-AzsServiceQuota @params
}
    
function Add-AzsNetworkQuota {
    param(
        [string] $Name = "default",
        [int] $PublicIpsPerSubscription = 500,
        [int] $VNetsPerSubscription = 500,
        [int] $GatewaysPerSubscription = 10,
        [int] $ConnectionsPerSubscription = 20,
        [int] $LoadBalancersPerSubscription = 500,
        [int] $NicsPerSubscription = 1000,
        [int] $SecurityGroupsPerSubscription = 500,
        [string] $Location = $null
    ) 
    
    $Location = Get-AzsLocation -Location $Location
    
    $params = @{
        ResourceName = "{0}/{1}" -f $Location, $Name
        ResourceType = "Microsoft.Network.Admin/locations/quotas"
        ApiVersion   = "2015-06-15"
        Properties   = @{
            maxPublicIpsPerSubscription                        = $PublicIpsPerSubscription
            maxVnetsPerSubscription                            = $VNetsPerSubscription
            maxVirtualNetworkGatewaysPerSubscription           = $GatewaysPerSubscription
            maxVirtualNetworkGatewayConnectionsPerSubscription = $ConnectionsPerSubscription
            maxLoadBalancersPerSubscription                    = $LoadBalancersPerSubscription
            maxNicsPerSubscription                             = $NicsPerSubscription
            maxSecurityGroupsPerSubscription                   = $SecurityGroupsPerSubscription
        }
    }
    
    New-AzsServiceQuota @params
}


function Get-AzsSubscriptionsQuota {
    param(
        [string] $Location
    )

    $Location = Get-AzsLocation -Location $Location

    $params = @{
        ResourceName = $Location
        ResourceType = "Microsoft.Subscriptions.Admin/locations/quotas"
        ApiVersion   = "2015-11-01"
    }

    Get-AzsServiceQuota @params
}

function Get-AzsKeyVaultQuota {
    param(  
        [string] $Location
    )
    
    $Location = Get-AzsLocation -Location $Location
    
    $params = @{
        ResourceName = $Location
        ResourceType = "Microsoft.Keyvault.Admin/locations/quotas"
        ApiVersion   = "2014-04-01-preview"
    }

    Get-AzsServiceQuota @params
}

function Get-AzsLocation {
    param(
        [string] $Location
    )

    if ($Location) {
        return $Location
    }

    $locationResource = Get-AzureRmManagedLocation
    return $locationResource.Name
}


function New-AzsServiceQuota {
    param(
        [string] $ResourceName,
        [string] $ResourceType,
        [string] $ApiVersion,
        [PSObject] $Properties
    )
        
    $serviceQuota = New-AzureRmResource -ResourceName $ResourceName -ResourceType $ResourceType -ApiVersion $ApiVersion -Properties $Properties -Force
    $serviceQuota.ResourceId
}

function Get-AzsServiceQuota {
    param(
        [string] $ResourceName,
        [string] $ResourceType,
        [string] $ApiVersion
    )
    
    $serviceQuota = Get-AzureRmResource -ResourceName $ResourceName  -ApiVersion $ApiVersion -ResourceType $ResourceType
    $serviceQuota.ResourceId
}
