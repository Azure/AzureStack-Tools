# Install-Module -Name AzureRM -RequiredVersion 1.2.8 -Scope CurrentUser

$Authority = "https://login.windows.net/"
$directoryTenantId = "iaad1.onmicrosoft.com"
$GuestTenantName = "redmarker.onmicrosoft.com"
$ArmEndpoint = "Https://adminmanagement.local.azurestack.external"

$GuestTenantId = $(Invoke-RestMethod $("{0}/{1}/.well-known/openid-configuration" -f $Authority.TrimEnd('/'), $GuestTenantName.TrimEnd('/'))).issuer.TrimEnd('/').Split('/')[-1]

Set-Alias `
    -Name "Initialize-AzurePowerShellEnvironment" `
    -Value "$PSScriptRoot\AzurePowerShell\Initialize-AzurePowerShellEnvironment.ps1"

# Init AzureStack environent
if (-not (Get-AzureRmEnvironment -Name "AzureStack-Admin"))
{
    Initialize-AzurePowerShellEnvironment `
        -ResourceManagerEndpoint $ArmEndpoint  `
        -DirectoryTenantId $directoryTenantId `
        -Name "AzureStack-Admin"
}

# Onboard a new tenant
New-AzureRmResource `
    -Location "local" `
    -ResourceGroupName "system" `
    -ResourceType "Microsoft.Subscriptions.Admin/directoryTenants" `
    -ResourceName $GuestTenantName `
    -Properties @{ tenantId = $GuestTenantId }

Get-AzureRmResource `
    -ResourceGroupName "system" `
    -ResourceType "Microsoft.Subscriptions.Admin/directoryTenants" `
    -IsCollection