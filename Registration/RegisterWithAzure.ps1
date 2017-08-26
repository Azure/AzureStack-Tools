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
# Pre-registration setup
#

Resolve-DomainAdminStatus -Verbose
Write-Verbose "Logging in to Azure."
$connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName -Verbose
$session = Initalize-PrivilegedJeaSession -JeaComputerName $JeaComputerName -CloudAdminCredential $CloudAdminCredential -Verbose

#
# Register with Azure
#

try
{
    $stampInfo = Confirm-StampVersion -PSSession $session
    Write-Verbose -Message "Running registration on build $($stampInfo.StampVersion). Cloud Id: $($stampInfo.CloudID), Deployment Id: $($stampInfo.DeploymentID)"

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
            Write-Verbose "Creating Azure Active Directory service principal in tenant: $tenantId. Attempt $currentAttempt of $maxAttempts"
            $servicePrincipal = Invoke-Command -Session $session -ScriptBlock { New-AzureBridgeServicePrincipal -RefreshToken $using:refreshToken -AzureEnvironment $using:AzureEnvironmentName -TenantId $using:tenantId }
            break
        }
        catch
        {
            Write-Verbose "Creation of service principal failed:`r`n$($_.Exception.Message)"
            Write-Verbose "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempts)
            {
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
            Write-Verbose "Creating registration token. Attempt $currentAttempt of $maxAttempts"
            $registrationToken = Invoke-Command -Session $session -ScriptBlock { New-RegistrationToken -BillingModel $using:BillingModel -MarketplaceSyndicationEnabled:$using:MarketplaceSyndicationEnabled -UsageReportingEnabled:$using:UsageReportingEnabled -AgreementNumber $using:AgreementNumber }
            break
        }
        catch
        {
            Write-Verbose "Creation of registration token failed:`r`n$($_.Exception.Message)"
            Write-Verbose "Waiting $sleepSeconds seconds and trying again..."
            $currentAttempt++
            Start-Sleep -Seconds $sleepSeconds
            if ($currentAttempt -ge $maxAttempts)
            {
                throw $_.Exception
            }
        }
    }while ($currentAttempt -lt $maxAttempts)

    #
    # Create Azure resources
    #

    Write-Verbose "Creating resource group '$ResourceGroupName' in location $ResourceGroupLocation."
    $resourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force

    Write-Verbose "Registering Azure Stack resource provider."
    Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.AzureStack" -Force | Out-Null

    $RegistrationName = if ($RegistrationName) { $RegistrationName } else { "AzureStack-$($stampInfo.CloudID)" }

    Write-Verbose "Creating registration resource '$RegistrationName'."
    $registrationResource = New-AzureRmResource `
        -ResourceGroupName $ResourceGroupName `
        -Location $ResourceGroupLocation `
        -ResourceName $RegistrationName `
        -ResourceType "Microsoft.AzureStack/registrations" `
        -Properties @{ registrationToken = "$registrationToken" } `
        -ApiVersion "2017-06-01" `
        -Force

    Write-Verbose "Registration resource: $(ConvertTo-Json $registrationResource)"

    Write-Verbose "Retrieving activation key."
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

    Write-Verbose "Setting Registration Reader role on '$($registrationResource.ResourceId)' for service principal $($servicePrincipal.ObjectId)."
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
                throw "$message `r`n$($_Exception.Message)"
            }
            else
            {
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

    Write-Verbose "Activating Azure Stack (this may take several minutes to complete)." 
    $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:actionResponse.ActivationKey }
    Write-Verbose "Azure Stack registration and activation completed successfully. Logs can be found at: \\$JeaComputerName\c$\maslogs"
}
finally
{
    $session | Remove-PSSession
}
