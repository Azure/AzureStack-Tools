# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Modules AzureStack.Connect

<#
    .SYNOPSIS
    Contains 3 functions.
    Add-GalleryItem: Uploads a gallery item azpkg to Azure stack marketplace.
    Get-GalleryItem: Gets a gallery item existed in Azure stack marketplace.
    Remove-GalleryItem: Removes gallery item from Azure stack marketplace.
#>

Function Add-GalleryItem{

    [CmdletBinding(DefaultParameterSetName='GalleryItemFromLocal')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromLocal')]
        [ValidateNotNullorEmpty()]
        [String] $galleryItemLocalPath,

        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $galleryItemBlobURI,

        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [Parameter(ParameterSetName='GalleryItemFromLocal')]
        [Parameter(ParameterSetName='GalleryItemFromAzure')]
        [String] $location = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromAzure')]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GalleryItemFromLocal')]
        [Parameter(ParameterSetName='GalleryItemFromAzure')]
        [string] $ArmEndpoint = 'https://adminmanagement.local.azurestack.external'
    )

    $resourceGroupName = "addiresourcegroup"
    $storageAccountName = "addgistorageaccount"
    $containerName = "addgicontainer"

    $subscription = (Get-AzureStackAdminSubscription -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint)

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

    if($pscmdlet.ParameterSetName -eq "GalleryItemFromLocal") {
        $storageAccount.PrimaryEndpoints.Blob
        $script:galleryItemName = Split-Path $galleryItemLocalPath -Leaf
        $script:galleryItemBlobURIFromLocal = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName,$galleryItemName
        Set-AzureStorageBlobContent -File $galleryItemLocalPath -Container $containerName -Blob $galleryItemName
        $galleryItemBlobURI = $galleryItemBlobURIFromLocal
    }

    if((Get-Module AzureStack).Version -ge [System.Version] "1.2.9"){
        Add-AzureRMGalleryItem -GalleryItemUri $galleryItemBlobURI
    }else{
        Add-AzureRMGalleryItem -SubscriptionId $subscription -GalleryItemUri $galleryItemBlobURI -ApiVersion 2015-04-01
    }

    Remove-AzureStorageContainer –Name $containerName -Force
    Remove-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName 
    Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
}

Function Get-GalleryItem{
    Param(
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $GalleryItemName
    )

    $subscription = (Get-AzureStackAdminSubscription -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint)

    if((Get-Module AzureStack).Version -ge [System.Version] "1.2.9"){
        Get-AzureRMGalleryItem -Name $GalleryItemName
    }else{
        Get-AzureRMGalleryItem -SubscriptionId $subscription -Name $GalleryItemName -ApiVersion '2015-04-01'
    }
}

Function Remove-GalleryItem{
    Param(
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $GalleryItemName
    )

    $subscription = (Get-AzureStackAdminSubscription -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -ArmEndpoint $ArmEndpoint)

    if((Get-Module AzureStack).Version -ge [System.Version] "1.2.9"){
        Remove-AzureRMGalleryItem -Name $GalleryItemName
    }else{
        Remove-AzureRMGalleryItem -SubscriptionId $subscription -Name $GalleryItemName -ApiVersion '2015-04-01'
    }
}

function Get-AzureStackAdminSubscription {
    param (
        [parameter(HelpMessage="Name of the Azure Stack Environment")]
        [string] $EnvironmentName = "AzureStack",
	
        [parameter(mandatory=$true, HelpMessage="TenantID of Identity Tenant")]
        [string] $tenantID,

        [parameter(HelpMessage="Credentials to retrieve token header for")]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(HelpMessage="The administration ARM endpoint of the Azure Stack Environment")]
        [string] $ArmEndpoint = 'https://adminmanagement.local.azurestack.external'
    )

    if(-not $azureStackCredentials){
        $azureStackCredentials = Get-Credential
    }
    
    if(!$ARMEndpoint.Contains('https://')){
        if($ARMEndpoint.Contains('http://')){
            $ARMEndpoint = $ARMEndpoint.Substring(7)
            $ARMEndpoint = 'https://' + $ARMEndpoint
        }else{
            $ARMEndpoint = 'https://' + $ARMEndpoint
        }
    }
    
    $ArmEndpoint = $ArmEndpoint.TrimEnd("/")

    try{
        Invoke-RestMethod -Method Get -Uri "$($ARMEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -ErrorAction Stop | Out-Null
    }catch{
        Write-Error "The specified ARM endpoint: $ArmEndpoint is not valid for this environment. Please make sure you are using the correct administrator ARM endpoint for this environment." -ErrorAction Stop
    }

    $Domain = ""
    try {
        $uriARMEndpoint = [System.Uri] $ArmEndpoint
        $i = $ArmEndpoint.IndexOf('.')
        $Domain = ($ArmEndpoint.Remove(0,$i+1)).TrimEnd('/')
    }
    catch {
        Write-Error "The specified ARM endpoint was invalid"
    }

    $subscriptionName = "Default Provider Subscription"

    if (-not (Get-AzureRmEnvironment -Name AzureStack -ErrorAction SilentlyContinue)){
        Add-AzureStackAzureRmEnvironment -AadTenant $tenantID -ArmEndpoint $ArmEndpoint | Out-Null
    }

    $azureStackEnvironment = Get-AzureRmEnvironment -Name AzureStack -ErrorAction SilentlyContinue
    $authority = $azureStackEnvironment.ActiveDirectoryAuthority
    $activeDirectoryServiceEndpointResourceId = $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId

    Login-AzureRmAccount -EnvironmentName "AzureStack" -TenantId $tenantID -Credential $azureStackCredentials | Out-Null

    try {
        $subscription = Get-AzureRmSubscription -SubscriptionName $subscriptionName 
    }
    catch {
        Write-Error "Verify that the login credentials are for the administrator and that the specified ARM endpoint: $ArmEndpoint is the valid administrator ARM endpoint for this environment." -ErrorAction Stop
    }

    $subscription | Select-AzureRmSubscription | Out-Null
   
    return $subscription.SubscriptionId
}