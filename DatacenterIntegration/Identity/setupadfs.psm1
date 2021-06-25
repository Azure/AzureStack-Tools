 # Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information. 

<#
 
.SYNOPSIS 
 
Configures existing AD FS for Azure Stack
 
.DESCRIPTION 
 
It will create a relying Party Trust to Azure Stack's AD FS with the necessary rules. It will also turn on form based authentication and Enable as setting to support Edge
 
.PARAMETER ExternalDNSZone
Specify the Extnerl Dns Zone of Azure Stack which was also provided for initial deployment
.EXAMPLE
import-module setupadfs.psm1 
register-adfs -externaldnszone local.azurestack.external
#>
 
Function Test-RegistryValue {
  param(
      [Alias("PSPath")]
      [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
      [String]$Path
      ,
      [Parameter(Position = 1, Mandatory = $true)]
      [String]$Name
      ,
      [Switch]$PassThru
  ) 

  process {
      if (Test-Path $Path) {
          $Key = Get-Item -LiteralPath $Path
          if ($Key.GetValue($Name, $null) -ne $null) {
              if ($PassThru) {
                  Get-ItemProperty $Path $Name
              } else {
                  $true
              }
          } else {
              $false
          }
      } else {
          $false
      }
  }
}


function register-adfs {
Param(  
[string] $ExternalDNSZone
)


$currentPath = $PSScriptRoot

#Create Endpoint
$VIP="adfs.$ExternalDnsZone"

#Verify if Endpoint is reachable
Write-Host "Validate AD FS Endpoint if reachable"
$Validator1=Test-NetConnection -ComputerName $VIP -Port 443
IF ($Validator1.TcpTestSucceeded -ne $true){
Write-Host "Check you DNS Integration with Azure Stack Error "$Validator1.TcpTestSucceeded ""
Exit}
else{
Write-host "Status "$Validator1.TcpTestSucceeded""
#Create Metadata URL
$MetadataURL= "https://$VIP/FederationMetadata/2007-06/FederationMetadata.xml"

#Verify Metadata URL
Write-Host "Validate AD FS Metadata URL"
$Validator2=Invoke-WebRequest $MetadataURL
If ($Validator2.StatusCode -ne 200){
Write-Host "Metadata URL could not be retrived Error "$Validator2.StatusCode""
Exit}
else{
Write-Host "Status "$Validator2.StatusCode""


#Validate if TLS1.2 is enabled

$Key1=Test-RegistryValue -path HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727 -Name "SchUseStrongCrypto"
$Key2=Test-RegistryValue -path HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319 -Name "SchUseStrongCrypto"
$Key3=Test-RegistryValue -path HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319 -Name "SchUseStrongCrypto"
$Key4=Test-RegistryValue -path HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v2.0.50727 -Name "SchUseStrongCrypto"

If ($Key1 -eq "false"){
  Write-Host "TLS1.2 is not enabled please see https://docs.microsoft.com/en-US/troubleshoot/windows-server/identity/disable-and-replace-tls-1dot0"
Exit}

elseif ($Key2 -eq "false") {
  Write-Host "TLS1.2 is not enabled please see https://docs.microsoft.com/en-US/troubleshoot/windows-server/identity/disable-and-replace-tls-1dot0"
Exit}

elseif ($Key3 -eq "false") {
  Write-Host "TLS1.2 is not enabled please see https://docs.microsoft.com/en-US/troubleshoot/windows-server/identity/disable-and-replace-tls-1dot0"
Exit}

elseif ($Key4 -eq "false") {
  Write-Host "TLS1.2 is not enabled please see https://docs.microsoft.com/en-US/troubleshoot/windows-server/identity/disable-and-replace-tls-1dot0"
Exit}


#Determine Windows Version
$WindowsVersion= [environment]::OSVersion.Version

#Configure Relying Party Trust
If ($WindowsVersion.Build -lt 14393) {

#Must be 2012 or 2012 R2 
Add-ADFSRelyingPartyTrust -Name AzureStack -MetadataUrl $MetadataURL -IssuanceTransformRulesFile ($currentPath + '\claimrules.txt') -AutoUpdateEnabled:$true -MonitoringEnabled:$true -enabled:$true -TokenLifeTime 1440
}
else{
#Must be 2016 or 2019
Add-ADFSRelyingPartyTrust -Name AzureStack -MetadataUrl $MetadataURL -IssuanceTransformRulesFile ($currentPath + '\claimrules.txt') -AutoUpdateEnabled:$true -MonitoringEnabled:$true -enabled:$true -AccessControlPolicyName “Permit everyone” -TokenLifeTime 1440

#Enable Supprt for Edge Browser
Set-AdfsProperties -IgnoreTokenBinding $true

}
}
}
}
Export-ModuleMember -Function * -Alias *