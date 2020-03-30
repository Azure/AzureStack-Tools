$ModuleName = 'AzureStack.Connect'
$ModuleImportFile = 'AzureStack.Connect.psm1'

$NatIPAddress = $null

$ModuleRoot = (Resolve-Path $PSScriptRoot\..).Path
Import-Module $script:ModuleRoot\$script:ModuleImportFile -Force

Describe $script:ModuleName {
    Context 'Module should be imported correctly' {
        It "$script:ModuleName module is imported" {
            Get-Module -Name $script:ModuleName |
                Should Not Be $null
        }
        
        It 'Add-AzsEnvironment should be exported' {
            Get-Command -Name Add-AzsEnvironment -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    
        It 'Add-AzsVpnConnection should be exported' {
            Get-Command -Name Add-AzsVpnConnection -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    
        It 'Connect-AzsVpn should be exported' {
            Get-Command -Name Connect-AzsVpn -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    }
}

InModuleScope $script:ModuleName {

    
    $HostComputer = $global:HostComputer
    $armEndpoint = $global:ArmEndpoint
    $natServer = $global:natServer 
    $AdminUser= $global:AdminUser 
    $AadServiceAdmin = $global:AadServiceAdmin 

    $AdminPassword = $global:AdminPassword
    $AadServiceAdminPassword = $global:AadServiceAdminPassword
    $stackLoginCreds = $global:AzureStackLoginCredentials

    $VPNConnectionName = $global:VPNConnectionName

    $EnvironmentName = $global:EnvironmentName

    Set-Item wsman:\localhost\Client\TrustedHosts -Value $HostComputer -Concatenate
    Set-Item wsman:\localhost\Client\TrustedHosts -Value Azs-ca01.azurestack.local -Concatenate

    Describe 'ConnectModule - Accessing Environment Data' {

        It 'Add-AzsVpnConnection should correctly return a VPN connection to a One Node' {
            Add-AzsVpnConnection -ServerAddress $script:NatIPAddress -ConnectionName $VPNConnectionName -Password $AdminPassword
            Get-VpnConnection -Name $VPNConnectionName | Should Not Be $null
        }

        It 'Connect-AzsVpn should successfully connect to a One Node environment' {
            {Connect-AzsVpn -ConnectionName $VPNConnectionName -User $AdminUser -Password $AdminPassword} | Should Not Throw
        }

        It 'Add-AzsEnvironment should successfully add a an administrator environment' {
            Add-AzsEnvironment -ArmEndpoint $armEndpoint -Name $EnvironmentName
            Get-AzEnvironment -Name $EnvironmentName | Should Not Be $null
        }

        It 'User should be able to login to environment successfully created by Add-AzsEnvironment' {
            Write-Verbose "Aad Tenant ID is $global:AadTenantID" -Verbose
            Write-Verbose "Passing credential to Login-AzureRmAccount" -Verbose
            {Login-AzAccount -EnvironmentName $EnvironmentName -TenantId $global:AadTenantID -Credential $global:AzureStackLoginCredentials} | Should Not Throw
        }

        It 'User should be able to list resource groups successfully in connected Azure Stack' {
            Get-AzResourceGroup | Should Not Be $null
        }

        It 'Get-AzsAdminSubTokenheader should retrieve a valid admin token' {
            $subID, $headers = Get-AzsAdminSubTokenheader -TenantID $global:AadTenantID -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds 
            Write-Verbose "Admin subscription ID was $subID" -Verbose
            Write-Verbose "Acquired token was $headers.Authorization" -Verbose
            $headers.Authorization | Should Not Be $null
            $subID | Should Not Be $null
        }

        It 'Register-AzsProvider should register all resource providers for the current subscription' {
            Register-AzsProvider 
            $unRegisteredProviders = Get-AzResourceProvider | Where-Object {$_.RegistrationState -ne "Registered"}
            $unRegisteredProviders | Should Be $null
        }

        It 'Register-AzsProviderOnAllSubscriptions should register all resource providers for all subscriptions' {
            Register-AzsProviderOnAllSubscriptions
            $unRegisteredProviders = Get-AzResourceProvider | Where-Object {$_.RegistrationState -ne "Registered"}
            $unRegisteredProviders | Should Be $null
        }

    }
}
