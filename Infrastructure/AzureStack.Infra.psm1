# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0

<#
    .SYNOPSIS
    List Active & Closed Infrastructure Alerts
#>

function Get-AzSAlert
{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.InfrastructureInsights.Admin/regionHealths/Alerts"

    $alerts = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $alerts.Properties
}

Export-ModuleMember -function Get-AzSAlert

<#
    .SYNOPSIS
    List Azure Stack Scale Units in specified Region
#>
function Get-AzSScaleUnit
{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/ScaleUnits"

    $cluster = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $cluster
}

Export-ModuleMember -function Get-AzSScaleUnit

<#
    .SYNOPSIS
    List Nodes in Scale Unit 
#>
function Get-AzSScaleUnitNode
{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"
    
    $nodesprop = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $nodesprop
}

Export-ModuleMember -function Get-AzSScaleUnitNode

<#
    .SYNOPSIS
    List total storage capacity 
#>
function Get-AzSStorageCapacity
{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/storagesubSystems"

    $storage = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $storage
}

Export-ModuleMember -function Get-AzSStorageCapacity

<#
    .SYNOPSIS
    List Infrastructure Roles 
#>
# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Get-AzsInfraRole' -Value 'Get-AzsInfrastructureRole' -ErrorAction SilentlyContinue

function Get-AzsInfrastructureRole{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/InfraRoles"

    $roles = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $roles
}

Export-ModuleMember -function Get-AzSInfrastructureRole

<#
    .SYNOPSIS
    List Infrastructure Role Instances
#>

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Get-AzsInfraRoleInstance' -Value 'Get-AzsInfrastructureRoleInstance' -ErrorAction SilentlyContinue

function Get-AzsInfrastructureRoleInstance{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/infraRoleInstances"

    $VMs = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $VMs
}       

Export-ModuleMember -function Get-AzSInfrastructureRoleInstance

<#
    .SYNOPSIS
    List File Shares
#>
function Get-AzSStorageShare
{
    Param(
        [string] $Region = $null
    )
    
    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/fileShares"

    $shares = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $shares
}

Export-ModuleMember -function Get-AzSStorageShare

<#
    .SYNOPSIS
    List Logical Networks
#>

function Get-AzSLogicalNetwork
{
    Param(
        [string] $Region = $null
    )
    
    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/logicalNetworks"

    $LNetworks = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $LNetworks
}

Export-ModuleMember -function Get-AzSLogicalNetwork

<#
    .SYNOPSIS
    List Region Update Summary
#>

function Get-AzSUpdateSummary
{
    Param(
        [string] $Region = $null
    )
    $resourceType = "Microsoft.Update.Admin/updatelocations/regionUpdateStatus"

    $updates = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $updates.Properties
}

Export-ModuleMember -function Get-AzSUpdateSummary

<#
    .SYNOPSIS
    List Available Updates
#>
function Get-AzSUpdate
{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Update.Admin/updatelocations/updates"

    $updates = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $updates | select UpdateName, Version, IsApplicable, Description, State, IsDownloaded, PackageSizeInMb, KbLink    
}

Export-ModuleMember -function Get-AzSUpdate

<#
    .SYNOPSIS
    List Status for a specific Update Run
#>
function Get-AzSUpdateRun
{
    Param(
        [string] $Region = $null,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $Update
    )
    
    $region = Get-AzSLocation -Location $Region
    $name = "{0}/{1}" -f $region, $Update
    $resourceType = "Microsoft.Update.Admin/updatelocations/updates/updateRuns"

    $updates = Get-AzSInfrastructureResource -name $name -region $region -resourceType $resourceType    
    $updates | select UpdateLocation, UpdateVersion, State, TimeStarted, Duration
}

Export-ModuleMember -function Get-AzSUpdateRun


<#
    .SYNOPSIS
    Apply Azure Stack Update 
#>

function Install-AzSUpdate
{
    Param(
        [string] $Region = $null,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $Update
    )

    $updates =  Get-AzSUpdate -Region $Region
        
    $updateContent = $updates | Where-Object {$_.UpdateName -eq $Update}
            
    $params = @{
        ResourceType = "Microsoft.Update.Admin/updatelocations/updates"
        ResourceName = "{0}/{1}" -f $Region, $Update
        ApiVersion = "2016-05-01"
        Properties = $updateContent
    }

    $StartRun = New-AzureRmResource @params -Force

    $StartRun
}

Export-ModuleMember -function Install-AzSUpdate

<#
    .SYNOPSIS
    Close Active Alert
#>
function Close-AzSAlert
{
    Param(
        [string] $Region = $null,

        [ValidateNotNullorEmpty()]
        [String] $AlertId
    )

    
    $region = Get-AzSLocation -Location $Region

    $alerts = Get-AzSAlert -Region $region
    
    $alert = $alerts | Where-Object { $_.AlertId -eq "$AlertId" }

    if($null -ne $alert)
    {
        $alertName = $alert.AlertId
        $alert.state = "Closed"
        
        $params = @{
            ApiVersion = "2016-05-01"
            ResourceName = "{0}/{1}" -f $region, $alertName
            ResourceType =  "Microsoft.InfrastructureInsights.Admin/regionHealths/Alerts"
            ResourceGroupName = "system.{0}" -f $region
            Properties = $alert
        }

        Set-AzureRmResource @params -Force
    }
}
Export-ModuleMember -function Close-AzSAlert

<#
    .SYNOPSIS
    List IP Address Pools
#>
function Get-AzSIPPool
{
    Param(
        [string] $Region = $null
    )
    
    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/IPPools"

    $IPPool = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $IPPool.Properties
}

Export-ModuleMember -function Get-AzSIPPool

<#
    .SYNOPSIS
    List MAC Address Pools
#>
function Get-AzSMaCPool
{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/MacAddressPools"

    $MACPools = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $MACPools.Properties
}

Export-ModuleMember -function Get-AzSMaCPool

<#
    .SYNOPSIS
   List Gateway Pools
#>

function Get-AzSGatewayPool
{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/edgeGatewayPools"

    $GatewayPools = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $GatewayPools.Properties
}

Export-ModuleMember -function Get-AzSGatewayPool

<#
    .SYNOPSIS
    List SLB MUX
#>

function Get-AzSSLBMUX
{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/SlbMuxInstances"

    $SLBMUX = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $SLBMUX.Properties
}

Export-ModuleMember -function Get-AzSSLBMUX

<#
    .SYNOPSIS
    List Gateways
#>
function Get-AzSGateway
{
    Param(
        [string] $Region = $null
    )

    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/edgegateways"

    $Gateways = Get-AzSInfrastructureResource -region $Region -resourceType $resourceType
    $Gateways.Properties
}

Export-ModuleMember -function Get-AzSGateway

<#
    .SYNOPSIS
    Start Infra Role Instance
#>

New-Alias -Name 'Start-AzsInfraRoleInstance' -Value 'Start-AzsInfrastructureRoleInstance' -ErrorAction SilentlyContinue

function Start-AzSInfrastructureRoleInstance
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [string] $Region = $null,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )
    
    if($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to start $Name ?",""))
    {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/infraRoleInstances"

        Invoke-AzSInfrastructureAction -Name $Name -Action "poweron" -Region $Region -ResourceType $resourceType
    }
}

Export-ModuleMember -function Start-AzSInfrastructureRoleInstance


<#
    .SYNOPSIS
    Shutdown Infra Role Instance
#>

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Stop-AzsInfraRoleInstance' -Value 'Stop-AzsInfrastructureRoleInstance' -ErrorAction SilentlyContinue

function Stop-AzSInfrastructureRoleInstance
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
       [string] $Region = $null,
       
       [Parameter(Mandatory=$true)]
       [ValidateNotNullorEmpty()]
       [string] $Name,

       [switch] $Force
    )

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to shut down $Name ?",""))
    {        
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/infraRoleInstances"

        Invoke-AzSInfrastructureAction -Name $Name -Action "shutdown" -Region $Region -ResourceType $resourceType
    }
}

Export-ModuleMember -function Stop-AzSInfrastructureRoleInstance


<#
    .SYNOPSIS
    Restart Infra Role Instance
#>
# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Restart-AzsInfraRoleInstance' -Value 'Restart-AzsInfrastructureRoleInstance' -ErrorAction SilentlyContinue


function Restart-AzSInfrastructureRoleInstance
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [string] $Region = $null,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to restart $Name ?",""))
    {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/infraRoleInstances"

        Invoke-AzSInfrastructureAction -Name $Name -Action "reboot" -Region $Region -ResourceType $resourceType
    }
}

Export-ModuleMember -function Restart-AzSInfrastructureRoleInstance


<#
    .SYNOPSIS
    Add IP Address Pool
#>
function Add-AzSIPPool
{
    Param(
        [string] $Region = $null,

        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $StartIPAddress,

        [Parameter(Mandatory=$true)]
        [string] $EndIPAddress,

        [string] $AddressPrefix = ''
    )

    $region = Get-AzSLocation -Location $Region
    
    $params = @{
        ResourceName = "{0}/{1}" -f $region, $Name
        ResourceType = "Microsoft.Fabric.Admin/fabricLocations/IPPools"
        ResourceGroupName = "system.{0}" -f $region
        ApiVersion = "2016-05-01"
        Properties = @{  
            StartIpAddress = "$StartIPAddress"
            EndIpAddress = "$EndIPAddress"
            AddressPrefix = "$AddressPrefix"
        }
    }

    New-AzureRmResource @params -Force
}

Export-ModuleMember -function Add-AzSIPPool

<#
    .SYNOPSIS
    Enable Maintenance Mode
#>

function Disable-AzSScaleUnitNode
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [string] $Region = $null,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to disable scale unit node $Name ?",""))
    {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"

        Invoke-AzSInfrastructureAction -Action "StartMaintenanceMode" -Name $Name -Region $Region -ResourceType $resourceType
    }
}

Export-ModuleMember -function Disable-AzSScaleUnitNode


<#
    .SYNOPSIS
    Disable Maintenance Mode
#>

function Enable-AzSScaleUnitNode
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [string] $Region = $null,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )
    
    if($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure to enable scale unit node $Name ?",""))
    {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"

        Invoke-AzSInfrastructureAction -Action "StopMaintenanceMode" -Name $Name -Region $Region -ResourceType $resourceType
    }
}

Export-ModuleMember -function Enable-AzSScaleUnitNode


<#
    .SYNOPSIS
    Get Region Capacity
#>
function Get-AzSRegionCapacity
{
    Param(        
        [string] $Region = $null
    )
        
    $region = Get-AzSLocation -Location $Region
    $name = "../"
    $resourceType = "Microsoft.InfrastructureInsights.Admin/locations/regionHealths"

    $Capacity = Get-AzSInfrastructureResource -name $name -region $region -resourceType $resourceType
    $Capacity.Properties
}

Export-ModuleMember -function Get-AzSRegionCapacity

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

function Get-AzSInfrastructureResource
{
    param(
        [string] $name = $null,
        [string] $region,
        [string] $apiVersion = "2016-05-01",
        [string] $resourceType
    )
    
    $region = Get-AzSLocation -Location $region

    # If $name is not given, list all resource by using location as ResourceName
    if($null -eq $name -or '' -eq $name)
    {       
        $name = $region
    }

    $params = @{
        ApiVersion = $apiVersion
        ResourceType = $resourceType
        ResourceName = $name
        ResourceGroupName = "system.{0}" -f $region
    }

    $infraResource = Get-AzureRmResource @params
    return $infraResource
}

Export-ModuleMember -function Set-AzsLocationInformation


function Invoke-AzSInfrastructureAction
{
    param(
        [string] $Name,
        [string] $Region,
        [string] $Action,
        [string] $ResourceType
    )
        
    $region = Get-AzSLocation -Location $Region

    $params = @{
        ApiVersion = "2016-05-01"
        Action = $Action
        ResourceType = $ResourceType
        ResourceGroupName = "system.{0}" -f $region
        ResourceName = "{0}/{1}" -f $region, $Name
    }

    Invoke-AzureRmResourceAction @params -Force
}
