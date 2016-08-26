# Tools for using Azure and Azure Stack

## Azure Resource Manager policy for Azure Stack

This tool constrains Azure subscription to the capabilities available in the Azure Stack via the [Azure Resource Manager policy](https://azure.microsoft.com/en-us/documentation/articles/resource-manager-policy/).

```powershell
Import-Module .\Policy\AzureStack.Policy.psm1

Login-AzureRmAccount
$s = Select-AzureRmSubscription -SubscriptionName "<your sub>"

$policy = New-AzureRmPolicyDefinition -Name AzureStack -Policy (Get-AzureStackRmPolicy)

New-AzureRmPolicyAssignment -Name AzureStack -PolicyDefinition $policy -Scope /subscriptions/$s.Subscription.SubscriptionId
```