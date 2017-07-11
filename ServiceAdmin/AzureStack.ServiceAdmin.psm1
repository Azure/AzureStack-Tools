# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0

<#
    .SYNOPSIS
    Creates "default" tenant offer with unlimited quotas across Compute, Network, Storage and KeyVault services.
#>

function Add-AzsStorageQuota {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [int] $CapacityInGb,

        [Parameter(Mandatory = $true)]
        [int] $NumberOfStorageAccounts,

        [Parameter(Mandatory = $true)]
        [string] $Location
    )

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

Export-ModuleMember -Function Add-AzsStorageQuota

function Add-AzsComputeQuota {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [int] $VmCount,

        [Parameter(Mandatory = $true)]
        [int] $MemoryLimitMB,

        [Parameter(Mandatory = $true)]
        [int] $CoresLimit,

        [Parameter(Mandatory = $true)]
        [string] $Location
    )
    
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

Export-ModuleMember -Function Add-AzsComputeQuota
    
function Add-AzsNetworkQuota {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [int] $PublicIpsPerSubscription,

        [Parameter(Mandatory = $true)]
        [int] $VNetsPerSubscription,

        [Parameter(Mandatory = $true)]
        [int] $GatewaysPerSubscription,

        [Parameter(Mandatory = $true)]
        [int] $ConnectionsPerSubscription,

        [Parameter(Mandatory = $true)]
        [int] $LoadBalancersPerSubscription,

        [Parameter(Mandatory = $true)]
        [int] $NicsPerSubscription,

        [Parameter(Mandatory = $true)]
        [int] $SecurityGroupsPerSubscription,

        [Parameter(Mandatory = $true)]
        [string] $Location
    ) 
    
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

Export-ModuleMember -Function Add-AzsNetworkQuota

function Get-AzsSubscriptionsQuota {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $params = @{
        ResourceName = $Location
        ResourceType = "Microsoft.Subscriptions.Admin/locations/quotas"
        ApiVersion   = "2015-11-01"
    }

    Get-AzsServiceQuota @params
}

Export-ModuleMember -Function Get-AzsSubscriptionsQuota

function Get-AzsKeyVaultQuota {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )
    
    $params = @{
        ResourceName = $Location
        ResourceType = "Microsoft.Keyvault.Admin/locations/quotas"
        ApiVersion   = "2014-04-01-preview"
    }

    Get-AzsServiceQuota @params
}

Export-ModuleMember -Function Get-AzsKeyVaultQuota

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
