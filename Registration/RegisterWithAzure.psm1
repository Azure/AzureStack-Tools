# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#

This module contains functions for registering your environment and enabling marketplace syndication / usage reporting. 
To run registration and activation functions you must have a public Azure subscription of any type.
You must also have access to an account / directory that is an owner or contributor to that subscription.

#>

# Generate log file(s)
function New-RegistrationLogFile
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [String] $LogDate = (Get-Date -Format yyyy-MM-dd),

        [Parameter(Mandatory=$false)]
        [String] $RegistrationFunction = 'RegistrationOperation'
    )

    # Create log folder
    $LogFolder = "$env:SystemDrive\MASLogs\Registration"
    if (-not (Test-Path $LogFolder -PathType Container))
    {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }

    $logFilePath = "$LogFolder\AzureStack.Activation.$RegistrationFunction-$LogDate.log"
    Write-Verbose "Writing logs to file: $logFilePath"
    if (-not (Test-Path $logFilePath -PathType Leaf))
    {
        $null = New-Item -Path $logFilePath -ItemType File -Force
    }

    $Script:registrationLog = $logFilePath
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

.PARAMETER PrivilegedEndpointCredential

Powershell object that contains credential information i.e. user name and password.The Azure Stack administrator has access to the Privileged Endpoint VM (also known as Emergency Console) to call whitelisted cmdlets and scripts.
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

.PARAMETER RegistrationName

The name of the registration resource to be created in Azure. A unique name is highly encouraged for those registering multiple environments.

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication, and enables usage reporting to Azure.

Set-AzsRegistration -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint "Azs-ERCS01"

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication, and enables usage reporting to Azure, and supplies a custom name.

Set-AzsRegistration -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint "Azs-ERCS01" -RegistrationName "AzsRegistration-TestEnvironment"

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication, and disables usage reporting to Azure.

Set-AzsRegistration -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint "Azs-ERCS01" -BillingModel 'Capacity' -UsageReportingEnabled:$false -AgreementNumber $MyAgreementNumber

.EXAMPLE

This example registers your AzureStack environment with Azure, enables syndication and usage and gives a specific name to the resource group

Set-AzsRegistration -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint "Azs-ERCS02" -ResourceGroupName "ContosoStackRegistrations"

.EXAMPLE

This example disables syndication and disables usage reporting to Azure. Note that usage will still be collected, just not sent to Azure.

Set-AzsRegistration -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint "Azs-ERCS01" -BillingModel Capacity -MarketplaceSyndicationEnabled:$false -UsageReportingEnabled:$false -AgreementNumber $MyAgreementNumber

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
        [PSCredential] $PrivilegedEndpointCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzContext),

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = (Get-DefaultResourceGroupLocation -AzureEnvironment $AzureContext.Environment.Name),
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development','Custom')]
        [string] $BillingModel = 'Development',

        [Parameter(Mandatory = $false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory = $false)]
        [switch] $UsageReportingEnabled = @{'Capacity'=$true; 
                                            'PayAsYouUse'=$true; 
                                            'Development'=$true; 
                                            'Custom'=$false}[$BillingModel],

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $AgreementNumber,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string] $MsAssetTag
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    Validate-ResourceGroupLocation -ResourceGroupLocation $ResourceGroupLocation
    Log-AzureAccountInfo -AzureContext $AzureContext

    try
    {
        $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -PrivilegedEndpointCredential $PrivilegedEndpointCredential -Verbose
        $stampInfo = Confirm-StampVersion -PSSession $session

        # Configure Azure Bridge
        $refreshToken = (Get-AzToken -Context $AzureContext -FromCache -Verbose).GetRefreshToken()
        $servicePrincipal = New-ServicePrincipal -RefreshToken $refreshToken -AzureEnvironmentName $AzureContext.Environment.Name -TenantId $AzureContext.Subscription.TenantId -PSSession $session

        # Get registration token
        $getTokenParams = @{
            BillingModel                  = $BillingModel
            MarketplaceSyndicationEnabled = $MarketplaceSyndicationEnabled
            UsageReportingEnabled         = $UsageReportingEnabled
            AgreementNumber               = $AgreementNumber
            MsAssetTag                    = $MsAssetTag
        }
        Log-Output "Get-RegistrationToken parameters: $(ConvertTo-Json $getTokenParams)"
        if (($BillingModel -eq 'Capacity') -and ($UsageReportingEnabled))
        {
            Log-Warning "Billing model is set to Capacity and Usage Reporting is enabled. This data will be used to guide product improvements and will not be used for billing purposes. If this is not desired please halt this operation and rerun with -UsageReportingEnabled:`$false. Execution will continue in 20 seconds."
            Start-Sleep -Seconds 20        
        }
        $registrationToken = Get-RegistrationToken @getTokenParams -Session $session -StampInfo $stampInfo
    
        # Register environment with Azure

        Log-Output "Creating registration resource at ResourceGroupLocation: $ResourceGroupLocation"
        New-RegistrationResource -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -RegistrationToken $RegistrationToken -RegistrationName $RegistrationName

        # Assign custom RBAC role
        Log-Output "Assigning custom RBAC role to resource $RegistrationName"
        New-RBACAssignment -SubscriptionId $AzureContext.Subscription.SubscriptionId -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName -ServicePrincipal $servicePrincipal

        # Activate AzureStack syndication / usage reporting features
        $activationKey = Get-AzsActivationkey -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName -ConnectedScenario
        Log-Output "Activating Azure Stack (this may take up to 10 minutes to complete)."
        Activate-AzureStack -Session $session -ActivationKey $ActivationKey
    }
    finally
    {
        if ($session)
        {
            Log-OutPut "Removing any existing PSSession..."
            $session | Remove-PSSession
        }
    }

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

.PARAMETER PrivilegedEndpointCredential

Powershell object that contains credential information i.e. user name and password. The Azure Stack administrator has access to the JEA Computer (also known as Emergency Console) to call whitelisted cmdlets and scripts.
If not supplied script will request manual input of username and password

.PARAMETER PrivilegedEndpoint

Privileged Endpoint VM that performs environment administration actions. Also known as Emergency Console VM.(Example: AzS-ERCS01 for the ASDK)

.PARAMETER ResourceGroupName

This is the name of the resource group in Azure where the registration resource has been created. Defaults to "azurestack"

.PARAMETER RegistrationName

The name of the registration resource that was created in Azure. If you have a unique name you should supply it here for removing registration.

.EXAMPLE

This example unregisters your AzureStack environment with Azure.

Remove-AzsRegistration -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint $PrivilegedEndpoint

.EXAMPLE

This example unregisters your AzureStack environment with Azure by pointing to a specific registration

Remove-AzsRegistration -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint $PrivilegedEndpoint -RegistrationName "AzsRegistration-TestEnvironment"

.NOTES

It is very important to ensure you are logged in to the correct Azure Account in Powershell before running this function.

#>
function Remove-AzsRegistration{
[CmdletBinding()]
    param(
    [Parameter(Mandatory = $true)]
        [PSCredential] $PrivilegedEndpointCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzContext)
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    Log-AzureAccountInfo -AzureContext $AzureContext
    try
    {
        $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -PrivilegedEndpointCredential $PrivilegedEndpointCredential -Verbose
        $stampInfo = Confirm-StampVersion -PSSession $session

        # Find registration resource in Azure
        Log-Output "Searching for registration resource in Azure..."
        $registrationResource = $null

        $registrationResourceId = "/subscriptions/$($AzureContext.Subscription.SubscriptionId)/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$registrationName"
        $registrationResource = Get-AzResource -ResourceId $registrationResourceId -ErrorAction Ignore
        if ($registrationResource.Properties.cloudId -eq $stampInfo.CloudId)
        {
            Log-Output "Registration resource found: $($registrationResource.ResourceId)"
        }
        else
        {
            Log-Throw "The registration resource found does not correlate the current environment's Cloud-Id. `r`nEnvironment Cloud Id: $($stampinfo.CloudId) `r`nResource Cloud Id: $($registrationResource.Properties.cloudId)" -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
        }
    
        if ($registrationResource)
        {
            Log-Output "Resource found. Deactivating Azure Stack and removing resource: $($registrationResource.ResourceId)"

            Log-Output "De-Activating Azure Stack (this may take up to 10 minutes to complete)."
            DeActivate-AzureStack -Session $session
        
            Log-Output "Your environment is now unable to syndicate items and is no longer reporting usage data"

            # Remove registration resource from Azure
            Log-Output "Removing registration resource from Azure..."
            Remove-RegistrationResource -ResourceId $registrationResource.ResourceId -ResourceGroupName $ResourceGroupName
        }
        else
        {
            Log-Throw -Message "Registration resource with matching CloudId property $($stampInfo.CloudId) was not found. Please ensure a registration resource exists in the provided subscription & resource group." -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
        }   
    }
    finally
    {
        if ($session)
        {
            Log-OutPut "Removing any existing PSSession..."
            $session | Remove-PSSession
        }
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

.PARAMETER PrivilegedEndpointCredential

Powershell object that contains credential information i.e. user name and password.The Azure Stack administrator has access to the privileged endpoint to call approved cmdlets and scripts.
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
$registrationToken = Get-AzsRegistrationToken -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development -TokenOutputFilePath "C:\Temp\RegistrationToken.txt"

.NOTES

This function is designed to only be used in conjunction with Register-AzsEnvironment. This will not enable any Azure Stack marketplace syndication or usage reporting features. Example:

$registrationToken = Get-AzsRegistrationToken -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development -TokenOutputFilePath "C:\Temp\RegistrationToken.txt"
Register-AzsEnvironment -PrivilegedEndpointCredential $PrivilegedEndpointCredential -PrivilegedEndpoint $PrivilegedEndpoint -RegistrationToken $registrationToken

#>
Function Get-AzsRegistrationToken{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $PrivilegedEndpointCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Capacity', 'Development','Custom')]
        [string] $BillingModel = 'Capacity',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String] $TokenOutputFilePath,

        [Parameter(Mandatory = $false)]
        [Switch] $UsageReportingEnabled = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $MarketplaceSyndicationEnabled = $false,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $AgreementNumber,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string] $MsAssetTag
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name

    if(($BillingModel -eq 'Capacity') -and ([String]::IsNullOrEmpty($AgreementNumber)))
    {
        Log-Throw -Message "Agreement number is null or empty when BillingModel is set to Capacity" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }

    if (($BillingModel -eq 'Capacity') -and ($UsageReportingEnabled))
    {
        Log-Warning "Billing model is set to Capacity and Usage Reporting is enabled. This data will be used to guide product improvements and will not be used for billing purposes. If this is not desired please halt this operation and rerun with -UsageReportingEnabled:`$false. Execution will continue in 20 seconds."
        Start-Sleep -Seconds 20     
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
        PrivilegedEndpointCredential  = $PrivilegedEndpointCredential
        PrivilegedEndpoint            = $PrivilegedEndpoint
        BillingModel                  = $BillingModel
        MarketplaceSyndicationEnabled = $MarketplaceSyndicationEnabled
        UsageReportingEnabled         = $UsageReportingEnabled
        AgreementNumber               = $AgreementNumber
        TokenOutputFilePath           = $TokenOutputFilePath
        MsAssetTag                    = $MsAssetTag
    }

    Log-Output "Registration action params: $(ConvertTo-Json $params)"

    try
    {
        $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -PrivilegedEndpointCredential $PrivilegedEndpointCredential -Verbose
        $registrationToken = Get-RegistrationToken @params -Session $session
    }
    finally
    {
        if ($session)
        {
            Log-OutPut "Removing any existing PSSession..."
            $session | Remove-PSSession
        }
    }

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

.PARAMETER RegistrationName

The name of the registration resource to be created in Azure. A unique name is highly encouraged for those registering multiple environments.

.EXAMPLE

This example will register your Azure Stack environment with all default parameters.

Register-AzsEnvironment -RegistrationToken $registrationToken

.EXAMPLE

This example will register your Azure Stack environment with a specific name for a resource group

Register-AzsEnvironment -RegistrationToken $registrationToken -ResourceGroupName "ContosoRegistrations"

.EXAMPLE

This example will register your Azure Stack environment with a specific name for the registration resource

Register-AzsEnvironment -RegistrationToken $registrationToken -RegistrationName "AzsRegistration-TestEnvironment"

.NOTES

This function will not enable marketplace syndication or usage reporting.

#>
Function Register-AzsEnvironment{
[CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [String] $RegistrationToken,

        [Parameter(Mandatory = $true)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzContext),

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = (Get-DefaultResourceGroupLocation -AzureEnvironment $AzureContext.Environment.Name)
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    Validate-ResourceGroupLocation -ResourceGroupLocation $ResourceGroupLocation
    Log-AzureAccountInfo -AzureContext $AzureContext
    New-RegistrationResource -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -RegistrationToken $RegistrationToken -RegistrationName $RegistrationName

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

.EXAMPLE

This example will unregister your Azure Stack environment using a registration token

UnRegister-AzsEnvironment -RegistrationToken $registrationToken

.EXAMPLE

This exmple will unregister your Azure Stack environment using the registration name.

UnRegister-AzsEnvironment -RegistrationName "AzsRegistration-TestEnvironment"

.NOTES

This should only be used if Register-AzsEnvironment was called previously. If you would like to disable syndication or usage reporting
that was enabled during Set-AzsRegistration, then you will need to run Remove-AzsRegistration

#>
Function UnRegister-AzsEnvironment{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzContext),

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [String] $RegistrationToken,

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $CloudId
    )
   
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    if ((-not $RegistrationToken) -and (-not $CloudId))
    {
        if (-not $RegistrationName)
        {
            Log-Throw "Unable to find registration resource with the given parameters. Please provide one of the following: RegistrationName, RegistrationToken, or CloudId" -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
        }
    }

    if ($RegistrationToken)
    {
        # Get CloudId from registration token
        try 
        {
            $bytes = [System.Convert]::FromBase64String($RegistrationToken)
            $tokenObject = [System.Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
            $CloudId = $tokenObject.CloudId
        }
        Catch
        {
            Log-Warning "Unable to extract CloudId from provided registration token. Please confirm the input text for the token is correct."
        }
    }

    Log-AzureAccountInfo -AzureContext $AzureContext

    # Find registration resource in Azure
    Log-Output "Searching for registration resource in Azure..."
    $registrationResource = $null
    if ($RegistrationName)
    {
        $registrationResourceId = "/subscriptions/$($AzureContext.Subscription.SubscriptionId)/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$registrationName"
        $registrationResource = Get-AzResource -ResourceId $registrationResourceId -ErrorAction Ignore
    }
    elseif ($CloudId)
    {
        Log-Output "Parameter 'RegistrationName' not supplied. Searching through all registration resources under current context."
        try
        {
            Log-Output "Attempting to retrieve resources using command: 'Find-AzResource -ResourceType Microsoft.AzureStack/registrations -ResourceGroupNameEquals $ResourceGroupName'"
            $registrationResources = Find-AzResource -ResourceType Microsoft.AzureStack/registrations -ResourceGroupNameEquals $ResourceGroupName
        }
        catch
        {
            Log-Warning "Could not retrieve resources from Azure `r`n$($_)"
        }

        if ($registrationResources.Count -eq 0)
        {
            try
            {
                Log-Output "Attempting to retrieve resources using command: 'Get-AzResource -ResourceType microsoft.azurestack/registrations -ResourceGroupName $ResourceGroupName'"
                $registrationresources = Get-AzResource -ResourceType microsoft.azurestack/registrations -ResourceGroupName $ResourceGroupName
            }
            catch
            {
                Log-Throw "Unable to retrieve registration resource(s) from Azure `r`n$($_)" -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
            }
        }

        Log-Output "Found $($registrationResources.Count) registration resources. Finding a matching CloudId may take some time."
        foreach ($resource in $registrationResources)
        {
            $resourceObject = Get-AzResource -ResourceId "/subscriptions/$($AzureContext.Subscription.SubscriptionId)/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$($resource.name)"
            $resourceCloudId = $resourceObject.Properties.CloudId
            if ($resourceCloudId -eq $stampInfo.CloudId)
            {
                $registrationResource = $resourceObject
                break   
            }
        }
    }
    
    if ($registrationResource)
    {
        Log-Output "Found registration resource in Azure: $($registrationResource.ResourceId)"
        Log-Output "Removing registration resource from Azure..."
        Remove-RegistrationResource -ResourceId $registrationResource.ResourceId -ResourceGroupName $ResourceGroupName
    }
    else
    {
        Log-Throw "Registration resource not found in Azure with the provided parameters. `r`nPlease ensure a valid registration exists in the subscription / resource group provided." -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
    }

    Log-Output "Your Azure Stack environment is now unregistered from Azure."
    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"
}

<#
.SYNOPSIS

Retrieves the ActivationKey from the registration resource created during Register-AzsEnvironment

.DESCRIPTION

This gets an activation key with details on the parameters and environment information from the registration resource. 
The activation key is used to create an activation record in AzureStack.

.PARAMETER RegistrationName

The neame of the registration resource created in Azure.

.PARAMETER ResourceGroupName

The name of the resource group where the registration resource was created.

#>
Function Get-AzsActivationKey{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzContext),

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $KeyOutputFilePath, 

        [Parameter(Mandatory = $false)]
        [Switch] $ConnectedScenario
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    if (-not $ConnectedScenario)
    {
        New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    Log-AzureAccountInfo -AzureContext $AzureContext

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
            $actionResponse = Invoke-AzResourceAction @resourceActionparams -Force
            Log-Output "Activation key successfully retrieved."

            if ($KeyOutputFilePath)
            {
                Log-Output "Activation key will be written to: $KeyOutputFilePath"
                $actionResponse.ActivationKey | Out-File $KeyOutputFilePath -Force
            }

            Log-Output "Your activation key has been collected."
            Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"

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

Creates the activation resource in Azure Stack

.DESCRIPTION

Creates an activation resource in Azure Stack in the resource group 'azurestack'. Also configures usage and syndication options. 

.PARAMETER PrivilegedEndpointCredential

Powershell object that contains credential information i.e. user name and password.The Azure Stack administrator has access to the privileged endpoint to call approved cmdlets and scripts.
This parameter is mandatory and if not supplied then this function will request manual input of username and password

.PARAMETER PrivilegedEndpoint

The name of the VM that has permissions to perform approved powershell cmdlets and scripts. Usually has a name in the format of <ComputerName>-ERCSxx where <ComputerName>
is the name of the machine and ERCS is followed by a number between 01 and 03. Example: Azs-ERCS01 (from the ASDK)

.PARAMETER ActivationKey

The text output of Get-AzsActivationKey. Contains information required to configure Azure Stack registration appropriately. 

#>
Function New-AzsActivationResource{
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [PSCredential] $PrivilegedEndpointCredential,

    [Parameter(Mandatory = $true)]
    [String] $PrivilegedEndpoint,

    [Parameter(Mandatory = $true)]
    [String] $ActivationKey
)

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    try
    {
        $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -PrivilegedEndpointCredential $PrivilegedEndpointCredential -Verbose
        
        Log-Output "Activating Azure Stack (this may take up to 10 minutes to complete)."
        Activate-AzureStack -Session $session -ActivationKey $ActivationKey
    }
    finally
    {
        if ($session)
        {
            Log-OutPut "Removing any existing PSSession..."
            $session | Remove-PSSession
        }
    }


    Log-OutPut "Your environment has finished the registration and activation process."

    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"
}

<#
.SYNOPSIS

De-activates Azure Stack in Disconnected Environments

.DESCRIPTION

Takes Azure Stack PrivilegedEndpoint and PrivilegedEndpoint credential as input, and deactivates the activation properties created by New-AzsActivationResource

#>
Function Remove-AzsActivationResource{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $PrivilegedEndpointCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    try
    {
        $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -PrivilegedEndpointCredential $PrivilegedEndpointCredential -Verbose
        Log-Output "Successfully initialized session with endpoint: $PrivilegedEndpoint"
        Log-Output "De-Activating Azure Stack (this may take up to 10 minutes to complete)."
        Invoke-Command -Session $session -ScriptBlock { Remove-AzureStackActivation }
    }
    catch
    {
        Log-Throw -Message "An error occurred during removal of the activation resource in Azure Stack: `r`n$_" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }
    finally
    {
        if ($session)
        {
            $session | Remove-PSSession
        }
    }

    Log-Output "Successfully de-activated Azure Stack"
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

Returns an object, RegistrationDetails, that contains a RegisrationToken and RegistrationName for use in Register-AzsEnvironment

#>
Function Get-RegistrationToken{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCredential] $PrivilegedEndpointCredential,

        [Parameter(Mandatory = $false)]
        [String] $PrivilegedEndpoint,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development','Custom')]
        [string] $BillingModel = 'Development',

        [Parameter(Mandatory = $false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory = $false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $AgreementNumber,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Runspaces.PSSession] $Session,

        [Parameter(Mandatory = $false)]
        [PSObject] $StampInfo,

        [Parameter(Mandatory = $false)]
        [String] $TokenOutputFilePath,

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string] $MsAssetTag
    )

    if (-not $StampInfo)
    {
        $StampInfo = Confirm-StampVersion -PSSession $session
    }

    $StampVersion = $StampInfo.StampVersion
    $CustomBillingModelVersion = [Version]"1.1912.0.19"
    if( ($StampVersion -lt $CustomBillingModelVersion) -and ($BillingModel -eq 'Custom') ){
        Log-Throw -Message "Custom BillingModel is not supported for StampVersion less than $CustomBillingModelVersion" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }
    
    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 
    do
    {
        try
        {
            Log-Output "Creating registration token. Attempt $currentAttempt of $maxAttempt"
            if( $StampVersion -ge $CustomBillingModelVersion){
                $registrationToken = Invoke-Command -Session $session -ScriptBlock { New-RegistrationToken -BillingModel $using:BillingModel -MarketplaceSyndicationEnabled:$using:MarketplaceSyndicationEnabled -UsageReportingEnabled:$using:UsageReportingEnabled -AgreementNumber $using:AgreementNumber -MsAssetTag $using:MsAssetTag }
            } else{
                $registrationToken = Invoke-Command -Session $session -ScriptBlock { New-RegistrationToken -BillingModel $using:BillingModel -MarketplaceSyndicationEnabled:$using:MarketplaceSyndicationEnabled -UsageReportingEnabled:$using:UsageReportingEnabled -AgreementNumber $using:AgreementNumber }
            }
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

<#
.SYNOPSIS

Uses information from Get-AzsRegistrationToken to create registration resource group and resource in Azure

#>
function New-RegistrationResource{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'westcentralus',

        [Parameter(Mandatory = $false)]
        [String] $RegistrationToken
    )

    Validate-ResourceGroupLocation -ResourceGroupLocation $ResourceGroupLocation
    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 

    Register-AzureStackResourceProvider

    $resourceCreationParams = @{
        ResourceGroupName = $ResourceGroupName
        Location          = 'Global'
        ResourceName      = $RegistrationName
        ResourceType      = "Microsoft.AzureStack/registrations"
        ApiVersion        = "2017-06-01" 
        Properties        = @{ registrationToken = "$registrationToken" }
    }

    Log-Output "Resource creation params: $(ConvertTo-Json $resourceCreationParams)"
    $resourceType = 'Microsoft.Azurestack/registrations'
    do
    {
        try
        {
                         
            ## Remove any existing locks on the resource group
           
            $lock = Get-AzResourceLock -LockName 'RegistrationResourceLock' -ResourceGroupName $ResourceGroupName -ResourceType $resourceType -ResourceName $RegistrationName -ErrorAction SilentlyContinue
            if ($lock)
            {
                Write-Verbose "Unlocking Registration resource lock  'RegistrationResourceLock'..." -Verbose
                Remove-AzResourceLock -LockId $lock.LockId -Force
            }

            Log-Output "Creating resource group '$ResourceGroupName' in location $ResourceGroupLocation."
            $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force

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
            $registrationResource = New-AzResource @resourceCreationParams -Force
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

    
    ## Registration resource is needed for syndication. Placing resource lock to prevent accidental deletion.
    Write-Verbose -Message "Registration resource $RegistrationName is needed for syndication. Placing resource lock to prevent accidental deletion."
    $lockNotes ="Registration resource $RegistrationName is needed for syndication. Placing resource lock to prevent accidental deletion."
    New-AzResourceLock -LockLevel CanNotDelete `
                     -LockNotes $lockNotes `
                     -LockName 'RegistrationResourceLock' `
                     -ResourceName $RegistrationName `
                     -ResourceGroupName $ResourceGroupName `
                     -ResourceType $resourceType `
                     -Force -Verbose
    Write-Verbose -Message "Resource lock placed successfully."
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
            $servicePrincipal = Invoke-Command -Session $PSSession -ScriptBlock { New-AzureBridgeServicePrincipal -RefreshToken $using:RefreshToken -AzureEnvironment $using:AzureEnvironmentName -TenantId $using:TenantId -TimeoutInSeconds 1800}
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
                $registrationResource = Get-AzResource -ResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$RegistrationName"
    
                $RoleAssigned = $false
                $RoleName = "Azure Stack Registration Owner"
    
                Log-Output "Setting $RoleName role on '$($RegistrationResource.ResourceId)'"
    
                # Determine if RBAC role has been assigned
                $roleAssignmentScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$($RegistrationResource.Name)"
                $roleAssignments = Get-AzRoleAssignment -Scope $roleAssignmentScope -ObjectId $ServicePrincipal.ObjectId
    
                foreach ($role in $roleAssignments)
                {
                    if ($role.RoleDefinitionName -eq $RoleName)
                    {
                        $RoleAssigned = $true
                    }
                }
    
                if (-not $RoleAssigned)
                {        
                    New-AzRoleAssignment -Scope $roleAssignmentScope -RoleDefinitionName $RoleName -ObjectId $ServicePrincipal.ObjectId
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
            $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:ActivationKey -TimeoutInSeconds 1800}
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

DeActivates features in AzureStack

#>
function DeActivate-AzureStack{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession] $Session
    )

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 
    do
    {
        try
        {
            $activation = Invoke-Command -Session $session -ScriptBlock { Remove-AzureStackActivation }
            break
        }
        catch
        {
            Log-Warning "DeActivation of Azure Stack features failed:`r`n$($_)"
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

function Get-AzToken
{
    [CmdletBinding(DefaultParameterSetName='default')]
    param
    (
        # The Azure PowerShell context representing the context of a token to be resolved.
        [Parameter()]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext] $Context = (Get-AzContext -ErrorAction Stop),

        # The target resource for which a token should be resolved.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Resource = ($Context.Environment.ActiveDirectoryServiceEndpointResourceId),

        # The target tenantId in which a token should be resolved.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $TenantId = ($t = if ($Context.Tenant) {$Context.Tenant} else {$Context.Subscription.TenantId}),

        # The account for which a token should be resolved.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $AccountId = ($Context.Account.Id),

        # Indicates that target token should be resolved from existing cache data (including a refresh token, if one is available).
        [Parameter(Mandatory=$true, ParameterSetName='FromCache')]
        [switch] $FromCache,

        # Indicates that all token cache data should be returned.
        [Parameter(ParameterSetName='FromCache')]
        [switch] $Raw
    )

    $originalErrorActionPreference = $ErrorActionPreference
    try
    {
        $ErrorActionPreference = 'Stop'

        Write-Verbose "Attempting to retrieve a token for account '$AccountId' in tenant '$TenantId' for resource '$Resource'..."

        if (-not $FromCache)
        {
            $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate(
                ($account            = $Context.Account),
                ($environment        = $Context.Environment),
                ($tenant             = $TenantId),
                ($password           = $null),
                ($promptBehavior     = 'Never'),
                ($promptAction       = $null),
                ($tokenCache         = $null),
                ($resourceIdEndpoint = $Resource))

            return [pscustomobject]@{ AccessToken = ConvertTo-SecureString $token.AccessToken -AsPlainText -Force } |
                Add-Member -MemberType ScriptMethod -Name 'GetAccessToken' -Value { return [System.Net.NetworkCredential]::new('$tokenType', $this.AccessToken).Password } -PassThru
        }
        else
        {
            Write-Warning "Attempting to find a refresh token and an access token from the existing token cache data..."
        }

        #
        # Resolve token cache data
        #

        [Microsoft.Azure.Commands.Common.Authentication.Authentication.Clients.AuthenticationClientFactory]$authenticationClientFactory = $null
        if (-not ([Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TryGetComponent(
            [Microsoft.Azure.Commands.Common.Authentication.Authentication.Clients.AuthenticationClientFactory]::AuthenticationClientFactoryKey,
            [ref]$authenticationClientFactory)))
        {
            $m = 'Please ensure you have authenticated with Az Accounts module!'
            $m += ' Unable to resolve authentication client factory from Az Accounts module runtime'
            $m += ' ([Microsoft.Azure.Commands.Common.Authentication.Authentication.Clients.AuthenticationClientFactory])'
            Write-Error $m
            return
        }

        $client = $authenticationClientFactory.CreatePublicClient(
            ($clientId='1950a258-227b-4e31-a9cf-717495945fc2'),
            ($TenantId),
            ($authority="$($Context.Environment.ActiveDirectoryAuthority.TrimEnd('/'))/$TenantId"),
            ($redirectUri='urn:ietf:wg:oauth:2.0:oob'),
            ($useAdfs=$Context.Environment.ActiveDirectoryAuthority -like '*/adfs*'))

        $authenticationClientFactory.RegisterCache($client)

        $accounts = $client.GetAccountsAsync().ConfigureAwait($true).GetAwaiter().GetResult()

        $bytes = ([Microsoft.Identity.Client.ITokenCacheSerializer]$client.UserTokenCache).SerializeMsalV3()
        $json  = [System.Text.Encoding]::UTF8.GetString($bytes)
        $data  =  ConvertFrom-Json $json

        Write-Debug "MSAL token cache deserialized ($($bytes.Length) bytes); Looking for target tokens..."

        if ($Raw)
        {
            Write-Warning "Returning raw token cache data!"
            Write-Output $data
            return
        }

        #
        # Resolve target account
        #

        $targetAccount = $accounts | Where Username -EQ $AccountId

        if (-not $targetAccount -or $targetAccount.Count -gt 1)
        {
            Write-Error "Unable to resolve acccount for identity '$AccountId'; available accounts: $(ConvertTo-Json $accounts.Username -Compress)"
            return
        }

        Write-Verbose "Target account resolved to: $(ConvertTo-Json $targetAccount -Compress)"

        #
        # Resolve target token(s)
        #

        $resolvedRefreshToken = $data.RefreshToken."$(Get-Member -InputObject $data.RefreshToken -MemberType NoteProperty |
            Where { "$($_.Name)".StartsWith($targetAccount.HomeAccountId.Identifier, [System.StringComparison]::OrdinalIgnoreCase) } |
            Select -ExpandProperty Name)".secret

        $resolvedAccessToken = Get-Member -InputObject $data.AccessToken -MemberType NoteProperty |
            ForEach { $data.AccessToken."$($_.Name)" } | 
            Where home_account_id -EQ $targetAccount.HomeAccountId.Identifier |
            Where { (-not $_.realm) -or ($_.realm -eq $TenantId) } |
            Where target -Like "*$Resource*" |
            Sort expires_on -Descending |
            Select -First 1 -ExpandProperty secret

        if (-not $resolvedAccessToken -and -not $resolvedRefreshToken)
        {
            Write-Error "Unable to resolve an access token or refresh token for identity '$identityId' with the specified properties..."
            return
        }
        elseif (-not $resolvedAccessToken)
        {
            Write-Warning "Unable to resolve an access token for identity '$identityId' with the specified properties..."
        }
        elseif (-not $resolvedRefreshToken)
        {
            Write-Warning "Unable to resolve a refresh token for identity '$identityId' with the specified properties..."
        }

        $result = [pscustomobject]@{
            AccessToken  = if ($resolvedAccessToken)  {ConvertTo-SecureString $resolvedAccessToken  -AsPlainText -Force} else {$null}
            RefreshToken = if ($resolvedRefreshToken) {ConvertTo-SecureString $resolvedRefreshToken -AsPlainText -Force} else {$null}
        }
    
        return $result |
            Add-Member -MemberType ScriptMethod -Name 'GetAccessToken' -Value { return [System.Net.NetworkCredential]::new('$tokenType', $this.AccessToken).Password } -PassThru |
            Add-Member -MemberType ScriptMethod -Name 'GetRefreshToken' -Value { return [System.Net.NetworkCredential]::new('$tokenType', $this.RefreshToken).Password } -PassThru
    }
    finally
    {
        $ErrorActionPreference = $originalErrorActionPreference
    }
}


<#

.SYNOPSIS

Gathers required data from current Azure Powershell context

#>
function Log-AzureAccountInfo{
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
    Log-Output "Current Azure Context: `r`n $(ConvertTo-Json $azureContextDetails)"
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
        [PSCredential] $PrivilegedEndpointCredential
    )

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10
    do
    {
        try
        {
            Log-Output "Initializing session with privileged endpoint: $PrivilegedEndpoint. Attempt $currentAttempt of $maxAttempt"
            $sessionOptions = New-PSSessionOption -IdleTimeout (3600 * 1000)
            $session = New-PSSession -ComputerName $PrivilegedEndpoint -ConfigurationName PrivilegedEndpoint -Credential $PrivilegedEndpointCredential -SessionOption $sessionOptions
            Log-Output "Connection to $PrivilegedEndpoint successful"
            return $session
        }
        catch
        {
            Log-Warning "Creation of session with $PrivilegedEndpoint failed:`r`n$($_)"

            if ($session)
            {
                Log-OutPut "Removing any existing PSSession..."
                $session | Remove-PSSession
            }

            $currentAttempt++
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
            }
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            Start-Sleep -Seconds $sleepSeconds
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
            Register-AzResourceProvider -ProviderNamespace "Microsoft.AzureStack" | Out-Null
            Log-Output "Resource provider registered."
            break
        }
        Catch
        {
            Log-Warning "Registering Azure Stack resource provider failed:`r`n$($_)"
            $currentAttempt++
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_ -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
            }
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            Start-Sleep -Seconds $sleepSeconds
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
        [String] $ResourceId,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'azurestack'
    )
    
    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 
    do
    {
        try
        {
            ## Remove any existing Resource level lock before deleting the resource
            $existingRegistrationResource = Get-AzResource -ResourceId $ResourceId
            $resourceName = $existingRegistrationResource.Name

            $resourceType = 'Microsoft.Azurestack/registrations'
            $lock = Get-AzResourceLock -LockName 'RegistrationResourceLock' -ResourceGroupName $ResourceGroupName -ResourceType $resourceType -ResourceName $resourceName -ErrorAction SilentlyContinue
            if ($lock)
            {
                Write-Verbose "Removing Registration resource lock  'RegistrationResourceLock'..." -Verbose
                Remove-AzResourceLock -LockId $lock.LockId -Force
            }

            Remove-AzResource -ResourceId $ResourceId -Force -Verbose
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
    }
    Catch
    {
        Log-Throw "An error occurred checking stamp information: `r`n$($_)" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }

    Log-Output -Message "Running registration actions on build $($stampInfo.StampVersion). Cloud Id: $($stampInfo.CloudID), Deployment Id: $($stampInfo.DeploymentID)"
    return $stampInfo
}

<#
.SYNOPSIS
Get the resource group location based on the AzureEnvironment name
#>
function Get-DefaultResourceGroupLocation{
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string] $AzureEnvironment
    )
    return @{'AzureCloud'='westcentralus'; 
            'AzureChinaCloud'='ChinaEast'; 
            'AzureUSGovernment'='usgovvirginia'; 
            'CustomCloud'='westcentralus'}[$AzureEnvironment]  
}

<#
.SYNOPSIS
Check if the selected ResourceGroupLocation is available
#>
function Validate-ResourceGroupLocation{
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupLocation
    )
    $availableLocations = (Get-AzLocation).Location
    if ($availableLocations -notcontains $ResourceGroupLocation){
        throw "ErrorCode: UnknownResourceGroupLocation.`nErrorReason: Resource group location '$ResourceGroupLocation' is not available. Please call the registration cmdlet along with ResourceGroupLocation parameter.`nAvailable locations: $($availableLocations -join ', ')`n"
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

    "$(Get-Date -Format yyyy-MM-dd.HH-mm-ss): $Message" | Out-File $Script:registrationLog -Append
    Write-Verbose "$(Get-Date -Format yyyy-MM-dd.HH-mm-ss): $Message"
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
    "$(Get-Date -Format yyyy-MM-dd.HH-mm-ss): $Message" | Out-File $Script:registrationLog -Append
    Write-Warning "$(Get-Date -Format yyyy-MM-dd.HH-mm-ss): $Message"
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
        [String] $CallingFunction,

        [Parameter(Mandatory=$false)]
        [PSObject] $ExceptionObject
    )

    $errorLine = "************************ Error ************************"

    # Write Error line seperately otherwise out message will not contain stack trace
    "$(Get-Date -Format yyyy-MM-dd.HH-mm-ss): $errorLine" | Out-File $Script:registrationLog -Append
    Write-Verbose "$(Get-Date -Format yyyy-MM-dd.HH-mm-ss): $errorLine"

    Log-Output $Message
    if ($Message.ScriptStacktrace)
    {
        Log-Output $Message.ScriptStacktrace   
    }

    if ($ExceptionObject)
    {
        for ($exCount = 0; $exCount -lt $ExceptionObject.Count; $exCount++)
        {
            Log-Output "Exception #$exCount`: $($ExceptionObject[$exCount])"
        }
    }

    Log-OutPut "*********************** Ending registration action during $CallingFunction ***********************`r`n"

    "$(Get-Date -Format yyyy-MM-dd.HH-mm-ss): Logs can be found at: $Script:registrationLog  and  \\$PrivilegedEndpoint\c$\maslogs `r`n" | Out-File $Script:registrationLog -Append
    Write-Verbose "$(Get-Date -Format yyyy-MM-dd.HH-mm-ss): Logs can be found at: $Script:registrationLog  and  \\$PrivilegedEndpoint\c$\maslogs `r`n" 

    throw $Message
}

#endregion

# Disconnected functions
Export-ModuleMember Get-AzsRegistrationToken
Export-ModuleMember Register-AzsEnvironment
Export-ModuleMember Unregister-AzsEnvironment
Export-ModuleMember Get-AzsActivationKey
Export-ModuleMember New-AzsActivationResource
Export-ModuleMember Remove-AzsActivationResource

# Connected functions
Export-ModuleMember Set-AzsRegistration
Export-ModuleMember Remove-AzsRegistration
