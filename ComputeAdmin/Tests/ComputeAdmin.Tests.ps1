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

    $HostComputer = $global:HostComputer
    $Domain = $global:Domain 
    $natServer = $global:natServer 
    $AdminUser= $global:AdminUser 
    $AadServiceAdmin = $global:AadServiceAdmin 

    $AdminPassword = $global:AdminPassword
    $AadServiceAdminPassword = $global:AadServiceAdminPassword
    $stackLoginCreds = $global:AzureStackLoginCredentials

    $VPNConnectionName = $global:VPNConnectionName

    $AadTenant = $global:AadTenantID

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
    $version = '1.0.3'
    $osType = 'Windows'
    $gallerySku = 'StackToolGalleryTest'

    Describe 'ComputeAdmin - Functional Tests' {
        It 'CreateGalleryItem = "$false" -and title = specified should throw' {
            { Add-VMImage -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -osDiskLocalPath $osDiskPath -tenantID $AadTenant -AzureStackCredential $stackLoginCreds -CreateGalleryItem $false -title 'testTitle' } |
                Should Throw
        }

        It 'CreateGalleryItem = "$false" -and description = specified should throw' {
            { Add-VMImage -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -osDiskLocalPath $osDiskPath -tenantID $AadTenant -AzureStackCredential $stackLoginCreds -CreateGalleryItem $false -title 'testTitle'  -CreateGalleryItem $false -description 'testdescription' } | Should Throw
        }

        It 'Add-VMImage via local path and upload to storage account should succeed' {
            { Add-VMImage -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -osDiskLocalPath $osDiskPath -tenantID $AadTenant -AzureStackCredential $stackLoginCreds -CreateGalleryItem $false } |
                Should Not Throw
        }

        It 'Remove-VMImage should successfully remove added VM Image' {
            { Remove-VMImage -publisher $publisher -offer $offer -sku $sku -version $version -osType $osType -tenantID $AadTenant -AzureStackCredential $stackLoginCreds} |
                Should Not Throw
        }

        It 'Add-VMImage via local path and upload to storage account with gallery item should succeed' {
            { Add-VMImage -publisher $publisher -offer $offer -sku $gallerySku -version $version -osType $osType -osDiskLocalPath $osDiskPath -tenantID $AadTenant -AzureStackCredential $stackLoginCreds } |
                Should Not Throw
        }

        It 'Remove-VMImage and Removing Marketplace Item should successfully complete' {
            { 
                Remove-VMImage -publisher $publisher -offer $offer -sku $gallerySku -version $version -osType $osType -tenantID $AadTenant -AzureStackCredential $stackLoginCreds
                Get-AzureRMGalleryItem -ApiVersion 2015-04-01
                Get-AzureRMGalleryItem -ApiVersion 2015-04-01 | Where-Object {$_.Name -contains "$publisher.$offer$gallerySku.$version"} | Remove-AzureRMGalleryItem -ApiVersion 2015-04-01
            } | Should Not Throw
        }

        It 'Adding Ubuntu Linux 16.04 Image and Marketplace Item Succeeds' {
            { Add-VMImage -publisher "Canonical" -offer "UbuntuServer" -sku "16.04.1-LTS" -version "1.0.3" -osType Linux -osDiskLocalPath $ubuntuPath -tenantID $AadTenant -AzureStackCredential $stackLoginCreds} | 
                Should Not Throw
        }

        It 'Removing Ubuntu Linux 16.04 Image and Marketplace Item Succeeds' {
            { 
                $newPub = "Canonical"
                $newOffer = "UbuntuServer"
                $newSKU = "16.04.1-LTS"
                $newVersion = "1.0.3"
                Remove-VMImage -publisher $newPub -offer $newOffer -sku $newSKU -version $newVersion -osType Linux -tenantID $AadTenant -AzureStackCredential $stackLoginCreds
                $GalleryItemName = "$newOffer$newSKU"
                $GalleryItemName = $GalleryItemName -replace "\.","-"
                Get-AzureRMGalleryItem -ApiVersion 2015-04-01 | Where-Object {$_.Name -contains "$newPub.$GalleryItemName.$newVersion"} | Remove-AzureRMGalleryItem -ApiVersion 2015-04-01
            } | Should Not Throw
        }

    }
    
    Remove-Item $ubuntuPath
    Remove-Item $osDiskPath
    Remove-Item $dataDiskPath
}