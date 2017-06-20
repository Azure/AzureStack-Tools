# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information. 

<# 
 
.SYNOPSIS 
 
This script can be used to register Azure Stack POC with Azure. To run this script, you must have a public Azure subscription of any type. 
There must also be an account that is an owner or contributor of the subscription. This account cannot be an MSA (i.e. cannot be live.com or hotmail.com) or 2FA account. 

.DESCRIPTION 
 
RegisterToAzure runs local scripts to connect your Azure Stack to Azure. After connecting with Azure, you can test marketplace syndication. 

The script will follow four steps:
Configure bridge identity: configures Azure Stack so that it can call to Azure via your Azure subscription
Get registration request: get Azure Stack environment information to create a registration for this azure stack in azure
Register with Azure: uses Azure powershell to create an "Azure Stack Registration" resource on your Azure subscription
Activate Azure Stack: final step in connecting Azure Stack to be able to call out to Azure

.PARAMETER azureSubscriptionId  
 
Azure subscription ID that you want to register your Azure Stack with. This parameter is mandatory.

.PARAMETER azureDirectory  
 
Name of your AAD Tenant which your Azure subscription is a part of. This parameter is mandatory.

.PARAMETER azureSubscriptionOwner
 
Username for an owner/contributor of the azure subscription. This user must not be an MSA or 2FA account. This parameter is mandatory.

.PARAMETER azureSubscriptionPassword

Password for the Azure subscription. You will be prompted to type in this password. This parameter is mandatory.

.PARAMETER marketplaceSyndication

Flag (ON/OFF) whether to enable downloading items from the Azure marketplace on this environment. Defaults to "ON".

.PARAMETER reportUsage

Flag (ON/OFF) whether to enable pushing usage data to Azure on this environment. Defaults to "ON".


.EXAMPLE

This script must be run from the Host machine of the POC. 
.\RegisterWithAzure.ps1 -azureSubscriptionId "5e0ae55d-0b7a-47a3-afbc-8b372650abd3" -azureDirectory "contoso.onmicrosoft.com" -azureSubscriptionOwner "serviceadmin@contoso.onmicrosoft.com"

 
.NOTES 
 Ensure that you have an Azure subscription 
#>

[CmdletBinding()]
Param     (
    [Parameter(Mandatory = $true)]
    [string]$azureDirectory,

    [Parameter(Mandatory = $true)]
    [String]$azureSubscriptionId,

    [Parameter(Mandatory = $true)]
    [String]$azureSubscriptionOwner,

    [Parameter(Mandatory = $true)]
    [securestring]$azureSubscriptionPassword,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('On', 'Off')]
    [string] $marketplaceSyndication = 'On',

    [Parameter(Mandatory=$false)]
    [ValidateSet('On', 'Off')]
    [string] $reportUsage = 'On'
)

#requires -Module AzureRM.Profile
#requires -Module AzureRM.Resources
#requires -RunAsAdministrator

Import-Module C:\CloudDeployment\ECEngine\EnterpriseCloudEngine.psm1 -Force 
cd  C:\CloudDeployment\Setup\Activation\Bridge

Read-Host "This script will turn marketplace syndication $marketplaceSyndication and usage reporting $reportUsage. You can change this by running the script using different flags. Press Enter to continue."

# Determine version of TP3 and set values accordingly
 $versionInfo = [xml] (Get-Content -Path C:\CloudDeployment\Configuration\Version\version.xml) 
if($versionInfo.Version -ge "1.0.170308.2") 
{ 
    Write-Verbose -Message "Using TP3.N release" -Verbose
    $bridgeAppConfigFile = "\\SU1FileServer\SU1_Infrastructure_1\ASResourceProvider\Config\AzureBridge.IdentityApplication.Configuration.json" 
} 
elseif($versionInfo.Version -eq "1.0.170225.2") 
{ 
    Write-Verbose -Message "Using TP3.O release" -Verbose
    $bridgeAppConfigFile = "\\SU1FileServer\SU1_Infrastructure_1\ASResourceProvider\Config\ConnectionAzureArm.IdentityApplication.Configuration.json"
} 
else 
{ 
    Write-Error -Message "Unsupported TP3 release" -Verbose 
} 


#
# Step 1: Configure Bridge identity
#

$azureCreds = New-Object System.Management.Automation.PSCredential($azureSubscriptionOwner, $azureSubscriptionPassword)
.\Configure-BridgeIdentity.ps1 -AzureCredential $azureCreds -AzureDirectoryTenantId $azureDirectory -AzureEnvironment AzureCloud -Verbose
Write-Host "STEP 1: Configure local identity completed"

#
# Step 2: Create new registration request
#

$registrationOutputFile = "c:\temp\registration.json"
.\New-RegistrationRequest.ps1 -BridgeAppConfigFile $bridgeAppConfigFile -RegistrationRequestOutputFile $registrationOutputFile -Verbose
Read-Host "STEP 2: Registration request completed. Re-enter your Azure subscription credentials in the next step. Note: Step 3 can be run from a different machine that is connected to Azure. Press Enter to continue and run step 3 from this machine."

#
# Step 3: Register Azure Stack with Azure
#
New-Item -ItemType Directory -Force -Path "C:\temp"
$registrationRequestFile = "c:\temp\registration.json"
$registrationOutputFile = "c:\temp\registrationOutput.json"

Login-AzureRmAccount -EnvironmentName AzureCloud
Select-AzureRmSubscription -SubscriptionId $azureSubscriptionId

# Ensure subscription is registered to Microsoft.AzureStack namespace in Azure
Register-AzureRmResourceProvider -ProviderNamespace 'microsoft.azurestack'
$result                        = $null
$attempts                      = 0
$maxAttempts                   = 20
$delayInSecondsBetweenAttempts = 10
do
{
    $attempts++
    Write-Verbose "[CHECK] Checking for resource provider registration... (attempt $attempts of $maxAttempts)"
    $result = $(Get-AzureRmResourceProvider -ProviderNamespace 'microsoft.azurestack')[0].RegistrationState -EQ 'Registered'
    $result
    if ((-not $result) -and ($attempts -lt $maxAttempts))
    {
        Write-Verbose "[DELAY] Attempt $attempts failed to see provider registration, delaying for $delayInSecondsBetweenAttempts seconds before retry"
        Start-Sleep -Seconds $delayInSecondsBetweenAttempts
    }
}
while ((-not $result) -and ($attempts -lt $maxAttempts))

if (-not $result)
{
    throw New-Object System.InvalidOperationException("Azure Bridge Resource Provider was registered but did not become routable within the alloted time")
}

.\Register-AzureStack.ps1 -BillingModel Consumption -Syndication $marketplaceSyndication -ReportUsage $reportUsage -SubscriptionId $azureSubscriptionId -AzureAdTenantId $azureDirectory `
  -AzureCredential $azureCreds -AzureEnvironmentName AzureCloud -RegistrationRequestFile $registrationRequestFile -RegistrationOutputFile $registrationOutputFile -Location "westcentralus" -Verbose
Read-Host "STEP 3: Register Azure Stack with Azure completed. Press Enter to continue."

#
# Step 4: Activate Azure Stack
#

# temporary step to adjust registration output to expected format
$reg = Get-Content $registrationOutputFile | ConvertFrom-Json
$newProps = @{
ObjectId = $reg.properties.ObjectId
ProvisioningState = $reg.properties.provisioningState
syndication = $marketplaceSyndication
usagebridge = $reportUsage
}
$reg.properties = $newProps
$reg | ConvertTo-Json -Depth 4 | Out-File -FilePath $registrationOutputFile

$regResponse = Get-Content -path  $registrationOutputFile
$AzureResourceManagerEndpoint = "https://management.azure.com"

if($versionInfo.Version -ge "1.0.170308.2") 
{ 
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($regResponse)
    $activationCode = [Convert]::ToBase64String($bytes)
    .\Activate-Bridge.ps1 -activationCode $activationCode -AzureResourceManagerEndpoint $AzureResourceManagerEndpoint -Verbose
}
elseif($versionInfo.Version -eq "1.0.170225.2") 
{ 
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($regResponse)
    $activationCode = [Convert]::ToBase64String($bytes)
    .\Activate-Bridge.ps1 -activationCode $activationCode -Verbose
} 

Write-Host "STEP 4: Activate Azure Stack completed"
Write-Host "Registration complete. Close and re-open the Marketplace Management blade in the admin portal."

# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUpfgRkxaVZmNt2V5kotPJmlBd
# AfugghhlMIIEwzCCA6ugAwIBAgITMwAAAMWWQGBL9N6uLgAAAAAAxTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODUy
# WhcNMTgwOTA3MTc1ODUyWjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkMwRjQtMzA4Ni1ERUY4MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtrwz4CWOpvnw
# EBVOe1crKElrs3CQl/yun1cdkpugh/MxsuoGn7BL43GRTxRn7sPD7rq1Dxj4smPl
# gVZr/ZhGMA8J3zXOqyIcD4hYFikXuhlGuuSokunCAxUl5N4gjN/M7+NwJPm2JtYK
# ZLBdH5J/y+GIk7rQhpgbstpLOZf4GHgC8Myji7089O1uX2MCKFFU+wt2Y560O4Xc
# 2NVjeuG+nnq5pGyq9111nK3f0DeT7FWjDVQWFghKOhyeBb4iMhmkdA8vWpYmx6TN
# c+d35nSZcLc0EhSIVJkzEBYfwkrzxFaG/pgNJ9C4jm/zHgwWLZwQpU7K2fP15fGk
# BGplwNjr1wIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFA4B9X87yXgCWEZxOwn8mnVX
# hjjEMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAAUS3tgSEzCpyuw21ySUAWvGltQxunyLUCaOf1dffUcG25oa
# OW/WuIFJs0lv8Py6TsOrulsx/4NTkIyXra/MsJvwczMX2s/vx6g63O3osQI85qHD
# dp8IMULGmry+oqPVTuvL7Bac905EqqGXGd9UY7y14FcKWBWJ28vjncTw8CW876pY
# 80nSm8hC/38M4RMGNEp7KGYxx5ZgGX3NpAVeUBio7XccXHEy7CSNmXm2V8ijeuGZ
# J9fIMkhiAWLEfKOgxGZ63s5yGwpMt2QE/6Py03uF+X2DHK76w3FQghqiUNPFC7uU
# o9poSfArmeLDuspkPAJ46db02bqNyRLP00bczzwwggYHMIID76ADAgECAgphFmg0
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
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFEkthEi8jx9r1yZfz8OwDboy/26lMIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEAYudVLadUc67tmHhugjxpNsPFa96VygOP
# bokKMwkmzebDfRtfZR9wdcAG63QjIdCPLFU1dSS28/h4DX4UZaznSOVFD7VJGmZj
# OBveaCF/5f0N4E855xD4dJJ1Ak94+MRJknANFGyDyH6bq5AjB3hEN9DgwUahL4cb
# EhpguLchT8dnT/KUE7uG24Nry9bF628/lTtaSS2zQ/0auQxvSPrgm6W2w6Fsyv9D
# T9cxLRZhU1iMqXlkyKLXas49fmZjFPmsKfq1vlIHuhOSjvCQNnydri0JT8n0wy7d
# RohvPkQXTrSNad7qNWhme9nPeMmvO//RaGJfZZfsHS7rEa5SEd142qGCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADFlkBgS/Teri4AAAAAAMUwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxM1owIwYJ
# KoZIhvcNAQkEMRYEFD6tlHxkY7mNE9Kkol1Bh/IX1kPTMA0GCSqGSIb3DQEBBQUA
# BIIBAGjiMpnkOl/w13RcFJfjo9bCAU22w6NUiBt/G+8cuV2JRymkyVwgI+YOBZQ5
# eRiAUFL/lb2KT8vsQjsNWRi3iTlcCjnHPxaKw5rKGsRyHy7Sm1IvO5dL/wx//YgB
# v1q0yqe79OY/pa3FQfsl7EYUFA+ODUR+HHkiN0IXE+tFP4J5Kh3ReMrjlO7/TJda
# kfHP8SUMWCpgX0r0cmXlFg7eH1M91s9EDNpvL238WTp0p1AyH+AxFAtOm3Sdlg1W
# hJJcSqIGaEf94SwUfSSKtp1evkMHmXH9zR/Dfk4wvC6CLOYgwXyxkkN30aZ8hmwN
# 5zJ73g5KYh12fPfWD8LVuRCe6CI=
# SIG # End signature block
