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
    [string]$CanaryUtilitiesRG = "canur",
    [parameter(HelpMessage="Resource group under which the virtual machines need to be placed")]
    [Parameter(ParameterSetName="default", Mandatory=$false)]
    [Parameter(ParameterSetName="tenant", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CanaryVMRG = "canvr25",
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

#Requires -Modules AzureRM
#Requires -RunAsAdministrator
Import-Module -Name $PSScriptRoot\Canary.Utilities.psm1 -Force
Import-Module -Name $PSScriptRoot\..\Connect\AzureStack.Connect.psm1 -Force
Import-Module -Name $PSScriptRoot\..\Infrastructure\AzureStack.Infra.psm1 -Force
Import-Module -Name $PSScriptRoot\..\ComputeAdmin\AzureStack.ComputeAdmin.psm1 -Force

$storageAccName         = $CanaryUtilitiesRG + "sa25"
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

        #cmd /c az cloud register --name $SvcAdminEnvironmentName --endpoint-active-directory $asEndpoints.ActiveDirectoryEndpoint --endpoint-active-directory-resource-id $asEndpoints.ActiveDirectoryServiceEndpointResourceId --endpoint-resource-manager $asEndpoints.ResourceManagerEndpoint --endpoint-gallery $asEndpoints.GalleryEndpoint --endpoint-active-directory-graph-resource-id $asEndpoints.GraphEndpoint --suffix-storage-endpoint $asEndpoints.StorageEndpointSuffix --suffix-keyvault-dns $asEndpoints.AzureKeyVaultDnsSuffix --debug


    }

    Invoke-Usecase -Name 'LoginToAzureStackEnvAsSvcAdmin' -Description "Login to $SvcAdminEnvironmentName as service administrator" -UsecaseBlock `
    {     
        Add-AzureRmAccount -EnvironmentName $SvcAdminEnvironmentName -Credential $ServiceAdminCredentials -TenantId $TenantID -ErrorAction Stop
        #cmd /c az cloud set --name $SvcAdminEnvironmentName
        #cmd /c az cloud update --profile 2017-03-09-profile-preview
        #cmd /c az login -u $ServiceAdminCredentials.UserName -p $ServiceAdminCredentials.Password --tenant $TenantID
    }

    Invoke-Usecase -Name 'SelectDefaultProviderSubscription' -Description "Select the Default Provider Subscription" -UsecaseBlock `
    {
        $defaultSubscription = Get-AzureRmSubscription -SubscriptionName "Default Provider Subscription" -ErrorAction Stop
        if ($defaultSubscription)
        {
            $defaultSubscription | Select-AzureRmSubscription
        }
        #cmd /c az account set --subscription "Default Provider Subscription"
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

        Invoke-Usecase -Name 'CreateTenantAzureStackEnv' -Description "Create Azure Stack environment $TntAdminEnvironmentName" -UsecaseBlock `
        {
            $asEndpoints = GetAzureStackEndpoints -EnvironmentDomainFQDN $EnvironmentDomainFQDN -ArmEndpoint $TenantArmEndpoint
            az cloud register --name $TntAdminEnvironmentName `
                 --endpoint-active-directory $asEndpoints.ActiveDirectoryEndpoint `
                 --endpoint-active-directory-resource-id $asEndpoints.ActiveDirectoryServiceEndpointResourceId `
                 --endpoint-resource-manager $asEndpoints.ResourceManagerEndpoint `
                 --endpoint-gallery $asEndpoints.GalleryEndpoint `
                 --endpoint-active-directory-graph-resource-id $asEndpoints.GraphEndpoint `
                 --suffix-storage-endpoint $asEndpoints.StorageEndpointSuffix `
                 --suffix-keyvault-dns ("." + $asEndpoints.AzureKeyVaultDnsSuffix) 

            # Register using Powershell
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

        Invoke-Usecase -Name 'LoginToAzureStackEnvAsTenantAdmin' -Description "Login to $TntAdminEnvironmentName as tenant administrator" -UsecaseBlock `
        {     
            Add-AzureRmAccount -EnvironmentName $TntAdminEnvironmentName -Credential $TenantAdminCredentials -TenantId $TenantID -ErrorAction Stop
            az cloud set --name $TntAdminEnvironmentName
            az cloud update --profile 2017-03-09-profile-preview
            az login -u $TenantAdminCredentials.UserName -p "User@123" --tenant $TenantID
        }

        Invoke-Usecase -Name 'CreateTenantSubscription' -Description "Create a subcsription for the tenant and select it as the current subscription" -UsecaseBlock `
        {
            Set-AzureRmContext -SubscriptionName $canaryDefaultTenantSubscription
            az account set --subscription $canaryDefaultTenantSubscription
            $asCanaryOffer = Get-AzureRmOffer -Provider "Default" -ErrorAction Stop | Where-Object Name -eq $tenantOfferName
            $asTenantSubscription = New-AzureRmTenantSubscription -OfferId $asCanaryOffer.Id -DisplayName $tenantSubscriptionName -ErrorAction Stop
            if ($asTenantSubscription)
            {
                az account clear
                az login -u $TenantAdminCredentials.UserName -p "User@123" --tenant $TenantID
                $asTenantSubscription | Select-AzureRmSubscription -ErrorAction Stop
                az account set --subscription $tenantSubscriptionName
            }       
        } 

        Invoke-Usecase -Name 'RegisterResourceProviders' -Description "Register Resouce providers" -UsecaseBlock `
        {
            cmd /c set ADAL_PYTHON_SSL_NO_VERIFY=1
            cmd /c set AZURE_CLI_DISABLE_CONNECTION_VERIFICATION=1
            $providerList = cmd /c az provider list -ojson
            $providerList = $providerList | ConvertFrom-Json
            $providerList | ForEach-Object { cmd /c az provider register --namespace $_.namespace }

            $sleepTime = 0        
            while($true)
            {
                $sleepTime += 10
                Start-Sleep -Seconds  10
                $requiredRPs = az provider list -ojson
                $requiredRPs = $requiredRPs | ConvertFrom-Json 
                $requiredRPs = $requiredRPs | Where-Object {$_.Namespace -in ("Microsoft.Storage", "Microsoft.Compute", "Microsoft.Network", "Microsoft.KeyVault")}
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
        }
    }

    Invoke-Usecase -Name 'CreateResourceGroupForUtilities' -Description "Create a resource group $CanaryUtilitiesRG for placing the utility files" -UsecaseBlock `
    {    
        if(cmd /c az group show --name $CanaryUtilitiesRG)
        {
            cmd /c az group delete --name $CanaryUtilitiesRG
        }
        cmd /c az group create --location $ResourceLocation --name $CanaryUtilitiesRG
    }

    Invoke-Usecase -Name 'CreateStorageAccountForUtilities' -Description "Create a storage account for placing the utility files" -UsecaseBlock `
    {    
        $storageAccExists = (az storage account check-name --name $storageAccName -ojson)
        $storageAccExists = $storageAccExists | ConvertFrom-Json
        if (-not $storageAccExists.nameAvailable)
        {
            az storage account delete -n $storageAccName -g $CanaryUtilitiesRG --yes
        }
        cmd /c az storage account create --location $ResourceLocation --name $storageAccName --resource-group $CanaryUtilitiesRG --account-type Standard_LRS
    }

    Invoke-Usecase -Name 'CreateStorageContainerForUtilities' -Description "Create a storage container for the placing the utility files" -UsecaseBlock `
    {
        $asStorageAccountKey = az storage account keys list -n $storageAccName -g $CanaryUtilitiesRG -ojson
        if ($asStorageAccountKey)
        {
            $asStorageAccountKey = $asStorageAccountKey | ConvertFrom-Json
            $storageAccountKey = $asStorageAccountKey.key1
        }
        $storageCtrExists = (az storage container exists -n $storageCtrName --account-key $storageAccountKey --account-name $storageAccName -ojson)
        $storageCtrExists = $storageCtrExists | ConvertFrom-Json
        if ($storageCtrExists.exists)
        {
            az storage container delete --name $storageCtrName --account-key $storageAccountKey --account-name $storageAccName
        }
        az storage container create -n $storageCtrName --account-name $storageAccName --account-key $storageAccountKey --public-access container
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
            $asStorageAccountKey = az storage account keys list -n $storageAccName -g $CanaryUtilitiesRG -ojson
            if ($asStorageAccountKey)
            {
                $asStorageAccountKey = $asStorageAccountKey | ConvertFrom-Json
                $storageAccountKey = $asStorageAccountKey.key1
            }

            $files = Get-ChildItem -Path $canaryUtilPath -File
            foreach ($file in $files)
            {
                if ($file.Extension -match "VHD")
                {
                    az storage blob upload --container-name $storageCtrName --file $file.FullName --name $file.Name --account-name $storageAccName --account-key $storageAccountKey --debug --type page
                }
                else {
                    az storage blob upload --container-name $storageCtrName --file $file.FullName --name $file.Name --account-name $storageAccName --account-key $storageAccountKey --debug
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
        cmd /c az keyvault create --name $keyvaultName --resource-group $CanaryUtilitiesRG --location $ResourceLocation --sku standard --enabled-for-deployment true --enabled-for-template-deployment true
        if (-not [string]::IsNullOrWhiteSpace($TenantAdminObjectId)) 
        {
            az keyvault set-policy --name $keyvaultName --resource-group $CanaryUtilitiesRG --object-id $TenantAdminObjectId --key-permissions all --secret-permissions all
        }
        $kvSecret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText -Force
        az keyvault secret set --name $kvSecretName --vault-name $keyvaultName --value $kvSecret
    }

    Invoke-Usecase -Name 'CreateResourceGroupForVMs' -Description "Create a resource group $CanaryVMRG for placing the VMs and corresponding resources" -UsecaseBlock `
    {
        if(cmd /c az group show --name $CanaryVMRG)
        {
            cmd /c az group delete --name $CanaryVMRG
        }
        cmd /c az group create --location $ResourceLocation --name $CanaryVMRG
    }

    Invoke-Usecase -Name 'DeployARMTemplate' -Description "Deploy ARM template to setup the virtual machines" -UsecaseBlock `
    {
        $osVersion = ""
        if (cmd /c az vm image list --location $ResourceLocation --publisher "MicrosoftWindowsServer" --offer "WindowsServer" --sku "2016-Datacenter-Core" --all)
        {
            $osVersion = "2016-Datacenter-Core"
        }
        elseif (cmd /c az vm image list --location $ResourceLocation --publisher "MicrosoftWindowsServer" --offer "WindowsServer" --sku "2016-Datacenter" --all)
        {
            $osVersion = "2016-Datacenter"
        }
        elseif (cmd /c az vm image list --location $ResourceLocation --publisher "MicrosoftWindowsServer" --offer "WindowsServer" --sku "2012-R2-Datacenter" --all)
        {
            $osVersion = "2012-R2-Datacenter"
        } 
        $linuxImgExists = $false      
        if (cmd /c az vm image list --location $ResourceLocation --publisher "Canonical" --offer "UbuntuServer" --sku $LinuxOSSku --all)
        {
            $linuxImgExists = $true
        }

        $templateDeploymentName = "CanaryVMDeployment"

        if (-not $linuxImgExists)
        {
            $templateError = cmd /c az group deployment validate --resource-group $CanaryVMRG --template-file $PSScriptRoot\azuredeploy.CLI.json --verbose -ojson
            $templateError = $templateError | convertfrom-json
        }
        elseif ($linuxImgExists) 
        {
            $templateError = cmd /c az group deployment validate --resource-group $CanaryVMRG --template-file $PSScriptRoot\azuredeploy.nolinux.CLI.json --verbose -ojson
            $templateError = $templateError | convertfrom-json
        }

        if ((-not $templateError.Error) -and ($linuxImgExists))
        {
            cmd /c az group deployment create --name $templateDeploymentName --resource-group $CanaryVMRG --template-file $PSScriptRoot\azuredeploy.CLI.json --verbose #testdeploytemplate.json --verbose # 
        }
        elseif (-not $templateError.Error) {
            cmd /c az group deployment create --name $templateDeploymentName --resource-group $CanaryVMRG --template-file $PSScriptRoot\azuredeploy.nolinux.CLI.json --verbose
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
        $vmList = cmd /c az vm list -g $CanaryVMRG -d -ojson
        $vmList = $vmList | ConvertFrom-Json
        $vmList = $vmList | Where-Object {$_.OSProfile.WindowsConfiguration}
        foreach ($vm in $vmList)
        {
            $vmObject = New-Object -TypeName System.Object
            $vmIPConfig = @()
            $privateIP  = @()
            $publicIP   = @()
            $vmObject | Add-Member -Type NoteProperty -Name VMName -Value $vm.Name 
            foreach ($nic in $vm.networkProfile.networkInterfaces.Id)
            {
                $vmNic = az vm nic show -g $canaryvmrg --vm-name $vm.Name --nic $nic -ojson
                $vmNic = $vmNic | ConvertFrom-Json
                $vmIPConfig += $vmNic.IpConfigurations
            } 
            foreach ($ipConfig in $vmIPConfig)
            {
                if ($pvtIP = $ipConfig.PrivateIpAddress)
                {
                    $privateIP += $pvtIP
                }
                if ($pubIP = $ipConfig.PublicIPAddress)
                {
                    $pubIPId = $pubIP.Id
                    $pubIP = az vm list-ip-addresses -g $canaryvmrg -n $vm.Name -ojson
                    $pubIp = $pubIP | ConvertFrom-Json
                    $publicIP += ($pubIp.virtualMachine.network.publicIpAddresses | Where-Object {$_.Id -eq $pubIPId}).IpAddress
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
        $vmCommsScriptBlock = "hostname"
        if (($pubVMObject = cmd /c az vm show -g $CanaryVMRG -d -n $publicVMName) -and ($pvtVMObject = cmd /c az vm show -g $CanaryVMRG -d -n $privateVMName))
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

    Invoke-Usecase -Name 'RestartVMWithPublicIP' -Description "Restart the VM which has a public IP address" -UsecaseBlock `
    {
        if ($vmObject = az vm show -g $CanaryVMRG -n $publicVMName -ErrorAction Stop)
        {
            $restartVM = az vm restart -g $CanaryVMRG -n $publicVMName -ojson
            $restartVM = $restartVM | ConvertFrom-Json
            if (-not ($restartVM.Status -eq "Succeeded"))
            {
                throw [System.Exception]"Failed to restart the VM $publicVMName"
            }
        }
    }

    Invoke-Usecase -Name 'StopDeallocateVMWithPrivateIP' -Description "Stop/Dellocate the VM with private IP" -UsecaseBlock `
    {
        if ($vmObject = az vm show -g $CanaryVMRG -n $privateVMName)
        {
            $stopVM = az vm stop -g $CanaryVMRG -n $privateVMName -ojson
            $stopVM = $stopVM | ConvertFrom-Json
            if ($stopVM.Status -eq "Succeeded") 
            {
                $vmInstanceView =  az vm get-instance-view -g $CanaryVMRG -n $privateVMName -ojson
                $vmInstanceView = $vmInstanceView | ConvertFrom-Json
                $powerState = ($vmInstanceView.instanceView.statuses | Where-Object Code -match "PowerState").DisplayStatus
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
        if ($vmObject = az vm show -g $CanaryVMRG -n $privateVMName)
        {
            $startVM = az vm start -g $CanaryVMRG -n $privateVMName -ojson
            $startVM = $startVM | ConvertFrom-Json
            if (-not ($startVM.Status -eq "Succeeded"))
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
        if (($pubVMObject = cmd /c az vm show -g $CanaryVMRG -d -n $publicVMName) -and ($pvtVMObject = cmd /c az vm show -g $CanaryVMRG -d -n $privateVMName))
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
        $asVmStorageAccountKey = az storage account keys list -n "$($CanaryVMRG)2sa" -g $CanaryVMRG -ojson
        if ($asVmStorageAccountKey)
        {
            $asVmStorageAccountKey = $asVmStorageAccountKey | ConvertFrom-Json
            $vmStorageAccountKey = $asVmStorageAccountKey.key1
        }

        $SCs = az storage container list --account-name "$($CanaryVMRG)2sa" --account-key $vmStorageAccountKey -ojson
        $SCs = $SCs | ConvertFrom-Json
        foreach ($sc in $SCs)
        {
            if ($sc.Name -like "bootdiagnostics-$CanaryVMRG*")
            {
                $diagSC = $sc
            }
        }

        if ($diagSC)
        {
            $blobs = az storage blob list --container-name $diagSC.Name --account-name "$($CanaryVMRG)2sa" --account-key $vmStorageAccountKey -ojson
            $blobs = $blobs | ConvertFrom-Json
            foreach ($blob in $blobs)
            {
                if ($blob.name -like "$privateVMName*screenshot.bmp")
                {
                    $screenShotBlob = $blob
                }
            }
        }

        if ($screenShotBlob)
        {
            az storage blob download --name $screenShotBlob.Name --container-name $diagSC.Name --account-name "$($CanaryVMRG)2sa" --account-key $vmStorageAccountKey --file "$CanaryLogPath\$($screenShotBlob.Name)"
        }

        if (-not (Get-ChildItem -Path $CanaryLogPath -File -Filter $screenShotBlob.name))
        {
            throw [System.Exception]"Unable to download screen shot for a Windows VM with private IP"
        }
    }

    Invoke-Usecase -Name 'EnumerateAllResources' -Description "List out all the resources that have been deployed" -UsecaseBlock `
    {
        cmd /c az resource list 
    }

    if (-not $NoCleanup)
    {
        Invoke-Usecase -Name 'DeleteVMWithPrivateIP' -Description "Delete the VM with private IP" -UsecaseBlock `
        {
            if ($vmObject = az vm show -g $CanaryVMRG -n $privateVMName)
            {
                $deleteVM = az vm delete -g $CanaryVMRG -n $privateVMName --yes -ojson
                $deleteVM = $deleteVM | ConvertFrom-Json
                if (-not ($deleteVM.Status -eq "Succeeded"))
                {
                    throw [System.Exception]"Failed to delete the VM $privateVMName"
                }
            }
        }

        Invoke-Usecase -Name 'DeleteVMResourceGroup' -Description "Delete the resource group that contains all the VMs and corresponding resources" -UsecaseBlock `
        {
            if ($removeRG = az group show --name $CanaryVMRG)
            {
                az group delete -n $CanaryVMRG --no-wait --yes
            }
        }

        Invoke-Usecase -Name 'DeleteUtilitiesResourceGroup' -Description "Delete the resource group that contains all the utilities and corresponding resources" -UsecaseBlock `
        {
            if ($removeRG = az group show --name $CanaryUtilitiesRG)
            {
                 az group delete -n $CanaryUtilitiesRG --no-wait --yes
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
