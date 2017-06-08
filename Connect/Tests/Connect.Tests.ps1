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

        It 'Register-AzSProvidersOnAllSubscriptions should be exported' {
            Get-Command -Name Register-AzSProvidersOnAllSubscriptions -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }

        It 'Register-AzSProviders should be exported' {
            Get-Command -Name Register-AzSProviders -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }

        It 'Get-AzsAADTenant should be exported' {
            Get-Command -Name Get-AzsAADTenant -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
        
        It 'Add-AzSEnvironment should be exported' {
            Get-Command -Name Add-AzSEnvironment -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    
        It 'Get-AzSNatServerAddress should be exported' {
            Get-Command -Name Get-AzSNatServerAddress -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    
        It 'Add-AzSVpnConnection should be exported' {
            Get-Command -Name Add-AzSVpnConnection -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    
        It 'Connect-AzSVpn should be exported' {
            Get-Command -Name Connect-AzSVpn -ErrorAction SilentlyContinue | 
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
    Set-Item wsman:\localhost\Client\TrustedHosts -Value azs-ca01.azurestack.local -Concatenate

    Describe 'ConnectModule - Accessing Environment Data' {
        It 'Recovered AAD Tenant ID should be correct' {
            $global:AadTenantID = Get-AzsAADTenant  -HostComputer $HostComputer -User $AdminUser -Password $AdminPassword 
            Write-Verbose "Aad Tenant ID is $global:AadTenantID" -Verbose
            $global:AadTenantID | Should Not Be $null
        }

        It 'Get-AzSNatServerAddress should return valid NAT address' {
            $script:NatIPAddress = Get-AzSNatServerAddress -natServer $natServer -HostComputer $HostComputer -User $AdminUser -Password $AdminPassword 
            Write-Verbose "Returned NAT IP Address of $natIPAddress" -Verbose
            [IPAddress]$script:NatIPAddress | Should Not Be $null
        }

        It 'Add-AzSVpnConnection should correctly return a VPN connection to a One Node' {
            Add-AzSVpnConnection -ServerAddress $script:NatIPAddress -ConnectionName $VPNConnectionName -Password $AdminPassword
            Get-VpnConnection -Name $VPNConnectionName | Should Not Be $null
        }

        It 'Connect-AzSVpn should successfully connect to a One Node environment' {
            {Connect-AzSVpn -ConnectionName $VPNConnectionName -User $AdminUser -Password $AdminPassword} | Should Not Throw
        }

        It 'Add-AzSEnvironment should successfully add a an administrator environment' {
            Add-AzSEnvironment -ArmEndpoint $armEndpoint -Name $EnvironmentName
            Get-AzureRmEnvironment -Name $EnvironmentName | Should Not Be $null
        }

        It 'User should be able to login to environment successfully created by Add-AzSEnvironment' {
            Write-Verbose "Aad Tenant ID is $global:AadTenantID" -Verbose
            Write-Verbose "Passing credential to Login-AzureRmAccount" -Verbose
            {Login-AzureRmAccount -EnvironmentName $EnvironmentName -TenantId $global:AadTenantID -Credential $global:AzureStackLoginCredentials} | Should Not Throw
        }

        It 'User should be able to list resource groups successfully in connected Azure Stack' {
            Get-AzureRmResourceGroup | Should Not Be $null
        }

        It 'Get-AzSAdminSubTokenheader should retrieve a valid admin token' {
            $subID, $headers = Get-AzSAdminSubTokenheader -TenantID $global:AadTenantID -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds 
            Write-Verbose "Admin subscription ID was $subID" -Verbose
            Write-Verbose "Acquired token was $headers.Authorization" -Verbose
            $headers.Authorization | Should Not Be $null
            $subID | Should Not Be $null
        }

        It 'Register-AzSProviders should register all resource providers for the current subscription' {
            Register-AzSProviders 
            $unRegisteredProviders = Get-AzureRmResourceProvider | Where-Object {$_.RegistrationState -ne "Registered"}
            $unRegisteredProviders | Should Be $null
        }

        It 'Register-AzSProvidersOnAllSubscriptions should register all resource providers for all subscriptions' {
            Register-AzSProvidersOnAllSubscriptions
            $unRegisteredProviders = Get-AzureRmResourceProvider | Where-Object {$_.RegistrationState -ne "Registered"}
            $unRegisteredProviders | Should Be $null
        }

    }
}
