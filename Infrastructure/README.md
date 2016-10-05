# Azure Stack Infrastructure Administration

Instructions below are relative to the .\Infrastructure folder of the [AzureStack-Tools repo](..).

```powershell
Import-Module .\AzureStack.Infra.psm1
```

##Retrieve Infrastructure Alerts

List active and closed Infrastructure Alerts

```powershell
$credential = Get-Credential
Get-AzureStackAlert -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve Alerts. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves Active & Closed Alerts


##Close Infrastructure Alerts

 Close any active Infrastructure Alert. Run Get-AzureStackAlert to get the AlertID, required to close a specific Alert.

```powershell
$credential = Get-Credential
Close-AzureStackAlert -AzureStackCredential $credential -TenantID "ID" -AlertID "ID"
```

Note: The cmdlet requires credentials to close active Alert. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Close active Alert


##Get Region Update Summary

 Review the Update Summary for a specified region.

```powershell
$credential = Get-Credential
Get-AzureStackUpdateSummary -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve Region Update Summary. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves Region Update Summary


##Get Azure Stack Update

 Retrieves list of Azure Stack Updates

```powershell
$credential = Get-Credential
Get-AzureStackUpdate -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve Azure Stack Updates. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- List Azure Stack Updates


##Apply Azure Stack Update

 Applies a specific Azure Stack Update that is downloaded and applicable. Run Get-AzureStackUpdate to retrieve Update Version first

```powershell
$credential = Get-Credential
Apply-AzureStackUpdate -AzureStackCredential $credential -TenantID "ID" -vupdate "Update Version"
```

Note: The cmdlet requires credentials to apply a specific Update. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Applies specified Update


##Get Azure Stack Update Run

 Should be used to validate a specific Update Run or look at previous update runs

```powershell
$credential = Get-Credential
Get-AzureStackUpdateRun -AzureStackCredential $credential -TenantID "ID" -vupdate "Update Version"
```

Note: The cmdlet requires credentials to retrieve Update Run information. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Update Run information for a specific Azure Stack update


##List Infrastructure Roles

 Does list all Infrastructure Roles

```powershell
$credential = Get-Credential
Get-AzureStackInfraRole -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve Infrastructure Roles. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Infrastructure Roles


##List Infrastructure Virtual Machines

 Does list all Infrastructure Role Instances (Note: Does not return Directory Management VM in One Node deployment)

```powershell
$credential = Get-Credential
Get-AzureStackInfraVM -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve Infrastructure Role Instances. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Infrastructure Role Instances


##List Scale Unit

 Does list all Scale Units in a specified Region

```powershell
$credential = Get-Credential
Get-AzureStackScaleUnit -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve Scale Units. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Scale Units


##List Nodes

 Does list Nodes in a Scale Unit

```powershell
$credential = Get-Credential
Get-AzureStackNode -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve Nodes. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists Nodes


##List Logical Networks

 Does list all logical Networks by ID

```powershell
$credential = Get-Credential
Get-AzureStackLogialNetwork -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve logical Networks. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists logical Networks


##List Storage Capacity

 Does return the total capacity of the storage subsystem

```powershell
$credential = Get-Credential
Get-AzureStackStorageCapacity -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve total storage capacity. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Lists total storage capacity for the storage subsystem


##List Storage Shares

 Does list all file shares in the storage subsystem

```powershell
$credential = Get-Credential
Get-AzureStackStorageShare -AzureStackCredential $credential -TenantID "ID"
```

Note: The cmdlet requires credentials to retrieve file shares. Provide the administrator Azure Active Directory credentials, such as *&lt;Admin Account&gt;*@*&lt;mydirectory&gt;*.onmicrosoft.com, to the prompt.  

The command does the following:
- Authenticates to the Azure Stack environment
- Retrieves all file shares
