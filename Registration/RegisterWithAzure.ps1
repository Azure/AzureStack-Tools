# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

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

If you would like to un-Register with you Azure by turning off marketplace syndication and usage reporting you can run this script again with both enableSyndication
and reportUsage set to false. This will unconfigure usage bridge so that syndication isn't possible and usage data is not reported.

If you would like to use a different subscription for registration you must remove the activation resource from Azure and then re-run this script with a new subscription Id passed in.

example: 

Remove-AzureRmResource -ResourceId "/subscriptions/4afd19a5-1cf7-4099-80ea-9aa2afdcb1e7/resourceGroups/ContosoStackRegistrations/providers/Microsoft.AzureStack/registrations/Registration01" `
.\RegisterWithAzure.ps1 -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $NewSubscriptionId -JeaComputername "<PreFix>-ERCS01" -ResourceGroupName "ContosoStackRegistrations" -RegistrationName "Registration02"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [PSCredential] $CloudAdminCredential,

    [Parameter(Mandatory = $true)]
    [String] $AzureSubscriptionId,

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

#
# Helper Function for connecting with Azure
#

function Connect-AzureAccount
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$AzureEnvironmentName
    )

    $isConnected = $false;

    try
    {
        $context = Get-AzureRmContext
        $environment = Get-AzureRmEnvironment -Name $AzureEnvironmentName
        $context.Environment = $environment
        if ($context.Subscription.SubscriptionId -eq $SubscriptionId)
        {
            $isConnected = $true;
        }
    }
    catch
    {
        Log-ErrorOutput "Not currently connected to Azure: `r`n$($_.Exception)"
    }

    if (-not $isConnected)
    {
        Add-AzureRmAccount -SubscriptionId $SubscriptionId        
    }

    $context = Get-AzureRmContext
    $environment = Get-AzureRmEnvironment -Name $AzureEnvironmentName
    $subscription = Get-AzureRmSubscription -SubscriptionId $SubscriptionId

    $tokens = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()
    if (-not $tokens -or ($tokens.Count -le 0))
    {
        $tokens = $context.TokenCache.ReadItems()
        if (-not $tokens -or ($tokens.Count -le 0))
        {
            throw "Token cache is empty"
        }

    }

    $token = $tokens |
        Where Resource -EQ $environment.ActiveDirectoryServiceEndpointResourceId |
        Where { $_.TenantId -eq $subscription.TenantId } |
        Where { $_.ExpiresOn -gt [datetime]::UtcNow } |
        Select -First 1

    if (-not $token)
    {
        throw "Token not found for tenant id $($subscription.TenantId) and resource $($environment.ActiveDirectoryServiceEndpointResourceId)."
    }

    return @{
        TenantId = $subscription.TenantId
        ManagementEndpoint = $environment.ResourceManagerUrl
        ManagementResourceId = $environment.ActiveDirectoryServiceEndpointResourceId
        Token = $token
    }
}

function Log-Output
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [object] $Message
    )

    $ErrorActionPreference = 'Stop'

    "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message" | Out-File $Global:AzureRegistrationLog -Append
    Write-Verbose "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message"
}

function Log-ErrorOutput
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [object] $Message
    )

    $ErrorActionPreference = 'Stop'

    # Write Error: line seperately otherwise out message will not contain stack trace
    "`r`n**************************** Error ****************************" | Out-File $Global:AzureRegistrationLog -Append
    $Message | Out-File $Global:AzureRegistrationLog -Append
    "***************************************************************" | Out-File $Global:AzureRegistrationLog -Append
    Write-Warning "$(Get-Date -Format yyyy-MM-dd.hh-mm-ss): $Message"
}

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

Log-Output "*********************** Begin Log: RegisterWithAzure ***********************`r`n"

#
# Domain Admin Check
#

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
    Log-ErrorOutput "$message `r`n$($_.Exception)"
    throw "$message `r`n$($_.Exception)"
}
catch
{
    Log-ErrorOutput "Unexpected error while checking for domain admin: `r`n$($_.Exception)"
    throw "Unexpected error while checking for domain admin: `r`n$($_.Exception)"
}

#
# Connect to Azure
#

Log-Output "Logging in to Azure."
$connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName

#
# Create PSSession with JEAComputer
#

$currentAttempt = 0
$maxAttempts = 3
$sleepSeconds = 10
do
{
    try
    {
        Log-Output "Initializing privileged JEA session. Attempt $currentAttempt of $maxAttempts"
        $session = New-PSSession -ComputerName $JeaComputerName -ConfigurationName PrivilegedEndpoint -Credential $CloudAdminCredential
        break
    }
    catch
    {
        Log-ErrorOutput "Creation of service principal failed:`r`n$($_.Exception.Message)"
        Log-Output "Waiting $sleepSeconds seconds and trying again..."
        $currentAttempt++
        Start-Sleep -Seconds $sleepSeconds
        if ($currentAttempt -ge $maxAttempts)
        {
            Log-ErrorOutput $_.Exception
            throw $_.Exception
        }
    }
}while ($currentAttempt -lt $maxAttempts)

#
# Register with Azure
#

try
{
    Log-Output "Verifying stamp version."
    $stampInfo = Invoke-Command -Session $session -ScriptBlock { Get-AzureStackStampInformation -WarningAction SilentlyContinue }
    $minVersion = [Version]"1.0.170626.1"
    if ([Version]$stampInfo.StampVersion -lt $minVersion) {
        Log-ErrorOutput "Script only applicable for Azure Stack builds $minVersion or later."
    }

    Log-Output "Running registration on build $($stampInfo.StampVersion). Cloud Id: $($stampInfo.CloudID), Deployment Id: $($stampInfo.DeploymentID)"

    $tenantId = $connection.TenantId    
    $refreshToken = $connection.Token.RefreshToken

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
            Log-ErrorOutput "Creation of service principal failed:`r`n$($_.Exception.Message)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempts)
            {
                Log-ErrorOutput $_.Exception
                throw $_.Exception
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
            Log-ErrorOutput "Creation of registration token failed:`r`n$($_.Exception.Message)"
            Log-Output "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempts)
            {
                Log-ErrorOutput $_.Exception
                throw $_.Exception
            }
        }
    }while ($currentAttempt -lt $maxAttempts)

    #
    # Create Azure resources
    #

    Log-Output "Creating resource group '$ResourceGroupName' in location $ResourceGroupLocation."
    $resourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force

    Log-Output "Registering Azure Stack resource provider."
    Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.AzureStack" -Force | Out-Null

    $RegistrationName = if ($RegistrationName) { $RegistrationName } else { "AzureStack-$($stampInfo.CloudID)" }

    Log-Output "Creating registration resource '$RegistrationName'."
    $registrationResource = New-AzureRmResource `
        -ResourceGroupName $ResourceGroupName `
        -Location $ResourceGroupLocation `
        -ResourceName $RegistrationName `
        -ResourceType "Microsoft.AzureStack/registrations" `
        -Properties @{ registrationToken = "$registrationToken" } `
        -ApiVersion "2017-06-01" `
        -Force

    Log-Output "Registration resource: $(ConvertTo-Json $registrationResource)"

    Log-Output "Retrieving activation key."
    $actionResponse = Invoke-AzureRmResourceAction `
        -Action "GetActivationKey" `
        -ResourceName $RegistrationName `
        -ResourceType "Microsoft.AzureStack/registrations" `
        -ResourceGroupName $ResourceGroupName `
        -ApiVersion "2017-06-01" `
        -Force

    #
    # Set RBAC role on registration resource
    #

    Log-Output "Setting Registration Reader role on '$($registrationResource.ResourceId)' for service principal $($servicePrincipal.ObjectId)."
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
        $role.AssignableScopes.Add("/subscriptions/$($registrationResource.SubscriptionId)")
        $role.Description = "Custom RBAC role for registration actions such as downloading products from Azure marketplace"
        try
        {
            New-AzureRmRoleDefinition -Role $role
        }
        catch
        {
            if ($_.Exception.Message -icontains "RoleDefinitionWithSameNameExists")
            {
                $message = "An RBAC role with the name $customRoleName already exists under this Azure account. Please remove this role from any other subscription before attempting registration again. `r`n"
                $message += "Please ensure your subscription Id context is set to the Id previously registered and run Remove-AzureRmRoleDefinition -Name 'Registration Reader'"
                Log-ErrorOutput "$message `r`n$($_Exception.Message)"
                throw "$message `r`n$($_Exception.Message)"
            }
            else
            {
                Log-ErrorOutput "Defining custom RBAC role $customRoleName failed: `r`n$($_.Exception)"
                Throw "Defining custom RBAC role $customRoleName failed: `r`n$($_.Exception)"
            }
        }
    }

    # Determine if custom RBAC role has been assigned
    $roleAssignmentScope = "/subscriptions/$($registrationResource.SubscriptionId)/resourceGroups/$($registrationResource.ResourceGroupName)/providers/Microsoft.AzureStack/registrations/$($RegistrationName)"
    $roleAssignments = Get-AzureRmRoleAssignment -Scope $roleAssignmentScope -ObjectId $servicePrincipal.ObjectId -ErrorAction SilentlyContinue

    foreach ($role in $roleAssignments)
    {
        if ($role.RoleDefinitionName -eq $customRoleName)
        {
            $customRoleAssigned = $true
        }
    }

    if (-not $customRoleAssigned)
    {        
        New-AzureRmRoleAssignment -Scope $roleAssignmentScope -RoleDefinitionName $customRoleName -ObjectId $servicePrincipal.ObjectId         
    }

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
    Log-Output "*********************** End Log: RegisterWithAzure ***********************`r`n"
}
