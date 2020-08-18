# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information.

<#
This module contains functions for creating edge subscription resource for default provider subscription and enabling remote management on AzureStack. 
This is supported only for connected AzureStack scenarios. You must use same Azure credentials that are used for registration.
#>

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
Check if the selected ResourceGroupLocation is available
#>
function Validate-ResourceGroupLocation{
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupLocation
    )
    $availableLocations = (Get-AzureRmLocation).Location
    if ($availableLocations -notcontains $ResourceGroupLocation){
        throw "ErrorCode: UnknownResourceGroupLocation.`nErrorReason: Resource group location '$ResourceGroupLocation' is not available. Please call the registration cmdlet along with ResourceGroupLocation parameter.`nAvailable locations: $($availableLocations -join ', ')`n"
    }
}

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
Uses information from Get-InfoForEdgeSubscription to create edge subscription resource group and resource in Azure
#>
function New-EdgeSubscriptionResource{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $EdgeSubscriptionName,

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

    $currentAttempt = 0
    $maxAttempt = 3
    $sleepSeconds = 10 

    Register-AzureStackResourceProvider

    $properties = @{
                         registrationResourceId = $RegistrationResourceId
                         deviceId               = $DeviceId
                         deviceObjectId         = $DeviceObjectId
                         edgeSubscriptionId     = $EdgeSubscriptionId
                       }
        
    $resourceCreationParams = @{
            Name              = $EdgeSubscriptionName
            Location          = $ResourceGroupLocation 
            Properties        = $properties 
            ResourceType      = "Microsoft.AzureStack/edgeSubscriptions" 
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
            Log-Output "Creating edge subscription resource..."             
            $edgeSubscriptionResource = New-AzureRmResource @resourceCreationParams
            Log-Output "EdgeSubscription resource created: $(ConvertTo-Json $edgeSubscriptionResource)"
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
    
    try
    {
        Log-Output "Getting EdgeSubscription."
        $deviceInfo = Invoke-Command -Session $PSSession -ScriptBlock { Get-DeviceInfoForEdgeSubscription -WarningAction SilentlyContinue }
    }
    Catch
    {
        Log-Throw "An error occurred querying device and registration information to create edge subscription : `r`n$($_)" -CallingFunction $PSCmdlet.MyInvocation.MyCommand.Name
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
        throw "ErrorCode: AzureContextNotSet.`nErrorReason: Azure Powershell context is null. Please log in to correct Azure Powershell context using 'Login-AzureRmAccount' and then call the registration cmdlet."
    }
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

    #ToDo: Confirm to throw not supported for non-AzureClouds
    return @{'AzureCloud'='eastus'; 
            'AzureChinaCloud'='ChinaEast';
            'AzureUSGovernment'='usgovvirginia'; 
            'CustomCloud'='eastus'}[$AzureEnvironment]  
}

function Enable-AzsCloudConnection{
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential] $PrivilegedEndpointCredential,

        [Parameter(Mandatory = $true)]
        [String] $PrivilegedEndpoint,

        [Parameter(Mandatory = $true)]
        [String] $EdgeSubscriptionName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject] $AzureContext = (Get-AzureRmContext),

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName = 'rgEdgeSub',

        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupLocation = (Get-DefaultResourceGroupLocation -AzureContext $AzureContext)
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    New-RegistrationLogFile -RegistrationFunction $PSCmdlet.MyInvocation.MyCommand.Name
    
    Log-Output "*********************** Begin log: $($PSCmdlet.MyInvocation.MyCommand.Name) ***********************`r`n"

    Validate-AzureContext -AzureContext $AzureContext
    Validate-ResourceGroupLocation -ResourceGroupLocation $ResourceGroupLocation

    try
    {
        $session = Initialize-PrivilegedEndpointSession -PrivilegedEndpoint $PrivilegedEndpoint -PrivilegedEndpointCredential $PrivilegedEndpointCredential -Verbose
        $deviceInfo = Get-InfoForEdgeSubscription -PSSession $session
        
        Log-Output "Creating EdgeSubscription now..."
        New-EdgeSubscriptionResource -EdgeSubscriptionName $EdgeSubscriptionName -RegistrationResourceId $deviceInfo.RegistrationResourceId -EdgeSubscriptionId $deviceInfo.EdgeSubscriptionId -DeviceId $deviceInfo.DeviceId -DeviceObjectId $deviceInfo.DeviceObjectId -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation

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
