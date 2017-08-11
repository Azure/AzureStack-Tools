# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#

.SYNOPSIS

This script can be used to register Azure Stack with Azure. To run this script, you must have a public Azure subscription of any type.
You must also have access to an account that is an owner or contributor to that subscription.

.DESCRIPTION

RegisterWithAzure runs scripts already present in Azure Stack (path: $root\CloudDeployment\Setup\Activation\Bridge)to connect your Azure Stack to Azure.
After connecting with Azure, you can download products from the marketplace (See the documentation for more information: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-download-azure-marketplace-item).
Running this script with default parameters will enable marketplace syndication and usage data will default to being reported to Azure.
To turn these features off see examples below.

This script will create several resources by default:
- A registration resource group and resource in Azure Stack
- A resource group in Azure
- A registration resource in the created resource group in Azure

See documentation for more detail: https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-register

.PARAMETER CloudAdminCredential

Powershell object that contains credential information such as user name and password.The CloudADmin has access to the JEA Computer (also known as Emergency Console).
If not supplied script will request manual input of username and password

.PARAMETER AzureSubscriptionId

The subscription Id that will be used for marketplace syndication and usage. The Azure Account Id used during registration must have access to this subscription.

.PARAMETER JeaComputerName

Just-Enough-Access Computer Name, also known as Emergency Console VM.

.PARAMETER ResourceGroupName

This will be the name of the resource group in Azure where the registration resource is stored. Defaults to "azurestack"

.PARAMETER  ResourceGroupLocation

The location where the resource group will be created. Defaults to "westcentralus"

.PARAMETER RegistrationName

The name of the registration resource that will be created in Azure. If none is supplied, defaults to "AzureStack-<CloudId>" where <CloudId> is the CloudId associated with the azure Stack environment

.PARAMETER AzureEnvironmentName

The name of the Azure Environment where resources will be created. Defaults to "AzureCloud"

.PARAMETER BillingModel

The billing model that the subscription uses. Select from "Capacity","PayAsYouUse", and "Development". Defaults to "Development"

.PARAMETER MarketplaceSyndicationEnabled

This is a switch that determines if this registration will allow you to download products from the Azure Marketplace. Defaults to $true

.PARAMETER UsageReportingEnabled

This is a switch that determines if usage records are reported to Azure. Defaults to $true

.PARAMETER AgreementNumber

Used when the billing model is set to capacity. If this is the case you will need to provide a specific agreement number associated with your billing agreement.

.EXAMPLE

This example registers your AzureStack account with Azure, enables syndication, and enables usage reporting to Azure.
This script must be run from the Host machine of the POC.

.\RegisterWithAzure.ps1 -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -JeaComputername "Azs-ERC01"

.EXAMPLE

This example registers your AzureStack account with Azure, enables syndication, and disables usage reporting to Azure. 

.\RegisterWithAzure.ps1 -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -JeaComputername "Azs-ERC01" -UsageReportingEnabled:$false

.EXAMPLE

This example registers your AzureStack account with Azure, enables syndication and usage and gives a specific name to the resource group and registration resource. 

.\RegisterWithAzure.ps1 -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -JeaComputername "Prefix-ERCS01" -ResourceGroupName "ContosoStackRegistrations" -RegistrationName "Registration01"

.EXAMPLE

This example un-Registers by disabling syndication and stopping usage push to Azure. Note that usage will still be collected, just not pushed to Azure.

.\RegisterWithAzure.ps1 -CloudAdminCredential $CloudAdminCredential -AzureSubscriptionId $SubscriptionId -JeaComputername "Azs-ERC01" -MarketplaceSyndicationEnabled:$false -UsageReportingEnabled:$false

.NOTES

If you would like to un-Register with you azure by turning off marketplace syndication and usage reporting you can run this script again with both enableSyndication
and reportUsage set to false. This will unconfigure usage bridge so that syndication isn't possible and usage data is not reported.

If you would like to use a different subscription for registration you must remove the activation resource from Azure and then re-run this script with a new subscription Id passed in.
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


#requires -Module AzureRM.Profile
#requires -Module AzureRM.Resources

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

$profileVersion = [Version](Get-Module -Name AzureRM.Profile).Version
$resourcesVersion = [Version](Get-Module -Name AzureRM.Resources).Version
$maxVersion = [Version]"1.0.4.4"

if (($profileVersion -gt $maxVersion) -or ($resourcesVersion -gt $maxVersion))
{
    Write-Error "You are using an incompatible version of Powershell Module: AzureRm. Please use the version outlined here: `r`n https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install"
}

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
        Write-Warning "Not currently connected to Azure: `r`n$($_.Exception)"
    }

    if (-not $isConnected)
    {
        Add-AzureRmAccount -SubscriptionId $SubscriptionId
        $context = Get-AzureRmContext
    }

    $environment = Get-AzureRmEnvironment -Name $AzureEnvironmentName
    $subscription = Get-AzureRmSubscription -SubscriptionId $SubscriptionId

    $tokens = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()
    if (-not $tokens -or ($tokens.Count -le 0))
    {
            throw "Token cache is empty"
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

Write-Verbose "Logging in to Azure." -Verbose
$connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironmentName

Write-Verbose "Initializing privileged JEA session." -Verbose
$session = New-PSSession -ComputerName $JeaComputerName -ConfigurationName PrivilegedEndpoint -Credential $CloudAdminCredential

try
{
    Write-Verbose "Verifying stamp version." -Verbose
    $stampInfo = Invoke-Command -Session $session -ScriptBlock { Get-AzureStackStampInformation -WarningAction SilentlyContinue }
    $minVersion = "1.0.170626.1"
    if ($stampInfo.StampVersion -lt $minVersion) {
        Write-Error -Message "Script only applicable for Azure Stack builds $minVersion or later."
    }

    Write-Verbose -Message "Running registration on build $($stampInfo.StampVersion). Cloud Id: $($stampInfo.CloudID), Deployment Id: $($stampInfo.DeploymentID)" -Verbose

    $tenantId = $connection.TenantId
    Write-Verbose "Creating Azure Active Directory service principal in tenant: $tenantId." -Verbose
    $refreshToken = $connection.Token.RefreshToken
    $servicePrincipal = Invoke-Command -Session $session -ScriptBlock { New-AzureBridgeServicePrincipal -RefreshToken $using:refreshToken -AzureEnvironment $using:AzureEnvironmentName -TenantId $using:tenantId }

    Write-Verbose "Creating registration token." -Verbose
    $registrationToken = Invoke-Command -Session $session -ScriptBlock { New-RegistrationToken -BillingModel $using:BillingModel -MarketplaceSyndicationEnabled:$using:MarketplaceSyndicationEnabled -UsageReportingEnabled:$using:UsageReportingEnabled -AgreementNumber $using:AgreementNumber }

    Write-Verbose "Creating resource group '$ResourceGroupName' in location $ResourceGroupLocation." -Verbose
    $resourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force

    Write-Verbose "Registering Azure Stack resource provider."
    Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.AzureStack" -Force | Out-Null

    $RegistrationName = if ($RegistrationName) { $RegistrationName } else { "AzureStack-$($stampInfo.CloudID)" }

    Write-Verbose "Creating registration resource '$RegistrationName'."
    $registrationResource = New-AzureRmResource `
        -ResourceGroupName $ResourceGroupName `
        -Location westcentralus `
        -ResourceName $RegistrationName `
        -ResourceType "Microsoft.AzureStack/registrations" `
        -Properties @{ registrationToken = "$registrationToken" } `
        -ApiVersion "2017-06-01" `
        -Force

    Write-Verbose "Registration resource: $(ConvertTo-Json $registrationResource)"

    Write-Verbose "Retrieving activation key."
    $actionResponse = Invoke-AzureRmResourceAction `
        -Action "getActivationKey" `
        -ResourceName $RegistrationName `
        -ResourceType "Microsoft.AzureStack/registrations" `
        -ResourceGroupName $ResourceGroupName `
        -ApiVersion "2017-06-01" `
        -Force

    Write-Verbose "Setting Registration Reader role on '$($registrationResource.ResourceId)' for service principal $($servicePrincipal.ObjectId)." -Verbose
    $customRoleAssigned = $false
    $customRoleName = "Registration Reader"
    $roleAssignments = Get-AzureRmRoleAssignment -Scope "/subscriptions/$($registrationResource.SubscriptionId)/resourceGroups/$($registrationResource.ResourceGroupName)/providers/Microsoft.AzureStack/registrations/$($RegistrationName)" -ObjectId $servicePrincipal.ObjectId -ErrorAction SilentlyContinue
    foreach ($role in $roleAssignments)
    {
        if ($role.RoleDefinitionName -eq $customRoleName)
        {
            $customRoleAssigned = $true
        }
    }

    if (-not $roleAssignments -or (-not $customRoleAssigned))
    {
        $customRoleDefined = Get-AzureRmRoleDefinition -Name $customRoleName
        if (-not $customRoleDefined)
        {
            # Create new RBAC role definition
            $role = Get-AzureRmRoleDefinition -Name "Reader"
            $role.Name = $customRoleName
            $role.id = [guid]::newguid()
            $role.IsCustom = $true
            $role.Actions.Clear()            
            $role.Actions.Add('Microsoft.AzureStack/registrations/products/listDetails/action')
            $role.Actions.Add('Microsoft.AzureStack/registrations/products/read')            
            $role.AssignableScopes.Clear()
            $role.AssignableScopes.Add("/subscriptions/$($registrationResource.SubscriptionId)/resourceGroups/$($registrationResource.ResourceGroupName)/providers/Microsoft.AzureStack/registrations/$($RegistrationName)")
            New-AzureRmRoleDefinition -Role $role
        }
        New-AzureRmRoleAssignment -Scope "/subscriptions/$($registrationResource.SubscriptionId)/resourceGroups/$($registrationResource.ResourceGroupName)/providers/Microsoft.AzureStack/registrations/$($RegistrationName)" -RoleDefinitionName $customRoleName -ObjectId $servicePrincipal.ObjectId         
    }
    
    Write-Verbose "Activating Azure Stack (this may take several minutes to complete)." -Verbose
    $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:actionResponse.ActivationKey }

    Write-Verbose "Azure Stack registration and activation completed successfully." -Verbose
}
finally
{
    $session | Remove-PSSession
}
