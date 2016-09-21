# Tools for using Azure and Azure Stack

## Azure Resource Manager policy for Azure Stack

This tool constrains Azure subscription to the capabilities available in the Azure Stack via the [Azure Resource Manager policy](https://azure.microsoft.com/en-us/documentation/articles/resource-manager-policy/).

```powershell
Import-Module .\Policy\AzureStack.Policy.psm1

Login-AzureRmAccount
$s = Select-AzureRmSubscription -SubscriptionName "<sub name>"
$subID = $s.Subscription.SubscriptionId

$policy = New-AzureRmPolicyDefinition -Name AzureStack -Policy (Get-AzureStackRmPolicy)

New-AzureRmPolicyAssignment -Name AzureStack -PolicyDefinition $policy -Scope /subscriptions/$subID
```

To constrain only a particular resource group in your Azure subscription to match the capabilities of Azure Stack, specify the resource group in the scope as below.

```powershell
Import-Module .\Policy\AzureStack.Policy.psm1

Login-AzureRmAccount
$s = Select-AzureRmSubscription -SubscriptionName "<sub name>"
$subID = $s.Subscription.SubscriptionId

$policy = New-AzureRmPolicyDefinition -Name AzureStack -Policy (Get-AzureStackRmPolicy)

#Specify the resource group where you would like to apply the policy
$rgName = 'AzureStack'
New-AzureRmPolicyAssignment -Name AzureStack -PolicyDefinition $policy -Scope /subscriptions/$subID/resourceGroups/$rgName
```

To remove the Azure Stack policy, run this command with the same scope used when the policy was applied:
```powershell
Remove-AzureRmPolicyAssignment -Name AzureStack -Scope /subscriptions/$subID/resourceGroups/$rgName
```


## Connecting to Azure Stack One Node

This tool allows you to connect to an Azure Stack One Node instance from your personal computer/laptop.

### VPN to Azure Stack One Node

You can establish a split tunnel VPN connection to an Azure Stack One Node. This allows your client computer to become part of the Azure Stack One Node network system and therefore resolve [`https:\\portal.azurestak.local'](https://portal.azurestack.local) and 'api.azurestack.local' and '*.blob.azurestack.local' and so on. 

The tool will wlso download root certificate of the targeted Azure Stack One Node instance locally to your client computer. This will esnure that SSL sites of the target Azure Stack installation are trusted by your client when accessed from the browser or from the command-line tools.

To connect to Azure Stack One Node via VPN, first locate the NAT address of the target installation. Then connect your client computer as follows.

```powershell
Import-Module .\Connect\AzureStack.Connect.psm1

$Password = (ConvertTo-SecureString <Admin password provided at the time of the Azure Stack deployment> -AsPlainText -Force)

# Create VPN connection entry for the current user
Add-AzureStackVpnConnection -ServerAddress <Azure Stack NAT address> -Password $Password

# Connect to the Azure Stack instance. This command can be used multiple times.
Connect-AzureStackVpn -Password $Password
```
