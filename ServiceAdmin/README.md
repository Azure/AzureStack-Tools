# Azure Stack Service Administration

Instructions below are relative to the .\ServiceAdmin folder of the [AzureStack-Tools repo](..\).

Make sure you have the following module prerequisites installed:

```powershell
Install-Module -Name 'AzureRm.Bootstrapper'
Install-AzureRmProfile -profile '2017-03-09-profile' -Force
Install-Module -Name AzureStack -RequiredVersion 1.2.11
```

Then make sure the following modules are imported:

```powershell
Import-Module ..\Connect\AzureStack.Connect.psm1
Import-Module .\AzureStack.ServiceAdmin.psm1
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


## Create default plan and quota for tenants

```powershell
# Default quotas, plan, and offer
$PlanName = "SimplePlan"
$OfferName = "SimpleOffer"
$RGName = "PlansandoffersRG"
$Location = (Get-AzsLocation).Name

$computeParams = @{
Name = "computedefault"
CoresLimit = 200
AvailabilitySetCount = 10
VirtualMachineCount = 50
VmScaleSetCount = 10
Location = $Location
}

$netParams = @{
Name = "netdefault"
PublicIpsPerSubscription = 500
VNetsPerSubscription = 500
GatewaysPerSubscription = 10
ConnectionsPerSubscription = 20
LoadBalancersPerSubscription = 500
NicsPerSubscription = 1000
SecurityGroupsPerSubscription = 500
Location = $Location
}

$storageParams = @{
Name = "storagedefault"
NumberOfStorageAccounts = 20
CapacityInGB = 2048
Location = $Location
}

$kvParams = @{
Location = $Location
}

$quotaIDs = @()
$quotaIDs += (New-AzsNetworkQuota @netParams).ID
$quotaIDs += (New-AzsComputeQuota @computeParams).ID
$quotaIDs += (New-AzsStorageQuota @storageParams).ID
$quotaIDs += (Get-AzsKeyVaultQuota @kvParams)

New-AzureRmResourceGroup -Name $RGName -Location $Location
$plan = New-AzsPlan -Name $PlanName -DisplayName $PlanName -ArmLocation $Location -ResourceGroupName $RGName -QuotaIds $QuotaIDs
New-AzsOffer -Name $OfferName -DisplayName $OfferName -State Public -BasePlanIds $plan.Id -ResourceGroupName $RGName -ArmLocation $Location 
```

Tenants can now see the "SimpleOffer" offer available to them and can subscribe to it. The offer includes unlimited compute, network, storage and key vault usage.
