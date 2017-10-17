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

#region ConnectedScenario

<# 

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
        [string] $BillingModel = 'PayAsYouUse',

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
    $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:activationKey }

    Log-Output "Your environment is now registered and activated using the provided parameters."
    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"
}

<#

#>
function Remove-AzsRegistration{
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
        [string] $BillingModel = 'PayAsYouUse',

        [Parameter(Mandatory = $false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory = $false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $AgreementNumber        
    )
    
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
        MarketplaceSyndicationEnabled = $false
        UsageReportingEnabled         = $false
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
    Log-Output "De-Activating Azure Stack (this may take up to 10 minutes to complete)."
    $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:activationKey }
    Log-Output "Your environment is now unable to syndicate items and is no longer reporting usage data"

    # Remove registration resource in Azure
    Log-Output "Searching for registration resource in Azure"
    $registrationResourceId = "/subscriptions/$($AzureContext.Subscription.SubscriptionId)/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$registrationName"
    $registrationResource = Get-AzureRmResource -ResourceId $resourceId -ErrorAction Ignore
    
    if ($registrationResource)
    {
        Log-Output "Resource found. Removing resource: $registrationResourceId"
        Remove-AzureRmResource -ResourceId $resourceId -Force
    }
    else
    {
        Log-Warning "Registration resource was not found: $registrationResourceId"
        Log-Output "Ending registration action..."
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

.PARAMETER BillingModel

The billing model that will be used for this environment. Select from "Capacity","PayAsYouUse", and "Development". Defaults to "Development" which is usable for POC / ASDK installments.
Please see documentation for more information: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-billing-and-chargeback

.PARAMETER AgreementNumber

A valid agreement number must be provided if the 'capacity' BillingModel parameter is provided.

.PARAMETER MarketplaceSyndicationEnabled

Switch parameter that enables this environment to download products from the Azure Marketplace. Defaults to $true

.PARAMETER UsageReportingEnabled

Switch parameter that determines if usage records are reported to Azure. Defaults to $true. 
Note: This cannot be disabled with billing model set to PayAsYouUse.

.PARAMETER WriteRegistrationToken

Switch parameter used in conjunction with TokenOutputFilePath. Pass in this parameter when the registration token needs to be manually copied and used in a separate environment.

.PARAMETER TokenOutputFilePath

Used in conjunction with the WriteRegistrationToken switch, this parameter sets the output location for the registration token.

.EXAMPLE

This example generates a registration token for use in a follow up function. All features will be enabled.
$registrationToken = Get-AzsRegistrationToken -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development

.EXAMPLE

This example generates a registration token and writes it to a text file. All features will be enabled.
Get-AzsRegistrationToken -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development -WriteRegistrationToken -TokenOutputFilePath "C:\Temp\RegistrationToken.txt"

.EXAMPLE

This example generates a registration token and writes it to a text file. All features will be disabled. This is used only to register an environment.
Get-AzsRegistrationToken -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development -MarketplaceSyndicationEnabled:$false -UsageReportingEnabled:$false -WriteRegistrationToken -TokenOutputFilePath "C:\Temp\RegistrationToken.txt"

.NOTES

This function can be used in conjunction with the others if you would like to perform full registration and activation. For example:

$registrationToken = Get-AzsRegistrationToken -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development
Register-AzsEnvironment -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -AzureSubscriptionId $ContosoSubId -AzureDirectoryTenantName $ContosoDirectory -RegistrationToken $registrationToken
Enable-AzsFeature -CloudAdminCredential $cloudAdminCredential -PrivilegedEndpoint $PrivilegedEndpoint -AzureSubscriptionId $ContosoSubId -AzureDirectoryTenantName $ContosoDirectory

#>
Function Get-AzsRegistrationToken{
[CmdletBinding(DefaultParameterSetName='WriteRegistration')]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Capacity', 'PayAsYouUse', 'Development')]
        [string] $BillingModel = 'Capacity',

        [Parameter(Mandatory = $false)]
        [switch] $MarketplaceSyndicationEnabled = $true,

        [Parameter(Mandatory = $false)]
        [switch] $UsageReportingEnabled = $true,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $AgreementNumber,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $TokenOutputFilePath
    )
    #requires -Version 4.0
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue
    

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
            Log-Throw -Message "Unable to create file at location $TokenOutputFilePath. Please provide a valid input for -TokenOutputFilePath. `r`n$($_.Exception)" -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
        }
    }

    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    $params = @{
        CloudAdminCredential          = $CloudAdminCredential
        PrivilegedEndpoint            = $PrivilegedEndpoint
        BillingModel                  = $BillingModel
        MarketplaceSyndicationEnabled = $MarketplaceSyndicationEnabled
        UsageReportingEnabled         = $UsageReportingEnabled
        AgreementNumber               = $AgreementNumber
        TokenOutputFilePath           = $TokenOutputFilePath
    }

    Log-Output "Registration action params: $(ConvertTo-Json $params)"

    $registrationToken = Get-RegistrationToken @params

    Log-Output "Your registration token can be found at: $TokenOutputFilePath"
    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"

    return $registrationToken
}

<#
.SYNOPSIS

Register-AzsEnvironment will register your environment with Azure but will not enable syndication or usage reporting.

.DESCRIPTION

Register-AzsEnvironment creates a resource group and registration resource in Azure that can be used to activate at a later date.
A registration token is required to register with Azure. This is a required step before activating marketplace syndication or 
usage reporting features. 

.PARAMETER AzureSubscriptionId

The subscription that will be used for creation of a resource group and registration resource. If activation occurs on this registration with a 
BillingModel set to PayAsYouUse then this subscription will be billed for usage data that is reported. 

.PARAMETER AzureDirectoryTenantName

The directory that is associated with the subscription provided. Example: "Contoso.onmicrosoft.com"

.PARAMETER RegistrationToken

The registration token created after running Get-AzsRegistrationToken. This contains BillingModel, marketplace syndication, and usage reporting parameter information
that will later be used in Enable-AzsFeature to activate Azure Stack.

.PARAMETER AzureEnvironmentName

The Azure environment that will be used to create registration resource. defaults to AzureCloud

.PARAMETER ResourceGroupName

The name of the resource group that will contain the registration resource. Defaults to 'azurestack'

.PARAMETER ResourceGroupLocation

The Azure location where the registration resource group will be created. Defaults to 'westcentralus'

.PARAMETER RegistrationName

The name of the registration resource created during Register-AzsEnvironment. Defaults to 'AzureStack-<Cloud Id>' where <Cloud Id> is the unique cloud
identifier for this Azure Stack environment.

.EXAMPLE

This example will register your Azure Stack environment with all default parameters.

Register-AzsEnvironment -AzureSubscriptionId $ContosoSubId -AzureDirectoryTenantName 'contoso.onmicrosoft.com' -RegistrationToken $registrationToken

.EXAMPLE

This example will register your Azure Stack environment with specific names for resource group and registration resource

Register-AzsEnvironment -AzureSubscriptionId $ContosoSubId -AzureDirectoryTenantName 'contoso.onmicrosoft.com' -RegistrationToken $registrationToken -ResourceGroupName 'ContosoAzureStack' -RegistrationName 'ContosoAzureStackRegistration'

.NOTES

This function will not enable marketplace syndication or usage reporting but it is a required step before those features can be enabled. 

#>
Function Register-AzsEnvironment{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzureRmContext),

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [String] $RegistrationToken,

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

Register-AzsEnvironment will register your environment with Azure but will not enable syndication or usage reporting.

.DESCRIPTION

Register-AzsEnvironment creates a resource group and registration resource in Azure that can be used to activate at a later date.
A registration token is required to register with Azure. This is a required step before activating marketplace syndication or 
usage reporting features. 

.PARAMETER AzureSubscriptionId

The subscription that will be used for creation of a resource group and registration resource. If activation occurs on this registration with a 
BillingModel set to PayAsYouUse then this subscription will be billed for usage data that is reported. 

.PARAMETER AzureDirectoryTenantName

The directory that is associated with the subscription provided. Example: "Contoso.onmicrosoft.com"

.PARAMETER RegistrationToken

The registration token created after running Get-AzsRegistrationToken. This contains BillingModel, marketplace syndication, and usage reporting parameter information
that will later be used in Enable-AzsFeature to activate Azure Stack.

.PARAMETER AzureEnvironmentName

The Azure environment that will be used to create registration resource. defaults to AzureCloud

.PARAMETER ResourceGroupName

The name of the resource group that will contain the registration resource. Defaults to 'azurestack'

.PARAMETER ResourceGroupLocation

The Azure location where the registration resource group will be created. Defaults to 'westcentralus'

.PARAMETER RegistrationName

The name of the registration resource created during Register-AzsEnvironment. Defaults to 'AzureStack-<Cloud Id>' where <Cloud Id> is the unique cloud
identifier for this Azure Stack environment.

.EXAMPLE

This example will register your Azure Stack environment with all default parameters.

Register-AzsEnvironment -AzureSubscriptionId $ContosoSubId -AzureDirectoryTenantName 'contoso.onmicrosoft.com' -RegistrationToken $registrationToken

.EXAMPLE

This example will register your Azure Stack environment with specific names for resource group and registration resource

Register-AzsEnvironment -AzureSubscriptionId $ContosoSubId -AzureDirectoryTenantName 'contoso.onmicrosoft.com' -RegistrationToken $registrationToken -ResourceGroupName 'ContosoAzureStack' -RegistrationName 'ContosoAzureStackRegistration'

.NOTES

This function will not enable marketplace syndication or usage reporting but it is a required step before those features can be enabled. 

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
            Log-Throw -Message "No registration name or registration token passed in. Unable to locate registration resource" -CallingFunction $($PSCmdlet.MyInvocation.MyCommand.Name)
        }   
    }

    $azureAccountInfo = Get-AzureAccountInfo -AzureContext $AzureContext
    $registrationResourceId = "/subscriptions/$($AzureContext.Subscription.SubscriptionId)/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStack/registrations/$RegistrationName"

    Log-Output "Your Azure Stack environment is now unregistered from Azure."
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
                Log-Warning "Creation of registration token failed:`r`n$($_.Exception)"
                Log-Output "Waiting $sleepSeconds seconds and trying again..."
                $currentAttempt++
                Start-Sleep -Seconds $sleepSeconds
                if ($currentAttempt -ge $maxAttempt)
                {
                    Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
            break
        }
        catch
        {
            Log-Warning "Creation of Azure resource group failed:`r`n$($_.Exception)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
            Log-Warning "Creation of Azure resource failed:`r`n$($_.Exception)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
            Log-Warning "Retrieval of activation key failed:`r`n$($_.Exception)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
            Log-Warning "Creation of service principal failed:`r`n$($_.Exception)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_.Exception -CallingFunction  $PSCmdlet.MyInvocation.MyCommand.Name
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
                        Log-Throw -Message "Defining custom RBAC role $customRoleName failed: `r`n$($_.Exception)" -CallingFunction  $PSCmdlet.MyInvocation.MyCommand.Name
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
            break
        }
        catch
        {
            Log-Warning "Assignment of custom RBAC Role $customRoleName failed:`r`n$($_.Exception)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_.Exception -CallingFunction  $PSCmdlet.MyInvocation.MyCommand.Name
            }
        }
    } while ($currentAttempt -lt $maxAttempt)
}

<#

.SYNOPSIS

Determines if a new Azure connection is required.

.DESCRIPTION

If the current powershell environment is not currently logged in to an Azure Account or is calling Add-AzsRegistration
with a subscription id that does not match one available under the current context then Connect-AzureAccount will prompt the user to log in
to the correct account. 

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
        Log-Throw -Message "Token cache is empty `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
            Log-Warning "Creation of session with $PrivilegedEndpoint failed:`r`n$($_.Exception)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
            Log-Warning "Registering Azure Stack resource provider failed:`r`n$($_.Exception)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
        Log-Throw "An error occurred checking stamp information: `r`n$($_.Exception)" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
    Log-Output "`r`n *** WARNING ***"
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

    Log-OutPut "*********************** Ending registration action during $CallingFunction ***********************`r`n"

    "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): Logs can be found at: $Global:AzureRegistrationLog  and  \\$PrivilegedEndpoint\c$\maslogs `r`n" | Out-File $Global:AzureRegistrationLog -Append
    Write-Verbose "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): Logs can be found at: $Global:AzureRegistrationLog  and  \\$PrivilegedEndpoint\c$\maslogs `r`n" 

    throw "$Message"
}

#endregion

# Disconnected functions
Export-ModuleMember Get-AzsRegistrationToken
Export-ModuleMember Register-AzsEnvironment
Export-ModuleMember Unregister-AzsEnvironment

# Connected functions
Export-ModuleMember Set-AzsRegistration
Export-ModuleMember Remove-AzsRegistration
