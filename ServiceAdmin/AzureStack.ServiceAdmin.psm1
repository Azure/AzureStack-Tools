# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0
#requires -Modules AzureStack.Connect

<#
    .SYNOPSIS
    Creates "default" tenant offer with unlimited quotas across Compute, Network, Storage and KeyVault services.
#>
function New-AzSTenantOfferAndQuotas
{
    param (
        [parameter(HelpMessage="Name of the offer to be made advailable to tenants")]
        [string] $Name ="default",
        [parameter(HelpMessage="Azure Stack region in which to define plans and quotas")]
        [string]$Location = "local",
        [Parameter(HelpMessage="If this parameter is not specified all quotas are assigned. Provide a sub selection of quotas in this parameter if you do not want all quotas assigned.")]
        [ValidateSet('Compute','Network','Storage','KeyVault','Subscriptions',IgnoreCase =$true)]
        [array]$ServiceQuotas,
        [parameter(Mandatory=$true,HelpMessage="The name of the AzureStack environment")]
        [string] $EnvironmentName,
        [parameter(Mandatory=$true,HelpMessage="Azure Stack service administrator credential")]
        [pscredential] $azureStackCredential,
        [parameter(mandatory=$true, HelpMessage="TenantID of Identity Tenant")]
	    [string] $tenantID
    )

    $azureStackEnvironment = Get-AzureRmEnvironment -Name $EnvironmentName -ErrorAction SilentlyContinue
    if($azureStackEnvironment -ne $null) {
        $ARMEndpoint = $azureStackEnvironment.ResourceManagerUrl
    }
    else {
        Write-Error "The Azure Stack Admin environment with the name $EnvironmentName does not exist. Create one with Add-AzureStackAzureRmEnvironment." -ErrorAction Stop
    }

    Write-Verbose "Obtaining token from AAD..." -Verbose
    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredential -EnvironmentName $EnvironmentName)

    Write-Verbose "Creating quotas..." -Verbose
    $Quotas = @()
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Compute')){ $Quotas += New-ComputeQuota -AdminUri $armEndPoint -SubscriptionId $subscription -AzureStackTokenHeader $headers -ArmLocation $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Network')){ $Quotas += New-NetworkQuota -AdminUri $armEndPoint -SubscriptionId $subscription -AzureStackTokenHeader $headers -ArmLocation $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Storage')){ $Quotas += New-StorageQuota -AdminUri $armEndPoint -SubscriptionId $subscription -AzureStackTokenHeader $headers -ArmLocation $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'KeyVault')){ $Quotas += Get-KeyVaultQuota -AdminUri $armEndPoint -SubscriptionId $subscription -AzureStackTokenHeader $headers -ArmLocation $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Subscriptions')){ $Quotas += Get-SubscriptionsQuota -AdminUri $armEndpoint -SubscriptionId $subscription -AzureStackTokenHeader $headers -ArmLocation $Location }

    Write-Verbose "Creating resource group for plans and offers..." -Verbose
    if (Get-AzureRmResourceGroup -Name $Name -ErrorAction SilentlyContinue)
    {        
        Remove-AzureRmResourceGroup -Name $Name -Force -ErrorAction Stop
    }
    New-AzureRmResourceGroup -Name $Name -Location $Location -ErrorAction Stop

    Write-Verbose "Creating plan..." -Verbose
    $plan = New-AzureRMPlan -Name $Name -DisplayName $Name -ArmLocation $Location -ResourceGroup $Name -QuotaIds $Quotas

    Write-Verbose "Creating public offer..." -Verbose
    $offer = New-AzureRMOffer -Name $Name -DisplayName $Name -State Public -BasePlanIds @($plan.Id) -ArmLocation $Location -ResourceGroup $Name

    return $offer
}

Export-ModuleMember New-AzSTenantOfferAndQuotas

function Get-SubscriptionsQuota
{
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $AdminUri,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $SubscriptionId,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [hashtable] $AzureStackTokenHeader,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $ArmLocation  
    )    

    $getSubscriptionsQuota = @{
        Uri = "{0}/subscriptions/{1}/providers/Microsoft.Subscriptions.Admin/locations/{2}/quotas?api-version=2015-11-01" -f $AdminUri, $SubscriptionId, $ArmLocation
        Method = "GET"
        Headers = $AzureStackTokenHeader
        ContentType = "application/json"
    }
    $subscriptionsQuota = Invoke-RestMethod @getSubscriptionsQuota
    $subscriptionsQuota.value.Id
}

function New-StorageQuota
{
    param(
        [string] $Name ="default",
        [int] $CapacityInGb = 1000,
        [int] $NumberOfStorageAccounts = 2000,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $AdminUri,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $SubscriptionId,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [hashtable] $AzureStackTokenHeader,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $ArmLocation  
    )    

    $ApiVersion = "2015-12-01-preview"

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Storage.Admin/locations/{2}/quotas/{3}?api-version={4}" -f $AdminUri, $SubscriptionId, $ArmLocation, $Name, $ApiVersion
    $RequestBody = @"
    {
        "name":"$Name",
        "location":"$ArmLocation",
        "properties": { 
            "capacityInGb": $CapacityInGb, 
            "numberOfStorageAccounts": $NumberOfStorageAccounts
        }
    }
"@
    $storageQuota = Invoke-RestMethod -Method Put -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $AzureStackTokenHeader
    $storageQuota.Id
}

function New-ComputeQuota
{
    param(
        [string] $Name ="default",
        [int] $VmCount = 1000,
        [int] $MemoryLimitMB = 1048576,
        [int] $CoresLimit = 1000,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $AdminUri,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $SubscriptionId,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [hashtable] $AzureStackTokenHeader,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $ArmLocation  
    )  

    $ApiVersion = "2015-12-01-preview"

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Compute.Admin/locations/{2}/quotas/{3}?api-version={4}" -f $AdminUri, $SubscriptionId, $ArmLocation, $Name, $ApiVersion
    $RequestBody = @"
    {
        "name":"$Name",
        "type":"Microsoft.Compute.Admin/quotas",
        "location":"$ArmLocation",
        "properties":{
            "virtualMachineCount":$VmCount,
            "memoryLimitMB":$MemoryLimitMB,
            "coresLimit":$CoresLimit
        }
    }
"@
    $computeQuota = Invoke-RestMethod -Method Put -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $AzureStackTokenHeader
    $computeQuota.Id
}

function New-NetworkQuota
{
    param(
        [string] $Name ="default",
        [int] $PublicIpsPerSubscription       = 500,
        [int] $VNetsPerSubscription           = 500,
        [int] $GatewaysPerSubscription        = 10,
        [int] $ConnectionsPerSubscription     = 20,
        [int] $LoadBalancersPerSubscription   = 500,
        [int] $NicsPerSubscription            = 1000,
        [int] $SecurityGroupsPerSubscription  = 500,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $AdminUri,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $SubscriptionId,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [hashtable] $AzureStackTokenHeader,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $ArmLocation  
    ) 
    
    $ApiVersion = "2015-06-15"

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Network.Admin/locations/{2}/quotas/{3}?api-version={4}" -f $AdminUri, $SubscriptionId, $ArmLocation, $Name, $ApiVersion
    $id = "/subscriptions/{0}/providers/Microsoft.Network.Admin/locations/{1}/quotas/{2}" -f  $SubscriptionId, $ArmLocation, $quotaName
    $RequestBody = @"
    {
        "id":"$id",
        "name":"$Name",
        "type":"Microsoft.Network.Admin/quotas",
        "location":"$ArmLocation",
        "properties":{
            "maxPublicIpsPerSubscription":$PublicIpsPerSubscription,
            "maxVnetsPerSubscription":$VNetsPerSubscription,
            "maxVirtualNetworkGatewaysPerSubscription":$GatewaysPerSubscription,
            "maxVirtualNetworkGatewayConnectionsPerSubscription":$ConnectionsPerSubscription,
            "maxLoadBalancersPerSubscription":$LoadBalancersPerSubscription,
            "maxNicsPerSubscription":$NicsPerSubscription,
            "maxSecurityGroupsPerSubscription":$SecurityGroupsPerSubscription,
        }
    }
"@
    $networkQuota = Invoke-RestMethod -Method Put -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $AzureStackTokenHeader
    $networkQuota.Id
}

function Get-KeyVaultQuota
{
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $AdminUri,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $SubscriptionId,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [hashtable] $AzureStackTokenHeader,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $ArmLocation  
    ) 

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Keyvault.Admin/locations/{2}/quotas?api-version=2014-04-01-preview" -f $AdminUri, $SubscriptionId, $ArmLocation
    $kvQuota = Invoke-RestMethod -Method Get -Uri $uri -Headers $AzureStackTokenHeader -ContentType 'application/json'
    $kvQuota.Value.Id
}
