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

        It 'Add-AzsTenantOfferAndQuotas should be exported' {
            Get-Command -Name Add-AzsTenantOfferAndQuotas -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }

    }
}

InModuleScope $script:ModuleName {

    Describe 'ServiceAdmin - Functional Tests' {
        It 'Add-AzsTenantOfferAndQuota should create Quotas, Plan and Offer' {
            { Add-AzsTenantOfferAndQuotas } |
                Should Not Throw
        }

    }
}
