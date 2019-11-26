# Can run with Invoke-Pester 3.4.0

$ModuleName = 'AzureStack.MarketplaceSyndication'
$ModuleImportFile = 'AzureStack.MarketplaceSyndication.psm1'

$NatIPAddress = $null

$ModuleRoot = (Resolve-Path $PSScriptRoot\..).Path
Import-Module $script:ModuleRoot\$script:ModuleImportFile -Force

Describe $script:ModuleName {
    Context 'Module should be imported correctly' {
        It "$script:ModuleName module is imported" {
            Get-Module -Name $script:ModuleName |
                Should Not Be $null
        }
        
        It 'Add-AzureRmEnvironment should be exported' {
            Get-Command -Name Add-AzureRmEnvironment -ErrorAction SilentlyContinue | 
                Should Not Be $null
        }
    }
}

InModuleScope $script:ModuleName {
    $mockedAccessToken = "mockedAccessToken"
    $mockedSubscriptionId = "mockedSubscriptionId"
    $mockedRegistrationName = "mockedRegistration"
    $mockedRegistrationResourceGroup = "azurestack"

    $sqliaasextensionProductName = "microsoft.sqliaasextension"
    $sqliaasextension1_2_30_0Version = "1.2.30.0"
    $sqliaasextension1_2_30_0 = ConvertFrom-JSON @"
{
    "id": "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/$sqliaasextensionProductName-$sqliaasextension1_2_30_0Version",
    "name": "mockedRegistration/$sqliaasextensionProductName-$sqliaasextension1_2_30_0Version",
    "type": "Microsoft.AzureStack/registrations/products",
    "properties": {
        "displayName": "SQL IaaS Extension",
        "publisherDisplayName": "Microsoft",
        "publisherIdentifier": "Microsoft.SqlServer.Management",
        "offer": "",
        "offerVersion": "",
        "sku": "",
        "vmExtensionType": "SqlIaaSAgent",
        "galleryItemIdentity": "Microsoft.SqlIaaSExtension.1.2.30",
        "iconUris": {
            "large": "https://azstmktprodwcu001.blob.core.windows.net/icons/bfd25edab24a4de9a1f1ba17bf91b62a/Large.png",
            "wide": "https://azstmktprodwcu001.blob.core.windows.net/icons/bfd25edab24a4de9a1f1ba17bf91b62a/Wide.png",
            "medium": "https://azstmktprodwcu001.blob.core.windows.net/icons/bfd25edab24a4de9a1f1ba17bf91b62a/Medium.png",
            "small": "https://azstmktprodwcu001.blob.core.windows.net/icons/bfd25edab24a4de9a1f1ba17bf91b62a/Small.png"
        },
        "payloadLength": 6613419,
        "productKind": "virtualMachineExtension",
        "productProperties": { "version": "$sqliaasextension1_2_30_0Version" }
    }
}
"@

    $sqliaasextension2_2_30_0Version = "2.2.30.0"
    $sqliaasextension2_2_30_0 = ConvertFrom-JSON @"
{
    "id": "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/$sqliaasextensionProductName-$sqliaasextension2_2_30_0Version",
    "name": "mockedRegistration/$sqliaasextensionProductName-$sqliaasextension2_2_30_0Version",
    "type": "Microsoft.AzureStack/registrations/products",
    "properties": {
        "displayName": "SQL IaaS Extension",
        "publisherDisplayName": "Microsoft",
        "publisherIdentifier": "Microsoft.SqlServer.Management",
        "offer": "",
        "offerVersion": "",
        "sku": "",
        "vmExtensionType": "SqlIaaSAgent",
        "galleryItemIdentity": "Microsoft.SqlIaaSExtension.2.2.30",
        "iconUris": {
            "large": "https://azstmktprodwcu001.blob.core.windows.net/icons/bfd25edab24a4de9a1f1ba17bf91b62a/Large.png",
            "wide": "https://azstmktprodwcu001.blob.core.windows.net/icons/bfd25edab24a4de9a1f1ba17bf91b62a/Wide.png",
            "medium": "https://azstmktprodwcu001.blob.core.windows.net/icons/bfd25edab24a4de9a1f1ba17bf91b62a/Medium.png",
            "small": "https://azstmktprodwcu001.blob.core.windows.net/icons/bfd25edab24a4de9a1f1ba17bf91b62a/Small.png"
        },
        "payloadLength": 6613419,
        "productKind": "virtualMachineExtension",
        "productProperties": { "version": "$sqliaasextension2_2_30_0Version" }
    }
}
"@

    $bitnamiRedmineProductName = "bitnami-redmine3"
    $bitnamiRedmineVersion = "3.4.1806101514"
    $bitnamiRedmine = ConvertFrom-JSON @"
{
    "id": "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/$bitnamiRedmineProductName-$bitnamiRedmineVersion",
    "name": "jash20181112/$bitnamiRedmineProductName-$bitnamiRedmineVersion",
    "type": "Microsoft.AzureStack/registrations/products",
    "properties": {
        "displayName": "Redmine Certified by Bitnami",
        "publisherDisplayName": "Bitnami",
        "publisherIdentifier": "bitnami",
        "offer": "redmine",
        "offerVersion": "6",
        "sku": "3",
        "galleryItemIdentity": "bitnami.redmine3.1.50.181",
        "iconUris": {
            "large": "https://azstmktprodwcu001.blob.core.windows.net/icons/c0a771c03e5348fbb1013168b1c35652/Large.png",
            "wide": "https://azstmktprodwcu001.blob.core.windows.net/icons/c0a771c03e5348fbb1013168b1c35652/Wide.png",
            "medium": "https://azstmktprodwcu001.blob.core.windows.net/icons/c0a771c03e5348fbb1013168b1c35652/Medium.png",
            "small": "https://azstmktprodwcu001.blob.core.windows.net/icons/c0a771c03e5348fbb1013168b1c35652/Small.png"
        },
        "payloadLength": 32212365220,
        "productKind": "virtualMachine",
        "productProperties": { "version": "$bitnamiRedmineVersion" }
    }
}
"@

    $mockedRpProductName = "mockedRp"
    $mockedRpVersion = "1.0"
    $mockedRp = ConvertFrom-JSON @"
{
    "id": "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/$mockedRpProductName-$mockedRpVersion",
    "name": "jash20181112/$mockedRpProductName-$mockedRpVersion",
    "type": "Microsoft.AzureStack/registrations/products",
    "properties": {
        "displayName": "Mocked Resource Provider",
        "publisherDisplayName": "Microsoft",
        "publisherIdentifier": "Microsoft",
        "offer": "Microsoft",
        "offerVersion": "6",
        "sku": "3",
        "iconUris": {
            "large": "https://azstmktprodwcu001.blob.core.windows.net/icons/c0a771c03e5348fbb1013168b1c35652/Large.png",
            "wide": "https://azstmktprodwcu001.blob.core.windows.net/icons/c0a771c03e5348fbb1013168b1c35652/Wide.png",
            "medium": "https://azstmktprodwcu001.blob.core.windows.net/icons/c0a771c03e5348fbb1013168b1c35652/Medium.png",
            "small": "https://azstmktprodwcu001.blob.core.windows.net/icons/c0a771c03e5348fbb1013168b1c35652/Small.png"
        },
        "payloadLength": 3221236,
        "productKind": "resourceProvider",
        "productProperties": { "version": "$mockedRpVersion" }
    }
}
"@

    $sqliaasextensionProductEntry = @{
        ProductName     = $sqliaasextensionProductName
        Type            = "Virtual Machine Extension"
        Name            = $sqliaasextension2_2_30_0.properties.displayName
        Publisher       = $sqliaasextension2_2_30_0.properties.publisherDisplayName
        VersionEntries  = [pscustomobject[]]@( [pscustomobject]@{
            ProductId               = "$sqliaasextensionProductName-$sqliaasextension1_2_30_0Version"
            ProductResourceId       = $sqliaasextension1_2_30_0.Id
            Version                 = $sqliaasextension1_2_30_0.properties.productProperties.version
            Description             = $sqliaasextension1_2_30_0.properties.description
            Size                    = "30 GB"
        }, [pscustomobject]@{
            ProductId               = "$sqliaasextensionProductName-$sqliaasextension2_2_30_0Version"
            ProductResourceId       = $sqliaasextension2_2_30_0.Id
            Version                 = $sqliaasextension2_2_30_0.properties.productProperties.version
            Description             = $sqliaasextension2_2_30_0.properties.description
            Size                    = "40 GB"
        } )
    }

    $bitnamiRedmineProductEntry = @{
        ProductName     = $bitnamiRedmineProductName
        Type            = "Virtual Machine"
        Name            = $bitnamiRedmine.properties.displayName
        Publisher       = $bitnamiRedmine.properties.publisherDisplayName
        VersionEntries  = [pscustomobject[]]@( [pscustomobject]@{
            ProductId               = "$bitnamiRedmineProductName-$bitnamiRedmineVersion"
            ProductResourceId       = $bitnamiRedmine.Id
            Version                 = $bitnamiRedmineVersion
            Description             = $bitnamiRedmine.properties.description
            Size                    = "30 GB"
        } )
    }

    $rpProductEntity = @{
        ProductName     = $mockedRpProductName
        Type            = "Resource Provider"
        Name            = $mockedRp.properties.displayName
        Publisher       = $mockedRp.properties.publisherDisplayName
        VersionEntries  = [pscustomobject[]]@( [pscustomobject]@{
            ProductId               = "$mockedRpProductName-$mockedRpVersion"
            ProductResourceId       = $mockedRp.Id
            Version                 = $mockedRpVersion
            Description             = $mockedRp.properties.description
            Size                    = "3 MB"
        } )
    }

    $mockedContext = [pscustomobject]@{
        Tenant = [pscustomobject]@{
            TenantId = "mockedTenantId"
        }
        Subscription = [pscustomobject]@{
            Id = $mockedSubscriptionId
        }
        Account = [pscustomobject]@{
            Id = "mocked@contoco.com"
        }
        Environment = [pscustomobject]@{
            Name                                              = "AzureCloud"
            ActiveDirectoryServiceEndpointResourceId          = "https://management.core.windows.net/"
            ResourceManagerUrl                                = "https://management.azure.com/"
        }
    }

    Describe 'AzureStack.MarketplaceSyndication module - Download marketplace items or resource providers' {
        Context "User interface" {
            Mock Export-AzSOfflineProductInternal { }
            $mockedDownloadDest = "$PSScriptRoot"
            $mockedAzCopyPath = "mockedAzCopyPath"

            It 'Export marketplace item' {
                Export-AzSOfflineMarketplaceItem -azureContext $mockedContext -resourceGroup $mockedRegistrationResourceGroup -destination $mockedDownloadDest
                
                Assert-MockCalled Export-AzSOfflineProductInternal -Scope It -Times 1 -ParameterFilter {
                    $azureContext -eq $mockedContext -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $destination -eq $mockedDownloadDest -and `
                    $resourceProvider -eq $false -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyDownloadThreads')) -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyPath'))
                }
            }

            It 'Export marketplace item without input azure context' {
                Mock Get-AzureRmContext { return $mockedContext }
                Export-AzSOfflineMarketplaceItem -resourceGroup $mockedRegistrationResourceGroup -destination $mockedDownloadDest
                
                Assert-MockCalled Get-AzureRmContext -Scope It -Times 1
                Assert-MockCalled Export-AzSOfflineProductInternal -Scope It -Times 1 -ParameterFilter {
                    $azureContext -eq $mockedContext -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $destination -eq $mockedDownloadDest -and `
                    $resourceProvider -eq $false -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyDownloadThreads')) -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyPath'))
                }
            }

            It 'Export marketplace item with azCopyDownloadThreads' {
                $params = @{
                    azureContext          = $mockedContext
                    resourceGroup         = $mockedRegistrationResourceGroup
                    destination           = $mockedDownloadDest
                    azCopyDownloadThreads = 100
                }
                Export-AzSOfflineMarketplaceItem @params
                
                Assert-MockCalled Export-AzSOfflineProductInternal -Scope It -Times 1 -ParameterFilter {
                    $azureContext -eq $mockedContext -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $destination -eq $mockedDownloadDest -and `
                    $resourceProvider -eq $false -and `
                    $azCopyDownloadThreads -eq 100 -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyPath'))
                }
            }

            It 'Export marketplace item with azCopyPath' {
                $params = @{
                    azureContext          = $mockedContext
                    resourceGroup         = $mockedRegistrationResourceGroup
                    destination           = $mockedDownloadDest
                    azCopyPath            = $mockedAzCopyPath
                }
                Export-AzSOfflineMarketplaceItem @params
                
                Assert-MockCalled Export-AzSOfflineProductInternal -Scope It -Times 1 -ParameterFilter {
                    $azureContext -eq $mockedContext -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $destination -eq $mockedDownloadDest -and `
                    $resourceProvider -eq $false -and `
                    $azCopyPath -eq $mockedAzCopyPath -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyDownloadThreads'))
                }
            }

            It 'Export resource provider' {
                Export-AzSOfflineResourceProvider -azureContext $mockedContext -resourceGroup $mockedRegistrationResourceGroup -destination $mockedDownloadDest
                
                Assert-MockCalled Export-AzSOfflineProductInternal -Scope It -Times 1 -ParameterFilter {
                    $azureContext -eq $mockedContext -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $destination -eq $mockedDownloadDest -and `
                    $resourceProvider -eq $true -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyDownloadThreads')) -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyPath'))
                }
            }

            It 'Export resource provider without input azure context' {
                Mock Get-AzureRmContext { return $mockedContext }
                Export-AzSOfflineResourceProvider -resourceGroup $mockedRegistrationResourceGroup -destination $mockedDownloadDest
                
                Assert-MockCalled Get-AzureRmContext -Scope It -Times 1
                Assert-MockCalled Export-AzSOfflineProductInternal -Scope It -Times 1 -ParameterFilter {
                    $azureContext -eq $mockedContext -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $destination -eq $mockedDownloadDest -and `
                    $resourceProvider -eq $true -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyDownloadThreads')) -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyPath'))
                }
            }

            It 'Export resource provider with azCopyDownloadThreads' {
                $params = @{
                    azureContext          = $mockedContext
                    resourceGroup         = $mockedRegistrationResourceGroup
                    destination           = $mockedDownloadDest
                    azCopyDownloadThreads = 100
                }
                Export-AzSOfflineResourceProvider @params
                
                Assert-MockCalled Export-AzSOfflineProductInternal -Scope It -Times 1 -ParameterFilter {
                    $azureContext -eq $mockedContext -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $destination -eq $mockedDownloadDest -and `
                    $resourceProvider -eq $true -and `
                    $azCopyDownloadThreads -eq 100 -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyPath'))
                }
            }

            It 'Export resource provider with azCopyPath' {
                $params = @{
                    azureContext          = $mockedContext
                    resourceGroup         = $mockedRegistrationResourceGroup
                    destination           = $mockedDownloadDest
                    azCopyPath            = $mockedAzCopyPath
                }
                Export-AzSOfflineResourceProvider @params
                
                Assert-MockCalled Export-AzSOfflineProductInternal -Scope It -Times 1 -ParameterFilter {
                    $azureContext -eq $mockedContext -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $destination -eq $mockedDownloadDest -and `
                    $resourceProvider -eq $true -and `
                    $azCopyPath -eq $mockedAzCopyPath -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyDownloadThreads'))
                }
            }
        }
    }

    Describe 'AzureStack.MarketplaceSyndication module - export offline products internal' {

        Context "User interface" {
            Mock Get-AccessTokenFromContext { return $mockedAccessToken }
            $mockedDownloadDest = "$PSScriptRoot"

            function Prepare-SelectProductAndDownloadTest {
                Mock Get-ProductsList { 
                    Write-Verbose "Input parameters of Get-ProductsList: $(ConvertTo-JSON $args)"
                    return @($bitnamiRedmineProductEntry, $sqliaasextensionProductEntry) 
                }
                Mock OutGridViewWrapper { 
                    Write-Verbose "Input parameters of OutGridViewWrapper for product selection: $(ConvertTo-JSON $args)"
                    Write-Verbose "expectedGridViewTitle: $expectedGridViewTitle"
                    Write-Verbose "Input parameters Title of OutGridViewWrapper for product selection: $($Title -eq $expectedGridViewTitle)"

                    return [pscustomobject[]]@( [pscustomobject]@{
                        Id          = $bitnamiRedmineProductName
                        Name        = $sqliaasextension1_2_30_0.properties.displayName
                        }, [pscustomobject]@{
                        Id          = $sqliaasextensionProductName
                        Name        = $sqliaasextension2_2_30_0.properties.displayName
                        } ) 
                } -ParameterFilter { $Title -eq "Download marketplace items from Azure" }
                Mock OutGridViewWrapper { 
                    Write-Verbose "Input parameters of OutGridViewWrapper for version selection: $(ConvertTo-JSON $args)"
                    return [pscustomobject[]]@( [pscustomobject]@{
                        Name        = $sqliaasextensionProductName
                        Version     = $sqliaasextension2_2_30_0Version
                        } ) 
                } -ParameterFilter { $Title -eq "Select version for $sqliaasextensionProductName" }
                Mock Get-DependenciesAndDownload { Write-Verbose "Input parameters of Get-DependenciesAndDownload: $(ConvertTo-JSON $args)"}
            }

            function Verify-SelectProductAndDownloadTest {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory = $true)]
                    [bool] $expectedResourceProviderSwitchValue,

                    [Parameter(Mandatory = $true)]
                    [string] $expectedGridViewTitle,

                    [Parameter(Mandatory = $false)]
                    [Int] $expectedAzCopyDownloadThreads,

                    [Parameter(Mandatory = $false)]
                    [string] $expectedAzCopyPath
                )

                Assert-MockCalled Get-AccessTokenFromContext -Scope It -Times 1 -ParameterFilter { 
                    $azureContext -eq $mockedContext
                }
                Assert-MockCalled Get-ProductsList -Scope It -Times 1 -ParameterFilter { 
                    $azureEnvironment -eq $mockedContext.Environment -and `
                    $azureSubscriptionID -eq $mockedContext.Subscription.Id -and `
                    $accessToken -eq $mockedAccessToken -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $resourceProvider -eq $expectedResourceProviderSwitchValue
                }
                Assert-MockCalled OutGridViewWrapper -Scope It -Times 1 -ParameterFilter { 
                    $Title -eq $expectedGridViewTitle -and `
                    $InputObject.length -eq 2 -and `
                    $InputObject[0].Name -eq $bitnamiRedmineProductEntry.Name -and `
                    $InputObject[0].Id -eq $bitnamiRedmineProductName -and `
                    $InputObject[0].Type -eq $bitnamiRedmineProductEntry.Type -and `
                    $InputObject[0].Publisher -eq $bitnamiRedmineProductEntry.Publisher -and `
                    $InputObject[0].Version -eq $bitnamiRedmineProductEntry.VersionEntries[0].version -and `
                    $InputObject[0].Size -eq $bitnamiRedmineProductEntry.VersionEntries[0].Size -and `
                    $InputObject[1].Name -eq $sqliaasextensionProductEntry.Name -and `
                    $InputObject[1].Id -eq $sqliaasextensionProductEntry.ProductName -and `
                    $InputObject[1].Type -eq $sqliaasextensionProductEntry.Type -and `
                    $InputObject[1].Publisher -eq $sqliaasextensionProductEntry.Publisher -and `
                    $InputObject[1].Version -eq "Multiple versions"  -and `
                    $InputObject[1].Size -eq "--"
                }
                Assert-MockCalled OutGridViewWrapper -Scope It -Times 1 -ParameterFilter { 
                    $Title -eq "Select version for $sqliaasextensionProductName" -and `
                    $InputObject.length -eq 2 -and `
                    $InputObject[0].Name -eq $sqliaasextension1_2_30_0.properties.displayName -and `
                    $InputObject[0]."Product Id" -eq $sqliaasextensionProductName -and `
                    $InputObject[0].Version -eq $sqliaasextension1_2_30_0Version -and `
                    $InputObject[0].Size -eq $sqliaasextensionProductEntry.VersionEntries[0].Size -and `
                    $InputObject[0].Name -eq $sqliaasextension2_2_30_0.properties.displayName -and `
                    $InputObject[1]."Product Id" -eq $sqliaasextensionProductName -and `
                    $InputObject[1].Version -eq $sqliaasextension2_2_30_0Version  -and `
                    $InputObject[1].Size -eq $sqliaasextensionProductEntry.VersionEntries[1].Size
                }
                Assert-MockCalled Get-DependenciesAndDownload -Scope It -Times 1 -ParameterFilter { 
                    $azureEnvironment -eq $mockedContext.Environment -and `
                    $destination -eq $mockedDownloadDest -and `
                    $productid -eq "$bitnamiRedmineProductName-$bitnamiRedmineVersion" -and `
                    $productResourceId -eq $bitnamiRedmine.Id -and `
                    (((-not $expectedAzCopyDownloadThreads) -and (-not $PSBoundParameters.ContainsKey('azCopyDownloadThreads'))) -or ($expectedAzCopyDownloadThreads -eq $azCopyDownloadThreads)) -and `
                    (((-not $expectedAzCopyPath) -and (-not $PSBoundParameters.ContainsKey('azCopyPath'))) -or ($expectedAzCopyPath -eq $azCopyPath))
                }
                Assert-MockCalled Get-DependenciesAndDownload -Scope It -Times 1 -ParameterFilter { 
                    $azureEnvironment -eq $mockedContext.Environment -and `
                    $destination -eq $mockedDownloadDest -and `
                    $productid -eq "$sqliaasextensionProductName-$sqliaasextension2_2_30_0Version" -and `
                    $productResourceId -eq $sqliaasextension2_2_30_0.Id -and `
                    (((-not $expectedAzCopyDownloadThreads) -and (-not $PSBoundParameters.ContainsKey('azCopyDownloadThreads'))) -or ($expectedAzCopyDownloadThreads -eq $azCopyDownloadThreads)) -and `
                    (((-not $expectedAzCopyPath) -and (-not $PSBoundParameters.ContainsKey('azCopyPath'))) -or ($expectedAzCopyPath -eq $azCopyPath))
                }
            }

            It 'Select marketplace item to download' {
                Prepare-SelectProductAndDownloadTest

                Export-AzSOfflineProductInternal -azureContext $mockedContext -resourceGroup $mockedRegistrationResourceGroup -destination $mockedDownloadDest -resourceProvider:$false

                Verify-SelectProductAndDownloadTest -expectedResourceProviderSwitchValue $false `
                    -expectedGridViewTitle "Download marketplace items from Azure"
            }

            It 'Select marketplace item to download with azCopyDownloadThreads' {
                Prepare-SelectProductAndDownloadTest

                $params = @{
                    azureContext = $mockedContext
                    resourceGroup =  $mockedRegistrationResourceGroup
                    destination = $mockedDownloadDest
                    resourceProvider = $false
                    azCopyDownloadThreads = 100
                }
                Export-AzSOfflineProductInternal @params

                Verify-SelectProductAndDownloadTest -expectedResourceProviderSwitchValue $false `
                    -expectedGridViewTitle "Download marketplace items from Azure" `
                    -expectedAzCopyDownloadThreads 100
            }

            It 'Select marketplace item to download with azCopyPath' {
                Prepare-SelectProductAndDownloadTest

                $params = @{
                    azureContext = $mockedContext
                    resourceGroup =  $mockedRegistrationResourceGroup
                    destination = $mockedDownloadDest
                    resourceProvider = $false
                    azCopyPath = "mockedAzCopyPath"
                }
                Export-AzSOfflineProductInternal @params

                Verify-SelectProductAndDownloadTest -expectedResourceProviderSwitchValue $false `
                    -expectedGridViewTitle "Download marketplace items from Azure" `
                    -expectedAzCopyPath "mockedAzCopyPath"
            }

            It 'Select resource provider to download' {
            
                Mock Get-ProductsList { 
                    Write-Verbose "Input parameters of Get-ProductsList: $(ConvertTo-JSON $args)"
                    return @($bitnamiRedmineProductEntry, $sqliaasextensionProductEntry) 
                }
                Mock OutGridViewWrapper { 
                    Write-Verbose "Input parameters of OutGridViewWrapper for product selection: $(ConvertTo-JSON $args)"
                    Write-Verbose "expectedGridViewTitle: $expectedGridViewTitle"
                    Write-Verbose "Input parameters Title of OutGridViewWrapper for product selection: $($Title -eq $expectedGridViewTitle)"

                    return [pscustomobject[]]@( [pscustomobject]@{
                        Id          = $bitnamiRedmineProductName
                        Name        = $sqliaasextension1_2_30_0.properties.displayName
                        }, [pscustomobject]@{
                        Id          = $sqliaasextensionProductName
                        Name        = $sqliaasextension2_2_30_0.properties.displayName
                        } ) 
                } -ParameterFilter { $Title -eq "Download resource providers from Azure" }
                Mock OutGridViewWrapper { 
                    Write-Verbose "Input parameters of OutGridViewWrapper for version selection: $(ConvertTo-JSON $args)"
                    return [pscustomobject[]]@( [pscustomobject]@{
                        Name        = $sqliaasextensionProductName
                        Version     = $sqliaasextension2_2_30_0Version
                        } ) 
                } -ParameterFilter { $Title -eq "Select version for $sqliaasextensionProductName" }
                Mock Get-DependenciesAndDownload { Write-Verbose "Input parameters of Get-DependenciesAndDownload: $(ConvertTo-JSON $args)"}

                $mockedDownloadDest = "$PSScriptRoot"
                Export-AzSOfflineProductInternal -azureContext $mockedContext -resourceGroup $mockedRegistrationResourceGroup -destination $mockedDownloadDest -resourceProvider:$true

                Verify-SelectProductAndDownloadTest -expectedResourceProviderSwitchValue $true `
                    -expectedGridViewTitle "Download resource providers from Azure"
            }

            It 'Select product to download when Azure returns empty' {
            
                Mock Get-ProductsList { 
                    Write-Verbose "Input parameters of Get-ProductsList: $(ConvertTo-JSON $args)"
                    return @()
                }
                Mock OutGridViewWrapper {
                    Write-Verbose "Input parameters of OutGridViewWrapper for product selection: $(ConvertTo-JSON $args)"
                } -ParameterFilter { $Title -eq "Download resource providers from Azure" }
                Mock Get-DependenciesAndDownload { Write-Verbose "Input parameters of Get-DependenciesAndDownload: $(ConvertTo-JSON $args)"}

                Export-AzSOfflineProductInternal -azureContext $mockedContext -resourceGroup $mockedRegistrationResourceGroup -destination $mockedDownloadDest -resourceProvider:$true

                Assert-MockCalled Get-AccessTokenFromContext -Scope It -Times 1
                Assert-MockCalled Get-ProductsList -Scope It -Times 1 -ParameterFilter { 
                    $azureEnvironment -eq $mockedContext.Environment -and `
                    $azureSubscriptionID -eq $mockedContext.Subscription.Id -and `
                    $accessToken -eq $mockedAccessToken -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $resourceProvider -eq $true
                }
                Assert-MockCalled OutGridViewWrapper -Scope It -Times 1 -ParameterFilter { 
                    $Title -eq "Download resource providers from Azure"
                    ([pscustomobject[]]$InputObject).length -eq 0
                }
                
                Assert-MockCalled Get-DependenciesAndDownload -Scope It -Times 0
            }

            It 'Select product to download when user select nothing' {
            
                Mock Get-ProductsList { 
                    Write-Verbose "Input parameters of Get-ProductsList: $(ConvertTo-JSON $args)"
                    return @($rpProductEntity)
                }
                Mock OutGridViewWrapper { 
                    Write-Verbose "Input parameters of OutGridViewWrapper for product selection: $(ConvertTo-JSON $args)"
                } -ParameterFilter { $Title -eq "Download resource providers from Azure" }
                Mock Get-DependenciesAndDownload { Write-Verbose "Input parameters of Get-DependenciesAndDownload: $(ConvertTo-JSON $args)"}

                $mockedDownloadDest = "$PSScriptRoot"
                Export-AzSOfflineProductInternal -azureContext $mockedContext -resourceGroup $mockedRegistrationResourceGroup -destination $mockedDownloadDest -resourceProvider:$true

                Assert-MockCalled Get-AccessTokenFromContext -Scope It -Times 1
                Assert-MockCalled Get-ProductsList -Scope It -Times 1 -ParameterFilter { 
                    $azureEnvironment -eq $mockedContext.Environment -and `
                    $azureSubscriptionID -eq $mockedContext.Subscription.Id -and `
                    $accessToken -eq $mockedAccessToken -and `
                    $resourceGroup -eq $mockedRegistrationResourceGroup -and `
                    $resourceProvider -eq $true
                }
                Assert-MockCalled OutGridViewWrapper -Scope It -Times 1 -ParameterFilter { 
                    $Title -eq "Download resource providers from Azure"
                    ([pscustomobject[]]$InputObject).length -eq 1
                }
                
                Assert-MockCalled Get-DependenciesAndDownload -Scope It -Times 0
            }
        }

        Context "Get-ProductsList context" {

            It 'Get marketplace items information from Azure' {
                $mockedRegistrationResource = [pscustomobject]@{
                ResourceId = "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName"
                }

                $mockedResponse = @{
                    value = @(
                        $sqliaasextension2_2_30_0,
                        $sqliaasextension1_2_30_0,
                        $bitnamiRedmine,
                        $mockedRp
                    )
                }

                Mock Get-AzureRmResource { 
                    Write-Verbose "Input parameters of Get-AzureRmResource: $(ConvertTo-JSON $args)"
                    return $mockedRegistrationResource }
                Mock Invoke-RestMethod { 
                    Write-Verbose "Input parameters of Invoke-RestMethod: $(ConvertTo-JSON $args)"
                    return $mockedResponse }

                $params = @{
                    azureEnvironment = $mockedContext.Environment
                    azureSubscriptionID = $mockedContext.Subscription.Id
                    accessToken = $mockedAccessToken
                    resourceGroup = $mockedRegistrationResourceGroup
                    resourceProvider = $false
                }

                $products = Get-ProductsList @params

                Write-Verbose "Results of Get-ProductsList is $(ConvertTo-JSOn $products)"
                $products.length | Should Be 2
                $products[0].ProductName | Should Be $bitnamiRedmineProductName
                $products[0].Type | Should Be "Virtual Machine"
                $products[0].Name | Should Be $bitnamiRedmine.properties.displayName
                $products[0].Publisher | Should Be $bitnamiRedmine.properties.publisherDisplayName
                $products[0].VersionEntries.length | Should Be 1
                $products[0].VersionEntries[0].ProductId | Should Be "$bitnamiRedmineProductName-$bitnamiRedmineVersion"
                $products[0].VersionEntries[0].ProductResourceId | Should Be $bitnamiRedmine.id
                $products[0].VersionEntries[0].Version | Should Be $bitnamiRedmineVersion
                $products[0].VersionEntries[0].Size | Should Be "30 GB"

                $products[1].ProductName | Should Be $sqliaasextensionProductName
                $products[1].Type | Should Be "Virtual Machine Extension"
                $products[1].Name | Should Be $sqliaasextension1_2_30_0.properties.displayName
                $products[1].Publisher | Should Be $sqliaasextension1_2_30_0.properties.publisherDisplayName
                $products[1].VersionEntries.length | Should Be 2
                $products[1].VersionEntries[0].ProductId | Should Be "$sqliaasextensionProductName-$sqliaasextension1_2_30_0Version"
                $products[1].VersionEntries[0].ProductResourceId | Should Be $sqliaasextension1_2_30_0.id
                $products[1].VersionEntries[0].Version | Should Be $sqliaasextension1_2_30_0Version
                $products[1].VersionEntries[0].Size | Should Be "6 MB"
                $products[1].VersionEntries[1].ProductId | Should Be "$sqliaasextensionProductName-$sqliaasextension2_2_30_0Version"
                $products[1].VersionEntries[1].ProductResourceId | Should Be $sqliaasextension2_2_30_0.id
                $products[1].VersionEntries[1].Version | Should Be $sqliaasextension2_2_30_0Version
                $products[1].VersionEntries[1].Size | Should Be "6 MB"

                Assert-MockCalled Get-AzureRmResource -Scope It -Times 1 -ParameterFilter {
                    $ResourceGroupName -eq $mockedRegistrationResourceGroup -and `
                    $ResourceType -eq "Microsoft.AzureStack/registrations"
                }

                Assert-MockCalled Invoke-RestMethod -Scope It -Times 1 -ParameterFilter {
                    $Uri -eq "https://management.azure.com//subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products?api-version=2016-01-01" -and `
                    $TimeoutSec -eq 180 -and `
                    $Method -eq 1 -and ` # GET
                    $Headers.authorization -eq "Bearer $mockedAccessToken"
                }
            }

            It 'Get resource providers information from Azure' {
                $mockedRegistrationResource = [pscustomobject]@{
                    ResourceId = "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName"
                }

                $mockedRegistrationResource2 = [pscustomobject]@{
                    ResourceId = "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/mocked2"
                }

                $mockedResponse = @{
                    value = @(
                        $sqliaasextension2_2_30_0,
                        $sqliaasextension1_2_30_0,
                        $bitnamiRedmine,
                        $mockedRp
                    )
                }

                Mock Get-AzureRmResource { 
                    Write-Verbose "Input parameters of Get-AzureRmResource: $(ConvertTo-JSON $args)"
                    return @($mockedRegistrationResource, $mockedRegistrationResource2) }
                Mock Invoke-RestMethod { 
                    Write-Verbose "Input parameters of Invoke-RestMethod: $(ConvertTo-JSON $args)"
                    return $mockedResponse }

                $params = @{
                    azureEnvironment = $mockedContext.Environment
                    azureSubscriptionID = $mockedContext.Subscription.Id
                    accessToken = $mockedAccessToken
                    resourceGroup = $mockedRegistrationResourceGroup
                    resourceProvider = $true
                }

                $products = [pscustomobject[]](Get-ProductsList @params)

                Write-Verbose "Results of Get-ProductsList is $(ConvertTo-JSOn $products)"
                $products.length | Should Be 1
                $products[0].ProductName | Should Be $mockedRpProductName
                $products[0].Type | Should Be "Resource Provider"
                $products[0].Name | Should Be $mockedRp.properties.displayName
                $products[0].Publisher | Should Be $mockedRp.properties.publisherDisplayName
                $products[0].VersionEntries.length | Should Be 1
                $products[0].VersionEntries[0].ProductId | Should Be "$mockedRpProductName-$mockedRpVersion"
                $products[0].VersionEntries[0].ProductResourceId | Should Be $mockedRp.id
                $products[0].VersionEntries[0].Version | Should Be $mockedRpVersion
                $products[0].VersionEntries[0].Size | Should Be "3 MB"

                Assert-MockCalled Get-AzureRmResource -Scope It -Times 1 -ParameterFilter {
                    $ResourceGroupName -eq $mockedRegistrationResourceGroup -and `
                    $ResourceType -eq "Microsoft.AzureStack/registrations"
                }

                Assert-MockCalled Invoke-RestMethod -Scope It -Times 1 -ParameterFilter {
                    $Uri -eq "https://management.azure.com//subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products?api-version=2016-01-01" -and `
                    $TimeoutSec -eq 180 -and `
                    $Method -eq 1 -and ` # GET
                    $Headers.authorization -eq "Bearer $mockedAccessToken"
                }
            }

            It 'Get product information from Azure with no registration' {
                Mock Get-AzureRmResource { 
                    Write-Verbose "Input parameters of Get-AzureRmResource: $(ConvertTo-JSON $args)"
                    return @() }

                $params = @{
                    azureEnvironment = $mockedContext.Environment
                    azureSubscriptionID = $mockedContext.Subscription.Id
                    accessToken = $mockedAccessToken
                    resourceGroup = $mockedRegistrationResourceGroup
                    resourceProvider = $true
                }

                try
                {
                    [pscustomobject[]](Get-ProductsList @params)
                    
                    throw "Get-ProductsList should throw exception because there is no registraion"
                } catch {
                    $_.Exception.Message | Should Be "The subscription does not have Azure Stack registration. Please use the correct subscription."
                }

                Assert-MockCalled Get-AzureRmResource -Scope It -Times 1 -ParameterFilter {
                    $ResourceGroupName -eq $mockedRegistrationResourceGroup -and `
                    $ResourceType -eq "Microsoft.AzureStack/registrations"
                }

                Assert-MockCalled Invoke-RestMethod -Scope It -Times 0
            }

            It 'Get resource providers information from Azure with empty response' {
                $mockedRegistrationResource = [pscustomobject]@{
                    ResourceId = "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName"
                }

                $mockedRegistrationResource2 = [pscustomobject]@{
                    ResourceId = "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/mocked2"
                }

                $mockedResponse = @{
                    value = @()
                }

                Mock Get-AzureRmResource { 
                    Write-Verbose "Input parameters of Get-AzureRmResource: $(ConvertTo-JSON $args)"
                    return @($mockedRegistrationResource, $mockedRegistrationResource2) }
                Mock Invoke-RestMethod { 
                    Write-Verbose "Input parameters of Invoke-RestMethod: $(ConvertTo-JSON $args)"
                    return $mockedResponse }

                $params = @{
                    azureEnvironment = $mockedContext.Environment
                    azureSubscriptionID = $mockedContext.Subscription.Id
                    accessToken = $mockedAccessToken
                    resourceGroup = $mockedRegistrationResourceGroup
                    resourceProvider = $true
                }

                $products = [pscustomobject[]](Get-ProductsList @params)

                Write-Verbose "Results of Get-ProductsList is $(ConvertTo-JSOn $products)"
                $products.length | Should Be 0

                Assert-MockCalled Get-AzureRmResource -Scope It -Times 1 -ParameterFilter {
                    $ResourceGroupName -eq $mockedRegistrationResourceGroup -and `
                    $ResourceType -eq "Microsoft.AzureStack/registrations"
                }

                Assert-MockCalled Invoke-RestMethod -Scope It -Times 1 -ParameterFilter {
                    $Uri -eq "https://management.azure.com//subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products?api-version=2016-01-01" -and `
                    $TimeoutSec -eq 180 -and `
                    $Method -eq 1 -and ` # GET
                    $Headers.authorization -eq "Bearer $mockedAccessToken"
                }
            }

        }

        Context "Product dependencies context" {
            It 'Download product without dependencies' {
                $mockedResponse = @{
                    productKind = "resourceProvider"
                    properties = @{
                        dependentProducts = @()
                        fileContainers = @()
                        version = "1.1"
                    }
                }

                Mock Invoke-RestMethod { 
                    Write-Verbose "Input parameters of Invoke-RestMethod: $(ConvertTo-JSON $args)"
                    return $mockedResponse 
                }

                Mock Download-Product {
                    Write-Verbose "Input parameters of Download-Product: $(ConvertTo-JSON $args)"
                }

                Mock Test-Path {
                    Write-Verbose "Input parameters of TestPath: $(ConvertTo-JSON $args)"

                    return $false
                }

                $productResourceId = "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.eventhub-1.0.1"
                $productId = "microsoft.eventhub-1.0.1"
                $mockedDownloadDest = "$PSScriptRoot"
                $params = @{
                    productid           = $productId
                    productResourceId   = $productResourceId
                    azureEnvironment    = $mockedContext.Environment
                    accessToken         = $mockedAccessToken
                    destination         = $mockedDownloadDest
                }

                Get-DependenciesAndDownload @params

                Assert-MockCalled Invoke-RestMethod -Scope It -Times 1 -ParameterFilter {
                    $Uri -eq "https://management.azure.com//subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.eventhub-1.0.1/listDetails?api-version=2016-01-01" -and `
                    $TimeoutSec -eq 180 -and `
                    $Method -eq 3 -and ` # POST
                    $Headers.authorization -eq "Bearer $mockedAccessToken"
                }

                Assert-MockCalled Test-Path -Scope It -Times 1 -ParameterFilter {
                    $Path -eq "$mockedDownloadDest\$productId"
                }

                Assert-MockCalled Download-Product -Scope It -Times 1 -ParameterFilter {
                    $productid -eq $productid -and `
                    $productResourceId -eq $productResourceId -and `
                    $azureEnvironment -eq $mockedContext.Environment -and ` # GET
                    $accessToken -eq $mockedAccessToken -and `
                    $destination -eq $mockedDownloadDest -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyDownloadThreads')) -and `
                    (-not $PSBoundParameters.ContainsKey('azCopyPath'))
                }
            }

            It 'Download product already existed' {
                $mockedResponse = @{
                    productKind = "resourceProvider"
                    properties = @{
                        dependentProducts = @()
                        fileContainers = @()
                        version = "1.1"
                    }
                }

                Mock Invoke-RestMethod { 
                    Write-Verbose "Input parameters of Invoke-RestMethod: $(ConvertTo-JSON $args)"
                    return $mockedResponse 
                }

                Mock Download-Product {
                    Write-Verbose "Input parameters of Download-Product: $(ConvertTo-JSON $args)"
                }

                Mock Test-Path {
                    Write-Verbose "Input parameters of TestPath: $(ConvertTo-JSON $args)"

                    return $true
                }

                $productResourceId = "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.eventhub-1.0.1"
                $productId = "microsoft.eventhub-1.0.1"
                $mockedDownloadDest = "$PSScriptRoot"
                $params = @{
                    productid           = $productId
                    productResourceId   = $productResourceId
                    azureEnvironment    = $mockedContext.Environment
                    accessToken         = $mockedAccessToken
                    destination         = $mockedDownloadDest
                }

                Get-DependenciesAndDownload @params

                Assert-MockCalled Invoke-RestMethod -Scope It -Times 1 -ParameterFilter {
                    $Uri -eq "https://management.azure.com//subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.eventhub-1.0.1/listDetails?api-version=2016-01-01" -and `
                    $TimeoutSec -eq 180 -and `
                    $Method -eq 3 -and ` # POST
                    $Headers.authorization -eq "Bearer $mockedAccessToken"
                }

                Assert-MockCalled Test-Path -Scope It -Times 1 -ParameterFilter {
                    $Path -eq "$mockedDownloadDest\$productId"
                }

                Assert-MockCalled Test-Path -Scope It -Times 1 -ParameterFilter {
                    $Path -eq "$mockedDownloadDest\$productId\$productid.json"
                }

                Assert-MockCalled Download-Product -Scope It -Times 0
            }

            It 'Download product with dependencies' {
                $mockedResponse = @{
                    productKind = "resourceProvider"
                    properties = @{
                        dependentProducts = @(
                        "microsoft.customscriptextension-arm-1.9.1",
                        "microsoft.sqliaasextension-1.2.30.0"
                        )
                        fileContainers = @()
                        version = "1.1"
                    }
                }

                $productResourceId = "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.eventhub-1.0.1"
                $productId = "microsoft.eventhub-1.0.1"
                $mockedDownloadDest = "$PSScriptRoot"

                Mock Invoke-RestMethod { 
                    Write-Verbose "Input parameters of Invoke-RestMethod: $(ConvertTo-JSON $args)"

                    if ($Uri -eq "https://management.azure.com//subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.eventhub-1.0.1/listDetails?api-version=2016-01-01") {
                        return $mockedResponse
                    } else {
                        return @{
                            productKind = "resourceProvider"
                            properties = @{}
                        }
                    }
                }

                Mock Download-Product {
                    Write-Verbose "Input parameters of Download-Product: $(ConvertTo-JSON $args)"
                }

                Mock Test-Path {
                    Write-Verbose "Input parameters of TestPath: $(ConvertTo-JSON $args)"

                    if ($Path -eq "$mockedDownloadDest\$productId") {
                        return $true
                    }

                    return $false
                }

                $params = @{
                    productid           = $productId
                    productResourceId   = $productResourceId
                    azureEnvironment    = $mockedContext.Environment
                    accessToken         = $mockedAccessToken
                    destination         = $mockedDownloadDest
                    azCopyDownloadThreads = 100
                    azCopyPath          = "mockedAzCopyPath"
                }

                Get-DependenciesAndDownload @params

                Assert-MockCalled Invoke-RestMethod -Scope It -Times 1 -ParameterFilter {
                    $Uri -eq "https://management.azure.com//subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.eventhub-1.0.1/listDetails?api-version=2016-01-01" -and `
                    $TimeoutSec -eq 180 -and `
                    $Method -eq 3 -and ` # POST
                    $Headers.authorization -eq "Bearer $mockedAccessToken"
                }

                Assert-MockCalled Invoke-RestMethod -Scope It -Times 1 -ParameterFilter {
                    $Uri -eq "https://management.azure.com//subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.customscriptextension-arm-1.9.1/listDetails?api-version=2016-01-01" -and `
                    $TimeoutSec -eq 180 -and `
                    $Method -eq 3 -and ` # POST
                    $Headers.authorization -eq "Bearer $mockedAccessToken"
                }

                Assert-MockCalled Invoke-RestMethod -Scope It -Times 1 -ParameterFilter {
                    $Uri -eq "https://management.azure.com//subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.sqliaasextension-1.2.30.0/listDetails?api-version=2016-01-01" -and `
                    $TimeoutSec -eq 180 -and `
                    $Method -eq 3 -and ` # POST
                    $Headers.authorization -eq "Bearer $mockedAccessToken"
                }

                Assert-MockCalled Test-Path -Scope It -Times 1 -ParameterFilter {
                    $Path -eq "$mockedDownloadDest\$productId"
                }

                Assert-MockCalled Test-Path -Scope It -Times 1 -ParameterFilter {
                    $Path -eq "$mockedDownloadDest\microsoft.customscriptextension-arm-1.9.1"
                }

                Assert-MockCalled Test-Path -Scope It -Times 1 -ParameterFilter {
                    $Path -eq "$mockedDownloadDest\microsoft.sqliaasextension-1.2.30.0"
                }

                Assert-MockCalled Test-Path -Scope It -Times 1 -ParameterFilter {
                    $Path -eq "$mockedDownloadDest\$productId\$productid.json"
                }

                Assert-MockCalled Download-Product -Scope It -Times 1 -ParameterFilter {
                    $productid -eq $productid -and `
                    $productResourceId -eq $productResourceId -and `
                    $azureEnvironment -eq $mockedContext.Environment -and ` # GET
                    $accessToken -eq $mockedAccessToken -and `
                    $destination -eq $mockedDownloadDest -and `
                    $azCopyDownloadThreads -eq 100 -and `
                    $azCopyPath -and "mockedAzCopyPath"
                }

                Assert-MockCalled Download-Product -Scope It -Times 1 -ParameterFilter {
                    $productid -eq "microsoft.customscriptextension-arm-1.9.1" -and `
                    $productResourceId -eq "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.customscriptextension-arm-1.9.1" -and `
                    $azureEnvironment -eq $mockedContext.Environment -and ` # GET
                    $accessToken -eq $mockedAccessToken -and `
                    $destination -eq $mockedDownloadDest -and `
                    $azCopyDownloadThreads -eq 100 -and `
                    $azCopyPath -and "mockedAzCopyPath"
                }

                Assert-MockCalled Download-Product -Scope It -Times 1 -ParameterFilter {
                    $productid -eq "microsoft.sqliaasextension-1.2.30.0" -and `
                    $productResourceId -eq "/subscriptions/$mockedSubscriptionId/resourceGroups/$mockedRegistrationResourceGroup/providers/Microsoft.AzureStack/registrations/$mockedRegistrationName/products/microsoft.sqliaasextension-1.2.30.0" -and `
                    $azureEnvironment -eq $mockedContext.Environment -and ` # GET
                    $accessToken -eq $mockedAccessToken -and `
                    $destination -eq $mockedDownloadDest -and `
                    $azCopyDownloadThreads -eq 100 -and `
                    $azCopyPath -and "mockedAzCopyPath"
                }
            }
        }
    }
}
