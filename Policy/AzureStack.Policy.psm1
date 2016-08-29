function Get-AzureStackRmPolicy 
{
    $defaults = [System.IO.Path]::GetDirectoryName($PSCommandPath)

    $providerMetadata = ConvertFrom-Json (Get-Content -Path ($defaults + "\AzureStack.Provider.Metadata.json") -Raw)
    $vmSkus = @() + (ConvertFrom-Json (Get-Content -Path ($defaults + "\AzureStack.vmSkus.json") -Raw))
    $storageSkus = @() + (ConvertFrom-Json (Get-Content -Path ($defaults + "\AzureStack.storageSkus.json") -Raw))
    
    $allowResources = @()

    foreach ($p in $providerMetadata.value) 
    {
        foreach ($r in $p.resourceTypes)
        {
            $allowResources += @{ field = "type"; equals = $p.namespace + "/" + $r.ResourceType}
            $allowResources += @{ field = "type"; like = $p.namespace + "/" + $r.ResourceType + "/*" }
        }
    }

    $vmSkuField = "Microsoft.Compute/virtualMachines/sku.name"
    $storageSkuField = "Microsoft.Storage/storageAccounts/sku.name"

    $policy = @{
        if = @{
            not = @{
                allOf = @(
                    @{
                        anyOf = $allowResources
                    },
                    @{
                        not = @{
                            anyOf = @(
                                @{
                                    allOf = @(
                                        @{
                                            field = $vmSkuField;
                                            exists = "true"
                                        },
                                        @{
                                            not = @{
                                                field = $vmSkuField;
                                                in = $vmSkus
                                            }
                                        }
                                    )
                                },
                                @{
                                    allOf = @(
                                        @{
                                            field = $storageSkuField;
                                            exists = "true"
                                        },
                                        @{
                                            not = @{
                                                field = $storageSkuField;
                                                in = $storageSkus
                                            }
                                        }
                                    )
                                }
                            )
                        }
                    }
                )
            }
        };
        then = @{
            effect = "deny"
        }
    }

    ConvertTo-Json $policy -Depth 100
}

Export-ModuleMember Get-AzureStackRmPolicy