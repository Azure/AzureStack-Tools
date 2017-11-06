# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0

<#
    .SYNOPSIS
    List Active & Closed Infrastructure Alerts
#>

function Get-AzsAlert {
    Param(
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
function Get-AzsInfrastructureShare {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $Location
    )
    
    $resourceType = "Microsoft.Fabric.Admin/fabricLocations/fileShares"

    $shares = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $shares
}

Export-ModuleMember -Function Get-AzsInfrastructureShare

<#
    .SYNOPSIS
    List Logical Networks
#>

function Get-AzsLogicalNetwork {
    Param(
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
        [string] $Location,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $Update
    )
    
    $Location = Get-AzsHomeLocation -Location $Location
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
function Close-AzSAlert {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $Location,

        [ValidateNotNullorEmpty()]
        [String] $AlertId
    )

    
    $Location = Get-AzsHomeLocation -Location $Location

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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )
    
    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure you want to start $Name ?", "")) {
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
        [Parameter(Mandatory = $false)]
        [string] $Location,
       
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )

    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure you want to shut down $Name ?", "")) {
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
        [Parameter(Mandatory = $false)]
        [string] $Location,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )

    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure you want to restart $Name ?", "")) {
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
        [Parameter(Mandatory = $false)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $StartIPAddress,

        [Parameter(Mandatory = $true)]
        [string] $EndIPAddress,

        [string] $AddressPrefix = ''
    )

    $Location = Get-AzsHomeLocation -Location $Location
    
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
        [Parameter(Mandatory = $false)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )

    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure you want to disable scale unit node $Name ?", "")) {
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
        [Parameter(Mandatory = $false)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )
    
    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure you want to enable scale unit node $Name ?", "")) {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"

        Invoke-AzsInfrastructureAction -Action "StopMaintenanceMode" -Name $Name -Location $Location -ResourceType $resourceType
    }
}

Export-ModuleMember -Function Enable-AzsScaleUnitNode

<#
    .SYNOPSIS
    Repairs a scale unit node by reimaging and readding a specific node
#>

function Repair-AzsScaleUnitNode {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $false)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $BMCIPv4Address,

        [switch] $Force
    )
    
    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure you want to repair scale unit node $ScaleUnitNodeName ?", "")) {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"

        $parameters = @{
            bmcIPv4Address = $BMCIPv4Address
        }

        Invoke-AzsInfrastructureAction -Action "Repair" -Name $Name -Location $Location -ResourceType $resourceType -Parameters $parameters
    }
}

Export-ModuleMember -Function Repair-AzsScaleUnitNode

<#
    .SYNOPSIS
    Powers off a scale unit node
#>

function Stop-AzsScaleUnitNode {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $false)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )
    
    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure you want to stop scale unit node $ScaleUnitNodeName ?", "")) {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"

        Invoke-AzsInfrastructureAction -Action "PowerOff" -Name $Name -Location $Location -ResourceType $resourceType
    }
}

Export-ModuleMember -Function Stop-AzsScaleUnitNode

<#
    .SYNOPSIS
    Powers on a scale unit node
#>

function Start-AzsScaleUnitNode {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $false)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string] $Name,

        [switch] $Force
    )
    
    if ($Force.IsPresent -or $PSCmdlet.ShouldContinue("Are you sure you want to start scale unit node $ScaleUnitNodeName ?", "")) {
        $resourceType = "Microsoft.Fabric.Admin/fabricLocations/scaleunitnodes"

        Invoke-AzsInfrastructureAction -Action "PowerOn" -Name $Name -Location $Location -ResourceType $resourceType
    }
}

Export-ModuleMember -Function Start-AzsScaleUnitNode

<#
    .SYNOPSIS
    Get Location Capacity
#>
function Get-AzsLocationCapacity {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $Location
    )
        
    $Location = Get-AzsHomeLocation -Location $Location
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
        [Parameter(Mandatory = $false)]
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
        [Parameter(Mandatory = $false)]
        [string] $Location
    )

    $resourceType = "Microsoft.Backup.Admin/backupLocations/backups"

    $backuplocation = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $backuplocation.Properties
}

Export-ModuleMember -Function Get-AzsBackup

<#
    .SYNOPSIS
    Set Azure Stack geographic location information
#>

function Set-AzSLocationInformation {
    param(
        [Parameter(Mandatory = $false)]
        [string] $Location,
		
        [Parameter(Mandatory = $true)] 
        [string] $Latitude = '47.608013', 

        [Parameter(Mandatory = $true)] 
        [string] $Longitude = '-122.335167' 
	)
	
    $Location = Get-AzsHomeLocation -Location $Location
	
	$resourceType = "Microsoft.Subscriptions.Admin/locations"
	$apiVersion = "2015-11-01"
		
	$locationResource = Get-AzureRmResource -ResourceType $resourceType -ResourceName $Location -ApiVersion $apiVersion
	
    $params = @{
        ResourceName      = $Location
        ResourceType      = $resourceType
        ApiVersion        = $apiVersion
        Properties        = @{
            Id            = $locationResource.ResourceId
            Name          = $locationResource.Name
            DisplayName   = $locationResource.Name
            Latitude      = $Latitude
            Longitude     = $Longitude
        }
    }
	
	New-AzureRmResource @params -IsFullObject -Force
}

<#
    .SYNOPSIS
    Start Infrastructure Backup
#>
function Start-AzsBackup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $false)]
        [string] $Location
    )

        $resourceType = "Microsoft.Backup.Admin/backupLocations"
        Invoke-AzsInfrastructureAction -Name $Location -Action "createbackup" -Location $Location -ResourceType $resourceType
}

Export-ModuleMember -Function Start-AzsBackup

<#
    .SYNOPSIS
    Restore Infrastructure Backup
#>
function Restore-AzsBackup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location,

         [Parameter(Mandatory = $true)]
        [string] $Name

    )

        $resourceType = "Microsoft.Backup.Admin/backupLocations/backups"
        Invoke-AzsInfrastructureAction -Name $Name -Action "restore" -Location $Location -ResourceType $resourceType
}

Export-ModuleMember -Function Restore-AzsBackup

<#
    .SYNOPSIS
    List Resource Provider Healths
#>

function Get-AzsResourceProviderHealths {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location

    )

    $resourceType = "Microsoft.InfrastructureInsights.Admin/regionHealths/serviceHealths"

    $rolehealth = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $rolehealth.Properties
}

Export-ModuleMember -Function Get-AzsResourceProviderHealths

<#
    .SYNOPSIS
    List Infrastructure Role Healths
#>

function Get-AzsInfrastructureRoleHealths {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $Location

    )
    $RP=Get-AzsResourceProviderHealths -Location $location|where {$_.DisplayName -eq "Capacity"}
    $ID=$RP.RegistrationID
    $resourceType = "Microsoft.InfrastructureInsights.Admin/regionHealths/serviceHealths/$ID/resourceHealths"

    $rolehealth = Get-AzsInfrastructureResource -Location $Location -resourceType $resourceType
    $rolehealth.Properties
}

Export-ModuleMember -Function Get-AzsInfrastructureRoleHealths

function Get-AzsHomeLocation {
    param(
        [Parameter(Mandatory = $false)]
        [string] $Location
    )

    if ($Location) {
        return $Location
    }

    $locationResource = Get-AzsLocation
    return $locationResource.Name
}

function Get-AzsInfrastructureResource {
    param(
        [Parameter(Mandatory = $false)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Location,

        [Parameter(Mandatory = $false)]
        [string] $ApiVersion = "2016-05-01",

        [string] $ResourceType
    )
    
    $Location = Get-AzsHomeLocation -Location $Location

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

Export-ModuleMember -Function Set-AzsLocationInformation

<#
    .SYNOPSIS
    Set Backup Share
#>
function Set-AzSBackupShare {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$UserName,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $false)]
        [string]$EncryptionKey
    )

    $Location = Get-AzsHomeLocation -Location $Location
    
    $params = @{
        ResourceName      = $Location
        ResourceType      = "Microsoft.Backup.Admin/backupLocations"
        ResourceGroupName = "system.{0}" -f $Location
        ApiVersion        = "2016-05-01"
        Properties        = @{externalStoreDefault=@{path = $Path;userName = $UserName;password = $Password;EncryptionKeyBase64=$EncryptionKey }} 
        location          = $location
    }

    New-AzureRmResource @params -Force
}

Export-ModuleMember -Function Set-AzSBackupShare

<#
    .SYNOPSIS
    Generate encryption key for infrastructure backups
#>
function New-EncryptionKeyBase64 {
    $tempEncryptionKeyString = ""
    foreach($i in 1..64) { $tempEncryptionKeyString += -join ((65..90) + (97..122) | Get-Random | % {[char]$_}) }
    $tempEncryptionKeyBytes = [System.Text.Encoding]::UTF8.GetBytes($tempEncryptionKeyString)
    $BackupEncryptionKeyBase64 = [System.Convert]::ToBase64String($tempEncryptionKeyBytes)
    $BackupEncryptionKeyBase64
}

Export-ModuleMember -Function New-EncryptionKeyBase64

function Invoke-AzsInfrastructureAction {
    param(
        [string] $Name,
        [string] $Location,
        [string] $Action,
        [string] $ResourceType,

        [Parameter(Mandatory = $false)]
        [Hashtable] $Parameters = $null
    )

    $Location = Get-AzsHomeLocation -Location $Location

    $params = @{
        ApiVersion        = "2016-05-01"
        Action            = $Action
        ResourceType      = $ResourceType
        ResourceGroupName = "system.{0}" -f $Location
        ResourceName      = "{0}/{1}" -f $Location, $Name
    }

    if ($Parameters)
    {
        $params.Parameters = $Parameters
    }

    Invoke-AzureRmResourceAction @params -Force
}
