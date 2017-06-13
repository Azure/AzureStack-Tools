# Azure Stack Infrastructure Administration

Instructions below are relative to the .\Infrastructure folder of the [AzureStack-Tools repo](..).
This also requires the Azure Stack Connect Module to be imported before running any of the commands. The Module can also be found in the [AzureStack-Tools repo](..).

Whats new for TP3:

- New Cmdlet Name Prefix
- API Resource Name changes
- New cmdlets
- Use of Azure Stack Connect Module

## Import the Module

```powershell
Import-Module .\AzureStack.Infra.psm1
```

## Add PowerShell environment
```powershell
Import-Module .\AzureStack.Connect.psm1
```

You will need to reference your Azure Stack Administrator environment. To create an administrator environment use the below. The ARM endpoint below is the administrator default for a one-node environment.

```powershell
Add-AzureStackAzureRmEnvironment -Name "AzureStackAdmin" -ArmEndpoint "https://adminmanagement.local.azurestack.external"
```

Connecting to your environment requires that you obtain the value of your Directory Tenant ID. For **Azure Active Directory** environments provide your directory tenant name:

```powershell
$TenantID = Get-DirectoryTenantID -AADTenantName "<mydirectorytenant>.onmicrosoft.com" -EnvironmentName AzureStackAdmin
```

For **ADFS** environments use the following:

```powershell
$TenantID = Get-DirectoryTenantID -ADFS -EnvironmentName AzureStackAdmin
```

Then login:

```powershell
Login-AzureRmAccount -EnvironmentName "AzureStackAdmin" -TenantId $TenantID
```

## Individual Command Usage

Explains each individual command and shows how to use it

### Retrieve Infrastructure Alerts

List active and closed Infrastructure Alerts

```powershell
Get-AzSAlert
```

The command does the following:
- Retrieves Active & Closed Alerts


### Close Infrastructure Alerts

 Close any active Infrastructure Alert. Run Get-AzSAlert to get the AlertID, required to close a specific Alert.

```powershell
Close-AzSAlert -AlertID "ID"
```

The command does the following:
- Close active Alert


### Get Region Update Summary

 Review the Update Summary for a specified region.

```powershell
Get-AzSUpdateSummary
```

The command does the following:
- Retrieves Region Update Summary


### Get Azure Stack Update

 Retrieves list of Azure Stack Updates

```powershell
Get-AzSUpdate
```

The command does the following:
- List Azure Stack Updates


### Apply Azure Stack Update

 Applies a specific Azure Stack Update that is downloaded and applicable. Run Get-AzureStackUpdate to retrieve Update Version first

```powershell
Install-AzSUpdate -Update "Update Version"
```

The command does the following:
- Applies specified Update


### Get Azure Stack Update Run

 Should be used to validate a specific Update Run or look at previous update runs

```powershell
Get-AzSUpdateRun -Update "Update Version"
```

The command does the following:
- Lists Update Run information for a specific Azure Stack update


### List Infrastructure Roles

 Does list all Infrastructure Roles

```powershell
Get-AzSInfraRole
```

The command does the following:
- Lists Infrastructure Roles


### List Infrastructure Role Instance

 Does list all Infrastructure Role Instances (Note: Does not return Directory Management VM in One Node deployment)

```powershell
Get-AzSInfraRoleInstance
```

The command does the following:
- Lists Infrastructure Role Instances


### List Scale Unit

 Does list all Scale Units in a specified Region

```powershell
Get-AzSScaleUnit
```

The command does the following:
- Lists Scale Units


### List Scale Unit Nodes

 Does list all Scale Units Nodes

```powershell
Get-AzSScaleUnitNode
```

The command does the following:
- Lists Scale Unit Nodes


### List Logical Networks

 Does list all logical Networks by ID

```powershell
Get-AzSLogicalNetwork
```

The command does the following:
- Lists logical Networks


### List Storage Capacity

 Does return the total capacity of the storage subsystem

```powershell
Get-AzSStorageCapacity
```

The command does the following:
- Lists total storage capacity for the storage subsystem


### List Storage Shares

 Does list all file shares in the storage subsystem

```powershell
Get-AzSStorageShare
```

The command does the following:
- Retrieves all file shares


### List IP Pools

 Does list all IP Pools

```powershell
Get-AzSIPPool
```

The command does the following:
- Retrieves all IP Pools


### List MAC Address Pools

 Does list all MAC Address Pool

```powershell
Get-AzSMacPool
```

The command does the following:
- Retrieves all MAC Address Pools


### List Gateway Pools

 Does list all Gateway Pools

```powershell
Get-AzSGatewayPool
```

The command does the following:
- Retrieves all Gateway Pools


### List SLB MUX

 Does list all SLB MUX Instances

```powershell
Get-AzSSLBMUX
```

The command does the following:
- Retrieves all SLB MUX instances


### List Gateway Instances

 Does list all Gateway Instances

```powershell
Get-AzSGateway
```

The command does the following:
- Retrieves all Gateway instances


### Start Infra Role Instance

 Does start an Infra Role Instance

```powershell
Start-AzSInfraRoleInstance -Name "InfraRoleInstanceName"
```

The command does the following:
- Starts an Infra Role instance


### Stop Infra Role Instance

 Does stop an Infra Role Instance

```powershell
Stop-AzSInfraRoleInstance -Name "InfraRoleInstanceName"
```

The command does the following:
- Stops an Infra Role instance


### Restart Infra Role Instance

 Does restart an Infra Role Instance

```powershell
Restart-AzSInfraRoleInstance -Name "InfraRoleInstanceName"
```

The command does the following:
- Restart an Infra Role instance


### Add IP Pool

 Does add an IP Pool

```powershell
Add-AzSIPPool -Name "PoolName" -StartIPAddress "192.168.55.1" -EndIPAddress "192.168.55.254" -AddressPrefix "192.168.0./24"
```

The command does the following:
- Adds an IP Pool


### Enable Maintenance Mode

 Does put a ScaleUnitNode in Maintenance Mode

```powershell
Disable-AzSScaleUnitNode -Name NodeName
```

The command does the following:
- Enables Maintenance Mode for a specified ScaleUnitNode


### Disable Maintenance Mode

 Does resume a ScaleUnitNode from Maintenance Mode

```powershell
Enable-AzSScaleUnitNode -Name NodeName
```

The command does the following:
- Resume from Maintenance Mode for a specified ScaleUnitNode


### Show Region Capacity

 Does show capacity for specified Region

```powershell
Get-AzSRegionCapacity
```

The command does the following:
- Retrieves Region Capacity information

## Scenario Command Usage
Demonstrates using multiple commands together for an end to end scenario.

### Recover an Infrastructure Role Instance that has an Alert assigned.

```powershell
#Retrieve all Alerts and apply a filter to only show active Alerts
$Active=Get-AzSAlert | Where {$_.State -eq "active"}
$Active

#Stop Infra Role Instance
Stop-AzSInfraRoleInstance -Name $Active.ResourceName

#Start Infra Role Instance
Start-AzSInfraRoleInstance -Name $Active.resourceName

#Validate if error is resolved (Can take up to 3min)
Get-AzSAlert | Where {$_.State -eq "active"}
```


### Increase Public IP Pool Capacity
```powershell
#Retrieve all Alerts and apply a filter to only show active Alerts
$Active=Get-AzSAlert | Where {$_.State -eq "active"}
$Active

#Review IP Pool Allocation
Get-AzSIPPool

#Add New Public IP Pool
Add-AzSIPPool -Name "NewPublicIPPool" -StartIPAddress "192.168.80.0" -EndIPAddress "192.168.80.255" -AddressPrefix "192.168.80.0/24"

#Validate new IP Pool
Get-AzSIPPool
```

### Apply Update to Azure Stack
```powershell
#Review Current Region Update Summary
Get-AzSUpdateSummary

#Check for available and applicable updates
Get-AzSUpdate

#Apply Update
Install-AzSUpdate -Update "2.0.0.0"

#Check Update Run
Get-AzSUpdateRun -Update "2.0.0.0"

#Review Region Update Summary after successful run
Get-AzSUpdateSummary
```


### Perform FRU procedure
```powershell
#Review current ScaleUnitNode State
$node=Get-AzSScaleUnitNode
$node | fl


#Enable Maintenance Mode for that node which drains all active resources
Disable-AzSScaleUnitNode -Name $node.name

#Power Off Server using build in KVN or physical power button
#BMC IP Address is returned by previous command $node.properties | fl
#Apply FRU Procedure
#Power On Server using build in KVN or physical power button

#Resume ScaleUnitNode from Maintenance Mode
Enable-AzSScaleUnitNode -Name $node.name

#Validate ScaleUnitNode Status
$node=Get-AzSScaleUnitNode
$node | fl
```