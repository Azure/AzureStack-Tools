$Global:ContinueOnFailure = $false
$Global:JSONLogFile  = "Run-Canary.JSON"
$Global:TxtLogFile  = "AzureStackCanaryLog.Log"
$Global:wttLogFileName= ""
if (Test-Path -Path "$PSScriptRoot\..\WTTLog.ps1")
{
    Import-Module -Name "$PSScriptRoot\..\WTTLog.ps1" -Force
    $Global:wttLogFileName = (Join-Path $PSScriptRoot "AzureStack_CanaryValidation_Test.wtl")    
}

$CurrentUseCase = @{}
[System.Collections.Stack] $UseCaseStack = New-Object System.Collections.Stack
filter timestamp {"$(Get-Date -Format HH:mm:ss.ffff): $_"}


function Log-Info
{
    Param ($Message)

    if ($Message.GetType().Name -eq "String")
    {
        $Message = "[INFO] " + $Message | timestamp
    }
    $Message | Tee-Object -FilePath $Global:TxtLogFile -Append
    Log-JSONReport $Message
} 

function Log-Error
{
    Param ([string] $Message)

    $Message = "[ERR] " + $Message | timestamp
    $Message | Tee-Object -FilePath $Global:TxtLogFile -Append
    Log-JSONReport $Message
}

function Log-Exception
{
    Param ([string] $Message)

    $Message = "[EXCEPTION] " + $Message | timestamp
    $Message | Tee-Object -FilePath $Global:TxtLogFile -Append
    Log-JSONReport $Message
}

function Log-JSONReport
{
    param (
        [string] $Message
    )
    if ($Message)
    {
        if ($Message.Contains(": ["))
        {
            $time = $Message.Substring(0, $Message.IndexOf(": ["))
        }    
        if ($Message.Contains("[START]"))
        {
            $name = $Message.Substring($Message.LastIndexOf(":") + 1).Trim().Replace("######", "").Trim()
            if ($UseCaseStack.Count)
            {
                $nestedUseCase = @{
                "Name" = $name
                "StartTime" = $time
                }
                if (-not $UseCaseStack.Peek().UseCase)
                {
                    $UseCaseStack.Peek().Add("UseCase", @())
                }
                $UseCaseStack.Peek().UseCase += , $nestedUseCase
                $UseCaseStack.Push($nestedUseCase)
            }
            else
            {
                $CurrentUseCase.Add("Name", $name)
                $CurrentUseCase.Add("StartTime", $time)
                $UseCaseStack.Push($CurrentUseCase)
            }
        }
        elseif ($Message.Contains("[END]"))
        {
            $result = ""            
            if ($UseCaseStack.Peek().UseCase -and ($UseCaseStack.Peek().UseCase | Where-Object {$_.Result -eq "FAIL"}))
            {
                $result = "FAIL" 
            }
            else
            {
                $result = $Message.Substring($Message.LastIndexOf("=") + 1).Trim().Replace("] ######", "").Trim()
            }
            $UseCaseStack.Peek().Add("Result", $result)
            $UseCaseStack.Peek().Add("EndTime", $time)            
            $UseCaseStack.Pop() | Out-Null
            if (-not $UseCaseStack.Count)
            {
                $jsonReport = ConvertFrom-Json (Get-Content -Path $Global:JSONLogFile -Raw)
                $jsonReport.UseCases += , $CurrentUseCase
                $jsonReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $Global:JSONLogFile
                $CurrentUseCase.Clear()
            }
        }
        elseif ($Message.Contains("[DESCRIPTION]"))
        {
            $description = $Message.Substring($Message.IndexOf("[DESCRIPTION]") + "[DESCRIPTION]".Length).Trim()
            $UseCaseStack.Peek().Add("Description", $description)
        }
        elseif ($Message.Contains("[EXCEPTION]"))
        {
            $exception = $Message.Substring($Message.IndexOf("[EXCEPTION]") + "[EXCEPTION]".Length).Trim()
            $UseCaseStack.Peek().Add("Exception", $exception)
        }
    }
}

function Get-CanaryResult
{    
    $logContent = Get-Content -Raw -Path $Global:JSONLogFile | ConvertFrom-Json
    Log-Info ($logContent.UseCases | Format-Table -AutoSize @{Expression = {$_.Name}; Label = "Name"; Align = "Left"}, 
                                                            @{Expression = {$_.Result}; Label="Result"; Align = "Left"}, 
                                                            @{Expression = {((Get-Date $_.EndTime) - (Get-Date $_.StartTime)).TotalSeconds}; Label = "Duration`n[Seconds]"; Align = "Left"},
                                                            @{Expression = {$_.Description}; Label = "Description"; Align = "Left"})                                                    
}

function Get-CanaryLonghaulResult
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath
    )

    $logFiles = (Get-ChildItem -Path $LogPath -Filter *.JSON -File).FullName
    $logContent = @()
    foreach($file in $logFiles)
    {
        $logContent += (Get-Content -Raw -Path $file | ConvertFrom-Json).UseCases
    }
    $usecasesGroup = $logContent | Group-Object -Property Name
    $usecasesGroup | Format-Table -AutoSize @{Expression = {$_.Name}; Label = "Name"; Align = "Left"},
                                            @{Expression={$_.Count}; Label="Count"; Align = "Left"},
                                            @{Expression={$passPct = [math]::Round(((($_.Group | Where-Object Result -eq "PASS" | Measure-Object).Count/$_.Count)*100), 0); $passPct.ToString()+"%"};Label="Pass`n[Goal: >99%]"; Align = "Left"},    
                                            @{Expression={[math]::Round(($_.Group | Where-Object Result -eq "PASS" | ForEach-Object {((Get-Date $_.EndTime) - (Get-Date $_.StartTime)).TotalMilliseconds} | Measure-Object -Minimum).Minimum, 0)};Label="MinTime`n[msecs]"; Align = "Left"},
                                            @{Expression={[math]::Round(($_.Group | Where-Object Result -eq "PASS" | ForEach-Object {((Get-Date $_.EndTime) - (Get-Date $_.StartTime)).TotalMilliseconds} | Measure-Object -Maximum).Maximum, 0)};Label="MaxTime`n[msecs]"; Align = "Left"},
                                            @{Expression={[math]::Round(($_.Group | Where-Object Result -eq "PASS" | ForEach-Object {((Get-Date $_.EndTime) - (Get-Date $_.StartTime)).TotalMilliseconds} | Measure-Object -Average).Average, 0)};Label="AvgTime`n[msecs]"; Align = "Left"},
                                            @{Expression={$pCount = ($_.Group | Where-Object Result -eq "PASS").Count; $times = ($_.Group | Where-Object Result -eq "PASS" | ForEach-Object {((Get-Date $_.EndTime) - (Get-Date $_.StartTime)).TotalMilliseconds}); $avgTime = ($times | Measure-Object -Average).Average; $sd = 0; foreach ($time in $times){$sd += [math]::Pow(($time - $avgTime), 2)}; [math]::Round([math]::Sqrt($sd/$pCount), 0)};Label="StdDev"; Align = "Left"},
                                            @{Expression={$pCount = ($_.Group | Where-Object Result -eq "PASS").Count; $times = ($_.Group | Where-Object Result -eq "PASS" | ForEach-Object {((Get-Date $_.EndTime) - (Get-Date $_.StartTime)).TotalMilliseconds}); $avgTime = ($times | Measure-Object -Average).Average; $sd = 0; foreach ($time in $times){$sd += [math]::Pow(($time - $avgTime), 2)}; [math]::Round(([math]::Round([math]::Sqrt($sd/$pCount), 0)/$avgTime), 0) * 100};Label="RelativeStdDev`n[Goal: <50%]"; Align = "Left"}
}

function Start-Scenario
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [parameter(Mandatory=$false, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Type,
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$LogFilename,
        [parameter(Mandatory=$false)]
        [bool] $ContinueOnFailure = $false
    )

    if ($LogFileName)
    {
        if ($fileExtension = [IO.Path]::GetExtension($LogFileName))
        {
            $Global:JSONLogFile = $LogFileName.Replace($fileExtension, ".JSON")
            $Global:TxtLogFile = $LogFileName   
        }        
        else 
        {
            $Global:JSONLogFile = $LogFileName + ".JSON"
            $Global:TxtLogFile = $LogFileName + ".Log"               
        }        
    }
    if ($Global:wttLogFileName)
    {
        OpenWTTLogger $Global:wttLogFileName    
    }
    
    New-Item -Path $Global:JSONLogFile -Type File -Force
    New-Item -Path $Global:TxtLogFile -Type File -Force
    $jsonReport = @{
    "Scenario" = ($Name + "-" + $Type)
    "UseCases" = @()
    }    
    $jsonReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $Global:JSONLogFile
    $Global:ContinueOnFailure = $ContinueOnFailure
}

function End-Scenario
{
    if ($Global:wttLogFileName)
    {
        CloseWTTLogger    
    }
}

function Invoke-Usecase
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [parameter(Mandatory=$false, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Description, 
        [parameter(Mandatory=$true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock]$UsecaseBlock    
    )
    Log-Info ("###### [START] Usecase: $Name ######`n") 
    if ($Global:wttLogFileName)
    {
        StartTest "CanaryGate:$Name"
    }

    if ($Description)
    {
        Log-Info ("[DESCRIPTION] $Description`n")        
    }

    try
    {
        $result = Invoke-Command -ScriptBlock $UsecaseBlock
        if ($result -and (-not $UsecaseBlock.ToString().Contains("Invoke-Usecase")))
        {
            Log-Info ($result)
        }
        if ($Global:wttLogFileName)
        {
            EndTest "CanaryGate:$Name" $true
        }
        Log-Info ("###### [END] Usecase: $Name ###### [RESULT = PASS] ######`n")
        return $result | Out-Null
    }
    catch [System.Exception]
    {        
        Log-Exception ($_.Exception)
        Log-Info ("###### <FAULTING SCRIPTBLOCK> ######")
        Log-Info ("$UsecaseBlock")
        Log-Info ("###### </FAULTING SCRIPTBLOCK> ######")
        Log-Error ("###### [END] Usecase: $Name ###### [RESULT = FAIL] ######`n")
        if ($Global:wttLogFileName)
        {
            EndTest "CanaryGate:$Name" $false
        }
        if (-not $Global:ContinueOnFailure)
        {
            throw $_.Exception
        }
    }
}

function GetAzureStackEndpoints
{
    [CmdletBinding()]
    param( 
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$EnvironmentDomainFQDN,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArmEndpoint

    ) 

    $aadTenantId    = $AADTenantId
    $endptres = Invoke-RestMethod "${armEndpoint}/metadata/endpoints?api-version=1.0" -ErrorAction Stop    
    $ActiveDirectoryEndpoint = $($endptres.authentication.loginEndpoint).TrimEnd("/") + "/"
    $ActiveDirectoryServiceEndpointResourceId = $($endptres.authentication.audiences[0])
    $ResourceManagerEndpoint = $armEndpoint
    $GalleryEndpoint = $endptres.galleryEndpoint
    $GraphEndpoint = $endptres.graphEndpoint
    $AzureKeyVaultDnsSuffix="vault.$EnvironmentDomainFQDN".ToLowerInvariant()
    $AzureKeyVaultServiceEndpointResourceId= $("https://vault.$EnvironmentDomainFQDN".ToLowerInvariant()) 
    $StorageEndpointSuffix = $EnvironmentDomainFQDN

    $asEndpointsObj = New-Object -TypeName PSObject
    $asEndpointsObj | Add-Member -Type NoteProperty  -TypeName System.Management.Automation.PSCustomObject -Name ActiveDirectoryEndpoint -Value $ActiveDirectoryEndpoint
    $asEndpointsObj | Add-Member -Type NoteProperty  -TypeName System.Management.Automation.PSCustomObject -Name ActiveDirectoryServiceEndpointResourceId -Value $ActiveDirectoryServiceEndpointResourceId
    $asEndpointsObj | Add-Member -Type NoteProperty  -TypeName System.Management.Automation.PSCustomObject -Name ResourceManagerEndpoint -Value $ResourceManagerEndpoint
    $asEndpointsObj | Add-Member -Type NoteProperty  -TypeName System.Management.Automation.PSCustomObject -Name GalleryEndpoint -Value $GalleryEndpoint
    $asEndpointsObj | Add-Member -Type NoteProperty  -TypeName System.Management.Automation.PSCustomObject -Name GraphEndpoint -Value $GraphEndpoint
    $asEndpointsObj | Add-Member -Type NoteProperty  -TypeName System.Management.Automation.PSCustomObject -Name StorageEndpointSuffix -Value $StorageEndpointSuffix
    $asEndpointsObj | Add-Member -Type NoteProperty  -TypeName System.Management.Automation.PSCustomObject -Name AzureKeyVaultDnsSuffix -Value $AzureKeyVaultDnsSuffix
    $asEndpointsObj | Add-Member -Type NoteProperty  -TypeName System.Management.Automation.PSCustomObject -Name AzureKeyVaultServiceEndpointResourceId -Value $AzureKeyVaultServiceEndpointResourceId

    return $asEndpointsObj
}

function NewSubscriptionsQuota
{
    [CmdletBinding()]
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

function NewStorageQuota
{
    [CmdletBinding()]
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

    $quotaName                  = "ascanarystoragequota"
    $capacityInGb               = 1000
    $numberOfStorageAccounts    = 200
    $ApiVersion                 = "2015-12-01-preview"

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Storage.Admin/locations/{2}/quotas/{3}?api-version={4}" -f $AdminUri, $SubscriptionId, $ArmLocation, $quotaName, $ApiVersion
    $RequestBody = @"
    {
        "name":"$quotaName",
        "location":"$ArmLocation",
        "properties": { 
            "capacityInGb": $capacityInGb, 
            "numberOfStorageAccounts": $numberOfStorageAccounts
        }
    }
"@
    $headers = @{ "Authorization" = "Bearer "+ $AzureStackToken }
    $storageQuota = Invoke-RestMethod -Method Put -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $headers
        
    $storageQuota.Id        
}

function NewComputeQuota
{
    [CmdletBinding()]
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

    $quotaName      = "ascanarycomputequota"
    $vmCount        = 100
    $memoryLimitMB  = 102400
    $coresLimit     = 100
    $ApiVersion     = "2015-12-01-preview"

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Compute.Admin/locations/{2}/quotas/{3}?api-version={4}" -f $AdminUri, $SubscriptionId, $ArmLocation, $quotaName, $ApiVersion
    $RequestBody = @"
    {
        "name":"$quotaName",
        "type":"Microsoft.Compute.Admin/quotas",
        "location":"$ArmLocation",
        "properties":{
            "virtualMachineCount":$vmCount,
            "memoryLimitMB":$memoryLimitMB,
            "coresLimit":$coresLimit
        }
    }
"@
    $headers = @{ "Authorization" = "Bearer "+ $AzureStackToken }
    $computeQuota = Invoke-RestMethod -Method Put -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $headers
        
    $computeQuota.Id        
}

function NewNetworkQuota
{
    [CmdletBinding()]
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

    $quotaName                      = "ascanarynetworkquota"
    $publicIpsPerSubscription       = 50
    $vNetsPerSubscription           = 50
    $gatewaysPerSubscription        = 1
    $connectionsPerSubscription     = 2
    $loadBalancersPerSubscription   = 50
    $nicsPerSubscription            = 100
    $securityGroupsPerSubscription  = 50
    $ApiVersion                     = "2015-06-15"
    
    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Network.Admin/locations/{2}/quotas/{3}?api-version={4}" -f $AdminUri, $SubscriptionId, $ArmLocation, $quotaName, $ApiVersion
    $id = "/subscriptions/{0}/providers/Microsoft.Network.Admin/locations/{1}/quotas/{2}" -f  $SubscriptionId, $ArmLocation, $quotaName
    $RequestBody = @"
    {
        "id":"$id",
        "name":"$quotaName",
        "type":"Microsoft.Network.Admin/quotas",
        "location":"$ArmLocation",
        "properties":{
            "maxPublicIpsPerSubscription":$publicIpsPerSubscription,
            "maxVnetsPerSubscription":$vNetsPerSubscription,
            "maxVirtualNetworkGatewaysPerSubscription":$gatewaysPerSubscription,
            "maxVirtualNetworkGatewayConnectionsPerSubscription":$connectionsPerSubscription,
            "maxLoadBalancersPerSubscription":$loadBalancersPerSubscription,
            "maxNicsPerSubscription":$nicsPerSubscription,
            "maxSecurityGroupsPerSubscription":$securityGroupsPerSubscription,
        }
    }
"@
    $headers = @{ "Authorization" = "Bearer "+ $AzureStackToken}
    $networkQuota = Invoke-RestMethod -Method Put -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $headers
        
    $networkQuota.Id       
}

function NewKeyVaultQuota
{
    [CmdletBinding()]
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

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Keyvault.Admin/locations/{2}/quotas?api-version=2017-02-01-preview" -f $AdminUri, $SubscriptionId, $ArmLocation
    $headers = @{ "Authorization" = "Bearer "+ $AzureStackToken }
    $kvQuota = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType 'application/json' -ErrorAction Stop
        
    $kvQuota.Value.Id
}

function NewAzureStackToken
{
    [CmdletBinding()]
    param(         
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$AADTenantID, 
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$EnvironmentDomainFQDN,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]$Credentials,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArmEndpoint

    )
    
    $endpoints = GetAzureStackEndpoints -EnvironmentDomainFQDN $EnvironmentDomainFQDN -ArmEndPoint $ArmEndpoint
    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    
    $contextAuthorityEndpoint = ([System.IO.Path]::Combine($endpoints.ActiveDirectoryEndpoint, $AADTenantID)).Replace('\','/')
    $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($contextAuthorityEndpoint, $false)
    $userCredential = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential($Credentials.UserName, $Credentials.Password)
    return ($authContext.AcquireToken($endpoints.ActiveDirectoryServiceEndpointResourceId, $clientId, $userCredential)).AccessToken  
}

function NewAzureStackDefaultQuotas
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceLocation,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionId,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$AADTenantID, 
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$EnvironmentDomainFQDN,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]$Credentials,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArmEndpoint
    ) 

    $aadTenantId    = $AADTenantId
    $serviceQuotas  = @()
    $asToken = NewAzureStackToken -AADTenantId $AADTenantId -EnvironmentDomainFQDN $EnvironmentDomainFQDN -Credentials $Credentials -ArmEndpoint $ArmEndpoint
    #$serviceQuotas += NewSubscriptionsQuota -AdminUri $armEndpoint -SubscriptionId $SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation
    $serviceQuotas += NewStorageQuota -AdminUri $armEndPoint -SubscriptionId $SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation
    $serviceQuotas += NewComputeQuota -AdminUri $armEndPoint -SubscriptionId $SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation
    $serviceQuotas += NewNetworkQuota -AdminUri $armEndPoint -SubscriptionId $SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation
    $serviceQuotas += NewKeyVaultQuota -AdminUri $armEndPoint -SubscriptionId $SubscriptionId -AzureStackToken $asToken -ArmLocation $ResourceLocation
    
    $serviceQuotas    
}

function NewAzureStackDSCScriptResource
{
    [CmdletBinding()]
    param( 
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DSCScriptResourceName,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath,
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$DSCScript     
    )

    if (-not $DSCScript)
    {
        $DSCScript = "Configuration ASCheckNetworkConnectivityUtil 
        {    
            Node localhost 
            {
                Script TestNetworkConnectivity 
                {
                    SetScript = {
                        Test-NetConnection -ComputerName www.microsoft.com -InformationLevel Detailed         
                    }
                    GetScript = { @{} }
                    TestScript = { `$false }
                }
                LocalConfigurationManager 
                {
                    ConfigurationMode = 'ApplyOnly'
                    RebootNodeIfNeeded = `$false
                }
            }
        }"
    }
    if (-not (Test-Path -Path $DestinationPath))
    {
        New-Item -Path $DestinationPath -ItemType Directory -Force
    }
    $destinationDSCScriptPath = Join-Path -Path $DestinationPath -ChildPath $DSCScriptResourceName
    $DSCScript | Out-File -FilePath $destinationDSCScriptPath -Encoding utf8 -ErrorAction Stop
    $dscZipPath = Join-Path -Path ($DestinationPath | Split-Path) -ChildPath "DSCResource.ZIP"
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
    $ZipLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory($DestinationPath, $dscZipPath, $ZipLevel, $false)  

    $dscZipPath   
}

function NewAzureStackCustomScriptResource
{
    [CmdletBinding()]
    param( 
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$CustomScriptResourceName,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath,
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$CustomScript     
    )

    if (-not $CustomScript)
    {
        $CustomScript = "Write-Output `"Disable firewall`"
                        netsh advfirewall set privateprofile state off;

                        Set-WSManQuickConfig -Force
                        winrm quickconfig -q -force
                        Set-NetFirewallRule -DisplayName `"Windows Remote Management (HTTP-In)`" -Profile `"Public`" -Action `"Allow`" -RemoteAddress `"Any`" -Confirm:`$false

                        Write-Output `"Checking for data disks on the VM`"
                        `$dataDisks = Get-Disk | Where-Object {(-not(`$_.IsBoot)) -and (-not(`$_.IsSystem))}

                        if (`$dataDisks) 
                        {
                            Write-Output `"Found data disk(s) attached to the VM`" | Tee-Object -FilePath (`$env:USERPROFILE + `"\CheckDataDiskUtil.log`")
                            `$dataDisks | Select Number, FriendlyName | Format-Table -AutoSize | Tee-Object -FilePath (`$env:USERPROFILE + `"\CheckDataDiskUtil.log`")
                        }
                        else
                        {
                            `"Found no data disk(s) attached to the VM`" | Out-File -FilePath (`$env:USERPROFILE + `"\CheckDataDiskUtil.log`") 
                            Write-Error `"Found no data disk(s) attached to the VM`"
                        }"
    }
    if (-not (Test-Path -Path $DestinationPath))
    {
        New-Item -Path $DestinationPath -ItemType Directory -Force
    }
    $destinationCustomScriptPath = Join-Path -Path $DestinationPath -ChildPath $CustomScriptResourceName
    $CustomScript | Out-File -FilePath $destinationCustomScriptPath -Encoding utf8 -ErrorAction Stop 

    $destinationCustomScriptPath    
}

function NewAzureStackDataVHD
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$VHDSizeInGB
    )

    $vhdSizeInBytes = $VHDSizeInGB * 1024
    $tmpPath = Split-Path -Path $FilePath
    "CREATE VDISK FILE=`"$FilePath`" MAXIMUM=$vhdSizeInBytes" | Out-File -FilePath "$tmpPath\CreateASDataDisk.txt" -Encoding ascii
    cmd /c diskpart /s "$tmpPath\CreateASDataDisk.txt"

    if (Test-Path $FilePath)
    {
        Remove-Item -Path "$tmpPath\CreateASDataDisk.txt" -Force
    }
    else 
    {
        throw [System.Exception]"Failed to create the VHD file"    
    }

    return $FilePath        
}

function GetAzureStackBlobUri
{
    [CmdletBinding()]
    param(        
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$BlobContent,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$StorageAccountName,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$StorageContainerName
    )

    try 
    {
        if (-not (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName))
        {
            throw [System.Exception]"Storage account $StorageAccountName does not exist"
        }
        $asStorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
        if ($asStorageAccountKey)
        {
            $storageAccountKey = $asStorageAccountKey.Key1
        }
        $asStorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey -ErrorAction Stop
        if (-not ($blobUri = (Get-AzureStorageBlob  -Blob $BlobContent -Container $StorageContainerName -Context $asStorageContext -ErrorAction Stop).ICloudBlob.uri.AbsoluteUri))
        {
            throw [System.Exception]"Failed to retrieve the blob content Uri"
        }

        return $blobUri        
    }
    catch [System.Exception] 
    {
        throw $_.Exception.Message    
    }
}

function DownloadFile
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String] $FileUrl,
        [Parameter(Mandatory=$true)]
        [String] $OutputFolder
    )
    $retries = 20
    $lastException = $null
    $success = $false
    
    while($success -eq $false -and $retries -ge 0)
    {
        $success = $true
        try 
        {
            $outputFile = Join-Path $OutputFolder (Split-Path -Path $FileUrl -Leaf)
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($FileUrl, $outputFile) | Out-Null
        }
        catch
        {
            $success = $false            
            $lastException = $_
        }
        $retries--
        if($success -eq $false)
        {
            Start-Sleep -Seconds 10                        
        }
    }

    if($success -eq $false)
    {
        Write-Output "Timed out trying to download $FileUrl"
        throw $lastException
    }

    return $outputFile
}

function CopyImage
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String] $ImagePath,
        [Parameter(Mandatory=$true)]
        [String] $OutputFolder
    )

    if (Test-Path $ImagePath)
    {
        Copy-Item $ImagePath $OutputFolder
        $outputfile = Join-Path $OutputFolder (Split-Path $ImagePath -Leaf)
    }
    elseif ($ImagePath.StartsWith("http"))
    {
        $outputfile = DownloadFile -FileUrl $ImagePath -OutputFolder $OutputFolder
    }
    if (([System.IO.FileInfo]$outputfile).Extension -eq ".zip")
    {
        Expand-Archive -Path $outputfile -DestinationPath $OutputFolder -Force   
    }

    return (Get-ChildItem -Path $OutputFolder -File | Where-Object {$_.Extension -eq ".vhd" -or $_.Extension -eq ".vhdx"})[0].FullName
}

# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU3fMEflwx+eQnUKlXJt9y2MRq
# P5GgghhlMIIEwzCCA6ugAwIBAgITMwAAAMlkTRbbGn2zFQAAAAAAyTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODU0
# WhcNMTgwOTA3MTc1ODU0WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkIxQjctRjY3Ri1GRUMyMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAotVXnfm6iRvJ
# s2GZXZXB2Jr9GoHX3HNAOp8xF/cnCE3fyHLwo1VF+TBQvObTTbxxdsUiqJ2Ew8DL
# jW8dolC9WqrPuP9Wj0gJNAdhnAYjtZN5fYEoGIsHBtuR3k+UxD2W7VWfjPDTY2zH
# e44WzfDvL2aXL2fomH73B7cx7YjT/7Du7vSdAHbr7SEdIyGJ5seMa+Y9MBJI48wZ
# A9CSnTGTFvhMXCYJuoR6Xc34A0EdHiTzfxY2tEWSiw5Xr+Oottc4IIHksNttYMgw
# HCu+tKqUlDkq5EdELh067r2Mv+OVkUkDQnLd1Vh/bP+yz92NKw7THQDYN7/4MTD2
# faNVsutryQIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFB7ZK3kpWqMOy6M4tybE49oI
# BMpsMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBACvoEvJ84B3DuFj+SDfpkM3OCxYon2F4wWTOQmpDmTwysrQ0
# grXhxNqMVL7QRKk34of1uvckfIhsjnckTjkaFJk/bQc8n5wwTzCKJ3T0rV/Vasoh
# MbGm4y3UYEh9nflmKbPpNhps20EeU9sdNIkxsrpQsPwk59wv13STtUjywuTvpM5s
# 1dQOIiUWrAMR14ZzOSBA7kgWI+UEj5iaGYOczxD+wH+07llzwlIC4TyRXtgKFuMF
# AONNNYUedbi6oOX7IPo0hb5RVPuVqAFxT98xIheJXNod9lf2JLhGD+H/pXnkZJRr
# VjJFcuJeEAnYAe7b97+BfhbPgv8V9FIAwqTxgxIwggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TCCBhEwggP5
# oAMCAQICEzMAAACOh5GkVxpfyj4AAAAAAI4wDQYJKoZIhvcNAQELBQAwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xNjExMTcyMjA5MjFaFw0xODAy
# MTcyMjA5MjFaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQh9RCK36d2cZ61KLD4xWS
# 0lOdlRfJUjb6VL+rEK/pyefMJlPDwnO/bdYA5QDc6WpnNDD2Fhe0AaWVfIu5pCzm
# izt59iMMeY/zUt9AARzCxgOd61nPc+nYcTmb8M4lWS3SyVsK737WMg5ddBIE7J4E
# U6ZrAmf4TVmLd+ArIeDvwKRFEs8DewPGOcPUItxVXHdC/5yy5VVnaLotdmp/ZlNH
# 1UcKzDjejXuXGX2C0Cb4pY7lofBeZBDk+esnxvLgCNAN8mfA2PIv+4naFfmuDz4A
# lwfRCz5w1HercnhBmAe4F8yisV/svfNQZ6PXlPDSi1WPU6aVk+ayZs/JN2jkY8fP
# AgMBAAGjggGAMIIBfDAfBgNVHSUEGDAWBgorBgEEAYI3TAgBBggrBgEFBQcDAzAd
# BgNVHQ4EFgQUq8jW7bIV0qqO8cztbDj3RUrQirswUgYDVR0RBEswSaRHMEUxDTAL
# BgNVBAsTBE1PUFIxNDAyBgNVBAUTKzIzMDAxMitiMDUwYzZlNy03NjQxLTQ0MWYt
# YmM0YS00MzQ4MWU0MTVkMDgwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1
# ApUwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEF
# BQcBAQRVMFMwUQYIKwYBBQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNV
# HRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBEiQKsaVPzxLa71IxgU+fKbKhJ
# aWa+pZpBmTrYndJXAlFq+r+bltumJn0JVujc7SV1eqVHUqgeSxZT8+4PmsMElSnB
# goSkVjH8oIqRlbW/Ws6pAR9kRqHmyvHXdHu/kghRXnwzAl5RO5vl2C5fAkwJnBpD
# 2nHt5Nnnotp0LBet5Qy1GPVUCdS+HHPNIHuk+sjb2Ns6rvqQxaO9lWWuRi1XKVjW
# kvBs2mPxjzOifjh2Xt3zNe2smjtigdBOGXxIfLALjzjMLbzVOWWplcED4pLJuavS
# Vwqq3FILLlYno+KYl1eOvKlZbiSSjoLiCXOC2TWDzJ9/0QSOiLjimoNYsNSa5jH6
# lEeOfabiTnnz2NNqMxZQcPFCu5gJ6f/MlVVbCL+SUqgIxPHo8f9A1/maNp39upCF
# 0lU+UK1GH+8lDLieOkgEY+94mKJdAw0C2Nwgq+ZWtd7vFmbD11WCHk+CeMmeVBoQ
# YLcXq0ATka6wGcGaM53uMnLNZcxPRpgtD1FgHnz7/tvoB3kH96EzOP4JmtuPe7Y6
# vYWGuMy8fQEwt3sdqV0bvcxNF/duRzPVQN9qyi5RuLW5z8ME0zvl4+kQjOunut6k
# LjNqKS8USuoewSI4NQWF78IEAA1rwdiWFEgVr35SsLhgxFK1SoK3hSoASSomgyda
# Qd691WZJvAuceHAJvDCCB3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEx
# MB4XDTExMDcwODIwNTkwOVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUg
# U2lnbmluZyBQQ0EgMjAxMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AKvw+nIQHC6t2G6qghBNNLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL
# 8DjCmQawyDnVARQxQtOJDXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/X
# llnKYBoF6WZ26DJSJhIv56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5k
# NXimoGMPLdNAk/jj3gcN1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJ
# Xtjt7UORg9l7snuGG9k+sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4
# ftKdgCz1TlaRITUlwzluZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgo
# tswnKDglmDlKNs98sZKuHCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0Xpb
# L9Uj43BdD1FGd7P4AOG8rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy
# 5yTfv0aZxe/CHFfbg43sTUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9
# Z4DmimJ4X7IvhNdXnFy/dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4
# IFgsE11glZo+TzOE2rCIF96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQ
# BgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUw
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0f
# BFMwUTBPoE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcB
# AQRSMFAwTgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kv
# Y2VydHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGX
# MIGUMIGRBgkrBgEEAYI3LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcC
# AjA0HjIgHQBMAGUAZwBhAGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUA
# bgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFj
# kplCln3SeQyQwWVfLiw++MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtG
# UFXYDJJ80hpLHPM8QotS0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32m
# kHSDjfTLJgJGKsKKELukqQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr
# 3vw70L01724lruWvJ+3Q3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYK
# wsatruWy2dsViFFFWDgycScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6C
# PxNNZgvAs0314Y9/HG8VfUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX
# 0O5dY0HjWwechz4GdwbRBrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADW
# oUa9WfOXpQlLSBCZgB/QACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9r
# t0uX4ut1eBrs6jeZeRhL/9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGd
# Vk5Pv4BXIqF4ETIheu9BCrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9
# bW1qyVJzEw16UM0xggTlMIIE4QIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5n
# IFBDQSAyMDExAhMzAAAAjoeRpFcaX8o+AAAAAACOMAkGBSsOAwIaBQCggfkwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFKbEU/72uxmVpr47g7MYPXqSKEdjMIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEAJ7e4OyEPu22+uRwcIsWqZBP1K/5VsEbH
# Ne8Dp1Q12veQ06snPLi6zneDn9+J27LAhfRug4CMZGzFolhY83d/VwpL29FLh7Ui
# 3yBUIKoN9wJwo9C72yqhB2zMMWhsifFqOsjVb2Q4vKKQpUfkeLlfoqF9g0rb2698
# a9UhLAW47n7Gsf1pLImUhT/bJxIYovV+peQ/ugTEwmStBphxfxXYk5ofc8tVeHSW
# 5iFtrWy0NZp8pYO+5JNNmGRSCJh88v0JlvgPDVcsNuOV3zs7w35vkvsBxbJBl2m3
# Ji6PYx4Tt1BDfSokzErebzGVQ+eV6jzIuMqVAt6lKUJ8AtJeYDQuGaGCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADJZE0W2xp9sxUAAAAAAMkwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxNlowIwYJ
# KoZIhvcNAQkEMRYEFOe7rVaRWK6IUN9kbAvr4/a2IioUMA0GCSqGSIb3DQEBBQUA
# BIIBAJig3BYMBeDdIavXWiL+zEinbg6Lt1rbxI6N0FiXJRZmJEV6yVMcxlHyOYz6
# jFXRqoXOtas3ZY7+yNusyJx9I6bwJvHSfZGVXa0QFGvsaP3B70blia3q0owL5zTm
# 1MbCNAo0erhjZzLNAPAsUOxm5DCGTdpC4ER3++cYtiVCL3e5Kl4ag+6frdb9K4fe
# D0immS8z113Z3v0xVTbEVa70gTpKKkNzIvVjBt225+9hLviNSdOrdDTX/8zuW/tp
# 6VtHyKj0OZLM2TqKQO5i3yrIVO/ks9+QD/E3HdzlMs81V94lRrLFUYJ8EUlWuO4S
# BETnPH+bcPv/qtvkBkqWOlt0FrU=
# SIG # End signature block
