$ModuleName = 'AzureStack.GalleryAdmin'
$ModuleImportFile = 'AzureStack.GalleryAdmin.psm1'

$ModuleRoot = (Resolve-Path $PSScriptRoot\..).Path
Import-Module $script:ModuleRoot\$script:ModuleImportFile -Force

Describe $script:ModuleName {
    Context 'Module should be imported correctly' {
        It "$script:ModuleName module is imported" {
            Get-Module -Name $script:ModuleName |
                Should Not Be $null
        }

        It 'Get-AzureRMGalleryItemContent should be exported' {
            Get-Command -Name Get-AzureRMGalleryItemContent -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    }
}

InModuleScope $script:ModuleName {

    $GetGalleryItemContentArgs = @{
        GalleryItemName = 'TestName'
        azureStackDomain = 'azurestack.local'
        location = 'local'
        tenantID = 'TestTenantId.onmicrosoft.com'
        azureStackCredentials = [pscredential]::new('testuser',(ConvertTo-SecureString -String 'testpass' -AsPlainText -Force))
    }



    Describe 'Parameter tests' {
        It 'TargetDirectory does not exist should throw' {
            { Get-AzureRMGalleryItemContent @GetGalleryItemContentArgs -TargetDirectory "C:\MissingDirectory"} |
                Should Throw
        }

        It 'TargetDirectory is not a directory should throw' {
            { Get-AzureRMGalleryItemContent @GetGalleryItemContentArgs -TargetDirectory $PSCommandPath } |
                Should Throw
        }

        New-Item -Path $env:TEMP -Name $GalleryItemName -ItemType Directory
        New-Item -Path $env:Temp\$galleryitemname -Name "TestItem.txt" -ItemType File

        It 'TargetDirectory is not empty, and Force not used should throw' {
            { Get-AzureRMGalleryItemContent @GetGalleryItemContentArgs -TargetDirectory $env:TEMP }
        }

        Remove-Item -Path $env:TEMP\$galleryitemname -Recurse -Force
    }
}