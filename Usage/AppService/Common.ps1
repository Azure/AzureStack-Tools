<#
    .Synopsis
        Get AppService billing records
    .DESCRIPTION
        This is sample script to illustrate how App Service billing records can be fetched using Azure stack usage API. It also provides example to calculate
         subscription usage for App Service and way to disable/enable if subscription limit is reached.
         IMPORTANT  : THIS SAMPLE IS PROVIDED AS IS AND ONLY INTENDED FOR REFERENCE PURPOSE.
    .EXAMPLE
        $usageSummary  = Get-AppServiceBillingRecords `
                            -StartTime $StartTime `
                            -EndTime $EndTime `
                            -Granularity $Granularity `
                            -TenantUsage $TenantUsage
#>

function Get-AppServiceBillingRecords 
{
    Param
    (
        [Parameter(Mandatory = $true)]
        [datetime]
        $StartTime,

        [Parameter(Mandatory = $true)]
        [datetime]
        $EndTime ,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Hourly", "Daily")]
        [String]
        $Granularity = 'Hourly',

        [Parameter(Mandatory = $false)]
        [bool]
        $TenantUsage = $true
    )

    $CsvFile = "AppServiceUsageSummary.csv"

    <#
     This is the meter used by Microsoft to bill App Service on Azure Stack.
     For example - for Pay as you use model, we charge $0.056/vCPU/hour ($42/vCPU/month) but we generate billing records for every minute,
     so if you are not using the machine the full hour, you will be charged for a fraction of it.
     We only generate billing records only for web worker machines and not for other machines which are of the service.
     the price can change, please review https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-usage-related-faq
    #>
    $AppServiceAdminMeters = @{
        '190c935e-9ada-48ff-9ab8-56ea1cf9adaa' = @{
                                                    name = 'App Service virtual core hours'
                                                    price = 0.056
                                                  }
    }

    <#
    The following meters can be used to bill to the tenants if using the default App Service Worker Tiers.
    For this example, the prices are 

    IMPORTANT: For the custom App Service Worker Tier, each worker tier will have a unique dynamically generated identifier. Please refer the usage report -> Identify the meter id generated for your custom worker tier and add to the table below.

    #>
    $AppServiceTenantMeters = @{
        '957e9f36-2c14-45a1-b6a1-1723ef71a01d' = @{
                                                    name = 'Shared App Service Hours'
                                                    price = 0.009
                                                  }
        '539cdec7-b4f5-49f6-aac4-1f15cff0eda9' = @{
                                                    name = 'Free App Service Hours'
                                                    price = 0.003
                                                  }
        'db658d61-ef2d-4888-9843-72f5c774fd3c' = @{
                                                    name = 'Small Basic App Service Hours'
                                                    price = 1
                                                  }
        '27b01104-e0df-4f30-a171-f1b00ecb76b3' = @{
                                                    name = 'Medium Basic App Service Hours'
                                                    price = 1
                                                  }
        '50db6a92-5dff-4c9b-8238-8ea5fb1be107' = @{
                                                    name = 'Large Basic App Service Hours'
                                                    price = 1
                                                  }
        '88039d51-a206-3a89-e9de-c5117e2d10a6' = @{
                                                    name = 'Small Standard App Service Hours'
                                                    price = 0.01
                                                  }
        '83a2a13e-4788-78dd-5d55-2831b68ed825' = @{
                                                    name = 'Medium Standard App Service Hours'
                                                    price = 0.02
                                                  }
        '1083b9db-e9bb-24be-a5e9-d6fdd0ddefe6' = @{
                                                    name = 'Large Standard App Service Hours'
                                                    price = 0.03
                                                  }
        '26bd6580-c3bd-4e7e-8092-58b28eb1bb94' = @{
                                                    name = 'Small Premium App Service Hours'
                                                    price = 1
                                                  }
        'a1cba406-e83e-45c3-bd36-485191c215d9' = @{
                                                    name = 'Medium Premium App Service Hours'
                                                    price = 1
                                                  }
        'a2104a9d-5a78-4f8f-a2df-034bd43d602d' = @{
                                                    name = 'Large Premium App Service Hours'
                                                    price = 1
                                                  }
        'a91eed6c-dbbc-4532-859c-86de776433a4' = @{
                                                    name = 'Extra Large Premium App Service Hours'
                                                    price = 1
                                                  }
        '73215a6c-fa54-4284-b9c1-7e8ec871cc5b' = @{
                                                    name = 'Web Process'
                                                    price = 0.002
                                                  }
        '5887d39b-0253-4e12-83c7-03e1a93dffd9' = @{
                                                    name = 'External Egress Bandwidth'
                                                    price = 1
                                                  }
        '264acb47-ad38-47f8-add3-47f01dc4f473' = @{
                                                    name = 'SNI SSL'
                                                    price = 1
                                                  }
        '60b42d72-dc1c-472c-9895-6c516277edb4' = @{
                                                    name = 'IP SSL'
                                                    price = 1
                                                 }
        'd1d04836-075c-4f27-bf65-0a1130ec60ed' = @{
                                                    name = 'Functions Compute'
                                                    price = 1
                                                  }
        '67cc4afc-0691-48e1-a4b8-d744d1fedbde' = @{
                                                    name = 'Functions Requests'
                                                    price = 1
                                                  }
    }    

    #build usage uri and set meters
    if ($TenantUsage)
    {
        $usageResourceType = "Microsoft.Commerce.Admin/locations/subscriberUsageAggregates"
        $meters = $AppServiceTenantMeters
    }
    else
    {
        $usageResourceType = "Microsoft.Commerce/locations/UsageAggregates"
        $meters = $AppServiceAdminMeters
    }

    $params = @{
        ResourceName = '../' 
        ResourceType = $usageResourceType
        ApiVersion = "2015-06-01-preview"
        ODataQuery = "reportedStartTime={0:s}&reportedEndTime={1:s}&showDetails=true&aggregationGranularity={2}" -f $StartTime, $EndTime, $Granularity
    }

    $result = Get-AzureRmResource @params -ErrorVariable RestError -Verbose

    if ($RestError)
    {
        return
    }

    $usageSummary = @()
    $count = $result.Count
    $result  | ForEach-Object {
        if ($meters.ContainsKey($_.Properties.MeterId))
        {
            $record = New-Object -TypeName System.Object
            $resourceInfo = ($_.Properties.InstanceData | ConvertFrom-Json).'Microsoft.Resources'
            $resourceText = $resourceInfo.resourceUri.Replace('\', '/')
            $subscription = $resourceText.Split('/')[2]
            $resourceType = $resourceText.Split('/')[7]
            $resourceName = $resourceText.Split('/')[8]
            #$record | Add-Member -Name Name -MemberType NoteProperty -Value $_.Name
            #$record | Add-Member -Name Type -MemberType NoteProperty -Value $_.Type
            $record | Add-Member -Name MeterId -MemberType NoteProperty -Value $_.Properties.MeterId
            $record | Add-Member -Name MeterName -MemberType NoteProperty -Value $meters[$_.Properties.MeterId].name
            $record | Add-Member -Name Quantity -MemberType NoteProperty -Value ([decimal]($_.Properties.Quantity)) -ErrorAction Continue
            $record | Add-Member -Name UnitPrice -MemberType NoteProperty -Value $meters[$_.Properties.MeterId].price
            $record | Add-Member -Name Amount -MemberType NoteProperty -Value ($meters[$_.Properties.MeterId].price * [decimal]($_.Properties.Quantity)) -ErrorAction Continue
            $record | Add-Member -Name UsageStartTime -MemberType NoteProperty -Value $_.Properties.UsageStartTime
            $record | Add-Member -Name UsageEndTime -MemberType NoteProperty -Value $_.Properties.UsageEndTime
            $record | Add-Member -Name additionalInfo -MemberType NoteProperty -Value $resourceInfo.additionalInfo
            $record | Add-Member -Name location -MemberType NoteProperty -Value $resourceInfo.location
            $record | Add-Member -Name tags -MemberType NoteProperty -Value $resourceInfo.tags
            $record | Add-Member -Name subscription -MemberType NoteProperty -Value $_.Properties.subscriptionId
            $record | Add-Member -Name resourceType -MemberType NoteProperty -Value $resourceType
            $record | Add-Member -Name resourceName -MemberType NoteProperty -Value $resourceName
            $record | Add-Member -Name resourceUri -MemberType NoteProperty -Value $resourceText
            $usageSummary += $record
        }
    }

    return $usageSummary
}
