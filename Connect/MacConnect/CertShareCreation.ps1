
$NatVMName = "MAS-BGPNAT01"
$RemoteCA = "MAS-CA01"
$Domain = "AzureStack.local"
$cred = Get-Credential AzureStack\Administrator
$sharePath = "C:\CertificateShare"
$shareName = "CertificateShare"


Invoke-Command -ComputerName "$NatVMName.$Domain"  -Credential $cred -ScriptBlock `
{ 
    Write-Host "Obtaining external NAT IP address..." -Verbose
    Get-NetIPConfiguration | ? { $_.IPv4DefaultGateway -ne $null } | foreach { $_.IPv4Address.IPAddress }
}



Write-Verbose "Retrieving Azure Stack Root Authority certificate..." -Verbose
$cert = Invoke-Command -ComputerName "$RemoteCA.$Domain" -ScriptBlock { Get-ChildItem cert:\currentuser\root | where-object {$_.Subject -eq "CN=AzureStackCertificationAuthority, DC=AzureStack, DC=local"} } -Credential $cred

if($cert -ne $null)
{

    if($cert.GetType().IsArray)

    {

        $cert = $cert[0] # take any that match the subject if multiple certs were deployed

    }

    

    New-Item $sharePath -type directory

    New-SmbShare -Name CertificateShare -Path $sharePath -Description 'Share created to share certificates to external clients.' -FullAccess "AzureStack\Administrator" 

    $certFilePath = "$sharePath\CA.cer"



    Write-Verbose "Saving Azure Stack Root certificate in $certFilePath..." -Verbose

    Export-Certificate -Cert $cert -FilePath $certFilePath -Force | Out-Null


}

else

{

    Write-Error "Certificate has not been retrieved!"

} 
