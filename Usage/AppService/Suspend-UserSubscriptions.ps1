<#
    .Synopsis
        Suspend or enable subscription based on usage limit.
    .DESCRIPTION
        This is sample script to illustrate how App Service billing records can be fetched using Azure stack usage API. It also provides example to calculate subscription usage.
        IMPORTANT  : THIS SAMPLE IS PROVIDED AS IS AND ONLY INTENDED FOR REFERENCE PURPOSE.
    .EXAMPLE
        #1 - If not alreday, configure and sign in to Azure stack environment : https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-configure-admin#configure-the-operator-environment-and-sign-in-to-azure-stack
        #2 - set value for $TenantSubscriptions with list of tenant subscription and usage limit.
        ** To get subscriber Usage data use (-TenantUsage $true) *******
        .\Suspend-UserSubscriptions.ps1 -StartTime 01/08/2018 -EndTime 01/24/2018 -Granularity Hourly -TenantUsage $true
        .\Suspend-UserSubscriptions.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true -ExportToCSV $true

        ***To get current subscription data use (-TenantUsage $false) ****
        .\Suspend-UserSubscriptions.ps1 -StartTime 01/08/2018 -EndTime 01/24/2018 -GranularityHourly -TenantUsage $false
#>
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
        $TenantUsage = $true,

        [Parameter(Mandatory = $false)]
        [bool]
        $ExportToCSV = $false
    )
    
    $VerbosePreference = 'Continue'

    # Load common functions
    . "$PSScriptRoot\Common.ps1"

    # Main
    $CsvFile = "AppServiceUsageSummary.csv"
    $SubscriptionsUsageUpdatedCsvFile = "SubscriptionsUsage-Updated.csv"

    # Provide List of tenant Subscriptions to be validated and disabled if hit the limit for the duration provided.
        $TenantSubscriptions = @{
        '53fd0778-cbd3-414c-8554-d006e976e748' = @{
                                                    usageLimit = 1
                                                  }
        'e33616fb-ceb7-4a9f-89f5-a7fcba7d5aca' = @{
                                                    usageLimit = 1000
                                                  }
    }

    $usageSummary  = Get-AppServiceBillingRecords `
                            -StartTime $StartTime `
                            -EndTime $EndTime `
                            -Granularity $Granularity `
                            -TenantUsage $TenantUsage

    $TenantSubscriptionRecords = @()

     $usageSummary | Group-Object Subscription | %{
        $record = New-Object -TypeName System.Object
        $record | Add-Member -Name Subscription -MemberType NoteProperty -Value $_.Name
        $CurrentUsage = (($_.Group | Measure-Object Amount -Sum).Sum)
        $record | Add-Member -Name currentUsage -MemberType NoteProperty -Value $CurrentUsage

        # Now take action on subscriptions based on current usage
        Write-Output "Processing subscription" $_.Name
        if ($TenantSubscriptions.ContainsKey($_.Name))
        {
            $sub = $null
            $sub = Get-AzsUserSubscription -SubscriptionId $_.Name -ErrorAction SilentlyContinue

            if ($sub -eq $null)
            {
                Write-Warning ("Subscription not found " + ($_.Name))
            }

            $record | Add-Member -Name State -MemberType NoteProperty -Value $sub.State -ErrorAction Continue
            $record | Add-Member -Name usageLimit -MemberType NoteProperty -Value $TenantSubscriptions[$_.Name].usageLimit
                
            if (([decimal]$CurrentUsage) -ge ([decimal]$TenantSubscriptions[$_.Name].usageLimit))
            {
                if ($sub.State -eq "Enabled")
                {
                    $sub.State ="Disabled" 
                    Set-AzsUserSubscription -Subscription $sub
                }
            }
            else
            {
                if ($sub.State -eq "Disabled")
                {
                    $sub.State ="Enabled" 
                    Set-AzsUserSubscription -Subscription $sub
                }
            }

            $record | Add-Member -Name StateUpdated -MemberType NoteProperty -Value $sub.State
        }

        $TenantSubscriptionRecords += $record
     }

     if (!$ExportToCSV)
     {
        Write-Output $usageSummary | Format-Table -AutoSize

        Write-Host "Complete - billing records" $usageSummary.Count

        Write-Output $TenantSubscriptionRecords | Format-Table -AutoSize

        Write-Host "Complete - subscription records" $TenantSubscriptionRecords.Count

        return
     }
    
    # Export to CSV
    if (Test-Path -Path $CsvFile -ErrorAction SilentlyContinue)
    {
        Remove-Item -Path $CsvFile -Force
    }

    if (Test-Path -Path $SubscriptionsUsageUpdatedCsvFile -ErrorAction SilentlyContinue)
    {
      Remove-Item -Path $SubscriptionsUsageUpdatedCsvFile -Force
    }

    New-Item -Path $CsvFile -ItemType File | Out-Null
    New-Item -Path $SubscriptionsUsageUpdatedCsvFile -ItemType File | Out-Null

    $usageSummary | Export-Csv -Path $CsvFile -Append -NoTypeInformation 
    $TenantSubscriptionRecords | Export-Csv -Path $SubscriptionsUsageUpdatedCsvFile -Append -NoTypeInformation

    if ($PSBoundParameters.ContainsKey('Debug'))
    {
        $result | Export-Csv -Path "$CsvFile.raw" -Append -NoTypeInformation
        $TenantSubscriptionRecords | Export-Csv -Path "$SubscriptionsUsageUpdatedCsvFile.raw" -Append -NoTypeInformation
    }

    Write-Host "Complete - Usage records written to $CsvFile " $usageSummary.Count
    Write-Host "Complete - Records written to $SubscriptionsUsageUpdatedCsvFile " $TenantSubscriptionRecords.Count
