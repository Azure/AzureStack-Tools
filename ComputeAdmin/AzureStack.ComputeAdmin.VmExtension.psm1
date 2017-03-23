# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Modules AzureStack.Connect

<#
    .SYNOPSIS
    Contains 2 functions.
    Add-VMExtension: Uploads a VM extension to your Azure Stack.
    Remove-VMExtension: Removes an existing VM extension from your Azure Stack.
#>


Function Add-VMExtension{

    [CmdletBinding(DefaultParameterSetName='VMExtensionFromLocal')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $publisher,

        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [ValidatePattern(“\d+\.\d+\.\d+”)]
        [String] $version,

        [Parameter(ParameterSetName='VMExtensionFromLocal')]
        [Parameter(ParameterSetName='VMExtesionFromAzure')]
        [String] $type,

        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [ValidateNotNullorEmpty()]
        [String] $extensionLocalPath,

        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $extensionBlobURI,

        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [ValidateSet('Windows' ,'Linux')]
        [String] $osType,

        [Parameter(ParameterSetName='VMExtensionFromLocal')]
        [Parameter(ParameterSetName='VMExtesionFromAzure')]
        [String] $vmScaleSetEnabled = "false",

        [Parameter(ParameterSetName='VMExtensionFromLocal')]
        [Parameter(ParameterSetName='VMExtesionFromAzure')]
        [String] $supportMultipleExtensions = "false",
    
        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [Parameter(ParameterSetName='VMExtensionFromLocal')]
        [Parameter(ParameterSetName='VMExtesionFromAzure')]
        [String] $location = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='VMExtensionFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='VMExtesionFromAzure')]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='VMExtensionFromLocal')]
        [Parameter(ParameterSetName='VMExtesionFromAzure')]
        [string] $ArmEndpoint = 'https://adminmanagement.local.azurestack.external'
    )

    $resourceGroupName = "addvmextresourcegroup"
    $storageAccountName = "addvmextstorageaccount"
    $containerName = "addvmextensioncontainer"

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint)

    #potentially the RG was not cleaned up when exception happened in previous run. Test for exist
    if (-not (Get-AzureRmResourceGroup -Name $resourceGroupName -Location $location -ErrorAction SilentlyContinue)) {
        New-AzureRmResourceGroup -Name $resourceGroupName -Location $location 
    }

    #same for storage
    $storageAccount = Get-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    if (-not ($storageAccount)) {
        $storageAccount = New-AzureRmStorageAccount -Name $storageAccountName -Location $location -ResourceGroupName $resourceGroupName -Type Standard_LRS
    }

    Set-AzureRmCurrentStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName
    
    #same for container
    $container = Get-AzureStorageContainer -Name $containerName -ErrorAction SilentlyContinue
    if (-not ($container)) {
        $container = New-AzureStorageContainer -Name $containerName -Permission Blob
    }

    if($pscmdlet.ParameterSetName -eq "VMExtensionFromLocal")
    {
        $storageAccount.PrimaryEndpoints.Blob
        $script:extensionName = Split-Path $extensionLocalPath -Leaf
        $script:extensionBlobURIFromLocal = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName,$extensionName
        Set-AzureStorageBlobContent -File $extensionLocalPath -Container $containerName -Blob $extensionName
    }

    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")
    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/VMExtension/publishers/' + $publisher
    $uri = $uri + '/types/' + $type + '/versions/' + $version + '?api-version=2015-12-01-preview'

    #building request body JSON
    if($pscmdlet.ParameterSetName -eq "VMExtensionFromLocal") {
        $sourceBlobJSON = '"SourceBlob" : {"Uri" :"' + $extensionBlobURIFromLocal + '"}'
    }
    else {
        $sourceBlobJSON = '"SourceBlob" : {"Uri" :"' + $extensionBlobURI + '"}'
    }
    
    $osTypeJSON = '"VmOsType" : "' + $osType + '"'
    $ComputeRoleJSON = '"ComputeRole" : "N/A"'
    $VMScaleSetEnabledJSON = '"VMScaleSetEnabled" : "' + $vmScaleSetEnabled + '"'
    $SupportMultipleExtensionsJSON = '"SupportMultipleExtensions" : "' + $supportMultipleExtensions + '"'
    $IsSystemExtensionJSON = '"IsSystemExtension" : "false"'

    $propertyBody = $sourceBlobJSON + "," + $osTypeJSON + ',' + $ComputeRoleJSON + "," + $VMScaleSetEnabledJSON + "," + $SupportMultipleExtensionsJSON + "," + $IsSystemExtensionJSON 

    #building ARMResource

    $RequestBody = '{"Properties":{'+$propertyBody+'}}'

    Invoke-RestMethod -Method PUT -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $Headers

    $extensionHandler = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers

    while($extensionHandler.Properties.ProvisioningState -ne 'Succeeded')
    {
        if($extensionHandler.Properties.ProvisioningState -eq 'Failed')
        {
            Write-Error -Message "VM extension download failed." -ErrorAction Stop
        }

        if($extensionHandler.Properties.ProvisioningState -eq 'Canceled')
        {
            Write-Error -Message "VM extension download was canceled." -ErrorAction Stop
        }

        Write-Host "Downloading";
        Start-Sleep -Seconds 4
        $extensionHandler = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    }

    Remove-AzureStorageContainer –Name $containerName -Force
    Remove-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName 
    Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
}

Function Remove-VMExtension{
    Param(
        [ValidatePattern(“[a-zA-Z0-9-]{3,}”)]
        [String] $publisher,

        [Parameter(Mandatory=$true)]
        [ValidatePattern(“\d+\.\d+\.\d+”)]
        [String] $version,

        [String] $type = "CustomScriptExtension",

        [Parameter(Mandatory=$true)]
        [ValidateSet('Windows' ,'Linux')]
        [String] $osType,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [String] $location = 'local',

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [string] $ArmEndpoint = 'https://adminmanagement.local.azurestack.external'
    )

    $subscription, $headers =  (Get-AzureStackAdminSubTokenHeader -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint)

    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")
    $uri = $armEndpoint + '/subscriptions/' + $subscription + '/providers/Microsoft.Compute.Admin/locations/' + $location + '/artifactTypes/VMExtension/publishers/' + $publisher
    $uri = $uri + '/types/' + $type + '/versions/' + $version + '?api-version=2015-12-01-preview'

    try{
        Invoke-RestMethod -Method DELETE -Uri $uri -ContentType 'application/json' -Headers $headers
    }
    catch{
        Write-Error -Message ('Deletion of VM extension with publisher "{0}" failed with Error:"{1}.' -f $publisher,$Error) -ErrorAction Stop
    }
}