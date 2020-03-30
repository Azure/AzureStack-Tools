# Azure Resource Manager policy for Azure Stack

Instructions below are relative to the .\Policy folder of the [AzureStack-Tools repo](..).

This tool constrains Azure subscription to the capabilities available in the Azure Stack via the [Azure Resource Manager policy](https://azure.microsoft.com/en-us/documentation/articles/resource-manager-policy/).

```powershell
Import-Module .\AzureStack.Policy.psm1

Login-AzureRmAccount
$s = Select-AzSubscription -SubscriptionName "<sub name>"
$subId = $s.Subscription.SubscriptionId

$policy = New-AzPolicyDefinition -Name AzureStack -Policy (Get-AzsPolicy)

New-AzPolicyAssignment -Name AzureStack -PolicyDefinition $policy -Scope /subscriptions/$subId
```

To constrain only a particular resource group in your Azure subscription to match the capabilities of Azure Stack, specify the resource group in the scope as below when assigning the policy.

```powershell
#Specify the resource group where you would like to apply the policy
$rgName = 'AzureStack'
New-AzPolicyAssignment -Name AzureStack -PolicyDefinition $policy -Scope /subscriptions/$subID/resourceGroups/$rgName
```

To remove the Azure Stack policy, run this command with the same scope used when the policy was applied:

```powershell

Remove-AzPolicyAssignment -Name AzureStack -Scope /subscriptions/$subId/resourceGroups/$rgName
Remove-AzPolicyAssignment -Name AzureStack -Scope /subscriptions/$subId
```
