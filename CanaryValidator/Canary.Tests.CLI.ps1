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
    [string]$CanaryVMRG = "canvr",
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
                 --suffix-keyvault-dns $asEndpoints.AzureKeyVaultDnsSuffix 

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
            az cloud set --name $TntAdminEnvironmentName
            az cloud update --profile 2015-sample 
            cmd /c az login -u $TenantAdminCredentials.UserName -p $TenantAdminCredentials.Password --tenant $TenantID
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

        Invoke-Usecase -Name 'RegisterResourceProviders' -Description "Register Resouce providers" -UsecaseBlock `
        {
            cmd /c set ADAL_PYTHON_SSL_NO_VERIFY=1
            cmd /c set AZURE_CLI_DISABLE_CONNECTION_VERIFICATION=1
            $providerList = cmd /c az provider list
            $providerList = $providerList | ConvertFrom-Json
            $providerList | ForEach-Object { cmd /c az provider register --namespace $_.namespace }

            $sleepTime = 0        
            while($true)
            {
                $sleepTime += 10
                Start-Sleep -Seconds  10
                $requiredRPs = az provider list 
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
        cmd /c az storage account create --location $ResourceLocation --name $storageAccName --resource-group $CanaryUtilitiesRG --account-type Standard_LRS
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
        if (cmd /c az vm image list --location $ResourceLocation --publisher "MicrosoftWindowsServer" --offer "WindowsServer" --sku "2016-Datacenter-Core")
        {
            $osVersion = "2016-Datacenter-Core"
        }
        elseif (cmd /c az vm image list --location $ResourceLocation --publisher "MicrosoftWindowsServer" --offer "WindowsServer" --sku "2016-Datacenter")
        {
            $osVersion = "2016-Datacenter"
        }
        elseif (cmd /c az vm image list --location $ResourceLocation --publisher "MicrosoftWindowsServer" --offer "WindowsServer" --sku "2012-R2-Datacenter")
        {
            $osVersion = "2012-R2-Datacenter"
        } 
        $linuxImgExists = $false      
        if (cmd /c az vm image list --location $ResourceLocation --publisher "Canonical" --offer "UbuntuServer" --sku $LinuxOSSku)
        {
            $linuxImgExists = $true
        }

        $templateDeploymentName = "CanaryVMDeployment"

        if (-not $linuxImgExists)
        {
            $templateError = cmd /c az group deployment validate --resource-group $CanaryVMRG --template-file $PSScriptRoot\azuredeploy.CLI.json --verbose
        }
        elseif ($linuxImgExists) 
        {
            $templateError = cmd /c az group deployment validate --resource-group $CanaryVMRG --template-file $PSScriptRoot\azuredeploy.nolinux.CLI.json --verbose
        }
        $templateError = $false
        if ((-not $templateError) -and ($linuxImgExists))
        {
            cmd /c az group deployment create --name $templateDeploymentName --resource-group $CanaryVMRG --template-file $PSScriptRoot\azuredeploy.CLI.json --verbose
        }
        elseif (-not $templateError) {
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
        $vmList = cmd /c az vm list -g $CanaryVMRG -d 
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
        if (($pubVMObject = cmd /c az vm show -g $CanaryVMRG -d -n $publicVMName) -and ($pvtVMObject = cmd /c az vm list -g $CanaryVMRG -d -n $privateVMName))
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
                $deleteVM = az vm delete -g $CanaryVMRG -n $privateVMName --yes
                if (-not (($deleteVM.StatusCode -eq "OK") -and ($deleteVM.IsSuccessStatusCode)))
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
