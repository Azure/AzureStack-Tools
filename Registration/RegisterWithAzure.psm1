# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

# Create log folder / prevent duplicate logs
$LogFolder = "$env:SystemDrive\MASLogs"
if (-not (Test-Path $LogFolder))
{
    New-Item -Path $LogFolder -ItemType Directory -Force
}
if(-not $Global:AzureRegistrationLog)
{
    $Global:AzureRegistrationLog = "$LogFolder\AzureStack.AzureRegistration.$(Get-Date -Format yyyy-MM-dd.hh-mm-ss).log"
    $null = New-Item -Path $Global:AzureRegistrationLog -ItemType File -Force
}

################################################################
# Core Functions
################################################################

#region CoreFunctions

#documentation template
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

<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER 

.EXAMPLE

.NOTES

#>
Function Get-AzsRegistrationToken{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development')]
        [string] $BillingModel = 'Capacity',

        [Parameter(Mandatory=$false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory=$false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string] $AgreementNumber,

        [Parameter(Mandatory=$false)]
        [Switch] $WriteRegistrationToken = $false,

        [Parameter(Mandatory = $false)]
        [String] $TokenOutputFilePath = "$Env:HOMEDRIVE\Temp\RegistrationToken.txt"
    )
    #requires -Version 4.0
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: Get-AzsRegistrationToken ***********************`r`n"

    $workerParams = @{
        CloudAdminCredential          = $CloudAdminCredential
        PrivilegedEndpoint            = $PrivilegedEndpoint
        BillingModel                  = $BillingModel
        MarketplaceSyndicationEnabled = $MarketplaceSyndicationEnabled
        UsageReportingEnabled         = $UsageReportingEnabled
        AgreementNumber               = $AgreementNumber
        TokenOutputFilePath           = $TokenOutputFilePath
        WriteRegistrationToken        = $WriteRegistrationToken
        RegistrationAction            = "Get-RegistrationToken"
    }

    Log-Output "Registration action params: $(ConvertTo-Json $workerParams)"

    RegistrationWorker @workerParams

    Log-Output "Your registration token can be found at: $TokenOutputFilePath"
    Log-Output "*********************** End log: Get-AzsRegistrationToken ***********************`r`n`r`n"
}

<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER

.EXAMPLE

.NOTES

#>
Function Register-AzureStack{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [String] $AzureSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [String] $RegistrationToken,

        [Parameter(Mandatory = $false)]
        [String] $AzureEnvironmentName = 'AzureCloud',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName
    )
    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: New-AzsRegistration ***********************`r`n"

    $workerParams = @{
        CloudAdminCredential     = $CloudAdminCredential
        PrivilegedEndpoint       = $PrivilegedEndpoint
        AzureSubscriptionId      = $AzureSubscriptionId
        AzureDirectoryTenantName = $AzureDirectoryTenantName
        AzureEnvironmentName     = $AzureEnvironmentName
        ResourceGroupName        = $ResourceGroupName
        ResourceGroupLocation    = $ResourceGroupLocation
        RegistrationName         = $RegistrationName
        RegistrationToken        = $RegistrationToken
        RegistrationAction       = "Register-AzureStack"
    }

    Log-Output "Registration action params: $(ConvertTo-Json $workerParams)"

    RegistrationWorker @workerParams

    Log-Output "Your Azure Stack environment is now registered with Azure."
    Log-Output "*********************** End log: New-AzsRegistration ***********************`r`n`r`n"
}

<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER 

.EXAMPLE

.NOTES

#>
Function Enable-AzureStackFeature{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [String] $AzureSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory = $false)]
        [String] $AzureEnvironmentName = 'AzureCloud',
        
        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName

    )
    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: New-AzsActivation ***********************`r`n"

    $workerParams = @{
        CloudAdminCredential     = $CloudAdminCredential
        PrivilegedEndpoint       = $PrivilegedEndpoint
        AzureSubscriptionId      = $AzureSubscriptionId
        AzureDirectoryTenantName = $AzureDirectoryTenantName
        AzureEnvironmentName     = $AzureEnvironmentName
        ResourceGroupName        = $ResourceGroupName
        RegistrationName         = $RegistrationName
        RegistrationAction       = "Enable-AzureStackFeature"
    }

    Log-Output "Registration action params: $(ConvertTo-Json $workerParams)"

    RegistrationWorker @workerParams

    Log-Output "Activation completed. You can now download items from the Azure marketplace."
    Log-Output "*********************** End log: New-AzsActivation ***********************`r`n`r`n"
}

#endregion

################################################################
# Helper Functions
################################################################

#region HelperFunctions

<#

.SYNOPSIS

Performs critical registration and activation actions

#>
function RegistrationWorker{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Get-RegistrationToken','Register-AzureStack','Enable-AzureStackFeature')]
        [String] $RegistrationAction,

        [Parameter(Mandatory = $false)]
        [String] $AzureSubscriptionId,

        [Parameter(Mandatory = $false)]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation,

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $AzureEnvironmentName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development')]
        [string] $BillingModel,

        [Parameter(Mandatory=$false)]
        [switch] $MarketplaceSyndicationEnabled,

        [Parameter(Mandatory=$false)]
        [switch] $UsageReportingEnabled,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string] $AgreementNumber,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [String] $RegistrationToken,

        [Parameter(Mandatory=$false)]
        [Switch] $WriteRegistrationToken = $false,

        [Parameter(Mandatory = $false)]
        [String] $TokenOutputFilePath
    )

    $session = Initialize-PrivilegedJeaSession -PrivilegedEndpoint $PrivilegedEndpoint -CloudAdminCredential $CloudAdminCredential -Verbose
    $stampInfo = Confirm-StampVersion -PSSession $session
    $RegistrationName = if ($RegistrationName) { $RegistrationName } else { "AzureStack-$($stampInfo.CloudID)" }

    try
    {
        Switch ($RegistrationAction)
        {
            #
            # Create registration token
            #
            'Get-RegistrationToken' 
            {
                Log-Output "Generating Registration Token..."
                $registrationToken = Get-RegistrationToken -PSSession $session -BillingModel $BillingModel -MarketplaceSyndicationEnabled:$MarketplaceSyndicationEnabled -UsageReportingEnabled:$UsageReportingEnabled -AgreementNumber $AgreementNumber 
                if ($WriteRegistrationToken)
                {
                    Log-Output "Registration token will be written to: $TokenOutputFilePath"
                    $RegistrationToken | Out-File $TokenOutputFilePath
                }                
                return $RegistrationToken
            }

            #
            # Create registration resource in Azure
            #
            'Register-AzureStack'
            {
                Log-Output "Registering with Azure by creating registration resources in Azure..."
                $connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -AzureDirectoryTenantName $AzureDirectoryTenantName -Verbose
                New-RegistrationResource -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -RegistrationName $RegistrationName -RegistrationToken $RegistrationToken -StampInfo $stampInfo
            }

            #
            # Activate Azure Stack
            #
            'Enable-AzureStackFeature'
            {
                Log-Output "Activating Azure Stack environment"
                $connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -AzureDirectoryTenantName $AzureDirectoryTenantName -Verbose
                $servicePrincipal = New-ServicePrincipal -RefreshToken $connection.Token.RefreshToken -AzureEnvironmentName $AzureEnvironmentName -TenantId $connection.TenantId -PSSession $session
                Log-Output "Assigning custom RBAC role to resource $RegistrationName"
                New-RBACAssignment -SubscriptionId $AzureSubscriptionId -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName -ServicePrincipal $servicePrincipal
                $activationKey = Get-RegistrationActivationKey -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName
                Log-Output "Activating Azure Stack (this may take up to 10 minutes to complete)."
                $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:activationKey }
            }
        }
    }
    catch
    {
        Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.InvocationName
    }
    finally
    {
        Log-Output "Terminating session with $PrivilegedEndpoint"
        $session | Remove-PSSession
    }
}

<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER 

.EXAMPLE

.NOTES

#>
Function Get-RegistrationToken{
[CmdletBinding()]
    param(
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
        [System.Management.Automation.Runspaces.PSSession] $PSSession
    )
    
    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 

    do
    {
        try
        {
            Log-Output "Creating registration token. Attempt $currentAttempt of $maxAttempts"
            $registrationToken = Invoke-Command -Session $session -ScriptBlock { New-RegistrationToken -BillingModel $using:BillingModel -MarketplaceSyndicationEnabled:$using:MarketplaceSyndicationEnabled -UsageReportingEnabled:$using:UsageReportingEnabled -AgreementNumber $using:AgreementNumber }
            return $registrationToken
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
}

<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER 

.EXAMPLE

.NOTES

#>
function New-RegistrationResource{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $RegistrationToken,

        [Parameter(Mandatory = $false)]
        [Object] $StampInfo
    )

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 

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
    
    $resourceCreationParams = @{
        ResourceGroupName = $ResourceGroupName
        Location          = $ResourceGroupLocation
        ResourceName      = $RegistrationName
        ResourceType      = "Microsoft.AzureStack/registrations"
        ApiVersion        = "2017-06-01" 
        Properties        = @{ registrationToken = "$registrationToken" }
    }

    do
    {
        try
        {
            Log-Output "Creating resource group '$ResourceGroupName' in location $ResourceGroupLocation."
            $resourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force
            Log-Output "Creating registration resource '$RegistrationName'."
            $registrationResource = New-AzureRmResource @resourceCreationParams -Force
            Log-Output "Registration resource: $(ConvertTo-Json $registrationResource)"
        }
        catch
        {
            Log-Warning "Creation of Azure resource failed:`r`n$($_.Exception.Message)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempts)
            {
                Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.InvocationName
            }
        }
    } while ($currentAttempt -lt $maxAttempts)
}

<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER 

.EXAMPLE

.NOTES

#>
Function Get-RegistrationActivationKey{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName
    )

    Log-Output "Retrieving activation key."
    $resourceActionparams = @{
        Action            = "GetActivationKey"
        ResourceName      = $RegistrationName
        ResourceType      = "Microsoft.AzureStack/registrations"
        ResourceGroupName = $ResourceGroupName
        ApiVersion        = "2017-06-01"
    }

    Log-Output "Getting activation key from $RegistrationName..."
    $actionResponse = Invoke-AzureRmResourceAction @resourceActionparams -Force
    Log-Output "Activation key successfully retrieved."
    return $actionResponse.ActivationKey
}

<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER 

.EXAMPLE

.NOTES

#>
Function New-ServicePrincipal{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $RefreshToken,

        [Parameter(Mandatory = $true)]
        [String] $AzureEnvironmentName,

        [Parameter(Mandatory = $true)]
        [String] $TenantId,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Runspaces.PSSession] $PSSession
    )
    
    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 
    do
    {
        try
        {
            Log-Output "Creating Azure Active Directory service principal in tenant '$TenantId' Attempt $currentAttempt of $maxAttempts"
            $servicePrincipal = Invoke-Command -Session $PSSession -ScriptBlock { New-AzureBridgeServicePrincipal -RefreshToken $using:RefreshToken -AzureEnvironment $using:AzureEnvironmentName -TenantId $using:TenantId }
            Log-Output "Service principal created. ObjectId: $($servicePrincipal.ObjectId)"
            return $servicePrincipal
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
}

<#

.SYNOPSIS

Adds the provided subscription id to the custom RBAC role 'Registration Reader'

#>
function New-RBACAssignment{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $true)]
        [String] $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [String] $SubscriptionId,

        [Parameter(Mandatory = $true)]
        [Object] $ServicePrincipal
    )

    $registrationResource = Get-AzureRmResource -ResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$RegistrationName"

    $customRoleAssigned = $false
    $customRoleName = "Registration Reader"

    Log-Output "Setting $customRoleName role on '$($RegistrationResource.ResourceId)'"

    # Determine if the custom RBAC role has been defined
    if (-not (Get-AzureRmRoleDefinition -Name $customRoleName))
    {
        $customRoleName = "Registration Reader-$($RegistrationResource.SubscriptionId)"
        if (-not (Get-AzureRmRoleDefinition -Name $customRoleName))
        {
            # Create new RBAC role definition
            $role = Get-AzureRmRoleDefinition -Name 'Reader'
            $role.Name = $customRoleName
            $role.id = [guid]::newguid()
            $role.IsCustom = $true
            $role.Actions.Add('Microsoft.AzureStack/registrations/products/listDetails/action')
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
    }

    # Determine if custom RBAC role has been assigned
    $roleAssignmentScope = "/subscriptions/$($RegistrationResource.SubscriptionId)/resourceGroups/$($RegistrationResource.ResourceGroupName)/providers/Microsoft.AzureStack/registrations/$($RegistrationResource.ResourceName)"
    $roleAssignments = Get-AzureRmRoleAssignment -Scope $roleAssignmentScope -ObjectId $ServicePrincipal.ObjectId

    foreach ($role in $roleAssignments)
    {
        if ($role.RoleDefinitionName -eq $customRoleName)
        {
            $customRoleAssigned = $true
        }
    }

    if (-not $customRoleAssigned)
    {        
        New-AzureRmRoleAssignment -Scope $roleAssignmentScope -RoleDefinitionName $customRoleName -ObjectId $ServicePrincipal.ObjectId
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
    Log-Output "Checking connection to Azure..."
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
            Log-Output "Attempting to connect to Azure..."
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

        Log-Output -Message "Running registration actions on build $($stampInfo.StampVersion). Cloud Id: $($stampInfo.CloudID), Deployment Id: $($stampInfo.DeploymentID)"
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
function Get-TenantIdFromName{
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
function Get-AzureURIs{
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
function Log-Output{
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
function Log-Warning{
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
function Log-Throw{
    param(
        [Parameter(Mandatory=$true)]
        [Object] $Message,

        [Parameter(Mandatory=$true)]
        [String] $CallingFunction
    )

    # Write Error: line seperately otherwise out message will not contain stack trace
    "`r`n`r`n**************************** Error ****************************" | Out-File $Global:AzureRegistrationLog -Append
    "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message" | Out-File $Global:AzureRegistrationLog -Append
    "***************************************************************`r`n" | Out-File $Global:AzureRegistrationLog -Append
    Log-Output "*********************** Ending registration action during $CallingFunction ***********************`r`n`r`n"

    throw "Logs can be found at: $Global:AzureRegistrationLog  and  \\$PrivilegedEndpoint\c$\maslogs `r`n$Message"
}

#endregion

Export-ModuleMember Get-AzsRegistrationToken
Export-ModuleMember Register-AzureStack
Export-ModuleMember Enable-AzureStackFeature
