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
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantArmEndpoint,    
    [parameter(HelpMessage="Tenant administrator account credentials from the Azure Stack active directory")] 
    [Parameter(ParameterSetName="default", Mandatory=$false)]
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
    [string] $LinuxImagePath = "https://partner-images.canonical.com/azure/azure_stack/ubuntu-14.04-LTS-microsoft_azure_stack-20161208-9.vhd.zip",
    [parameter(HelpMessage="Linux OS sku")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [string] $LinuxOSSku = "14.04.3-LTS",
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
    [string]$CanaryUtilitiesRG = "canur" + [Random]::new().Next(1,999),
    [parameter(HelpMessage="Resource group under which the virtual machines need to be placed")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CanaryVMRG = "canvr" + [Random]::new().Next(1,999),
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
    [parameter(HelpMessage="Specifies the path for log files")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CanaryLogPath = $env:TMP + "\CanaryLogs$((Get-Date).Ticks)",
	[parameter(HelpMessage="Specifies the file name for canary log file")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CanaryLogFileName = "Canary-Basic-$((Get-Date).Ticks).log"   
)

#requires -Modules AzureRM.Profile, AzureRM.AzureStackAdmin
#Requires -RunAsAdministrator
Import-Module -Name $PSScriptRoot\Canary.Utilities.psm1 -Force
Import-Module -Name $PSScriptRoot\..\Connect\AzureStack.Connect.psm1 -Force
Import-Module -Name $PSScriptRoot\..\Infrastructure\AzureStack.Infra.psm1 -Force
Import-Module -Name $PSScriptRoot\..\ComputeAdmin\AzureStack.ComputeAdmin.psm1 -Force

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

$runCount = 1
$tmpLogname = $CanaryLogFileName
while ($runCount -le $NumberOfIterations)
{
    if (Test-Path -Path $canaryUtilPath)
    {
        Remove-Item -Path $canaryUtilPath -Force -Recurse 
    }
    New-Item -Path $canaryUtilPath -ItemType Directory | Out-Null

    #
    # Start Canary 
    #  
    $CanaryLogFileName = [IO.Path]::GetFileNameWithoutExtension($tmpLogname) + "-$runCount" + [IO.Path]::GetExtension($tmpLogname)
    $CanaryLogFile = Join-Path -Path $CanaryLogPath -ChildPath $CanaryLogFileName

    Start-Scenario -Name 'Canary' -Type 'Basic' -LogFilename $CanaryLogFile -ContinueOnFailure $ContinueOnFailure

    $SvcAdminEnvironmentName = $EnvironmentName + "-SVCAdmin"
    $TntAdminEnvironmentName = $EnvironmentName + "-Tenant"

    if(-not $EnvironmentDomainFQDN)
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
       
    if ($WindowsISOPath)
    {
        Invoke-Usecase -Name 'UploadWindows2016ImageToPIR' -Description "Uploads a windows server 2016 image to the PIR" -UsecaseBlock `
        {
            if (-not (Get-AzureRmVMImage -Location $ResourceLocation -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Sku "2016-Datacenter-Core" -ErrorAction SilentlyContinue))
            {
                New-Server2016VMImage -ISOPath $WindowsISOPath -TenantId $TenantID -EnvironmentName $SvcAdminEnvironmentName -Version Core -AzureStackCredentials $ServiceAdminCredentials -CreateGalleryItem $false
            }
        }
    }

    if ((Get-Volume ((Get-Item -Path $ENV:TMP).PSDrive.Name)).SizeRemaining/1GB -gt 35)
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
                    Add-VMImage -publisher $linuxImagePublisher -offer $linuxImageOffer -sku $LinuxOSSku -version $linuxImageVersion -osDiskLocalPath $CustomVHDPath -osType Linux -tenantID $TenantID -azureStackCredentials $ServiceAdminCredentials -CreateGalleryItem $false -EnvironmentName $SvcAdminEnvironmentName
                    Remove-Item $CanaryCustomImageFolder -Force -Recurse
                }    
            }
            catch
            {
                Remove-Item -Path $CanaryCustomImageFolder -Force -Recurse
                throw [System.Exception]"Failed to upload the linux image to PIR. `n$($_.Exception.Message)"            
            }
        }
    }

    if ($TenantAdminCredentials)
    {
        $subscriptionRGName                 = "ascansubscrrg" + [Random]::new().Next(1,999)
        $tenantPlanName                     = "ascantenantplan" + [Random]::new().Next(1,999)        
        $tenantOfferName                    = "ascantenantoffer" + [Random]::new().Next(1,999)
        $tenantSubscriptionName             = "ascanarytenantsubscription" + [Random]::new().Next(1,999)            
        $canaryDefaultTenantSubscription    = "canarytenantdefaultsubscription" + [Random]::new().Next(1,999) 

        if (-not $TenantArmEndpoint)
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
                $asTenantSubscription | Select-AzureRmSubscription -ErrorAction Stop
            }           
        } 

        Invoke-Usecase -Name 'RegisterResourceProviders' -Description "Register resource providers" -UsecaseBlock `
        {
            Get-AzureRmResourceProvider -ListAvailable | Register-AzureRmResourceProvider -Force        
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

    Invoke-Usecase -Name 'DeployARMTemplate' -Description "Deploy ARM template to setup the virtual machines" -UsecaseBlock `
    {        
        $kvSecretId = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $kvSecretName -IncludeVersions -ErrorAction Stop).Id  
        $osVersion = ""
        if (Get-AzureRmVMImage -Location $ResourceLocation -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Sku "2016-Datacenter-Core" -ErrorAction SilentlyContinue)
        {
            $osVersion = "2016-Datacenter-Core"
        }
        elseif (Get-AzureRmVMImage -Location $ResourceLocation -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Sku "2016-Datacenter" -ErrorAction SilentlyContinue)
        {
            $osVersion = "2016-Datacenter"
        }
        elseif (Get-AzureRmVMImage -Location $ResourceLocation -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Sku "2012-R2-Datacenter" -ErrorAction SilentlyContinue)
        {
            $osVersion = "2012-R2-Datacenter"
        } 
        $linuxImgExists = $false      
        if (Get-AzureRmVMImage -Location $ResourceLocation -PublisherName "Canonical" -Offer "UbuntuServer" -Sku $LinuxOSSku -ErrorAction SilentlyContinue)
        {
            $linuxImgExists = $true
        }

        $templateDeploymentName = "CanaryVMDeployment"
        $parameters = @{"VMAdminUserName"       = $VMAdminUserName;
                        "VMAdminUserPassword"   = $VMAdminUserPass;
                        "ASCanaryUtilRG"        = $CanaryUtilitiesRG;
                        "ASCanaryUtilSA"        = $storageAccName;
                        "ASCanaryUtilSC"        = $storageCtrName;
                        "vaultName"             = $keyvaultName;
                        "windowsOSVersion"      = $osVersion;
                        "secretUrlWithVersion"  = $kvSecretId;
                        "LinuxImagePublisher"   = $linuxImagePublisher;
                        "LinuxImageOffer"       = $linuxImageOffer;
                        "LinuxImageSku"         = $LinuxOSSku}   
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
            if ($publicVMSession = New-PSSession -ComputerName $publicVMIP -Credential $vmCreds -ErrorAction Stop)
            {
                Invoke-Command -Session $publicVMSession -Script{param ($privateIP) Set-item wsman:\localhost\Client\TrustedHosts -Value $privateIP -Force -Confirm:$false} -ArgumentList $privateVMIP | Out-Null
                $privateVMResponseFromRemoteSession = Invoke-Command -Session $publicVMSession -Script{param ($privateIP, $vmCreds, $scriptToRun) $privateSess = New-PSSession -ComputerName $privateIP -Credential $vmCreds; Invoke-Command -Session $privateSess -Script{param($script) Invoke-Expression $script} -ArgumentList $scriptToRun} -ArgumentList $privateVMIP, $vmCreds, $vmCommsScriptBlock
                if ($privateVMResponseFromRemoteSession)
                {
                    $publicVMSession | Remove-PSSession -Confirm:$false
                    $privateVMResponseFromRemoteSession
                }
                else 
                {
                    throw [System.Exception]"Public VM was not able to talk to the Private VM via the private IP"
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
            if ($publicVMSession = New-PSSession -ComputerName $publicVMIP -Credential $vmCreds -ErrorAction Stop)
            {
                Invoke-Command -Session $publicVMSession -Script{param ($privateIP) Set-item wsman:\localhost\Client\TrustedHosts -Value $privateIP -Force -Confirm:$false} -ArgumentList $privateVMIP | Out-Null
                $privateVMResponseFromRemoteSession = Invoke-Command -Session $publicVMSession -Script{param ($privateIP, $vmCreds, $scriptToRun) $privateSess = New-PSSession -ComputerName $privateIP -Credential $vmCreds; Invoke-Command -Session $privateSess -Script{param($script) Invoke-Expression $script} -ArgumentList $scriptToRun} -ArgumentList $privateVMIP, $vmCreds, $vmCommsScriptBlock
                if ($privateVMResponseFromRemoteSession)
                {
                    $publicVMSession | Remove-PSSession -Confirm:$false
                    $privateVMResponseFromRemoteSession
                }
                else 
                {
                    throw [System.Exception]"Public VM was not able to talk to the Private VM via the private IP"
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

        if ($TenantAdminCredentials)
        {
            Invoke-Usecase -Name 'TenantRelatedcleanup' -Description "Remove all the tenant related stuff" -UsecaseBlock `
            {
                Invoke-Usecase -Name 'DeleteTenantSubscriptions' -Description "Remove all the tenant related subscriptions" -UsecaseBlock `
                {
                    if ($subs = Get-AzureRmTenantSubscription -ErrorAction Stop | Where-Object DisplayName -eq $tenantSubscriptionName)
                    {
                        Remove-AzureRmTenantSubscription -TargetSubscriptionId $subs.SubscriptionId -ErrorAction Stop
                    } 
                    if ($subs = Get-AzureRmTenantSubscription -ErrorAction Stop | Where-Object DisplayName -eq $canaryDefaultTenantSubscription)
                    {
                        Remove-AzureRmTenantSubscription -TargetSubscriptionId $subs.SubscriptionId -ErrorAction Stop
                    } 
                }

                Invoke-Usecase -Name 'LoginToAzureStackEnvAsSvcAdminForCleanup' -Description "Login to $SvcAdminEnvironmentName as service administrator to remove the subscription resource group" -UsecaseBlock `
                {     
                    Add-AzureRmAccount -EnvironmentName $SvcAdminEnvironmentName -Credential $ServiceAdminCredentials -TenantId $TenantID -ErrorAction Stop
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

    End-Scenario
    $runCount += 1
    Get-CanaryResult
}

if ($NumberOfIterations -gt 1)
{
    Get-CanaryLonghaulResult -LogPath $CanaryLogPath
}

# SIG # Begin signature block
# MIId4AYJKoZIhvcNAQcCoIId0TCCHc0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEZJ3n83/Shwe4ADhgMwhxdxf
# Jn6gghhlMIIEwzCCA6ugAwIBAgITMwAAAMWWQGBL9N6uLgAAAAAAxTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODUy
# WhcNMTgwOTA3MTc1ODUyWjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkMwRjQtMzA4Ni1ERUY4MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtrwz4CWOpvnw
# EBVOe1crKElrs3CQl/yun1cdkpugh/MxsuoGn7BL43GRTxRn7sPD7rq1Dxj4smPl
# gVZr/ZhGMA8J3zXOqyIcD4hYFikXuhlGuuSokunCAxUl5N4gjN/M7+NwJPm2JtYK
# ZLBdH5J/y+GIk7rQhpgbstpLOZf4GHgC8Myji7089O1uX2MCKFFU+wt2Y560O4Xc
# 2NVjeuG+nnq5pGyq9111nK3f0DeT7FWjDVQWFghKOhyeBb4iMhmkdA8vWpYmx6TN
# c+d35nSZcLc0EhSIVJkzEBYfwkrzxFaG/pgNJ9C4jm/zHgwWLZwQpU7K2fP15fGk
# BGplwNjr1wIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFA4B9X87yXgCWEZxOwn8mnVX
# hjjEMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAAUS3tgSEzCpyuw21ySUAWvGltQxunyLUCaOf1dffUcG25oa
# OW/WuIFJs0lv8Py6TsOrulsx/4NTkIyXra/MsJvwczMX2s/vx6g63O3osQI85qHD
# dp8IMULGmry+oqPVTuvL7Bac905EqqGXGd9UY7y14FcKWBWJ28vjncTw8CW876pY
# 80nSm8hC/38M4RMGNEp7KGYxx5ZgGX3NpAVeUBio7XccXHEy7CSNmXm2V8ijeuGZ
# J9fIMkhiAWLEfKOgxGZ63s5yGwpMt2QE/6Py03uF+X2DHK76w3FQghqiUNPFC7uU
# o9poSfArmeLDuspkPAJ46db02bqNyRLP00bczzwwggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TCCBhEwggP5
# oAMCAQICEzMAAACOh5GkVxpfyj4AAAAAAI4wDQYJKoZIhvcNAQELBQAwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xNjExMTcyMjA5MjFaFw0xODAy
# MTcyMjA5MjFaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQh9RCK36d2cZ61KLD4xWS
# 0lOdlRfJUjb6VL+rEK/pyefMJlPDwnO/bdYA5QDc6WpnNDD2Fhe0AaWVfIu5pCzm
# izt59iMMeY/zUt9AARzCxgOd61nPc+nYcTmb8M4lWS3SyVsK737WMg5ddBIE7J4E
# U6ZrAmf4TVmLd+ArIeDvwKRFEs8DewPGOcPUItxVXHdC/5yy5VVnaLotdmp/ZlNH
# 1UcKzDjejXuXGX2C0Cb4pY7lofBeZBDk+esnxvLgCNAN8mfA2PIv+4naFfmuDz4A
# lwfRCz5w1HercnhBmAe4F8yisV/svfNQZ6PXlPDSi1WPU6aVk+ayZs/JN2jkY8fP
# AgMBAAGjggGAMIIBfDAfBgNVHSUEGDAWBgorBgEEAYI3TAgBBggrBgEFBQcDAzAd
# BgNVHQ4EFgQUq8jW7bIV0qqO8cztbDj3RUrQirswUgYDVR0RBEswSaRHMEUxDTAL
# BgNVBAsTBE1PUFIxNDAyBgNVBAUTKzIzMDAxMitiMDUwYzZlNy03NjQxLTQ0MWYt
# YmM0YS00MzQ4MWU0MTVkMDgwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1
# ApUwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEF
# BQcBAQRVMFMwUQYIKwYBBQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNV
# HRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBEiQKsaVPzxLa71IxgU+fKbKhJ
# aWa+pZpBmTrYndJXAlFq+r+bltumJn0JVujc7SV1eqVHUqgeSxZT8+4PmsMElSnB
# goSkVjH8oIqRlbW/Ws6pAR9kRqHmyvHXdHu/kghRXnwzAl5RO5vl2C5fAkwJnBpD
# 2nHt5Nnnotp0LBet5Qy1GPVUCdS+HHPNIHuk+sjb2Ns6rvqQxaO9lWWuRi1XKVjW
# kvBs2mPxjzOifjh2Xt3zNe2smjtigdBOGXxIfLALjzjMLbzVOWWplcED4pLJuavS
# Vwqq3FILLlYno+KYl1eOvKlZbiSSjoLiCXOC2TWDzJ9/0QSOiLjimoNYsNSa5jH6
# lEeOfabiTnnz2NNqMxZQcPFCu5gJ6f/MlVVbCL+SUqgIxPHo8f9A1/maNp39upCF
# 0lU+UK1GH+8lDLieOkgEY+94mKJdAw0C2Nwgq+ZWtd7vFmbD11WCHk+CeMmeVBoQ
# YLcXq0ATka6wGcGaM53uMnLNZcxPRpgtD1FgHnz7/tvoB3kH96EzOP4JmtuPe7Y6
# vYWGuMy8fQEwt3sdqV0bvcxNF/duRzPVQN9qyi5RuLW5z8ME0zvl4+kQjOunut6k
# LjNqKS8USuoewSI4NQWF78IEAA1rwdiWFEgVr35SsLhgxFK1SoK3hSoASSomgyda
# Qd691WZJvAuceHAJvDCCB3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEx
# MB4XDTExMDcwODIwNTkwOVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUg
# U2lnbmluZyBQQ0EgMjAxMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AKvw+nIQHC6t2G6qghBNNLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL
# 8DjCmQawyDnVARQxQtOJDXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/X
# llnKYBoF6WZ26DJSJhIv56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5k
# NXimoGMPLdNAk/jj3gcN1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJ
# Xtjt7UORg9l7snuGG9k+sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4
# ftKdgCz1TlaRITUlwzluZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgo
# tswnKDglmDlKNs98sZKuHCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0Xpb
# L9Uj43BdD1FGd7P4AOG8rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy
# 5yTfv0aZxe/CHFfbg43sTUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9
# Z4DmimJ4X7IvhNdXnFy/dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4
# IFgsE11glZo+TzOE2rCIF96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQ
# BgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUw
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0f
# BFMwUTBPoE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcB
# AQRSMFAwTgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kv
# Y2VydHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGX
# MIGUMIGRBgkrBgEEAYI3LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcC
# AjA0HjIgHQBMAGUAZwBhAGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUA
# bgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFj
# kplCln3SeQyQwWVfLiw++MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtG
# UFXYDJJ80hpLHPM8QotS0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32m
# kHSDjfTLJgJGKsKKELukqQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr
# 3vw70L01724lruWvJ+3Q3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYK
# wsatruWy2dsViFFFWDgycScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6C
# PxNNZgvAs0314Y9/HG8VfUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX
# 0O5dY0HjWwechz4GdwbRBrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADW
# oUa9WfOXpQlLSBCZgB/QACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9r
# t0uX4ut1eBrs6jeZeRhL/9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGd
# Vk5Pv4BXIqF4ETIheu9BCrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9
# bW1qyVJzEw16UM0xggTlMIIE4QIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5n
# IFBDQSAyMDExAhMzAAAAjoeRpFcaX8o+AAAAAACOMAkGBSsOAwIaBQCggfkwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFNBY5VetHAPtYVy2nLCcaULcgZ8IMIGYBgor
# BgEEAYI3AgEMMYGJMIGGoFaAVABBAHoAdQByAGUAIABTAHQAYQBjAGsAIABUAG8A
# bwBsAHMAIABNAG8AZAB1AGwAZQBzACAAYQBuAGQAIABUAGUAcwB0ACAAUwBjAHIA
# aQBwAHQAc6EsgCpodHRwczovL2dpdGh1Yi5jb20vQXp1cmUvQXp1cmVTdGFjay1U
# b29scyAwDQYJKoZIhvcNAQEBBQAEggEAKQ9fXlZaFxV0vKUq0M1fitmM+jF0dAW7
# 4EUhVGNTSk47PoZIq4USnwgZKTAZ0+P1tGwzjga60JOfhUBQ9ge2geqbh2UCjAu2
# JfCwXM827aMOC1neE4RHVdkemy1JllyNZJ53VAuH7Exztf1PXub6F+oZtlBtIysX
# XFTC4OttyJ7afL9gJORhXLc1uDLkVs+gJVe8ccn4gKaVTjLV2nK61Pj1S0UTsIq6
# Lk2uuZjRultpjYeR2Fp4SJ5WAN1PFs9DQD9Z6/XxMo0NmDmrJvhzUA1efsw8k6Zx
# 7iCYlWsTsO4IUd6Wy4/s1QR4Vp/cEmq6LNJzqMmZayYLsycxPQvWE6GCAigwggIk
# BgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0ECEzMAAADFlkBgS/Teri4AAAAAAMUwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE3MDUyNDA5MjYxNlowIwYJ
# KoZIhvcNAQkEMRYEFEwW/3RPlbLSrDQeMOW31QjuOyFHMA0GCSqGSIb3DQEBBQUA
# BIIBAFvYnBarHYs0D/kykuXk6UhrySSnR1utkirHOc5/JlUB6xm8lD19F6yYzW31
# r16BApdZuUE/pckA7XH0QVgcP2OZGKRkIpr3FJiFUOO1hy+2e3MuRaiQd6cRf5qW
# bWy5PLycISTRQptrJz6I0JJIzsmu4nzo8bJTIfMhgbtmcstDp+DRx3tsg746aUfY
# xejj+pIgSlXmbm+GMDYshDD0FPXELZtOyg5uGiLZkHpoGOB/Sh2tg0uZc+4oH9ZS
# s/yupBUvvF1+S1Znx6DIujvv5EemBd7er4oYT1r6YV/JWUSC9RMnVmv7FUm7gULy
# hGlPJBFzepDUKN08AFW/Y8aenjQ=
# SIG # End signature block
