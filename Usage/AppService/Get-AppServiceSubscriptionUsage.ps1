<#
    .Synopsis
        Get AppService billing details per subscription.
    .DESCRIPTION
        This is sample script to illustrate how App Service billing records can be fetched using Azure stack usage API. It also provides example to calculate subscription usage.
        IMPORTANT  : THIS SAMPLE IS PROVIDED AS IS AND ONLY INTENDED FOR REFERENCE PURPOSE.
    .EXAMPLE
        If not alreday, Configure and sign in to Azure stack environment : https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-configure-admin#configure-the-operator-environment-and-sign-in-to-azure-stack
        ** To get subscriber Usage data use (-TenantUsage $true) *******
        .\Get-AppServiceSubscriptionUsage.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Daily -TenantUsage $true
        .\Get-AppServiceSubscriptionUsage.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true -ExportToCSV $true

        *****To get current subscription data use (-TenantUsage $false) ****
        .\Get-AppServiceSubscriptionUsage.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $false
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
    $SubscriptionsUsageCsvFile = "SubscriptionsUsage.csv"

    $usageSummary  = Get-AppServiceBillingRecords `
                            -StartTime $StartTime `
                            -EndTime $EndTime `
                            -Granularity $Granularity `
                            -TenantUsage $TenantUsage

    $TenantSubscriptionRecords = @()

     $usageSummary | Group-Object Subscription | %{
        $record = New-Object -TypeName System.Object
        $record | Add-Member -Name Subscription -MemberType NoteProperty -Value $_.Name
        $record | Add-Member -Name currentUsage -MemberType NoteProperty -Value (($_.Group | Measure-Object Amount -Sum).Sum)
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
    
    #Export to CSV
    if (Test-Path -Path $CsvFile -ErrorAction SilentlyContinue)
    {
        Remove-Item -Path $CsvFile -Force
    }

    if (Test-Path -Path $SubscriptionsUsageCsvFile -ErrorAction SilentlyContinue)
    {
        Remove-Item -Path $SubscriptionsUsageCsvFile -Force
    }

    New-Item -Path $CsvFile -ItemType File | Out-Null
    New-Item -Path $SubscriptionsUsageCsvFile -ItemType File | Out-Null

    $usageSummary | Export-Csv -Path $CsvFile -Append -NoTypeInformation 
    $TenantSubscriptionRecords | Export-Csv -Path $SubscriptionsUsageCsvFile -Append -NoTypeInformation

    if ($PSBoundParameters.ContainsKey('Debug'))
    {
        $result | Export-Csv -Path "$CsvFile.raw" -Append -NoTypeInformation
        $TenantSubscriptionRecords | Export-Csv -Path "$SubscriptionsUsageCsvFile.raw" -Append -NoTypeInformation
    }

    Write-Host "Complete - billing records written to $CsvFile " $usageSummary.Count
    Write-Host "Complete - Records written to $SubscriptionsUsageCsvFile " $TenantSubscriptionRecords.Count