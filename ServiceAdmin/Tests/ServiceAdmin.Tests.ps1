$ModuleName = 'AzureStack.ServiceAdmin'
$ModuleImportFile = 'AzureStack.ServiceAdmin.psm1'

$ModuleRoot = (Resolve-Path $PSScriptRoot\..).Path
Import-Module $script:ModuleRoot\$script:ModuleImportFile -Force

Describe $script:ModuleName {
    Context 'Module should be imported correctly' {
        It "$script:ModuleName module is imported" {
            Get-Module -Name $script:ModuleName |
                Should Not Be $null
        }

        It 'New-AzSTenantOfferAndQuotas should be exported' {
            Get-Command -Name New-AzSTenantOfferAndQuotas -ErrorAction SilentlyContinue | 
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

    Describe 'ServiceAdmin - Functional Tests' {
        It 'New-AzSTenantOfferAndQuotas should create Quotas, Plan and Offer' {
            { New-AzSTenantOfferAndQuotas -tenantID $AadTenant -AzureStackCredential $stackLoginCreds -EnvironmentName $EnvironmentName } |
                Should Not Throw
        }

    }
}