# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0

<#
    .SYNOPSIS
    List Active & Closed Infrastructure Alerts
#>

function Get-AzsAlert {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.InfrastructureInsights.Admin/regionHealths/Alerts"

    $alerts = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $alerts.Properties
}

Export-ModuleMember -Function Get-AzsAlert

<#
    .SYNOPSIS
    List Azure Stack Scale Units in specified Location
#>
function Get-AzsScaleUnit {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/ScaleUnits"

    $cluster = Get-AzsInfrastructureResource -Location $Location -ResourceType $resourceType
    $cluster
}

Export-ModuleMember -Function Get-AzsScaleUnit

<#
    .SYNOPSIS
    List Nodes in Scale Unit 
#>
function Get-AzsScaleUnitNode {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"
    
    $nodesprop = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $nodesprop
}

Export-ModuleMember -Function Get-AzsScaleUnitNode

<#
    .SYNOPSIS
    List total storage capacity 
#>
function Get-AzsStorageSubsystem {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/storagesubSystems"

    $storage = Get-AzsInfrastructureResource -Location $Location -ResourceType $resourceType
    $storage
}

Export-ModuleMember -function Get-AzsStorageSubsystem

<#
    .SYNOPSIS
    List Infrastructure Roles 
#>

function Get-AzsInfrastructureRole {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/InfraRoles"

    $roles = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $roles
}

Export-ModuleMember -Function Get-AzsInfrastructureRole

<#
    .SYNOPSIS
    List Infrastructure Role Instances
#>

function Get-AzsInfrastructureRoleInstance {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/infraRoleInstances"

    $VMs = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $VMs
}       

Export-ModuleMember -Function Get-AzsInfrastructureRoleInstance

<#
    .SYNOPSIS
    List File Shares
#>
function Get-AzsStorageShare {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )
    
    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/fileShares"

    $shares = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $shares
}

Export-ModuleMember -Function Get-AzsStorageShare

<#
    .SYNOPSIS
    List Logical Networks
#>

function Get-AzsLogicalNetwork {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )
    
    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/logicalNetworks"

    $LNetworks = Get-AzsInfrastructureResource -Location $Location -ResourceType $resourceType
    $LNetworks
}

Export-ModuleMember -Function Get-AzsLogicalNetwork

<#
    .SYNOPSIS
    List Location Update Summary
#>

function Get-AzSUpdateLocation {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )
    $resourceType = "Microsoft.Update.Admin/updatelocations"

    $updates = Get-AzsInfrastructureResource -Location $Location -ResourceType $resourceType
    $updates.Properties
}

Export-ModuleMember -function Get-AzsUpdateLocation

<#
    .SYNOPSIS
    List Available Updates
#>
Function Get-AzsUpdate {
    [CmdletBinding(DefaultParameterSetName = 'GetUpdate')]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Update.Admin/updatelocations/updates"

    $updates = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $updates    
}

Export-ModuleMember -Function Get-AzsUpdate

<#
    .SYNOPSIS
    List Status for a specific Update Run
#>
function Get-AzsUpdateRun {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $Update
    )
    
    $name = "{0}/{1}" -f $Location, $Update
    $resourceType = "Microsoft.Update.Admin/updatelocations/updates/updateRuns"

    $updates = Get-AzsInfrastructureResource -Name $name -Location $Location -ResourceType $resourceType
    $updates
}

Export-ModuleMember -Function Get-AzsUpdateRun


<#
    .SYNOPSIS
    Apply Azure Stack Update 
#>

function Install-AzsUpdate {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $Update
    )

          
    $params = @{
        ResourceType = "Microsoft.Update.Admin/updatelocations/updates"
        ResourceName = "{0}/{1}" -f $Location, $Update
        ApiVersion   = "2016-05-01"
        ResourceGroupName = "system.{0}" -f $Location
    }

    $StartRun = Invoke-AzureRmResourceAction @params -Action 'apply' -Force

    $StartRun
}

Export-ModuleMember -Function Install-AzsUpdate

<#
    .SYNOPSIS
    Close Active Alert
#>
function Close-AsSAlert {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [ValidateNotNullorEmpty()]
        [String] $AlertId
    )

    $alerts = Get-AzsAlert -Location $Location
    
    $alert = $alerts | Where-Object { $_.AlertId -eq "$AlertId" }

    if ($null -ne $alert) {
        $alertName = $alert.AlertId
        $alert.state = "Closed"
        
        $params = @{
            ApiVersion        = "2016-05-01"
            ResourceName      = "{0}/{1}" -f $Location, $alertName
            ResourceType      = "Microsoft.InfrastructureInsights.Admin/regionHealths/Alerts"
            ResourceGroupName = "system.{0}" -f $Location
            Properties        = $alert
        }

        Set-AzureRmResource @params -Force
    }
}
Export-ModuleMember -Function Close-AzsAlert

<#
    .SYNOPSIS
    List IP Address Pools
#>
function Get-AzsIpPool {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )
    
    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/IPPools"

    $IPPool = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $IPPool.Properties
}

Export-ModuleMember -Function Get-AzsIPPool

<#
    .SYNOPSIS
    List MAC Address Pools
#>
function Get-AzsMacPool {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/MacAddressPools"

    $MACPools = Get-AzsInfrastructureResource -Location $Location -ResourceType $resourceType
    $MACPools.Properties
}

Export-ModuleMember -Function Get-AzsMacPool

<#
    .SYNOPSIS
   List Gateway Pools
#>

function Get-AzsGatewayPool {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/edgeGatewayPools"

    $GatewayPools = Get-AzsInfrastructureResource -Location $Location -ResourceType $resourceType
    $GatewayPools.Properties
}

Export-ModuleMember -Function Get-AzsGatewayPool

<#
    .SYNOPSIS
    List SLB MUX
#>

function Get-AzsSLBMux {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/SlbMuxInstances"

    $SLBMUX = Get-AzsInfrastructureResource -Location $Location -ResourceType $resourceType
    $SLBMUX.Properties
}

Export-ModuleMember -Function Get-AzsSLBMux

<#
    .SYNOPSIS
    List Gateways
#>
function Get-AzsGateway {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/edgegateways"

    $Gateways = Get-AzsInfrastructureResource -Location $Location -ResourceType $resourceType
    $Gateways.Properties
}

Export-ModuleMember -Function Get-AzsGateway

<#
    .SYNOPSIS
    Start Infra Role Instance
#>
function Start-AzsInfrastructureRoleInstance {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )
    
    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to start $Name ?", "")) {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/infraRoleInstances"

        Invoke-AzsInfrastructureAction -Name $Name -Action "poweron" -Location $Location -ResourceType $resourceType
    }
}

Export-ModuleMember -Function Start-AzsInfrastructureRoleInstance

<#
    .SYNOPSIS
    Shutdown Infra Role Instance
#>
function Stop-AzsInfrastructureRoleInstance {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,
       
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )

    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to shut down $Name ?", "")) {        
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/infraRoleInstances"

        Invoke-AzsInfrastructureAction -Name $Name -Action "shutdown" -Location $Location -ResourceType $resourceType
    }
}

Export-ModuleMember -Function Stop-AzsInfrastructureRoleInstance

<#
    .SYNOPSIS
    Restart Infra Role Instance
#>
function Restart-AzsInfrastructureRoleInstance {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )

    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to restart $Name ?", "")) {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/infraRoleInstances"

        Invoke-AzsInfrastructureAction -Name $Name -Action "reboot" -Location $Location -ResourceType $resourceType
    }
}

Export-ModuleMember -Function Restart-AzsInfrastructureRoleInstance


<#
    .SYNOPSIS
    Add IP Address Pool
#>
function Add-AzsIpPool {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $StartIPAddress,

        [Parameter(Mandatory = $true)]
        [string] $EndIPAddress,

        [string] $AddressPrefix = ''
    )
    
    $params = @{
        ResourceName      = "{0}/{1}" -f $Location, $Name
        ResourceType      = "Microsoft.Fabric.Admin/fabricLocations/IPPools"
        ResourceGroupName = "system.{0}" -f $Location
        ApiVersion        = "2016-05-01"
        Properties        = @{  
            StartIpAddress = "$StartIPAddress"
            EndIpAddress   = "$EndIPAddress"
            AddressPrefix  = "$AddressPrefix"
        }
    }

    New-AzureRmResource @params -Force
}

Export-ModuleMember -Function Add-AzsIpPool

<#
    .SYNOPSIS
    Enable Maintenance Mode
#>

function Disable-AzsScaleUnitNode {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )

    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to disable scale unit node $Name ?", "")) {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"

        Invoke-AzsInfrastructureAction -Action "StartMaintenanceMode" -Name $Name -Location $Location -ResourceType $resourceType
    }
}

Export-ModuleMember -Function Disable-AzsScaleUnitNode


<#
    .SYNOPSIS
    Disable Maintenance Mode
#>

function Enable-AzsScaleUnitNode {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )
    
    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to enable scale unit node $Name ?", "")) {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"

        Invoke-AzsInfrastructureAction -Action "StopMaintenanceMode" -Name $Name -Location $Location -ResourceType $resourceType
    }
}

Export-ModuleMember -Function Enable-AzsScaleUnitNode


<#
    .SYNOPSIS
    Get Location Capacity
#>
function Get-AzsLocationCapacity {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )
    
    $name = "../"
    $resourceType = "Microsoft.InfrastructureInsights.Admin/locations/regionHealths"

    $Capacity = Get-AzsInfrastructureResource -Name $name -Location $Location -ResourceType $resourceType
    $Capacity.Properties
}

Export-ModuleMember -Function Get-AzsLocationCapacity


<#
    .SYNOPSIS
    List Backup location
#>

function Get-AzsBackupLocation {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Backup.Admin/backupLocations"

    $backuplocation = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $backuplocation.Properties
}

Export-ModuleMember -Function Get-AzsBackupLocation

<#
    .SYNOPSIS
    List Backups
#>

function Get-AzsBackup {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $resourceType = "Microsoft.Backup.Admin/backupLocations/$Location/backups"

    $backuplocation = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $backuplocation.Properties
}

Export-ModuleMember -Function Get-AzsBackup

function Get-AzsInfrastructureResource {
    param(
        [Parameter(Mandatory = $false)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Location,

        [Parameter(Mandatory = $false)]
        [string] $ApiVersion = "2016-05-01",

        [string] $ResourceType
    )
    
    # If $name is not given, list all resource by using location as ResourceName
    if (-not $Name) {       
        $Name = $Location
    }

    $params = @{
        ApiVersion        = $apiVersion
        ResourceType      = $resourceType
        ResourceName      = $name
        ResourceGroupName = "system.{0}" -f $Location
    }

    $infraResource = Get-AzureRmResource @params
    return $infraResource
}

function Invoke-AzsInfrastructureAction {
    param(
        [string] $Name,
        [string] $Location,
        [string] $Action,
        [string] $ResourceType
    )

    $params = @{
        ApiVersion        = "2016-05-01"
        Action            = $Action
        ResourceType      = $ResourceType
        ResourceGroupName = "system.{0}" -f $Location
        ResourceName      = "{0}/{1}" -f $Location, $Name
    }

    Invoke-AzureRmResourceAction @params -Force
}
