<#
.SYNOPSIS
    Display certificate inventory for Public SSL EndPoints
.DESCRIPTION
    Probes SSL endpoints of an Azure Stack deployment to gather external certificate inventory. 
    It then displays certificate inventory for Public SSL EndPoints. 
    Endpoints not accessible will return blank information.
    User can optionally add ADFS, AppServices, SQLAdapter and MySQLAdapter.
    User can exclude certain endpoints also.
.EXAMPLE
    PS C:\> .\Get-AzsSSLEndPoints.ps1 -FQDN "east.azurestack.contoso.com"
    Seeds public endpoints with east.azurestack.contoso.com and attempts gather certificate inventory from each endpoint
.EXAMPLE
    PS C:\> .\Get-SSLEndPoints.ps1 -FQDN "east.azurestack.contoso.com" -exclude adminvault
    Seeds public endpoints with east.azurestack.contoso.com and attempts gather certificate inventory from each endpoint, except adfs, graph and adminvault.
.EXAMPLE
    PS C:\> .\Get-AzsSSLEndPoints.ps1 -FQDN "east.azurestack.contoso.com" -UsePaaS -exclude AppServices
    Seeds public endpoints with east.azurestack.contoso.com and attempts gather certificate inventory from each endpoint includes PaaS endpoints except for AppServices.
.EXAMPLE
    PS C:\> .\Get-SSLEndPoints.ps1 -FQDN "east.azurestack.contoso.com" -ExpiringInDays 30
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
    "portal.$FQDN"
    "adminportal.$FQDN"
    "management.$FQDN"
    "adminmanagement.$FQDN"
    "$(new-guid).queue.$FQDN"
    "$(new-guid).table.$FQDN"
    "$(new-guid).blob.$FQDN"
    "$(new-guid).vault.$FQDN"
    "$(new-guid).adminvault.$FQDN"
)

if ($UseADFS) {
    $allendPoints += @( 
        "adfs.$FQDN"
        "graph.$FQDN"
    )
}

if ($UsePaaS) {
    $allendPoints += @( 
        "mysqladapter.dbadapter.$FQDN"
        "sqladapter.dbadapter.$FQDN"
        "ftp.appservice.$FQDN"
        "sso.appservice.$FQDN"
        "$(new-guid).appservice.$FQDN"
        "$(new-guid).scm.appservice.$FQDN"
        "$(new-guid).sso.appservice.$FQDN"
        "api.appservice.$FQDN"
    )
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

foreach ($endPoint in $endPoints) {
    $result = New-Object -TypeName PSCustomObject @{
        Name       = $endPoint
        Thumbprint = $null
        Subject    = $null
        Expires    = $null
        Issuer     = $null
        Notes      = $null
        State      = $null
    }
    if (Resolve-DnsName -Name $endPoint -ErrorAction SilentlyContinue) {
        #try and retrieve certificate inventory from SSL endpoint
        $SSLEndPoint = "https://{0}" -f $endPoint
        try {
            $null = Invoke-WebRequest $SSLEndPoint -TimeoutSec 3 -ErrorAction SilentlyContinue
        }
        catch {
            $null
        }
        #create service connection point to the target SSL endpoint
        $servicePoint = [System.Net.ServicePointManager]::FindServicePoint($SSLEndPoint)

        # Cosmetic: change guid to testcert to ensure uniqueness in the call but tidy the screen output.
        $pattern = '(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?'
        $endPoint = [regex]::replace($endPoint, $pattern, "testcert")
        $result.Name = $endPoint
        if ($servicePoint.Certificate) {
            $result.Thumbprint = $servicePoint.Certificate.GetCertHashString()
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
            $result.notes = "Unable to connect to SSL endpoint {0}" -f $endPoint    
        }
    }
    else {
        $result.notes = "Cannot resolve name {0}" -f $endPoint
    }
    $results += $result
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

# if the PSEdition is desktop and the user doesn't use passthru colour-code the output in a table
# otherwise just return the object
if ($PSEdition -eq 'Desktop' -AND -not $passThru) {
    $results | Write-Table -padright 15
}
else {
    $results | ForEach-Object { [pscustomobject] $_ }
}
# SIG # Begin signature block
# MIIdqQYJKoZIhvcNAQcCoIIdmjCCHZYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnnB1yxTD/9TC78ljscz2lP0H
# DLqgghhVMIIEwzCCA6ugAwIBAgITMwAAAMp9MhZ8fv0FAwAAAAAAyjANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODU1
# WhcNMTgwOTA3MTc1ODU1WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OjcyOEQtQzQ1Ri1GOUVCMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAj3CeDl2ll7S4
# 96ityzOt4bkPI1FucwjpTvklJZLOYljFyIGs/LLi6HyH+Czg8Xd/oDQYFzmJTWac
# A0flGdvk8Yj5OLMEH4yPFFgQsZA5Wfnz/Cg5WYR2gmsFRUFELCyCbO58DvzOQQt1
# k/tsTJ5Ns5DfgCb5e31m95yiI44v23FVpKnTY9CUJbIr8j28O3biAhrvrVxI57GZ
# nzkUM8GPQ03o0NGCY1UEpe7UjY22XL2Uq816r0jnKtErcNqIgglXIurJF9QFJrvw
# uvMbRjeTBTCt5o12D4b7a7oFmQEDgg+koAY5TX+ZcLVksdgPNwbidprgEfPykXiG
# ATSQlFCEXwIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFGb30hxaE8ox6QInbJZnmt6n
# G7LKMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAGyg/1zQebvX564G4LsdYjFr9ptnqO4KaD0lnYBECEjMqdBM
# 4t+rNhN38qGgERoc+ns5QEGrrtcIW30dvMvtGaeQww5sFcAonUCOs3OHR05QII6R
# XYbxtAMyniTUPwacJiiCSeA06tLg1bebsrIY569mRQHSOgqzaO52EzJlOtdLrGDk
# Ot1/eu8E2zN9/xetZm16wLJVCJMb3MKosVFjFZ7OlClFTPk6rGyN9jfbKKDsDtNr
# jfAiZGVhxrEqMiYkj4S4OyvJ2uhw/ap7dbotTCfZu1yO57SU8rE06K6j8zWB5L9u
# DmtgcqXg3ckGvdmWVWBrcWgnmqNMYgX50XSzffQwggYBMIID6aADAgECAhMzAAAA
# xOmJ+HqBUOn/AAAAAADEMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTEwHhcNMTcwODExMjAyMDI0WhcNMTgwODExMjAyMDI0WjB0
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCIirgkwwePmoB5FfwmYPxyiCz69KOXiJZGt6PLX4kvOjMuHpF4+nypH4IB
# tXrLGrwDykbrxZn3+wQd8oUK/yJuofJnPcUnGOUoH/UElEFj7OO6FYztE5o13jhw
# VG877K1FCTBJwb6PMJkMy3bJ93OVFnfRi7uUxwiFIO0eqDXxccLgdABLitLckevW
# eP6N+q1giD29uR+uYpe/xYSxkK7WryvTVPs12s1xkuYe/+xxa8t/CHZ04BBRSNTx
# AMhITKMHNeVZDf18nMjmWuOF9daaDx+OpuSEF8HWyp8dAcf9SKcTkjOXIUgy+MIk
# ogCyvlPKg24pW4HvOG6A87vsEwvrAgMBAAGjggGAMIIBfDAfBgNVHSUEGDAWBgor
# BgEEAYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUy9ZihM9gOer/Z8Jc0si7q7fD
# E5gwUgYDVR0RBEswSaRHMEUxDTALBgNVBAsTBE1PUFIxNDAyBgNVBAUTKzIzMDAx
# MitjODA0YjVlYS00OWI0LTQyMzgtODM2Mi1kODUxZmEyMjU0ZmMwHwYDVR0jBBgw
# FoAUSG5k5VAF04KqFzc3IrVtqMp1ApUwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljQ29kU2lnUENBMjAxMV8y
# MDExLTA3LTA4LmNybDBhBggrBgEFBQcBAQRVMFMwUQYIKwYBBQUHMAKGRWh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljQ29kU2lnUENBMjAx
# MV8yMDExLTA3LTA4LmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IC
# AQAGFh/bV8JQyCNPolF41+34/c291cDx+RtW7VPIaUcF1cTL7OL8mVuVXxE4KMAF
# RRPgmnmIvGar27vrAlUjtz0jeEFtrvjxAFqUmYoczAmV0JocRDCppRbHukdb9Ss0
# i5+PWDfDThyvIsoQzdiCEKk18K4iyI8kpoGL3ycc5GYdiT4u/1cDTcFug6Ay67Sz
# L1BWXQaxFYzIHWO3cwzj1nomDyqWRacygz6WPldJdyOJ/rEQx4rlCBVRxStaMVs5
# apaopIhrlihv8cSu6r1FF8xiToG1VBpHjpilbcBuJ8b4Jx/I7SCpC7HxzgualOJq
# nWmDoTbXbSD+hdX/w7iXNgn+PRTBmBSpwIbM74LBq1UkQxi1SIV4htD50p0/GdkU
# ieeNn2gkiGg7qceATibnCCFMY/2ckxVNM7VWYE/XSrk4jv8u3bFfpENryXjPsbtr
# j4Nsh3Kq6qX7n90a1jn8ZMltPgjlfIOxrbyjunvPllakeljLEkdi0iHv/DzEMQv3
# Lz5kpTdvYFA/t0SQT6ALi75+WPbHZ4dh256YxMiMy29H4cAulO2x9rAwbexqSajp
# lnbIvQjE/jv1rnM3BrJWzxnUu/WUyocc8oBqAU+2G4Fzs9NbIj86WBjfiO5nxEmn
# L9wliz1e0Ow0RJEdvJEMdoI+78TYLaEEAo5I+e/dAs8DojCCBgcwggPvoAMCAQIC
# CmEWaDQAAAAAABwwDQYJKoZIhvcNAQEFBQAwXzETMBEGCgmSJomT8ixkARkWA2Nv
# bTEZMBcGCgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0
# IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5MB4XDTA3MDQwMzEyNTMwOVoXDTIx
# MDQwMzEzMDMwOVowdzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBMIIBIjANBgkqhkiG
# 9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn6Fssd/bSJIqfGsuGeG94uPFmVEjUK3O3RhO
# JA/u0afRTK10MCAR6wfVVJUVSZQbQpKumFwwJtoAa+h7veyJBw/3DgSY8InMH8sz
# JIed8vRnHCz8e+eIHernTqOhwSNTyo36Rc8J0F6v0LBCBKL5pmyTZ9co3EZTsIbQ
# 5ShGLieshk9VUgzkAyz7apCQMG6H81kwnfp+1pez6CGXfvjSE/MIt1NtUrRFkJ9I
# AEpHZhEnKWaol+TTBoFKovmEpxFHFAmCn4TtVXj+AZodUAiFABAwRu233iNGu8Qt
# VJ+vHnhBMXfMm987g5OhYQK1HQ2x/PebsgHOIktU//kFw8IgCwIDAQABo4IBqzCC
# AacwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUIzT42VJGcArtQPt2+7MrsMM1
# sw8wCwYDVR0PBAQDAgGGMBAGCSsGAQQBgjcVAQQDAgEAMIGYBgNVHSMEgZAwgY2A
# FA6sgmBAVieX5SUT/CrhClOVWeSkoWOkYTBfMRMwEQYKCZImiZPyLGQBGRYDY29t
# MRkwFwYKCZImiZPyLGQBGRYJbWljcm9zb2Z0MS0wKwYDVQQDEyRNaWNyb3NvZnQg
# Um9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHmCEHmtFqFKoKWtTHNY9AcTLmUwUAYD
# VR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwv
# cHJvZHVjdHMvbWljcm9zb2Z0cm9vdGNlcnQuY3JsMFQGCCsGAQUFBwEBBEgwRjBE
# BggrBgEFBQcwAoY4aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9N
# aWNyb3NvZnRSb290Q2VydC5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggIBABCXisNcA0Q23em0rXfbznlRTQGxLnRxW20ME6vOvnuPuC7U
# EqKMbWK4VwLLTiATUJndekDiV7uvWJoc4R0Bhqy7ePKL0Ow7Ae7ivo8KBciNSOLw
# UxXdT6uS5OeNatWAweaU8gYvhQPpkSokInD79vzkeJkuDfcH4nC8GE6djmsKcpW4
# oTmcZy3FUQ7qYlw/FpiLID/iBxoy+cwxSnYxPStyC8jqcD3/hQoT38IKYY7w17gX
# 606Lf8U1K16jv+u8fQtCe9RTciHuMMq7eGVcWwEXChQO0toUmPU8uWZYsy0v5/mF
# hsxRVuidcJRsrDlM1PZ5v6oYemIp76KbKTQGdxpiyT0ebR+C8AvHLLvPQ7Pl+ex9
# teOkqHQ1uE7FcSMSJnYLPFKMcVpGQxS8s7OwTWfIn0L/gHkhgJ4VMGboQhJeGsie
# IiHQQ+kr6bv0SMws1NgygEwmKkgkX1rqVu+m3pmdyjpvvYEndAYR7nYhv5uCwSdU
# trFqPYmhdmG0bqETpr+qR/ASb/2KMmyy/t9RyIwjyWa9nR2HEmQCPS2vWY+45CHl
# tbDKY7R4VAXUQS5QrJSwpXirs6CWdRrZkocTdSIvMqgIbqBbjCW/oO+EyiHW6x5P
# yZruSeD3AWVviQt9yGnI5m7qp5fOMSn/DsVbXNhNG6HY+i+ePy5VFmvJE6P9MIIH
# ejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0
# IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5
# WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDEx
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00
# uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kN
# eWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/n
# qwhQz7NEt13YxC4Ddato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3V
# XHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6x
# jF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5k
# f1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4c
# I6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bys
# AoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexN
# STCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93
# KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX
# 3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEA
# MB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4K
# AFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSME
# GDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRw
# Oi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJB
# dXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcw
# AoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJB
# dXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcu
# AzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEA
# bABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3
# DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74
# w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQ
# sP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6Sp
# BQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd
# 8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJx
# Jxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9
# Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEG
# sXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AA
# KcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/
# 1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EK
# sT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCBL4w
# ggS6AgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAADE
# 6Yn4eoFQ6f8AAAAAAMQwCQYFKw4DAhoFAKCB0jAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0B
# CQQxFgQUh7RHGhSTNAq3ZJR57bIfGz/Z9lQwcgYKKwYBBAGCNwIBDDFkMGKgSIBG
# AE0AaQBjAHIAbwBzAG8AZgB0ACAAQQB6AHUAcgBlAFMAdABhAGMAawAgAFAAYQBy
# AHQAbgBlAHIAVABvAG8AbABrAGkAdKEWgBRodHRwOi8vQ29kZVNpZ25JbmZvIDAN
# BgkqhkiG9w0BAQEFAASCAQARJEgl1HymGAJfWGlbh2W2koBCRx2TmOZHGHPV9wd1
# pK0kmwfKDu1/+GkiOQWxzIDV5kv0si7lGR6gnjwX0N9FXoH7Ml57MQig3PNAXnPu
# TODyS/XCFcWRYeFMRIp1Fnspf8jD/iU7holFXqkzvsSnjx/V3Mnke4J8q+vwB9SQ
# CbhKZTWPQwKA9cqSktrZ7KB06704IO9iheAwe5RFKGUie+JHrhg6UwmoI65JGkmq
# cnznSNLc4IFMP9ekvJhmxOXYgPGEqiza8q/ITd+ayjc3O7NSBokpBRG3YSgOaQZy
# JcXxcfaSsQPs5TCEfI8Uqsh3lhrL55vm0yr+L1R07iX+oYICKDCCAiQGCSqGSIb3
# DQEJBjGCAhUwggIRAgEBMIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQQITMwAA
# AMp9MhZ8fv0FAwAAAAAAyjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTgwNjIyMTQ1NTMxWjAjBgkqhkiG9w0B
# CQQxFgQUa+dGmXnaPXim+w7pjFVqIF04RicwDQYJKoZIhvcNAQEFBQAEggEADFBS
# 0OejiFpPh2+3mRL4jqtIn/vNccnfABBXkju4oNMwjOg5gnYAfOfJQxopmuGg+MWn
# WIxWsXKNNOva1ohZEeQkwSmSiWhbV6TdsvKk4n3YhRA/QGXrttm47VQL16jlhuxq
# jdu0WDTCykw+gsWoYbfdb1OVhmi3NmA9RvKTd3BU5sN+KwRrrTPScNYcufRi1pZp
# mnvlxPOZSTieZKVDNvbTREmWchUIDqi4eRHz6T4U/hME2IVacSu0lF4eH9tNicWM
# b96p4i9fnDifTYLtc+iAjtRvO/KOl1k6lJrdGq3QhmFlNH5P4lzt2+thQ8YOEkTB
# a1rQxlx1Z+Qm9Akmvw==
# SIG # End signature block
