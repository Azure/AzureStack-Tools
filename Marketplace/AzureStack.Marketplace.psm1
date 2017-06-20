# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

#requires -Modules AzureStack.Connect

<#
    .SYNOPSIS
    Contains 4 functions.
    Add-GalleryItem: Uploads a gallery item azpkg from local folder to Azure stack marketplace.
    Add-ProviderGalleryItem: Uploads a provider gallery item azpkg from local folder to Azure stack marketplace.
    Get-ProviderGalleryItem: Gets a gallery item existed in Azure stack marketplace.
    Remove-ProviderGalleryItem: Removes provider gallery item from Azure stack marketplace.
#>

Function Add-GalleryItem{

    [CmdletBinding(DefaultParameterSetName='GalleryItemFromLocal')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromLocal')]
        [ValidateNotNullorEmpty()]
        [ValidateScript({Test-Path $_})]
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
        [string] $armEndpoint = 'https://api.local.azurestack.external'
    )

    $resourceGroupName = "addgiresourcegroup"
    $storageAccountName = "addgistorageaccount"
    $containerName = "addgicontainer"

    $subscription = (Get-AzureStackAdminSubscription -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint)

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

    Add-AzureRMGalleryItem -GalleryItemUri $galleryItemBlobURI

    Remove-AzureStorageContainer –Name $containerName -Force
    Remove-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName 
    Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
}

Function Add-ProviderGalleryItem{

    [CmdletBinding(DefaultParameterSetName='GalleryItemFromLocal')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromLocal')]
        [ValidateNotNullorEmpty()]
        [ValidateScript({Test-Path $_})]
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
        [ValidateNotNullorEmpty()]
        [String] $resourceGroupName = 'system.local',

        [Parameter(ParameterSetName='GalleryItemFromLocal')]
        [Parameter(ParameterSetName='GalleryItemFromAzure')]
        [String] $location = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $providerNameSpace,

        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromAzure')]
        [ValidateNotNullorEmpty()]
        [String] $providerLocation,

        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromLocal')]
        [Parameter(Mandatory=$true, ParameterSetName='GalleryItemFromAzure')]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GalleryItemFromLocal')]
        [Parameter(ParameterSetName='GalleryItemFromAzure')]
        [string] $armEndpoint = 'https://api.local.azurestack.external'
    )

    $environmentName = "AzureStack"
    $storageAccountName = "addpgistorageaccount"
    $containerName = "addpgicontainer"

    $subscription = (Get-AzureStackAdminSubscription -environmentName $environmentName -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint)

    #potentially the storage was not cleaned up when exception happened in previous run. Test for exist
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
        $script:providerGalleryItemName = Split-Path $galleryItemLocalPath -Leaf
        $script:galleryItemBlobURIFromLocal = '{0}{1}/{2}' -f $storageAccount.PrimaryEndpoints.Blob.AbsoluteUri, $containerName,$providerGalleryItemName
        Set-AzureStorageBlobContent -File $galleryItemLocalPath -Container $containerName -Blob $providerGalleryItemName
        $galleryItemBlobURI = $galleryItemBlobURIFromLocal
    }

    $providerGalleryItemId = $galleryItemBlobURI.Split('/')[-1] | % { $_.Substring(0,$_.LastIndexOf('.')) }

    $armEndpoint = $armEndpoint.TrimEnd("/") 
    $resourceId = '/subscriptions/' + $subscription + '/resourceGroups/' + $resourceGroupName + '/providers/Microsoft.Gallery.Providers/GalleryItems/' + $providerGalleryItemId
    $uri = $armEndpoint + $resourceId + '?api-version=2015-04-01'

    Write-Host $uri 

    $headers = (Get-AzureStackAdminToken -environmentName $environmentName -tenantID $tenantID -azureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint)

    #building request body JSON 
    
    if($pscmdlet.ParameterSetName -eq "GalleryItemFromLocal") { 
        $sourceBlobJSON = '"GalleryItemUri" :"' + $galleryItemBlobURIFromLocal + '"' 
    } 
    else { 
        $sourceBlobJSON = '"GalleryItemUri" :"' + $galleryItemBlobURI + '"' 
    } 

    $type = "Microsoft.Gallery.Providers/GalleryItems"
    $providerNamespace = '"ProviderNamespace" : "' + $providerNamespace + '"' 
    $providerLocation = '"ProviderLocation" : "' + $providerLocation + '"' 
    $galleryItemId = '"GalleryItemId" : "' + $providerGalleryItemId + '"' 

    $propertyBody = $sourceBlobJSON + "," + $providerNamespace + ',' + $providerLocation + "," + $galleryItemId 

    #building ARMResource 

    $RequestBody = '{"Id":"'+$resourceId+'","Name":"'+$providerGalleryItemId+'","Type":"'+$type+'","Location":"'+$location+'","Properties":{'+$propertyBody+'}}' 

    Write-Host $RequestBody

    Invoke-RestMethod -Method PUT -Uri $uri -Body $RequestBody -ContentType 'application/json' -Headers $headers 

    $providerGalleryItemHandler = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $headers 

    while($providerGalleryItemHandler.Properties.ProvisioningState -ne 'Succeeded') 
    { 
        if($providerGalleryItemHandler.Properties.ProvisioningState -eq 'Failed') 
        { 
            Write-Error -Message ('Provider gallery item download failed with Error:"{0}.' -f $_.Exception.Message ) -ErrorAction Stop 
        } 

        if($providerGalleryItemHandler.Properties.ProvisioningState -eq 'Canceled') 
        { 
            Write-Error -Message "Provider gallery item download was canceled." -ErrorAction Stop 
        } 

        Write-Host "Downloading"; 
        Start-Sleep -Seconds 4 
        $providerGalleryItemHandler = Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $headers 
    } 

    Remove-AzureStorageContainer –Name $containerName -Force
    Remove-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName 
}

Function Get-ProviderGalleryItem{
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $galleryItemId,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [ValidateNotNullorEmpty()]
        [String] $resourceGroupName = 'system.local',

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [string] $armEndpoint = 'https://api.local.azurestack.external'

    )

    $environmentName = "AzureStack"
    $subscription = (Get-AzureStackAdminSubscription -environmentName $environmentName -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint)

    $armEndpoint = $armEndpoint.TrimEnd("/") 
    $resourceId = '/subscriptions/' + $subscription + '/resourceGroups/' + $resourceGroupName + '/providers/Microsoft.Gallery.Providers/GalleryItems/' + $galleryItemId
    $uri = $armEndpoint + $resourceId + '?api-version=2015-04-01'

    Write-Host $uri 

    $headers = (Get-AzureStackAdminToken -environmentName $environmentName -tenantID $tenantID -azureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint)

    Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $headers 
}

Function Remove-ProviderGalleryItem{
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $galleryItemId,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [ValidateNotNullorEmpty()]
        [String] $resourceGroupName = 'system.local',

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [string] $armEndpoint = 'https://api.local.azurestack.external'
    )

    $environmentName = "AzureStack"
    $subscription = (Get-AzureStackAdminSubscription -environmentName $environmentName -TenantId $tenantId -AzureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint)

    $armEndpoint = $armEndpoint.TrimEnd("/") 
    $resourceId = '/subscriptions/' + $subscription + '/resourceGroups/' + $resourceGroupName + '/providers/Microsoft.Gallery.Providers/GalleryItems/' + $galleryItemId
    $uri = $armEndpoint + $resourceId + '?api-version=2015-04-01'

    Write-Host $uri 
    
    $headers = (Get-AzureStackAdminToken -environmentName $environmentName -tenantID $tenantID -azureStackCredentials $azureStackCredentials -armEndpoint $armEndpoint)

    Invoke-RestMethod -Method DELETE -Uri $uri -ContentType 'application/json' -Headers $headers 
}

function Get-AzureStackAdminSubscription {
    param (
        [parameter(HelpMessage="Name of the Azure Stack Environment")]
        [string] $environmentName = "AzureStack",
	
        [parameter(mandatory=$true, HelpMessage="TenantID of Identity Tenant")]
        [string] $tenantID,

        [parameter(HelpMessage="Credentials to retrieve token header for")]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(HelpMessage="The administration ARM endpoint of the Azure Stack Environment")]
        [string] $armEndpoint = 'https://api.local.azurestack.external'
    )

    if(-not $azureStackCredentials){
        $azureStackCredentials = Get-Credential
    }
    
    if(!$armEndpoint.StartsWith('https://')){
        if($armEndpoint.StartsWith('http://')){
           $armEndpoint.Replace('http://', 'https://')
        }else{
            $armEndpoint = 'https://' + $armEndpoint
        }
    }
    
    $armEndpoint = $armEndpoint.TrimEnd("/")

    try{
        Invoke-RestMethod -Method Get -Uri "$($armEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -ErrorAction Stop | Out-Null
    }catch{
        Write-Error "The specified ARM endpoint: $armEndpoint is not valid for this environment. Please make sure you are using the correct administrator ARM endpoint for this environment." -ErrorAction Stop
    }

    $subscriptionName = "Default Provider Subscription"

    if (-not (Get-AzureRmEnvironment -Name AzureStack -ErrorAction SilentlyContinue)){
        Add-AzureStackAzureRmEnvironment -AadTenant $tenantID -ArmEndpoint $armEndpoint | Out-Null
    }

    $azureStackEnvironment = Get-AzureRmEnvironment -Name AzureStack -ErrorAction SilentlyContinue
    $authority = $azureStackEnvironment.ActiveDirectoryAuthority
    $activeDirectoryServiceEndpointResourceId = $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId

    Login-AzureRmAccount -EnvironmentName "AzureStack" -TenantId $tenantID -Credential $azureStackCredentials | Out-Null

    try {
        $subscription = Get-AzureRmSubscription -SubscriptionName $subscriptionName 
    }
    catch {
        Write-Error "Verify that the login credentials are for the administrator and that the specified ARM endpoint: $armEndpoint is the valid administrator ARM endpoint for this environment." -ErrorAction Stop
    }

    $subscription | Select-AzureRmSubscription | Out-Null
   
    return $subscription.SubscriptionId
}

function Get-AzureStackAdminToken {
    param (
        [parameter(HelpMessage="Name of the Azure Stack Environment")]
        [string] $environmentName = "AzureStack",
	
        [parameter(mandatory=$true, HelpMessage="TenantID of Identity Tenant")]
        [string] $tenantID,

        [parameter(HelpMessage="Credentials to retrieve token header for")]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(HelpMessage="The administration ARM endpoint of the Azure Stack Environment")]
        [string] $armEndpoint = 'https://api.local.azurestack.external'
    )

    $azureStackEnvironment = Get-AzureRmEnvironment -Name $environmentName -ErrorAction SilentlyContinue
    $authority = $azureStackEnvironment.ActiveDirectoryAuthority
    $activeDirectoryServiceEndpointResourceId = $azureStackEnvironment.ActiveDirectoryServiceEndpointResourceId

    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"

    $adminToken = Get-AzureStackToken `
        -Authority $authority `
        -Resource $activeDirectoryServiceEndpointResourceId `
        -AadTenantId $tenantID `
        -ClientId $powershellClientId `
        -Credential $azureStackCredentials 

    $headers = @{ Authorization = ("Bearer $adminToken") }
    
    return $headers
}

<#
    .SYNOPSIS
    Adds Azure Stack environment to use with AzureRM command-lets when targeting Azure Stack
#>
function Add-AzureStackAzureRmEnvironment {
    param (
        [parameter(mandatory=$true, HelpMessage="AAD Tenant name or ID used when deploying Azure Stack such as 'mydirectory.onmicrosoft.com'")]
        [string] $AadTenant,
        [Parameter(HelpMessage="The Admin ARM endpoint of the Azure Stack Environment")]
        [string] $armEndpoint = 'https://api.local.azurestack.external',
        [parameter(HelpMessage="Azure Stack environment name for use with AzureRM commandlets")]
        [string] $Name = "AzureStack"
    )

    if(!$armEndpoint.StartsWith('https://')){
        if($armEndpoint.StartsWith('http://')){
           $armEndpoint.Replace('http://', 'https://')
        }else{
            $armEndpoint = 'https://' + $armEndpoint
        }
    }

    $armEndpoint = $armEndpoint.TrimEnd("/")

    $Domain = ""
    try {
        $uriARMEndpoint = [System.Uri] $ArmEndpoint
        $i = $ArmEndpoint.IndexOf('.')
        $Domain = ($ArmEndpoint.Remove(0,$i+1)).TrimEnd('/')
    }
    catch {
        Write-Error "The specified ARM endpoint was invalid"
    }

    $ResourceManagerEndpoint = $armEndpoint 
    $stackdomain = $Domain         

    Write-Verbose "Retrieving endpoints from the $ResourceManagerEndpoint..." -Verbose
    $endpoints = Invoke-RestMethod -Method Get -Uri "$($ResourceManagerEndpoint.ToString().TrimEnd('/'))/metadata/endpoints?api-version=2015-01-01" -ErrorAction Stop

    $AzureKeyVaultDnsSuffix="vault.$($stackdomain)".ToLowerInvariant()
    $AzureKeyVaultServiceEndpointResourceId= $("https://vault.$stackdomain".ToLowerInvariant())
    $StorageEndpointSuffix = ($stackdomain).ToLowerInvariant()
    $aadAuthorityEndpoint = $endpoints.authentication.loginEndpoint

    $azureEnvironmentParams = @{
        Name                                     = $Name
        ActiveDirectoryEndpoint                  = $endpoints.authentication.loginEndpoint.TrimEnd('/') + "/"
        ActiveDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
        AdTenant                                 = $AadTenant
        ResourceManagerEndpoint                  = $ResourceManagerEndpoint
        GalleryEndpoint                          = $endpoints.galleryEndpoint
        GraphEndpoint                            = $endpoints.graphEndpoint
        GraphAudience                            = $endpoints.graphEndpoint
        StorageEndpointSuffix                    = $StorageEndpointSuffix
        AzureKeyVaultDnsSuffix                   = $AzureKeyVaultDnsSuffix
        AzureKeyVaultServiceEndpointResourceId   = $AzureKeyVaultServiceEndpointResourceId
        EnableAdfsAuthentication                 = $aadAuthorityEndpoint.TrimEnd("/").EndsWith("/adfs", [System.StringComparison]::OrdinalIgnoreCase)
    }

    $armEnv = Get-AzureRmEnvironment -Name $Name
    if($armEnv -ne $null) {
        Write-Verbose "Updating AzureRm environment $Name" -Verbose
        Remove-AzureRmEnvironment -Name $Name | Out-Null
    }
    else {
        Write-Verbose "Adding AzureRm environment $Name" -Verbose
    }
        
    return Add-AzureRmEnvironment @azureEnvironmentParams
}