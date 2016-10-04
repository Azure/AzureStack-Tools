# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.
<#
    .SYNOPSIS
    Manage Azure Stack Infrastructure 
    Requires AzureRm.AzureStackAdmin module
#>


Function Get-AzureStackAlert{

<#
    .SYNOPSIS
    List Active & Closed Infrastructure Alerts
#>

    [CmdletBinding(DefaultParameterSetName='GetAlert')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetAlert')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetAlert')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,
	
        [Parameter(ParameterSetName='GetAlert')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='GetAlert')]
        [string] $region = 'local'

        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"

    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
        
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.InfrastructureInsights.Admin/regionHealths/$region/Alerts?api-version=2016-05-01"
   $Alert=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
   $Alerts=$Alert.value
   $Alertsprop=$alerts.properties 
   $alertsprop |select alertid,state,title,resourcename,createdtimestamp,remediation |fl 
       }
export-modulemember -function Get-AzureStackAlert

Function Get-AzureStackScaleUnit{

<#
    .SYNOPSIS
    List Azure Stack Scale Units in specified Region
#>

    [CmdletBinding(DefaultParameterSetName='ScaleUnit')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='ScaleUnit')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='ScaleUnit')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='ScaleUnit')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='ScaleUnit')]
        [string] $region = 'local'

        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"

    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"

    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
        
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Fabric.Admin/fabricLocations/$region/clusters?api-version=2016-05-01"
   $Cluster=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
   $Cluster.value |select name,location |fl 
       }
       
export-modulemember -function Get-AzureStackScaleUnit

Function Get-AzureStackNode{

<#
    .SYNOPSIS
    List Nodes in Scale Unit 
#>

    [CmdletBinding(DefaultParameterSetName='GetNode')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetNode')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetNode')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GetNode')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='GetNode')]
        [string] $region = 'local'

        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
        
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Fabric.Admin/fabricLocations/$region/clusters?api-version=2016-05-01"
   $Cluster=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
   $Clusterprop=$cluster.value
   $clusterprop.properties|select servers|fl 
       }
       
export-modulemember -function Get-AzureStackNode

Function Get-AzureStackStorageCapacity{

<#
    .SYNOPSIS
    List total storage capacity 
#>

    [CmdletBinding(DefaultParameterSetName='GetStorageCapacity')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetStorageCapacity')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetStorageCapacity')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GetStorageCapacity')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='GetStorageCapacity')]
        [string] $region = 'local'
        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Fabric.Admin/fabricLocations/$region/storagesubSystems?api-version=2016-05-01"
    $Storage=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Storageprop=$storage.value
    $storageprop.properties|select totalcapacityGB|fl
       }

export-modulemember -function Get-AzureSt

Function Get-AzureStackInfraRole{

<#
    .SYNOPSIS
    List Infrastructure Roles 
#>

    [CmdletBinding(DefaultParameterSetName='GetInfraRole')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetInfraRole')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetInfraRole')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GetInfraRole')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='GetInfraRole')]
        [string] $region = 'local'
        )

     

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Fabric.Admin/fabricLocations/$region/applications?api-version=2016-05-01"
    $Roles=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Roleprop=$roles.value
    $Roleprop.Name|fl 
       }

Function Get-AzureStackInfraVM{

<#
    .SYNOPSIS
    List Infrastructure Role Instances
#>

    [CmdletBinding(DefaultParameterSetName='GetInfraVM')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetInfraVM')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetInfraVM')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GetInfraVM')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='GetInfraVM')]
        [string] $region = 'local'
        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Fabric.Admin/fabricLocations/$region/infraVirtualMachines?api-version=2016-05-01"
    $VMs=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $VMprop=$VMs.value
    $VMprop|ft name 
       }

Function Get-AzureStackStorageShare{

<#
    .SYNOPSIS
    List File Shares
#>

    [CmdletBinding(DefaultParameterSetName='GetShare')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetShare')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetShare')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GetShare')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='GetShare')]
        [string] $region = 'local'
        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Fabric.Admin/fabricLocations/$region/fileShares?api-version=2016-05-01"
    $Shares=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Shareprop=$Shares.value
    $Shareprop.properties|select uncPath|fl
       }

Function Get-AzureStacklogicalnetwork{

<#
    .SYNOPSIS
    List Logical Networks
#>

    [CmdletBinding(DefaultParameterSetName='Getlogicalnetwork')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='Getlogicalnetwork')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='Getlogicalnetwork')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='Getlogicalnetwork')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='Getlogicalnetwork')]
        [string] $region = 'local'
        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
		$armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Fabric.Admin/fabricLocations/$region/logicalNetworks?api-version=2016-05-01"
   $LNetworks=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
   $LNetworkprop=$LNetworks.value
   $LNetworkprop|ft name
       }

Function Get-AzureStackUpdateSummary{

<#
    .SYNOPSIS
    List Region Update Summary
#>

    [CmdletBinding(DefaultParameterSetName='GetUpdateSummary')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateSummary')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateSummary')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GetUpdateSummary')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='GetUpdateSummary')]
        [string] $region = 'local'
        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Update.Admin/updatelocations/$region/regionUpdateStatus?api-version=2016-05-01"
    $USummary=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $USummaryprop=$USummary.value
    $USummaryprop.properties|select locationName,currentversion,lastUpdated,lastChecked,state|fl 
       }

Function Get-AzureStackUpdate{

<#
    .SYNOPSIS
    List Available Updates
#>

    [CmdletBinding(DefaultParameterSetName='GetUpdate')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdate')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdate')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GetUpdate')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='GetUpdate')]
        [string] $region = 'local'
        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Update.Admin/updatelocations/$region/updates?api-version=2016-05-01"
    $Updates=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updateprop=$Updates.value
    $Updateprop.properties|select updateName,version,isApplicable,description,state,isDownloaded,packageSizeInMb,kblink|fl
       }

Function Get-AzureStackUpdateRun{

<#
    .SYNOPSIS
    List Status for a specific Update Run
#>

    [CmdletBinding(DefaultParameterSetName='GetUpdateRun')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateRun')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateRun')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='GetUpdateRun')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='GetUpdateRun')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='GetUpdateRun')]
        [ValidateNotNullorEmpty()]
        [String] $vupdate
        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint | Out-Null 
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Update.Admin/updatelocations/$region/updates/$vupdate/updateRuns?api-version=2016-05-01"
    $UpdateRuns=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updaterunprop=$UpdateRuns.value
    $Updaterunprop.properties|select updateLocation,updateversion,state,timeStarted,duration|fl 
       }

Function Apply-AzureStackUpdate{

<#
    .SYNOPSIS
    Apply Azure Stack Update 
#>

    [CmdletBinding(DefaultParameterSetName='ApplyUpdate')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='ApplyUpdate')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='ApplyUpdate')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='ApplyUpdate')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='ApplyUpdate')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='ApplyUpdate')]
        [ValidateNotNullorEmpty()]
        [String] $vupdate
        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null 
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Update.Admin/updatelocations/$region/updates?api-version=2016-05-01"
    $Updates=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Updateprop=$Updates.value
    $Update=$updateprop |where-object {$_.name -eq "$vupdate"}
    $StartUpdateBody = $update | ConvertTo-Json
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.Update.Admin/updatelocations/$region/updates/$vupdate ?api-version=2016-05-01"
    $Runs=Invoke-RestMethod -Method PUT -Uri $uri -ContentType 'application/json' -Headers $Headers -Body $StartUpdateBody
    $Startrun=$Runs.value
    $Startrun   
       }

Function Close-AzureStackAlert{

<#
    .SYNOPSIS
    Close Active Alert
#>

    [CmdletBinding(DefaultParameterSetName='closealert')]
    Param(
    
        [Parameter(Mandatory=$true, ParameterSetName='closealert')]
        [ValidateNotNullorEmpty()]
        [String] $TenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='closealert')]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential] $azureStackCredentials,

        [Parameter(ParameterSetName='closealert')]
        [string] $azureStackDomain = 'azurestack.local',

        [Parameter(ParameterSetName='closealert')]
        [string] $region = 'local',

        [Parameter(Mandatory=$true, ParameterSetName='closealert')]
        [ValidateNotNullorEmpty()]
        [String] $alertid
        )

    $endpoints = (Invoke-RestMethod -Uri https://api.$azureStackDomain/metadata/endpoints?api-version=1.0 -Method Get)
    $activeDirectoryServiceEndpointResourceId = $endpoints.authentication.audiences[0]
    $galleryEndpoint = $endpoints.galleryEndpoint
    $graphEndpoint = $endpoints.graphEndpoint
    $loginEndpoint = $endpoints.authentication.loginEndpoint
    $authority = $loginEndpoint + $tenantID + "/"
    Add-AzureRmEnvironment -Name 'Azure Stack' -ActiveDirectoryEndpoint $authority -ActiveDirectoryServiceEndpointResourceId $activeDirectoryServiceEndpointResourceId -ResourceManagerEndpoint  "https://api.$azureStackDomain/" -GalleryEndpoint $galleryEndpoint -GraphEndpoint $graphEndpoint |Out-Null 
    $environment = Get-AzureRmEnvironment 'Azure Stack'
    $profile = Add-AzureRmAccount -Environment $environment -Credential $azureStackCredentials
    $powershellClientId = "0a7bdc5c-7b57-40be-9939-d4c5fc7cd417"
    $adminToken = Get-AzureStackToken -WarningAction Ignore `
		-Authority $authority `
		-Resource $activeDirectoryServiceEndpointResourceId `
		-AadTenantId $tenantID `
		-ClientId $powershellClientId `
		-Credential $azureStackCredentials
   $armEndpoint = 'https://api.' + $azureStackDomain
   $adminSubscription = Get-AzureRMTenantSubscription -AdminUri $ArmEndPoint -Token $admintoken -WarningAction Ignore
   $subscription = $adminSubscription.SubscriptionId 
   $headers =  @{ Authorization = ("Bearer $adminToken") }
   $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.InfrastructureInsights.Admin/regionHealths/$region/Alerts?api-version=2016-05-01"
    $Alert=Invoke-RestMethod -Method GET -Uri $uri -ContentType 'application/json' -Headers $Headers
    $Alerts=$Alert.value |where-object {$_.properties.alertid -eq "$alertid"}
    $alertname=$alerts.name
   $Alerts.properties.state = "Closed"
    $AlertUpdateBody = $Alerts | ConvertTo-Json
    $URI= "${ArmEndpoint}/subscriptions/${subscription}/resourceGroups/system/providers/Microsoft.InfrastructureInsights.Admin/regionHealths/$region/Alerts/${alertname}?api-version=2016-05-01"
    $URI
    $Close=Invoke-RestMethod -Method PUT -Uri $uri -ContentType 'application/json' -Headers $Headers -Body $AlertUpdateBody
    $CloseRun=$Close.value
    $closeRun 
       }
