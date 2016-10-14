# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Version 4.0
#requires -Modules AzureRM.Profile, AzureRm.AzureStackAdmin

<#
    .SYNOPSIS
    Creates "default" tenant offer with unlimited quotas across Compute, Network, Storage and KeyVault services.
#>
function New-AzureStackTenantOfferAndQuotas
{
    param (
        [parameter(HelpMessage="Name of the offer to be made advailable to tenants")]
        [string] $Name ="default",
        [parameter(HelpMessage="Azure Stack environment name for use with AzureRM commandlets")]
        [string] $EnvironmentName = "AzureStack",
        [parameter(HelpMessage="Azure Stack region in which to define plans and quotas")]
        [string]$ResourceLocation = "local",
        [Parameter(HelpMessage="If this parameter is not specified all quotas are assigned. Provide a sub selection of quotas in this parameter if you do not want all quotas assigned.")]
        [ValidateSet('Compute','Network','Storage','KeyVault','Subscriptions',IgnoreCase =$true)]
        [array]$ServiceQuotas,
        [parameter(Mandatory=$true,HelpMessage="Azure Stack service administrator credential in Azure Active Directory")]
        [pscredential] $ServiceAdminCredential
    )

    $envName = $EnvironmentName
    $credentialObj = $ServiceAdminCredential

    Write-Verbose "Logging service admin into Azure Active Directory..." -Verbose
    Add-AzureRmAccount -EnvironmentName $envName -Credential $credentialObj -ErrorAction Stop

    $defaultSubscription = Get-AzureRmSubscription -SubscriptionName "Default Provider Subscription"

    $defaultSubscription | Select-AzureRmSubscription -ErrorAction Stop

    $azEnv = Get-AzureRmEnvironment -Name $envName
    $ActiveDirectoryEndpoint = $azEnv.ActiveDirectoryAuthority + $azEnv.AdTenant + "/"
    $ActiveDirectoryServiceEndpointResourceId = $azEnv.ActiveDirectoryServiceEndpointResourceId
    $AADTenantID = $azEnv.AdTenant
    $armEndpoint = $azEnv.ResourceManagerUrl

    Write-Verbose "Obtaining token from AAD..." -Verbose
    $asToken = Get-AzureStackToken -Authority ($ActiveDirectoryEndpoint + "oauth2") -Resource $ActiveDirectoryServiceEndpointResourceId -AadTenantId $AADTenantID -Credential $credentialObj

    Write-Verbose "Creating quotas..." -Verbose
    $Quotas = @()
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Compute')){ $Quotas += New-ComputeQuota -AdminUri $armEndPoint -SubscriptionId $defaultSubscription.SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Network')){ $Quotas += New-NetworkQuota -AdminUri $armEndPoint -SubscriptionId $defaultSubscription.SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Storage')){ $Quotas += New-StorageQuota -AdminUri $armEndPoint -SubscriptionId $defaultSubscription.SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'KeyVault')){ $Quotas += Get-KeyVaultQuota -AdminUri $armEndPoint -SubscriptionId $defaultSubscription.SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation }
    if ((!($ServiceQuotas)) -or ($ServiceQuotas -match 'Subscriptions')){ $Quotas += Get-SubscriptionsQuota -AdminUri $armEndpoint -SubscriptionId $defaultSubscription.SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation }

    Write-Verbose "Creating resource group for plans and offers..." -Verbose
    if (Get-AzureRmResourceGroup -Name $Name -ErrorAction SilentlyContinue)
    {        
        Remove-AzureRmResourceGroup -Name $Name -Force -ErrorAction Stop
    }
    New-AzureRmResourceGroup -Name $Name -Location $ResourceLocation -ErrorAction Stop

    Write-Verbose "Creating plan..." -Verbose
    $plan = New-AzureRMPlan -Name $Name -DisplayName $Name -ArmLocation $ResourceLocation -ResourceGroup $Name -SubscriptionId $defaultSubscription.SubscriptionId -AdminUri $armEndpoint -Token $asToken -QuotaIds $Quotas

    Write-Verbose "Creating public offer..." -Verbose
    $offer = New-AzureRMOffer -Name $Name -DisplayName $Name -State Public -BasePlanIds @($plan.Id) -ArmLocation $ResourceLocation -ResourceGroup $Name

    return $offer
}

Export-ModuleMember New-AzureStackTenantOfferAndQuotas

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
        [string] $AzureStackToken,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $ArmLocation  
    )    

    $getSubscriptionsQuota = @{
        Uri = "{0}/subscriptions/{1}/providers/Microsoft.Subscriptions.Admin/locations/{2}/quotas?api-version=2015-11-01" -f $AdminUri, $SubscriptionId, $ArmLocation
        Method = "GET"
        Headers = @{ "Authorization" = "Bearer " + $AzureStackToken }
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
        [string] $AzureStackToken,
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
    $headers = @{ "Authorization" = "Bearer "+ $AzureStackToken }
    $storageQuota = Invoke-RestMethod -Method Put -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $headers
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
        [string] $AzureStackToken,
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
    $headers = @{ "Authorization" = "Bearer "+ $AzureStackToken }
    $computeQuota = Invoke-RestMethod -Method Put -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $headers
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
        [string] $AzureStackToken,
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
    $headers = @{ "Authorization" = "Bearer "+ $AzureStackToken}
    $networkQuota = Invoke-RestMethod -Method Put -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $headers
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
        [string] $AzureStackToken,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]    
        [string] $ArmLocation  
    ) 

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Keyvault.Admin/locations/{2}/quotas?api-version=2014-04-01-preview" -f $AdminUri, $SubscriptionId, $ArmLocation
    $headers = @{ "Authorization" = "Bearer "+ $AzureStackToken }
    $kvQuota = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType 'application/json'
    $kvQuota.Value.Id
}
