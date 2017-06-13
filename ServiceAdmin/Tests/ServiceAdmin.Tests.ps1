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

        It 'Add-AzSTenantOfferAndQuota should be exported' {
            Get-Command -Name Add-AzSTenantOfferAndQuotas -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }

    }
}

InModuleScope $script:ModuleName {

    Describe 'ServiceAdmin - Functional Tests' {
        It 'Add-AzSTenantOfferAndQuota should create Quotas, Plan and Offer' {
            { Add-AzSTenantOfferAndQuotas } |
                Should Not Throw
        }

    }
}