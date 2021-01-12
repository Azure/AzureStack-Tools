function Enable-AzsCloudConnection{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $PrivilegedEndpointCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [String] $LinkedSubscriptionName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzContext),

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'rgEdgeSub',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = (Get-DefaultResourceGroupLocation -AzureContext $AzureContext),

        [Parameter(Mandatory = $false)]
        [Switch] $AgreeToRemoteManagementConsent
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name
    
    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    $text = Get-ConsentText

    Write-Host $text
    Write-Host ""

    $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    if(-not $AgreeToRemoteManagementConsent.IsPresent)
    {
       $isConsentProvided = Read-Host -Prompt "If you agree to above consent statement then type 'Yes' to continue else 'No' to exit"        
       if($isConsentProvided -ne "Yes")
       {
          Log-Warning "Cannot proceed as required consent is not provided."
          return
       }
    }
    else
    {
       Log-Output "AgreeToRemoteManagementConsent flag is set"
       $isConsentProvided = "With-Parameter-AgreeToRemoteManagementConsent"           
    }
    
    Log-Output "User '$userName' provided consent to following by typing '$isConsentProvided' at $((get-date).ToUniversalTime().ToString())"
    Log-Output "========================================================================================================================="
    Log-Output "$text"
    Log-Output "========================================================================================================================="
    
    Validate-AzureContext -AzureContext $AzureContext
    Validate-ResourceGroupLocation -ResourceGroupLocation $ResourceGroupLocation

    try
    {
        $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -PrivilegedEndpointCredential $PrivilegedEndpointCredential -Verbose
        $deviceInfo = Get-InfoForEdgeSubscription -PSSession $session
        
        Log-Output "Calling EnableRemoteManagement on Hub RP"
        Notify-EnableRmToHubRp -RegistrationResourceId $deviceInfo.RegistrationResourceId

        Log-Output "Creating LinkedSubscription resource:$LinkedSubscriptionName with resource group:$ResourceGroupName at location:$ResourceGroupLocation"
        New-LinkedSubscriptionResource -LinkedSubscriptionName $LinkedSubscriptionName -RegistrationResourceId $deviceInfo.RegistrationResourceId -EdgeSubscriptionId $deviceInfo.EdgeSubscriptionId -DeviceId $deviceInfo.DeviceId -DeviceObjectId $deviceInfo.DeviceObjectId -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation

        Log-Output "Enabling remote management on AzureStack"
        Enable-RemoteManageOnDevice -PSSession $session
    }
    finally
    {
        if ($session)
        {
            Log-OutPut "Removing any existing PSSession..."
            $session | Remove-PSSession
        }
    }

    Log-Output "[SUCCESS]::Remote management is now enabled in your environment."
    Log-Output "*********************** End log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n`r`n"
}

<#
.SYNOPSIS
 Get consent text
#>
function Get-ConsentText
{
   $text = "By running PowerShell command to enable the connection to the cloud you consent to the following:
   • Replication of Azure Stack Hub resource metadata for the purposes of managing Azure Stack Hub from Azure. For more details about the replicated data go here http://aka.ms/ashdatatoazure
   • Permission to allow only your approved operators the ability to control Azure Stack resources from the Azure portal
   • Permission for Microsoft support to issue Support commands only during active support incidents, subject to an additional approval from you, to diagnose and resolve issues within your Azure Stack Hub infrastructure."

   return $text
}

<#
.SYNOPSIS
Uses information from Get-InfoForEdgeSubscription to create linked subscription resource group and resource in Azure
#>
function New-LinkedSubscriptionResource{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $LinkedSubscriptionName,

        [Parameter(Mandatory = $true)]
        [String] $RegistrationResourceId,

        [Parameter(Mandatory = $true)]
        [String] $EdgeSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $DeviceId,

        [Parameter(Mandatory = $true)]
        [String] $DeviceObjectId,

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'rgEdgeSub',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = 'eastus'
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 

    Register-AzureStackResourceProvider

    $properties = @{
                     registrationResourceId = $RegistrationResourceId
                     LinkedSubscriptionId     = $EdgeSubscriptionId
                   }
        
    $resourceCreationParams = @{
            Name              = $LinkedSubscriptionName
            Location          = $ResourceGroupLocation 
            Properties        = $properties 
            ResourceType      = "Microsoft.AzureStack/linkedSubscriptions" 
            ResourceGroupName = $ResourceGroupName 
            Force             = $true
            ApiVersion        = "2020-06-01-preview"  
    }

    Log-Output "Resource creation params: $(ConvertTo-Json $resourceCreationParams)"

    do
    {
        try
        {  
            $DebugPreference="Continue"                       
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
        finally
        {
           $DebugPreference="SilentlyContinue"
        }
    } while ($currentAttempt -lt $maxAttempt)

    do
    {
        try
        {
            $DebugPreference="Continue"
            Log-Output "Creating linked AzResource resource..."             
            $linkedSubscriptionResource = New-AzResource @resourceCreationParams
            Log-Output "LinkedSubscription resource created: $(ConvertTo-Json $linkedSubscriptionResource)"
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
        finally
        {
           $DebugPreference="SilentlyContinue"
        }
    } while ($currentAttempt -lt $maxAttempt)    
}

function Notify-EnableRmToHubRp{
[CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String] $RegistrationResourceId
        )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    $enableRemoteManagementActionName = "enableRemoteManagement"
    try
    {
        $registrationResouce = Get-AzResource -ResourceId $RegistrationResourceId
        if($null -eq $registrationResouce)
        {
            Log-Throw "Unable to find registration resource $registrationResouce"
        }

        Log-Output "Found registration resource:$RegistrationResourceId. Now calling action:$enableRemoteManagementActionName on Registration:$($registrationResouce.Name) with resourceGroup:$($registrationResouce.resourceGroupName)"
        Invoke-AzResourceAction `
            -ResourceName $registrationResouce.Name `
            -ResourceGroupName $registrationResouce.resourceGroupName `
            -Action $enableRemoteManagementActionName `
            -ResourceType $registrationResouce.ResourceType `
            -ApiVersion "2020-06-01-preview" `
            -Force

        Log-Output "[Success]::Action:$enableRemoteManagementActionName on Registration Resource:$resourceName with resourceGroup:$resourceGroupName"
    }
    Catch
    {
        Log-Throw "An error occurred while calling action $enableRemoteManagementActionName on RegistrationResource:$RegistrationResourceId `r`n$($_)" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }
}

<#
.SYNOPSIS
Uses the current session with the PrivilegedEndpoint to get registration information need to create EdgeSubscription
#>
function Get-InfoForEdgeSubscription{
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Runspaces.PSSession] $PSSession
    )
    
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    try
    {
        Log-Output "Calling Get-DeviceInfoForEdgeSubscription from PEP endpoint."
        $deviceInfo = Invoke-Command -Session $PSSession -ScriptBlock { Get-DeviceInfoForEdgeSubscription -WarningAction SilentlyContinue }
    }
    Catch
    {
        Log-Throw "An error occurred querying device and registration information to create linked subscription : `r`n$($_)" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }

    Log-Output -Message "Received information $($deviceInfo | ConvertTo-Json -Depth 4)."
    Log-Output -Message "Count: $($deviceInfo.Count)"
    Log-Output -Message "DeviceInfo1: $($deviceInfo[1] | ConvertTo-Json -Depth 4)"

    return $deviceInfo[1]
}

<#
.SYNOPSIS
Uses the current session with the PrivilegedEndpoint to enable remote management on device
#>
function Enable-RemoteManageOnDevice{
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Runspaces.PSSession] $PSSession
    )
    
    try
    {
        Log-Output "Enabling remote management on AzureStack."
        Invoke-Command -Session $PSSession -ScriptBlock { Enable-AzsCloudConnection -WarningAction SilentlyContinue }

        Log-Output "Remote management successfully enabled on device"
    }
    Catch
    {
        Log-Throw "An error occurred while enaling remote management on AzureStack: `r`n$($_)" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
    }    
}

#region HelperFunctions

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

Generate log file(s)

#>
function New-RegistrationLogFile{
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
   
   $logFilePath = "$LogFolder\AzureStack.RemoteManagement.$RegistrationFunction-$LogDate.log"
   Write-Verbose "Writing logs to file: $logFilePath"
   if (-not (Test-Path $logFilePath -PathType Leaf))
   {
       $null = New-Item -Path $logFilePath -ItemType File -Force
   }
   
   $Script:registrationLog = $logFilePath
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
        Log-Throw -Message "Current Azure context is not currently set. Please call Login-AzAccount to set the Azure context." -CallingFunction  $PSCmdlet.MyInvocation.MyCommand.Name
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
Get the resource group location based on the AzureEnvironment name
#>
function Get-DefaultResourceGroupLocation{
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [PSObject] $AzureContext
    )
    Validate-AzureContext -AzureContext $AzureContext
    $AzureEnvironment = $AzureContext.Environment.Name
    return @{'AzureCloud'='eastus'; 
            'AzureChinaCloud'='ChinaEast'; 
            'AzureUSGovernment'='usgovvirginia'; 
            'CustomCloud'='eastus'}[$AzureEnvironment]  
}

<#
.SYNOPSIS
Validate if AzureContext is set
#>
function Validate-AzureContext{
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [PSObject] $AzureContext
    )
    if ($null -eq $AzureContext){
        throw "ErrorCode: AzureContextNotSet.`nErrorReason: Azure Powershell context is null. Please log in to correct Azure Powershell context using 'Login-AzAccount' and then call the registration cmdlet."
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
