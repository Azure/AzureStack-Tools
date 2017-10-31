# Azure Stack Infrastructure Administration

Instructions below are relative to the .\Infrastructure folder of the [AzureStack-Tools repo](..).
This also requires the Azure Stack Connect Module to be imported before running any of the commands. The Module can also be found in the [AzureStack-Tools repo](..).

![Using infrastructure cmdlets against Azure Stack](/Infrastructure/InfraAlertsVideo.gif)

## Import the Module

```powershell
Import-Module .\AzureStack.Infra.psm1
```

## Add PowerShell environment

You will need to login to your Azure Stack Administrator environment. To create an administrator environment use the below. The ARM endpoint below is the administrator default for a one-node environment.

```powershell
Add-AzureRMEnvironment -Name "AzureStackAdmin" -ArmEndpoint "https://adminmanagement.local.azurestack.external"
```

Then login:

```powershell
Login-AzureRmAccount -EnvironmentName "AzureStackAdmin"
```
----
If you are **not** using your home directory tenant, you will need to supply the tenant ID to your login command. You may find it easiest to obtain using the Connect tool. For **Azure Active Directory** environments provide your directory tenant name:

```powershell
$TenantID = Get-AzsDirectoryTenantId -AADTenantName "<mydirectorytenant>.onmicrosoft.com" -EnvironmentName AzureStackAdmin
```

For **ADFS** environments use the following:

```powershell
$TenantID = Get-AzsDirectoryTenantId -ADFS -EnvironmentName AzureStackAdmin
```

## Individual Command Usage

Explains each individual command and shows how to use it

### Retrieve Infrastructure Alerts

List active and closed Infrastructure Alerts

```powershell
Get-AzsAlert
```

The command does the following:
- Retrieves Active & Closed Alerts

### Close Infrastructure Alerts

 Close any active Infrastructure Alert. Run Get-AzsAlert to get the AlertID, required to close a specific Alert.

```powershell
Close-AzsAlert -AlertID "ID"
```

The command does the following:
- Close active Alert

### Get Region Update Summary

 Review the Update Summary for a specified region.

```powershell
Get-AzsUpdateLocation
```

The command does the following:
- Retrieves Region Update Summary

### Get Azure Stack Update

 Retrieves list of Azure Stack Updates

```powershell
Get-AzsUpdate
```

The command does the following:
- List Azure Stack Updates

### Apply Azure Stack Update

 Applies a specific Azure Stack Update that is downloaded and applicable. Run Get-AzureStackUpdate to retrieve Update Version first

```powershell
Install-AzsUpdate -Update "Update Version"
```

The command does the following:
- Applies specified Update

### Get Azure Stack Update Run

 Should be used to validate a specific Update Run or look at previous update runs

```powershell
Get-AzsUpdateRun -Update "Update Version"
```

The command does the following:
- Lists Update Run information for a specific Azure Stack update

### List Infrastructure Roles

 Does list all Infrastructure Roles

```powershell
Get-AzsInfrastructureRole
```

The command does the following:
- Lists Infrastructure Roles

### List Infrastructure Role Instance

 Does list all Infrastructure Role Instances (Note: Does not return Directory Management VM in One Node deployment)

```powershell
Get-AzsInfrastructureRoleInstance
```

The command does the following:
- Lists Infrastructure Role Instances

### List Scale Unit

 Does list all Scale Units in a specified Region

```powershell
Get-AzsScaleUnit
```

The command does the following:
- Lists Scale Units

### List Scale Unit Nodes

 Does list all Scale Units Nodes

```powershell
Get-AzsScaleUnitNode
```

The command does the following:
- Lists Scale Unit Nodes

### List Logical Networks

 Does list all logical Networks by ID

```powershell
Get-AzsLogicalNetwork
```

The command does the following:
- Lists logical Networks

### List Storage Capacity

 Does return the total capacity of the storage subsystem

```powershell
Get-AzSStorageSubsystem
```

The command does the following:
- Lists total storage capacity for the storage subsystem

### List Storage Shares

 Does list all file shares in the storage subsystem

```powershell

Get-AzsInfrastructureShare
```

The command does the following:
- Retrieves all file shares

### List IP Pools

 Does list all IP Pools

```powershell
Get-AzsIpPool
```

The command does the following:
- Retrieves all IP Pools

### List MAC Address Pools

 Does list all MAC Address Pool

```powershell
Get-AzsMacPool
```

The command does the following:
- Retrieves all MAC Address Pools

### List Gateway Pools

 Does list all Gateway Pools

```powershell
Get-AzsGatewayPool
```

The command does the following:
- Retrieves all Gateway Pools

### List SLB MUX

 Does list all SLB MUX Instances

```powershell
Get-AzsSLBMux
```

The command does the following:
- Retrieves all SLB MUX instances

### List Gateway Instances

 Does list all Gateway Instances

```powershell
Get-AzsGateway
```

The command does the following:
- Retrieves all Gateway instances

### Start Infra Role Instance

 Does start an Infra Role Instance

```powershell
Start-AzsInfrastructureRoleInstance -Name "InfraRoleInstanceName"
```

The command does the following:
- Starts an Infra Role instance

### Stop Infra Role Instance

 Does stop an Infra Role Instance

```powershell
Stop-AzsInfrastructureRoleInstance -Name "InfraRoleInstanceName"
```

The command does the following:
- Stops an Infra Role instance

### Restart Infra Role Instance

 Does Restart an Infra Role Instance

```powershell
Restart-AzsInfrastructureRoleInstance -Name "InfraRoleInstanceName"
```

The command does the following:
- Restart an Infra Role instance

### Add IP Pool

 Does add an IP Pool

```powershell
Add-AzsIpPool -Name "PoolName" -StartIPAddress "192.168.55.1" -EndIPAddress "192.168.55.254" -AddressPrefix "192.168.55.0/24"
```

The command does the following:
- Adds an IP Pool

### Enable Maintenance Mode

 Does put a ScaleUnitNode in Maintenance Mode

```powershell
Disable-AzsScaleUnitNode -Name NodeName
```

The command does the following:
- Enables Maintenance Mode for a specified ScaleUnitNode

### Disable Maintenance Mode

 Does resume a ScaleUnitNode from Maintenance Mode

```powershell
Enable-AzsScaleUnitNode -Name NodeName
```

The command does the following:
- Resume from Maintenance Mode for a specified ScaleUnitNode

### Show Region Capacity

 Does show capacity for specified Region

```powershell
Get-AzsLocationCapacity
```

The command does the following:
- Retrieves Region Capacity information

### Show Resource Provider Healths

 Does show resource provider healths

```powershell
Get-AzsResourceProviderHealths
```

The command does the following:
- List Resource Provider and their Healths status

### Show Infrastrcuture Role Healths

 Does show infrastructure role healths

```powershell
Get-AzsInfrastructureRoleHealths
```

The command does the following:
- List Infrastructure Roles and their Healths status

### Show Backup Location

 Does show Backup location

```powershell
Get-AzsBackupLocation
```

The command does the following:
- List information about the backup location like share path

### Show Backup

 Does show backups

```powershell
Get-AzsBackup
```

The command does the following:
- List backups

### Start Backup

 Does start a backup job

```powershell
Start-AzsBackup
```

The command does the following:
- starts a backup job and does store it at configured share path

### Restore Backup

 Does restore a backup job

```powershell
Restore-AzsBackup -name ID
```

The command does the following:
- Restore a specified Backup job

## Scenario Command Usage

Demonstrates using multiple commands together for an end to end scenario.

### Recover an Infrastructure Role Instance that has an Alert assigned

```powershell
#Retrieve all Alerts and apply a filter to only show active Alerts
$Active=Get-AzsAlert | Where {$_.State -eq "active"}
$Active

#Stop Infra Role Instance
Stop-AzsInfrastructureRoleInstance -Name $Active.ResourceName

#Start Infra Role Instance
Start-AzsInfrastructureRoleInstance -Name $Active.resourceName

#Validate if error is resolved (Can take up to 3min)
Get-AzsAlert | Where {$_.State -eq "active"}
```

### Increase Public IP Pool Capacity

```powershell
#Retrieve all Alerts and apply a filter to only show active Alerts
$Active=Get-AzsAlert | Where {$_.State -eq "active"}
$Active

#Review IP Pool Allocation
Get-AzsIpPool

#Add New Public IP Pool
Add-AzsIpPool -Name "NewPublicIPPool" -StartIPAddress "192.168.80.0" -EndIPAddress "192.168.80.255" -AddressPrefix "192.168.80.0/24"

#Validate new IP Pool
Get-AzsIpPool
```

### Apply Update to Azure Stack

```powershell
#Review Current Region Update Summary
Get-AzsUpdateLocation

#Check for available and applicable updates
Get-AzsUpdate

#Apply Update
Install-AzsUpdate -Update "2.0.0.0"

#Check Update Run
Get-AzsUpdateRun -Update "2.0.0.0"

#Review Region Update Summary after successful run
Get-AzsUpdateLocation
```

### Perform FRU procedure

```powershell
#Review current ScaleUnitNode State
$node=Get-AzsScaleUnitNode
$node | fl


#Enable Maintenance Mode for that node which drains all active resources
Disable-AzsScaleUnitNode -Name $node.name

#Power Off Server using build in KVM or physical power button
#BMC IP Address is returned by previous command $node.properties | fl
#Apply FRU Procedure
#Power On Server using build in KVM or physical power button

#Resume ScaleUnitNode from Maintenance Mode
Enable-AzsScaleUnitNode -Name $node.name

#Validate ScaleUnitNode Status
$node=Get-AzsScaleUnitNode
$node | fl
```

### Set Azure Stack's Latitude and Longitude

This command modifies an Azure Stack instance's latitude and longitude location

```powershell
$EnvironmentName = "AzureStackAdmin"
$directoryName = "<<yourDirectoryName>>.onmicrosoft.com"
$credential = Get-Credential
$latitude = '12.972442'
$longitude = '77.580643'
$regionName = 'local'

Set-AzsLocationInformation -Location $regionName -Latitude $latitude -Longitude $longitude

```
