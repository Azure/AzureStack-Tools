#Create a PEP session
$cred = get-credential
$pepsession = New-PSSession -ComputerName 172.16.150.224 -ConfigurationName PrivilegedEndpoint -Credential $cred

$ScriptBlock = {
    $duration=""
    [DateTime]$endTime = Get-Date
    if (![String]::IsNullOrEmpty($_.StartTimeUtc)){
        if (![String]::IsNullOrEmpty($_.EndTimeUtc)){
            $endTime = $_.EndTimeUtc
            }
        $duration= ($endTime - [DateTime]$_.StartTimeUtc).ToString("hh\:mm\:ss")
        }
    Write-Host ("{0,-8} {1,-10}  {2,-30} {3,-20} {4}" -f $_.FullStepIndex,$duration,$_.Name,$_.Status,$_.Description)
}


$retryDelay = 3600
# enum UpdateRunState
$failed = $false
do {    
    Write-Host -ForegroundColor Cyan "Checking update run progress" 
    try
    {
          [xml]$status = Invoke-Command -Session $pepsession -ScriptBlock {Get-AzureStackUpdateStatus}

        switch ($status.Action.Status)
        {
            'Unknown' {
                Write-Host -ForegroundColor Cyan "Update run state is unknown" }
            'Succeeded' {
                Write-Host -ForegroundColor Green "Update run is successful" }
            'InProgress' {
                Write-Host -ForegroundColor Cyan "Update run is in progress" }
            'Failed' {
                Write-Host -ForegroundColor Yellow "Update run failed"
                $failed = $true
                return }
        }

        $runtime = (Get-Date) - $([DateTime]$status.Action.StartTimeUtc)
        #$status.SelectNodes("//Step") | % $ScriptBlock
        $status.SelectNodes("//Step") | Where-Object {$_.Status -notlike "Success"} | % $ScriptBlock  

    }
    catch
    {
        Write-Host -ForegroundColor Yellow "Exception - ERCS may be unavailable"
    }
    Finally
    {
        if ($status.Action.Status -eq 'InProgress' -and (-NOT $failed))
        {
            $time = Get-Date -Format s
            Write-Host -ForegroundColor Cyan "$time - Current Run Time: $($runtime) - Sleeping $retryDelay seconds"
            Start-Sleep -Seconds $retryDelay
        }
    }
} while ($status.Action.Status -eq 'InProgress')
