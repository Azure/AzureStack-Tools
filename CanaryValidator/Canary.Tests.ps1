[CmdletBinding(DefaultParameterSetName="default")]
param (    
    [parameter(HelpMessage="Tenant ID value")]
    [Parameter(ParameterSetName="default", Mandatory=$true)]
    [Parameter(ParameterSetName="tenant", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantID,
    [parameter(HelpMessage="Administrative ARM endpoint")]
    [Parameter(ParameterSetName="default", Mandatory=$true)]
    [Parameter(ParameterSetName="tenant", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AdminArmEndpoint,   
    [parameter(HelpMessage="Service Administrator account credential from the Azure Stack active directory")]
    [Parameter(ParameterSetName="default", Mandatory=$true)]
    [Parameter(ParameterSetName="tenant", Mandatory=$true)]    
    [ValidateNotNullOrEmpty()]
    [pscredential]$ServiceAdminCredentials,
    [parameter(HelpMessage="Tenant ARM endpoint")]
    [Parameter(ParameterSetName="default", Mandatory=$true)]
    [Parameter(ParameterSetName="tenant", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantArmEndpoint,    
    [parameter(HelpMessage="Tenant administrator account credentials from the Azure Stack active directory")] 
    [Parameter(ParameterSetName="default", Mandatory=$true)]
    [Parameter(ParameterSetName="tenant", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]    
    [pscredential]$TenantAdminCredentials,
    [parameter(HelpMessage="Local path where the windows 2016/2012R2 ISO image is stored")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateScript({Test-Path -Path $_})]
    [ValidateNotNullOrEmpty()]
    [string]$WindowsISOPath, 
    [parameter(HelpMessage="Local path where the windows 2016/2012R2 VHD file is stored")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateScript({Test-Path -Path $_})]
    [string]$WindowsVHDPath,
    [parameter(HelpMessage="Path for Linux VHD")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [string] $LinuxImagePath = "http://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-disk1.vhd.zip",
    [parameter(HelpMessage="Linux OS sku")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [string] $LinuxOSSku = "16.04-LTS",
    [parameter(HelpMessage="Fully qualified domain name of the azure stack environment. Ex: contoso.com")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentDomainFQDN,    
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string]$TenantAdminObjectId = "", 
    [parameter(HelpMessage="Name of the Azure Stack environment to be deployed")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentName = "AzureStackCanaryCloud",   
    [parameter(HelpMessage="Resource group under which all the utilities need to be placed")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CanaryUtilitiesRG = "cnur" + [Random]::new().Next(1,9999),
    [parameter(HelpMessage="Resource group under which the virtual machines need to be placed")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CanaryVMRG = "cnvr" + [Random]::new().Next(1,99),
    [parameter(HelpMessage="Location where all the resource need to deployed and placed")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceLocation = "local",
    [parameter(HelpMessage="Flag to indicate whether to continue Canary after an exception")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [bool] $ContinueOnFailure = $false,
    [parameter(HelpMessage="Number of iterations for which Canary needs to be running in a loop (used in longhaul mode)")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$NumberOfIterations = 1,
    [parameter(HelpMessage="Specifies whether Canary needs to clean up resources after each run (used in longhaul mode)")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$NoCleanup,
    [parameter(HelpMessage="Specifies whether Canary needs to clean up resources when a failure is encountered")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$NoCleanupOnFailure,        
    [parameter(HelpMessage="Specifies the path for log files")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CanaryLogPath = $env:TMP + "\CanaryLogs$((Get-Date).Ticks)",
	[parameter(HelpMessage="Specifies the file name for canary log file")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CanaryLogFileName = "Canary-Basic-$((Get-Date).Ticks).log",
    [parameter(HelpMessage="List of usecases to be excluded from execution")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]  
    [string[]]$ExclusionList = ("GetAzureStackInfraRoleInstance", "DeleteSubscriptionResourceGroup", "QueryImagesFromPIR", "DeployARMTemplate", "RetrieveResourceDeploymentTimes", "QueryTheVMsDeployed", "CheckVMCommunicationPreVMReboot", "TransmitMTUSizedPacketsBetweenTenantVMs", "AddDatadiskToVMWithPrivateIP", "ApplyDataDiskCheckCustomScriptExtensionToVMWithPrivateIP", "RestartVMWithPublicIP", "StopDeallocateVMWithPrivateIP", "StartVMWithPrivateIP", "CheckVMCommunicationPostVMReboot", "CheckExistenceOfScreenShotForVMWithPrivateIP", "DeleteVMWithPrivateIP"),
    [parameter(HelpMessage="Lists the available usecases in Canary")]
    [Parameter(ParameterSetName="listavl", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]  
    [switch]$ListAvailable     
)

Import-Module -Name $PSScriptRoot\Canary.Utilities.psm1 -Force -DisableNameChecking
if (-not $ListAvailable.IsPresent)
{
    #requires -Modules AzureRM.Profile, AzureRM.AzureStackAdmin
    #Requires -RunAsAdministrator

    Import-Module -Name $PSScriptRoot\..\Connect\AzureStack.Connect.psm1 -Force
    Import-Module -Name $PSScriptRoot\..\Infrastructure\AzureStack.Infra.psm1 -Force
    Import-Module -Name $PSScriptRoot\..\ComputeAdmin\AzureStack.ComputeAdmin.psm1 -Force
}
else
{
    $ErrorActionPreference = "SilentlyContinue"
}
$runCount = 1
$tmpLogname = $CanaryLogFileName
while ($runCount -le $NumberOfIterations)
{
    if ($NumberOfIterations -gt 1)
    {
        $CanaryUtilitiesRG      = $CanaryUtilitiesRG + $runCount
        $CanaryVMRG             = $CanaryVMRG + $runCount
    }
    $storageAccName         = $CanaryUtilitiesRG + "sa"
    $storageCtrName         = $CanaryUtilitiesRG + "sc"
    $keyvaultName           = $CanaryUtilitiesRG + "kv"
    $keyvaultCertName       = "ASCanaryVMCertificate"
    $kvSecretName           = $keyvaultName.ToLowerInvariant() + "secret"
    $VMAdminUserName        = "CanaryAdmin" 
    $VMAdminUserPass        = "CanaryAdmin@123"
    $canaryUtilPath         = Join-Path -Path $env:TEMP -ChildPath "CanaryUtilities$((Get-Date).Ticks)"
    $linuxImagePublisher    = "Canonical"
    $linuxImageOffer        = "UbuntuServer"
    $linuxImageVersion      = "1.0.0"
    [boolean]$linuxUpload   = $false
    if (Test-Path -Path $canaryUtilPath)
    {
        Remove-Item -Path $canaryUtilPath -Force -Recurse 
    }
    New-Item -Path $canaryUtilPath -ItemType Directory | Out-Null

    #
    # Start Canary 
    #  
    if($ListAvailable){Write-Host "List of scenarios in Canary:" -ForegroundColor Green; $listAvl = $true} else{$listAvl = $false}
    $CanaryLogFileName = [IO.Path]::GetFileNameWithoutExtension($tmpLogname) + "-$runCount" + [IO.Path]::GetExtension($tmpLogname)
    $CanaryLogFile = Join-Path -Path $CanaryLogPath -ChildPath $CanaryLogFileName
    Start-Scenario -Name 'Canary' -Type 'Basic' -LogFilename $CanaryLogFile -ContinueOnFailure $ContinueOnFailure -ListAvailable $listAvl -ExclusionList $ExclusionList

    $SvcAdminEnvironmentName = $EnvironmentName + "-SVCAdmin"
    $TntAdminEnvironmentName = $EnvironmentName + "-Tenant"

    if((-not $EnvironmentDomainFQDN) -and (-not $listAvl))
    {
        $endptres = Invoke-RestMethod "${AdminArmEndpoint}/metadata/endpoints?api-version=1.0" -ErrorAction Stop 
        $EnvironmentDomainFQDN = $endptres.portalEndpoint
        $EnvironmentDomainFQDN = $EnvironmentDomainFQDN.Replace($EnvironmentDomainFQDN.Split(".")[0], "").TrimEnd("/").TrimStart(".") 
    }

    Invoke-Usecase -Name 'CreateAdminAzureStackEnv' -Description "Create Azure Stack environment $SvcAdminEnvironmentName" -UsecaseBlock `
    {
        $asEndpoints = GetAzureStackEndpoints -EnvironmentDomainFQDN $EnvironmentDomainFQDN -ArmEndpoint $AdminArmEndpoint 
        Add-AzureRmEnvironment  -Name ($SvcAdminEnvironmentName) `
                                -ActiveDirectoryEndpoint ($asEndpoints.ActiveDirectoryEndpoint) `
                                -ActiveDirectoryServiceEndpointResourceId ($asEndpoints.ActiveDirectoryServiceEndpointResourceId) `
                                -ResourceManagerEndpoint ($asEndpoints.ResourceManagerEndpoint) `
                                -GalleryEndpoint ($asEndpoints.GalleryEndpoint) `
                                -GraphEndpoint ($asEndpoints.GraphEndpoint) `
                                -GraphAudience ($asEndpoints.GraphEndpoint) `
                                -StorageEndpointSuffix ($asEndpoints.StorageEndpointSuffix) `
                                -AzureKeyVaultDnsSuffix ($asEndpoints.AzureKeyVaultDnsSuffix) `
                                -EnableAdfsAuthentication:$asEndpoints.ActiveDirectoryEndpoint.TrimEnd("/").EndsWith("/adfs", [System.StringComparison]::OrdinalIgnoreCase) `
                                -ErrorAction Stop
    }

    Invoke-Usecase -Name 'LoginToAzureStackEnvAsSvcAdmin' -Description "Login to $SvcAdminEnvironmentName as service administrator" -UsecaseBlock `
    {     
        Add-AzureRmAccount -EnvironmentName $SvcAdminEnvironmentName -Credential $ServiceAdminCredentials -TenantId $TenantID -ErrorAction Stop
    }

    Invoke-Usecase -Name 'SelectDefaultProviderSubscription' -Description "Select the Default Provider Subscription" -UsecaseBlock `
    {
        $defaultSubscription = Get-AzureRmSubscription -SubscriptionName "Default Provider Subscription" -ErrorAction Stop
        if ($defaultSubscription)
        {
            $defaultSubscription | Select-AzureRmSubscription
        }
    } 
    
    if ($resLocation = (Get-AzsLocation -ErrorAction SilentlyContinue).Name) {if ($resLocation -ne $ResourceLocation) {$ResourceLocation = $resLocation}}

    Invoke-Usecase -Name 'ListFabricResourceProviderInfo' -Description "List FabricResourceProvider(FRP) information like storage shares, capacity, logical networks etc." -UsecaseBlock `
    {
        Invoke-Usecase -Name 'GetAzureStackInfraRole' -Description "List all infrastructure roles" -UsecaseBlock `
        {
            Get-AzsInfrastructureRole -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackInfraRoleInstance' -Description "List all infrastructure role instances" -UsecaseBlock `
        {
            Get-AzsInfrastructureRoleInstance -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackLogicalNetwork' -Description "List all logical networks" -UsecaseBlock `
        {
            Get-AzsLogicalNetwork -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackStorageCapacity' -Description "List storage capacity" -UsecaseBlock `
        {
            Get-AzSStorageSubsystem -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackInfrastructureShare' -Description "List all storage file shares" -UsecaseBlock `
        {
            Get-AzsInfrastructureShare -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackScaleUnit' -Description "List Azure Stack scale units in specified Region" -UsecaseBlock `
        {
            Get-AzsScaleUnit -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackScaleUnitNode' -Description "List nodes in scale unit" -RetryCount 2 -RetryDelayInSec 20 -UsecaseBlock `
        {
            Get-AzsScaleUnitNode -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackIPPool' -Description "List all IP pools" -UsecaseBlock `
        {
            Get-AzsIpPool -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackMacPool' -Description "List all MAC address pools " -UsecaseBlock `
        {
            Get-AzsMacPool -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackGatewayPool' -Description "List all gateway pools" -UsecaseBlock `
        {
            Get-AzsGatewayPool -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackSLBMux' -Description "List all SLB MUX instances" -UsecaseBlock `
        {
            Get-AzsSlbMux -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackGateway' -Description "List all gateway" -UsecaseBlock `
        {
            Get-AzsGateway -Location $ResourceLocation
        }            
    }
   
    Invoke-Usecase -Name 'ListHealthResourceProviderAlerts' -Description "List all HealthResourceProvider(HRP) alerts " -UsecaseBlock `
    {     
        Invoke-Usecase -Name 'GetAzureStackAlert' -Description "List all alerts" -UsecaseBlock `
        {
            Get-AzsAlert -Location $ResourceLocation
        }
    }

    Invoke-Usecase -Name 'ListUpdatesResourceProviderInfo' -Description "List URP information like summary of updates available, update to be applied, last update applied etc." -UsecaseBlock `
    {        
        Invoke-Usecase -Name 'GetAzureStackUpdateSummary' -Description "List summary of updates status" -UsecaseBlock `
        {
            Get-AzSUpdateLocation -Location $ResourceLocation
        }

        Invoke-Usecase -Name 'GetAzureStackUpdateToApply' -Description "List all updates that can be applied" -UsecaseBlock `
        {
            Get-AzsUpdate -Location $ResourceLocation
        }         
    }
    
    if ($WindowsISOPath)
    {
        Invoke-Usecase -Name 'UploadWindows2016ImageToPIR' -Description "Uploads a windows server 2016 image to the PIR" -UsecaseBlock `
        {
            if (-not (Get-AzureRmVMImage -Location $ResourceLocation -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Sku "2016-Datacenter-Core" -ErrorAction SilentlyContinue))
            {
                New-AzsServer2016VMImage -ISOPath $WindowsISOPath -Location $ResourceLocation -Version Core -CreateGalleryItem $false
            }
        }
    }

    if ((Get-Volume ((Get-Item -Path $ENV:TMP).PSDrive.Name) -ErrorAction SilentlyContinue).SizeRemaining/1GB -gt 35)
    {
        [boolean]$invalidUri = $false
        try {Invoke-WebRequest -Uri $LinuxImagePath -UseBasicParsing -DisableKeepAlive -Method Head -ErrorAction SilentlyContinue | Out-Null} 
        catch {$invalidUri = $true}
        if (-not $invalidUri)
        {
            Invoke-Usecase -Name 'UploadLinuxImageToPIR' -Description "Uploads Linux image to the PIR" -UsecaseBlock `
            {
                try 
                {
                    if (-not (Get-AzureRmVMImage -Location $ResourceLocation -PublisherName $linuxImagePublisher -Offer $linuxImageOffer -Sku $LinuxOSSku -ErrorAction SilentlyContinue))
                    {
                        $CanaryCustomImageFolder = Join-Path -Path $env:TMP -childPath "CanaryCustomImage$((Get-Date).Ticks)"
                        if (Test-Path -Path $CanaryCustomImageFolder)
                        {
                            Remove-Item -Path $CanaryCustomImageFolder -Force -Recurse 
                        }
                        New-Item -Path $CanaryCustomImageFolder -ItemType Directory
                        $CustomVHDPath = CopyImage -ImagePath $LinuxImagePath -OutputFolder $CanaryCustomImageFolder
                        Add-AzsVMImage -publisher $linuxImagePublisher -offer $linuxImageOffer -sku $LinuxOSSku -version $linuxImageVersion -osDiskLocalPath $CustomVHDPath -osType Linux -Location $ResourceLocation -CreateGalleryItem $false
                        Remove-Item $CanaryCustomImageFolder -Force -Recurse
                        Set-Variable -Name linuxUpload -Value $true -Scope 1
                    }    
                }
                catch
                {
                    Remove-Item -Path $CanaryCustomImageFolder -Force -Recurse
                    throw [System.Exception]"Failed to upload the linux image to PIR. `n$($_.Exception.Message)"            
                }
            }
        }
    }

    if (($TenantAdminCredentials) -or ($ListAvailable))
    {
        $subscriptionRGName                 = $CanaryUtilitiesRG + "subscrrg" + [Random]::new().Next(1,999)
        $tenantPlanName                     = $CanaryUtilitiesRG + "tenantplan" + [Random]::new().Next(1,999)        
        $tenantOfferName                    = $CanaryUtilitiesRG + "tenantoffer" + [Random]::new().Next(1,999)
        $tenantSubscriptionName             = $CanaryUtilitiesRG + "tenantsubscription" + [Random]::new().Next(1,999)            
        $canaryDefaultTenantSubscription    = $CanaryUtilitiesRG + "tenantdefaultsubscription" + [Random]::new().Next(1,999) 

        if ((-not $TenantArmEndpoint) -and (-not $ListAvailable.IsPresent))
        {
            throw [System.Exception] "Tenant ARM endpoint is required."
        }

        Invoke-Usecase -Name 'CreateTenantAzureStackEnv' -Description "Create Azure Stack environment $TntAdminEnvironmentName" -UsecaseBlock `
        {
            $asEndpoints = GetAzureStackEndpoints -EnvironmentDomainFQDN $EnvironmentDomainFQDN -ArmEndpoint $TenantArmEndpoint
            Add-AzureRmEnvironment  -Name ($TntAdminEnvironmentName) `
                                    -ActiveDirectoryEndpoint ($asEndpoints.ActiveDirectoryEndpoint) `
                                    -ActiveDirectoryServiceEndpointResourceId ($asEndpoints.ActiveDirectoryServiceEndpointResourceId) `
                                    -ResourceManagerEndpoint ($asEndpoints.ResourceManagerEndpoint) `
                                    -GalleryEndpoint ($asEndpoints.GalleryEndpoint) `
                                    -GraphEndpoint ($asEndpoints.GraphEndpoint) `
                                    -GraphAudience ($asEndpoints.GraphEndpoint) `
                                    -StorageEndpointSuffix ($asEndpoints.StorageEndpointSuffix) `
                                    -AzureKeyVaultDnsSuffix ($asEndpoints.AzureKeyVaultDnsSuffix) `
                                    -EnableAdfsAuthentication:$asEndpoints.ActiveDirectoryEndpoint.TrimEnd("/").EndsWith("/adfs", [System.StringComparison]::OrdinalIgnoreCase) `
                                    -ErrorAction Stop
        }

        Invoke-Usecase -Name 'CreateResourceGroupForTenantSubscription' -Description "Create a resource group $subscriptionRGName for the tenant subscription" -UsecaseBlock `
        {        
            if (Get-AzureRmResourceGroup -Name $subscriptionRGName -ErrorAction SilentlyContinue)
            {
                Remove-AzureRmResourceGroup -Name $subscriptionRGName -Force -ErrorAction Stop
            }
            New-AzureRmResourceGroup -Name $subscriptionRGName -Location $ResourceLocation -ErrorAction Stop 
        }

        Invoke-Usecase -Name 'CreateTenantPlan' -Description "Create a tenant plan" -UsecaseBlock `
        {      
            $asToken = NewAzureStackToken -AADTenantId $TenantID -EnvironmentDomainFQDN $EnvironmentDomainFQDN -Credentials $ServiceAdminCredentials -ArmEndPoint $AdminArmEndpoint
            $defaultSubscription = Get-AzureRmSubscription -SubscriptionName "Default Provider Subscription" -ErrorAction Stop            
            $asCanaryQuotas = NewAzureStackDefaultQuotas -ResourceLocation $ResourceLocation -SubscriptionId $defaultSubscription.SubscriptionId -AADTenantID $TenantID -EnvironmentDomainFQDN $EnvironmentDomainFQDN -Credentials $ServiceAdminCredentials -ArmEndPoint $AdminArmEndPoint
            New-AzureRMPlan -Name $tenantPlanName -DisplayName $tenantPlanName -ArmLocation $ResourceLocation -ResourceGroup $subscriptionRGName -QuotaIds $asCanaryQuotas -ErrorAction Stop
        }

        Invoke-Usecase -Name 'CreateTenantOffer' -Description "Create a tenant offer" -UsecaseBlock `
        {       
            if ($ascanaryPlan = Get-AzureRMPlan -Managed -ResourceGroup $subscriptionRGName | Where-Object Name -eq $tenantPlanName )
            {
                New-AzureRMOffer -Name $tenantOfferName -DisplayName $tenantOfferName -State Public -BasePlanIds @($ascanaryPlan.Id) -ArmLocation $ResourceLocation -ResourceGroup $subscriptionRGName -ErrorAction Stop
            }
        }

        Invoke-Usecase -Name 'CreateTenantDefaultManagedSubscription' -Description "Create a default managed subscription for the tenant" -UsecaseBlock `
        {       
            if (-not (Get-AzureRMManagedSubscription | Where-Object DisplayName -eq $canaryDefaultTenantSubscription))
            {
                $asCanaryOffer = Get-AzureRMOffer -Name $tenantOfferName -Managed -ResourceGroup $subscriptionRGName -ErrorAction Stop
                New-AzureRmManagedSubscription -Owner $TenantAdminCredentials.UserName -OfferId $asCanaryOffer.Id -DisplayName $canaryDefaultTenantSubscription -ErrorAction Stop  
            }   
            return $true
        }

        Invoke-Usecase -Name 'LoginToAzureStackEnvAsTenantAdmin' -Description "Login to $TntAdminEnvironmentName as tenant administrator" -UsecaseBlock `
        {     
            Add-AzureRmAccount -EnvironmentName $TntAdminEnvironmentName -Credential $TenantAdminCredentials -TenantId $TenantID -ErrorAction Stop
        }

        Invoke-Usecase -Name 'CreateTenantSubscription' -Description "Create a subcsription for the tenant and select it as the current subscription" -UsecaseBlock `
        {
            Set-AzureRmContext -SubscriptionName $canaryDefaultTenantSubscription
            $asCanaryOffer = Get-AzureRmOffer -Provider "Default" -ErrorAction Stop | Where-Object Name -eq $tenantOfferName
            $asTenantSubscription = New-AzureRmTenantSubscription -OfferId $asCanaryOffer.Id -DisplayName $tenantSubscriptionName -ErrorAction Stop
            if ($asTenantSubscription)
            {
                Get-AzureRmSubscription -SubscriptionName $asTenantSubscription.DisplayName | Select-AzureRmSubscription -ErrorAction Stop
            }          
        } 

        Invoke-Usecase -Name 'RoleAssignmentAndCustomRoleDefinition' -Description "Assign a reader role and create a custom role definition" -UsecaseBlock `
        {
            if (-not $ListAvailable.IsPresent)
            {         
                $servicePrincipal = (Get-AzureRmADServicePrincipal)[0]             
                $customRoleName = "CustomCanaryRole-" + [Random]::new().Next(1,99)            
            }
        
            Invoke-Usecase -Name 'ListAssignedRoles' -Description "List assigned roles to Service Principle - $($servicePrincipal.DisplayName)" -UsecaseBlock `
            {
	            Get-AzureRmRoleAssignment -ObjectId $servicePrincipal.Id -ErrorAction Stop
            }

            Invoke-Usecase -Name 'ListExistingRoleDefinitions' -Description "List existing Role Definitions" -UsecaseBlock `
            {
	            $availableRoles = Get-AzureRmRoleDefinition -ErrorAction Stop                
                if (-not $availableRoles)
                {
                    throw [System.Exception] "No roles are available."
                }   
                else
                {
                    $availableRoles
                    $availableRolesNames = $availableRoles.Name
                    $mustHaveRoles = @("Owner", "Reader", "Contributor")
                    $match = Compare-Object $mustHaveRoles $availableRolesNames
                    if ($match -and ($match | Where-Object {$_.SideIndicator -eq "<="}))
                    {
                        $notAvailableRoles = ($match | Where-Object {$_.SideIndicator -eq "<="}).InputObject
                        throw [System.Exception] "Some must have Role Definitions are not available. Number of missing Role Definitions - $($notAvailableRoles.Count). Missing Role Definitions - $notAvailableRoles"
                    }
                }                
            }

            Invoke-Usecase -Name 'GetProviderOperations' -Description "Get provider operations for all resource providers" -UsecaseBlock `
            {
	            $resourceProviders = Get-AzureRmResourceProvider -ListAvailable
                # Some of the RPs have not implemented their operations API yet. So update this exclusion list whenever any RP implements its operations API
                $rpOperationsExclusionList = @("Microsoft.Commerce", "Microsoft.Gallery", "Microsoft.Insights")
                $totalOperationsPerRP = @()    
                foreach($rp in $resourceProviders)
                {
                    $operations = Get-AzureRMProviderOperation "$($rp.ProviderNamespace)/*" -ErrorAction Stop
                    $operationObj = New-Object -TypeName System.Object            
                    $operationObj | Add-Member -Type NoteProperty -Name ResourceProvider -Value $rp.ProviderNamespace 
                    if (-not $operations)
                    {
                        $operationObj | Add-Member -Type NoteProperty -Name TotalProviderOperations -Value 0 
                    }
                    else
                    {
                        $operationObj | Add-Member -Type NoteProperty -Name TotalProviderOperations -Value $operations.Count 
                    }
                    $totalOperationsPerRP += $operationObj                    
                }
                $totalOperationsPerRP
                if ($totalOperationsPerRP -and ($totalOperationsPerRP | Where-Object {$_.TotalProviderOperations -eq 0}))
                {
                    $rpWithNoOperations = ($totalOperationsPerRP | Where-Object {$_.TotalProviderOperations -eq 0}).ResourceProvider
                    $match = Compare-Object $rpOperationsExclusionList $rpWithNoOperations
                    if ($match -and ($match | Where-Object {$_.SideIndicator -eq "=>"}))
                    {
                        $missed = ($match | Where-Object {$_.SideIndicator -eq "=>"}).InputObject
                        throw [System.Exception] "Some Resource Providers have zero Provider Operations. Number of Resource Providers with zero Provider Operations - $($missed.Count). Resource Providers with zero Provider Operations - $missed"
                    }
                }
            }

            Invoke-Usecase -Name 'AssignReaderRole' -Description "Assign Reader role to Service Principle - $($servicePrincipal.DisplayName)" -UsecaseBlock `
            {
                $readerRole = Get-AzureRmRoleDefinition -Name Reader 
                $subscriptionID = (Get-AzureRmSubscription -SubscriptionName $tenantSubscriptionName).SubscriptionId                
                $allAssignedRoles = Get-AzureRmRoleAssignment -ObjectId $servicePrincipal.Id -ErrorAction Stop
                if ($subscriptionID -and $readerRole -and (-not $allAssignedRoles -or ($allAssignedRoles -and -not ($allAssignedRoles | Where-Object {$_.RoleDefinitionName -eq $readerRole.Name}))))
                {
	                New-AzureRmRoleAssignment -Scope "/Subscriptions/$subscriptionID" -RoleDefinitionName $readerRole.Name -ObjectId $servicePrincipal.Id -ErrorAction Stop
                }                
            }

            Invoke-Usecase -Name 'VerifyReaderRoleAssignment' -Description "Verify if the Service Principle has got Reader role assigned successfully" -UsecaseBlock `
            {
                $readerRole = Get-AzureRmRoleDefinition -Name Reader 
                $subscriptionID = (Get-AzureRmSubscription -SubscriptionName $tenantSubscriptionName).SubscriptionId
	            if ($subscriptionID -and $readerRole -and (-not (Get-AzureRmRoleAssignment -RoleDefinitionName $readerRole.Name -Scope "/Subscriptions/$subscriptionID" -ErrorAction Stop)))
                {
                    throw [System.Exception] "Unable to assign role ($readerRole.Name) to Service Principle ($servicePrincipal.Id) for subscription $tenantSubscriptionName"
                }                    
            }

            Invoke-Usecase -Name 'RemoveReaderRoleAssignment' -Description "Remove Reader role assignment from Service Principle - $($servicePrincipal.DisplayName)" -UsecaseBlock `
            {
                $parameters = @{}
                if ((Get-Module AzureRM -ListAvailable).Version -le "1.2.10") {$parameters = @{"Force" = $True}}
                $readerRole = Get-AzureRmRoleDefinition -Name Reader 
                $subscriptionID = (Get-AzureRmSubscription -SubscriptionName $tenantSubscriptionName).SubscriptionId
                if ($subscriptionID -and $readerRole -and (Get-AzureRmRoleAssignment -RoleDefinitionName $readerRole.Name -Scope "/Subscriptions/$subscriptionID" -ErrorAction Stop))
                {                
	                Remove-AzureRmRoleAssignment -Scope "/Subscriptions/$subscriptionID" -RoleDefinitionName $readerRole.Name -ObjectId $servicePrincipal.Id -ErrorAction Stop @parameters
                }
            }           
            
            Invoke-Usecase -Name 'CustomRoleDefinition' -Description "Create a custom Role Definition - $customRoleName" -UsecaseBlock `
            {
                $subscriptionID = (Get-AzureRmSubscription -SubscriptionName $tenantSubscriptionName).SubscriptionId                
                if (Get-AzureRmRoleDefinition -Name $customRoleName)
                {
                    Remove-AzureRmRoleDefinition -Name $customRoleName -Scope "/Subscriptions/$subscriptionID" -Force -ErrorAction Stop
                }                               
	            $role = Get-AzureRmRoleDefinition -Name Reader                
                $role.Id = $null                
                $role.Name = $customRoleName
                $role.Description = "Custom role definition for Canary"
                $role.Actions.Clear()
                $role.Actions.Add("Microsoft.Authorization/*/Read")
                $role.AssignableScopes.Clear()
                $role.AssignableScopes.Add("/Subscriptions/$subscriptionID")
                New-AzureRmRoleDefinition -Role $role -ErrorAction Stop
                if (-not (Get-AzureRmRoleDefinition -Name $customRoleName -Scope "/Subscriptions/$subscriptionID" -ErrorAction Stop))
                {
                    throw [System.Exception] "Unable to create custom role definition ($customRoleName) for subscription $tenantSubscriptionName"
                }                               
            }

            Invoke-Usecase -Name 'ListRoleDefinitionsAfterCustomRoleCreation' -Description "List existing Role Definitions" -UsecaseBlock `
            {
	            $availableRoles = Get-AzureRmRoleDefinition -ErrorAction Stop               
                if (-not $availableRoles)
                {
                    throw [System.Exception] "No roles are available."
                }   
                else
                {
                    $availableRoles
                    $availableRolesNames = $availableRoles.Name
                    $mustHaveRoles = @("Owner", "Reader", "Contributor")
                    $match = Compare-Object $mustHaveRoles $availableRolesNames
                    if ($match -and ($match | Where-Object {$_.SideIndicator -eq "<="}))
                    {
                        $notAvailableRoles = ($match | Where-Object {$_.SideIndicator -eq "<="}).InputObject
                        throw [System.Exception] "Some must have Role Definitions are not available. Number of missing Role Definitions - $($notAvailableRoles.Count). Missing Role Definitions - $notAvailableRoles"
                    }
                }                
            }

            Invoke-Usecase -Name 'RemoveCustomRoleDefinition' -Description "Remove custom role definition - $customRoleName" -UsecaseBlock `
            {
                $subscriptionID = (Get-AzureRmSubscription -SubscriptionName $tenantSubscriptionName).SubscriptionId
                if(Get-AzureRmRoleDefinition -Name $customRoleName -Scope "/Subscriptions/$subscriptionID" -ErrorAction Stop)
                {
	                Remove-AzureRmRoleDefinition -Name $customRoleName -Scope "/Subscriptions/$subscriptionID" -Force -ErrorAction Stop                
                }
                else
                {
                    throw [System.Exception] "Custom role definition ($customRoleName) for subscription $tenantSubscriptionName is not available"
                }
            }
        }

        Invoke-Usecase -Name 'RegisterResourceProviders' -Description "Register resource providers" -UsecaseBlock `
        {
            $parameters = @{}
            if ((Get-Module AzureRM -ListAvailable).Version -le "1.2.10") {$parameters = @{"Force" = $True}}
            ("Microsoft.Storage", "Microsoft.Compute", "Microsoft.Network", "Microsoft.KeyVault") | ForEach-Object {Get-AzureRmResourceProvider -ProviderNamespace $_} | Register-AzureRmResourceProvider @parameters
            $sleepTime = 0        
            while($true)
            {
                $sleepTime += 10
                Start-Sleep -Seconds  10
                $requiredRPs = Get-AzureRmResourceProvider -ListAvailable | Where-Object {$_.ProviderNamespace -in ("Microsoft.Storage", "Microsoft.Compute", "Microsoft.Network", "Microsoft.KeyVault")}
                $notRegistered = $requiredRPs | Where-Object {$_.RegistrationState -ne "Registered"}
                $registered = $requiredRPs | Where-Object {$_.RegistrationState -eq "Registered"}
                if (($sleepTime -ge 120) -and $notRegistered)
                {
                    Get-AzureRmResourceProvider | Format-Table
                    throw [System.Exception] "Resource providers did not get registered in time."
                }
                elseif ($registered.Count -eq $requiredRPs.Count)
                {
                    break
                }
            }
            Get-AzureRmResourceProvider | Format-Table             
        }         
    }

    Invoke-Usecase -Name 'CreateResourceGroupForUtilities' -Description "Create a resource group $CanaryUtilitiesRG for the placing the utility files" -UsecaseBlock `
    {        
        if (Get-AzureRmResourceGroup -Name $CanaryUtilitiesRG -ErrorAction SilentlyContinue)
        {
            Remove-AzureRmResourceGroup -Name $CanaryUtilitiesRG -Force -ErrorAction Stop
        }
        New-AzureRmResourceGroup -Name $CanaryUtilitiesRG -Location $ResourceLocation -ErrorAction Stop 
    }

    Invoke-Usecase -Name 'CreateStorageAccountForUtilities' -Description "Create a storage account for the placing the utility files" -UsecaseBlock `
    {      
        New-AzureRmStorageAccount -ResourceGroupName $CanaryUtilitiesRG -Name $storageAccName -Type Standard_LRS -Location $ResourceLocation -ErrorAction Stop
    }

    Invoke-Usecase -Name 'CreateStorageContainerForUtilities' -Description "Create a storage container for the placing the utility files" -UsecaseBlock `
    {        
        $asStorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $CanaryUtilitiesRG -Name $storageAccName -ErrorAction Stop
        if ($asStorageAccountKey)
        {
            $storageAccountKey = $asStorageAccountKey.Key1
        }
        $asStorageContext = New-AzureStorageContext -StorageAccountName $storageAccName -StorageAccountKey $storageAccountKey -ErrorAction Stop
        if ($asStorageContext)
        {
            New-AzureStorageContainer -Name $storageCtrName -Permission Container -Context $asStorageContext -ErrorAction Stop   
        }
    }

    Invoke-Usecase -Name 'CreateDSCScriptResourceUtility' -Description "Create a DSC script resource that checks for internet connection" -UsecaseBlock `
    {      
        $dscScriptPath = Join-Path -Path $canaryUtilPath -ChildPath "DSCScriptResource"
        $dscScriptName = "ASCheckNetworkConnectivityUtil.ps1"
        NewAzureStackDSCScriptResource -DSCScriptResourceName $dscScriptName -DestinationPath $dscScriptPath
    }

    Invoke-Usecase -Name 'CreateCustomScriptResourceUtility' -Description "Create a custom script resource that checks for the presence of data disks" -UsecaseBlock `
    {      
        $customScriptPath = $canaryUtilPath
        $customScriptName = "ASCheckDataDiskUtil.ps1"
        NewAzureStackCustomScriptResource -CustomScriptResourceName $customScriptName -DestinationPath $customScriptPath
    }

    Invoke-Usecase -Name 'CreateDataDiskForVM' -Description "Create a data disk to be attached to the VMs" -UsecaseBlock `
    {      
        $vhdPath = Join-Path -Path $canaryUtilPath -Childpath "VMDataDisk.VHD"
        NewAzureStackDataVHD -FilePath $vhdPath -VHDSizeInGB 1
    }
        
    Invoke-Usecase -Name 'UploadUtilitiesToBlobStorage' -Description "Upload the canary utilities to the blob storage" -UsecaseBlock `
    {    
        try
        {  
            $asStorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $CanaryUtilitiesRG -Name $storageAccName -ErrorAction Stop
            if ($asStorageAccountKey)
            {
                $storageAccountKey = $asStorageAccountKey.Key1
            }
            $asStorageContext = New-AzureStorageContext -StorageAccountName $storageAccName -StorageAccountKey $storageAccountKey -ErrorAction Stop
            if ($asStorageContext)
            {
                $files = Get-ChildItem -Path $canaryUtilPath -File
                foreach ($file in $files)
                {
                    if ($file.Extension -match "VHD")
                    {
                        Set-AzureStorageBlobContent -Container $storageCtrName -File $file.FullName -BlobType Page -Context $asStorageContext -Force -ErrorAction Stop     
                    }
                    else 
                    {
                        Set-AzureStorageBlobContent -Container $storageCtrName -File $file.FullName -Context $asStorageContext -Force -ErrorAction Stop             
                    }
                }
            }
        }
        finally
        {
            if (Test-Path -Path $canaryUtilPath)
            {
                Remove-Item -Path $canaryUtilPath -Recurse -Force
            }
        }
    }

    Invoke-Usecase -Name 'CreateKeyVaultStoreForCertSecret' -Description "Create a key vault store to put the certificate secret" -UsecaseBlock `
    {      
        if ($certExists = Get-ChildItem -Path "cert:\LocalMachine\My" | Where-Object Subject -Match $keyvaultCertName)
        {
            $certExists | Remove-Item -Force
        }
        New-SelfSignedCertificate -DnsName $keyvaultCertName -CertStoreLocation "cert:\LocalMachine\My" -ErrorAction Stop | Out-Null
        Add-Type -AssemblyName System.Web
        $certPasswordString = [System.Web.Security.Membership]::GeneratePassword(12,2)
        $certPassword = ConvertTo-SecureString -String $certPasswordString -AsPlainText -Force
        $kvCertificateName = $keyvaultCertName + ".pfx"
        $kvCertificatePath = "$env:TEMP\$kvCertificateName" 
        Get-ChildItem -Path "cert:\localMachine\my" | Where-Object Subject -Match $keyvaultCertName | Export-PfxCertificate -FilePath $kvCertificatePath -Password $certPassword | Out-Null
        $fileContentBytes     = get-content $kvCertificatePath -Encoding Byte
        $fileContentEncoded   = [System.Convert]::ToBase64String($fileContentBytes)
        $jsonObject = @"
        {
        "data": "$filecontentencoded",
        "dataType" :"pfx",
        "password": "$certPasswordString"
        }
"@ 
        $jsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
        $jsonEncoded     = [System.Convert]::ToBase64String($jsonObjectBytes)
        New-AzureRmKeyVault -VaultName $keyvaultName -ResourceGroupName $CanaryUtilitiesRG -Location $ResourceLocation -sku standard -EnabledForDeployment -EnabledForTemplateDeployment -ErrorAction Stop | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($TenantAdminObjectId)) 
        {
            Set-AzureRmKeyVaultAccessPolicy -VaultName $keyvaultName -ResourceGroupName $CanaryUtilitiesRG -ObjectId $TenantAdminObjectId -BypassObjectIdValidation -PermissionsToKeys all -PermissionsToSecrets all  
        }
        $kvSecret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText -Force
        Set-AzureKeyVaultSecret -VaultName $keyvaultName -Name $kvSecretName -SecretValue $kvSecret -ErrorAction Stop
    }

    Invoke-Usecase -Name 'CreateResourceGroupForVMs' -Description "Create a resource group $CanaryVMRG for the placing the VMs and corresponding resources" -UsecaseBlock `
    {        
        if (Get-AzureRmResourceGroup -Name $CanaryVMRG -ErrorAction SilentlyContinue)
        {
            Remove-AzureRmResourceGroup -Name $CanaryVMRG -Force -ErrorAction Stop
        }
        New-AzureRmResourceGroup -Name $CanaryVMRG -Location $ResourceLocation -ErrorAction Stop 
    }

    $pirQueryRes = Invoke-Usecase -Name 'QueryImagesFromPIR' -Description "Queries the images in Platform Image Repository to retrieve the OS Version to deploy on the VMs" -UsecaseBlock `
    {
        $osVersion = ""
        [boolean]$linuxImgExists = $false
        $sw = [system.diagnostics.stopwatch]::startNew()
        while (([string]::IsNullOrEmpty($osVersion)) -and ($sw.ElapsedMilliseconds -lt 300000))
        {
            # Returns all the images that are available in the PIR
            $pirImages = Get-AzureRmVMImagePublisher -Location $ResourceLocation | Get-AzureRmVMImageOffer | Get-AzureRmVMImageSku | Get-AzureRMVMImage | Get-AzureRmVMImage

            foreach($image in $pirImages)
            {
                # Canary specific check to see if the required Ubuntu image was successfully uploaded and available in PIR
                if ($image.PublisherName.Equals("Canonical") -and $image.Offer.Equals("UbuntuServer") -and $image.Skus.Equals($LinuxOSSku))
                {
                    $linuxImgExists = $true
                }

                if ($image.PublisherName.Equals("MicrosoftWindowsServer") -and $image.Offer.Equals("WindowsServer") -and $image.Skus.Equals("2016-Datacenter-Core"))
                {
                    $osVersion = "2016-Datacenter-Core"
                }
                elseif ($image.PublisherName.Equals("MicrosoftWindowsServer") -and $image.Offer.Equals("WindowsServer") -and $image.Skus.Equals("2016-Datacenter"))
                {
                    $osVersion = "2016-Datacenter"
                }
                elseif ($image.PublisherName.Equals("MicrosoftWindowsServer") -and $image.Offer.Equals("WindowsServer") -and $image.Skus.Equals("2012-R2-Datacenter"))
                {
                    $osVersion = "2012-R2-Datacenter"
                }
            }
            Start-Sleep -Seconds 20  
        } 
        $sw.Stop()
        if (($linuxUpload) -and (-not $linuxImgExists))
        {
            throw [System.Exception] "Unable to find Ubuntu image (Ubuntu $LinuxOSSku) in PIR or failed to retrieve the image from PIR"
        }
        if ([string]::IsNullOrEmpty($osVersion))
        {
            throw [System.Exception] "Unable to find windows image in PIR or failed to retrieve the image from PIR"
        }
        $osVersion, $linuxImgExists
    }
    #[string]$osVersion = $pirQueryRes[2]
    #[boolean]$linuxImgExists = $pirQueryRes[3]

    Invoke-Usecase -Name 'DeployARMTemplate' -Description "Deploy ARM template to setup the virtual machines" -UsecaseBlock `
    {        
        $kvSecretId = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $kvSecretName -IncludeVersions -ErrorAction Stop).Id  
        $templateDeploymentName = "CanaryVMDeployment"
        $parameters = @{"VMAdminUserName"           = $VMAdminUserName;
                        "VMAdminUserPassword"       = $VMAdminUserPass;
                        "ASCanaryUtilRG"            = $CanaryUtilitiesRG;
                        "ASCanaryUtilSA"            = $storageAccName;
                        "ASCanaryUtilSC"            = $storageCtrName;
                        "vaultName"                 = $keyvaultName;
                        "windowsOSVersion"          = $osVersion;
                        "secretUrlWithVersion"      = $kvSecretId;
                        "LinuxImagePublisher"       = $linuxImagePublisher;
                        "LinuxImageOffer"           = $linuxImageOffer;
                        "LinuxImageSku"             = $LinuxOSSku;
                        "storageAccountEndPoint"    = "https://$EnvironmentDomainFQDN/"}   
        if (-not $linuxImgExists)
        {
            $templateError = Test-AzureRmResourceGroupDeployment -ResourceGroupName $CanaryVMRG -TemplateFile $PSScriptRoot\azuredeploy.json -TemplateParameterObject $parameters
        }
        elseif ($linuxImgExists) 
        {
            $templateError = Test-AzureRmResourceGroupDeployment -ResourceGroupName $CanaryVMRG -TemplateFile $PSScriptRoot\azuredeploy.nolinux.json -TemplateParameterObject $parameters
        }
        
        if ((-not $templateError) -and ($linuxImgExists))
        {
            New-AzureRmResourceGroupDeployment -Name $templateDeploymentName -ResourceGroupName $CanaryVMRG -TemplateFile $PSScriptRoot\azuredeploy.json -TemplateParameterObject $parameters -Verbose -ErrorAction Stop
        }
        elseif (-not $templateError) {
            New-AzureRmResourceGroupDeployment -Name $templateDeploymentName -ResourceGroupName $CanaryVMRG -TemplateFile $PSScriptRoot\azuredeploy.nolinux.json -TemplateParameterObject $parameters -Verbose -ErrorAction Stop    
        }
        else 
        {
            throw [System.Exception] "Template validation failed. `n$($templateError.Message)"
        }
    }

    Invoke-Usecase -Name 'RetrieveResourceDeploymentTimes' -Description "Retrieves the resources deployment times from the ARM template deployment" -UsecaseBlock `
    {
        $templateDeploymentName = "CanaryVMDeployment"
        (Get-AzureRmResourceGroupDeploymentOperation -Deploymentname $templateDeploymentName -ResourceGroupName $CanaryVMRG).Properties | Select-Object @{Name="ResourceName";Expression={$_.TargetResource.ResourceName}},Duration,ProvisioningState,@{Name="ResourceType";Expression={$_.TargetResource.ResourceType}},ProvisioningOperation,StatusCode | Format-Table -AutoSize
    }

    $canaryWindowsVMList = @()
    $canaryWindowsVMList = Invoke-Usecase -Name 'QueryTheVMsDeployed' -Description "Queries for the VMs that were deployed using the ARM template" -UsecaseBlock `
    {
        $canaryWindowsVMList = @()        
        $vmList = Get-AzureRmVm -ResourceGroupName $CanaryVMRG -ErrorAction Stop
        $vmList = $vmList | Where-Object {$_.OSProfile.WindowsConfiguration}
        foreach ($vm in $vmList)
        {
            $vmObject = New-Object -TypeName System.Object
            $vmIPConfig = @()
            $privateIP  = @()
            $publicIP   = @()
            $vmObject | Add-Member -Type NoteProperty -Name VMName -Value $vm.Name 
            foreach ($nic in $vm.NetworkInterfaceIds)
            {
                $vmIPConfig += (Get-AzureRmNetworkInterface -ResourceGroupName $CanaryVMRG | Where-Object Id -match $nic).IpConfigurations
            } 
            foreach ($ipConfig in $vmIPConfig)
            {
                if ($pvtIP = $ipConfig.PrivateIpAddress)
                {
                    $privateIP += $pvtIP
                }
                if ($pubIP = $ipConfig.PublicIPAddress)
                {
                    if ($pubIPId = $pubIP.Id)
                    {
                        $publicIP += (Get-AzureRmPublicIpAddress -ResourceGroupName $CanaryVMRG | Where-Object Id -eq $pubIPId).IpAddress 
                    }
                }
            }
            $vmObject | Add-Member -Type NoteProperty -Name VMPrivateIP -Value $privateIP -Force
            $vmObject | Add-Member -Type NoteProperty -Name VMPublicIP -Value $publicIP -Force
            $canaryWindowsVMList += $vmObject 
        }
        $canaryWindowsVMList
    }
    if ($canaryWindowsVMList)
    {   
        $canaryWindowsVMList | Format-Table -AutoSize    
        foreach($vm in $canaryWindowsVMList)
        {
            if ($vm.VMPublicIP -and $vm.VMName.EndsWith("VM1", 'CurrentCultureIgnoreCase'))
            {
                $publicVMName = $vm.VMName
                $publicVMIP = $vm.VMPublicIP[0]
            }
            if ((-not ($vm.VMPublicIP)) -and ($vm.VMPrivateIP) -and ($vm.VMName.EndsWith("VM2", 'CurrentCultureIgnoreCase')))
            {
                $privateVMName = $vm.VMName
                $privateVMIP = $vm.VMPrivateIP[0]
            }
        }        
    }

    Invoke-Usecase -Name 'CheckVMCommunicationPreVMReboot' -Description "Check if the VMs deployed can talk to each other before they are rebooted" -UsecaseBlock `
    {
        $vmUser = ".\$VMAdminUserName"
        $vmCreds = New-Object System.Management.Automation.PSCredential $vmUser, (ConvertTo-SecureString $VMAdminUserPass -AsPlainText -Force)
        $vmCommsScriptBlock = "Get-Childitem -Path `"cert:\LocalMachine\My`" | Where-Object Subject -Match $keyvaultCertName"
        if (($pubVMObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $publicVMName -ErrorAction Stop) -and ($pvtVMObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop))
        {
            Set-item wsman:\localhost\Client\TrustedHosts -Value $publicVMIP -Force -Confirm:$false
            $sw = [system.diagnostics.stopwatch]::startNew()
            while (-not($publicVMSession = New-PSSession -ComputerName $publicVMIP -Credential $vmCreds -ErrorAction SilentlyContinue)){if (($sw.ElapsedMilliseconds -gt 240000) -and (-not($publicVMSession))){$sw.Stop(); throw [System.Exception]"Unable to establish a remote session to the tenant VM using public IP: $publicVMIP"}; Start-Sleep -Seconds 15}
            if ($publicVMSession)
            {
                Invoke-Command -Session $publicVMSession -Script{param ($privateIP) Set-item wsman:\localhost\Client\TrustedHosts -Value $privateIP -Force -Confirm:$false} -ArgumentList $privateVMIP | Out-Null
                $privateVMResponseFromRemoteSession = Invoke-Command -Session $publicVMSession -Script{param ($privateIP, $vmCreds, $scriptToRun) $sw = [system.diagnostics.stopwatch]::startNew(); while (-not($privateSess = New-PSSession -ComputerName $privateIP -Credential $vmCreds -ErrorAction SilentlyContinue)){if (($sw.ElapsedMilliseconds -gt 240000) -and (-not($privateSess))){$sw.Stop(); throw [System.Exception]"Unable to establish a remote session to the tenant VM using private IP: $privateIP"}; Start-Sleep -Seconds 15}; Invoke-Command -Session $privateSess -Script{param($script) Invoke-Expression $script} -ArgumentList $scriptToRun} -ArgumentList $privateVMIP, $vmCreds, $vmCommsScriptBlock -ErrorVariable remoteExecError 2>$null
                $publicVMSession | Remove-PSSession -Confirm:$false
                if ($remoteExecError)
                {
                    throw [System.Exception]"$remoteExecError"
                }
                if ($privateVMResponseFromRemoteSession)
                {
                    $privateVMResponseFromRemoteSession
                }
                else 
                {
                    throw [System.Exception]"The expected certificate from KV was not found on the tenant VM with private IP: $privateVMIP"
                }
            }    
        }
    }

    Invoke-Usecase -Name 'TransmitMTUSizedPacketsBetweenTenantVMs' -Description "Check if the tenant VMs can transmit MTU sized packets between themselves" -UsecaseBlock `
    {
        $vmUser = ".\$VMAdminUserName"
        $vmCreds = New-Object System.Management.Automation.PSCredential $vmUser, (ConvertTo-SecureString $VMAdminUserPass -AsPlainText -Force)
        if (($pubVMObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $publicVMName -ErrorAction Stop) -and ($pvtVMObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop))
        {
            Set-item wsman:\localhost\Client\TrustedHosts -Value $publicVMIP -Force -Confirm:$false
            $sw = [system.diagnostics.stopwatch]::startNew()
            while (-not($publicVMSession = New-PSSession -ComputerName $publicVMIP -Credential $vmCreds -ErrorAction SilentlyContinue)){if (($sw.ElapsedMilliseconds -gt 240000) -and (-not($publicVMSession))){$sw.Stop(); throw [System.Exception]"Unable to establish a remote session to the tenant VM using public IP: $publicVMIP"}; Start-Sleep -Seconds 15}
            if ($publicVMSession)
            {
                $remoteExecError = $null
                Invoke-Command -Session $publicVMSession -Script{param ($privateIP) Set-item wsman:\localhost\Client\TrustedHosts -Value $privateIP -Force -Confirm:$false} -ArgumentList $privateVMIP | Out-Null
                Invoke-Command -Session $publicVMSession -Script{Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False} | Out-Null
                $publicVMHost = Invoke-Command -Session $publicVMSession -Script{(Get-ItemProperty "HKLM:\Software\Microsoft\Virtual Machine\Guest\Parameters" ).PhysicalHostName}
                $privateVMHost = Invoke-Command -Session $publicVMSession -Script{param ($privateIP, $vmCreds) $sw = [system.diagnostics.stopwatch]::startNew(); while (-not($privateSess = New-PSSession -ComputerName $privateIP -Credential $vmCreds -ErrorAction SilentlyContinue)){if (($sw.ElapsedMilliseconds -gt 240000) -and (-not($privateSess))){$sw.Stop(); throw [System.Exception]"Unable to establish a remote session to the tenant VM using private IP: $privateIP"}; Start-Sleep -Seconds 15}; Invoke-Command -Session $privateSess -Script{Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False | Out-Null; (Get-ItemProperty "HKLM:\Software\Microsoft\Virtual Machine\Guest\Parameters" ).PhysicalHostName} } -ArgumentList $privateVMIP, $vmCreds -ErrorVariable remoteExecError 2>$null
                Invoke-Command -Session $publicVMSession -Script{param ($privateIP, $vmCreds) $sw = [system.diagnostics.stopwatch]::startNew(); while (-not($privateSess = New-PSSession -ComputerName $privateIP -Credential $vmCreds -ErrorAction SilentlyContinue)){if (($sw.ElapsedMilliseconds -gt 240000) -and (-not($privateSess))){$sw.Stop(); throw [System.Exception]"Unable to establish a remote session to the tenant VM using private IP: $privateIP"}; Start-Sleep -Seconds 15}; Invoke-Command -Session $privateSess -Script{Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False | Out-Null} } -ArgumentList $privateVMIP, $vmCreds -ErrorVariable remoteExecError 2>$null
                $privateVMResponseFromRemoteSession = Invoke-Command -Session $publicVMSession -Script{param($targetIP) $targetName = $targetIP; $pingOptions = New-Object Net.NetworkInformation.PingOptions(64, $true); [int]$PingDataSize = 1472; [int]$TimeoutMilliseconds = 1000; $pingData = New-Object byte[]($PingDataSize); $ping = New-Object Net.NetworkInformation.Ping; $task = $ping.SendPingAsync($targetName, $TimeoutMilliseconds, $pingData, $pingOptions); [Threading.Tasks.Task]::WaitAll($task); if ($task.Result.Status -ne "Success") {throw "Ping request returned error $($task.Result.Status)"} else {return "Success"} } -ArgumentList $privateVMIP -ErrorVariable remoteExecError 2>$null               
                $publicVMSession | Remove-PSSession -Confirm:$false
                if ($remoteExecError)
                {
                    throw [System.Exception]"$remoteExecError"
                }
                if ($privateVMResponseFromRemoteSession)
                {
                    "MTU sized packet transfer between tenant VM1 on host $publicVMHost and tenant VM2 on host $privateVMHost succeeded"
                }
                else 
                {
                    throw [System.Exception]"Failed to transmit MTU sized packets between the tenant VMs"
                }
            }    
        }
    }

    Invoke-Usecase -Name 'AddDatadiskToVMWithPrivateIP' -Description "Add a data disk from utilities resource group to the VM with private IP" -UsecaseBlock `
    {
        Invoke-Usecase -Name 'StopDeallocateVMWithPrivateIPBeforeAddingDatadisk' -Description "Stop/Deallocate the VM with private IP before adding the data disk" -UsecaseBlock `
        {
            if ($vmObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop)
            {
                $stopVM = $vmObject | Stop-AzureRmVM -Force -ErrorAction Stop
                if (($stopVM.StatusCode -eq "OK") -and ($stopVM.IsSuccessStatusCode))
                {
                    $vmStatus = (Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -Status).Statuses
                    $powerState = ($vmStatus | Where-Object Code -match "PowerState").DisplayStatus
                    if (-not (($powerState -eq "VM stopped") -or ($powerState -eq "VM deallocated")))
                    {
                        throw [System.Exception]"Unexpected PowerState $powerState"
                    }
                }
                else
                {
                    throw [System.Exception]"Failed to stop the VM"
                }
            }
        }

        Invoke-Usecase -Name 'AddTheDataDiskToVMWithPrivateIP' -Description "Attach the data disk to VM with private IP" -UsecaseBlock `
        {
            $datadiskUri = GetAzureStackBlobUri -ResourceGroupName $CanaryUtilitiesRG -BlobContent "VMDataDisk.VHD" -StorageAccountName $storageAccName -StorageContainerName $storageCtrName
            if ($datadiskUri)
            {
                if ($vmObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop)
                {
                    $destinationUri = Split-Path -Path $datadiskUri
                    $destinationUri = $destinationUri.Replace("\", "/") + "/VMDataDisk/VMDataDisk.vhd"
                    $vmObject | Add-AzureRmVMDataDisk -CreateOption fromImage -SourceImageUri $datadiskUri -Lun 1 -DiskSizeInGB 1 -Caching ReadWrite -VhdUri $destinationUri -ErrorAction Stop
                    Update-AzureRmVM -VM $vmObject -ResourceGroupName $CanaryVMRG -ErrorAction Stop
                }
            }
        } 

        Invoke-Usecase -Name 'StartVMWithPrivateIPAfterAddingDatadisk' -Description "Start the VM with private IP after adding data disk and updating the VM" -UsecaseBlock `
        {
            if ($vmObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop)
            {
                $startVM = $vmObject | Start-AzureRmVM -ErrorAction Stop
                if (-not (($startVM.StatusCode -eq "OK") -and ($startVM.IsSuccessStatusCode)))
                {
                    throw [System.Exception]"Failed to start the VM $privateVMName"
                }
            }
        }
    }

    Invoke-Usecase -Name 'ApplyDataDiskCheckCustomScriptExtensionToVMWithPrivateIP' -Description "Apply custom script that checks for the presence of data disk on the VM with private IP" -UsecaseBlock `
    {
        Invoke-Usecase -Name 'CheckForExistingCustomScriptExtensionOnVMWithPrivateIP' -Description "Check for any existing custom script extensions on the VM with private IP" -UsecaseBlock `
        {
            if ($vmObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop)
            {
                if ($existingCustomScriptExtension = $vmObject.Extensions | Where-Object VirtualMachineExtensionType -eq "CustomScriptExtension")
                {
                    Remove-AzureRmVMCustomScriptExtension -ResourceGroupName $CanaryVMRG -VMName $privateVMName -Name $existingCustomScriptExtension.Name -Force -ErrorAction Stop    
                }
            }
        }

        Invoke-Usecase -Name 'ApplyCustomScriptExtensionToVMWithPrivateIP' -Description "Apply the custom script extension to the VM with private IP" -UsecaseBlock `
        {
            $customScriptUri = GetAzureStackBlobUri -ResourceGroupName $CanaryUtilitiesRG -BlobContent "ASCheckDataDiskUtil.ps1" -StorageAccountName $storageAccName -StorageContainerName $storageCtrName
            if ($customScriptUri)
            {
                if ($vmObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop)
                {
                    $vmObject | Set-AzureRmVMCustomScriptExtension -FileUri $CustomScriptUri -Run "ASCheckDataDiskUtil.ps1" -Name ([io.path]::GetFileNameWithoutExtension("ASCheckDataDiskUtil.ps1")) -VMName $privateVMName -TypeHandlerVersion "1.7" -ErrorAction Stop
                    Update-AzureRmVM -VM $vmObject -ResourceGroupName $CanaryVMRG -ErrorAction Stop 
                }
            }
        }
    }

    Invoke-Usecase -Name 'RestartVMWithPublicIP' -Description "Restart the VM which has a public IP address" -UsecaseBlock `
    {
        if ($vmObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $publicVMName -ErrorAction Stop)
        {
            $restartVM = $vmObject | Restart-AzureRmVM -ErrorAction Stop
            if (-not (($restartVM.StatusCode -eq "OK") -and ($restartVM.IsSuccessStatusCode)))
            {
                throw [System.Exception]"Failed to restart the VM $publicVMName"
            }
        }
    }

    Invoke-Usecase -Name 'StopDeallocateVMWithPrivateIP' -Description "Stop/Dellocate the VM with private IP" -UsecaseBlock `
    {
        if ($vmObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop)
        {
            $stopVM = $vmObject | Stop-AzureRmVM -Force -ErrorAction Stop
            if (($stopVM.StatusCode -eq "OK") -and ($stopVM.IsSuccessStatusCode))
            {
                $vmStatus = (Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -Status).Statuses
                $powerState = ($vmStatus | Where-Object Code -match "PowerState").DisplayStatus
                if (-not (($powerState -eq "VM stopped") -or ($powerState -eq "VM deallocated")))
                {
                    throw [System.Exception]"Unexpected PowerState $powerState"
                }
            }
            else 
            {
                throw [System.Exception]"Unexpected StatusCode/IsSuccessStatusCode: $stopVM.StatusCode/$stopVM.IsSuccessStatusCode"
            }  
        }
    }

    Invoke-Usecase -Name 'StartVMWithPrivateIP' -Description "Start the VM with private IP" -UsecaseBlock `
    {
        if ($vmObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop)
        {
            $startVM = $vmObject | Start-AzureRmVM -ErrorAction Stop
            if (-not (($startVM.StatusCode -eq "OK") -and ($startVM.IsSuccessStatusCode)))
            {
                throw [System.Exception]"Failed to start the VM $privateVMName"   
            }
        }
    }

    Invoke-Usecase -Name 'CheckVMCommunicationPostVMReboot' -Description "Check if the VMs deployed can talk to each other after they are rebooted" -UsecaseBlock `
    {
        $vmUser = ".\$VMAdminUserName"
        $vmCreds = New-Object System.Management.Automation.PSCredential $vmUser, (ConvertTo-SecureString $VMAdminUserPass -AsPlainText -Force)
        $vmCommsScriptBlock = "hostname"
        if (($pubVMObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $publicVMName -ErrorAction Stop) -and ($pvtVMObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop))
        {
            Set-item wsman:\localhost\Client\TrustedHosts -Value $publicVMIP -Force -Confirm:$false
            $sw = [system.diagnostics.stopwatch]::startNew()
            while (-not($publicVMSession = New-PSSession -ComputerName $publicVMIP -Credential $vmCreds -ErrorAction SilentlyContinue)){if (($sw.ElapsedMilliseconds -gt 240000) -and (-not($publicVMSession))){$sw.Stop(); throw [System.Exception]"Unable to establish a remote session to the tenant VM using public IP: $publicVMIP"}; Start-Sleep -Seconds 15}
            if ($publicVMSession)
            {
                Invoke-Command -Session $publicVMSession -Script{param ($privateIP) Set-item wsman:\localhost\Client\TrustedHosts -Value $privateIP -Force -Confirm:$false} -ArgumentList $privateVMIP | Out-Null
                $privateVMResponseFromRemoteSession = Invoke-Command -Session $publicVMSession -Script{param ($privateIP, $vmCreds, $scriptToRun) $sw = [system.diagnostics.stopwatch]::startNew(); while (-not($privateSess = New-PSSession -ComputerName $privateIP -Credential $vmCreds -ErrorAction SilentlyContinue)){if (($sw.ElapsedMilliseconds -gt 240000) -and (-not($privateSess))){$sw.Stop(); throw [System.Exception]"Unable to establish a remote session to the tenant VM using private IP: $privateIP"}; Start-Sleep -Seconds 15}; Invoke-Command -Session $privateSess -Script{param($script) Invoke-Expression $script} -ArgumentList $scriptToRun} -ArgumentList $privateVMIP, $vmCreds, $vmCommsScriptBlock -ErrorVariable remoteExecError 2>$null
                $publicVMSession | Remove-PSSession -Confirm:$false
                if ($remoteExecError)
                {
                    throw [System.Exception]"$remoteExecError"
                }
                if ($privateVMResponseFromRemoteSession)
                {
                    $privateVMResponseFromRemoteSession
                }
                else 
                {
                    throw [System.Exception]"Host name could not be retrieved from the tenant VM with private IP: $privateVMIP"
                }
            }    
        }
    }
    
    Invoke-Usecase -Name 'CheckExistenceOfScreenShotForVMWithPrivateIP' -Description "Check if screen shots are available for Windows VM with private IP and store the screen shot in log folder" -UsecaseBlock `
    {
        $sa = Get-AzureRmStorageAccount -ResourceGroupName $CanaryVMRG -Name "$($CanaryVMRG)2sa"
        $diagSC = $sa | Get-AzureStorageContainer | Where-Object {$_.Name -like "bootdiagnostics-$CanaryVMRG*"}
        $screenShotBlob = $diagSC | Get-AzureStorageBlob | Where-Object {$_.Name -like "$privateVMName*screenshot.bmp"}
        $sa | Get-AzureStorageBlobContent -Blob $screenShotBlob.Name -Container $diagSC.Name -Destination $CanaryLogPath -Force
        if (-not (Get-ChildItem -Path $CanaryLogPath -File -Filter $screenShotBlob.name))
        {
            throw [System.Exception]"Unable to download screen shot for a Windows VM with private IP"
        }
    }

    Invoke-Usecase -Name 'EnumerateAllResources' -Description "List out all the resources that have been deployed" -UsecaseBlock `
    {
        Get-AzureRmResource
    }

    if (-not $NoCleanup)
    {
        if (-not ($NoCleanupOnFailure -and (Get-CanaryFailureStatus)))
        {
            Invoke-Usecase -Name 'DeleteVMWithPrivateIP' -Description "Delete the VM with private IP" -UsecaseBlock `
            {
                if ($vmObject = Get-AzureRmVM -ResourceGroupName $CanaryVMRG -Name $privateVMName -ErrorAction Stop)
                {
                    $deleteVM = $vmObject | Remove-AzureRmVM -Force -ErrorAction Stop
                    if (-not (($deleteVM.StatusCode -eq "OK") -and ($deleteVM.IsSuccessStatusCode)))
                    {
                        throw [System.Exception]"Failed to delete the VM $privateVMName"
                    }
                }
            }

            Invoke-Usecase -Name 'DeleteVMResourceGroup' -Description "Delete the resource group that contains all the VMs and corresponding resources" -UsecaseBlock `
            {
                if ($removeRG = Get-AzureRmResourceGroup -Name $CanaryVMRG -ErrorAction Stop)
                {
                    $removeRG | Remove-AzureRmResourceGroup -Force -ErrorAction Stop
                }
            }

            Invoke-Usecase -Name 'DeleteUtilitiesResourceGroup' -Description "Delete the resource group that contains all the utilities and corresponding resources" -UsecaseBlock `
            {
                if ($removeRG = Get-AzureRmResourceGroup -Name $CanaryUtilitiesRG -ErrorAction Stop)
                {
                    $removeRG | Remove-AzureRmResourceGroup -Force -ErrorAction Stop
                }
            }

            if (($TenantAdminCredentials) -or ($listAvl))
            {
                Invoke-Usecase -Name 'TenantRelatedcleanup' -Description "Remove all the tenant related resources" -UsecaseBlock `
                {
                    Invoke-Usecase -Name 'DeleteTenantSubscriptions' -Description "Remove all the tenant related subscriptions" -UsecaseBlock `
                    {
                        if ($subs = Get-AzsSubscription -ErrorAction Stop | Where-Object DisplayName -eq $tenantSubscriptionName)
                        {
                            Remove-AzsSubscription -TargetSubscriptionId $subs.SubscriptionId -ErrorAction Stop
                        } 
                        if ($subs = Get-AzsSubscription -ErrorAction Stop | Where-Object DisplayName -eq $canaryDefaultTenantSubscription)
                        {
                            Remove-AzsSubscription -TargetSubscriptionId $subs.SubscriptionId -ErrorAction Stop
                        } 
                        $sw = [system.diagnostics.stopwatch]::startNew()
                        while ((Get-AzsSubscription -ErrorAction Stop | Where-Object DisplayName -eq $tenantSubscriptionName) -or (Get-AzsSubscription -ErrorAction Stop | Where-Object DisplayName -eq $canaryDefaultTenantSubscription))
                        {
                            if ($sw.Elapsed.Seconds -gt 600) {break}
                            Start-Sleep -Seconds 30
                        }
                        $sw.Stop()
                    }

                    Invoke-Usecase -Name 'LoginToAzureStackEnvAsSvcAdminForCleanup' -Description "Login to $SvcAdminEnvironmentName as service administrator to remove the subscription resource group" -UsecaseBlock `
                    {     
                        Add-AzureRmAccount -EnvironmentName $SvcAdminEnvironmentName -Credential $ServiceAdminCredentials -TenantId $TenantID -ErrorAction Stop
                    }

                    Invoke-Usecase -Name 'RemoveLinuxImageFromPIR' -Description "Remove the Linux image uploaded during setup from the Platform Image Respository" -UsecaseBlock `
                    {
                        if ((Get-AzureRmVMImage -Location $ResourceLocation -PublisherName $linuxImagePublisher -Offer $linuxImageOffer -Sku $LinuxOSSku -ErrorAction SilentlyContinue) -and ($linuxUpload))
                        {
                            Remove-AzsVMImage -publisher $linuxImagePublisher -offer $linuxImageOffer -sku $LinuxOSSku -version $linuxImageVersion -Location $ResourceLocation -Force
                        }
                    }
                    Invoke-Usecase -Name 'DeleteSubscriptionResourceGroup' -Description "Delete the resource group that contains subscription resources" -UsecaseBlock `
                    {   
                        if ($removeRG = Get-AzureRmResourceGroup -Name $subscriptionRGName -ErrorAction Stop)
                        {
                            $removeRG | Remove-AzureRmResourceGroup -Force -ErrorAction Stop
                        }
                    } 
                }   
            }
        }
    }

    End-Scenario
    $runCount += 1
    if (-not $ListAvailable)
    {
        Get-CanaryResult
    }    
}

if ($NumberOfIterations -gt 1)
{
    Get-CanaryLonghaulResult -LogPath $CanaryLogPath
}
