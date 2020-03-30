# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Modules Az.Accounts

<#
    .SYNOPSIS
    Produces Azure Resource Manager Policy document to apply to restrict Azure subscriptions to Azure Stack compatible functionality
#>

function Get-AzsPolicy {
    $defaults = [System.IO.Path]::GetDirectoryName($PSCommandPath)

    $providerMetadata = ConvertFrom-Json (Get-Content -Path ($defaults + "\AzureStack.Provider.Metadata.json") -Raw)
    $vmSkus = @() + (ConvertFrom-Json (Get-Content -Path ($defaults + "\AzureStack.vmSkus.json") -Raw))
    $storageSkus = @() + (ConvertFrom-Json (Get-Content -Path ($defaults + "\AzureStack.storageSkus.json") -Raw))
    
    $allowResources = @()

    foreach ($p in $providerMetadata.value) {
        foreach ($r in $p.resourceTypes) {
            $allowResources += @{ field = "type"; equals = $p.namespace + "/" + $r.ResourceType}
            $allowResources += @{ field = "type"; like = $p.namespace + "/" + $r.ResourceType + "/*" }
        }
    }

    $vmSkuField = "Microsoft.Compute/virtualMachines/sku.name"
    $storageSkuField = "Microsoft.Storage/storageAccounts/sku.name"

    $policy = @{
        if   = @{
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
                                            field  = $vmSkuField;
                                            exists = "true"
                                        },
                                        @{
                                            not = @{
                                                field = $vmSkuField;
                                                in    = $vmSkus
                                            }
                                        }
                                    )
                                },
                                @{
                                    allOf = @(
                                        @{
                                            field  = $storageSkuField;
                                            exists = "true"
                                        },
                                        @{
                                            not = @{
                                                field = $storageSkuField;
                                                in    = $storageSkus
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

Export-ModuleMember Get-AzsPolicy
