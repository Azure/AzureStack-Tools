function Connect-AzureAccount{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$AzureEnvironmentName
    )

    $isConnected = $false;

    try
    {
        $context = Get-AzureRmContext
        $environment = Get-AzureRmEnvironment -Name $AzureEnvironmentName
        $context.Environment = $environment
        if ($context.Subscription.SubscriptionId -eq $SubscriptionId)
        {
            $isConnected = $true;
        }
    }
    catch
    {
        Write-Warning "Not currently connected to Azure: `r`n$($_.Exception)"
    }

    if (-not $isConnected)
    {
        Add-AzureRmAccount -SubscriptionId $SubscriptionId
        $context = Get-AzureRmContext
    }

    $environment = Get-AzureRmEnvironment -Name $AzureEnvironmentName
    $subscription = Get-AzureRmSubscription -SubscriptionId $SubscriptionId

    $tokens = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()
    if (-not $tokens -or ($tokens.Count -le 0))
    {
        throw "Token cache is empty"
    }

    $token = $tokens |
        Where Resource -EQ $environment.ActiveDirectoryServiceEndpointResourceId |
        Where { $_.TenantId -eq $subscription.TenantId } |
        Where { $_.ExpiresOn -gt [datetime]::UtcNow } |
        Select -First 1

    if (-not $token)
    {
        throw "Token not found for tenant id $($subscription.TenantId) and resource $($environment.ActiveDirectoryServiceEndpointResourceId)."
    }

    return @{
        TenantId = $subscription.TenantId
        ManagementEndpoint = $environment.ResourceManagerUrl
        ManagementResourceId = $environment.ActiveDirectoryServiceEndpointResourceId
        Token = $token
    }
}

function Resolve-DomainAdminStatus{
[CmdletBinding()]
Param()
    try
    {
        Write-Verbose "Checking for user logged in as Domain Admin"
        $currentUser     = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($CurrentUser)
        $domain = Get-ADDomain
        $sid = "$($domain.DomainSID)-512"

        if($windowsPrincipal.IsInRole($sid))
        {
            Write-Verbose "Domain Admin check : ok"
        }    
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    {
        $message = "User is not logged in as a domain admin. registration has been cancelled."
        throw "$message `r`n$($_.Exception)"
    }
    catch
    {
        throw "Unexpected error while checking for domain admin: `r`n$($_.Exception)"
    }
}

function Initalize-PrivilegedJeaSession{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [String] $JeaComputerName,

    [Parameter(Mandatory=$true)]
    [PSCredential] $CloudAdminCredential
)
    $currentAttempt = 0
    $maxAttempts = 3
    $sleepSeconds = 10
    do
    {
        try
        {
            Write-Verbose "Initializing privileged JEA session. Attempt $currentAttempt of $maxAttempts"
            $session = New-PSSession -ComputerName $JeaComputerName -ConfigurationName PrivilegedEndpoint -Credential $CloudAdminCredential
            Write-Verbose "Connection to $JeaComputerName successful"
            return $session
        }
        catch
        {
            Write-Verbose "Creation of session with $JeaComputerName failed:`r`n$($_.Exception.Message)"
            Write-Verbose "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempts)
            {
                throw $_.Exception
            }
        }
    }while ($currentAttempt -lt $maxAttempts)
}

function Confirm-StampVersion{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [System.Management.Automation.Runspaces.PSSession] $PSSession
)
    try
    {
        Write-Verbose "Verifying stamp version."
        $stampInfo = Invoke-Command -Session $PSSession -ScriptBlock { Get-AzureStackStampInformation -WarningAction SilentlyContinue }
        $minVersion = [Version]"1.0.170626.1"
        if ([Version]$stampInfo.StampVersion -lt $minVersion) {
            Write-Error -Message "Script only applicable for Azure Stack builds $minVersion or later."
        }
        return $stampInfo
    }
    Catch
    {
        Write-Verbose "An error occurred checking stamp information: `r`n$($_.Exception)"        
    }
}