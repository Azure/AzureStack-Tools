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

        It 'Get-AzureStackAlert should be exported' {
            Get-Command -Name Get-AzureStackAlert -ErrorAction SilentlyContinue | 
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



    Describe 'Infra - Functional Tests' {
        It 'Get-AzureStackAlert should not throw' {
            { Get-AzureStackAlert -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzureStackScaleUnit should not throw' {
            { Get-AzureStackAlert -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzureStackNode should not throw' {
            { Get-AzureStackNode -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzureStackStorageCapacity should not throw' {
            { Get-AzureStackStorageCapacity -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzureStackInfraRole should not throw' {
            { Get-AzureStackInfraRole -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzureStackInfraVM should not throw' {
            { Get-AzureStackInfraVM -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzureStackStorageShare should not throw' {
            { Get-AzureStackStorageShare -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzureStacklogicalnetwork should not throw' {
            { Get-AzureStacklogicalnetwork -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        
        It 'Get-AzureStackUpdateSummary should not throw' {
            { Get-AzureStackUpdateSummary -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }
        It 'Get-AzureStackUpdate should not throw' {
            { Get-AzureStackUpdate -TenantID $AadTenant -ArmEndpoint $global:ArmEndpoint -AzureStackCredentials $stackLoginCreds } |
                Should Not Throw
        }


    }
    

}