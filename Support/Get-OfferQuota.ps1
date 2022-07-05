#$SubscriptionID = "53a7c7d6-f9c8-4ce0-84a4-9c35b3154801"

<#
    .Synopsis
    Exports Tenant Subscriptions Quotas
    .DESCRIPTION
    Exports Tenant Subscriptions Quotas 
#>

Param
(
    [Parameter(Mandatory = $false)]
    [string] $SubscriptionID = $null,
    [Parameter(Mandatory = $true)]
    [string]$AdminARMEndpoint = $null
)

$FinalResult = [System.Collections.ArrayList]::new()
$allOffers = [System.Collections.ArrayList]::new()

# Get DPS subscriptionID
write-host "Getting SubscriptionID for Default Provider Subscription" -ForegroundColor cyan
$defaultProviderSubscription = (get-azssubscription | Where-Object { $_.DisplayName -like "Default Provider Subscription" } | Select-Object SubscriptionId).subscriptionId
write-host "Default Provider Subscription SubscriptionID : $defaultProviderSubscription " -foreground cyan

# To add timestamp to generated files
$datetime = Get-Date -Format "yyyy.MM.dd_HH-mm-ss"


#get apiverison for resource providers
$PlanAPI = (Get-AzResourceProvider  | Select-Object ResourceTypes -expand ResourceTypes | Where-Object { $_.ResourceTypeName -like "*acquiredPlans" }).apiversions[0]
$OfferAPI = (Get-AzResourceProvider -ProviderNamespace Microsoft.Subscriptions.Admin | select ResourceTypes -expand ResourceTypes | Where-Object { $_.ResourceTypeName -like "*offers" }).apiversions[0]
$StorageQuotaAPI = (Get-AzResourceProvider -ProviderNamespace Microsoft.Storage.Admin | select ResourceTypes -expand ResourceTypes | Where-Object { $_.ResourceTypeName -like "*quotas" }).apiversions[0]
$ComputeQuotaAPI = (Get-AzResourceProvider -ProviderNamespace Microsoft.Compute.Admin | select ResourceTypes -expand ResourceTypes | Where-Object { $_.ResourceTypeName -like "*quotas" }).apiversions[0]
$NetworkQuotaAPI = (Get-AzResourceProvider -ProviderNamespace Microsoft.Network.Admin | select ResourceTypes -expand ResourceTypes | Where-Object { $_.ResourceTypeName -like "*quotas" }).apiversions[0]
$ContainerServiceQuotaAPI = (Get-AzResourceProvider -ProviderNamespace Microsoft.ContainerService.Admin | select ResourceTypes -expand ResourceTypes | Where-Object { $_.ResourceTypeName -like "*quotas" }).apiversions[0]
$WebQuotaAPI = (Get-AzResourceProvider -ProviderNamespace Microsoft.Web.Admin | select ResourceTypes -expand ResourceTypes | Where-Object { $_.ResourceTypeName -like "*quotas" }).apiversions[0]
$MySQLAdapterQuotaAPI = (Get-AzResourceProvider -ProviderNamespace Microsoft.MySQLAdapter.Admin | select ResourceTypes -expand ResourceTypes | Where-Object { $_.ResourceTypeName -like "*quotas" }).apiversions[0]
$SQLAdapterQuotaAPI = (Get-AzResourceProvider -ProviderNamespace Microsoft.SQLAdapter.Admin | select ResourceTypes -expand ResourceTypes | Where-Object { $_.ResourceTypeName -like "*quotas" }).apiversions[0]
write-host "Retrieving apiversion for Resource Providers" -foreground cyan

# Retrive token for API calls
$token = Get-AzAccessToken
$headers = @{ "Authorization" = "Bearer " + $token.Token }

# API is used to show more data like the subscription count, offer state, and its plans
$urlOffers = "$AdminARMEndpoint/subscriptions/$defaultProviderSubscription/providers/Microsoft.Subscriptions.Admin/offers?api-version={0}" -f $OfferAPI #2018-04-01
$listOffers = (Invoke-RestMethod -Method Get -Uri $urlOffers  -Headers $headers).value


# Generate List of Quotas file names
$file_name = "ListofQuotas" + $datetime + ".csv";
$file_path = "./" + $file_name;

$newcsv = {} | Select "OfferName", "Status", "SubscriptionsCount", "BasePlans", "BasePlansRG", "AddOnPlans", "AddOnPlansRG" | Export-Csv $file_path
$csvfile = Import-Csv $file_path

foreach ($offer in $listOffers) {
    $addontemp = $null
    $addonplanRGtemp = $null
    $csvfile.OfferName = $offer.Name
    $csvfile.Status = $offer.properties.State
    $csvfile.SubscriptionsCount = $offer.properties.subscriptionCount
    $csvfile.BasePlans = ($offer.properties.basePlanIds | Out-String).split("/")[8]
    $csvfile.BasePlansRG = ($offer.properties.basePlanIds | Out-String).split("/")[4]
    foreach ($addonplan in $offer.properties.addonPlans.PlanId) {
        $addontemp += ($addonplan | Out-String).split("/")[8] 
        $addonplanRGtemp += ($addonplan | Out-String).split("/")[4]
    }
    $csvfile.AddOnPlans = $addontemp
    $csvfile.AddOnPlansRG = $addonplanRGtemp
    $csvfile | Export-CSV $file_path -NoTypeInformation -Append
}



# Check if single Subscription is trageted or all subscriptions
if ($SubscriptionID ) {
    $subscriptions = Get-AzsUserSubscription  -targetSubscriptionId $SubscriptionID
    write-host "Number of Tenant Subscription: $($subscriptions.count)" -foreground yellow
}
else {
    $subscriptions = Get-AzsUserSubscription
}

foreach ($sub in $subscriptions) {
    
    $token = Get-AzAccessToken
    $headers = @{ "Authorization" = "Bearer " + $token.Token }
    
    write-host "Checking Sub: $($sub.DisplayName)" -foreground cyan 
    
    $offerID = $sub.OfferId
    $OfferName = $offerID.Split("/")[8]
    $RGName = $offerID.Split("/")[4]


    # list offer details
    # baseplans, check offer base plans
    $baseplans = (Get-AzsAdminManagedOffer -name $OfferName -ResourceGroupName $RGName).BasePlanIds
    
    # for Addons better to see it from Sub aspect
    $Addonplans = (Get-AzsAcquiredPlan -targetSubscriptionId $sub.SubscriptionId ).PlanId
    
 
    $basePlantoAdd = [System.Collections.ArrayList]::new()
    $AddonPlantoAdd = [System.Collections.ArrayList]::new()

    foreach ($baseplan in $baseplans) {
        $urlbaseplan = "$AdminARMEndpoint{0}?api-version={1}" -f $baseplan, $PlanAPI #2018-04-01
        $resultbaseplan = Invoke-RestMethod -Method Get -Uri $urlbaseplan -Headers $headers
        $Quotas = $resultbaseplan.properties.quotaIds
        
        foreach ($Quota in $Quotas) {
            if ($Quota -like "*Microsoft.Storage.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $StorageQuotaAPI #2019-08-08-preview
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $capacityInGb += $result.properties.capacityInGb
                $numberOfStorageAccounts += $result.properties.numberOfStorageAccounts
            }
            if ($Quota -like "*Microsoft.Compute.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $ComputeQuotaAPI #2021-01-01
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $virtualMachineCount += $result.properties.virtualMachineCount
                $coresLimit += $result.properties.coresLimit
                $availabilitySetCount += $result.properties.availabilitySetCount
                $vmScaleSetCount += $result.properties.vmScaleSetCount
                $maxAllocationStandardManagedDisksAndSnapshots += $result.properties.maxAllocationStandardManagedDisksAndSnapshots
                $maxAllocationPremiumManagedDisksAndSnapshots += $result.properties.maxAllocationPremiumManagedDisksAndSnapshots
                $ddagpuCount += $result.properties.ddagpuCount
                $partitionedGPUCount += $result.properties.partitionedGPUCount
            }
            <#if($Quota -like "*Microsoft.KeyVault.Admin*"){
                #$Quota
                $url = "https://adminmanagement.lnv5.contosolabs.net{0}?api-version=2017-02-01-preview" -f $Quota
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                #$result.properties

            }#>
            if ($Quota -like "*Microsoft.Network.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $NetworkQuotaAPI  #2015-06-15
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $maxPublicIpsPerSubscription += $result.properties.maxPublicIpsPerSubscription
                $maxVnetsPerSubscription += $result.properties.maxVnetsPerSubscription
                $maxVirtualNetworkGatewaysPerSubscription += $result.properties.maxVirtualNetworkGatewaysPerSubscription
                $maxVirtualNetworkGatewayConnectionsPerSubscription += $result.properties.maxVirtualNetworkGatewayConnectionsPerSubscription
                $maxLoadBalancersPerSubscription += $result.properties.maxLoadBalancersPerSubscription
                $maxNicsPerSubscription += $result.properties.maxNicsPerSubscription
                $maxSecurityGroupsPerSubscription += $result.properties.maxSecurityGroupsPerSubscription
            }
            if ($Quota -like "*Microsoft.ContainerService.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $ContainerServiceQuotaAPI #2019-11-01
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                #unlimited quota for containerService, so no need at the moment to add to it
            }
            if ($Quota -like "*Microsoft.Web.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $WebQuotaAPI #2018-11-01
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $totalAppServicePlansAllowed += $result.properties.totalAppServicePlansAllowed
                $dedicatedAppServicePlansAllowed += $result.properties.dedicatedAppServicePlansAllowed
                $sharedAppServicePlansAllowed += $result.properties.sharedAppServicePlansAllowed
            }
            if ($Quota -like "*Microsoft.MySQLAdapter.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $MySQLAdapterQuotaAPI #2017-08-28
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $resourceCount += $result.properties.resourceCount
                $totalResourceSizeMB += $result.properties.totalResourceSizeMB
            }
            if ($Quota -like "*Microsoft.SQLAdapter.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $SQLAdapterQuotaAPI #2017-08-28
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $resourceCount += $result.properties.resourceCount
                $totalResourceSizeMB += $result.properties.totalResourceSizeMB
            }
        }
        
        $basePlantemp = [PSCustomObject]@{
            baseplanName = $baseplan.Split("/")[8]
        }

        $basePlantoAdd += $basePlantemp
    }

    foreach ($Addonplan in $Addonplans) {
        $Addonplan = (Get-AzResource -Name $Addonplan.Split("/")[6]).ResourceId
        $urlAddonplan = "$AdminARMEndpoint{0}?api-version=2018-04-01" -f $Addonplan
        $resultAddonplan = Invoke-RestMethod -Method Get -Uri $urlAddonplan -Headers $headers
        $Quotas = $resultAddonplan.properties.quotaIds
        foreach ($Quota in $Quotas) {
            if ($Quota -like "*Microsoft.Storage.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $StorageQuotaAPI #2019-08-08-preview
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $capacityInGb += $result.properties.capacityInGb
                $numberOfStorageAccounts += $result.properties.numberOfStorageAccounts
            }
            if ($Quota -like "*Microsoft.Compute.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $ComputeQuotaAPI #2021-01-01
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $virtualMachineCount += $result.properties.virtualMachineCount
                $coresLimit += $result.properties.coresLimit
                $availabilitySetCount += $result.properties.availabilitySetCount
                $vmScaleSetCount += $result.properties.vmScaleSetCount
                $maxAllocationStandardManagedDisksAndSnapshots += $result.properties.maxAllocationStandardManagedDisksAndSnapshots
                $maxAllocationPremiumManagedDisksAndSnapshots += $result.properties.maxAllocationPremiumManagedDisksAndSnapshots
                $ddagpuCount += $result.properties.ddagpuCount
                $partitionedGPUCount += $result.properties.partitionedGPUCount
            }
            <#if($Quota -like "*Microsoft.KeyVault.Admin*"){
                #$Quota
                $url = "https://adminmanagement.lnv5.contosolabs.net{0}?api-version=2017-02-01-preview" -f $Quota
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                #$result.properties

            }#>
            if ($Quota -like "*Microsoft.Network.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $NetworkQuotaAPI  #2015-06-15
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $maxPublicIpsPerSubscription += $result.properties.maxPublicIpsPerSubscription
                $maxVnetsPerSubscription += $result.properties.maxVnetsPerSubscription
                $maxVirtualNetworkGatewaysPerSubscription += $result.properties.maxVirtualNetworkGatewaysPerSubscription
                $maxVirtualNetworkGatewayConnectionsPerSubscription += $result.properties.maxVirtualNetworkGatewayConnectionsPerSubscription
                $maxLoadBalancersPerSubscription += $result.properties.maxLoadBalancersPerSubscription
                $maxNicsPerSubscription += $result.properties.maxNicsPerSubscription
                $maxSecurityGroupsPerSubscription += $result.properties.maxSecurityGroupsPerSubscription
            }
            if ($Quota -like "*Microsoft.ContainerService.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $ContainerServiceQuotaAPI #2019-11-01
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                #unlimited quota for containerService, so no need at the moment to add to it
            }
            if ($Quota -like "*Microsoft.Web.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $WebQuotaAPI #2018-11-01
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $totalAppServicePlansAllowed += $result.properties.totalAppServicePlansAllowed
                $dedicatedAppServicePlansAllowed += $result.properties.dedicatedAppServicePlansAllowed
                $sharedAppServicePlansAllowed += $result.properties.sharedAppServicePlansAllowed
            }
            if ($Quota -like "*Microsoft.MySQLAdapter.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $MySQLAdapterQuotaAPI #2017-08-28
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $mySQLresourceCount += $result.properties.resourceCount
                $mySQLtotalResourceSizeMB += $result.properties.totalResourceSizeMB
            }
            if ($Quota -like "*Microsoft.SQLAdapter.Admin*") {
                $url = "$AdminARMEndpoint{0}?api-version={1}" -f $Quota, $SQLAdapterQuotaAPI #2017-08-28
                $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                $SQLresourceCount += $result.properties.resourceCount
                $SQLtotalResourceSizeMB += $result.properties.totalResourceSizeMB
            }
        }
        $Addonplantemp = [PSCustomObject]@{
            AddonplanName = $Addonplan.Split("/")[8]
        }

        $AddonPlantoAdd += $Addonplantemp
    }
    
    $SubResult = [pscustomobject]@{
        #INFO
        Info_DisplayName                                           = $sub.DisplayName
        Info_SubscriptionId                                        = $sub.SubscriptionId
        Info_Owner                                                 = $sub.Owner
        Info_OfferName                                             = $OfferName
        Info_Baseplans                                             = $basePlantoAdd.baseplanName | out-string
        Info_AddonPlans                                            = $AddonPlantoAdd.AddonplanName | out-string

        #Storage
        Storage_CapacityInGb                                       = $capacityInGb
        Storage_NumberOfStorageAccounts                            = $numberOfStorageAccounts

        #Compute
        Compute_VirtualMachineCount                                = $virtualMachineCount
        Compute_CoresLimit                                         = $coresLimit
        Compute_AvailabilitySetCount                               = $availabilitySetCount
        Compute_VMSSCount                                          = $vmScaleSetCount
        Compute_MaxAllocationStandardManagedDisksAndSnapshots      = $maxAllocationStandardManagedDisksAndSnapshots
        Compute_MaxAllocationPremiumManagedDisksAndSnapshots       = $maxAllocationPremiumManagedDisksAndSnapshots
        Compute_DdagpuCount                                        = $ddagpuCount
        Compute_PartitionedGPUCount                                = $partitionedGPUCount

        #Network
        Network_MaxPublicIpsPerSubscription                        = $maxPublicIpsPerSubscription
        Network_MaxVnetsPerSubscription                            = $maxVnetsPerSubscription
        Network_MaxVirtualNetworkGatewaysPerSubscription           = $maxVirtualNetworkGatewaysPerSubscription
        Network_MaxVirtualNetworkGatewayConnectionsPerSubscription = $maxVirtualNetworkGatewayConnectionsPerSubscription
        Network_MaxLoadBalancersPerSubscription                    = $maxLoadBalancersPerSubscription
        Network_MaxNicsPerSubscription                             = $maxNicsPerSubscription
        Network_MaxSecurityGroupsPerSubscription                   = $maxSecurityGroupsPerSubscription

        #AppServices
        AppServices_TotalAppServicePlansAllowed                    = $totalAppServicePlansAllowed
        AppServices_DedicatedAppServicePlansAllowed                = $dedicatedAppServicePlansAllowed
        AppServices_SharedAppServicePlansAllowed                   = $sharedAppServicePlansAllowed

        #SQL
        SQL_resourceCount                                          = $SQLresourceCount
        SQL_totalResourceSizeMB                                    = $SQLtotalResourceSizeMB

        #mySQL
        mySQL_resourceCount                                        = $mySQLresourceCount
        mySQL_totalResourceSizeMB                                  = $mySQLtotalResourceSizeMB
    }
    $FinalResult.add([pscustomobject]$SubResult ) | Out-Null
    $SubResult 
}



$file_name = "QuotaResult" + $datetime + ".csv";
$file_path = "./" + $file_name;
$FinalResult  | Format-Table * -AutoSize
$FinalResult  | Export-Csv -NoTypeInformation -Path $file_path
write-host "CSV file $file_path has been generated"
