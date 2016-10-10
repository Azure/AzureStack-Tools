$ModuleName = 'AzureStack.ComputeAdmin'
$ModuleImportFile = 'AzureStack.ComputeAdmin.psm1'

$ModuleRoot = (Resolve-Path $PSScriptRoot\..).Path
Import-Module $script:ModuleRoot\$script:ModuleImportFile -Force

Describe $script:ModuleName {
    Context 'Module should be imported correctly' {
        It "$script:ModuleName module is imported" {
            Get-Module -Name $script:ModuleName |
                Should Not Be $null
        }

        It 'Add-VMImage should be exported' {
            Get-Command -Name Add-VMImage -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }

        It 'Remove-VMImage should be exported' {
            Get-Command -Name Add-VMImage -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    }
}

InModuleScope $script:ModuleName {

    $AddVMImageArgs = @{
        publisher = 'Testing'
        offer = 'Test'
        sku = '2016'
        version = '1.0.0'
        osType = 'Windows'
        osDiskLocalPath = '.\Test.vhd'
        tenantID = 'TestTenantId.onmicrosoft.com'
        azureStackCredentials = [pscredential]::new('testuser',(ConvertTo-SecureString -String 'testpass' -AsPlainText -Force))
    }

    Describe 'Parameter combinations' {
        It 'CreateGalleryItem = "$false" -and title = specified should throw' {
            { Add-VMImage @AddVMImageArgs -CreateGalleryItem $false -title 'testTitle' } |
                Should Throw
        }

        It 'CreateGalleryItem = "$false" -and description = specified should throw' {
            { Add-VMImage @AddVMImageArgs -CreateGalleryItem $false -description 'testdescription' } |
                Should Throw
        }
    }
}