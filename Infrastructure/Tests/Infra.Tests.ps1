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

        It 'Get-AzsAlert should be exported' {
            Get-Command -Name Get-AzsAlert -ErrorAction SilentlyContinue |
                Should Not Be $null
        }
    }
}

InModuleScope $script:ModuleName {

    $HostComputer = $global:HostComputer
    $ArmEndpoint = $global:ArmEndpoint
    $natServer = $global:natServer
    $AdminUser = $global:AdminUser
    $AadServiceAdmin = $global:AadServiceAdmin

    $AdminPassword = $global:AdminPassword
    $AadServiceAdminPassword = $global:AadServiceAdminPassword
    $VPNConnectionName = $global:VPNConnectionName
    $EnvironmentName = $global:EnvironmentName

    Describe 'Infra - Functional Tests' {
        It 'Get-AzsAlert should not throw' {
            { Get-AzsAlert } |
                Should Not Throw
        }
        It 'Get-AzsScaleUnit should not throw' {
            { Get-AzsAlert } |
                Should Not Throw
        }
        It 'Get-AzsScaleUnitNode should not throw' {
            { Get-AzsScaleUnitNode } |
                Should Not Throw
        }
        It 'Get-AzsStorageSubsystem should not throw' {
            { Get-AzsStorageSubsystem } |
                Should Not Throw
        }
        It 'Get-AzsInfraRole should not throw' {
            { Get-AzsInfraRole } |
                Should Not Throw
        }
        It 'Get-AzsInfraRoleInstance should not throw' {
            { Get-AzsInfraRoleInstance } |
                Should Not Throw
        }
        It 'Get-AzsInfrastructureShare should not throw' {
            { Get-AzsInfrastructureShare } |
                Should Not Throw
        }
        It 'Get-Azslogicalnetwork should not throw' {
            { Get-Azslogicalnetwork } |
                Should Not Throw
        }
        It 'Get-AzsUpdateLocation should not throw' {
            { Get-AzsUpdateLocation } |
                Should Not Throw
        }
        It 'Get-AzsUpdate should not throw' {
            { Get-AzsUpdate } |
                Should Not Throw
        }

    }


}
