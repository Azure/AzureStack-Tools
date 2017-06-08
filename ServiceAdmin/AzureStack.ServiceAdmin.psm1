# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0
#requires -Modules AzureStack.Connect

<#
    .SYNOPSIS
    Creates "default" tenant offer with unlimited quotas across Compute, Network, Storage and KeyVault services.
#>

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'New-AzSTenantOfferAndQuotas' -Value 'Add-AzSTenantOfferAndQuotas' -ErrorAction SilentlyContinue

function Add-AzSTenantOfferAndQuotas
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
        [pscredential] $azureStackCredentials,
        [parameter(mandatory=$true, HelpMessage="TenantID of Identity Tenant")]
	    [string] $tenantID
    )

    Write-Warning "The function '$($MyInvocation.MyCommand)' is marked for deprecation. Please remove any references in code."

    $azureStackEnvironment = Get-AzureRmEnvironment -Name $EnvironmentName -ErrorAction SilentlyContinue
    if($azureStackEnvironment -ne $null) {
        $ARMEndpoint = $azureStackEnvironment.ResourceManagerUrl
    }
    else {
        Write-Error "The Azure Stack Admin environment with the name $EnvironmentName does not exist. Create one with Add-AzSEnvironment." -ErrorAction Stop
    }

    Write-Verbose "Obtaining token from AAD..." -Verbose
    $subscription, $headers =  (Get-AzSAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -EnvironmentName $EnvironmentName)

    Write-Verbose "Creating quotas..." -Verbose
    $Quotas = @()
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Compute')){ $Quotas += Add-AzSComputeQuota -AdminUri $armEndPoint -SubscriptionId $subscription -AzureStackTokenHeader $headers -ArmLocation $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Network')){ $Quotas += Add-AzSNetworkQuota -AdminUri $armEndPoint -SubscriptionId $subscription -AzureStackTokenHeader $headers -ArmLocation $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Storage')){ $Quotas += Add-AzSStorageQuota -AdminUri $armEndPoint -SubscriptionId $subscription -AzureStackTokenHeader $headers -ArmLocation $Location }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'KeyVault')){ $Quotas += Add-AzSKeyVaultQuota -AdminUri $armEndPoint -SubscriptionId $subscription -AzureStackTokenHeader $headers -ArmLocation $Location }
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

Export-ModuleMember Add-AzSTenantOfferAndQuotas

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

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'New-StorageQuota' -Value 'Add-AzSStorageQuota' -ErrorAction SilentlyContinue

function Add-AzSStorageQuota
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

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'New-ComputeQuota' -Value 'Add-AzSComputeQuota' -ErrorAction SilentlyContinue

function Add-AzSComputeQuota
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

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'New-NetworkQuota'-Value 'Add-AzSNetworkQuota' -ErrorAction SilentlyContinue
    
function Add-AzSNetworkQuota
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

# Temporary backwards compatibility.  Original name has been deprecated.
New-Alias -Name 'Get-KeyVaultQuota' -Value 'Get-AzSKeyVaultQuota' -ErrorAction SilentlyContinue

function Get-AzSKeyVaultQuota
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
