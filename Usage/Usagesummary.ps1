<#
    .Synopsis
    Exports usage meters from Azure Stack to a csv file
    .DESCRIPTION
    Long description
    .EXAMPLE
    Export-AzsUsage -StartTime 2/15/2017 -EndTime 2/16/2017 -Granularity Hourly
#>

function Export-AzsUsage {
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
        [String]
        $CsvFile = "UsageSummary.csv",
        [Parameter (Mandatory = $false)]
        [Switch]
        $TenantUsage,
        [Parameter(Mandatory = $false)]
        [Switch]
        $Force
    )

    #Initialise result count and meter hashtable
    $Total = 0
    $meters = @{
        'F271A8A388C44D93956A063E1D2FA80B' = 'Static IP Address Usage'
        '9E2739BA86744796B465F64674B822BA' = 'Dynamic IP Address Usage'
        'B4438D5D-453B-4EE1-B42A-DC72E377F1E4' = 'TableCapacity'
        'B5C15376-6C94-4FDD-B655-1A69D138ACA3' = 'PageBlobCapacity'
        'B03C6AE7-B080-4BFA-84A3-22C800F315C6' = 'QueueCapacity'
        '09F8879E-87E9-4305-A572-4B7BE209F857' = 'BlockBlobCapacity'
        'B9FF3CD0-28AA-4762-84BB-FF8FBAEA6A90' = 'TableTransactions'
        '50A1AEAF-8ECA-48A0-8973-A5B3077FEE0D' = 'TableDataTransIn'
        '1B8C1DEC-EE42-414B-AA36-6229CF199370' = 'TableDataTransOut'
        '43DAF82B-4618-444A-B994-40C23F7CD438' = 'BlobTransactions'
        '9764F92C-E44A-498E-8DC1-AAD66587A810' = 'BlobDataTransIn'
        '3023FEF4-ECA5-4D7B-87B3-CFBC061931E8' = 'BlobDataTransOut'
        'EB43DD12-1AA6-4C4B-872C-FAF15A6785EA' = 'QueueTransactions'
        'E518E809-E369-4A45-9274-2017B29FFF25' = 'QueueDataTransIn'
        'DD0A10BA-A5D6-4CB6-88C0-7D585CEF9FC2' = 'QueueDataTransOut'
        'FAB6EB84-500B-4A09-A8CA-7358F8BBAEA5' = 'Base VM Size Hours'
        '9CD92D4C-BAFD-4492-B278-BEDC2DE8232A' = 'Windows VM Size Hours'
        '6DAB500F-A4FD-49C4-956D-229BB9C8C793' = 'VM size hours'
    }

    #Output Files
    if (Test-Path -Path $CsvFile -ErrorAction SilentlyContinue)
    {
        if ($Force)
        {
            Remove-Item -Path $CsvFile -Force
        }
        else {
            Write-Error "'$CsvFile' already exists use -Force to overwrite"
            return
        }
    }
    New-Item -Path $CsvFile -ItemType File | Out-Null

    $usageResourceType = "Microsoft.Commerce/locations/subscriberUsageAggregates"
        
    #build usage uri
    if ($TenantUsage)
    {
        $usageResourceType = "Microsoft.Commerce/locations/UsageAggregates"
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
    $Total += $count
    $result  | ForEach-Object {
        $record = New-Object -TypeName System.Object
        $resourceInfo = ($_.Properties.InstanceData | ConvertFrom-Json).'Microsoft.Resources'
        $resourceText = $resourceInfo.resourceUri.Replace('\', '/')        
        $resourceType = $resourceText.Split('/')[7]
        $resourceName = $resourceText.Split('/')[8]
        #$record | Add-Member -Name Name -MemberType NoteProperty -Value $_.Name
        #$record | Add-Member -Name Type -MemberType NoteProperty -Value $_.Type
        $record | Add-Member -Name MeterId -MemberType NoteProperty -Value $_.Properties.MeterId
        if ($meters.ContainsKey($_.Properties.MeterId)) {
            $record | Add-Member -Name MeterName -MemberType NoteProperty -Value $meters[$_.Properties.MeterId]
        }
        $record | Add-Member -Name Quantity -MemberType NoteProperty -Value $_.Properties.Quantity
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
    
    $usageSummary | Export-Csv -Path $CsvFile -Append -NoTypeInformation 
    if ($PSBoundParameters.ContainsKey('Debug'))
    {
        $result | Export-Csv -Path "$CsvFile.raw" -Append -NoTypeInformation
    }
    
    Write-Host "Complete - $Total Usage records written to $CsvFile"
}

#Main

Export-AzsUsage -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -Force
