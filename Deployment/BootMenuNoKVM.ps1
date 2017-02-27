# Copyright (c) Microsoft Corporation. All rights reserved.
# See LICENSE.txt in the project root for license information. 

<# 
 
.SYNOPSIS 
 
Modify the boot entry and reboot the Azure Stack host back to the base Operating System, so that Azure Stack can be redeployed. 
 
.DESCRIPTION 
 
BootMenuNoKVM updates the boot configuration with the original entry, and then prompts to reboot the host.
Because the default boot entry is set with this script, no KVM or manual selection of the boot entry is required as the machine restarts.

.EXAMPLE 

Prompt user for the desired boot configuraiton and confirm reboot of the host so a redeployment of Azure Stack can begin.
This does not require KVM access to the host for selection of the correct Operating System as the machine restarts.
.\BootMenuNoKVM.ps1

.NOTES 
 
You will need execute this script in an elevated PS console session.
 
#>

#requires -version 4.0
#requires –runasadministrator

#region Menu   
    $prompt = ('Are you sure you want to configure this onetime boot value and reboot now?' + $title)
    $Yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes','Reboot now'
    $Abort = New-Object System.Management.Automation.Host.ChoiceDescription '&Abort','Abort'
    $options = [System.Management.Automation.Host.ChoiceDescription[]] ($Yes,$Abort)
#endregion


$bootOptions = bcdedit /enum  | Select-String 'path' -Context 2,1
cls

#region Selection
write-host 'This script specifies a one-time display order to be used for the next boot. Afterwards, the computer reverts to the original display order.' -ForegroundColor Yellow
write-host 'Select the Operating System to boot from:' -ForegroundColor Cyan
$menu = @{}
for ($i=1;$i -le $bootOptions.count; $i++) {
    Write-Host "$i. $($bootOptions[$i-1].Context.PostContext[0] -replace '^description +')"
    $menu.Add($i,($bootOptions[$i-1].Context.PreContext[0]))
    }

[int]$ans = Read-Host 'Enter selection'
$selection = $menu.Item($ans)
#endregion

$BootEntry = $selection -replace '^identifier +'
if($Selection -ne $null)
    {
    $choice = $host.ui.PromptForChoice($title,$prompt,$options,0)
    if ($choice -eq 0)
        {
        $BootID = '"' + $BootEntry + '"'
        bcdedit /bootsequence $BootID
        Restart-Computer
        }
        else 
            {
            write-host 'No changes are made to the boot configuration. Exiting..' -ForegroundColor Yellow
            Break
            }
    }
    else 
        {write-host 'Not a valid selection. No changes are made to the boot configuration. Exiting..' -ForegroundColor Yellow}
