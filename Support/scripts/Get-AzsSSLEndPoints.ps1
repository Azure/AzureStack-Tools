<#
.SYNOPSIS
    Display certificate inventory for Public SSL EndPoints
.DESCRIPTION
    Probes SSL endpoints of an Azure Stack deployment to gather external certificate inventory. 
    It then displays certificate inventory for Public SSL EndPoints. 
    Endpoints not accessible will return blank information.
    User can optionally add ADFS, AppServices, SQLAdapter and MySQLAdapter.
    User can exclude certain endpoints also.
    SSL Endpoints tested are documented here: https://docs.microsoft.com/en-gb/azure/azure-stack/azure-stack-integrate-endpoints#ports-and-protocols-inbound
.EXAMPLE
    PS C:\> .\Get-AzsSSLEndPoints.ps1 -FQDN "east.azurestack.contoso.com"
    Seeds public endpoints with east.azurestack.contoso.com and attempts gather certificate inventory from each endpoint
.EXAMPLE
    PS C:\> .\Get-AzsSSLEndPoints.ps1 -FQDN "east.azurestack.contoso.com" -exclude adminvault
    Seeds public endpoints with east.azurestack.contoso.com and attempts gather certificate inventory from each endpoint, except adfs, graph and adminvault.
.EXAMPLE
    PS C:\> .\Get-AzsSSLEndPoints.ps1 -FQDN "east.azurestack.contoso.com" -UsePaaS -exclude AppServices
    Seeds public endpoints with east.azurestack.contoso.com and attempts gather certificate inventory from each endpoint includes PaaS endpoints except for AppServices.
.EXAMPLE
    PS C:\> .\Get-AzsSSLEndPoints.ps1 -FQDN "east.azurestack.contoso.com" -ExpiringInDays 30
    Seeds public endpoints with east.azurestack.contoso.com and attempts gather certificate inventory from each endpoint and only warns if expiry is in less than 30 days.
.PARAMETER FQDN
    String. Specifies FQDN (region.domain.com) of the AzureStack deployment.
.PARAMETER UseADFS
    Switch. Add ADFS and Graph services to be scanned
.PARAMETER UsePaaS
    Switch. Add PaaS services to be scanned
.PARAMETER exclude
    String Array. Specifies endpoints that should be skipped. 
    Valid (any/all) values 'adminportal','adminmanagement','queue','table','blob','adminvault','adfs','graph','mysqladapter','sqladapter','appservice' 
    Tenant facing services; portal, management and vault, cannot be excluded.  If these are not reachable the script will not error, but the output will be empty.
.PARAMETER ExpiringInDays
    Integer. Optional parameter for user defined threshold for expiration warning.
.PARAMETER PassThru
    Switch. Returns a custom object (PSCustomObject) that contains the test results.
.OUTPUTS
    PSCustomObject
.NOTES
    When checking wildcard endpoints, the script generates a random GUID to test against, this ensures uniqueness, the GUID is then replaced with 'certtest' so output to the screen is more tidy.
#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "Provide the FQDN for azure stack environment e.g. regionname.domain.com")]
    [string]
    $FQDN,
    [Parameter(Mandatory = $false, HelpMessage = "Provide number of days (default 90) warning for expiring certificates.")]
    [int]
    $ExpiringInDays = 90,
    [Parameter(Mandatory = $false, HelpMessage = "Include ADFS and Graph services")]
    [switch]
    $UseADFS,
    [Parameter(Mandatory = $false, HelpMessage = "Include PaaS services")]
    [switch]
    $UsePaaS,
    [Parameter(Mandatory = $false, HelpMessage = "Optionally remove services")]
    [ValidateSet('adminportal', 'adminmanagement', 'queue', 'table', 'blob', 'adminvault', 'adfs', 'graph', 'mysqladapter', 'sqladapter', 'appservice')]
    [string[]]
    $exclude,
    [Parameter(Mandatory = $false, HelpMessage = "Return PSObject")]
    [switch]
    $PassThru,
    [Parameter(Mandatory = $false, HelpMessage = "Include all ports")]
    [switch]
    $AllPorts
)

# endpoint data
if(!$AllPorts) {
    $allendPoints = @(
        443 | ForEach-Object {"adminportal.{0}:{1}" -f $FQDN, $PSITEM}
        443 | ForEach-Object {"portal.{0}:{1}" -f $FQDN, $PSITEM}
        443 | Foreach-Object {"management.{0}:{1}" -f $FQDN, $PSITEM}
        443 | Foreach-Object {"adminmanagement.{0}:{1}" -f $FQDN, $PSITEM}
    )
} else {
    $allendPoints = @(
        443,12495,12499,12646,12647,12648,12649,12650,13001,13003,13010,13011,13012,13020,13021,13026,30015 | ForEach-Object {"adminportal.{0}:{1}" -f $FQDN, $PSITEM}
        443,12495,12649,13001,13010,13011,13012,13020,13021,30015,13003 | ForEach-Object {"portal.{0}:{1}" -f $FQDN, $PSITEM}
        443,30024 | Foreach-Object {"management.{0}:{1}" -f $FQDN, $PSITEM}
        443,30024 | Foreach-Object {"adminmanagement.{0}:{1}" -f $FQDN, $PSITEM}
    )
}
$allendPoints += @(
    443 | Foreach-Object {"{0}.queue.{1}:{2}" -f (new-guid),$FQDN,$PSITEM}
    443 | Foreach-Object {"{0}.table.{1}:{2}" -f (new-guid),$FQDN,$PSITEM}
    443 | Foreach-Object {"{0}.blob.{1}:{2}" -f (new-guid),$FQDN,$PSITEM}
    "$(new-guid).vault.$FQDN"
    "$(new-guid).adminvault.$FQDN"
    443 | Foreach-Object {"{0}.hosting.{1}:{2}" -f (new-guid),$FQDN,$PSITEM}
    443 | Foreach-Object {"{0}.adminhosting.{1}:{2}" -f (new-guid),$FQDN,$PSITEM}
)

if ($UseADFS) {
    $allendPoints += @( 
        "adfs.$FQDN"
        "graph.$FQDN"
    )
}

if ($UsePaaS) {
    $allendPoints += @( 
        44300 | ForEach-Object {"mysqladapter.dbadapter.{0}:{1}" -f $FQDN,$PSITEM}
        44300 | ForEach-Object {"sqladapter.dbadapter.{0}:{1}" -f $FQDN,$PSITEM}
        44300 | ForEach-Object {"sqlrp.dbadapter.{0}:{1}" -f $FQDN,$PSITEM}
        "sso.appservice.$FQDN"
        443 | ForEach-Object {"$(new-guid).appservice.{0}:{1}" -f $FQDN, $PSITEM}
        "$(new-guid).scm.appservice.$FQDN"
        "$(new-guid).sso.appservice.$FQDN"
        443,44300 | ForEach-Object {"api.appservice.{0}:{1}" -f $FQDN, $PSITEM}
        443 | ForEach-Object {"$(new-guid).azsacr.{0}:{1}" -f $FQDN, $PSITEM}
    )
}

function Get-ThumbprintMask
{
    [cmdletbinding()]
    [OutputType([string])]
    Param ([Parameter(ValueFromPipelinebyPropertyName=$True)]$thumbprint)
    Begin
    {
        $thumbprintMasks = @()
    }
    Process
    {
        $thumbprintMasks += foreach ($thumb in $thumbprint)
        {
            try
            {
                if (($thumb.length - 12) -gt 0)
                {
                    $firstSix = $thumb.Substring(0,6)
                    $lastSix = $thumb.Substring(($thumb.length - 6),6)
                    $middleN = '*' * ($thumb.length - 12)
                    $thumbprintMask = '{0}{1}{2}' -f $firstSix,$middleN, $lastSix
                }
                else
                {
                    throw ("Error applying thumbprint mask from thumbprint starting with {0} and length of {1}" -f $thumbprint.Substring(0,10),$thumbprint.Length)
                }

            }
            catch
            {
                $_.exception
            }
            $thumbprintMask
        }
    }
    End
    {
        $thumbprintMasks -join ','
    }
}

function Test-CertificateReuse
{
    param ($results)

    # Here we are looking for duplicate thumbprints that are used on more than one fqdn
    if ($dups = $results | Where-Object { $null -ne $_.name -and $null -ne $_.thumbprint } | Group-Object thumbprint | Where-Object Count -gt 1 | Where-Object { $_.Group | Group-Object fqdn | Where-Object Count -eq 1 }) {
        Write-Host "`n"
        Write-Warning -Message "Certificate Reuse Detected. We recommend using separate certificates for each endpoint."
        foreach ($_dup in $dups)
        {
            $names = $_dup.Group.FQDN | Foreach-Object {$PSITEM.split(':')[0]} | Get-Unique
            Write-Host ("`nCertificate {0} is configured for use on the following endpoint(s): " -f $_dup.name)
            $names | Foreach-Object {Write-Host ("`t{0}" -f ($_ -replace 'testcert.'))}
        }
        Write-Host "`n"
    } else {
        Write-Host "`nNo Certificate Reuse Detected." -ForegroundColor Green
    }
}

#Function to display colour-coded table
function Write-Table {
    param ([Parameter(ValueFromPipeline = $True)]
        $object,
        [int]$padright = 15
    )
    
    process {
        foreach ($obj in $object) {
            Write-Host "`n"
            foreach ($key in $obj.PSObject.Properties.Name) {
                Write-Host ("{0}: " -f $key).PadRight($padright) -NoNewline
                Write-Host (": " -f $key) -NoNewline
                if ($obj.State -like 'EXPIRING') {
                    Write-Host ("   {0}" -f $obj.$key) -ForegroundColor Yellow
                }
                elseif ($obj.State -like 'EXPIRED') {
                    Write-Host ("   {0}" -f $obj.$key) -ForegroundColor Red
                }
                else {
                    Write-Host ("   {0}" -f $obj.$key) -foreground Green
                }
            }
        }
    }
}


# filter on exclude
if ($exclude) {
    $excludelist = $exclude -join '|'
    $endPoints = $allendPoints.Where( {$_ -notmatch $excludeList})
}
else {
    $endPoints = $allendPoints
}

$results = New-Object System.Collections.ArrayList
$i = 1
foreach ($endPoint in $endPoints) {
    [int]$percentageComplete = $i / $endPoints.count * 100
    Write-Progress -Activity "Testing Azure Stack Endpoints" -Status "$percentageComplete% Complete:" -PercentComplete $percentageComplete -CurrentOperation $endPoint
    
    $result = New-Object -TypeName PSCustomObject -Property @{
        Name       = $endPoint
        FQDN       = $null
        Thumbprint = $null
        Subject    = $null
        Expires    = $null
        Issuer     = $null
        Notes      = $null
        State      = $null
    }
    if (Resolve-DnsName -Name $endPoint.split(':')[0] -ErrorAction SilentlyContinue -QuickTimeout) {
        #try and retrieve certificate inventory from SSL endpoint
        $SSLEndPoint = "https://{0}" -f $endPoint
        try {
            $null = Invoke-WebRequest $SSLEndPoint -TimeoutSec 3
        }
        catch {
            $ConnectionError = $_.exception.message
        }
        #create service connection point to the target SSL endpoint
        $servicePoint = [System.Net.ServicePointManager]::FindServicePoint($SSLEndPoint)

        # Cosmetic: change guid to testcert to ensure uniqueness in the call but tidy the screen output.
        $pattern = '(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?'
        $endPoint = [regex]::replace($endPoint, $pattern, "testcert")
        $result.Name = $endPoint
        $result.fqdn = ($endpoint -split ':')[0]
        if ($servicePoint.Certificate) {
            $result.Thumbprint = Get-ThumbprintMask -thumbprint $servicePoint.Certificate.GetCertHashString()
            $result.Expires = $servicePoint.Certificate.GetExpirationDateString()
            $result.Issuer = $servicePoint.Certificate.Issuer
            $result.Subject = $servicePoint.Certificate.Subject
            # calculate expiry days and check against threshold.
            $actualExpiryDays = ((Get-Date $result.Expires) - (Get-Date)).Days
            if ((Get-Date $result.Expires) -lt (Get-Date)) {
                $result.notes = "Renew Certificate. Certificate expired {0}" -f $result.Expires
                $result.State = "EXPIRED"
            }
            elseif ($actualExpiryDays -lt $ExpiringInDays) {
                $result.notes = "CONSIDER RENEWING: Certificate expires in {0} days" -f $actualExpiryDays
                $result.State = "EXPIRING"
            }
            else {
                $result.notes = "Certificate expires in {0} days" -f $actualExpiryDays
                $result.State = "OK"
            }
        }
        else {
            $result.notes = "Unable to connect to SSL endpoint {0}. Error: {1}" -f $endPoint, $ConnectionError
        }
    }
    else {
        $result.notes = "Cannot resolve name {0}" -f $endPoint
    }
    $i++
    $results.Add($result) | Out-Null
}

# if the PSEdition is desktop and the user doesn't use passthru colour-code the output in a table
# otherwise just return the object
if ($PSEdition -eq 'Desktop' -AND -not $passThru) {
    $results | Write-Table -padright 15
    Test-CertificateReuse -results $results
}
else {
    $results
}
