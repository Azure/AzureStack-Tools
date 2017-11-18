# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

# Create log folder / prevent duplicate logs
if(-not $Global:AzureRegistrationLog)
{
    $LogFolder = "$env:SystemDrive\MASLogs"
    if (-not (Test-Path $LogFolder))
    {
        New-Item -Path $LogFolder -ItemType Directory -Force
    }
    $Global:AzureRegistrationLog = "$LogFolder\AzureStack.AzureRegistration.$(Get-Date -Format yyyy-MM-dd.hh-mm-ss).log"
    $null = New-Item -Path $Global:AzureRegistrationLog -ItemType File -Force
}

################################################################
# Core Functions
################################################################

<#
.SYNOPSIS

Add-AzsRegistration can be used to register Azure Stack with Azure. To run this function, you must have a public Azure subscription of any type.
You must also have access to an account that is an owner or contributor to that subscription.

.DESCRIPTION

Add-AzsRegistration runs scripts already present in Azure Stack from the ERCS VM to connect your Azure Stack to Azure.
After connecting with Azure, you can download products from the marketplace (See the documentation for more information: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-download-azure-marketplace-item).
Running this script with default parameters will enable marketplace syndication and usage data will default to being reported to Azure.
NOTE: Default billing model is 'Development' and is only usable for proof of concept builds.
To disable syndication or usage reporting see examples below.

This script will create the following resources by default:
- A service principal to perform resource actions
- A resource group in Azure (if needed)
- A registration resource in the created resource group in Azure
- A custom RBAC role for the resource in Azure
- An activation resource group and resource in Azure Stack

See documentation for more detail: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the JEA Computer (also known as Emergency Console) to call whitelisted cmdlets and scripts.
If not supplied script will request manual input of username and password

.PARAMETER AzureSubscriptionId

The subscription Id that will be used for marketplace syndication and usage. The Azure Account Id used during registration must have resource creation access to this subscription.

.PARAMETER AzureDirectoryTenantName

The Azure tenant directory where you would like your registration resource in Azure to be created.

.PARAMETER PrivilegedEndpoint

Just-Enough-Access Computer Name, also known as Emergency Console VM.(Example: AzS-ERCS01 for the ASDK)

.PARAMETER ResourceGroupName

This will be the name of the resource group in Azure where the registration resource is stored. Defaults to "azurestack"

.PARAMETER  ResourceGroupLocation

The location where the resource group will be created. Defaults to "westcentralus"

.PARAMETER RegistrationName

The name of the registration resource that will be created in Azure. If none is supplied, defaults to "AzureStack-<CloudId>" where <CloudId> is the CloudId associated with the Azure Stack environment

.PARAMETER AzureEnvironmentName

The name of the Azure Environment where resources will be created. Defaults to "AzureCloud"

.PARAMETER BillingModel

The billing model that the subscription uses. Select from "Capacity","PayAsYouUse", and "Development". Defaults to "Development" which is usable for POC installments.
Please see documentation for more information: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-billing-and-chargeback

.PARAMETER MarketplaceSyndicationEnabled

This is a switch that determines if this registration will allow you to download products from the Azure Marketplace. Defaults to $true

.PARAMETER UsageReportingEnabled

This is a switch that determines if usage records are reported to Azure. Defaults to $true. Note: This cannot be disabled with billing model set to PayAsYouUse.

.PARAMETER AgreementNumber

Used when the billing model is set to capacity. If this is the case you will need to provide a specific agreement number associated with your billing agreement.

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication, and enables usage reporting to Azure.

Add-AzsRegistration -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -AzureDirectoryTenantName "contoso.onmicrosoft.com" -PrivilegedEndpoint "Azs-ERCS01"

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication, and disables usage reporting to Azure. 

Add-AzsRegistration -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -AzureDirectoryTenantName "contoso.onmicrosoft.com"  -PrivilegedEndpoint "Azs-ERCS01" -BillingMode 'Capacity' -UsageReportingEnabled:$false -AgreementNumber $MyAgreementNumber

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication and usage and gives a specific name to the resource group and registration resource. 

Add-AzsRegistration -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -AzureDirectoryTenantName "contoso.onmicrosoft.com"  -PrivilegedEndpoint "Azs-ERCS02" -ResourceGroupName "ContosoStackRegistrations" -RegistrationName "ContosoRegistration"

.EXAMPLE

This example disables syndication and disables usage reporting to Azure. Note that usage will still be collected, just not sent to Azure.

Add-AzsRegistration -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -AzureDirectoryTenantName "contoso.onmicrosoft.com"  -PrivilegedEndpoint "Azs-ERCS01" -BillingModel Development -MarketplaceSyndicationEnabled:$false -UsageReportingEnabled:$false

.NOTES

If you would like to un-Register with you Azure by turning off marketplace syndication, disabling usage reporting, and removing the registration resource from Azure you can run Remove-AzsRegistration.

If you would like to use a different subscription for registration you can run Set-AzsRegistrationSubscription

#>

Function Add-AzsRegistration{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $AzureSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $AzureEnvironmentName = 'AzureCloud',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development')]
        [string] $BillingModel = 'Development',

        [Parameter(Mandatory=$false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory=$false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string] $AgreementNumber
    )

    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin Log: Add-AzsRegistration  ***********************`r`n"
    Log-Output "This script will connect your Azure Stack with Azure, allowing for usage data to be sent and items to be downloaded from the marketplace."

    $params = @{}
    $PSCmdlet.MyInvocation.BoundParameters.Keys.ForEach({if(($value=Get-Variable -Name $_ -ValueOnly -ErrorAction Ignore)){$params[$_]=$value}})
    Log-Output "Add-AzsRegistration params: `r`n $(ConvertTo-Json $params)"

    RegistrationWorker @params

    Log-Output "*********************** End log: Add-AzsRegistration ***********************`r`n`r`n"
}

<#

.SYNOPSIS

Sets current registration parameters MarketplaceSyndicationEnabled and EnableUsageReporting to $false, then removes registration resource from Azure.

.DESCRIPTION

If no registration resource name is supplied then then this script will use this environments CloudId to search for a registration resource and remove it from Azure.
If a RegistrationName and ResourceGroupName are supplied this script will remove the specified registration resource from Azure.

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the JEA Computer (also known as Emergency Console) to call whitelisted cmdlets and scripts.
If not supplied script will request manual input of username and password.

.PARAMETER AzureSubscriptionId

The subscription Id that was previously used to register this Azure Stack environment with Azure.

.PARAMETER AzureDirectoryTenantName

The Azure tenant directory previously used to register this Azure Stack environment with Azure.

.PARAMETER PrivilegedEndpoint

Just-Enough-Access Computer Name, also known as Emergency Console VM.(Example: AzS-ERCS01 for the ASDK).

.PARAMETER ResourceGroupName

This is the name of the resource group in Azure where the previous registration resource was stored. Defaults to "azurestack"

.PARAMETER RegistrationName

This is the name of the previous registration resource that was created in Azure. This resource will be removed. Defaults to "AzureStack-<CloudId>"

.PARAMETER AzureEnvironmentName

The name of the Azure Environment where registration resources have been created. Defaults to "AzureCloud"

.EXAMPLE

This example removes a registration resource in Azure that was created from a prior successful run of Add-AzsRegistration and uses defaults for RegistrationName and ResourceGroupName.

Remove-AzsRegistration -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $AzureSubscriptionId -AzureDirectoryTenantName 'contoso.onmicrosoft.com' -PrivilegedEndpoint $PrivilegedEndpoint

.NOTES

This will always set syndication and usage reporting to false as well as remove the provided registration resource from Azure. 

#>

function Remove-AzsRegistration{
[CmdletBinding()]
    param(

        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $AzureSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $AzureEnvironmentName = 'AzureCloud',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development')]
        [string] $BillingModel = 'Development',

        [Parameter(Mandatory=$false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory=$false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string] $AgreementNumber
    )

    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"}
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: Remove-AzsRegistration ***********************`r`n"
    Log-Output "This script will disable syndication and remove the registration resource in Azure. If no registration name is input, it will default to the resource associated with this environment."    

    $params = @{}
    $PSCmdlet.MyInvocation.BoundParameters.Keys.ForEach({if(($value=Get-Variable -Name $_ -ValueOnly -ErrorAction Ignore)){$params[$_]=$value}})
    $params['MarketplaceSyndicationEnabled'] = $false
    if (($params['BillingModel'] -eq 'Development') -or ($params['BillingModel'] -eq 'Capacity'))
    {
        $params['UsageReportingEnabled'] = $false
    }
    Log-Output "Remove-AzsRegistration params: `r`n $(ConvertTo-Json $params)"
    $RegistrationName = RegistrationWorker @params -ReturnRegistrationName

    $currentAttempt = 0
    $maxAttempts = 3
    $sleepSeconds = 10
    do {
        try{            
            $azureResource = Find-AzureRmResource -ResourceType "Microsoft.AzureStack/registrations" -ResourceGroupNameContains $ResourceGroupName -ResourceNameContains $RegistrationName
            if ($azureResource)
            {
                Log-Output "Found registration resource in azure: $(ConvertTo-Json $azureResource)"
                Log-Output "Removing resource $($azureresource.Name) from Azure"
                Remove-AzureRmResource -ResourceName $azureResource.Name -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.AzureStack/registrations" -Force -Verbose                
                Log-Output "Cleanup successful. Registration resource removed from Azure"         
                break
            }
            else
            {
                Log-Warning "Resource not found in Azure, registration may have failed or it may be under another subscription. Cancelling cleanup."
                break
            }
        }
        Catch
        {
            $exceptionMessage = $_.Exception.Message
            Log-Warning "Failed while removing resource from Azure: `r`n$exceptionMessage"
            Log-Output "Waiting $sleepSeconds seconds and trying again... attempt $currentAttempt of $maxAttempts"
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempts)
            {
                Log-Throw -Message "Failed to remove resource from Azure on final attempt: `r`n$exceptionMessage" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
            }
        }
    }while ($currentAttempt -le $maxAttempts)
    Log-Output "*********************** End log: Remove-AzsRegistration ***********************`r`n`r`n"
}

<#

.SYNOPSIS

Set-AzsRegistrationSubscription calls Remove-AzsRegistration on the current registration resource and then calls Add-AzsRegistration with the new parameters

.DESCRIPTION

Set-AzsRegistrationSubsription requires the parameters for the current registration as well as parameters for a new registration resource. The function 
attempts to add the custom RBAC role created during Add-AzsRegistration to the new subscription passed in. If not possible the function will continue as normal.
Set-AzsRegistrationSubscription will call Remove-AzsRegistration on the current registration resource and then pass the new subscription Id and new 
Azure directory tenant name into Add-AzsRegistration.

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the JEA Computer (also known as Emergency Console) to call whitelisted cmdlets and scripts.
If not supplied script will request manual input of username and password.

.PARAMETER CurrentAzureSubscriptionId

The subscription Id that was previously used to register this Azure Stack environment with Azure.

.PARAMETER AzureDirectoryTenantName

The Azure tenant directory previously used to register this Azure Stack environment with Azure.

.PARAMETER NewAzureSubscriptionId

The subscription Id you would like to change your registration to.

.PARAMETER PrivilegedEndpoint

Just-Enough-Access Computer Name, also known as Emergency Console VM.(Example: AzS-ERCS01 for the ASDK).

.PARAMETER NewAzureDirectoryTenantName

The new Azure tenant directory you would like used during registration. This can be the same as the previous tenant name.

.PARAMETER ResourceGroupName

This is the name of the resource group in Azure where the previous registration resource was stored. Defaults to "azurestack"

.PARAMETER RegistrationName

This is the name of the previous registration resource that was created in Azure. This resource will be removed. Defaults to "AzureStack-<CloudId>"

.PARAMETER AzureEnvironmentName

The name of the Azure Environment where registration resources have been created. Defaults to "AzureCloud"

.EXAMPLE

Set-AzsRegistrationSubscription -CloudAdminCredential $CloudAdminCredential -CurrentAzureSubscriptionId $CurrentSubscriptionId -AzureDirectoryTenantName 'contoso.onmicrosoft.com' -NewAzureSubscriptionId $NewAzureSubscriptionId `
-PrivilegedEndpoint <Prefix>-ERCS01 -NewAzureDirectoryTenantname 'microsoft.onmicrosoft.com'

.NOTES

If you would like to register with a different resource group, resource name, or resource group location you cannot currently use Set-AzsRegistrationSubsription for that. 
To do so you should call Remove-AzsRegistration followed by Add-AzsRegistration with the new parameters you would like. 

#>

function Set-AzsRegistrationSubscription{
[CmdletBinding()]
    param(

        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $CurrentAzureSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [String] $NewAzureSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [String] $NewAzureDirectoryTenantName,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $AzureEnvironmentName = 'AzureCloud',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development')]
        [string] $BillingModel = 'Development',

        [Parameter(Mandatory=$false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory=$false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string] $AgreementNumber        
    )

    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: Set-AzsRegistrationSubscription ***********************`r`n"

    Log-Output "Logging in to Azure."
    $connection = Connect-AzureAccount -SubscriptionId $CurrentAzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -AzureDirectoryTenantName $AzureDirectoryTenantName -Verbose
    
    $params = @{}
    $PSCmdlet.MyInvocation.BoundParameters.Keys.ForEach({if(($value=Get-Variable -Name $_ -ValueOnly -ErrorAction Ignore)){$params[$_]=$value}})    
    $params.Add('AzureSubscriptionId',$CurrentAzureSubscriptionId)    
    $params.Remove('NewAzureDirectoryTenantName')
    $params.Remove('NewAzureSubscriptionId')
    $params.Remove('CurrentAzureSubscriptionId')
    Log-Output "Remove-AzsRegistration params: `r`n $(ConvertTo-Json $params)"
    Remove-AzSRegistration @params
    $params["AzureSubscriptionId"] = $NewAzureSubscriptionId
    $params["AzureDirectoryTenantName"] = $NewAzureDirectoryTenantName
    Log-Output "Add-AzsRegistration params: `r`n $(ConvertTo-Json $params)"
    RegistrationWorker @params

    Log-Output "*********************** End log: Set-AzsRegistrationSubscription ***********************`r`n`r`n"
}

################################################################
# Helper Functions
################################################################

<#

.SYNOPSIS

Performs critical registration actions

#>
function RegistrationWorker{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $AzureSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,        

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $AzureEnvironmentName = 'AzureCloud',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development')]
        [string] $BillingModel = 'Development',

        [Parameter(Mandatory=$false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory=$false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string] $AgreementNumber,

        [Parameter(Mandatory=$false)]
        [Switch] $ReturnRegistrationName
    )    

    #
    # Pre-registration setup
    #    

    Log-Output "Logging in to Azure."
    $connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -AzureDirectoryTenantName $AzureDirectoryTenantName -Verbose
    $session = Initialize-PrivilegedJeaSession -PrivilegedEndpoint $PrivilegedEndpoint -CloudAdminCredential $CloudAdminCredential -Verbose
    $stampInfo = Confirm-StampVersion -PSSession $session
    $tenantId = $connection.TenantId    
    $refreshToken = $connection.Token.RefreshToken
    $sleepSeconds = 10    
    $maxAttempts = 3

    Log-Output -Message "Running registration on build $($stampInfo.StampVersion). Cloud Id: $($stampInfo.CloudID), Deployment Id: $($stampInfo.DeploymentID)"

    #
    # Register with Azure
    #

    try
    {
        #
        # Create service principal in Azure
        #

        $currentAttempt = 0
        do
        {
            try
            {
                Log-Output "Creating Azure Active Directory service principal in tenant: $tenantId. Attempt $currentAttempt of $maxAttempts"
                $servicePrincipal = Invoke-Command -Session $session -ScriptBlock { New-AzureBridgeServicePrincipal -RefreshToken $using:refreshToken -AzureEnvironment $using:AzureEnvironmentName -TenantId $using:tenantId }
                break
            }
            catch
            {
                Log-Warning "Creation of service principal failed:`r`n$($_.Exception.Message)"
                Log-Output "Waiting $sleepSeconds seconds and trying again..."
                $currentAttempt++
                Start-Sleep -Seconds $sleepSeconds
                if ($currentAttempt -ge $maxAttempts)
                {
                    Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.InvocationName
                }
            }
        }while ($currentAttempt -lt $maxAttempts)

        #
        # Create registration token
        #

        $currentAttempt = 0
        do
        {
            try
            {
                Log-Output "Creating registration token. Attempt $currentAttempt of $maxAttempts"
                $registrationToken = Invoke-Command -Session $session -ScriptBlock { New-RegistrationToken -BillingModel $using:BillingModel -MarketplaceSyndicationEnabled:$using:MarketplaceSyndicationEnabled -UsageReportingEnabled:$using:UsageReportingEnabled -AgreementNumber $using:AgreementNumber }
                break
            }
            catch
            {
                Log-Warning "Creation of registration token failed:`r`n$($_.Exception.Message)"
                Log-Output "Waiting $sleepSeconds seconds and trying again..."
                $currentAttempt++
                Start-Sleep -Seconds $sleepSeconds
                if ($currentAttempt -ge $maxAttempts)
                {
                    Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.InvocationName
                }
            }
        }while ($currentAttempt -lt $maxAttempts)

        #
        # Create Azure resources
        #

        Log-Output "Creating resource group '$ResourceGroupName' in location $ResourceGroupLocation."
        $resourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force

        Log-Output "Registering Azure Stack resource provider."
        [Version]$azurePSVersion = (Get-Module AzureRm.Resources).Version
        if ($azurePSVersion -ge [Version]"4.3.2")
        {
            Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.AzureStack" | Out-Null
        }
        else
        {
            Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.AzureStack" -Force | Out-Null
        }

        $RegistrationName = if ($RegistrationName) { $RegistrationName } else { "AzureStack-$($stampInfo.CloudID)" }

        Log-Output "Creating registration resource '$RegistrationName'."
        $resourceCreationParams = @{
            ResourceGroupName = $ResourceGroupName
            Location          = 'Global'
            ResourceName      = $RegistrationName
            ResourceType      = "Microsoft.AzureStack/registrations"
            ApiVersion        = "2017-06-01" 
            Properties        = @{ registrationToken = "$registrationToken" }
        }

        $registrationResource = New-AzureRmResource @resourceCreationParams -Force

        Log-Output "Registration resource: $(ConvertTo-Json $registrationResource)"

        Log-Output "Retrieving activation key."
        $resourceActionparams = @{
            Action            = "GetActivationKey"
            ResourceName      = $RegistrationName
            ResourceType      = "Microsoft.AzureStack/registrations"
            ResourceGroupName = $ResourceGroupName
            ApiVersion        = "2017-06-01"
        }

        $actionResponse = Invoke-AzureRmResourceAction @resourceActionparams -Force

        #
        # Set RBAC role on registration resource
        #

        New-RBACAssignment -RegistrationResource $registrationResource -ServicePrincipalObjectId $servicePrincipal.ObjectId

        #
        # Activate Azure Stack
        #

        Log-Output "Activating Azure Stack (this may take up to 10 minutes to complete)." 
        $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:actionResponse.ActivationKey }
        Log-Output "Azure Stack registration and activation completed successfully. Logs can be found at: $Global:AzureRegistrationLog  and  \\$PrivilegedEndpoint\c$\maslogs"
    }
    finally
    {
        $session | Remove-PSSession
    }

    if ($ReturnRegistrationName)
    {
        return $RegistrationName
    }
}

<#

.SYNOPSIS

Adds the provided subscription id to the custom RBAC role 'Registration Reader'

#>

function New-RBACAssignment{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Object] $RegistrationResource,

        [Parameter(Mandatory = $true)]
        [String] $ServicePrincipalObjectId
    )

    Log-Output "Setting Registration Reader role on '$($RegistrationResource.ResourceId)' for service principal $ServicePrincipalObjectId."
    $roleAssigned = $false
    $roleName = "Azure Stack Registration Owner"

    # Determine if Azure Stack Registration Owner RBAC role has been assigned
    $roleAssignmentScope = "/subscriptions/$($RegistrationResource.SubscriptionId)/resourceGroups/$($RegistrationResource.ResourceGroupName)/providers/Microsoft.AzureStack/registrations/$($RegistrationResource.ResourceName)"
    $roleAssignments = Get-AzureRmRoleAssignment -Scope $roleAssignmentScope -ObjectId $ServicePrincipalObjectId -ErrorAction SilentlyContinue

    foreach ($role in $roleAssignments)
    {
        if ($role.RoleDefinitionName -eq $roleName)
        {
            $roleAssigned = $true
        }
    }

    if (-not $roleAssigned)
    {        
        New-AzureRmRoleAssignment -Scope $roleAssignmentScope -RoleDefinitionName $roleName -ObjectId $ServicePrincipalObjectId        
    }
}

<#

.SYNOPSIS

Determines if a new Azure connection is required.

.DESCRIPTION

If the current powershell environment is not currently logged in to an Azure Account or is calling Add-AzsRegistration
with a subscription id that does not match one available under the current context then Connect-AzureAccount will prompt the user to log in
to the correct account. 

#>
function Connect-AzureAccount{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory = $true)]
        [string]$AzureEnvironmentName
    )

    $isConnected = $false;

    try
    {
        $AzureDirectoryTenantId = Get-TenantIdFromName -AzureEnvironment $AzureEnvironmentName -TenantName $AzureDirectoryTenantName
        Set-AzureRmContext -SubscriptionId $SubscriptionId -TenantId $AzureDirectoryTenantId
        $context = Get-AzureRmContext
        $environment = Get-AzureRmEnvironment -Name $AzureEnvironmentName
        $subscription = Get-AzureRmSubscription -SubscriptionId $SubscriptionId
        $context.Environment = $environment
        if ($context.Subscription.SubscriptionId -eq $SubscriptionId)
        {
            $isConnected = $true;
        }
    }
    catch
    {
        Log-Warning "Not currently connected to Azure: `r`n$($_.Exception)"
    }
    
    if (-not $isConnected)
    {
        try
        {
            Add-AzureRmAccount -SubscriptionId $SubscriptionId       
            Set-AzureRmContext -SubscriptionId $SubscriptionId -TenantId $AzureDirectoryTenantId
            $environment = Get-AzureRmEnvironment -Name $AzureEnvironmentName
            $subscription = Get-AzureRmSubscription -SubscriptionId $SubscriptionId
            $context = Get-AzureRmContext
        }
        catch
        {
            Log-Throw "Unable to connect to Azure: `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
        }
    }
    else
    {
        Log-Output "Currently connected to Azure."
    }


    $tokens = @()
    try{$tokens += [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache.ReadItems()}catch{}
    try{$tokens += [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()}catch{}
    try{$tokens += $context.TokenCache.ReadItems()}catch{}

    if (-not $tokens -or ($tokens.Count -le 0))
    {
        Log-Throw -Message "Token cache is empty `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
    }

    $token = $tokens |
        Where Resource -EQ $environment.ActiveDirectoryServiceEndpointResourceId |
        Where { $_.TenantId -eq $subscription.TenantId } |
        Sort ExpiresOn |
        Select -Last 1


    if (-not $token)
    {
        Log-Throw -Message "Token not found for tenant id $($subscription.TenantId) and resource $($environment.ActiveDirectoryServiceEndpointResourceId)." -CallingFunction $PSCmdlet.MyInvocation.InvocationName
    }

    Log-Output "Current Azure Context: `r`n $(ConvertTo-Json $context)"
    return @{
        TenantId = $subscription.TenantId
        ManagementEndpoint = $environment.ResourceManagerUrl
        ManagementResourceId = $environment.ActiveDirectoryServiceEndpointResourceId
        Token = $token
    }
}

<#

.SYNOPSIS

Creates a powershell session with the PrivilegedEndpoint for registration actions

#>
function Initialize-PrivilegedJeaSession{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [String] $PrivilegedEndpoint,

    [Parameter(Mandatory=$true)]
    [PSCredential] $CloudAdminCredential
)
    $currentAttempt = 0
    $maxAttempts = 3
    $sleepSeconds = 10
    do
    {
        try
        {
            Log-Output "Initializing privileged JEA session with $PrivilegedEndpoint. Attempt $currentAttempt of $maxAttempts"
            $session = New-PSSession -ComputerName $PrivilegedEndpoint -ConfigurationName PrivilegedEndpoint -Credential $CloudAdminCredential
            Log-Output "Connection to $PrivilegedEndpoint successful"
            return $session
        }
        catch
        {
            Log-Warning "Creation of session with $PrivilegedEndpoint failed:`r`n$($_.Exception.Message)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempts)
            {
                Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.InvocationName
            }
        }
    }while ($currentAttempt -lt $maxAttempts)
}

<#

.SYNOPSIS

Uses the current session with the PrivilegedEndpoint to determine the version of Azure Stack that has been deployed

#>
function Confirm-StampVersion{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [System.Management.Automation.Runspaces.PSSession] $PSSession
)
    try
    {
        Log-Output "Verifying stamp version."
        $stampInfo = Invoke-Command -Session $PSSession -ScriptBlock { Get-AzureStackStampInformation -WarningAction SilentlyContinue }
        $minVersion = [Version]"1.0.170626.1"
        if ([Version]$stampInfo.StampVersion -lt $minVersion) {
            Log-Throw -Message "Script only applicable for Azure Stack builds $minVersion or later." -CallingFunction $PSCmdlet.MyInvocation.InvocationName
        }
        return $stampInfo
    }
    Catch
    {
        Log-Throw "An error occurred checking stamp information: `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
    }
}

<#
.SYNOPSIS
    Returns Azure AD directory tenant ID given the login endpoint and the directory tenant name
.DESCRIPTION
    Makes an unauthenticated REST call to the given Azure environment's login endpoint to retrieve directory tenant id
.EXAMPLE
  $tenantId = Get-TenantIdFromName -azureEnvironment "Public Azure" -tenantName "msazurestack.onmicrosoft.com"
#>
function Get-TenantIdFromName
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $azureEnvironment,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $tenantName
    )

    $azureURIs = Get-AzureURIs -AzureEnvironment $AzureEnvironment

    $uri = "{0}/{1}/.well-known/openid-configuration" -f ($azureURIs.LoginUri).TrimEnd('/'), $tenantName

    $response = Invoke-RestMethod -Uri $uri -Method Get -Verbose

    $tenantId = $response.token_endpoint.Split('/')[3]
 
    $tenantIdGuid = [guid]::NewGuid()
    $result = [guid]::TryParse($tenantId, [ref] $tenantIdGuid)

    if(-not $result)
    {
        Log-Throw -Message "Error obtaining tenant id from tenant name $tenantName `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
    }
    else
    {
        Log-Output "Tenant Name: $tenantName Tenant id: $tenantId" -Verbose
        return $tenantId
    }
}

<#
.SYNOPSIS

Returns the common AzureURIs associated with the provided AzureEnvironmentName

#>
function Get-AzureURIs
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $AzureEnvironment
    )

    if ($AzureEnvironment -eq "AzureChinaCloud")
    {
        return @{
                    GraphUri = "https://graph.chinacloudapi.cn/"
                    LoginUri = "https://login.chinacloudapi.cn/"
                    ManagementServiceUri = "https://management.core.chinacloudapi.cn/"
                    ARMUri = "https://management.chinacloudapi.cn/"
                }
    }
    elseif ($AzureEnvironment -eq "AzureGermanCloud")
    {
        return @{
                    GraphUri = "https://graph.cloudapi.de/"
                    LoginUri = "https://login.microsoftonline.de/"
                    ManagementServiceUri = "https://management.core.cloudapi.de/"
                    ARMUri = "https://management.microsoftazure.de/"
                }
    }
    else
    {
        return @{
                    GraphUri = "https://graph.windows.net/"
                    LoginUri = "https://login.windows.net/"
                    ManagementServiceUri = "https://management.core.windows.net/"
                    ARMUri = "https://management.azure.com/"
                }
    }
}

<#

.SYNOPSIS

Appends the text passed in to a log file and writes the verbose stream to the console.

#>
function Log-Output
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [object] $Message
    )    

    "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message" | Out-File $Global:AzureRegistrationLog -Append
    Write-Verbose "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message"
}

<#

.SYNOPSIS

Appends the error text passed in to a log file and writes the a warning verbose stream to the console.

#>
function Log-Warning
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [object] $Message
    )    

    # Write Error: line seperately otherwise out message will not contain stack trace
    "`r`n *** WARNING ***" | Out-File $Global:AzureRegistrationLog -Append
    "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message" | Out-File $Global:AzureRegistrationLog -Append
    "*** End WARNING ***" | Out-File $Global:AzureRegistrationLog -Append
    Write-Warning "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message"
}

<#

.SYNOPSIS

Appends the error text passed in to a log file throws an exception.

#>
function Log-Throw
{
    param(
        [Parameter(Mandatory=$true)]
        [Object] $Message,

        [Parameter(Mandatory=$true)]
        [String] $CallingFunction
    )

    # Write Error: line seperately otherwise out message will not contain stack trace
    "`r`n**************************** Error ****************************" | Out-File $Global:AzureRegistrationLog -Append
    "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message" | Out-File $Global:AzureRegistrationLog -Append
    "***************************************************************`r`n" | Out-File $Global:AzureRegistrationLog -Append
    Log-Output "*********************** Ending registration action during $CallingFunction ***********************`r`n`r`n"

    throw "Logs can be found at: $Global:AzureRegistrationLog  and  \\$PrivilegedEndpoint\c$\maslogs `r`n$Message"
}

Export-ModuleMember Add-AzsRegistration
Export-ModuleMember Remove-AzsRegistration
Export-ModuleMember Set-AzsRegistrationSubscription
