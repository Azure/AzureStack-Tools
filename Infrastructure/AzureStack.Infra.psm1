# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0
#requires -Modules AzureStack.Connect


<#
    .SYNOPSIS
    List Active & Closed Infrastructure Alerts
#>
Function Get-AzSAlert{
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
    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.InfrastructureInsights.Admin/regionHealths/$region/Alerts?api-version=2016-05-01"
    $Alert=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Alerts=$Alert.value
    $Alertsprop=$Alerts.properties 
    $Alertsprop 
}
export-modulemember -function Get-AzSAlert

<#
    .SYNOPSIS
    List Azure Stack Scale Units in specified Region
#>
Function Get-AzSScaleUnit{
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
    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)   
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/ScaleUnits?api-version=2016-05-01"
    $Cluster=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Cluster.value |select name,location,properties
   
}       
export-modulemember -function Get-AzSScaleUnit

<#
    .SYNOPSIS
    List Nodes in Scale Unit 
#>
Function Get-AzSScaleUnitNode{
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
    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/scaleunitnodes?api-version=2016-05-01"
    $nodes=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $nodesprop=$nodes.value
    $nodesprop|select name,location,properties
}
       
export-modulemember -function Get-AzSScaleUnitNode

<#
    .SYNOPSIS
    List total storage capacity 
#>
Function Get-AzSStorageCapacity{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)

    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/storagesubSystems?api-version=2016-05-01"
    $Storage=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Storageprop=$storage.value
    $storageprop|select name,location,properties
    
}
export-modulemember -function Get-AzSStorageCapacity

<#
    .SYNOPSIS
    List Infrastructure Roles 
#>
Function Get-AzSInfraRole{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/InfraRoles?api-version=2016-05-01"
    $Roles=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $roles.value|select name,properties
    
}      
export-modulemember -function Get-AzSInfraRole

<#
    .SYNOPSIS
    List Infrastructure Role Instances
#>

Function Get-AzSInfraRoleInstance{
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
    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraRoleInstances?api-version=2016-05-01"
    $VMs=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $VMprop=$VMs.value
    $VMprop|select name,properties 
    
}       
export-modulemember -function Get-AzSInfraRoleInstance

<#
    .SYNOPSIS
    List File Shares
#>
Function Get-AzSStorageShare{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/fileShares?api-version=2016-05-01"
    $Shares=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Shareprop=$Shares.value
    $Shareprop|select name,location,properties
    
}
export-modulemember -function Get-AzSStorageShare

<#
    .SYNOPSIS
    List Logical Networks
#>
Function Get-AzSLogicalNetwork{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/logicalNetworks?api-version=2016-05-01"
    $LNetworks=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $LNetworkprop=$LNetworks.value
    $LNetworkprop|select name,location,properties
    
}
export-modulemember -function Get-AzSLogicalNetwork

<#
    .SYNOPSIS
    List Region Update Summary
#>
Function Get-AzSUpdateSummary{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/regionUpdateStatus?api-version=2016-05-01"
    $USummary=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $USummaryprop=$USummary.value
    $USummaryprop.properties|select locationName,currentversion,lastUpdated,lastChecked,state
    
}
export-modulemember -function Get-AzSUpdateSummary

<#
    .SYNOPSIS
    List Available Updates
#>
Function Get-AzSUpdate{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/updates?api-version=2016-05-01"
    $Updates=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updateprop=$Updates.value
    $Updateprop.properties|select updateName,version,isApplicable,description,state,isDownloaded,packageSizeInMb,kblink
    
}
export-modulemember -function Get-AzSUpdate

<#
    .SYNOPSIS
    List Status for a specific Update Run
#>
Function Get-AzSUpdateRun{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/updates/$vupdate/updateRuns?api-version=2016-05-01"
    $UpdateRuns=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updaterunprop=$UpdateRuns.value
    $Updaterunprop.properties|select updateLocation,updateversion,state,timeStarted,duration
    
}
export-modulemember -function Get-AzSUpdateRun

<#
    .SYNOPSIS
    Apply Azure Stack Update 
#>
Function Install-AzSUpdate{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
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
export-modulemember -function Install-AzSUpdate

<#
    .SYNOPSIS
    Close Active Alert
#>
Function Close-AzSAlert{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
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
export-modulemember -function Close-AzSAlert

<#
    .SYNOPSIS
    List IP Address Pools
#>
Function Get-AzSIPPool{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/IPPools?api-version=2016-05-01"
    $IPPools=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $IPPoolprop=$IPPools.value
    $IPPoolprop.properties|select startIpAddress,endIpAddress,numberOfIpAddresses,numberOfAllocatedIpAddresses
}
export-modulemember -function Get-AzSIPPool


<#
    .SYNOPSIS
    List MAC Address Pools
#>
Function Get-AzSMaCPool{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/MacAddressPools?api-version=2016-05-01"
    $MACPools=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $MaCPoolsprop=$MaCPools.value
    $MaCPoolsprop.properties|select startmacAddress,endmacAddress,numberOfmacAddresses,numberOfAllocatedmacAddresses
}
export-modulemember -function Get-AzSMaCPool

<#
    .SYNOPSIS
   List Gateway Pools
#>

Function Get-AzSGatewayPool{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/edgeGatewayPools?api-version=2016-05-01"
    $GatewayPools=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $MGatewaysprop=$GatewayPools.value
    $MGatewaysprop.properties|select Gatewaytype,numberofgateways,redundantGatewayCount,gatewayCapacityKiloBitsPerSecond,publicIpAddress
}
export-modulemember -function Get-AzSGatewayPool

<#
    .SYNOPSIS
    List SLB MUX
#>


Function Get-AzSSLBMUX{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/SlbMuxInstances?api-version=2016-05-01"
    $SLBMUX=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $SLBMUXprop=$SLBMUX.value
    $SLBMUXprop.properties|select VirtualServer,ConfigurationState
}
export-modulemember -function Get-AzSSLBMUX

<#
    .SYNOPSIS
    List Gateways
#>

Function Get-AzSGateway{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/edgegateways?api-version=2016-05-01"
    $Gateways=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Gatewaysprop=$Gateways.value
    $Gatewaysprop.properties|select state, numberofconnections,totalcapacity,availablecapacity
}
export-modulemember -function Get-AzSGateway


<#
    .SYNOPSIS
    Start Infra Role Instance
#>

Function Start-AzSInfraRoleInstance{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraroleinstances/$name/poweron?api-version=2016-05-01"
    $PowerON=Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $Headers
    $PowerON
}
export-modulemember -function Start-AzSInfraRoleInstance


<#
    .SYNOPSIS
    Shutdown Infra Role Instance
#>

Function Stop-AzSInfraRoleInstance{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraroleinstances/$name/shutdown?api-version=2016-05-01"      
    $PowerOff=Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $Headers
    $PowerOff
}
export-modulemember -function Stop-AzSInfraRoleInstance


<#
    .SYNOPSIS
    Restart Infra Role Instance
#>

Function Restart-AzSInfraRoleInstance{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraroleinstances/$name/reboot?api-version=2016-05-01"      
    $Restart=Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Restart
}
export-modulemember -function Restart-AzSInfraRoleInstance


<#
    .SYNOPSIS
    Add IP Address Pool
#>

Function Add-AzSIPPool{
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

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)      
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
export-modulemember -function Add-AzSIPPool

Function Set-AzSLocationInformation {
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
    $subscription, $headers = (Get-AzureStackAdminSubTokenHeader -TenantId $TenantId -AzureStackCredentials $AzureStackCredentials -EnvironmentName $EnvironmentName)
    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Subscriptions.Admin/locations/{2}?api-version=2015-11-01" -f $ArmEndpoint, $subscription, $Region

    $obtainedRegion = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $headers
    $obtainedRegion.latitude = $Latitude
    $obtainedRegion.longitude = $Longitude

    Invoke-WebRequest -Uri $uri -Method PUT -Body $(Convertto-Json $obtainedRegion) -ContentType 'application/json' -Headers $headers
}
Export-ModuleMember -function Set-AzSLocationInformation

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
        Write-Error "The Azure Stack environment with the name $EnvironmentName does not exist. Create one with Add-AzureStackAzureRmEnvironment." -ErrorAction Stop
    }

    $ARMEndpoint
}

# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJM8woBYUS+5kLLBpSZKh8zKa
# r+WgghhlMIIEwzCCA6ugAwIBAgITMwAAAMWWQGBL9N6uLgAAAAAAxTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODUy
# WhcNMTgwOTA3MTc1ODUyWjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkMwRjQtMzA4Ni1ERUY4MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtrwz4CWOpvnw
# EBVOe1crKElrs3CQl/yun1cdkpugh/MxsuoGn7BL43GRTxRn7sPD7rq1Dxj4smPl
# gVZr/ZhGMA8J3zXOqyIcD4hYFikXuhlGuuSokunCAxUl5N4gjN/M7+NwJPm2JtYK
# ZLBdH5J/y+GIk7rQhpgbstpLOZf4GHgC8Myji7089O1uX2MCKFFU+wt2Y560O4Xc
# 2NVjeuG+nnq5pGyq9111nK3f0DeT7FWjDVQWFghKOhyeBb4iMhmkdA8vWpYmx6TN
# c+d35nSZcLc0EhSIVJkzEBYfwkrzxFaG/pgNJ9C4jm/zHgwWLZwQpU7K2fP15fGk
# BGplwNjr1wIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFA4B9X87yXgCWEZxOwn8mnVX
# hjjEMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAAUS3tgSEzCpyuw21ySUAWvGltQxunyLUCaOf1dffUcG25oa
# OW/WuIFJs0lv8Py6TsOrulsx/4NTkIyXra/MsJvwczMX2s/vx6g63O3osQI85qHD
# dp8IMULGmry+oqPVTuvL7Bac905EqqGXGd9UY7y14FcKWBWJ28vjncTw8CW876pY
# 80nSm8hC/38M4RMGNEp7KGYxx5ZgGX3NpAVeUBio7XccXHEy7CSNmXm2V8ijeuGZ
# J9fIMkhiAWLEfKOgxGZ63s5yGwpMt2QE/6Py03uF+X2DHK76w3FQghqiUNPFC7uU
# o9poSfArmeLDuspkPAJ46db02bqNyRLP00bczzwwggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TCCBhEwggP5
# oAMCAQICEzMAAACOh5GkVxpfyj4AAAAAAI4wDQYJKoZIhvcNAQELBQAwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xNjExMTcyMjA5MjFaFw0xODAy
# MTcyMjA5MjFaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQh9RCK36d2cZ61KLD4xWS
# 0lOdlRfJUjb6VL+rEK/pyefMJlPDwnO/bdYA5QDc6WpnNDD2Fhe0AaWVfIu5pCzm
# izt59iMMeY/zUt9AARzCxgOd61nPc+nYcTmb8M4lWS3SyVsK737WMg5ddBIE7J4E
# U6ZrAmf4TVmLd+ArIeDvwKRFEs8DewPGOcPUItxVXHdC/5yy5VVnaLotdmp/ZlNH
# 1UcKzDjejXuXGX2C0Cb4pY7lofBeZBDk+esnxvLgCNAN8mfA2PIv+4naFfmuDz4A
# lwfRCz5w1HercnhBmAe4F8yisV/svfNQZ6PXlPDSi1WPU6aVk+ayZs/JN2jkY8fP
# AgMBAAGjggGAMIIBfDAfBgNVHSUEGDAWBgorBgEEAYI3TAgBBggrBgEFBQcDAzAd
# BgNVHQ4EFgQUq8jW7bIV0qqO8cztbDj3RUrQirswUgYDVR0RBEswSaRHMEUxDTAL
# BgNVBAsTBE1PUFIxNDAyBgNVBAUTKzIzMDAxMitiMDUwYzZlNy03NjQxLTQ0MWYt
# YmM0YS00MzQ4MWU0MTVkMDgwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1
# ApUwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEF
# BQcBAQRVMFMwUQYIKwYBBQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNV
# HRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBEiQKsaVPzxLa71IxgU+fKbKhJ
# aWa+pZpBmTrYndJXAlFq+r+bltumJn0JVujc7SV1eqVHUqgeSxZT8+4PmsMElSnB
# goSkVjH8oIqRlbW/Ws6pAR9kRqHmyvHXdHu/kghRXnwzAl5RO5vl2C5fAkwJnBpD
# 2nHt5Nnnotp0LBet5Qy1GPVUCdS+HHPNIHuk+sjb2Ns6rvqQxaO9lWWuRi1XKVjW
# kvBs2mPxjzOifjh2Xt3zNe2smjtigdBOGXxIfLALjzjMLbzVOWWplcED4pLJuavS
# Vwqq3FILLlYno+KYl1eOvKlZbiSSjoLiCXOC2TWDzJ9/0QSOiLjimoNYsNSa5jH6
# lEeOfabiTnnz2NNqMxZQcPFCu5gJ6f/MlVVbCL+SUqgIxPHo8f9A1/maNp39upCF
# 0lU+UK1GH+8lDLieOkgEY+94mKJdAw0C2Nwgq+ZWtd7vFmbD11WCHk+CeMmeVBoQ
# YLcXq0ATka6wGcGaM53uMnLNZcxPRpgtD1FgHnz7/tvoB3kH96EzOP4JmtuPe7Y6
# vYWGuMy8fQEwt3sdqV0bvcxNF/duRzPVQN9qyi5RuLW5z8ME0zvl4+kQjOunut6k
# LjNqKS8USuoewSI4NQWF78IEAA1rwdiWFEgVr35SsLhgxFK1SoK3hSoASSomgyda
# Qd691WZJvAuceHAJvDCCB3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEx
# MB4XDTExMDcwODIwNTkwOVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUg
# U2lnbmluZyBQQ0EgMjAxMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AKvw+nIQHC6t2G6qghBNNLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL
# 8DjCmQawyDnVARQxQtOJDXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/X
# llnKYBoF6WZ26DJSJhIv56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5k
# NXimoGMPLdNAk/jj3gcN1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJ
# Xtjt7UORg9l7snuGG9k+sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4
# ftKdgCz1TlaRITUlwzluZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgo
# tswnKDglmDlKNs98sZKuHCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0Xpb
# L9Uj43BdD1FGd7P4AOG8rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy
# 5yTfv0aZxe/CHFfbg43sTUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9
# Z4DmimJ4X7IvhNdXnFy/dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4
# IFgsE11glZo+TzOE2rCIF96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQ
# BgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUw
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0f
# BFMwUTBPoE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcB
# AQRSMFAwTgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kv
# Y2VydHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGX
# MIGUMIGRBgkrBgEEAYI3LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcC
# AjA0HjIgHQBMAGUAZwBhAGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUA
# bgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFj
# kplCln3SeQyQwWVfLiw++MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtG
# UFXYDJJ80hpLHPM8QotS0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32m
# kHSDjfTLJgJGKsKKELukqQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr
# 3vw70L01724lruWvJ+3Q3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYK
# wsatruWy2dsViFFFWDgycScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6C
# PxNNZgvAs0314Y9/HG8VfUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX
# 0O5dY0HjWwechz4GdwbRBrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADW
# oUa9WfOXpQlLSBCZgB/QACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9r
# t0uX4ut1eBrs6jeZeRhL/9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGd
# Vk5Pv4BXIqF4ETIheu9BCrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9
# bW1qyVJzEw16UM0xggTlMIIE4QIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5n
# IFBDQSAyMDExAhMzAAAAjoeRpFcaX8o+AAAAAACOMAkGBSsOAwIaBQCggfkwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFPqGGJ1LL0f8pGpIG6Oi5wggkcU4MIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEAguMvMiVbrQdCiBgzKQ4cOzTGaA7bEW1D
# H4YqKnZcZI5Ky4hfdyv72SuEK+txcR8LqQrSjoisXsauVq/0C+P2BsFNIWbuyddc
# FzSzEMnEo4hxhg9tW/zeIhUX8dv5rEHU4cA58ND2Q9Y/sQeHrbcRyHRZpV9KjmQo
# 5wAXR8pbHwHhRD+e7mr9IubRdyaUq1+SFiu2EEizhyIYQBmqO3jL+V4QZWK37EHZ
# IvaCrxsZwFEsthknygQVb0yy60Oej6iIO6CLWtE6QIfd60CCM+IQq3qZBRKZjQzj
# i7bx2ELrRk5aey3N4UbqJRjuWVWphLvL58F3SIUMFNZyDaG5apCBZqGCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADFlkBgS/Teri4AAAAAAMUwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxNFowIwYJ
# KoZIhvcNAQkEMRYEFCLHbcg9mUhGjKuU6ibddMsL+xrUMA0GCSqGSIb3DQEBBQUA
# BIIBAI93z4BoO0wTwbUBjDMCAeBV73YewCdbluK8CahyrmOvvwed7kS1zT9dHOoL
# cVz36E8mtaUUPwxvCBTphGyapDvRmRbB6vI20+A+1IKVakPyTW05xbSVnzTN2+3g
# OLpDY6OmnMqZBwp5BpFPVGf/EZvdratyL8/jaU9CPwLogIpm5Q7jETl4JrsdbPx4
# hzrIazqjbeRLKFzwi0hZZVVJNOoulKL/TaONz2uph+KoEMarFhEf4ZMqrKtB7Xh8
# im70TAKS/ykFVqB/FC4DsEB3q/mRHjccjTkyW582FIU0RwkU+FGx3dES6zM+sg1x
# zVEThzmxRVrV/aMB0/XsasojhlQ=
# SIG # End signature block
