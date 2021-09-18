<#
.SYNOPSIS
Short description
This prechecker script validates the hardware and software requirements of your host to prepare for the deployment of the Azure Stack Development Kit

.DESCRIPTION
The script provides a way to confirm the host meets the hardware and software requirements, before downloading the larger package for the Azure Stack Development Kit.

For more information on ASDK requirements and considerations, see https://docs.microsoft.com/azure-stack/asdk/asdk-deploy-considerations.

.EXAMPLE
.\asdk-prechecker.ps1

.NOTES
To use this script on the host where Azure Stack Development Kit will be installed, you need to run it as an administrator (the script will check if it is running in this context). 
You may also need to update the PowerShell script execution policy with Set-ExecutionPolicy, since the script is not signed : https://technet.microsoft.com/en-us/library/hh849812.aspx 

The Azure Stack Development Kit Pre-Checker script is a PowerShell script published in this public repository so you can make improvements to it by submitting a pull request.
https://github.com/Azure/AzureStack-Tools
#>

#requires -runasadministrator

function CheckNestedVirtualization {

    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking for physical/virtual machine status..."

    $BaseBoard = (Get-WmiObject Win32_BaseBoard)
    If ($BaseBoard)
        {
        If (($BaseBoard.Manufacturer.Tolower() -match 'microsoft' -and $BaseBoard.Product.Tolower() -match 'virtual') -or ($BaseBoard.Manufacturer.Tolower() -match 'vmware'))
            {
            write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- WARNING : This server seems to be a virtual machine running on Hyper-V or VMware. Running ASDK on a nested hypervisor is not a tested or supported scenario. Setup will not block this, but this but this may lead to performance or reliability issues."
            $Global:ChecksFailure++
            }
            else
            {
            write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- This is a physical machine."
            $Global:ChecksSuccess++
            }
        }
        else
        {
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- This is a physical machine."
        $Global:ChecksSuccess++
        }

}

function CheckInternetAccess {
    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking Internet access..."

    # Test AAD http connection.
    try {
        $resp = Invoke-WebRequest -Uri "https://login.windows.net" -UseBasicParsing
        if ($resp.StatusCode -ne 200) {
            write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- Failed to connect to AAD endpoint https://login.windows.net"
            $Global:ChecksFailure++
        }
        else
        {
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- This machine has internet access (we tried to contact https://login.windows.net)."
        $Global:ChecksSuccess++
        }
    }
    catch {
        write-host -ForegroundColor white "["(date -format "HH:mm:ss")"]" $_.Exception.Message
        write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- Failed to connect to AAD endpoint 'https://login.windows.net'."
        $Global:ChecksFailure++
    }
}

function CheckSystemDisk {
    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking system disk capacity..."

    $systemDisk = Get-Disk | ? {$_.IsSystem -eq $true}
    If ($systemDisk.Size -lt 200 * 1024 * 1024 * 1024)
        {
            write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- Check system disk failed - Size should be 200 GB minimum."
            $Global:ChecksFailure++
        }
        else
        {
            write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- Check system disk passed successfully."
            $Global:ChecksSuccess++
        }   
}

function CheckDisks {
    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking physical disks..."
  
    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" " -- Listing of all physical disks on this server:"
    write-host -ForegroundColor gray (Get-PhysicalDisk | Format-Table -Property @("FriendlyName", "SerialNumber", "CanPool", "BusType", "OperationalStatus", "HealthStatus", "Usage", "Size") | Out-String)
    $physicalDisks = Get-PhysicalDisk | Where-Object { ($_.BusType -eq 'RAID' -or $_.BusType -eq 'SAS' -or $_.BusType -eq 'SATA') -and $_.Size -gt 135 * 1024 * 1024 * 1024 }
    $selectedDisks = $physicalDisks | Group-Object -Property BusType | Sort-Object -Property Count -Descending | Select-Object -First 1

    if ($selectedDisks.Count -ge 3) {
        write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" " -- Listing of all physical disks meeting ASDK requirements:"
        write-host -ForegroundColor gray ($physicalDisks | Format-Table -Property @("FriendlyName", "SerialNumber", "BusType", "OperationalStatus", "HealthStatus", "Usage", "Size") | Out-String)
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- Check physical disks passed successfully. Note that ASDK handles situations where there is a pre-existing storage pool, and will delete/recreate it."
        $Global:ChecksSuccess++
    }

    if ($selectedDisks.Count -lt 3) {
        write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- Check physical disks failed - At least 4 disks or more of the same bus type (RAID/SAS/SATA), and of capacity 135 GB or higher are strongly recommended. 3-disk configurations may work but are not tested by Microsoft."
        $Global:ChecksFailure++
     }    

}

function CheckFreeSpaceForExtraction {

    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" " Checking free space for extracting the ASDK files..."
    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" " -- Listing disks and their free space"
    write-host -ForegroundColor gray (Get-Disk | Get-Partition | Get-Volume | Sort-Object -Property SizeRemaining -Descending | Out-String)
    $volumes = (Get-disk | ? {$_.BusType -ne 'File Backed Virtual' -or $_.IsBoot} | Get-Partition | Get-Volume |`
         ? {-not [String]::IsNullOrEmpty($_.DriveLetter)} | sort -Property SizeRemaining -Descending)
    if (!$volumes -or ($volumes | Measure-Object).count -le 0) {
        Write-Host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- Free space check failed. No volumes are available."
        $Global:ChecksFailure++
    }
    if ($volumes[0].SizeRemaining -lt 130 * 1024 * 1024 * 1024) {
        write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- Free space check failed. ASDK requires 130 GB for the expanded Cloudbuilder.vhdx file. An additional 40 GB may be needed if you want to keep the ZIP and self extractor files."
        $Global:ChecksFailure++
    }
    else
    {
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- Free space check passed successfully."
        $Global:ChecksSuccess++
    }
}

function CheckRam {
    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking Memory..."
    
    $mem = Get-WmiObject -Class Win32_ComputerSystem
    $totalMemoryInGB = [Math]::Round($mem.TotalPhysicalMemory / (1024 * 1024 * 1024))
    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" " -- Memory on this server = $totalMemoryInGB"
    if ($totalMemoryInGB -lt 192) {
        write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- Check system memory requirement failed. At least 192 GB physical memory is required (256 GB recommended)."
        $Global:ChecksFailure++
    }
    else
    {
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- System memory check passed successfully. ASDK requires a minimum of 192 GB of RAM, with 256 GB recommended."
        $Global:ChecksSuccess++
    }
}

function CheckHyperVSupport {
    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking Hyper-V support on the host..."

    $feature = Get-WindowsFeature -Name "Hyper-V"
    if ($feature.InstallState -ne "Installed") {
          $cpu = Get-WmiObject -Class WIN32_PROCESSOR
          $os = Get-WmiObject -Class Win32_OperatingSystem
          if (($cpu.VirtualizationFirmwareEnabled -contains $false) -or ($cpu.SecondLevelAddressTranslationExtensions -contains $false) -or ($cpu.VMMonitorModeExtensions -contains $false) -or ($os.DataExecutionPrevention_Available -eq $false)) {
            write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- Hyper-V is not supported on this host. Hardware virtualization is required for Hyper-V."
            $Global:ChecksFailure++
         }
         else
         {
            write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- This server supports the hardware virtualization required to enable Hyper-V."
            $Global:ChecksSuccess++
         }
    }
    else
    {
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- Hyper-V is already installed. Note that the installer would enable it otherwise."
        $Global:ChecksSuccess++
    }
}

function CheckOSVersion {
 
    # Check Host OS version first, otherwist DISM will failed to get VHD OS version
    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking Host OS version..."
    $hostOS = Get-WmiObject win32_operatingsystem
    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" (" -- Host OS version: {0}, SKU: {1}" -f $hostOS.Version, $hostOS.OperatingSystemSKU)
    $hostOSVersion = [Version]::Parse($hostOS.Version)
    
    $server2016OSVersionRequired = "10.0.14393"
    $server2016OSVersion = [Version]::Parse($server2016OSVersionRequired)
    $serverDataCenterSku = 8 # Server Datacenter
    $serverDataCenterEvalSku = 80 # Server Datacenter EVal
 
    if ($hostOSVersion -lt $server2016OSVersion -or ($hostOS.OperatingSystemSKU -ne $serverDataCenterSku -and $hostOS.OperatingSystemSKU -ne $serverDataCenterEvalSku)) {
        write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- The host OS should be Windows Server 2016 Datacenter, version $server2016OSVersionRequired."
        $Global:ChecksFailure++
    }
    else
    {
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- The host OS version matches the requirements for ASDK ($server2016OSVersionRequired)."
        $Global:ChecksSuccess++
    }
}

function CheckDomainJoinStatus {
    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking domain join status..."

    $sysInfo = Get-WmiObject -Class Win32_ComputerSystem
    if ($sysInfo.PartOfDomain) {
        write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- The host must not be domain joined. Please leave the domain and try again."
        $Global:ChecksFailure++
    }
    else
    {
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- The host is not domain joined."
        $Global:ChecksSuccess++
    }

}

function CheckVMSwitch {

    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking NIC status..."

    if (([array](Get-NetAdapter | ? {$_.Status -eq 'Up'})).Count -ne 1) {
        write-host -ForegroundColor darkyellow "["(date -format "HH:mm:ss")"]" " -- Multiple NICs, virtual switches or NIC teaming are not allowed. Please only keep one physical NIC enabled and remove virtual switches or NIC teaming. This message can be ignored if you are planning to leverage the ASDK Installer from GitHub, as it provides a way to configure the NICs."
        $Global:ChecksSuccess++
    }
    else
    {
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- NIC configuration passed successfully."
        $Global:ChecksSuccess++
    }
}

function CheckServerName {

    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking server name..."

    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" " -- Server name is" $Env:COMPUTERNAME

  if ($Env:COMPUTERNAME -eq 'AzureStack') {
    write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- Server name cannot be ""AzureStack"" since it conflicts with the domain name."
    $Global:ChecksFailure++
  }
  else
  {
    write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- Server name does not conflict with future domain name AzureStack.local."
    $Global:ChecksSuccess++
  }
}


function CheckCPU {

    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking processor information..."

    $CPUCount = (Get-WmiObject -class win32_processor -computername localhost).count
    $CoreCount =  ((Get-WmiObject -class win32_processor -computername localhost -Property "numberOfCores")[0].numberOfCores)*$CPUCount
    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" " -- Number of CPU sockets = $CPUCount"
    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" " -- Number of physical cores =  $CoreCount"

    If (($CPUCount -lt 2) -or ($CoreCount -lt 16)){
    write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- CPU count must be 2 or higher, Core count must be 16 or higher (20 cores recommended)."
    $Global:ChecksFailure++
  }
  else
  {
    write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- CPU socket count ($CPUCount) and core count ($CoreCount) meet the minimum requirements for ASDK."
    $Global:ChecksSuccess++
  }
}

function CheckNICSupport {

    write-host -ForegroundColor yellow "["(date -format "HH:mm:ss")"]" "Checking NIC requirements..."

    $FoundNIC = $false
    Get-NetAdapter -IncludeHidden | ForEach-Object {
        $pnpDevoceId = $_.PnPDeviceID
        if($pnpDevoceId -eq $null) { return }
        $PnPDevice = Get-PnpDevice -InstanceId $pnpDevoceId
        If ((Get-PnpDeviceProperty -InputObject $PnPDevice -KeyName DEVPKEY_Device_DriverInfPath).Data -eq "netbxnda.inf")
        {
            $FoundNIC = $true
        }
    }

    If ($FoundNIC)
    {
        write-host -ForegroundColor darkyellow "["(date -format "HH:mm:ss")"]" " -- Please make sure to leverage the ASDK Installer for deployment, per the documentation. This installer will apply an update to this host prior to deployment."
        $Global:ChecksSuccess++
    }
    else
    {        
        write-host -ForegroundColor green "["(date -format "HH:mm:ss")"]" " -- Network cards requirements are met."
        $Global:ChecksSuccess++
    }

}

$ErrorActionPreference = 'Stop'

write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" "Starting Deployment Checker for Microsoft Azure Stack Development Kit (ASDK)..."
Write-Host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" "There are several prerequisites checks to verify that your machine meets all the minimum requirements for deploying ASDK."
write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" "For more details, please refer to the online requirements : https://azure.microsoft.com/en-us/documentation/articles/azure-stack-deploy/"

write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" "Checking for Administrator priviledge..."

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" " -- You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
        break
    }

$checksHW = {CheckNestedVirtualization}, `
            {CheckSystemDisk},
            {CheckDisks}, 
            {CheckRam}, `
            {CheckCPU},
            {CheckHyperVSupport}`

$CheckHWOnly = {CheckFreeSpaceForExtraction}

$checksSW = {CheckDomainJoinStatus}, `
            {CheckInternetAccess}, `
            {CheckOSVersion}, `
            {CheckVMSwitch}, `
            {CheckNICSupport},
            {CheckServerName}
            

$Global:ChecksSuccess = 0
$Global:ChecksFailure = 0

#Checking if ASDK is already installed

$POCInstalledOrFailedPreviousInstall = $false
If ((get-module -Name Hyper-V -ListAvailable).count -gt 0)
    {
    $VMList = @("MAS-ACS01","MAS-ADFS01","MAS-ASql01","MAS-BGPNAT01","MAS-CA01","MAS-Con01","MAS-DC01","MAS-Gwy01","MAS-NC01", "MAS-SLB01", "MAS-SUS01", "MAS-WAS01", "MAS-Xrp01", "AzS-ACS01","AzS-ADFS01","AzS-ASql01","AzS-BGPNAT01","AzS-CA01","AzS-Con01","AzS-DC01","AzS-Gwy01","AzS-NC01", "AzS-SLB01", "AzS-SUS01", "AzS-WAS01", "AzS-Xrp01")
    If ((Get-VM $VMList -ErrorAction SilentlyContinue).Count -gt 0)
        {$POCInstalledOrFailedPreviousInstall = $true}
    }
If ($POCInstalledOrFailedPreviousInstall)
    {
    write-host -ForegroundColor red "["(date -format "HH:mm:ss")"] This machine seems to host an existing successful or failed installation of Azure Stack Development Kit. The prerequisite checker is meant to be run prior to installation, and will return errors post-install, as some of the configuration may already have been applied (joining the domain, setting up storage pools,...)"
    If ((Read-Host "Do you want to continue anyway (Y/N)?") -eq "N")
        {
        break
        }
    }


write-host -ForegroundColor white "["(date -format "HH:mm:ss")"] This script can be run on the host where you will be configuring boot from VHD, for example prior to downloading the ASDK files. Or it can be run after booting from the provided Cloudbuilder.vhdx file where the ASDK will be installed. In the first case, it will only check for hardware specifications like memory, cores, hard disk configuration, as well as free space for extracting the ASDK files. In the second case, it will run both hardware and software tests, and other items like domain membership, OS version, NIC configuration will be checked."
Switch (Read-Host "Are you running this script on the host before booting in the provider VHDX file [1] or after booting into it [2] (any other input will exit the script)?")
    {
    "1"
    {
    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" "User chose to run pre-boot from VHD checks (hardware checks only)"
    $checks = $checksHW + $CheckHWOnly
    }
    "2"
    {
    write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" "User chose to run post-boot from VHD checks (all checks except free space)"
    $checks = $checksHW + $checksSW
    }
    Default
    {
    write-host -ForegroundColor red "["(date -format "HH:mm:ss")"]" "User did not pick one of the two options, exiting script..."
    exit
    }
    }

$PreCheckProgressMessage = "Running Prerequisites Check"

for($i=0; $i -lt $checks.Length; $i++)
{
     Write-Progress -Activity $PreCheckProgressMessage -PercentComplete ($i * 100 / $checks.Length)
     Invoke-Command -ScriptBlock $checks[$i] -NoNewScope
}

Write-Progress -Activity $PreCheckProgressMessage -Completed

If ($Global:ChecksSuccess -eq $Checks.Length)
    {
    Write-Host -ForegroundColor green "["(date -format "HH:mm:ss")"]" "SUCCESS : All of the prerequisite checks passed."
    }
    else
    {
    Write-Host -ForegroundColor red "["(date -format "HH:mm:ss")"]" "FAILURE:"$ChecksFailure "prerequisite check(s) failed out of" $Checks.Length ". Please review previous entries to understand where the requirements are not met."
    }


write-host -ForegroundColor gray "["(date -format "HH:mm:ss")"]" "Deployment Checker has finished checking Azure Stack Development Kit requirements"
