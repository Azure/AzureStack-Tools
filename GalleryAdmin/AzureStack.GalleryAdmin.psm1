#requires -Version 4.0
#requires -Modules AzureRM.Profile, AzureRm.AzureStackAdmin, AzureRM.Storage, Azure.Storage

<#
    .SYNOPSIS
    Get-AzureRMGalleryItemContent
    Retireves an existing Gallery Item and outputs it to a directory
    Does not take pipeline input, yet.

    Update-AzureRMGalleryItem (coming soon)
    Updates an existing Azure Gallery Item
#>

Function Get-AzureRMGalleryItemContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $GalleryItemName,

        [Parameter(Mandatory=$true)]
        [String] $TargetDirectory,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String] $tenantID,

        [String] $location = 'local',

        #Whether or not to overwrite the contents of the destination directory
        [Switch] $Force

    )

    #Validate Path
    if(-not (Test-Path $TargetDirectory)){
        Throw "Path $TargetDirectory does not exist"
        Exit
    }

    if(-not (Get-Item $TargetDirectory).PSIsContainer){
        Throw "$TargetDirectory is not a directory"
        Exit
    }

    #check if target directory is not empty
    if(Test-Path (Join-Path -Path $TargetDirectory -ChildPath $GalleryItemName)){
        Write-Verbose "Path $TargetDirectory\$GalleryItemName exists"
        if((Get-ChildItem (Join-Path -Path $TargetDirectory -ChildPath $GalleryItemName)).count -gt 0){
            If($Force){
                Write-Verbose "Path $TargetDirectory\$GalleryItemName is not empty, and will be overwritten"
            }
            Else{
                Throw "Path $TargetDirectory\$GalleryItemName is not empty, run command with -Force to overwrite"
            }
        }
    }

    #Connect to Azure Stack Environment and Subscription
    $subscriptionName = "Default Provider Subscription"

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"

    Add-AzureRmEnvironment -Name 'Azure Stack' `
        -ActiveDirectoryEndpoint $authority `
        -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId `
        -ResourceManagerEndpoint  "https://api.$azureStackDomain/" `
        -GalleryEndpoint $galleryEndpoint `
        -GraphEndpoint $graphEndpoint

    $environment = Get-AzureRmEnvironment 'Azure Stack'

    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials

    Select-AzureRmProfile -Profile $profile
    $subscription = Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription

    #Validate Gallery Item Exists
    try{
        Write-Verbose "Looking for $GalleryItemName in the gallery"
        $item = Get-AzureRMGalleryItem -Name $GalleryItemName -SubscriptionId $subscription.Subscription.SubscriptionId -ApiVersion 2015-04-01
        Write-Verbose "Item $($item.Name) found in the gallery"
    }
    catch{
        Write-Error "$GalleryItemName not found in the Gallery"
        exit
    }
    try{

        $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName System.Gallery -Name "systemgallery"
        Write-Verbose "Retrieved Storage Account $($storageAccount.StorageAccountName)"

        Write-Verbose "Create Storage Context"
        $ctx = $storageAccount.Context

        $cont = Get-AzureStorageContainer -Context $ctx | Sort-Object -Property LastModified -Descending | Select-Object -First 1
        Write-Verbose "Retrieved Container Name $($cont.Name)"

        Write-Verbose "Retrieving Blobs"
        $blobs = Get-AzureStorageBlob -Container $cont.Name -Context $ctx -Prefix $item.Name

        Write-Verbose "Copying Blob Content to Target Directory"
        $blobs | %{Get-AzureStorageBlobContent -Blob $_.Name -Container $cont.Name -Destination $TargetDirectory -Context $ctx -Force}
    }
    catch{
        Write-Error "Errors occured getting Blob items: $Error[0]"
        Exit
    }
}

Export-ModuleMember Get-AzureRMGalleryItemContent