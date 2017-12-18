# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#

This module contains functions for registering your environment and enabling marketplace syndication / usage reporting. 
To run registration and activation functions you must have a public Azure subscription of any type.
You must also have access to an account / directory that is an owner or contributor to that subscription.

#>

# Create log folder / prevent duplicate logs
$LogFolder = "$env:SystemDrive\MASLogs"
if (-not (Test-Path $LogFolder))
{
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
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

#region ConnectedScenario

<#

.SYNOPSIS

Set-AzsRegistration can be used to register Azure Stack with Azure and enable/disable marketplace syndication and usage reporting.
To run this function, you must have a public Azure subscription of any type. 
You must also be logged in to Azure Powershell with an account that is an owner or contributor to that subscription.

.DESCRIPTION

Set-AzsRegistration uses the current Azure Powershell context and runs scripts already present in Azure Stack from the ERCS VM to connect your Azure Stack to Azure.
You MUST be logged in to the Azure Powershell context that you want to register your Azure Stack with.
After connecting with Azure, you can download products from the marketplace (See the documentation for more information: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-download-azure-marketplace-item).
Running this script with default parameters will enable marketplace syndication and usage data will default to being reported to Azure.
NOTE: Default billing model is 'Development' and is only usable for proof of concept builds.
To disable syndication or usage reporting see examples below.

This script will create the following resources by default:
- A service principal to perform resource actions
- A resource group in Azure (if needed)
- A registration resource in the created resource group in Azure
- An activation resource group and resource in Azure Stack

See documentation for more detail: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the Privileged Endpoint VM (also known as Emergency Console) to call whitelisted cmdlets and scripts.
If not supplied script will request manual input of username and password

.PARAMETER PrivilegedEndpoint

Privileged Endpoint VM that performs environment administration actions. Also known as Emergency Console VM.(Example: AzS-ERCS01 for the ASDK)

.PARAMETER ResourceGroupName

This will be the name of the resource group in Azure where the registration resource is stored. Defaults to "azurestack"

.PARAMETER  ResourceGroupLocation

The location where the resource group will be created. Defaults to "westcentralus"

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

Used when the billing model is set to capacity. You will need to provide a specific agreement number associated with your billing agreement.

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication, and enables usage reporting to Azure.

Set-AzsRegistration -CloudAdminCredential $CloudAdminCredential -PrivilegedEndpoint "Azs-ERCS01"

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication, and disables usage reporting to Azure.

Set-AzsRegistration -CloudAdminCredential $CloudAdminCredential -PrivilegedEndpoint "Azs-ERCS01" -BillingModel 'Capacity' -UsageReportingEnabled:$false -AgreementNumber $MyAgreementNumber

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication and usage and gives a specific name to the resource group

Set-AzsRegistration -CloudAdminCredential $CloudAdminCredential -PrivilegedEndpoint "Azs-ERCS02" -ResourceGroupName "ContosoStackRegistrations"

.EXAMPLE

This example disables syndication and disables usage reporting to Azure. Note that usage will still be collected, just not sent to Azure.

Set-AzsRegistration -CloudAdminCredential $CloudAdminCredential -PrivilegedEndpoint "Azs-ERCS01" -BillingModel Capacity -MarketplaceSyndicationEnabled:$false -UsageReportingEnabled:$false -AgreementNumber $MyAgreementNumber

.NOTES

If you would like to un-Register with Azure by turning off marketplace syndication, disabling usage reporting, and removing the registration resource from Azure you can run Remove-AzsRegistration.
Note that this will remove any downloaded marketplace products.

If you would like to use a different subscription for registration you must first run Remove-AzsRegistration followed by Set-AzsRegistration after logging into the appropriate Azure Powershell context.
This will remove any downloaded marketplace products and they will need to be re-downloaded.

You MUST be logged in to Azure before attempting to use Set-AzsRegistration.
It is very important to ensure you are logged in to the correct Azure Account in Powershell before running this function.

#>
function Set-AzsRegistration{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzureRmContext),

        [Parameter(Mandatory = $false)]
        [String] $AzureEnvironmentName = 'AzureCloud',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development')]
        [string] $BillingModel = 'Development',

        [Parameter(Mandatory = $false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory = $false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $AgreementNumber
    )
    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    $azureAccountInfo = Get-AzureAccountInfo -AzureContext $AzureContext
    $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -CloudAdminCredential $CloudAdminCredential -Verbose
    $stampInfo = Confirm-StampVersion -PSSession $session

    $registrationName =  "AzureStack-$($stampInfo.CloudID)"

    # Configure Azure Bridge
    $servicePrincipal = New-ServicePrincipal -RefreshToken $azureAccountInfo.Token.RefreshToken -AzureEnvironmentName $AzureContext.Environment.Name -TenantId $azureAccountInfo.TenantId -PSSession $session
    
    # Get registration token
    $getTokenParams = @{
        BillingModel                  = $BillingModel
        MarketplaceSyndicationEnabled = $MarketplaceSyndicationEnabled
        UsageReportingEnabled         = $UsageReportingEnabled
        AgreementNumber               = $AgreementNumber
    }
    Log-Output "Get-RegistrationToken parameters: $(ConvertTo-Json $getTokenParams)"
    $registrationToken = Get-RegistrationToken @getTokenParams -Session $session -StampInfo $stampInfo
    
    # Register environment with Azure
    New-RegistrationResource -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -RegistrationToken $RegistrationToken

    # Assign custom RBAC role
    Log-Output "Assigning custom RBAC role to resource $RegistrationName"
    New-RBACAssignment -SubscriptionId $AzureContext.Subscription.SubscriptionId -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName -ServicePrincipal $servicePrincipal

    # Activate AzureStack syndication / usage reporting features
    $activationKey = Get-RegistrationActivationKey -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName
    Log-Output "Activating Azure Stack (this may take up to 10 minutes to complete)."
    Activate-AzureStack -Session $session -ActivationKey $ActivationKey

    Log-Output "Your environment is now registered and activated using the provided parameters."
    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"
}

<#

.SYNOPSIS

Remove-AzsRegistration can be used to disable syndication, disable usage reporting, and unregister your environment with Azure.
To run this function, you must have previously run Set-AzsRegistration
You must also be logged in to Azure Powershell with an account that is an owner or contributor to that subscription.

.DESCRIPTION

Remove-AzsRegistration uses the current Azure Powershell context and runs scripts already present in Azure Stack from the ERCS VM to remove a current registration from Azure.
You MUST be logged in to the Azure Powershell context that you want to disassociate your environment from.
You must have already run Set-AzsRegistration before running this function.

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the JEA Computer (also known as Emergency Console) to call whitelisted cmdlets and scripts.
If not supplied script will request manual input of username and password

.PARAMETER PrivilegedEndpoint

Privileged Endpoint VM that performs environment administration actions. Also known as Emergency Console VM.(Example: AzS-ERCS01 for the ASDK)

.PARAMETER ResourceGroupName

This is the name of the resource group in Azure where the registration resource has been created. Defaults to "azurestack"

.PARAMETER  ResourceGroupLocation

The location where the resource group has been created. Defaults to "westcentralus"

.EXAMPLE

This example unregisters your AzureStack environment with Azure.

Remove-AzsRegistration -CloudAdminCredential $CloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint

.NOTES

It is very important to ensure you are logged in to the correct Azure Account in Powershell before running this function.

#>
function Remove-AzsRegistration{
[CmdletBinding()]
    param(
    [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzureRmContext)
    )
    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    $azureAccountInfo = Get-AzureAccountInfo -AzureContext $AzureContext
    $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -CloudAdminCredential $CloudAdminCredential -Verbose
    $stampInfo = Confirm-StampVersion -PSSession $session

    $registrationName =  "AzureStack-$($stampInfo.CloudID)"

    # Find registration resource in Azure
    Log-Output "Searching for registration resource in Azure..."
    $registrationResourceId = "/subscriptions/$($AzureContext.Subscription.SubscriptionId)/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$registrationName"
    $registrationResource = Get-AzureRmResource -ResourceId $registrationResourceId -ErrorAction Ignore
    
    if ($registrationResource)
    {
        Log-Output "Resource found. Deactivating Azure Stack and removing resource: $registrationResourceId"

        $BillingModel = $registrationResource.Properties.BillingModel
        $AgreementNumber = $registrationResource.Properties.AgreementNumber

        # Configure Azure Bridge
        $servicePrincipal = New-ServicePrincipal -RefreshToken $azureAccountInfo.Token.RefreshToken -AzureEnvironmentName $AzureContext.Environment.Name -TenantId $azureAccountInfo.TenantId -PSSession $session

        # Get registration token
        if (($BillingModel -eq "Capacity") -or ($BillingModel -eq "Development"))
        {
            $getTokenParams = @{
            BillingModel                  = $BillingModel
            MarketplaceSyndicationEnabled = $false
            UsageReportingEnabled         = $false
            AgreementNumber               = $AgreementNumber
            }
        }
        else
        {
            $getTokenParams = @{
            BillingModel                  = $BillingModel
            MarketplaceSyndicationEnabled = $false
            UsageReportingEnabled         = $true
            }
        }
    
        Log-Output "Deactivating syndication features..."
        Log-Output "Get-RegistrationToken parameters: $(ConvertTo-Json $getTokenParams)"
        $registrationToken = Get-RegistrationToken @getTokenParams -Session $session -StampInfo $stampInfo

        # Register environment with Azure
        New-RegistrationResource -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -RegistrationToken $RegistrationToken

        # Assign custom RBAC role
        Log-Output "Assigning custom RBAC role to resource $RegistrationName"
        New-RBACAssignment -SubscriptionId $AzureContext.Subscription.SubscriptionId -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName -ServicePrincipal $servicePrincipal

        # Deactivate AzureStack syndication / usage reporting features
        $activationKey = Get-RegistrationActivationKey -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName
        Log-Output "De-Activating Azure Stack (this may take up to 10 minutes to complete)."
        Activate-AzureStack -Session $session -ActivationKey $ActivationKey
        
        Log-Output "Your environment is now unable to syndicate items and is no longer reporting usage data"

        # Remove registration resource from Azure
        Log-Output "Removing registration resource from Azure..."
        Remove-RegistrationResource -ResourceId $registrationResourceId
    }
    else
    {
        Log-Throw -Message "Registration resource was not found: $registrationResourceId. Please ensure a registration resource exists in the provided subscription & resource group." -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
    }

    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"
}

#endregion

#region DisconnectedScenario

<#
.SYNOPSIS

Get-AzsRegistrationToken will generate a registration token from the input parameters.

.DESCRIPTION

Get-AzsRegistrationToken will use the BillingModel, MarketplaceSyndicationEnabled, UsageReportingEnabled, and AgreementNumber (if necessary) parameters to generate a registration token. 
This token is used to enable / disable Azure Stack features such as Azure marketplace product syndication and Azure Stack usage reporting. 
A registration token is required to call Register-AzsEnvironment. 

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the privileged endpoint to call approved cmdlets and scripts.
This parameter is mandatory and if not supplied then this function will request manual input of username and password

.PARAMETER PrivilegedEndpoint

The name of the VM that has permissions to perform approved powershell cmdlets and scripts. Usually has a name in the format of <ComputerName>-ERCSxx where <ComputerName>
is the name of the machine and ERCS is followed by a number between 01 and 03. Example: Azs-ERCS01 (from the ASDK)

.PARAMETER TokenOutputFilePath

This parameter sets the output location for the registration token.

.PARAMETER BillingModel

The billing model that will be used for this environment. Select from "Capacity", and "Development". Defaults to "Development" which is usable for POC / ASDK installments.
Please see documentation for more information: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-billing-and-chargeback

.PARAMETER AgreementNumber

A valid agreement number must be provided if the 'capacity' BillingModel parameter is provided.

.EXAMPLE

This example generates a registration token for use in Register-AzsEnvironment and writes it to a txt file.
$registrationToken = Get-AzsRegistrationToken -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development -TokenOutputFilePath "C:\Temp\RegistrationToken.txt"

.NOTES

This function is designed to only be used in conjunction with Register-AzsEnvironment. This will not enable any Azure Stack marketplace syndication or usage reporting features. Example:

$registrationToken = Get-AzsRegistrationToken -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development -TokenOutputFilePath "C:\Temp\RegistrationToken.txt"
Register-AzsEnvironment -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -RegistrationToken $registrationToken

#>
Function Get-AzsRegistrationToken{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Capacity', 'Development')]
        [string] $BillingModel = 'Capacity',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String] $TokenOutputFilePath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $AgreementNumber
    )
    #requires -Version 4.0
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    if(($BillingModel -eq 'Capacity') -and ([String]::IsNullOrEmpty($AgreementNumber)))
    {
        Log-Throw -Message "Agreement number is null or empty when BillingModel is set to Capacity" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }

    if ($TokenOutputFilePath -and (-not (Test-Path -Path $TokenOutputFilePath -PathType Leaf)))
    {
        Log-Warning "Provided value for -TokenOutputFilePath does not exist. attempting to create file at $TokenOutputFilePath..."
        try
        {
            New-Item -Path $TokenOutputFilePath -ItemType File -Verbose
            Log-Output "File created at path: $TokenOutputFilePath"
        }
        catch
        {
            Log-Throw -Message "Unable to create file at location $TokenOutputFilePath. Please provide a valid input for -TokenOutputFilePath. `r`n$($_)" -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
        }
    }

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    $params = @{
        CloudAdminCredential          = $CloudAdminCredential
        PrivilegedEndpoint            = $PrivilegedEndpoint
        BillingModel                  = $BillingModel
        MarketplaceSyndicationEnabled = $false
        UsageReportingEnabled         = $false
        AgreementNumber               = $AgreementNumber
        TokenOutputFilePath           = $TokenOutputFilePath
    }

    Log-Output "Registration action params: $(ConvertTo-Json $params)"

    $registrationToken = Get-RegistrationToken @params

    if ($TokenOutputFilePath)
    {
        Log-Output "Your registration token can be found at: $TokenOutputFilePath"   
    }
    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"

    return $registrationToken
}

<#
.SYNOPSIS

Register-AzsEnvironment will register your environment with Azure but will not enable syndication or usage reporting. This can be run on any computer with a connection to the internet.

.DESCRIPTION

Register-AzsEnvironment creates a resource group and registration resource in Azure.
A registration token is required to register with Azure.

.PARAMETER RegistrationToken

The registration token created after running Get-AzsRegistrationToken. This contains BillingModel, marketplace syndication, and other important information.

.PARAMETER AzureEnvironmentName

The Azure environment that will be used to create registration resource. defaults to AzureCloud

.PARAMETER ResourceGroupName

The name of the resource group that will contain the registration resource. Defaults to 'azurestack'

.PARAMETER ResourceGroupLocation

The Azure location where the registration resource group will be created. Defaults to 'westcentralus'

.EXAMPLE

This example will register your Azure Stack environment with all default parameters.

Register-AzsEnvironment -RegistrationToken $registrationToken

.EXAMPLE

This example will register your Azure Stack environment with a specific name for a resource group

Register-AzsEnvironment -RegistrationToken $registrationToken -ResourceGroupName "ContosoRegistrations"

.NOTES

This function will not enable marketplace syndication or usage reporting.

#>
Function Register-AzsEnvironment{
[CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [String] $RegistrationToken,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzureRmContext),

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus'
    )
    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    $azureAccountInfo = Get-AzureAccountInfo -AzureContext $AzureContext
    New-RegistrationResource -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -RegistrationToken $RegistrationToken

    Log-Output "Your Azure Stack environment is now registered with Azure."
    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"
}

<#
.SYNOPSIS

UnRegister-AzsEnvironment will unregister your environment with Azure

.DESCRIPTION

UnRegister-AzsEnvironment removes the registration resource that was created in Azure during Register-AzsEnvironment

.PARAMETER RegistrationToken

The registration token created after running Get-AzsRegistrationToken. This contains information used to find the registration name

.PARAMETER RegistrationName

The name of the registration resource that was created during Register-AzsEnvironment.

.PARAMETER AzureEnvironmentName

The Azure environment that was used to create registration resource. defaults to AzureCloud

.PARAMETER ResourceGroupName

The name of the resource group that was created for the registration resource. Defaults to 'azurestack'

.PARAMETER ResourceGroupLocation

The Azure location where the registration resource group was created. Defaults to 'westcentralus'

.EXAMPLE

This example will unregister your Azure Stack environment using a registration token

UnRegister-AzsEnvironment -RegistrationToken $registrationToken

.EXAMPLE

This exmple will unregister your Azure Stack environment using the registration name.

UnRegister-AzsEnvironment -RegistrationName "AzureStack-33295300-80f3-4fa6-a031-26d51331e826"

.NOTES

This should only be used if Register-AzsEnvironment was called previously. If you would like to disable syndication or usage reporting
that was enabled during Set-AzsRegistration, then you will need to run Remove-AzsRegistration

#>
Function UnRegister-AzsEnvironment{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzureRmContext),

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [String] $RegistrationToken,

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus'
    )
    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    if (-not $RegistrationName)
    {
        try 
        {
            $bytes = [System.Convert]::FromBase64String($RegistrationToken)
            $tokenObject = [System.Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
            $registrationName = "AzureStack-$($tokenObject.CloudId)"
        }
        Catch
        {
            Log-Throw -Message "No registration name or registration token passed in. Unable to locate registration resource for removal." -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
        }   
    }

    $azureAccountInfo = Get-AzureAccountInfo -AzureContext $AzureContext
    $registrationResourceId = "/subscriptions/$($AzureContext.Subscription.SubscriptionId)/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$RegistrationName"
    $registrationResource = Get-AzureRmResource -ResourceId $registrationResourceId -ErrorAction Ignore
    
    if ($registrationResource)
    {
        Log-Output "Found registration resource in Azure: $registrationResourceId"
        Log-Output "Removing registration resource from Azure..."
        Remove-RegistrationResource -ResourceId $registrationResourceId
    }
    else
    {
        Log-Throw "Registration resource not found in Azure: $registrationResourceId `r`nPlease ensure a valid registration exists in the subscription / resource group provided." -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
    }

    Log-Output "Your Azure Stack environment is now unregistered from Azure."
    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"
}

<#
.SYNOPSIS

Gets the registration name used for registration

.DESCRIPTION

The registration name in Azure is derived from the CloudId of the environment: "AzureStack-<CloudId>". 
This function gets the CloudId by calling a PEP script and returns the name used during registration

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the Privileged Endpoint VM (also known as Emergency Console) to call whitelisted cmdlets and scripts.
If not supplied script will request manual input of username and password

.PARAMETER PrivilegedEndpoint

Privileged Endpoint VM that performs environment administration actions. Also known as Emergency Console VM.(Example: AzS-ERCS01 for the ASDK)

.EXAMPLE

This example returns the name that was used for registration
Get-AzsRegistrationName -CloudAdminCredential $CloudAdminCredential -PrivilegedEndpoint Azs-ERCS01

#>
Function Get-AzsRegistrationName{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint
    )
    #requires -Version 4.0
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"
    $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -CloudAdminCredential $CloudAdminCredential -Verbose
    $registrationName = Get-RegistrationName -Session $session
    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"
}

#endregion

#endregion

################################################################
# Helper Functions
################################################################

#region HelperFunctions

<#
.SYNOPSIS

Calls the Get-AzureStackStampInformation PEP script and returns the name used for the registration resource

#>
Function Get-RegistrationName{
[CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.Runspaces.PSSession] $Session
    )
    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 
    do
    {
        try
        {
            Log-Output "Retrieving AzureStack stamp information..."
            $azureStackStampInfo = Invoke-Command -Session $session -ScriptBlock { Get-AzureStackStampInformation }
            $RegistrationName = "AzureStack-$($azureStackStampInfo.CloudId)"
            Write-Verbose "Registration name: $RegistrationName"
            return $RegistrationName
        }
        catch
        {
            Log-Warning "Retrieving AzureStack stamp information failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction  $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)
}
<#
.SYNOPSIS

Returns an object, RegistrationDetails, that contains a RegisrationToken and RegistrationName for use in Register-AzsEnvironment

#>
Function Get-RegistrationToken{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $false)]
        [String] $PrivilegedEndpoint,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development')]
        [string] $BillingModel = 'Development',

        [Parameter(Mandatory = $false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory = $false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $AgreementNumber,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.Runspaces.PSSession] $Session,

        [Parameter(Mandatory = $false)]
        [PSObject] $StampInfo,

        [Parameter(Mandatory = $false)]
        [String] $TokenOutputFilePath
    )

    $sessionProvided = $true

    try
    {
        if (-not $session)
        {
            $sessionProvided = $false
            $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -CloudAdminCredential $CloudAdminCredential -Verbose
        }

        if (-not $StampInfo)
        {
            Confirm-StampVersion -PSSession $session | Out-Null
        }
    
        $currentAttempt = 0
        $maxAttempt = 3
        $sleepSeconds = 10 
        do
        {
            try
            {
                Log-Output "Creating registration token. Attempt $currentAttempt of $maxAttempt"
                $registrationToken = Invoke-Command -Session $session -ScriptBlock { New-RegistrationToken -BillingModel $using:BillingModel -MarketplaceSyndicationEnabled:$using:MarketplaceSyndicationEnabled -UsageReportingEnabled:$using:UsageReportingEnabled -AgreementNumber $using:AgreementNumber }
                if ($TokenOutputFilePath)
                {
                    Log-Output "Registration token will be written to: $TokenOutputFilePath"
                    $registrationToken | Out-File $TokenOutputFilePath -Force
                }
                Log-Output "Registration token created."
                return $registrationToken
            }
            catch
            {
                Log-Warning "Creation of registration token failed:`r`n$($_)"
                Log-Output "Waiting $sleepSeconds seconds and trying again..."
                $currentAttempt++
                Start-Sleep -Seconds $sleepSeconds
                if ($currentAttempt -ge $maxAttempt)
                {
                    Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
                }
            }
        }
        while ($currentAttempt -lt $maxAttempt)
    }
    finally
    {
        if (-not $sessionProvided)
        {
            Log-Output "Terminating session with $PrivilegedEndpoint"
            $session | Remove-PSSession
        }
    }
}

<#
.SYNOPSIS

Uses information from Get-AzsRegistrationToken to create registration resource group and resource in Azure

#>
function New-RegistrationResource{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationToken
    )

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 

    try 
    {
        $bytes = [System.Convert]::FromBase64String($RegistrationToken)
        $tokenObject = [System.Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
        $registrationName = "AzureStack-$($tokenObject.CloudId)"
        Log-Output "Registration resource name: $registrationName"
    }
    Catch
    {
        $registrationName = "AzureStack-CloudIdError-$([Guid]::NewGuid())"
        Log-Warning "Unable to extract cloud-Id from registration token. Setting registration name to: $registrationName"
    }

    Register-AzureStackResourceProvider

    $resourceCreationParams = @{
        ResourceGroupName = $ResourceGroupName
        Location          = 'Global'
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
            break
        }
        catch
        {
            Log-Warning "Creation of Azure resource group failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)

    do
    {
        try
        {
            Log-Output "Creating registration resource..."
            $registrationResource = New-AzureRmResource @resourceCreationParams -Force
            Log-Output "Registration resource created: $(ConvertTo-Json $registrationResource)"
            break
        }
        catch
        {
            Log-Warning "Creation of Azure resource failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)
}

<#
.SYNOPSIS

Retrieves the ActivationKey from the registration resource created during Register-AzsEnvironment

#>
Function Get-RegistrationActivationKey{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName
    )

    
    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 

    do 
    {
        try 
        {
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
        catch
        {
            Log-Warning "Retrieval of activation key failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)
}

<#
.SYNOPSIS

Configures bridge from AzureStack to Azure through use of a service principal.

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
            Log-Output "Creating Azure Active Directory service principal in tenant '$TenantId' Attempt $currentAttempt of $maxAttempt"
            $servicePrincipal = Invoke-Command -Session $PSSession -ScriptBlock { New-AzureBridgeServicePrincipal -RefreshToken $using:RefreshToken -AzureEnvironment $using:AzureEnvironmentName -TenantId $using:TenantId }
            Log-Output "Service principal created and Azure bridge configured. ObjectId: $($servicePrincipal.ObjectId)"
            return $servicePrincipal
        }
        catch
        {
            Log-Warning "Creation of service principal failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction  $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)
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

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 
    do
    {
        try
        {
            $registrationResource = Get-AzureRmResource -ResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$RegistrationName"

            $RoleAssigned = $false
            $RoleName = "Azure Stack Registration Owner"

            Log-Output "Setting $RoleName role on '$($RegistrationResource.ResourceId)'"

            # Determine if RBAC role has been assigned
            $roleAssignmentScope = "/subscriptions/$($RegistrationResource.SubscriptionId)/resourceGroups/$($RegistrationResource.ResourceGroupName)/providers/Microsoft.AzureStack/registrations/$($RegistrationResource.ResourceName)"
            $roleAssignments = Get-AzureRmRoleAssignment -Scope $roleAssignmentScope -ObjectId $ServicePrincipal.ObjectId

            foreach ($role in $roleAssignments)
            {
                if ($role.RoleDefinitionName -eq $RoleName)
                {
                    $RoleAssigned = $true
                }
            }

            if (-not $RoleAssigned)
            {        
                New-AzureRmRoleAssignment -Scope $roleAssignmentScope -RoleDefinitionName $RoleName -ObjectId $ServicePrincipal.ObjectId
            }
            break
        }
        catch
        {
            Log-Warning "Assignment of custom RBAC Role $RoleName failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction  $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)
}

<#

.SYNOPSIS

Activates features in AzureStack according to the properties in the activation key

#>
function Activate-AzureStack{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession] $Session,

        [Parameter(Mandatory = $true)]
        [PSObject] $ActivationKey
    )

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 
    do
    {
        try
        {
            $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:ActivationKey }
            break
        }
        catch
        {
            Log-Warning "Activation of Azure Stack features failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
            } 
        }
    } while ($currentAttempt -lt $maxAttempt)
}

<#

.SYNOPSIS

Gathers required data from current Azure Powershell context

#>
function Get-AzureAccountInfo{
[CmdletBinding()]
    param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [PSObject] $AzureContext
    )
    
    Log-Output "Gathering info from current Azure Powershell context..."

    $azureContextDetails = @{
        Account          = $AzureContext.Account
        Environment      = $AzureContext.Environment
        Subscription     = $AzureContext.Subscription
        Tenant           = $AzureContext.Tenant
    }

    if (-not($AzureContext.Subscription))
    {
        Log-Output "Current Azure context:`r`n$(ConvertTo-Json $azureContextDetails)"
        Log-Throw -Message "Current Azure context is not currently set. Please call Login-AzureRmAccount to set the Azure context." -CallingFunction  $PSCmdlet.MyInvocation.MyCommand.Name
    }

    $AzureEnvironment = $AzureContext.Environment
    $AzureSubscription = $AzureContext.Subscription

    $tokens = @()
    try{$tokens += [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache.ReadItems()}catch{}
    try{$tokens += [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()}catch{}
    try{$tokens += $AzureContext.TokenCache.ReadItems()}catch{}

    if (-not $tokens -or ($tokens.Count -le 0))
    {
        Log-Throw -Message "Token cache is empty `r`n$($_)" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }

    $token = $tokens |
        Where Resource -EQ $AzureEnvironment.ActiveDirectoryServiceEndpointResourceId |
        Where { $_.TenantId -eq $AzureSubscription.TenantId } |
        Sort ExpiresOn |
        Select -Last 1

    if (-not $token)
    {
        Log-Throw -Message "Token not found for tenant id $($AzureSubscription.TenantId) and resource $($AzureEnvironment.ActiveDirectoryServiceEndpointResourceId)." -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }

    Log-Output "Current Azure Context: `r`n $(ConvertTo-Json $azureContextDetails)"
    return @{
        TenantId = $AzureSubscription.TenantId
        Token = $token
    }
}

<#

.SYNOPSIS

Creates a powershell session with the PrivilegedEndpoint for registration actions

#>
function Initialize-PrivilegedEndpointSession{
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory=$true)]
        [PSCredential] $CloudAdminCredential
    )

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10
    do
    {
        try
        {
            Log-Output "Initializing session with privileged endpoint: $PrivilegedEndpoint. Attempt $currentAttempt of $maxAttempt"
            $session = New-PSSession -ComputerName $PrivilegedEndpoint -ConfigurationName PrivilegedEndpoint -Credential $CloudAdminCredential
            Log-Output "Connection to $PrivilegedEndpoint successful"
            return $session
        }
        catch
        {
            Log-Warning "Creation of session with $PrivilegedEndpoint failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)
}

<#

.SYNOPSIS

Registers the AzureStack resource provider in this environment

#>
function Register-AzureStackResourceProvider{
[CmdletBinding()]

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10
    do
    {
        try
        {
            Log-Output "Registering Azure Stack resource provider."
            [Version]$azurePSVersion = (Get-Module AzureRm.Resources).Version
            if ($azurePSVersion -ge [Version]"4.3.2")
            {
                Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.AzureStack" | Out-Null
                Log-Output "Resource provider registered."
                break
            }
            else
            {
                Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.AzureStack" -Force | Out-Null
                Log-Output "Resource provider registered."
                break
            }
        }
        Catch
        {
            Log-Warning "Registering Azure Stack resource provider failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)
}

<#

.SYNOPSIS

Removes the specified registration resource from Azure

#>
function Remove-RegistrationResource{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $ResourceId
    )
    
    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 
    do
    {
        try
        {
            Remove-AzureRmResource -ResourceId $ResourceId -Force -Verbose
            break
        }
        catch
        {
            Log-Warning "Removal of registration resource failed:`r`n$($_)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)
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
        $minVersion = [Version]"1.0.170828.1"
        if ([Version]$stampInfo.StampVersion -lt $minVersion) {
            Log-Throw -Message "Script only applicable for Azure Stack builds $minVersion or later." -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
        }

        Log-Output -Message "Running registration actions on build $($stampInfo.StampVersion). Cloud Id: $($stampInfo.CloudID), Deployment Id: $($stampInfo.DeploymentID)"
        return $stampInfo
    }
    Catch
    {
        Log-Throw "An error occurred checking stamp information: `r`n$($_)" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
    Log-Output "*** WARNING ***"
    "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message" | Out-File $Global:AzureRegistrationLog -Append
    Write-Warning "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message"
    Log-Output "*** End WARNING ***"
}

<#

.SYNOPSIS

Appends the error text passed in to a log file throws an exception.

#>
function Log-Throw{
[CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Object] $Message,

        [Parameter(Mandatory=$true)]
        [String] $CallingFunction
    )

    $errorLine = "************************ Error ************************"

    # Write Error line seperately otherwise out message will not contain stack trace
    "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $errorLine" | Out-File $Global:AzureRegistrationLog -Append
    Write-Verbose "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $errorLine"

    Log-Output $Message
    Log-Output $Message.ScriptStacktrace

    Log-OutPut "*********************** Ending registration action during $CallingFunction ***********************`r`n"

    "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): Logs can be found at: $Global:AzureRegistrationLog  and  \\$PrivilegedEndpoint\c$\maslogs `r`n" | Out-File $Global:AzureRegistrationLog -Append
    Write-Verbose "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): Logs can be found at: $Global:AzureRegistrationLog  and  \\$PrivilegedEndpoint\c$\maslogs `r`n" 

    throw $Message
}

#endregion

# Disconnected functions
Export-ModuleMember Get-AzsRegistrationToken
Export-ModuleMember Register-AzsEnvironment
Export-ModuleMember Unregister-AzsEnvironment
Export-ModuleMember Get-AzsRegistrationName

# Connected functions
Export-ModuleMember Set-AzsRegistration
Export-ModuleMember Remove-AzsRegistration
