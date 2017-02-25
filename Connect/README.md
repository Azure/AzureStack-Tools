# Connecting to Azure Stack

This tool set allows you to connect to an Azure Stack instance from your personal computer/laptop.

Instructions below are relative to the .\Connect folder of the [AzureStack-Tools repo](..).

```powershell
Import-Module .\AzureStack.Connect.psm1
```

## VPN to Azure Stack One Node

You can establish a split tunnel VPN connection to an Azure Stack One Node. 
This allows your client computer to become part of the Azure Stack One Node network system and therefore resolve [https://portal.azurestack.local](https://portal.azurestack.local), api.azurestack.local, *.blob.azurestack.local and so on. 

The tool will also download root certificate of the targeted Azure Stack One Node instance locally to your client computer. 
This will ensure that SSL sites of the target Azure Stack installation are trusted by your client when accessed from the browser or from the command-line tools.

Use the admin password provided at the time of the Azure Stack deployment.

```powershell
$Password = ConvertTo-SecureString -AsPlainText -Force "<Admin password provided when deploying Azure Stack>" 
```

To connect to Azure Stack One Node via VPN, first locate the NAT address of the target installation. 
If you specified static IP of the NAT when deploying Azure Stack One Node, then use it in the connection example below. 
If you did not specify static IP then NAT was configured with DHCP. In that case, obtain NAT IP as follows using IP address of the Azure Stack One Node host (which should be known to you after deployment).  

```powershell
$hostIp = "<Azure Stack host address>"
```

Since the command below needs to access the Azure Stack One Node host computer and Azure Stack CA, they need to be trusted hosts in PowerShell. Run PowerShell as administrator and modify TrustedHosts as follows.

```powershell
# Add Azure Stack One Node host to the trusted hosts on your client computer
Set-Item wsman:\localhost\Client\TrustedHosts -Value $hostIp -Concatenate
Set-Item wsman:\localhost\Client\TrustedHosts -Value mas-ca01.azurestack.local -Concatenate
```

Then obtain NAT IP.

```powershell
$natIp = Get-AzureStackNatServerAddress -HostComputer $hostIp -Password $Password
```

Then connect your client computer as follows.

```powershell
# Create VPN connection entry for the current user
Add-AzureStackVpnConnection -ServerAddress $natIp -Password $Password

# Connect to the Azure Stack instance. This command can be used multiple times.
Connect-AzureStackVpn -Password $Password
```
## Configure Azure Stack PowerShell Environment

AzureRM cmdlets can be targeted at multiple Azure clouds such as Azure China, Government, and Azure Stack.
To target your Azure Stack instance, an AzureRM environment needs to be registered as follows.

```powershell
Add-AzureStackAzureRmEnvironment -AadTenant "<mydirectory>.onmicrosoft.com"
```

The AadTenant parameter above specifies the directory that was used when deploying Azure Stack. 
If you do not remember the directory, you could retrieve it as follows. 
Note that Azure Stack One Node host needs to be added to TrustedHosts as described in the VPN section above.

```powershell
$AadTenant = "<mydirectory>.onmicrosoft.com"
Add-AzureStackAzureRmEnvironment -AadTenant $AadTenant
``` 

After registering AzureRM environment cmdlets can be easily targeted at your Azure Stack instance. For example:

```powershell
Add-AzureRmAccount -EnvironmentName AzureStack -TenantId $AadTenant
```

You will be prompted for the account login including two factor authentication if it is enabled in your organization. You can also log in with a service principal using appropriate parameters of the Add-AzureRmAccount cmdlet.

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
