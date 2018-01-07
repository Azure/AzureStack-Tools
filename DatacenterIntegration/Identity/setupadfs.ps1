# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information. 

<#
 
.SYNOPSIS 
 
Configures existing AD FS for Azure Stack
 
.DESCRIPTION 
 
It will create a relying Party Trust to Azure Stack's AD FS with the necessary rules. It will also turn on form based authentication and Enable as setting to support Edge
 
.PARAMETER ExternalDNSZoneSpecify the Extnerl Dns Zone of Azure Stack which was also provided for initial deployment.EXAMPLE .\setupadfs.ps1 -externaldnszone local.azurestack.external#>Param(  [string]$ExternalDNSZone)
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

#Determine Windows Version
$WindowsVersion= [environment]::OSVersion.Version

#Configure Relying Party Trust
If ($WindowsVersion.Build -lt 14393) {

#Must be 2012 or 2012 R2 
Add-ADFSRelyingPartyTrust -Name AzureStack -MetadataUrl $MetadataURL -IssuanceTransformRulesFile ($currentPath + '\claimrules.txt') -AutoUpdateEnabled:$true -MonitoringEnabled:$true -enabled:$true
}
else{
#Must be 2016
Add-ADFSRelyingPartyTrust -Name AzureStack -MetadataUrl $MetadataURL -IssuanceTransformRulesFile ($currentPath + '\claimrules.txt') -AutoUpdateEnabled:$true -MonitoringEnabled:$true -enabled:$true -AccessControlPolicyName “Permit everyone”


#Enable Form Based Authentication
Set-AdfsProperties -WIASupportedUserAgents @("MSAuthHost/1.0/In-Domain","MSIPC","Windows Rights Management Client","Kloud")

#Enable Supprt for Edge Browser
Set-AdfsProperties -IgnoreTokenBinding $true

#Enable Refresh Token
Set-ADFSRelyingPartyTrust -TargetName AzureStack -TokenLifeTime 1440
}
}
}