# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0

<#
    .SYNOPSIS
    Creates "default" tenant offer with unlimited quotas across Compute, Network, Storage and KeyVault services.
#>

function New-AzsComputeQuota {
    param(
        [string] $Name = "default",
        [int] $CoresLimit = 200,
        [int] $VirtualMachineCount = 50,
        [int] $AvailabilitySetCount = 10,
        [int] $VmScaleSetCount = 10,
        [string] $Location = $null
    )

    $Location = Get-AzsHomeLocation -Location $Location    
    
    $params = @{
        ResourceName = "{0}/{1}" -f $Location, $Name
        ResourceType = "Microsoft.Compute.Admin/locations/quotas"
        ApiVersion   = "2015-12-01-preview"
        Properties   = @{
            virtualMachineCount  = $VirtualMachineCount
            availabilitySetCount = $AvailabilitySetCount
            coresLimit           = $CoresLimit
            vmScaleSetCount      = $VmScaleSetCount
        }
    }
    
    New-AzsServiceQuota @params
}
    
function New-AzsNetworkQuota {
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
    
    $Location = Get-AzsHomeLocation -Location $Location
    
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

    $Location = Get-AzsHomeLocation -Location $Location

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
    
    $Location = Get-AzsHomeLocation -Location $Location
    
    $params = @{
        ResourceName = $Location
        ResourceType = "Microsoft.Keyvault.Admin/locations/quotas"
        ApiVersion   = "2014-04-01-preview"
    }

    Get-AzsServiceQuota @params
}

function Get-AzsHomeLocation {
    param(
        [string] $Location
    )

    if ($Location) {
        return $Location
    }

    $locationResource = Get-AzsLocation
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
    $quotaObject = New-Object PSObject      
    foreach ($property in ($serviceQuota.Properties | Get-Member -MemberType NoteProperty)){
        $quotaObject | Add-Member NoteProperty -Name $property.Name -Value $serviceQuota.Properties.($property.Name)
    }
    $quotaObject | Add-Member NoteProperty Name($serviceQuota.ResourceName)
    $quotaObject | Add-Member NoteProperty Type($serviceQuota.ResourceType)
    $quotaObject | Add-Member NoteProperty Location($serviceQuota.Location)
    $quotaObject | Add-Member NoteProperty Id($serviceQuota.ResourceId)
    $quotaObject
}

function Get-AzsServiceQuota {
    param(
        [string] $ResourceName,
        [string] $ResourceType,
        [string] $ResourceGroupName,
        [string] $ApiVersion
    )
    if($ResourceGroupName){
        $serviceQuota = Get-AzureRmResource -ResourceName $ResourceName  -ApiVersion $ApiVersion -ResourceType $ResourceType -ResourceGroupName $ResourceGroupName
    }
    else{
        $serviceQuota = Get-AzureRmResource -ResourceName $ResourceName  -ApiVersion $ApiVersion -ResourceType $ResourceType
    }
    $serviceQuota.ResourceId
}
