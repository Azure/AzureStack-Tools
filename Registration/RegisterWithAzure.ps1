# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#

.SYNOPSIS

This script can be used to register Azure Stack POC with Azure. To run this script, you must have a public Azure subscription of any type.
There must also be an account that is an owner or contributor of the subscription, and you must have registered the AzureStack resource provider

.DESCRIPTION

RegisterWithAzure runs scripts already present in Azure Stack (path: $root\CloudDeployment\Setup\Activation\Bridge)to connect your Azure Stack to Azure.
After connecting with Azure, you can test marketplace syndication by downloading products from the marketplace. Usage data will also default to being reported to Azure for billing purposes.
To turn these features off see examples below.

The script will follow four steps:
Configure bridge identity: Creates Azure AD application that is used by Azure Bridge for marketplace syndication and by Usage Bridge to send Usage records (if configured).
Get registration request: get Azure Stack environment information to create a registration for this Azure Stack in azure
Register with Azure: uses Azure powershell to create an "Azure Stack Registration" resource on your Azure subscription
Activate Azure Stack: final step in connecting Azure Stack to be able to call out to Azure

.PARAMETER azureCredential

Powershell object that contains credential information such as user name and password. If not supplied script will request login via gui

.PARAMETER azureAccountId

Username for an owner/contributor of the azure subscription. This user must not be an MSA or 2FA account. This parameter is mandatory.

.PARAMETER azureSubscriptionId

Azure subscription ID that you want to register your Azure Stack with. This parameter is mandatory.

.PARAMETER azureDirectoryTenantName

Name of your AAD Tenant which your Azure subscription is a part of. This parameter is mandatory.

.PARAMETER azureEnvironment

Environment name for use in retrieving tenant details and running several of the activation scripts. Defaults to "AzureCloud".

.PARAMETER azureResourceManagerEndpoint

URI used for ActivateBridge.ps1 that refers to the endpoint for Azure Resource Manager. Defaults to "https://management.azure.com"

.PARAMETER enableSyndication

Boolean value used in Register-AzureStack.ps1 to enable marketplace syndication. Defaults to $true

.PARAMETER reportUsage

Boolean value used in Register-AzureStack.ps1 to enable reporting of usage records to Azure. Defaults to $true

.EXAMPLE

This example registers your AzureStack account with Azure, enables syndication, and enables usage reporting to Azure.
This script must be run from the Host machine of the POC.

.\RegisterWithAzure.ps1 -azureCredential $yourCredentials -azureSubscriptionId $subsciptionId -azureDirectoryTenantName "contoso.onmicrosoft.com" -azureAccountId "serviceadmin@contoso.onmicrosoft.com"

.EXAMPLE

This example registers your AzureStack account with Azure, enables syndication, and disables usage reporting to Azure. 

.\RegisterWithAzure.ps1 -azureCredential $yourCredentials -azureSubscriptionId $subsciptionId -azureDirectoryTenantName "contoso.onmicrosoft.com" -azureAccountId "serviceadmin@contoso.onmicrosoft.com" -reportUsage:$false

.NOTES
 Ensure that you have an Azure subscription and it is registered for Microsoft.AzureStack namespace in Azure.
 Namespace can be registered with the following command:
 Register-AzureRmResourceProvider -ProviderNamespace 'microsoft.azurestack' 

 If you would like to un-Register with you azure by turning off marketplace syndication and usage reporting you can run this script again with both enableSyndication
 and reportUsage set to false. This will unconfigure usage bridge so that syndication isn't possible and usage data is not reported. 
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
    [String] $AzureEnvironment = 'AzureCloud',

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

function Connect-AzureAccount
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$AzureEnvironment
    )

    $isConnected = $false;

    try
    {
        $context = Get-AzureRmContext
        if ($context.Subscription.SubscriptionId -eq $SubscriptionId)
        {
            $isConnected = $true;
        }
    }
    catch [System.Management.Automation.PSInvalidOperationException]
    {
    }

    if (-not $isConnected)
        {
            Add-AzureRmAccount -SubscriptionId $SubscriptionId
            $context = Get-AzureRmContext

        }

        $environment = Get-AzureRmEnvironment -Name $AzureEnvironment
        $subscription = Get-AzureRmSubscription -SubscriptionId $SubscriptionId

        $tokens = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()
        if (-not $tokens -or ($tokens.Count -le 0))
        {
            $tokens = $context.TokenCache.ReadItems()
            -not $tokens -or ($tokens.Count -le 0)
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


Write-Verbose "Logging in to Azure." -Verbose
$connection = Connect-AzureAccount -SubscriptionId $AzureSubscriptionId -AzureEnvironment $AzureEnvironment

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
    $servicePrincipal = Invoke-Command -Session $session -ScriptBlock { New-AzureBridgeServicePrincipal -RefreshToken $using:refreshToken -AzureEnvironment $using:AzureEnvironment -TenantId $using:tenantId }

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

    Write-Verbose "Setting Reader role on '$($registrationResource.ResourceId)' for service principal $($servicePrincipal.ObjectId)." -Verbose
    $roleAssignments = Get-AzureRmRoleAssignment -Scope "/subscriptions/$($registrationResource.SubscriptionId)/resourceGroups/$($registrationResource.ResourceGroupName)" -ObjectId $servicePrincipal.ObjectId -ErrorAction SilentlyContinue
    if (-not $roleAssignments -or ($roleAssignments.Count -le 0))
    {
        New-AzureRmRoleAssignment -Scope "/subscriptions/$($registrationResource.SubscriptionId)/resourceGroups/$($registrationResource.ResourceGroupName)" -RoleDefinitionName Contributor -ObjectId $servicePrincipal.ObjectId
    } 
    
    Write-Verbose "Activating Azure Stack (this may take several minutes to complete)." -Verbose
    $activation = Invoke-Command -Session $session -ScriptBlock { New-AzureStackActivation -ActivationKey $using:actionResponse.ActivationKey }

    Write-Verbose "Azure Stack registration and activation completed successfully." -Verbose
}
finally
{
    $session | Remove-PSSession
} 
