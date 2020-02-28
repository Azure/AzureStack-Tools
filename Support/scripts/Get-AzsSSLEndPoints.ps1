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
    $PassThru
)

# endpoint data
$allendPoints = @(
    443,12495,12499,12646,12647,12648,12649,12650,13001,13003,13010,13011,13012,13020,13021,13026,30015 | ForEach-Object {"adminportal.{0}:{1}" -f $FQDN, $PSITEM}
    443,12495,12649,13001,13010,13011,13012,13020,13021,30015,13003 | ForEach-Object {"portal.{0}:{1}" -f $FQDN, $PSITEM}
    443,30024 | Foreach-Object {"management.{0}:{1}" -f $FQDN, $PSITEM}
    443,30024 | Foreach-Object {"adminmanagement.{0}:{1}" -f $FQDN, $PSITEM}
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
        "sso.appservice.$FQDN"
        443,8172 | ForEach-Object {"$(new-guid).appservice.{0}:{1}" -f $FQDN, $PSITEM}
        "$(new-guid).scm.appservice.$FQDN"
        "$(new-guid).sso.appservice.$FQDN"
        443,44300 | ForEach-Object {"api.appservice.{0}:{1}" -f $FQDN, $PSITEM}
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
    $svcCount = ($results | Where-Object name -ne $null).count
    $uniqueThumbprints = $results.thumbprint | Sort-Object | Get-Unique
    if ($uniqueThumbprints.count -lt $svcCount)
    {
        Write-Host "`n"
        Write-Warning -Message "Certificate Reuse Detected. We recommend using seperate certificates for each endpoint."
        foreach ($uniqueThumbprint in $uniqueThumbprints)
        {
            $names = ($results | Where-Object thumbprint -eq $uniqueThumbprint).name | Foreach-Object {$PSITEM.split(':')[0]} | Get-Unique
            Write-Host ("`nCertificate {0} is configured for use on the following endpoint(s): " -f $uniqueThumbprint)
            $names | Foreach-Object {Write-Host ("`t{0}" -f ($_.trimstart('testcert.')))}
        }
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
            foreach ($key in $obj.keys) {
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

$results = @()
$i = 1
foreach ($endPoint in $endPoints) {
    [int]$percentageComplete = $i / $endPoints.count * 100
    Write-Progress -Activity "Testing Azure Stack Endpoints" -Status "$percentageComplete% Complete:" -PercentComplete $percentageComplete -CurrentOperation $endPoint
    
    $result = New-Object -TypeName PSCustomObject @{
        Name       = $endPoint
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
    $results += $result
}

# if the PSEdition is desktop and the user doesn't use passthru colour-code the output in a table
# otherwise just return the object
if ($PSEdition -eq 'Desktop' -AND -not $passThru) {
    $results | Write-Table -padright 15
    Test-CertificateReuse -results $results
}
else {
    $results | ForEach-Object { [pscustomobject] $_ }
}
# SIG # Begin signature block
# MIIppwYJKoZIhvcNAQcCoIIpmDCCKZQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDBTm7ZbNSRQJ5z
# iYxuecCkRI+5NBMwYoOeHYMLHs19rqCCDYEwggX/MIID56ADAgECAhMzAAABA14l
# HJkfox64AAAAAAEDMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTgwNzEyMjAwODQ4WhcNMTkwNzI2MjAwODQ4WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDRlHY25oarNv5p+UZ8i4hQy5Bwf7BVqSQdfjnnBZ8PrHuXss5zCvvUmyRcFrU5
# 3Rt+M2wR/Dsm85iqXVNrqsPsE7jS789Xf8xly69NLjKxVitONAeJ/mkhvT5E+94S
# nYW/fHaGfXKxdpth5opkTEbOttU6jHeTd2chnLZaBl5HhvU80QnKDT3NsumhUHjR
# hIjiATwi/K+WCMxdmcDt66VamJL1yEBOanOv3uN0etNfRpe84mcod5mswQ4xFo8A
# DwH+S15UD8rEZT8K46NG2/YsAzoZvmgFFpzmfzS/p4eNZTkmyWPU78XdvSX+/Sj0
# NIZ5rCrVXzCRO+QUauuxygQjAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUR77Ay+GmP/1l1jjyA123r3f3QP8w
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDM3OTY1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAn/XJ
# Uw0/DSbsokTYDdGfY5YGSz8eXMUzo6TDbK8fwAG662XsnjMQD6esW9S9kGEX5zHn
# wya0rPUn00iThoj+EjWRZCLRay07qCwVlCnSN5bmNf8MzsgGFhaeJLHiOfluDnjY
# DBu2KWAndjQkm925l3XLATutghIWIoCJFYS7mFAgsBcmhkmvzn1FFUM0ls+BXBgs
# 1JPyZ6vic8g9o838Mh5gHOmwGzD7LLsHLpaEk0UoVFzNlv2g24HYtjDKQ7HzSMCy
# RhxdXnYqWJ/U7vL0+khMtWGLsIxB6aq4nZD0/2pCD7k+6Q7slPyNgLt44yOneFuy
# bR/5WcF9ttE5yXnggxxgCto9sNHtNr9FB+kbNm7lPTsFA6fUpyUSj+Z2oxOzRVpD
# MYLa2ISuubAfdfX2HX1RETcn6LU1hHH3V6qu+olxyZjSnlpkdr6Mw30VapHxFPTy
# 2TUxuNty+rR1yIibar+YRcdmstf/zpKQdeTr5obSyBvbJ8BblW9Jb1hdaSreU0v4
# 6Mp79mwV+QMZDxGFqk+av6pX3WDG9XEg9FGomsrp0es0Rz11+iLsVT9qGTlrEOla
# P470I3gwsvKmOMs1jaqYWSRAuDpnpAdfoP7YO0kT+wzh7Qttg1DO8H8+4NkI6Iwh
# SkHC3uuOW+4Dwx1ubuZUNWZncnwa6lL2IsRyP64wggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIbfDCCG3gCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAQNeJRyZH6MeuAAAAAABAzAN
# BglghkgBZQMEAgEFAKCB3jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQguUm1Upw8
# sT9xuGKliUPZtKbcV8fC/0/vtJcRMqkXQPkwcgYKKwYBBAGCNwIBDDFkMGKgSIBG
# AE0AaQBjAHIAbwBzAG8AZgB0ACAAQQB6AHUAcgBlAFMAdABhAGMAawAgAFAAYQBy
# AHQAbgBlAHIAVABvAG8AbABrAGkAdKEWgBRodHRwOi8vQ29kZVNpZ25JbmZvIDAN
# BgkqhkiG9w0BAQEFAASCAQCXDjoCT21k9O1X3oBbo6u+JQ3KDvz80gTfkj3pGVwt
# kpZJ6sAWuThXURg3NPDKR46w/zupun6v7LjwX6pqhkF9IlG+y7a8jqunTqvGk8TC
# T/yFpCodMwNd1oci3/Pp70rOd3j/J7jKUCXo4KpxfMOwMWxPHdA/1C+p7aABBE4L
# if8Fly2OpAqCXMwG8f/eCUprjTFhqIzTOvWdaSQ0aC+OibHvfoFM3cO+L263qdbj
# Rw5f67tGbf67lzGZUiLg1Uuxoz0QMd5SoZ/Whuk204+UOJQwQ7F0uJYl6DDwHOcR
# Ls9ddEUpOqlQAUCBAaqmOL18nV5oPBAwpnqfCqDwqzq2oYIY1jCCGNIGCisGAQQB
# gjcDAwExghjCMIIYvgYJKoZIhvcNAQcCoIIYrzCCGKsCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIF+19sCf86hrRPnEcyPu8fN6iuFNHQCDlrzngd6v
# CpyFAgZbhw4w3fIYEzIwMTgwODMxMTY0MzE3Ljc1N1owBIACAfSggdCkgc0wgcox
# CzAJBgNVBAYTAlVTMQswCQYDVQQIEwJXQTEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQg
# SXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjhFOUUtNEJEMC0yRUQwMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBzZXJ2aWNloIIULTCCBPEwggPZoAMCAQICEzMAAADDGu2K0g0+y1EAAAAAAMMw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MTgwMTMxMTkwMDQ2WhcNMTgwOTA3MTkwMDQ2WjCByjELMAkGA1UEBhMCVVMxCzAJ
# BgNVBAgTAldBMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlv
# bnMgTGltaXRlZDEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046OEU5RS00QkQwLTJF
# RDAxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIHNlcnZpY2UwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCMN/dJFVWpHposmQoHrI9ldf5Uur+U
# 75SrN4UPt+QxlW/vKFylbLXNzfEitzbazmK4KQirtWWmLcBH4JqpjxThYpSjU87b
# mhStUQ7tpqziUWKA/GbYQSH4iZOq2TWY4QN4fsb39L3y7xQa062mpliGgwB5gnYm
# KPQ9Uwe+J6XIzKN7IKLGjPBncY4OoS4PjPUXC7n/yYgzcvkJDc4Wh/lYiZtnzjSc
# lVRjnf6MUnJng/SO4y9wBju6JN155idAMbBvnuJnZbtZZy3mR/pnX8CKnuuYjpSC
# 584MTsH+/qvaz4GJrknh3n9TwGeY5eoJBOwVIRdjZna9DuiqlrPcgisTAgMBAAGj
# ggEbMIIBFzAdBgNVHQ4EFgQUqKX8YULH7IWJxGWi+APSuTLftdowHwYDVR0jBBgw
# FoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDov
# L2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3RhUENB
# XzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAx
# MC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDAN
# BgkqhkiG9w0BAQsFAAOCAQEAqAGHNw86RThfkGA9tVq9GyTu4FEDw9AW3dxSBWEU
# CY/CiKHVbV47tTC3pogDgH0MjYkET9rReUEWzpQcILRvnpz+xJS0Pa34Mrhf4e3B
# RAhXyWg2iA6QbRIBpdWgNZWDPT/B9oRzN9vUA6i1IoXLc4PFBMrB7TNpQLSPzFvl
# kgDu3S3FQmletMf09msZy8WJjoYJnRIEQRbfnqtIdJ37NQPmfmtJ7pUJdyLd6hXk
# eWwRtAmN6SbmFbKeIxZyGETtZQZpa2mQSg7nyEvpr82wBCYwqR+71xH+ECiMDJMZ
# 6fF7NXtywdcOvAA9Tpznl/oSEa78xBeEDqgt3zqgYhHUlDCCBe0wggPVoAMCAQIC
# ECjMOiW/ukSsRJqbWGtDOaowDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEwMDYyMzIxNTcyNFoXDTM1
# MDYyMzIyMDQwMVowgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAuQieKOTk7AZO
# UGizQcV76662jq+BuiJEH2U0aUy+cEAX8hZ74nn9hu0NOfQbqK2SkB7LPXaPWtm1
# kRAuPAWNim0kVOcf7Vatg7RQnBWlF3SIWSD8CMWEdtNo1G8oeM5cuPNQkET/42Nf
# vqGaLJYVBNYH/h6EIeBCMRHEKDaUz1CkYp7J1qtxALJbDOaW1AoklvX/xtW3G9fL
# tyFirxLcoV034xr7GkaYwJvA52MfKgiTAn4eao7ynxiJ5CKForGEV0D/9Q7Yb5zt
# 4kUxAc0X6X+wgUXjqiFAJqFyqqdPPAEFfu6DWLFeBmOZYpF4grcNkwwkarQb2yfs
# X5UEP5NKMPWXGLOn+RmnkzMdAcjbIlJc1yXJRvmi+4dZQ76bYrGNLYZEGkaseGF+
# MAn6ronEQSoiZgOROUWcx4sMqMoNL/tS6gz3YzMjnf6wH61n1qdQA8YEcGO1LLGG
# WkO3+675biluISFBJgaMycPusMKFk6G5hdnmMmxLTD/WXaPltZ13w5zAVbd0AOO4
# OKuDl1DhmkIkHcbAozDRGlrIUjT3c/HHGB8zrXrsy0Fg8yOUIMJIRaxcUcYugMLi
# dxW9hYftNp2Wke4AtaNw7J/jjYBog3a6r11wUiIW4mb7urPFwvc+L3emyt7BpsZI
# TMM3USPTJ9e4TnCW8KFEdq94z5rhZhMCAwEAAaNRME8wCwYDVR0PBAQDAgGGMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFNX2VsuP6KJcYmjRPZSQW9fOmhjEMBAG
# CSsGAQQBgjcVAQQDAgEAMA0GCSqGSIb3DQEBCwUAA4ICAQCspZaMv7uupvbXcYdD
# MVaI/RwycVs1t9TwkfKvN+IU8fMCJgU+FhR/FLq4T/uJsrLn1AnMbblbO2RlcGa3
# 8rFa3xoC8/VRuGdtefO/VnvkhLkrHptAnCY0+UcYmGnYHNe20b+PYcJnxLXvYEOO
# EBs2SeQgyq2nwbEnZQn4zfVbKtCEM/PvH/L1nAtYkzegdaDect5sdSpmIvWMBjBW
# n0C5MKpAdxWC14vswNOyvYPFdwwerq8ZU6BNeXGfD68wzmf51izMIkF6B/KXQhjO
# WXkQVd5vEOS42oNmQBYJaCNbly4mmgK7V4zFuLppYjKAiZ6h/cCSfHsrMxmEKmPF
# AGhi+p9HjZl6RTqn6e3uaUK184GbR1YQe/xwNoQYc+rv+ZdNnjMj3SYLuiq3P0Tc
# gyf/vWFZKxG3yk/bxYsMHDGuMvj4uUL3f9xhmnaxWgThET1mRbcYcb7JJIXW89S6
# QTRdEi0luY2mE0htS7AHfZmTCWGBdFcmiqtp4+TZx4jMJNjsUiRcHryRFOKW3usK
# 2p7dX7Nb29SC7MYgUIclQDr7x+7N/jPlbsOECVUDJTnA6TVdZTGo9r+gCc0px7M2
# Mi7clfODwVrPi4326rMh+KTtHjEOtkwRq2ALpBIjIhejNmSCkQQS4KtvHstQBWG0
# QP9ZhnHR1TNpfKlzijjXZAzxaTCCBnEwggRZoAMCAQICCmEJgSoAAAAAAAIwDQYJ
# KoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIxNDY1NVowfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF++18aEssX8XD5WHCdrc+
# Zitb8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRDDNdNuDgIs0Ldk6zWczBX
# JoKjRQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSxz5NMksHEpl3RYRNuKMYa
# +YaAu99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1rL2KQk1AUdEPnAY+Z3/1
# ZsADlkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16HgcsOmZzTznL0S6p/TcZL2k
# AcEgCZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB4jAQBgkrBgEEAYI3FQEE
# AwIBADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqFbVUwGQYJKwYBBAGCNxQC
# BAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYD
# VR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZF
# aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9v
# Q2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcw
# AoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJB
# dXRfMjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCBkjCBjwYJKwYBBAGCNy4D
# MIGBMD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vUEtJL2Rv
# Y3MvQ1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABf
# AFAAbwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEB
# CwUAA4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUxvs8F4qn++ldtGTCzwsVm
# yWrf9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GASinbMQEBBm9xcF/9c+V4X
# NZgkVkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1L3mBZdmptWvkx872ynoA
# b0swRCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWOM7tiX5rbV0Dp8c6ZZpCM
# /2pif93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4pm3S4Zz5Hfw42JT0xqUK
# loakvZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45V3aicaoGig+JFrphpxHL
# mtgOR5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x4QDf5zEHpJM692VHeOj4
# qEir995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEegPsbiSpUObJb2sgNVZl6
# h3M7COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKnQqLJzxlBTeCG+SqaoxFm
# MNO7dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp3lfB0d4wwP3M5k37Db9d
# T+mdHhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvTX4/edIhJEqGCAs4wggI3
# AgEBMIH4oYHQpIHNMIHKMQswCQYDVQQGEwJVUzELMAkGA1UECBMCV0ExEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsG
# A1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYD
# VQQLEx1UaGFsZXMgVFNTIEVTTjo4RTlFLTRCRDAtMkVEMDElMCMGA1UEAxMcTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgc2VydmljZaIjCgEBMAcGBSsOAwIaAxUAybtFiTJ7
# M24kwW5YE9d6GKXiCMOggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDANBgkqhkiG9w0BAQUFAAIFAN8zhucwIhgPMjAxODA4MzExNzIwMzlaGA8y
# MDE4MDkwMTE3MjAzOVowdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA3zOG5wIBADAK
# AgEAAgImeAIB/zAHAgEAAgITVTAKAgUA3zTYZwIBADA2BgorBgEEAYRZCgQCMSgw
# JjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3
# DQEBBQUAA4GBACqi4VCcKP15HurYYkCJwgChOJcwXO8jXERhGN2o17vsjyE+ssNV
# nYdeFGk+63HhhzxYXHJRRugS/Lj4Gwb9H1ls3ek3OIg58NyC4JMpaJJNcas1ghhj
# mZh82ZQGIfSk8/0IQv5NZlLsbHAxGaoWclmOMe1JKqGfCOYCZ+CTsXFpMYIDDTCC
# AwkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAADDGu2K
# 0g0+y1EAAAAAAMMwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsq
# hkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgz+Nq6+PUbqCtbfZftDoAu7Y12wGO
# Ca/WsmHn9icilDYwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCCz+WivtpFS
# JEGUqqiE9MIF44SXs1OtNR4BAQA6MNq16jCBmDCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwAhMzAAAAwxrtitINPstRAAAAAADDMCIEIKt0j+HbgGUd
# VjQOxbGuPR5RK+jlm05Zfdk++RUOysGsMA0GCSqGSIb3DQEBCwUABIIBAHrHLegK
# Bo4OsdhXvw7HkdQabuMRyok98DEhj7OZFQMdR/PUEiM1wCrsb8CZjLYEmUIwlgZq
# T5u1lwPWAbvKhqUn2NRf5cTThuyUPkSrGxdUuMCgj3+b98S6h7XmLik3y6zUcuxv
# WCvBksIeVW6vWlN7m8PRzgcC2drMbEKDXMY3qCpKQoX1xPrywE9jmg/8r/UqMhB/
# qMMKxA6gaSVI4G/eMm0yNo3iWFFSnGNZB1FxpG4P226B7uHjXohgAQ8LvHCRH1ZO
# aQ4U74woSboBlvFdedmrGH5TH4epdSNjHR35ulfWpN2wniPHPUSB8K6NsJGCjoox
# ggKwgEU4fcTu2Ws=
# SIG # End signature block
