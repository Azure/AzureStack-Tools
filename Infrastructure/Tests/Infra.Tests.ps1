$ModuleName = 'AzureStack.Infra'
$ModuleImportFile = 'AzureStack.Infra.psm1'

$ModuleRoot = (Resolve-Path $PSScriptRoot\..).Path
Import-Module $script:ModuleRoot\$script:ModuleImportFile -Force

Describe $script:ModuleName {
    Context 'Module should be imported correctly' {
        It "$script:ModuleName module is imported" {
            Get-Module -Name $script:ModuleName |
                Should Not Be $null
        }

        It 'Get-AzSAlert should be exported' {
            Get-Command -Name Get-AzSAlert -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    }
}

InModuleScope $script:ModuleName {

    $HostComputer = $global:HostComputer
    $ArmEndpoint = $global:ArmEndpoint
    $natServer = $global:natServer 
    $AdminUser= $global:AdminUser 
    $AadServiceAdmin = $global:AadServiceAdmin 

    $AdminPassword = $global:AdminPassword
    $AadServiceAdminPassword = $global:AadServiceAdminPassword
    $stackLoginCreds = $global:AzureStackLoginCredentials

    $VPNConnectionName = $global:VPNConnectionName

    $AadTenant = $global:AadTenantID

    $EnvironmentName = $global:EnvironmentName



    Describe 'Infra - Functional Tests' {
        It 'Get-AzSAlert should not throw' {
            { Get-AzSAlert -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzSScaleUnit should not throw' {
            { Get-AzSAlert -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzSScaleUnitNode should not throw' {
            { Get-AzSScaleUnitNode -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzSStorageCapacity should not throw' {
            { Get-AzSStorageCapacity -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzSInfraRole should not throw' {
            { Get-AzSInfraRole -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzSInfraRoleInstance should not throw' {
            { Get-AzSInfraRoleInstance -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzSStorageShare should not throw' {
            { Get-AzSStorageShare -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzSlogicalnetwork should not throw' {
            { Get-AzSlogicalnetwork -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        
        It 'Get-AzSUpdateSummary should not throw' {
            { Get-AzSUpdateSummary -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzSUpdate should not throw' {
            { Get-AzSUpdate -TenantID $AadTenant -EnvironmentName $EnvironmentName -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }


    }
    

}