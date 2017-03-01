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

        It 'Register-AllAzureRmProvidersOnAllSubscriptions should be exported' {
            Get-Command -Name Register-AllAzureRmProvidersOnAllSubscriptions -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }

        It 'Register-AllAzureRmProviders should be exported' {
            Get-Command -Name Register-AllAzureRmProviders -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }

        It 'Get-AzureStackAadTenant should be exported' {
            Get-Command -Name Get-AzureStackAadTenant -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
        
        It 'Add-AzureStackAzureRmEnvironment should be exported' {
            Get-Command -Name Add-AzureStackAzureRmEnvironment -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    
        It 'Get-AzureStackNatServerAddress should be exported' {
            Get-Command -Name Get-AzureStackNatServerAddress -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    
        It 'Add-AzureStackVpnConnection should be exported' {
            Get-Command -Name Add-AzureStackVpnConnection -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    
        It 'Connect-AzureStackVpn should be exported' {
            Get-Command -Name Connect-AzureStackVpn -ErrorAction SilentlyContinue | 
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

    Set-Item wsman:\localhost\Client\TrustedHosts -Value $HostComputer -Concatenate
    Set-Item wsman:\localhost\Client\TrustedHosts -Value mas-ca01.azurestack.local -Concatenate

    Describe 'ConnectModule - Accessing Environment Data' {
        It 'Recovered AAD Tenant ID should be correct' {
            $global:AadTenantID = Get-AzureStackAadTenant  -HostComputer $HostComputer -ArmEndpoint $armEndpoint -User $AdminUser -Password $AdminPassword 
            Write-Verbose "Aad Tenant ID is $global:AadTenantID" -Verbose
            $global:AadTenantID | Should Not Be $null
        }

        It 'Get-AzureStackNatServerAddress should return valid NAT address' {
            $script:NatIPAddress = Get-AzureStackNatServerAddress -natServer $natServer -HostComputer $HostComputer -ArmEndpoint $armEndpoint -User $AdminUser -Password $AdminPassword 
            Write-Verbose "Returned NAT IP Address of $natIPAddress" -Verbose
            [IPAddress]$script:NatIPAddress | Should Not Be $null
        }

        It 'Add-AzureStackVpnConnection should correctly return a VPN connection to a One Node' {
            Add-AzureStackVpnConnection -ServerAddress $script:NatIPAddress -ConnectionName $VPNConnectionName -Password $AdminPassword
            Get-VpnConnection -Name $VPNConnectionName | Should Not Be $null
        }

        It 'Connect-AzureStackVpn should successfully connect to a One Node environment' {
            {Connect-AzureStackVpn -ConnectionName $VPNConnectionName -User $AdminUser -ArmEndpoint $armEndpoint -Password $AdminPassword} | Should Not Throw
        }

        It 'Add-AzureStackAzureRmEnvironment should successfully add a One Node environment' {
            Remove-AzureRmEnvironment -Name "AzureStack" -ErrorAction SilentlyContinue -Force
            Add-AzureStackAzureRmEnvironment -AadTenant $global:AadTenantID -ArmEndpoint $armEndpoint
            Get-AzureRmEnvironment -Name "AzureStack" | Should Not Be $null
        }

        It 'User should be able to login to environment successfully created by Add-AzureStackAzureRmEnvironment' {
            Write-Verbose "Aad Tenant ID is $global:AadTenantID" -Verbose
            Write-Verbose "Passing credential to Login-AzureRmAccount" -Verbose
            {Login-AzureRmAccount -EnvironmentName "AzureStack" -TenantId $global:AadTenantID -Credential $global:AzureStackLoginCredentials} | Should Not Throw
        }

        It 'User should be able to list resource groups successfully in connected Azure Stack' {
            Get-AzureRmResourceGroup | Should Not Be $null
        }

        It 'Get-AzureStackAdminSubTokenHeader should retrieve a valid admin token' {
            $subID, $headers = Get-AzureStackAdminSubTokenHeader -TenantID $global:AadTenantID -ArmEndpoint $armEndpoint -AzureStackCredentials $stackLoginCreds 
            Write-Verbose "Admin subscription ID was $subID" -Verbose
            Write-Verbose "Acquired token was $headers.Authorization" -Verbose
            $headers.Authorization | Should Not Be $null
            $subID | Should Not Be $null
        }

        It 'Register-AllAzureRmProviders should register all resource providers for the current subscription' {
            Register-AllAzureRmProviders 
            $unRegisteredProviders = Get-AzureRmResourceProvider | Where-Object {$_.RegistrationState -ne "Registered"}
            $unRegisteredProviders | Should Be $null
        }

        It 'Register-AllAzureRmProvidersOnAllSubscriptions should register all resource providers for all subscriptions' {
            Register-AllAzureRmProvidersOnAllSubscriptions
            $unRegisteredProviders = Get-AzureRmResourceProvider | Where-Object {$_.RegistrationState -ne "Registered"}
            $unRegisteredProviders | Should Be $null
        }

    }
}