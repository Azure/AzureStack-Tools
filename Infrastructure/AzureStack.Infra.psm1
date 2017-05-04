# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0
#requires -Modules AzureStack.Connect


<#
    .SYNOPSIS
    List Active & Closed Infrastructure Alerts
#>
Function Get-AzSAlert{
    [CmdletBinding()]
    Param(

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $tenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
        
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,
        
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
    [CmdletBinding()]
    Param(

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,  
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
        
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)   
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/ScaleUnits?api-version=2016-05-01"
    $Cluster=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Cluster.value |select name,location |fl 
   
}       
export-modulemember -function Get-AzSScaleUnit

<#
    .SYNOPSIS
    List Nodes in Scale Unit 
#>
Function Get-AzSScaleUnitNode{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/scaleunitnodes?api-version=2016-05-01"
    $nodes=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $nodesprop=$nodes.value
    $nodesprop.name
}
       
export-modulemember -function Get-AzSScaleUnitNode

<#
    .SYNOPSIS
    List total storage capacity 
#>
Function Get-AzSStorageCapacity{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)

    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/storagesubSystems?api-version=2016-05-01"
    $Storage=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Storageprop=$storage.value
    $storageprop.properties|select totalcapacityGB|fl
    
}
export-modulemember -function Get-AzSStorageCapacity

<#
    .SYNOPSIS
    List Infrastructure Roles 
#>
Function Get-AzSInfraRole{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )

    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/InfraRoles?api-version=2016-05-01"
    $Roles=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Roleprop=$roles.value
    $Roleprop.Name|fl 
    
}      
export-modulemember -function Get-AzSInfraRole

<#
    .SYNOPSIS
    List Infrastructure Role Instances
#>

Function Get-AzSInfraRoleInstance{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )

    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop
    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraRoleInstances?api-version=2016-05-01"
    $VMs=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $VMprop=$VMs.value
    $VMprop|ft name 
    
}       
export-modulemember -function Get-AzSInfraRoleInstance

<#
    .SYNOPSIS
    List File Shares
#>
Function Get-AzSStorageShare{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/fileShares?api-version=2016-05-01"
    $Shares=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Shareprop=$Shares.value
    $Shareprop.properties|select uncPath|fl
    
}
export-modulemember -function Get-AzSStorageShare

<#
    .SYNOPSIS
    List Logical Networks
#>
Function Get-AzSLogicalNetwork{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/logicalNetworks?api-version=2016-05-01"
    $LNetworks=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $LNetworkprop=$LNetworks.value
    $LNetworkprop|ft name
    
}
export-modulemember -function Get-AzSLogicalNetwork

<#
    .SYNOPSIS
    List Region Update Summary
#>
Function Get-AzSUpdateSummary{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/regionUpdateStatus?api-version=2016-05-01"
    $USummary=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $USummaryprop=$USummary.value
    $USummaryprop.properties|select locationName,currentversion,lastUpdated,lastChecked,state|fl 
    
}
export-modulemember -function Get-AzSUpdateSummary

<#
    .SYNOPSIS
    List Available Updates
#>
Function Get-AzSUpdate{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/updates?api-version=2016-05-01"
    $Updates=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updateprop=$Updates.value
    $Updateprop.properties|select updateName,version,isApplicable,description,state,isDownloaded,packageSizeInMb,kblink|fl
    
}
export-modulemember -function Get-AzSUpdate

<#
    .SYNOPSIS
    List Status for a specific Update Run
#>
Function Get-AzSUpdateRun{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local',

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $vupdate

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Update.Admin/updatelocations/$region/updates/$vupdate/updateRuns?api-version=2016-05-01"
    $UpdateRuns=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updaterunprop=$UpdateRuns.value
    $Updaterunprop.properties|select updateLocation,updateversion,state,timeStarted,duration|fl 
    
}
export-modulemember -function Get-AzSUpdateRun

<#
    .SYNOPSIS
    Apply Azure Stack Update 
#>
Function Install-AzSUpdate{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local',

        [Parameter(Mandatory=$true)]
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
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [Parameter(Mandatory=$false)]
        [string] $region = 'local',

        [Parameter(Mandatory=$true)]
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
    $URI
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
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/IPPools?api-version=2016-05-01"
    $IPPools=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $IPPoolprop=$IPPools.value
    $IPPoolprop.properties|select startIpAddress,endIpAddress,numberOfIpAddresses,numberOfAllocatedIpAddresses |fl
}
export-modulemember -function Get-AzSIPPool


<#
    .SYNOPSIS
    List MAC Address Pools
#>
Function Get-AzSMaCPool{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/MacAddressPools?api-version=2016-05-01"
    $MACPools=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $MaCPoolsprop=$MaCPools.value
    $MaCPoolsprop.properties|select startmacAddress,endmacAddress,numberOfmacAddresses,numberOfAllocatedmacAddresses |fl
}
export-modulemember -function Get-AzSMaCPool

<#
    .SYNOPSIS
   List Gateway Pools
#>

Function Get-AzSGatewayPool{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/edgeGatewayPools?api-version=2016-05-01"
    $GatewayPools=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $MGatewaysprop=$GatewayPools.value
    $MGatewaysprop.properties|select Gatewaytype,numberofgateways,redundantGatewayCount,gatewayCapacityKiloBitsPerSecond,publicIpAddress |fl
}
export-modulemember -function Get-AzSGatewayPool

<#
    .SYNOPSIS
    List SLB MUX
#>


Function Get-AzSSLBMUX{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/SlbMuxInstances?api-version=2016-05-01"
    $SLBMUX=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $SLBMUXprop=$SLBMUX.value
    $SLBMUXprop.properties|select VirtualServer,ConfigurationState |fl
}
export-modulemember -function Get-AzSSLBMUX

<#
    .SYNOPSIS
    List Gateways
#>

Function Get-AzSGateway{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local'

    )
    $ARMEndpoint = GetARMEndpoint -EnvironmentName $EnvironmentName -ErrorAction Stop

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system.$region/providers/Microsoft.Fabric.Admin/fabricLocations/$region/edgegateways?api-version=2016-05-01"
    $Gateways=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Gatewaysprop=$Gateways.value
    $Gatewaysprop.properties|select state, numberofconnections,totalcapacity,availablecapacity |fl
}
export-modulemember -function Get-AzSGateway


<#
    .SYNOPSIS
    Start Infra Role Instance
#>

Function Start-AzSInfraRoleInstance{
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local',

        [Parameter(Mandatory=$true)]
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
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local',

        [Parameter(Mandatory=$true)]
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
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local',

        [Parameter(Mandatory=$true)]
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
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(Mandatory=$true, HelpMessage="The Azure Stack Administrator Environment Name")]
        [string] $EnvironmentName,

        [string] $region = 'local',

        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $StartIPAddress = '',

        [Parameter(Mandatory=$true)]
        [string] $EndIPAddress = '',

        [Parameter(Mandatory=$true)]
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