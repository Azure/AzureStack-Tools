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

        It 'Add-AzSVMImage should be exported' {
            Get-Command -Name Add-AzSVMImage -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }

        It 'Remove-AzSVMImage should be exported' {
            Get-Command -Name Remove-AzSVMImage -ErrorAction SilentlyContinue | 
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

    # Generate Fake VHD for testing image upload
    $osDiskPath = ".\osDisk_1.vhd"
    $dataDiskPath = ".\dataDisk_1.vhd"
    $ubuntuPath = ".\ubuntu-16.04-server-cloudimg-amd64-disk1.vhd"
    New-VHD -Path $ubuntuPath -Fixed -SizeBytes 5MB
    New-VHD -Path $osDiskPath -Fixed -SizeBytes 5MB
    New-VHD -Path $dataDiskPath -Fixed -SizeBytes 5MB

    
    $publisher = 'Microsoft'
    $offer = 'Azure'
    $sku = 'StackToolTest'
    $version = '1.0.4'
    $osType = 'Windows'
    $gallerySku = 'StackToolGalleryTest'

    Describe 'ComputeAdmin - Functional Tests' {
        It 'CreateGalleryItem = "$false" -and title = specified should throw' {
            { Add-AzSVMImage -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -osDiskLocalPath $osDiskPath -CreateGalleryItem $false -title 'testTitle' } |
                Should Throw
        }

        It 'CreateGalleryItem = "$false" -and description = specified should throw' {
            { Add-AzSVMImage -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -osDiskLocalPath $osDiskPath -CreateGalleryItem $false -title 'testTitle'  -CreateGalleryItem $false -description 'testdescription' } | Should Throw
        }

        It 'Add-AzSVMImage via local path and upload to storage account should succeed' {
            { Add-AzSVMImage -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -osDiskLocalPath $osDiskPath -CreateGalleryItem $false } |
                Should Not Throw
        }

        It 'Remove-AzSVMImage should successfully remove added VM Image' {
            { Remove-AzSVMImage -publisher $publisher -offer $offer -sku $sku -version $version} |
                Should Not Throw
        }

        It 'Add-AzSVMImage via local path and upload to storage account with gallery item should succeed' {
            { Add-AzSVMImage -publisher $publisher -offer $offer -sku $gallerySku -version $version -osType $osType -osDiskLocalPath $osDiskPath } |
                Should Not Throw
        }

        It 'Remove-AzSVMImage and Removing Marketplace Item should successfully complete' {
            { 
                Remove-AzSVMImage -publisher $publisher -offer $offer -sku $gallerySku -version $version
                Get-AzureRMGalleryItem | Where-Object {$_.Name -contains "$publisher.$offer$gallerySku.$version"} | Remove-AzureRMGalleryItem 
            } | Should Not Throw
        }

        It 'Adding Ubuntu Linux 16.04 Image and Marketplace Item Succeeds' {
            { Add-AzSVMImage -publisher "Canonical" -offer "UbuntuServer" -sku "16.04.1-LTS" -version "1.0.4" -osType Linux -osDiskLocalPath $ubuntuPath} | 
                Should Not Throw
        }

        It 'Removing Ubuntu Linux 16.04 Image and Marketplace Item Succeeds' {
            { 
                $newPub = "Canonical"
                $newOffer = "UbuntuServer"
                $newSKU = "16.04.1-LTS"
                $newVersion = "1.0.4"
                Remove-AzSVMImage -publisher $newPub -offer $newOffer -sku $newSKU -version $newVersion

                $GalleryItemName = "$newOffer$newSKU"
                $GalleryItemName = $GalleryItemName -replace "\.","-"
                Get-AzureRMGalleryItem | Where-Object {$_.Name -contains "$newPub.$GalleryItemName.$newVersion"} | Remove-AzureRMGalleryItem
            } | Should Not Throw
        }

    }
    
    Remove-Item $ubuntuPath
    Remove-Item $osDiskPath
    Remove-Item $dataDiskPath
}
