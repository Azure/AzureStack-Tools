$Global:ContinueOnFailure = $false
$Global:JSONLogFile  = "Run-Canary.JSON"
$Global:TxtLogFile  = "AzureStackCanaryLog.Log"
$UseCase = @{}
[System.Collections.Stack] $AllUseCases = New-Object System.Collections.Stack
filter timestamp {"$(Get-Date -Format G): $_"}

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
            if ($AllUseCases.Count)
            {
                $nestedUseCase = @{
                "Name" = $name
                "StartTime" = $time
                }
                if (-not $AllUseCases.Peek().UseCase)
                {
                    $AllUseCases.Peek().Add("UseCase", @())
                }
                $AllUseCases.Peek().UseCase += , $nestedUseCase
                $AllUseCases.Push($nestedUseCase)
            }
            else
            {
                $UseCase.Add("Name", $name)
                $UseCase.Add("StartTime", $time)
                $AllUseCases.Push($UseCase)
            }
        }
        elseif ($Message.Contains("[END]"))
        {
            $result = $Message.Substring($Message.LastIndexOf("=") + 1).Trim().Replace("] ######", "").Trim()
            $AllUseCases.Peek().Add("EndTime", $time)
            $AllUseCases.Peek().Add("Result", $result)
            $AllUseCases.Pop() | Out-Null
            if (-not $AllUseCases.Count)
            {
                $jsonReport = ConvertFrom-Json (Get-Content -Path $Global:JSONLogFile -Raw)
                $jsonReport.UseCases += , $UseCase
                $jsonReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $Global:JSONLogFile
                $UseCase.Clear()
            }
        }
        elseif ($Message.Contains("[DESCRIPTION]"))
        {
            $description = $Message.Substring($Message.IndexOf("[DESCRIPTION]") + "[DESCRIPTION]".Length).Trim()
            $AllUseCases.Peek().Add("Description", $description)
        }
        elseif ($Message.Contains("[EXCEPTION]"))
        {
            $exception = $Message.Substring($Message.IndexOf("[EXCEPTION]") + "[EXCEPTION]".Length).Trim()
            $AllUseCases.Peek().Add("Exception", $exception)
        }
    }
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
{}

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

        Log-Info ("###### [END] Usecase: $Name ###### [RESULT = PASS] ######`n")
        return $result | Out-Null
    }
    catch [System.Exception]
    {        
        Log-Exception ($_.Exception)
        Log-Error ("###### [END] Usecase: $Name ###### [RESULT = FAIL] ######`n")
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
        [string]$EnvironmentDomainFQDN      
    ) 

    $aadTenantId    = $AADTenantId
    $armEndpoint    = "https://api." + $EnvironmentDomainFQDN
    $endptres = Invoke-RestMethod "${armEndpoint}/metadata/endpoints?api-version=1.0" -ErrorAction Stop    
    $ActiveDirectoryEndpoint = $($endptres.authentication.loginEndpoint)
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
    $capacityInGb               = 100
    $numberOfStorageAccounts    = 20
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
    $vmCount        = 10
    $memoryLimitMB  = 10240
    $coresLimit     = 10
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

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Keyvault.Admin/locations/{2}/quotas?api-version=2014-04-01-preview" -f $AdminUri, $SubscriptionId, $ArmLocation
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
        [System.Management.Automation.PSCredential]$Credentials
    )
    
    $endpoints = GetAzureStackEndpoints -EnvironmentDomainFQDN $EnvironmentDomainFQDN
    #$asToken = Get-AzureStackToken -Authority ($endpoints.ActiveDirectoryEndpoint  + $aadTenantId + "/oauth2") -Resource $endpoints.ActiveDirectoryServiceEndpointResourceId -AadTenantId $AADTenantID -Credential $Credentials -ErrorAction Stop
    $asToken = Get-AzureStackToken -Authority $endpoints.ActiveDirectoryEndpoint -Resource $endpoints.ActiveDirectoryServiceEndpointResourceId -AadTenantId $aadTenantId -Credential $Credentials -ErrorAction Stop
    return $asToken  
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
        [System.Management.Automation.PSCredential]$Credentials
    ) 

    $aadTenantId    = $AADTenantId
    $serviceQuotas  = @()
    $armEndpoint    = "https://api." + $EnvironmentDomainFQDN
    $asToken = NewAzureStackToken -AADTenantId $AADTenantId -EnvironmentDomainFQDN $EnvironmentDomainFQDN -Credentials $Credentials
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
