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

This script can be used to register Azure Stack with Azure. To run this script, you must have a public Azure subscription of any type.
You must also have access to an account that is an owner or contributor to that subscription.

.DESCRIPTION

RegisterWithAzure runs scripts already present in Azure Stack from the ERCS VM to connect your Azure Stack to Azure.
After connecting with Azure, you can download products from the marketplace (See the documentation for more information: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-download-azure-marketplace-item).
Running this script with default parameters will enable marketplace syndication and usage data will default to being reported to Azure.
To turn these features off see examples below.

This script will create the following resources by default:
- A service principal to perform resource actions
- A resource group in Azure (if needed)
- A registration resource in the created resource group in Azure
- An activation resource group and resource in Azure Stack

See documentation for more detail: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the JEA Computer (also known as Emergency Console) to call whitelisted cmdlets and scripts.
If not supplied script will request manual input of username and password

.PARAMETER AzureSubscriptionId

The subscription Id that will be used for marketplace syndication and usage. The Azure Account Id used during registration must have resource creation access to this subscription.

.PARAMETER JeaComputerName

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

The billing model that the subscription uses. Select from "Capacity","PayAsYouUse", and "Development". Defaults to "Development". Please see documentation for more information: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-billing-and-chargeback

.PARAMETER MarketplaceSyndicationEnabled

This is a switch that determines if this registration will allow you to download products from the Azure Marketplace. Defaults to $true

.PARAMETER UsageReportingEnabled

This is a switch that determines if usage records are reported to Azure. Defaults to $true

.PARAMETER AgreementNumber

Used when the billing model is set to capacity. If this is the case you will need to provide a specific agreement number associated with your billing agreement.

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication, and enables usage reporting to Azure.

.\RegisterWithAzure.ps1 -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -JeaComputername "Azs-ERCS01"

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication, and disables usage reporting to Azure. 

.\RegisterWithAzure.ps1 -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -JeaComputername "Azs-ERC01" -UsageReportingEnabled:$false

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication and usage and gives a specific name to the resource group and registration resource. 

.\RegisterWithAzure.ps1 -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -JeaComputername "<PreFix>-ERCS01" -ResourceGroupName "ContosoStackRegistrations" -RegistrationName "Registration01"

.EXAMPLE

This example un-registers by disabling syndication and stopping usage sent to Azure. Note that usage will still be collected, just not sent to Azure.

.\RegisterWithAzure.ps1 -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -JeaComputername "<Prefix>-ERC01" -MarketplaceSyndicationEnabled:$false -UsageReportingEnabled:$false

.NOTES

If you would like to un-Register with you Azure by turning off marketplace syndication and usage reporting you can run this script again with both enableSyndication and reportUsage set to false.
This will unconfigure usage bridge so that syndication isn't possible and usage data is not reported. This is only possible with billing model of Development or Capacity. 

If you would like to use a different subscription for registration there are two functions to be run before re-registering: 
- Add-RegistrationRoleAssignment: Use this function If your next subscription Id is under the same account as the current registration
- Remove-RegistrationResource: Use this function if your next subscription Id is under a different account than the current registration

Once you have run the appropriate function you can call RegisterWithAzure again to re-register. 

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
        [String] $JeaComputerName,

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

Removes a registration resource from Azure

.DESCRIPTION

If no registration resource name is supplied then then this script will use this environments CloudId to search for a registration resource and remove it from Azure.
If a RegistrationName and ResourceGroupName are supplied this script will remove the specified registration resource from Azure. This will disable marketplace syndication
and allow you to run RegisterWithAzure with a different subscription Id. Note: If the provided subscription for a subsequent RegisterWithAzure is under the same Azure Account
as the previous registration you MUST run Add-RegistrationRoleAssignment before attempting RegisterWithAzure.

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the JEA Computer (also known as Emergency Console) to call whitelisted cmdlets and scripts.
If not supplied script will request manual input of username and password.

.PARAMETER AzureSubscriptionId

The subscription Id that was previously used to register this Azure Stack environment with Azure.

.PARAMETER JeaComputerName

Just-Enough-Access Computer Name, also known as Emergency Console VM.(Example: AzS-ERCS01 for the ASDK).

.PARAMETER ResourceGroupName

This is the name of the resource group in Azure where the previous registration resource was stored. Defaults to "azurestack"

.PARAMETER RegistrationName

This is the name of the previous registration resource that was created in Azure. This resource will be removed Defaults to "AzureStack-<CloudId>"

.PARAMETER AzureEnvironmentName

The name of the Azure Environment where registration resources have been created. Defaults to "AzureCloud"

.EXAMPLE

This example removes a registration resource in Azure that was created from a prior successful run of RegisterWithAzure and uses defaults for RegistrationName and ResourceGroupName.

Remove-RegistrationResource -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $AzureSubscriptionId -JeaComputerName $JeaComputerName

.NOTES

This script should be used in conjuction with running RegisterWithAzure to disable marketplace syndication and usage reporting (if able). If after running this script
you attempt to re-register with a different subscription Id that is under the same account as the previous registration you will recieve an error related to the custom 
RBAC role for registration resources. To fix this, please run Add-RegistrationRoleAssignment to re-register with a subscription under the previously registered account. 

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
        [String] $JeaComputerName,

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

This script is used to prepare the current environment for registering with a new subscription Id under the same account.

.DESCRIPTION

Add-RegistrationRoleAssignment will add the provided alternate subscription Id to the list of assignable scopes for the custom RBAC role that is defined  and assigned to registration resources.
This RBAC role is created / assigned during the RegisterWithAzure function.

.PARAMETER AzureSubscriptionId

The subscription Id that was previously used to register this Azure Stack environment with Azure.

.PARAMETER AlternateSubscriptionId

The new subscription Id that this environment will be registered to in Azure.

.PARAMETER AzureEnvironmentName

The name of the Azure Environment where registration resources have been created. Defaults to "AzureCloud"

.EXAMPLE

Add-RegistrationRoleAssignment -AzureSubscriptionId $CurrentRegisteredSubscription -AlternateSubscriptionId $FutureRegisteredSubscription

.NOTES

This function should only be used if you have a currently registered environment and would like to switch the subscription used to register to a different subscription 
that is under the same account. If you would like to register to a subscription Id that is under a separate account then you must use Remove-RegistrationResource before
calling RegisterWithAzure again.

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
        [String] $JeaComputerName,

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

    $role = Get-AzureRmRoleDefinition -Name 'Registration Reader'
    if($role)
    {
        if(-not($role.AssignableScopes -icontains "/subscriptions/$NewAzureSubscriptionId"))
        {
            try
            {
                Log-Output "Adding alternate subscription Id to scope of custom RBAC role"
                $role.AssignableScopes.Add("/subscriptions/$NewAzureSubscriptionId")
                Set-AzureRmRoleDefinition -Role $role
            }
            catch
            {
                if($_.Exception -ilike "*LinkedAuthorizationFailed:*")
                {
                    Log-Warning "Unable to add the new subscription: $NewAzureSubscriptionId  to the scope of existing RBAC role definition. Continuing with transfer of registration"
                }
                else
                {
                    Log-Throw "Unable to swap to the provided NewAzureSubscriptionId $NewAzureSubscriptionId `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
                }
            }
        }
        else
        {
            Log-Output "The provided subscription is already in the assignable scopes of RBAC role 'Registration Reader'. Continuing with transfer of registration."
        }
    }
    else
    {
        Log-Throw -Message "The 'Registration Reader' custom RBAC role has not been defined. Please run Add-AzsRegistration to ensure it is created." -CallingFunction $PSCmdlet.MyInvocation.InvocationName
    }
    
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
        [String] $JeaComputerName,        

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

    Resolve-DomainAdminStatus -Verbose
    Log-Output "Logging in to Azure."
    $connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -AzureDirectoryTenantName $AzureDirectoryTenantName -Verbose
    $session = Initialize-PrivilegedJeaSession -JeaComputerName $JeaComputerName -CloudAdminCredential $CloudAdminCredential -Verbose
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
            Location          = $ResourceGroupLocation
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
        Log-Output "Azure Stack registration and activation completed successfully. Logs can be found at: $Global:AzureRegistrationLog  and  \\$JeaComputerName\c$\maslogs"
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
    $customRoleAssigned = $false
    $customRoleName = "Registration Reader"

    # Determine if the custom RBAC role has been defined
    $customRoleDefined = Get-AzureRmRoleDefinition -Name $customRoleName
    if (-not $customRoleDefined)
    {
        # Create new RBAC role definition
        $role = Get-AzureRmRoleDefinition -Name 'Reader'
        $role.Name = $customRoleName
        $role.id = [guid]::newguid()
        $role.IsCustom = $true
        $role.Actions.Add('Microsoft.AzureStack/registrations/products/listDetails/action')
        $role.Actions.Add('Microsoft.AzureStack/registrations/products/read')
        $role.AssignableScopes.Clear()
        $role.AssignableScopes.Add("/subscriptions/$($RegistrationResource.SubscriptionId)")
        $role.Description = "Custom RBAC role for registration actions such as downloading products from Azure marketplace"
        try
        {
            New-AzureRmRoleDefinition -Role $role
        }
        catch
        {
            Log-Throw -Message "Defining custom RBAC role $customRoleName failed: `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
        }
    }

    # Determine if custom RBAC role has been assigned
    $roleAssignmentScope = "/subscriptions/$($RegistrationResource.SubscriptionId)/resourceGroups/$($RegistrationResource.ResourceGroupName)/providers/Microsoft.AzureStack/registrations/$($RegistrationResource.ResourceName)"
    $roleAssignments = Get-AzureRmRoleAssignment -Scope $roleAssignmentScope -ObjectId $ServicePrincipalObjectId -ErrorAction SilentlyContinue

    foreach ($role in $roleAssignments)
    {
        if ($role.RoleDefinitionName -eq $customRoleName)
        {
            $customRoleAssigned = $true
        }
    }

    if (-not $customRoleAssigned)
    {        
        New-AzureRmRoleAssignment -Scope $roleAssignmentScope -RoleDefinitionName $customRoleName -ObjectId $ServicePrincipalObjectId        
    }
}

<#

.SYNOPSIS

Determines if a new Azure connection is required.

.DESCRIPTION

If the current powershell environment is not currently logged in to an Azure Account or is calling either RegisterWithAzure or
Initialize-AlternateRegistration with a subscription id that does not match the current environment's subscription then Connect-AzureAccount will prompt the user to log in
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


    [Version]$azurePSVersion = (Get-Module AzureRm.Profile).Version
    Log-Output "Using AzureRm.Profile version: $azurePSVersion"

    if ($azurePSVersion -ge [Version]"3.3.2")
    {
        $tokens = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache.ReadItems()
        if (-not $tokens -or ($tokens.Count -le 0))
        {
            $tokens = $context.TokenCache.ReadItems()

            if (-not $tokens -or ($tokens.Count -le 0))
            {
                Log-Throw -Message "Token cache is empty `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
            }
            else
            {
                $token = $tokens[0]
            }
        }
        else
        {
            $token = $tokens[0]
        }
    }
    else
    {
        $tokens = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()
        if (-not $tokens -or ($tokens.Count -le 0))
        {            
            if (-not $tokens -or ($tokens.Count -le 0))
            {
                Log-Throw -Message "Token cache is empty `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
            }
        }
        else
        {
            $token = $tokens |
                Where Resource -EQ $environment.ActiveDirectoryServiceEndpointResourceId |
                Where { $_.TenantId -eq $subscription.TenantId } |
                Where { $_.ExpiresOn -gt [datetime]::UtcNow } |
                Select -First 1
        }
    }


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

Determines if the currently running user is part of the Domain Admin's group

#>
function Resolve-DomainAdminStatus{
[CmdletBinding()]
Param()
    try
    {
        Log-Output "Checking for user logged in as Domain Admin"
        $currentUser     = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($CurrentUser)
        $domain = Get-ADDomain
        $sid = "$($domain.DomainSID)-512"

        if($windowsPrincipal.IsInRole($sid))
        {
            Log-Output "Domain Admin check : ok"
        }    
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    {
        $message = "User is not logged in as a domain admin. registration has been cancelled."        
        Log-Throw -Message "$message `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
    }
    catch
    {        
        Log-Throw -Message "Unexpected error while checking for domain admin: `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.InvocationName
    }
}

<#

.SYNOPSIS

Creates a powershell session with the JeaComputer for registration actions

#>
function Initialize-PrivilegedJeaSession{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [String] $JeaComputerName,

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
            Log-Output "Initializing privileged JEA session with $JeaComputerName. Attempt $currentAttempt of $maxAttempts"
            $session = New-PSSession -ComputerName $JeaComputerName -ConfigurationName PrivilegedEndpoint -Credential $CloudAdminCredential
            Log-Output "Connection to $JeaComputerName successful"
            return $session
        }
        catch
        {
            Log-Warning "Creation of session with $JeaComputerName failed:`r`n$($_.Exception.Message)"
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

Uses the current session with the JeaComputer to determine the version of Azure Stack that has been deployed

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

    Write-Verbose -Message "using token_endpoint $($response.token_endpoint) to parse tenant id" -Verbose
    $tenantId = $response.token_endpoint.Split('/')[3]
 
    $tenantIdGuid = [guid]::NewGuid()
    $result = [guid]::TryParse($tenantId, [ref] $tenantIdGuid)

    if(-not $result)
    {
        Write-Error "Error obtaining tenant id from tenant name"
    }
    else
    {
        Write-Verbose -Message "Tenant Name: $tenantName Tenant id: $tenantId" -Verbose
        return $tenantId
    }
}

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

    throw "Logs can be found at: $Global:AzureRegistrationLog  and  \\$JeaComputerName\c$\maslogs `r`n$Message"
}

Export-ModuleMember Add-AzsRegistration
Export-ModuleMember Remove-AzsRegistration
Export-ModuleMember Set-AzsRegistrationSubscription
