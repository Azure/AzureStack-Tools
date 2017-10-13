# Connection Scripts

As a prerequisite, make sure that you installed the correct PowerShell modules and versions:

```powershell
Install-Module -Name 'AzureRm.Bootstrapper'
Install-AzureRmProfile -profile '2017-03-09-profile' -Force
Install-Module -Name AzureStack -RequiredVersion 1.2.11
```

This tool set allows you to connect to an Azure Stack Development Kit (ASDK) instance from an external personal laptop. You can then access the portal or log into that environment via PowerShell.

Instructions below are relative to the .\Connect folder of the [AzureStack-Tools repo](..).

```powershell
Import-Module .\AzureStack.Connect.psm1
```

## VPN to Azure Stack Development Kit

![VPN to Azure Stack Development Kit](/Connect/VPNConnection.gif)

The [Connect to Azure Stack](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-connect-azure-stack) document describes ways to connect to your Azure Stack Development Kit environment.

One method is to establish a split tunnel VPN connection to an Azure Stack Development Kit.
This allows your client computer to become part of the Azure Stack Development Kit network system and therefore resolve Azure Stack endpoints.

The tool will also download the root certificate of the targeted Azure Stack Development Kit instance locally to your client computer.
This will ensure that SSL sites of the target Azure Stack installation are trusted by your client when accessed from the browser or from the command-line tools.

To connect to an Azure Stack Development Kit via VPN, you will need to know the host IP address of the target installation. 

The commands below need to access the Azure Stack Development Kit host computer, so it needs to be a trusted host in PowerShell. Run PowerShell as administrator and modify TrustedHosts as follows.

```powershell
# Add Azure Stack Development Kit host to the trusted hosts on your client computer
Set-Item wsman:\localhost\Client\TrustedHosts -Value "<Azure Stack host IP address>" -Concatenate
```  

For the VPN connection, use the admin password provided at the time of the Azure Stack deployment.

```powershell
$Password = ConvertTo-SecureString "<Admin password provided when deploying Azure Stack>" -AsPlainText -Force
```

Then connect your client computer to the environment as follows.

```powershell
# Create VPN connection entry for the current user
Add-AzsVpnConnection -ServerAddress <Host IP Address> -Password $Password

# Connect to the Azure Stack instance. This command can be used multiple times.
Connect-AzsVpn -Password $Password
```

## Configure Azure Stack PowerShell Environment
![Adding Azure Stack Environment](/Connect/EnvironmentAdd.gif)


One method of deploying templates and interacting with your Azure Stack Development Kit is to access it via PowerShell.

See the [Azure Stack Install PowerShell](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-connect-powershell) article to download and install the correct PowerShell modules for Azure Stack.

To target your Azure Stack instance as a tenant, an AzureRM environment needs to be registered as follows. The ARM endpoint below is the tenant default for a one-node environment. AzureRM cmdlets can be targeted at multiple Azure clouds such as Azure China, Government, and Azure Stack.


```powershell
Add-AzureRMEnvironment -Name AzureStack -ArmEndpoint "https://management.local.azurestack.external"
```

To create an administrator environment use the below. The ARM endpoint below is the administrator default for a one-node environment.

```powershell
Add-AzureRMEnvironment -Name AzureStackAdmin -ArmEndpoint "https://adminmanagement.local.azurestack.external"
```

Connecting to your environment requires that you obtain the value of your Directory Tenant ID. For **Azure Active Directory** environments provide your directory tenant name:

```powershell
$TenantID = Get-AzsDirectoryTenantId -AADTenantName "<mydirectorytenant>.onmicrosoft.com" -EnvironmentName AzureStackAdmin
```

For **ADFS** environments use the following:

```powershell
$TenantID = Get-AzsDirectoryTenantId -ADFS -EnvironmentName AzureStackAdmin
```

After registering the AzureRM environment, cmdlets can be easily targeted at your Azure Stack instance. For example:

```powershell
Login-AzureRmAccount -EnvironmentName "AzureStack" -TenantId $TenantID
```

Similarly, for targeting the administrator endpoints:

```powershell
Login-AzureRmAccount -EnvironmentName "AzureStackAdmin" -TenantId $TenantID
```
