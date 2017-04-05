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
$Password = ConvertTo-SecureString "<Admin password provided when deploying Azure Stack>" -AsPlainText -Force
$AadTenant = Get-AzureStackAadTenant  -HostComputer <Host IP Address> -Password $Password
Add-AzureStackAzureRmEnvironment -Name "AzureStackAdmin" -ArmEndpoint "https://adminmanagement.local.azurestack.external"
Login-AzureRmAccount -EnvironmentName "AzureStackAdmin" -TenantId $AadTenant
```

## Individual Command Usage

Explains each individual command and shows how to use it

### Retrieve Infrastructure Alerts

List active and closed Infrastructure Alerts

```powershell
$credential = Get-Credential
Get-AzSAlert -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve Alerts. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves Active & Closed Alerts


### Close Infrastructure Alerts

 Close any active Infrastructure Alert. Run Get-AzureStackAlert to get the AlertID, required to close a specific Alert.

```powershell
$credential = Get-Credential
Close-AzSAlert -AzureStackCredential $credential -TenantID $AadTenant -AlertID "ID" -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to close active Alert. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Close active Alert


### Get Region Update Summary

 Review the Update Summary for a specified region.

```powershell
$credential = Get-Credential
Get-AzSUpdateSummary -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve Region Update Summary. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves Region Update Summary


### Get Azure Stack Update

 Retrieves list of Azure Stack Updates

```powershell
$credential = Get-Credential
Get-AzSUpdate -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve Azure Stack Updates. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- List Azure Stack Updates


### Apply Azure Stack Update

 Applies a specific Azure Stack Update that is downloaded and applicable. Run Get-AzureStackUpdate to retrieve Update Version first

```powershell
$credential = Get-Credential
Apply-AzSUpdate -AzureStackCredential $credential -TenantID $AadTenant -vupdate "Update Version" -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to apply a specific Update. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Applies specified Update


### Get Azure Stack Update Run

 Should be used to validate a specific Update Run or look at previous update runs

```powershell
$credential = Get-Credential
Get-AzSUpdateRun -AzureStackCredential $credential -TenantID $AadTenant -vupdate "Update Version" -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve Update Run information. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Update Run information for a specific Azure Stack update


### List Infrastructure Roles

 Does list all Infrastructure Roles

```powershell
$credential = Get-Credential
Get-AzSInfraRole -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve Infrastructure Roles. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Infrastructure Roles


### List Infrastructure Role Instance

 Does list all Infrastructure Role Instances (Note: Does not return Directory Management VM in One Node deployment)

```powershell
$credential = Get-Credential
Get-AzSInfraRoleInstance -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve Infrastructure Role Instances. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Infrastructure Role Instances


### List Scale Unit

 Does list all Scale Units in a specified Region

```powershell
$credential = Get-Credential
Get-AzSScaleUnit -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve Scale Units. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Scale Units


### List Scale Unit Nodes

 Does list all Scale Units Nodes

```powershell
$credential = Get-Credential
Get-AzSScaleUnitNode -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve all Scale Unit Nodes. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Scale Unit Nodes


### List Logical Networks

 Does list all logical Networks by ID

```powershell
$credential = Get-Credential
Get-AzSLogicalNetwork -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve logical Networks. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists logical Networks


### List Storage Capacity

 Does return the total capacity of the storage subsystem

```powershell
$credential = Get-Credential
Get-AzSStorageCapacity -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve total storage capacity. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists total storage capacity for the storage subsystem


### List Storage Shares

 Does list all file shares in the storage subsystem

```powershell
$credential = Get-Credential
Get-AzSStorageShare -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve file shares. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves all file shares


### List IP Pools

 Does list all IP Pools

```powershell
$credential = Get-Credential
Get-AzSIPPool -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve IP Pools. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves all IP Pools


### List MAC Address Pools

 Does list all MAC Address Pool

```powershell
$credential = Get-Credential
Get-AzSMacPool -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve all MAC Address Pools. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves all MAC Address Pools


### List Gateway Pools

 Does list all Gateway Pools

```powershell
$credential = Get-Credential
Get-AzSGatewayPool -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve the Gateway Pools. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves all Gateway Pools


### List SLB MUX

 Does list all SLB MUX Instances

```powershell
$credential = Get-Credential
Get-AzSSLBMUX -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve all SLB MUX instances. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves all SLB MUX instances


### List Gateway Instances

 Does list all Gateway Instances

```powershell
$credential = Get-Credential
Get-AzSGateway -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to retrieve all Gateway instances. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves all Gateway instances


### Start Infra Role Instance

 Does start an Infra Role Instance

```powershell
$credential = Get-Credential
Start-AzSInfraRoleInstance -AzureStackCredential $credential -TenantID $AadTenant -Name "InfraRoleInstanceName" -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to start an infra role instance. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Starts an Infra Role instance


### Stop Infra Role Instance

 Does stop an Infra Role Instance

```powershell
$credential = Get-Credential
Stop-AzSInfraRoleInstance -AzureStackCredential $credential -TenantID $AadTenant -Name "InfraRoleInstanceName" -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to stop an infra role instance. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Stops an Infra Role instance


### Restart Infra Role Instance

 Does restart an Infra Role Instance

```powershell
$credential = Get-Credential
Restart-AzSInfraRoleInstance -AzureStackCredential $credential -TenantID $AadTenant -Name "InfraRoleInstanceName" -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to restart an infra role instance. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Restart an Infra Role instance


### Add IP Pool

 Does add an IP Pool

```powershell
$credential = Get-Credential
Add-AzSIPPool -AzureStackCredential $credential -TenantID $AadTenant -Name "PoolName" -StartIPAddress "192.168.55.1" -EndIPAddress "192.168.55.254" -AddressPrefix "192.168.0./24" -EnvironmentName "AzureStackAdmin"
```

Note: The cmdlet requires credentials to add an IP Pool. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com or the ADFS credentials, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Adds an IP Pool


## Scenario Command Usage
Demonstrates using multiple commands together for an end to end scenario.

### Recover an Infrastructure Role Instance that has an Alert assigned.

```powershell
#Declare Credentials
$credential = Get-Credential

#Retrieve all Alerts and apply a filter to only show active Alerts
$Active=Get-AzSAlert -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"|where {$_.state -eq "active"}

#Stop Infra Role Instance
Stop-AzSInfraRoleInstance -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin" -Name $Active.resourceName

#Start Infra Role Instance
Start-AzSInfraRoleInstance -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin" -Name $Active.resourceName

#Validate if error is resolved (Can take up to 3min)
Get-AzSAlert -AzureStackCredential $credential -TenantID $AadTenant -EnvironmentName "AzureStackAdmin"|where {$_.state -eq "active"}
```
