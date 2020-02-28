<#
    .Synopsis
        Get AppService billing records from Azure Stack. You can also export the data to CSV.
    .DESCRIPTION
        This is sample script to illustrate how App Service billing records can be fetched using Azure stack usage API.
        IMPORTANT  : THIS SAMPLE IS PROVIDED AS IS AND ONLY INTENDED FOR REFERENCE PURPOSE.
    .EXAMPLE
        if not alreday, Configure and sign in to Azure stack environment : https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-configure-admin#configure-the-operator-environment-and-sign-in-to-azure-stack
        ** To get subscriber Usage data use (-TenantUsage $true) *******
        .\Get-AppServiceBillingRecords.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true
        .\Get-AppServiceBillingRecords.ps1 -StartTime 01/08/2018 -EndTime 01/09/2018 -Granularity Hourly -TenantUsage $true -ExportToCSV $true
        *****To get current subscription data use (-TenantUsage $false) ****
        .\Get-AppServiceBillingRecords.ps1 -StartTime 01/08/2018 -EndTime 01/24/2018 -Granularity Daily -TenantUsage $false
#>
    [CmdletBinding()]
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

    $usageSummary  = Get-AppServiceBillingRecords `
                            -StartTime $StartTime `
                            -EndTime $EndTime `
                            -Granularity $Granularity `
                            -TenantUsage $TenantUsage

    if (!$ExportToCSV)
    {
        Write-Output $usageSummary | Format-Table -AutoSize

        Write-Host "Complete - billing records" $usageSummary.Count

        return
     }

    #Export to CSV
    if (Test-Path -Path $CsvFile -ErrorAction SilentlyContinue)
    {
       Remove-Item -Path $CsvFile -Force
    }

    New-Item -Path $CsvFile -ItemType File | Out-Null

    $usageSummary | Export-Csv -Path $CsvFile -Append -NoTypeInformation 

    if ($PSBoundParameters.ContainsKey('Debug'))
    {
        $result | Export-Csv -Path "$CsvFile.raw" -Append -NoTypeInformation
    }

    Write-Host "Complete - billing records written to $CsvFile " $usageSummary.Count