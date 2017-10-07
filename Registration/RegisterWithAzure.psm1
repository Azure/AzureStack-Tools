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

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOreEmpty()]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -IsValid })]
        [String] $TokenOutputFilePath,        

        [Parameter(Mandatory = $true, ParameterSetName = "ConnectedScenario")]
        [String] $AzureSubscriptionId,

        [Parameter(Mandatory = $true, ParameterSetName = "ConnectedScenario")]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory = $true, ParameterSetName = "ConnectedScenario")]
        [String] $AzureEnvironmentName = 'AzureCloud'
    )
    #requires -Version 4.0
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: Get-AzsRegistrationToken ***********************`r`n"

    $params = @{
        CloudAdminCredential          = $CloudAdminCredential
        PrivilegedEndpoint            = $PrivilegedEndpoint
        BillingModel                  = $BillingModel
        MarketplaceSyndicationEnabled = $MarketplaceSyndicationEnabled
        UsageReportingEnabled         = $UsageReportingEnabled
        AgreementNumber               = $AgreementNumber
        RegistrationName              = $RegistrationName
        TokenOutputFilePath           = $TokenOutputFilePath
        WriteRegistrationToken        = $WriteRegistrationToken
        DisconnectedScenario          = $DisconnectedScenario
        AzureSubscriptionId           = $AzureSubscriptionId
        AzureDirectoryTenantName      = $AzureDirectoryTenantName
        AzureEnvironmentName          = $AzureEnvironmentName
    }

    Log-Output "Registration action params: $(ConvertTo-Json $params)"

    $registrationDetails = Get-RegistrationToken @params

    Log-Output "Your registration token can be found at: $TokenOutputFilePath"
    Log-Output "*********************** End log: Get-AzsRegistrationToken ***********************`r`n`r`n"

    return $registrationDetails
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

        [Parameter(Mandatory = $true)]
        [String] $RegistrationName
    )
    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: Register-AzsEnvironment ***********************`r`n"

    $params = @{
        AzureSubscriptionId      = $AzureSubscriptionId
        AzureDirectoryTenantName = $AzureDirectoryTenantName
        AzureEnvironmentName     = $AzureEnvironmentName
        ResourceGroupName        = $ResourceGroupName
        ResourceGroupLocation    = $ResourceGroupLocation
        RegistrationName         = $RegistrationName
        RegistrationToken        = $RegistrationToken
    }

    Log-Output "Registration action params: $(ConvertTo-Json $params)"

    $connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -AzureDirectoryTenantName $AzureDirectoryTenantName -Verbose
    New-RegistrationResource -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -RegistrationName $RegistrationName -RegistrationToken $RegistrationToken

    Log-Output "Your Azure Stack environment is now registered with Azure."
    Log-Output "*********************** End log: Register-AzsEnvironment ***********************`r`n`r`n"
}

<#
.SYNOPSIS

Enable-AzsFeature will enable the features that were set in Get-AzsRegistrationToken

.DESCRIPTION

Enable-AzsFeature performs several operations to activate your Azure Stack environment and enable the MarketplaceSyndicationEnabled and UsageReportingEnabled 
parameters that were set during Get-AzsRegistrationToken. The operations performed are:

- Create Service Principal in Azure
- Assign custom RBAC Role to the registration resource
- Retrieve activation key from registration resource
- Activate Azure Stack environment using activation key

.PARAMETER CloudAdminCredential

Powershell object that contains credential information i.e. user name and password.The CloudAdmin has access to the privileged endpoint to call approved cmdlets and scripts.
This parameter is mandatory and if not supplied then this function will request manual input of username and password

.PARAMETER PrivilegedEndpoint

The name of the VM that has permissions to perform approved powershell cmdlets and scripts. Usually has a name in the format of <ComputerName>-ERCSxx where <ComputerName>
is the name of the machine and ERCS is followed by a number between 01 and 03. Example: Azs-ERCS01 (from the ASDK)

.PARAMETER AzureSubscriptionId

The subscription that will be used for creation of a resource group and registration resource. If activation occurs on this registration with a 
BillingModel set to PayAsYouUse then this subscription will be billed for usage data that is reported. 

.PARAMETER AzureDirectoryTenantName

The directory that is associated with the subscription provided. Example: "Contoso.onmicrosoft.com"

.PARAMETER AzureEnvironmentName

The Azure environment that will be used to create registration resource. defaults to AzureCloud

.PARAMETER ResourceGroupName

The name of the resource group that will contain the registration resource. Defaults to 'azurestack'

.PARAMETER RegistrationName

The name of the registration resource created during Register-AzsEnvironment. Defaults to 'AzureStack-<Cloud Id>' where <Cloud Id> is the unique cloud
identifier for this Azure Stack environment.

.EXAMPLE

This example will activate the features set during Get-AzsRegistrationToken

Enable-AzsFeature -CloudAdminCredential $CloudAdminCred -PrivilegedEndpoint $PrivilegedEndpoint -AzureSubscriptionId $ContosoSubId -AzureDirectoryTenantName 'contoso.onmicrosoft.com'

.NOTES

To disable features such as Marketplace Syndication or Usage Reporting (if able) you must get a new registration token with appropriate parameters set to false,
you must register again, and you must call Enable-AzsFeature again.

#>
Function Enable-AzsFeature{
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

        [Parameter(Mandatory = $true)]
        [String] $RegistrationName

    )
    #requires -Version 4.0
    #requires -Modules @{ModuleName = "AzureRM.Profile" ; ModuleVersion = "1.0.4.4"} 
    #requires -Modules @{ModuleName = "AzureRM.Resources" ; ModuleVersion = "1.0.4.4"} 
    #requires -RunAsAdministrator

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Log-Output "*********************** Begin log: Enable-AzsFeature ***********************`r`n"

    $params = @{
        CloudAdminCredential     = $CloudAdminCredential
        PrivilegedEndpoint       = $PrivilegedEndpoint
        AzureSubscriptionId      = $AzureSubscriptionId
        AzureDirectoryTenantName = $AzureDirectoryTenantName
        AzureEnvironmentName     = $AzureEnvironmentName
        ResourceGroupName        = $ResourceGroupName
        RegistrationName         = $RegistrationName
    }

    Log-Output "Registration action params: $(ConvertTo-Json $params)"

    try
    {
        $session = Initialize-PrivilegedJeaSession -PrivilegedEndpoint $PrivilegedEndpoint -CloudAdminCredential $CloudAdminCredential -Verbose
        $stampInfo = Confirm-StampVersion -PSSession $session
        $connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -AzureDirectoryTenantName $AzureDirectoryTenantName -Verbose

        $servicePrincipal = New-ServicePrincipal -RefreshToken $connection.Token.RefreshToken -AzureEnvironmentName $AzureEnvironmentName -TenantId $connection.TenantId -PSSession $session
        Log-Output "Assigning custom RBAC role to resource $RegistrationName"
        New-RBACAssignment -SubscriptionId $AzureSubscriptionId -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName -ServicePrincipal $servicePrincipal
        $activationKey = Get-RegistrationActivationKey -ResourceGroupName $ResourceGroupName -RegistrationName $RegistrationName
        Log-Output "Activating Azure Stack (this may take up to 10 minutes to complete)."
        $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:activationKey }
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

    Log-Output "Activation completed. You can now download items from the Azure marketplace."
    Log-Output "*********************** End log: Enable-AzsFeature ***********************`r`n`r`n"
}

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
        [Parameter(Mandatory = $true)]
        [PSCredential] $CloudAdminCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,
        
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

        [Parameter(Mandatory = $false)]
        [String] $RegistrationName,

        [Parameter(Mandatory=$false)]
        [Switch] $WriteRegistrationToken = $false,

        [Parameter(Mandatory = $false)]
        [String] $TokenOutputFilePath,

        [Parameter(Mandatory = $false, ParameterSetName = "ConnectionStatus")]
        [Switch] $DisconnectedScenario = $false,

        [Parameter(Mandatory = $true, ParameterSetName = "ConnectionStatus")]
        [String] $AzureSubscriptionId,

        [Parameter(Mandatory = $true, ParameterSetName = "ConnectionStatus")]
        [String] $AzureDirectoryTenantName,

        [Parameter(Mandatory = $true, ParameterSetName = "ConnectionStatus")]
        [String] $AzureEnvironmentName = 'AzureCloud'
    )

    try
    {
        $session = Initialize-PrivilegedJeaSession -PrivilegedEndpoint $PrivilegedEndpoint -CloudAdminCredential $CloudAdminCredential -Verbose
        $stampInfo = Confirm-StampVersion -PSSession $session

        # Return registration name for use in Register-AzsEnvironment
        $RegistrationName = if ($RegistrationName) { $RegistrationName } else { "AzureStack-$($stampInfo.CloudID)" }
    
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

                $registrationDetails = [PSCustomObject]@{
                    RegistrationToken = $registrationToken
                    RegistrationName  = $RegistrationName
                }

                if (-not $DisconnectedScenario)
                {
                    $connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -AzureDirectoryTenantName $AzureDirectoryTenantName -Verbose
                    $servicePrincipal = New-ServicePrincipal -RefreshToken $connection.Token.RefreshToken -AzureEnvironmentName $AzureEnvironmentName -TenantId $connection.TenantId -PSSession $session
                }

                return $registrationDetails
            }
            catch
            {
                Log-Warning "Creation of registration token failed:`r`n$($_.Exception.Message)"
                Log-Output "Waiting $sleepSeconds seconds and trying again..."
                $currentAttempt++
                Start-Sleep -Seconds $sleepSeconds
                if ($currentAttempt -ge $maxAttempt)
                {
                    Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.InvocationName
                }
            }
        }
        while ($currentAttempt -lt $maxAttempt)
    }
    finally
    {
        Log-Output "Terminating session with $PrivilegedEndpoint"
        $session | Remove-PSSession
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
        [String] $RegistrationName,

        [Parameter(Mandatory = $false)]
        [String] $RegistrationToken
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
            break
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
            Log-Output "Service principal created. ObjectId: $($servicePrincipal.ObjectId)"
            return $servicePrincipal
        }
        catch
        {
            Log-Warning "Creation of service principal failed:`r`n$($_.Exception.Message)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.InvocationName
            }
        }
    }while ($currentAttempt -lt $maxAttempt)
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
        [string]$SubscriptionI,

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
    $maxAttempt = 3
    $sleepSeconds = 10
    do
    {
        try
        {
            Log-Output "Initializing privileged JEA session with $PrivilegedEndpoint. Attempt $currentAttempt of $maxAttempt"
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
            if ($currentAttempt -ge $maxAttempt)
            {
                Log-Throw -Message $_.Exception -CallingFunction $PSCmdlet.MyInvocation.InvocationName
            }
        }
    }while ($currentAttempt -lt $maxAttempt)
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
Export-ModuleMember Register-AzsEnvironment
Export-ModuleMember Enable-AzsFeature
