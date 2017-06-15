# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0
#requires -Modules AzureStack.Connect


<#
    .SYNOPSIS
    List Active & Closed Infrastructure Alerts
#>
Function Get-AzsAlert{
    [CmdletBinding(DefaultParameterSetName='GetAlert')]
    Param(    
        [Parameter(Mandatory=$true, ParameterSetName='GetAlert')]
        [ValidateNotNullorEmpty()]
        [String] $tenantId,
        
        [Parameter(ParameterSetName='GetAlert')]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
        
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetAlert')]
        [string] $EnvironmentName,
        
        [Parameter(ParameterSetName='GetAlert')]
        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.InfrastructureInsights.Admin/regionHealths/$region/Alerts?api-version=2016-05-01"
    $Alert=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Alerts=$Alert.value
    $Alertsprop=$Alerts.properties 
    $Alertsprop 
}
export-modulemember -function Get-AzsAlert

<#
    .SYNOPSIS
    List Azure Stack Scale Units in specified Region
#>
Function Get-AzsScaleUnit{
    [CmdletBinding(DefaultParameterSetName='ScaleUnit')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ScaleUnit')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,  
        
        [Parameter(Mandatory=$true, ParameterSetName='ScaleUnit')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
        
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='ScaleUnit')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='ScaleUnit')]
        [string] $region = 'local'
    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)   
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/ScaleUnits?api-version=2016-05-01"
    $Cluster=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Cluster.value |select name,location,properties
   
}       
export-modulemember -function Get-AzsScaleUnit

<#
    .SYNOPSIS
    List Nodes in Scale Unit 
#>
Function Get-AzsScaleUnitNode{
    [CmdletBinding(DefaultParameterSetName='GetNode')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetNode')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetNode')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetNode')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetNode')]
        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/scaleunitnodes?api-version=2016-05-01"
    $nodes=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $nodesprop=$nodes.value
    $nodesprop|select name,location,properties
}
       
export-modulemember -function Get-AzsScaleUnitNode

<#
    .SYNOPSIS
    List total storage capacity 
#>
Function Get-AzsStorageCapacity{
    [CmdletBinding(DefaultParameterSetName='GetStorageCapacity')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetStorageCapacity')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetStorageCapacity')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetStorageCapacity')]

        [string] $EnvironmentName,


        [Parameter(ParameterSetName='GetStorageCapacity')]
        [string] $region = 'local'
    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)

    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/storagesubSystems?api-version=2016-05-01"
    $Storage=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Storageprop=$storage.value
    $storageprop|select name,location,properties
    
}
export-modulemember -function Get-AzsStorageCapacity

<#
    .SYNOPSIS
    List Infrastructure Roles 
#>

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Get-AzsInfraRole' -Value 'Get-AzsInfrastructureRole' -ErrorAction SilentlyContinue

function Get-AzsInfrastructureRole{
    [CmdletBinding(DefaultParameterSetName='GetInfraRole')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetInfraRole')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetInfraRole')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetInfraRole')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetInfraRole')]
        [string] $region = 'local'
    )

    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/InfraRoles?api-version=2016-05-01"
    $Roles=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $roles.value|select name,properties
    
}      
export-modulemember -function Get-AzsInfrastructureRole

<#
    .SYNOPSIS
    List Infrastructure Role Instances
#>

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Get-AzsInfraRoleInstance' -Value 'Get-AzsInfrastructureRoleInstance' -ErrorAction SilentlyContinue

function Get-AzsInfrastructureRoleInstance{
    [CmdletBinding(DefaultParameterSetName='GetInfraRoleInstance')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetInfraRoleInstance')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetInfraRoleInstance')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetInfraRoleInstance')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetInfraRoleInstance')]
        [string] $region = 'local'
    )

    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraRoleInstances?api-version=2016-05-01"
    $VMs=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $VMprop=$VMs.value
    $VMprop|select name,properties 
    
}       

export-modulemember -function Get-AzsInfrastructureRoleInstance 

<#
    .SYNOPSIS
    List File Shares
#>
Function Get-AzsStorageShare{
    [CmdletBinding(DefaultParameterSetName='GetShare')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetShare')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetShare')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetShare')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetShare')]
        [string] $region = 'local'
    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/fileShares?api-version=2016-05-01"
    $Shares=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Shareprop=$Shares.value
    $Shareprop|select name,location,properties
    
}
export-modulemember -function Get-AzsStorageShare

<#
    .SYNOPSIS
    List Logical Networks
#>
Function Get-AzsLogicalNetwork{
    [CmdletBinding(DefaultParameterSetName='Getlogicalnetwork')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='Getlogicalnetwork')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='Getlogicalnetwork')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='Getlogicalnetwork')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='Getlogicalnetwork')]
        [string] $region = 'local'
    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/logicalNetworks?api-version=2016-05-01"
    $LNetworks=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $LNetworkprop=$LNetworks.value
    $LNetworkprop|select name,location,properties
    
}
export-modulemember -function Get-AzsLogicalNetwork

<#
    .SYNOPSIS
    List Region Update Summary
#>
Function Get-AzsUpdateSummary{
    [CmdletBinding(DefaultParameterSetName='GetUpdateSummary')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateSummary')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateSummary')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetUpdateSummary')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetUpdateSummary')]
        [string] $region = 'local'
    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/regionUpdateStatus?api-version=2016-05-01"
    $USummary=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $USummaryprop=$USummary.value
    $USummaryprop.properties|select locationName,currentversion,lastUpdated,lastChecked,state
    
}
export-modulemember -function Get-AzsUpdateSummary

<#
    .SYNOPSIS
    List Available Updates
#>
Function Get-AzsUpdate{
    [CmdletBinding(DefaultParameterSetName='GetUpdate')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdate')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdate')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetUpdate')]
        [string] $EnvironmentName,


        [Parameter(ParameterSetName='GetUpdate')]
        [string] $region = 'local'
    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/updates?api-version=2016-05-01"
    $Updates=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updateprop=$Updates.value
    $Updateprop.properties|select updateName,version,isApplicable,description,state,isDownloaded,packageSizeInMb,kblink
    
}
export-modulemember -function Get-AzsUpdate

<#
    .SYNOPSIS
    List Status for a specific Update Run
#>
Function Get-AzsUpdateRun{
    [CmdletBinding(DefaultParameterSetName='GetUpdateRun')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateRun')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateRun')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetUpdateRun')]
        [string] $EnvironmentName,


        [Parameter(ParameterSetName='GetUpdateRun')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateRun')]
        [ValidateNotNullorEmpty()]
        [String] $vupdate
    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/updates/$vupdate/updateRuns?api-version=2016-05-01"
    $UpdateRuns=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updaterunprop=$UpdateRuns.value
    $Updaterunprop.properties|select updateLocation,updateversion,state,timeStarted,duration
    
}
export-modulemember -function Get-AzsUpdateRun

<#
    .SYNOPSIS
    Apply Azure Stack Update 
#>
Function Install-AzsUpdate{
    [CmdletBinding(DefaultParameterSetName='ApplyUpdate')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='ApplyUpdate')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='ApplyUpdate')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='ApplyUpdate')]
        [string] $EnvironmentName,


        [Parameter(ParameterSetName='ApplyUpdate')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='ApplyUpdate')]
        [ValidateNotNullorEmpty()]
        [String] $vupdate
    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/updates?api-version=2016-05-01"
    $Updates=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updateprop=$Updates.value
    $Update=$updateprop |where-object {$_.name -eq "$vupdate"}
    $StartUpdateBody = $update | ConvertTo-Json
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/updates/$vupdate ?api-version=2016-05-01"
    $Runs=Invoke-RestMethod -Method PUT -Uri $uri -ContentType 'application/json' -Headers $Headers -Body $StartUpdateBody
    $Startrun=$Runs.value
    $Startrun   
    
}
export-modulemember -function Install-AzsUpdate

<#
    .SYNOPSIS
    Close Active Alert
#>
Function Close-AzsAlert{
    [CmdletBinding(DefaultParameterSetName='closealert')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='closealert')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='closealert')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='closealert')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='closealert')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='closealert')]
        [ValidateNotNullorEmpty()]
        [String] $alertid
    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.InfrastructureInsights.Admin/regionHealths/$region/Alerts?api-version=2016-05-01"
    $Alert=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Alerts=$Alert.value |where-object {$_.properties.alertid -eq "$alertid"}
    $alertname=$alerts.name
    $Alerts.properties.state = "Closed"
    $AlertUpdateBody = $Alerts | ConvertTo-Json
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.InfrastructureInsights.Admin/regionHealths/$region/Alerts/${alertname}?api-version=2016-05-01"
    $Close=Invoke-RestMethod -Method PUT -Uri $uri -ContentType 'application/json' -Headers $Headers -Body $AlertUpdateBody
    $CloseRun=$Close.value
    $closeRun 
    

}
export-modulemember -function Close-AzsAlert

<#
    .SYNOPSIS
    List IP Address Pools
#>

function Get-AzsIpPool{
    [CmdletBinding(DefaultParameterSetName='GetIPPool')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetIPPool')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetIPPool')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetIPPool')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetIPPool')]
        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/IPPools?api-version=2016-05-01"
    $IPPools=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $IPPoolprop=$IPPools.value
    $IPPoolprop.properties|select startIpAddress,endIpAddress,numberOfIpAddresses,numberOfAllocatedIpAddresses
}
export-modulemember -function Get-AzsIpPool


<#
    .SYNOPSIS
    List MAC Address Pools
#>
function Get-AzsMacPool{
    [CmdletBinding(DefaultParameterSetName='GetMaCPool')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetMaCPool')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetMaCPool')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetMaCPool')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetMaCPool')]
        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/MacAddressPools?api-version=2016-05-01"
    $MACPools=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $MaCPoolsprop=$MaCPools.value
    $MaCPoolsprop.properties|select startmacAddress,endmacAddress,numberOfmacAddresses,numberOfAllocatedmacAddresses
}
export-modulemember -function Get-AzsMacPool

<#
    .SYNOPSIS
   List Gateway Pools
#>

Function Get-AzsGatewayPool{
    [CmdletBinding(DefaultParameterSetName='GetGatewayPool')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetGatewayPool')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetGatewayPool')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetGatewayPool')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetGatewayPool')]
        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/edgeGatewayPools?api-version=2016-05-01"
    $GatewayPools=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $MGatewaysprop=$GatewayPools.value
    $MGatewaysprop.properties|select Gatewaytype,numberofgateways,redundantGatewayCount,gatewayCapacityKiloBitsPerSecond,publicIpAddress
}
export-modulemember -function Get-AzsGatewayPool

<#
    .SYNOPSIS
    List SLB MUX
#>


function Get-AzsSlbMux{
    [CmdletBinding(DefaultParameterSetName='GetSLBMUX')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetSLBMUX')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetSLBMUX')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetSLBMUX')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetSLBMUX')]
        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/SlbMuxInstances?api-version=2016-05-01"
    $SLBMUX=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $SLBMUXprop=$SLBMUX.value
    $SLBMUXprop.properties|select VirtualServer,ConfigurationState
}
export-modulemember -function Get-AzsSlbMux

<#
    .SYNOPSIS
    List Gateways
#>

Function Get-AzsGateway{
    [CmdletBinding(DefaultParameterSetName='GetGateway')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetGateway')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetGateway')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetGateway')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetGateway')]
        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/edgegateways?api-version=2016-05-01"
    $Gateways=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Gatewaysprop=$Gateways.value
    $Gatewaysprop.properties|select state, numberofconnections,totalcapacity,availablecapacity
}
export-modulemember -function Get-AzsGateway


<#
    .SYNOPSIS
    Start Infra Role Instance
#>

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Start-AzsInfraRoleInstance' -Value 'Start-AzsInfrastructureRoleInstance' -ErrorAction SilentlyContinue

function Start-AzsInfrastructureRoleInstance{
    [CmdletBinding(DefaultParameterSetName='StartInfraRoleInstance')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='StartInfraRoleInstance')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='StartInfraRoleInstance')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='StartInfraRoleInstance')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='StartInfraRoleInstance')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true,ParameterSetName='StartInfraRoleInstance')]
        [string] $Name

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraroleinstances/$name/poweron?api-version=2016-05-01"
    $PowerON=Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $Headers
    $PowerON
}
export-modulemember -function Start-AzsInfrastructureRoleInstance


<#
    .SYNOPSIS
    Shutdown Infra Role Instance
#>

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Stop-AzsInfraRoleInstance' -Value 'Stop-AzsInfrastructureRoleInstance' -ErrorAction SilentlyContinue

function Stop-AzsInfrastructureRoleInstance{
    [CmdletBinding(DefaultParameterSetName='StopInfraRoleInstance')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='StopInfraRoleInstance')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='StopInfraRoleInstance')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='StopInfraRoleInstance')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='StopInfraRoleInstance')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true,ParameterSetName='StopInfraRoleInstance')]
        [string] $Name

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraroleinstances/$name/shutdown?api-version=2016-05-01"      
    $PowerOff=Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $Headers
    $PowerOff
}
export-modulemember -function Stop-AzsInfrastructureRoleInstance


<#
    .SYNOPSIS
    Restart Infra Role Instance
#>

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Restart-AzsInfraRoleInstance' -Value 'Restart-AzsInfrastructureRoleInstance' -ErrorAction SilentlyContinue

function Restart-AzsInfrastructureRoleInstance{
    [CmdletBinding(DefaultParameterSetName='RestartInfraRoleInstance')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='RestartInfraRoleInstance')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='RestartInfraRoleInstance')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='RestartInfraRoleInstance')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='RestartInfraRoleInstance')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='RestartInfraRoleInstance')]
        [string] $Name

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraroleinstances/$name/reboot?api-version=2016-05-01"      
    $Restart=Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Restart
}
export-modulemember -function Restart-AzsInfrastructureRoleInstance


<#
    .SYNOPSIS
    Add IP Address Pool
#>
function Add-AzsIpPool{
    [CmdletBinding(DefaultParameterSetName='AddIPPool')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='AddIPPool')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='AddIPPool')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='AddIPPool')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='AddIPPool')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true,ParameterSetName='AddIPPool')]
        [string] $Name,

        [Parameter(Mandatory=$true,ParameterSetName='AddIPPool')]
        [string] $StartIPAddress = '',

        [Parameter(Mandatory=$true,ParameterSetName='AddIPPool')]
        [string] $EndIPAddress = '',

        [Parameter(Mandatory=$true,ParameterSetName='AddIPPool')]
        [string] $AddressPrefix = ''

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)      
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/IPPools/'$Name'?api-version=2016-05-01"
    $IPPoolBody=@{
    name=$name
    properties=@{"StartIpAddress"="$StartIPAddress";"EndIpAddress"="$EndIPAddress";"AddressPrefix"="$AddressPrefix"}
    subscription=$subscription
    location=$region
    type='Microsoft.Fabric.Admin/fabricLocations/ipPools'
    id='subscriptions/$subscription/resourcegroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/ipPools/$name'
    tags=''
}

$IPPoolBodyJson =$IPPoolBody |ConvertTo-Json
    $NewIPPool=Invoke-RestMethod -Method Put -Uri $uri -ContentType 'application/json' -Headers $Headers -Body $IPPoolBodyJson

}
export-modulemember -function function Add-AzsIpPool


<#
    .SYNOPSIS
    Enable Maintenance Mode
#>

Function Disable-AzsScaleUnitNode{
    [CmdletBinding(DefaultParameterSetName='DisableAzsScaleUnitNode')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='DisableAzsScaleUnitNode')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='DisableAzsScaleUnitNode')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='DisableAzsScaleUnitNode')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='DisableAzsScaleUnitNode')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='DisableAzsScaleUnitNode')]
        [string] $Name

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
 
    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/scaleunitnodes/$name/StartMaintenanceMode?api-version=2016-05-01"      
    $Drain=Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Drain
   
}
export-modulemember -function Disable-AzsScaleUnitNode


<#
    .SYNOPSIS
    Enable Maintenance Mode
#>

Function Enable-AzsScaleUnitNode{
    [CmdletBinding(DefaultParameterSetName='EnableAzsScaleUnitNode')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='EnableAzsScaleUnitNode')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='EnableAzsScaleUnitNode')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

	    [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='EnableAzsScaleUnitNode')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='EnableAzsScaleUnitNode')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='EnableAzsScaleUnitNode')]
        [string] $Name

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
   
    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/scaleunitnodes/$name/StopMaintenanceMode?api-version=2016-05-01"      
    $Resume=Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Resume
    
}
export-modulemember -function Enable-AzsScaleUnitNode


<#
    .SYNOPSIS
    Get Region Capacity
#>

Function Get-AzsRegionCapacity{
    [CmdletBinding(DefaultParameterSetName='GetRegionCapacity')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetRegionCapacity')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetRegionCapacity')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

	    [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name", ParameterSetName='GetRegionCapacity')]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName='GetRegionCapacity')]
        [string] $region = 'local'

        

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
   
    $subscription, $headers =  (Get-AzsAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.InfrastructureInsights.Admin/regionHealths?api-version=2016-05-01"
    $Capacity=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $RCapacity=$Capacity.value
    $RCapacity| select name,properties

    
}
export-modulemember -function Get-AzsRegionCapacity


Function Set-AzsLocationInformation {
    Param(    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential] $AzureStackCredentials,

        [Parameter(Mandatory = $true)]
        [string] $EnvironmentName,

        [Parameter(Mandatory = $true)]
        [string] $Region = 'local',

        [Parameter(Mandatory = $true)]
        [string] $Latitude = '47.608013',

        [Parameter(Mandatory = $true)]
        [string] $Longitude = '-122.335167'
    )
    $ArmEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
    $subscription, $headers = (Get-AzsAdminSubTokenHeader -TenantId $TenantId -AzureStackCredentials $AzureStackCredentials -EnvironmentName $EnvironmentName)
    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Subscriptions.Admin/locations/{2}?api-version=2015-11-01" -f $ArmEndpoint, $subscription, $Region

    $obtainedRegion = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $headers
    $obtainedRegion.latitude = $Latitude
    $obtainedRegion.longitude = $Longitude

    Invoke-WebRequest -Uri $uri -Method PUT -Body $(Convertto-Json $obtainedRegion) -ContentType 'application/json' -Headers $headers
}
Export-ModuleMember -function Set-AzsLocationInformation

Function GetARMEndpoint{
    param(
        # Azure Stack environment name
        [Parameter(Mandatory=$true)]
        [string] $EnvironmentName
        
    )

    $armEnv = Get-AzureRmEnvironment -Name $EnvironmentName
    if($armEnv -ne $null) {
        $ARMEndpoint = $armEnv.ResourceManagerUrl
    }
    else {
        Write-Error "The Azure Stack environment with the name $EnvironmentName does not exist. Create one with Add-AzsEnvironment." -ErrorAction Stop
    }

    $ARMEndpoint
}
