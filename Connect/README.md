As a prerequisite, make sure that you installed the correct PowerShell modules and versions:

```powershell
Install-Module -Name AzureRM -RequiredVersion 1.2.8 -Scope CurrentUser
Install-Module -Name AzureStack
```

This tool set allows you to connect to an Azure Stack PoC (Proof of Concept) instance from an external personal laptop. You can then access the portal or log into that environment via PowerShell. 

Instructions below are relative to the .\Connect folder of the [AzureStack-Tools repo](..).

```powershell
Import-Module .\AzureStack.Connect.psm1
```

# VPN to Azure Stack Proof of Concept

The [Connect to Azure Stack](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-connect-azure-stack) document describes ways to connect to your Azure Stack Proof of Concept environment.

One method is to establish a split tunnel VPN connection to an Azure Stack PoC. 
This allows your client computer to become part of the Azure Stack PoC network system and therefore resolve [https://portal.azurestack.local](https://portal.azurestack.local), api.azurestack.local, *.blob.azurestack.local and so on. 

The tool will also download root certificate of the targeted Azure Stack PoC instance locally to your client computer. 
This will ensure that SSL sites of the target Azure Stack installation are trusted by your client when accessed from the browser or from the command-line tools.

To connect to Azure Stack PoC via VPN, first locate the external BGP-NAT01 address of the target installation. 
If you specified a static IP for the BGP-NAT during deployment of the Azure Stack PoC, then use it in the connection example below. 

If you did not specify a static IP then the BGP-NAT was configured with DHCP. In that case, **read the below section** to obtain your BGP-NAT VM IP by using the IP address of the Azure Stack PoC host (which should be known to you after deployment). 

The commands below need to access the Azure Stack PoC host computer and Azure Stack CA, so they need to be trusted hosts in PowerShell. Run PowerShell as administrator and modify TrustedHosts as follows.

```powershell
# Add Azure Stack PoC host to the trusted hosts on your client computer
Set-Item wsman:\localhost\Client\TrustedHosts -Value "<Azure Stack host address>" -Concatenate
Set-Item wsman:\localhost\Client\TrustedHosts -Value mas-ca01.azurestack.local -Concatenate
```  

For the VPN connection, use the admin password provided at the time of the Azure Stack deployment.

```powershell
$Password = ConvertTo-SecureString "<Admin password provided when deploying Azure Stack>" -AsPlainText -Force
```

Then connect your client computer to the environment as follows.

```powershell
# Create VPN connection entry for the current user
Add-AzureStackVpnConnection -ServerAddress <NAT IP> -Password $Password

# Connect to the Azure Stack instance. This command can be used multiple times.
Connect-AzureStackVpn -Password $Password
```

## Obtain the NAT IP address with the Azure Stack PoC host address

This command is helpful if you do not immediately know the NAT IP of the Azure Stack PoC you are trying to connect to. You must know the host address of your Azure Stack PoC.

```powershell
$natIp = Get-AzureStackNatServerAddress -HostComputer "<Azure Stack host address>" -Password $Password
```


# Configure Azure Stack PowerShell Environment

One method of deploying templates and interacting with your Azure Stack PoC is to access it via PowerShell. 

See the [Azure Stack Install PowerShell](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-connect-powershell) article to download and install the correct PowerShell modules for Azure Stack.

AzureRM cmdlets can be targeted at multiple Azure clouds such as Azure China, Government, and Azure Stack.

To retrieve your Azure Active Directory Tenant ID (this will be a GUID value), do the following:

First, make sure that your host is added to the list of trusted hosts:
```powershell
Set-Item wsman:\localhost\Client\TrustedHosts -Value "<Azure Stack host address>" -Concatenate
```

Then execute the following:
```powershell
$Password = ConvertTo-SecureString "<Admin password provided when deploying Azure Stack>" -AsPlainText -Force
$AadTenant = Get-AzureStackAadTenant  -HostComputer <Host IP Address> -Password $Password
```

To target your Azure Stack instance, an AzureRM environment needs to be registered as follows.

```powershell
Add-AzureStackAzureRmEnvironment -AadTenant $AadTenant
```

The AadTenant parameter above specifies the directory that was used when deploying Azure Stack. 

After registering the AzureRM environment, cmdlets can be easily targeted at your Azure Stack instance. For example:

```powershell
Login-AzureRmAccount -EnvironmentName "AzureStack" -TenantId $AadTenant
```

You will be prompted for the account login including two factor authentication if it is enabled in your organization. You can also log in with a service principal using appropriate parameters of the Login-AzureRmAccount cmdlet.

If the account you are logging in with comes from the same Azure Active Directory tenant as the one used when deploying Azure Stack, then you can omit the TenantId parameter above.

## Register Azure RM Providers on new subscriptions

If you are intending to use newly created subscriptions via PowerShell, CLI or direct API calls before deploying any templates or using the Portal, you need to ensure that resource providers are registered on the subscription.
To register providers on the current subscription, do the following.

```powershell
Register-AllAzureRmProviders
```

To register all resource providers on all your subscriptions after logging in using Add-AzureRmAccount do the following. Note that this can take a while.

```powershell
Register-AllAzureRmProvidersOnAllSubscriptions
```

These registrations are idempotent and can be run multiple times. If provider has already been registered, it will simply be reported in the output.





