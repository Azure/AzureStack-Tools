<#############################################################
 #                                                           #
 # Copyright (C) Microsoft Corporation. All rights reserved. #
 #                                                           #
 #############################################################>

# Script to create AD objects from domain admin context prior to azurestack hci deployment driver execution.
#
# Requirements:
#  - Ensure that the following parameters must be unquie in AD per cluster instance
#     - Azurestack hci deployment user.
#     - Azurestack hci organization unit name.
#     - Azurestack hci deployment prefix (must be at the max 8 characters).
#     - Azurestack hci deployment cluster name.
#  - Physical nodes objects (if already created) must be available under nested computers organization unit.
#
# Objects to be created:
#  - Hci Organizational Unit that will be the parent to an organizational unit for each instance and 2 sub organizational units (Computers and Users) with group policy inheritance blocked.
#  - A user account (under users OU) that will have full control to that organizational unit.
#  - Computer objects (if provided under Computers OU else all computer objects must be present under Computer OU)
#  - Security groups (under users OU)
#  - Group managed service accounts (gMSA) (under users OU)
#  - Azurestack Hci cluster object (under computers OU)
#
# This script should be run by a user that has domain admin privileges to the domain.
#
# Parameter Ex:
#  -AsHciOUName "OU=Hci001,OU=HciDeployments,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com" [Hci001 OU will be created under OU=HciDeployments,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com]
#  -DomainFQDN "Test.microsoft.com"
#  -AsHciClusterName "s-cluster"
#
# Usage Ex:
#
#  .\AsHciADArtifactsPreCreationTool.ps1 -AsHciDeploymentUserCredential (get-credential) -AsHciOUName "OU=Hci001,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com" -AsHciPhysicalNodeList @("Physical Machine1", "Physical Machine2") -DomainFQDN "Test.microsoft.com" -AsHciClusterName "s-cluster" -AsHciDeploymentPrefix "Hci001"
#
#  To Rerun the script
#  .\AsHciADArtifactsPreCreationTool.ps1 -AsHciDeploymentUserCredential (get-credential) -AsHciOUName "OU=Hci001,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com" -AsHciPhysicalNodeList @("Physical Machine1", "Physical Machine2") -DomainFQDN "Test.microsoft.com" -AsHciClusterName "s-cluster" -AsHciDeploymentPrefix "Hci001" -Rerun
#
#  To Delete existing cluster use -Rerun -Force options
#  .\AsHciADArtifactsPreCreationTool.ps1 -AsHciDeploymentUserCredential (get-credential) -AsHciOUName "OU=Hci001,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com" -AsHciPhysicalNodeList @("Physical Machine1", "Physical Machine2") -DomainFQDN "Test.microsoft.com" -AsHciClusterName "s-cluster" -AsHciDeploymentPrefix "Hci001" -Rerun -Force


[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium", PositionalBinding=$false)]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [PSCredential] $AsHciDeploymentUserCredential,

    [Parameter(Mandatory=$true)]
    [validatePattern('^(ou=[a-z0-9]*\,)')]
    [ValidateNotNullOrEmpty()]
    [string] $AsHciOUName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string[]] $AsHciPhysicalNodeList,

    [Parameter(Mandatory=$true)]
    [ValidateLength(1,8)]
    [string] $AsHciDeploymentPrefix,

    [Parameter(Mandatory=$true)]
    [validatePattern('^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')]
    [ValidateNotNullOrEmpty()]
    [string] $DomainFQDN,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string] $AsHciClusterName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string] $DNSServerIP,

    [Parameter(Mandatory=$false)]
    [Switch] $Rerun,

    [Parameter(Mandatory=$false)]
    [Switch] $Force

)

<#
 .Synopsis
  Tests kds root key configuration.

 .Parameter DomainFQDN
  The AD domain fqdn.
#>

function Test-KDSConfiguration
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $DomainFQDN
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    try
    {
        $adDomainController = Get-ADDomainController -DomainName $DomainFQDN -Discover -MinimumDirectoryServiceVersion Windows2012 -NextClosestSite
        $dcName = "$($adDomainController.Name).$($adDomainController.Domain)"
        Write-Verbose "Domain controller :: $dcName"
    }
    catch
    {
        Write-Error "Make sure a domain controller with minimum OS level of 'Windows Server 2012' is available"
    }

    # Checking for kds root key
    try
    {
        Write-Verbose "Checking for KDS root key"
        $KdsRootKeys = Get-KdsRootKey
        if ((-not $kdsRootKeys) -or ($kdsRootKeys.Count -eq 0))
        {
            Write-Error "KDS rootkey is not found/configured, please configure KDS root key. KDS rootkey Configure cmdlet 'Add-KdsRootKey '"
        }
        $kdsRootKeyEffective = $false

        foreach ($KdsRootKey in $KdsRootKeys)
        {
            # make sure it is effective at least 10 hours ago
            if(((Get-Date) - $KdsRootKey.EffectiveTime).TotalHours -ge 10)
            {
                Write-Verbose "Found KDS rootkey and it is effective "
                $kdsRootKeyEffective = $true
                break
            }
        }
        if (! $kdsRootKeyEffective)
        {
            Write-Error "Found KDS rootkey but it is not active."
        }
    }
    catch
    {
        Write-Error "Unable to verify kds configuration. Error :: $_"
    }
}

<#
 .Synopsis
  Tests hci parent organization unit.

 .Parameter AsHciParentOUPath
  The hci parent ou path.
#>

function Test-AsHciParentOU
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $AsHciOUPath
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    $hciParentOUPath = $AsHciOUPath.Split(",",2)[1]
    if ($Null -eq $hciParentOUPath)
    {
        Write-Error "Hci OU path '$AsHciOUName' is invalid. Please provide full OU path. Ex:- 'OU=Hci001,OU=HciDeployments,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com'"
    }

    try
    {
        if (-not [adsi]::Exists("LDAP://$hciParentOUPath"))
        {
            Write-Error "'$hciParentOUPath' does not exist, please create $hciParentOUPath and run the tool"
        }
        Write-Verbose "Successfully verified $hciParentOUPath"
    }
    catch
    {
        Write-Error "'$hciParentOUPath' is invalid, please provide valid path"
    }
}


<#
 .Synopsis
  Verifies deployment prefix uniqueness.

 .Parameter AsHciParentOUPath
  The hci parent ou path.

 .Parameter AsHciParentOUPath
  The hci parent ou path.

#>

function Test-AsHciDeploymentPrefix
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $AsHciOUPath,

        [Parameter(Mandatory = $true)]
        [string]
        $AsHciDeploymentPrefix
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $opsAdminGroup = "$AsHciDeploymentPrefix-OpsAdmin"
    $hciGroup = Get-AdGroup -Filter { Name -eq $opsAdminGroup}
    # Test for unique AsHciDeploymentPrefix
    if ($hciGroup)
    {
        if (-not ($hciGroup.DistinguishedName -match $AsHciOUPath) )
        {
            Write-Error "Deployment prefix '$AsHciDeploymentPrefix' is in use, please provide an unique prefix"
        }
    }
}

<#
 .Synopsis
  Creates HCI organization unit in a given AD domain.

 .Parameter DomainOUPath
  The AD domain organization unit path

 .Parameter HciOUName
  The HCI organizational unit name.
#>

function New-AsHciOrganizationalUnit
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $DomainOUPath,

        [Parameter(Mandatory = $true)]
        [String]
        $OUName,

        [Parameter(Mandatory = $false)]
        [bool]
        $Rerun
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    $ouPath = Get-ADOrganizationalUnit -SearchBase $DomainOUPath -Filter { Name -eq $OUName } | Select-Object DistinguishedName
    if ($ouPath -and (-not $Rerun))
    {
        Write-Error "Hci organizational unit '$OUName' exists under '$DomainOUPath', to continue with this OU please execute the tool with -Rerun flag"
    }

    try
    {
        # Creating Hci organization unit
        if ($ouPath)
        {
            Write-Verbose "Hci organizational unit '$OUName' exists under '$DomainOUPath', skipping"
        }
        else
        {
            New-ADOrganizationalUnit -Name $OUName -Path $DomainOUPath
            Write-Verbose "Successfully created $OUName organization unit under '$DomainOUPath' "
        }
    }
    catch
    {
        Write-Error "Failed to create organization unit. Exception :: $_"
    }
}

<#
 .Synopsis
  Creates hci deployment users under hci users organization unit path.

 .Parameter AsHciDeploymentUserName
  The azure stack hci deployment user names

 .Parameter DomainFQDN
  The active directory domain fqdn

 .Parameter AsHciUserPassword
  The azure stack hci user password.

 .Parameter HciUsersOUPath
  The hci users organization unit path object.

#>

function New-AsHciUser
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $AsHciDeploymentUserName,

        [Parameter(Mandatory = $true)]
        [String]
        $DomainFQDN,

        [Parameter(Mandatory = $true)]
        [SecureString]
        $AsHciUserPassword,

        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciUsersOUPath,

        [Parameter(Mandatory = $false)]
        [bool]
        $Rerun
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    try
    {
        $user = Get-ADUser -SearchBase $AsHciUsersOUPath -Filter { Name -eq $AsHciDeploymentUserName }
        if ($user -and (-not $Rerun))
        {
            Write-Error "$AsHciDeploymentUserName exists, please provide an unique username."
        }
        if ($user)
        {
            Write-verbose "$AsHciDeploymentUserName exists under $AsHciUsersOUPath, skipping."
        }
        else
        {
            New-ADUser -Name $AsHciDeploymentUserName -AccountPassword $AsHciUserPassword -UserPrincipalName "$AsHciDeploymentUserName@$DomainFQDN" -Enabled $true -PasswordNeverExpires $true -path $AsHciUsersOUPath.DistinguishedName
            Write-Verbose "Successfully created '$AsHciDeploymentUserName' under '$AsHciUsersOUPath'"
        }
    }
    catch
    {
        if ($_ -match 'The operation failed because UPN value provided for addition/modification is not unique forest-wide')
        {
            Write-Error "UserPrincipalName '$AsHciDeploymentUserName@$DomainFQDN' already exists, please provide a different user name"
        }
        elseif ($_ -match 'The specified account already exists')
        {
            Write-Error "$AsHciDeploymentUserName already exists, please provide a different user name"
        }
        else
        {
            Write-Error "Unable to create $AsHciDeploymentUserName. Error :: $_ "
        }
    }
}

<#
 .Synopsis
  Grants full access permissions of hci organization unit to hci deployment user.

 .Parameter HciDeploymentUserName
  The hci deployment user name.

 .Parameter HciOUPath
  The hci organization unit path.
#>
function Grant-HciOuPermissionsToHciDeploymentUser
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $AsHciDeploymentUserName,

        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciOUPath

    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    try
    {
        $ouPath = "AD:\$($AsHciOUPath.DistinguishedName)"

        $userSecurityIdentifier = Get-ADuser -Identity $AsHciDeploymentUserName
        $userSID = [System.Security.Principal.SecurityIdentifier] $userSecurityIdentifier.SID
        $acl = Get-Acl -Path $ouPath
        $userIdentityReference = [System.Security.Principal.IdentityReference] $userSID
        $adRight = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
        $type = [System.Security.AccessControl.AccessControlType] "Allow"
        $inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
        $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($userIdentityReference, $adRight, $type, $inheritanceType)
        $acl.AddAccessRule($Rule)
        Set-Acl -Path $ouPath -AclObject $acl

        (Get-Acl $ouPath).Access | Where-Object IdentityReference -eq $userSID
        Write-Verbose "Successfully granted access permissions '$($AsHciOUPath.DistinguishedName)' to '$AsHciDeploymentUserName'"
    }
    catch
    {
        Write-Error "Failed to grant access permissions '$($AsHciOUPath.DistinguishedName)' to '$AsHciDeploymentUserName'. Error :: $_"
    }
}

<#
 .Synopsis
  Pre creates computer object in AD under hci computers ou path.

 .Parameter Machines
  The list of machines required for hci deployment.

 .Parameter DomainFQDN
  The domain fqdn.

 .Parameter HciComputerOuPath
  The hci computers ou path.
#>

function New-MachineObject
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory = $true)]
        [String[]]
        $Machines,

        [Parameter(Mandatory = $true)]
        [String]
        $DomainFQDN,

        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciComputerOuPath
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    foreach ($node in $Machines)
    {
        try
        {
            $computerObject = Get-ADComputer -SearchBase $($AsHciComputerOuPath.DistinguishedName) -Filter {Name -eq $node }
            if ($computerObject)
            {
                Write-Verbose "$node exists in AD, skipping computer object creation."
            }
            else
            {
                New-ADComputer -Name $node -SAMAccountName $node -DNSHostName "$node.$DomainFQDN" -Path $AsHciComputerOuPath
                Write-Verbose "Successfully created $node computer object under $($AsHciComputerOuPath.DistinguishedName)"
            }
        }
        catch
        {
            if ($_ -match 'The specified account already exists')
            {
                Write-Error "$node object already exists, move $node object under '$($AsHciComputerOuPath.DistinguishedName)'"
            }
            else
            {
                Write-Error "Error :: $_"
            }
        }
    }
}


<#
  .Synopsis
  Enables dynamic updates in the DNS zone corresponding to the domain and gives NC VMs permissions to update it.

  .Parameter DomainFQDN
  The domain fqdn.

  .Parameter DeploymentPrefix
  The deployment domain prefix.

  .Parameter OrganizationalUnit
  The OrganizationalUnit object under which the NC computer objects will be created

  .Parameter DNSServerIP
  IP of the DNS Server.
#>

function Set-DynamicDNSAndConfigureDomainZoneForNC
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $DomainFQDN,

        [Parameter(Mandatory = $true)]
        [string]
        $DeploymentPrefix,

        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $OrganizationalUnit,

        [Parameter(Mandatory=$false)]
        [string] $DNSServerIP
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    try
    {
        $dnsZone = Get-DnsServerZone -Name $DomainFQDN -ComputerName $DNSServerIP
        if ($dnsZone.DynamicUpdate -eq "NonsecureAndSecure")
        {
            Write-Verbose "DNS server is configured to accept dynamic updates from secure and non-secure sources. No further DNS configuration changes are needed."
            return
        }

        Write-Verbose "Configuring DNS server to accept secure dynamic updates. Identities with the right access will be allowed to update DNS entries."
        Set-DnsServerPrimaryZone -Name $DomainFQDN -ComputerName $DNSServerIP -DynamicUpdate Secure

        $ncVmNames = @("$DeploymentPrefix-NC01", "$DeploymentPrefix-NC02", "$DeploymentPrefix-NC03")

        Write-Verbose "Pre-creating the following computer objects for the Network Controller nodes: $ncVmNames."
        New-MachineObject -Machines $ncVmNames -DomainFQDN $DomainFQDN -AsHciComputerOuPath $OrganizationalUnit -Verbose

        $domainZoneAcl = Get-Acl "AD:\$($dnsZone.DistinguishedName)"

        foreach ($ncVm in $ncVmNames)
        {
            Write-Verbose "Giving access to $ncVm to allow it to do DNS dynamic updates."

            $adComputer = Get-ADComputer $ncVm
            $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $adComputer.SID,'GenericAll','Allow'
            $domainZoneAcl.AddAccessRule($ace)
        }

        Set-Acl -AclObject $domainZoneAcl "AD:\$($dnsZone.DistinguishedName)"

        Write-Output "List of AD identities with write permissions that are allowed to do DNS dynamic updates to DNS zone: $DomainFQDN."

        $domainZoneAcl.Access | where -FilterScript {($_.ActiveDirectoryRights -band `
            [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite) -eq `
            [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite -and `
            $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow} `
            | select @{n="Identities";e={$_.IdentityReference}}
    }
    catch
    {
        Write-Error "Failed to configure the DNS server to support dynamic updates. Please enable dynamic updates manually in your DNS server."
    }
}


<#
 .Synopsis
  Prestage cluster computer object in AD
  Refer to https://docs.microsoft.com/en-us/windows-server/failover-clustering/prestage-cluster-adds

 .Parameter OrganizationalUnit
  The OrganizationalUnit object under which to create the cluster computer object

 .Parameter ClusterName
  The cluster name

 .Parameter Force
  Whether overwrite exiting cluster computer object

 .Example
  $ou = Get-ADOrganizationalUnit -Filter 'Name -eq "testou"'
  New-ADPrestagedCluster -OrganizationalUnit $ou -ClusterName 's-cluster' -Force
#>
function New-PrestagedAsHciCluster
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
          [Parameter(Mandatory=$true)]
          [ValidateNotNull()]
          [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
          $OrganizationalUnit,

          [Parameter(Mandatory=$true)]
          [ValidateNotNullOrEmpty()]
          [string]
          $ClusterName,

          [Parameter(Mandatory = $false)]
          [bool]
          $Force
    )

    $ErrorActionPreference = "Stop"

    Write-Verbose "Checking computer '$ClusterName' in AD ..." -Verbose

    $cno = Get-ADComputer -Filter "Name -eq '$ClusterName'"

    if ($cno)
    {
        $cno
        if ($Force)
        {
            Write-Verbose "Removing computer '$ClusterName' from AD ..."
            $cno | Set-ADObject -ProtectedFromAccidentalDeletion:$false -Verbose
            $cno | Remove-ADComputer -Confirm:$false -Verbose
        }
        else
        {
            Write-Error "Found existing computer with name '$ClusterName', please check the current usage of this object, and rerun with -Rerun -Force to overwrite this object."
        }
    }

    Write-Verbose "Creating computer '$ClusterName' under OU '$($OrganizationalUnit.DistinguishedName)' ..." -Verbose

    $cno = New-ADComputer -Name $ClusterName -Description 'Cluster Name Object of HCI deployment' -Path $OrganizationalUnit.DistinguishedName -Enabled $false -PassThru -Verbose
    $cno | Set-ADObject -ProtectedFromAccidentalDeletion:$true -Verbose

    Write-Verbose "Configuring permission for computer '$ClusterName' ..." -Verbose

    $ouPath = "AD:\$($OrganizationalUnit.DistinguishedName)"
    $ouAcl = Get-Acl $ouPath
    $ouAclUpdate = New-Object System.DirectoryServices.ActiveDirectorySecurity

    foreach ($ace in $ouAcl.Access)
    {
        if ($ace.IdentityReference -notlike "*\$ClusterName$")
        {
            $ouAclUpdate.AddAccessRule($ace)
        }
    }

    # Refer to https://docs.microsoft.com/en-us/windows/win32/adschema/c-computer
    $computersObjectType = [System.Guid]::New('bf967a86-0de6-11d0-a285-00aa003049e2')
    $allObjectType = [System.Guid]::Empty
    $ace1 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $cno.SID, "CreateChild", "Allow", $computersObjectType, "All"
    $ace2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $cno.SID, "ReadProperty", "Allow", $allObjectType, "All"

    $ouAclUpdate.AddAccessRule($ace1)
    $ouAclUpdate.AddAccessRule($ace2)

    $ouAclUpdate | Set-Acl $ouPath -Verbose

    (Get-Acl $ouPath).Access | Where-Object IdentityReference -like "*\$ClusterName$"

    Write-Verbose "Finish prestage for cluster '$ClusterName'." -Verbose
}


<#
 .Synopsis
  Creates required security groups for hci deployment.

 .Parameter HciUsersOuPath
  The hci users organization unit object.

 .Parameter HciComputersOuPath
  The hci computers organization unit object.

 .Parameter DeploymentPrefix
  The hci deployment prefix.

 .Parameter PhysicalMachines
  The hci cluster physical machines.

 .Parameter HciDeploymentUserName
  The hci deployment username.
#>
function New-AsHciSecurityGroup
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciUsersOuPath,

        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciComputersOuPath,

        [Parameter(Mandatory = $true)]
        [string]
        $DeploymentPrefix,

        [Parameter(Mandatory = $false)]
        [string[]]
        $PhysicalMachines,

        [Parameter(Mandatory = $true)]
        [string]
        $AsHciDeploymentUserName
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    Write-Verbose "Creating security groups under '$($AsHciUsersOuPath.DistinguishedName)'"
    # List of security groups required for hci deployment.
    $securityGroups = @( "AzS-Sto-SG",
                     "AzS-FsAcl-InfraSG",
                     "AzS-FsAcl-AcsSG",
                     "AzS-CertificateReadersSG",
                     "AzS-Slb-VmSG",
                     "AzS-Gw-VmSG",
                     "AzS-FsAcl-SqlSG",
                     "AzS-Fab-SrvSG",
                     "AzS-HA-SrvSG",
                     "AzS-Ercs-EceSG",
                     "AzS-Host-EceSG",
                     "AzS-HA-R-SrvSG",
                     "AzS-SB-Jea-LC-VmSG",
                     "AzS-Hc-Rs-SrvSG",
                     "AzS-Agw-SrvSG",
                     "AzS-Hrp-HssSG",
                     "AzS-IH-HsSG",
                     "AzS-Ercs-VmSG",
                     "JEAMachinesTemp",
                     "AzS-NC-VmSG",
                     "AzS-Nc-BmSG",
                     "AzS-NC-FsSG",
                     "$($DeploymentPrefix)-OpsAdmin",
                     "AzS-SB-Jea-MG-VmSG",
                     "Azs-Nc-EceSG",
                     "AzS-FsAcl-PublicSG")

    foreach ($securityGroup in $securityGroups)
    {
        try
        {
            $adGroup = Get-AdGroup -SearchBase $($AsHciUsersOuPath.DistinguishedName) -Filter { Name -eq $SecurityGroup}
            if ($adGroup)
            {
                Write-Verbose "$securityGroup is present on AD hence skipping."
            }
            else
            {
                New-ADGroup -Name $SecurityGroup -DisplayName $securityGroup -Description $securityGroup -GroupCategory Security -GroupScope DomainLocal -Path $($AsHciUsersOuPath.DistinguishedName)
            }
            Write-Verbose "$securityGroup successfully created."
        }
        catch
        {
            Write-Error "$SecurityGroup creation failed. Error :: $_ "
        }
    }

    Write-Verbose "Successfully created security groups under '$($AsHciUsersOuPath.DistinguishedName)'"
    # Todo :: Do we really need JEAMachinesTemp security group?

    $physicalMachineSecurityGroups = @("AzS-Sto-SG","JEAMachinesTemp")
    #Add physical machines to the security groups.
    foreach ($physicalMachine in $PhysicalMachines)
    {
        $machineObject = Get-ADComputer -SearchBase $($AsHciComputersOuPath.DistinguishedName) -Filter {Name -eq $physicalMachine}
        Add-Membership -IdentityObject $machineObject -SecurityGroupNames $physicalMachineSecurityGroups -AsHciUsersOUPath $($AsHciUsersOuPath.DistinguishedName)
    }

    #Add user membership.
    $AsHciUserSecurityGroups = @("AzS-Ercs-EceSG", "AzS-Host-EceSG", "AzS-FsAcl-InfraSG", "AzS-FsAcl-AcsSG", "$($AsHciDeploymentPrefix)-OpsAdmin", "Azs-Nc-EceSG")
    $userIdentity = Get-ADUser -SearchBase $AsHciUsersOuPath.DistinguishedName -Filter { Name -eq $AsHciDeploymentUserName }
    Add-Membership -IdentityObject $userIdentity -SecurityGroupNames $AsHciUserSecurityGroups -AsHciUsersOuPath $AsHciUsersOuPath.DistinguishedName

}

<#
 .Synopsis
  Creates required group managed service accounts for hci deployment.

 .Parameter DomainFQDN
  The domain fqdn.

 .Parameter AsHciUsersOuPath
  The hci users organization unit object.
#>

function New-AsHciGmsaAccount
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (

        [Parameter(Mandatory = $true)]
        [String]
        $DomainFQDN,

        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciUsersOuPath

    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    # List of gMSA accounts, it's membership, principals allowed to retrieve the password and service principal names if any.
    $gmsaAccounts =
    @([pscustomobject]@{ GmsaName="AzS-Host-EceSA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@("AzS/ae3299a9-3e87-4186-bd99-c43c9ae6a571");
                         MemberOf=@("AzS-FsAcl-SqlSG", "AzS-Fab-SrvSG","AzS-HA-SrvSG", "AzS-Ercs-EceSG", "AzS-Host-EceSG","AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Host-Alm";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Nc-Alm";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Nc-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Slb-Alm";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Slb-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Gw-Alm";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Gw-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Host-Fca";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Nc-Fca";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Nc-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Slb-Fca";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Slb-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Gw-Fca";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Gw-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-SB-JeaLC-SA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Host-Fra";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Host-Tca";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-NC-Tca";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Nc-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-NC-Fra";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Nc-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Nc-HASA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Nc-VmSG");
                         ServicePrincipalName=@("AzS/NC/1b4dde6b-7ea8-407a-8c9e-f86e8b97fd1c");
                         MemberOf=@("AzS-FsAcl-InfraSG","AzS-HA-R-SrvSG")},

    [pscustomobject]@{ GmsaName="AzS-Host-HASA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@("AzS/PhysicalNode/1b4dde6b-7ea8-407a-8c9e-f86e8b97fd1c");
                         MemberOf=@("AzS-FsAcl-InfraSG","AzS-HA-R-SrvSG")},

    [pscustomobject]@{ GmsaName="AzS-SB-LC-SrvSA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG", "AzS-SB-Jea-LC-VmSG");
                         ServicePrincipalName=@("AzS/754dbc04-8f91-4cb6-a10f-899dac573fa0");
                         MemberOf=@("AzS-FsAcl-InfraSG","AzS-SB-Jea-LC-VmSG","AzS-Sto-SG" ) },

    [pscustomobject]@{ GmsaName="AzS-SB-JeaLC-SA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG","AzS-Sto-SG" ) },

    [pscustomobject]@{ GmsaName="AzS-SB-MG-SRVSA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG", "AzS-SB-Jea-MG-VmSG");
                         ServicePrincipalName=@("AzS/ea126685-c89e-4294-959f-bba6bf75b4aa");
                         MemberOf=@("AzS-FsAcl-InfraSG","AzS-SB-Jea-MG-VmSG", "AzS-Sto-SG" ) },

    [pscustomobject]@{ GmsaName="AzS-SB-JeaMG-SA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG", "AzS-Sto-SG" ) },

    [pscustomobject]@{ GmsaName="AzS-NC-SA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-NC-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-NC-VmSG")},

    [pscustomobject]@{ GmsaName="AzS-Nc-TSSA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-NC-VmSG");
                         ServicePrincipalName=@();
                         MemberOf=@("AzS-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="AzS-Ercs-EceSA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@("AzS/4dde37cc-6ee0-4d75-9444-7061e156507f");
                         MemberOf=@("AzS-FsAcl-InfraSG", "AzS-FsAcl-SqlSG", "AzS-Fab-SrvSG", "AzS-HA-SrvSG", "AzS-Ercs-EceSG", "AzS-CertificateReadersSG", "AzS-Host-EceSG", "AzS-Nc-EceSG")},

    [pscustomobject]@{ GmsaName="AzS-NC-ECESA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Nc-VmSG");
                         ServicePrincipalName=@("AzS/128fd370-07e4-41ac-876f-738c3c4cfd1b");
                         MemberOf=@("AzS-FsAcl-SqlSG", "AzS-Fab-SrvSG", "AzS-HA-SrvSG", "AzS-Ercs-EceSG", "Azs-Nc-EceSG", "AzS-FsAcl-InfraSG")},


    [pscustomobject]@{ GmsaName="AzS-Urp-SrvSA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("AzS-Sto-SG");
                         ServicePrincipalName=@("AzS/110bac92-1879-47ae-9611-e40f8abf4fc0");
                         MemberOf=@("AzS-FsAcl-PublicSG", "AzS-FsAcl-InfraSG", "AzS-Host-EceSG", "AzS-Fab-SrvSG", "AzS-Ercs-EceSG")})

    # Creating gmsa accounts.
    foreach ($gmsaAccount in $GmsaAccounts)
    {
        try
        {
            $gmsaName = $($gmsaAccount.GmsaName)
            $adGmsaAccount = Get-ADServiceAccount -SearchBase $($AsHciUsersOuPath.DistinguishedName) -Filter {Name -eq $gmsaName}
            if ($adGmsaAccount)
            {
                Write-Verbose "$gmsaName exists hence skipping."
            }
            else
            {
                if ($($gmsaAccount.ServicePrincipalName).count -ge 1)
                {
                    New-ADServiceAccount -Name $gmsaName -DNSHostName "$($gmsaAccount.GmsaName).$DomainFQDN" -ServicePrincipalNames $($gmsaAccount.ServicePrincipalName) -PrincipalsAllowedToRetrieveManagedPassword $($gmsaAccount.PrincipalsAllowedToRetrieveManagedPassword) -ManagedPasswordIntervalInDays 1 -KerberosEncryptionType AES256 -Path $($AsHciUsersOuPath.DistinguishedName)
                }
                else
                {
                    New-ADServiceAccount -Name $gmsaName -DNSHostName "$($gmsaAccount.GmsaName).$DomainFQDN" -PrincipalsAllowedToRetrieveManagedPassword $($gmsaAccount.PrincipalsAllowedToRetrieveManagedPassword) -ManagedPasswordIntervalInDays 1 -KerberosEncryptionType AES256 -Path $($AsHciUsersOuPath.DistinguishedName)
                }
                Write-Verbose "Successfully created $gmsaName on AD"
            }
            $serviceAccountIdentityObject = Get-ADServiceAccount -SearchBase $($AsHciUsersOuPath.DistinguishedName) -Filter {Name -eq $gmsaName}
            Add-Membership -IdentityObject $serviceAccountIdentityObject -SecurityGroupNames $($gmsaAccount.MemberOf) -AsHciUsersOuPath $($AsHciUsersOuPath.DistinguishedName)
        }
        catch
        {
            if ($_ -match 'The operation failed because SPN value provided for addition/modification is not unique forest-wide')
            {
                Write-Error "SPN '$($gmsaAccount.ServicePrincipalName)' already exists, please remove the SPN and Rerun the tool."
            }
            Write-Error "Failed to create $gmsaName or adding it's membership. Error :: $_"
        }
    }
}

<#
 .Synopsis
  Add security group membership to other required security groups.

 .Parameter HciUsersOuPath
  The hci users ou path.

#>

function Add-GroupMembership
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciUsersOuPath

    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    # Security group memberships.
    $SecurityGroupMemberships =
    @([pscustomobject]@{ Name="AzS-HA-R-SrvSG";
                         MemberOf=@("AzS-Hc-Rs-SrvSG", "AzS-Agw-SrvSG","AzS-Hrp-HssSG", "AzS-IH-HsSG","AzS-FsAcl-InfraSG")} ,

    [pscustomobject]@{ Name="AzS-NC-VmSG";
                         MemberOf=@("AzS-FsAcl-AcsSG", "AzS-FsAcl-InfraSG")})

    foreach ($securityGroupMembership in $SecurityGroupMemberships)
    {
        $group = $securityGroupMembership.Name
        $SecurityGroupNames = $securityGroupMembership.MemberOf
        $groupObject = Get-ADGroup -SearchBase $($AsHciUsersOuPath.DistinguishedName) -Filter {Name -eq $group}
        Add-Membership -IdentityObject $groupObject -SecurityGroupNames $SecurityGroupNames -AsHciUsersOuPath $AsHciUsersOuPath
    }
}


<#
 .Synopsis
  Helper function to add the membership of an identity object to the security group name.

 .Parameter IdentityObject
  The ad identity object.

 .Parameter SecurityGroupNames
  The list of security group names.

 .Parameter HciUsersOuPath
  The hci users ou path.

#>

function Add-Membership
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        $IdentityObject,

        [Parameter(Mandatory = $true)]
        $SecurityGroupNames,

        [Parameter(Mandatory = $true)]
        $AsHciUsersOuPath
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    foreach ($securityGroupName in $SecurityGroupNames)
    {
        try
        {
            $groupObject =  Get-ADGroup -SearchBase $AsHciUsersOuPath -Filter {Name -eq $securityGroupName}
            if (-not $groupObject)
            {
                Write-Error "$securityGroupName is not available."
            }

            $isMember = Get-ADGroupMember -Identity $groupObject |Where-Object {$_.Name -eq $($IdentityObject.Name)}
            if ($isMember)
            {
                Write-Verbose "$($IdentityObject.Name) is already a member of $securityGroupName hence skipping"
            }
            else
            {
                Add-ADGroupMember -Identity $groupObject -Members $IdentityObject
                Write-Verbose "Finished adding '$($IdentityObject.Name)' as a member of the group '$securityGroupName'."
            }
        }
        catch
        {
            Write-Error "Failed to add the $($IdentityObject.Name) to $securityGroupName. Error :: $_"
        }
    }
}

<#
 .Synopsis
  Blocks gpo inheritance to Hci ou

 .Parameter HciOUs
  List of hci ou
#>

function Block-GPInheritance
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit[]]
        $AsHciOUs
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    foreach ($asHciOu in $AsHciOUs)
    {
        try
        {
            $gpInheritance = Get-GPInheritance -Target $($asHciOu.DistinguishedName)
            if (-not $gpInheritance.GpoInheritanceBlocked)
            {
                $gpInheritance = Set-GPInheritance -Target $($asHciOu.DistinguishedName) -IsBlocked Yes
            }
            Write-Verbose "Gpo inheritance blocked for '$($asHciOu.DistinguishedName)', inheritance blocked state is : $($gpInheritance.GpoInheritanceBlocked)"
        }
        catch
        {
            Write-Error "Failed to block gpo inheritance for '$($asHciOu.DistinguishedName)'. Error :: $_"
        }
    }
}

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

# import required modules
$modules = @('ActiveDirectory','GroupPolicy','Kds')
foreach ($module in $modules)
{
    Import-Module -Name $module -Verbose:$false -ErrorAction Stop | Out-Null
}

# Test kds root key configuration.
Test-KDSConfiguration -DomainFQDN $DomainFQDN -Verbose

# Test hci parent ou path exists or not."
Test-AsHciParentOU -AsHciOUPath $AsHciOUName -Verbose
$hciParentOUPath = $AsHciOUName.Split(",",2)[1]

Test-AsHciDeploymentPrefix -AsHciOUPath $AsHciOUName -AsHciDeploymentPrefix $AsHciDeploymentPrefix -Verbose

# Create Hci organization units
$hciOUName = ($AsHciOUName.Split(",",2)[0]).split("=")[1]
# Write-Verbose "Creating $hciOUName under $hciParentOUPath"
New-AsHciOrganizationalUnit -DomainOUPath $hciParentOUPath -OUName $hciOUName -Rerun $Rerun -Verbose
$asHciOUPath = Get-ADOrganizationalUnit -SearchBase $hciParentOUPath -Filter { Name -eq $hciOUName }

# Create computers OU under $asHciOUPath
$computersOU = "Computers"
New-AsHciOrganizationalUnit -DomainOUPath $($asHciOUPath.DistinguishedName) -OUName $computersOU -Rerun $Rerun -Verbose
$asHciComputersOUPath = Get-ADOrganizationalUnit -SearchBase $asHciOUPath.DistinguishedName -Filter { Name -eq $computersOU }

# Create users OU under $asHciOUPath
$usersOU = "Users"
New-AsHciOrganizationalUnit -DomainOUPath $($asHciOUPath.DistinguishedName) -OUName $usersOU -Rerun $Rerun -Verbose
$asHciUsersOUPath = Get-ADOrganizationalUnit -SearchBase $asHciOUPath.DistinguishedName -Filter { Name -eq $usersOU }


# Create Hci deployment user under Hci users OU path
$asHciDeploymentUserName = $AsHciDeploymentUserCredential.UserName
$asHciDeploymentUserPassword = $AsHciDeploymentUserCredential.Password
New-AsHciUser -AsHciDeploymentUserName $asHciDeploymentUserName -AsHciUserPassword $asHciDeploymentUserPassword -DomainFQDN $DomainFQDN -AsHciUsersOUPath $asHciUsersOUPath -Rerun $Rerun -Verbose

# Grant permissions to hci deployment user
Grant-HciOuPermissionsToHciDeploymentUser -AsHciDeploymentUserName $asHciDeploymentUserName -AsHciOUPath $asHciOUPath -Verbose

# Pre-create computer objects
if ($AsHciPhysicalNodeList.Count -gt 0)
{
    New-MachineObject -Machines $AsHciPhysicalNodeList -DomainFQDN $DomainFQDN -AsHciComputerOuPath $asHciComputersOUPath -Verbose
}

# Pre-create cluster objects
if ($AsHciClusterName -ne $null)
{
    New-PrestagedAsHciCluster -OrganizationalUnit $asHciComputersOUPath -ClusterName $AsHciClusterName -Force $Force -Verbose
}

# Create security groups
New-AsHciSecurityGroup -AsHciUsersOuPath $asHciUsersOUPath -AsHciComputersOuPath $asHciComputersOUPath -PhysicalMachines $AsHciPhysicalNodeList -DeploymentPrefix $AsHciDeploymentPrefix -AsHciDeploymentUserName $asHciDeploymentUserName -Verbose

# Create gMSA accounts
New-AsHciGmsaAccount -DomainFQDN $DomainFQDN -AsHciUsersOuPath $AsHciUsersOuPath -Verbose

# Add security group membership to other security groups.
Add-GroupMembership -AsHciUsersOuPath $AsHciUsersOuPath -Verbose

# Block gpo inheritance to hci ou
Block-GPInheritance -AsHciOUs @($asHciOUPath, $asHciUsersOUPath,$asHciComputersOUPath) -Verbose

if ($DNSServerIP)
{
    # Configure the DNS to support dynamic updates and give NC VMs permissions to update the domain zone
    Set-DynamicDNSAndConfigureDomainZoneForNC -DomainFQDN $DomainFQDN -DeploymentPrefix $AsHciDeploymentPrefix -OrganizationalUnit $asHciComputersOUPath -DNSServerIP $DNSServerIP -Verbose
}
else
{
    Write-Warning "DNSServerIP parameter was not provided, so configuring dynamic DNS updates on the server was skipped. Please make sure that your DNS supports dynamic updates and that Network Controller VMs have access to do DNS updates."
}

# SIG # Begin signature block
# MIIntwYJKoZIhvcNAQcCoIInqDCCJ6QCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBUR5k0a5wlCtHi
# zU0WWbNabrI6DvN588dI+RHPsRMaBaCCDYEwggX/MIID56ADAgECAhMzAAACzI61
# lqa90clOAAAAAALMMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjIwNTEyMjA0NjAxWhcNMjMwNTExMjA0NjAxWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCiTbHs68bADvNud97NzcdP0zh0mRr4VpDv68KobjQFybVAuVgiINf9aG2zQtWK
# No6+2X2Ix65KGcBXuZyEi0oBUAAGnIe5O5q/Y0Ij0WwDyMWaVad2Te4r1Eic3HWH
# UfiiNjF0ETHKg3qa7DCyUqwsR9q5SaXuHlYCwM+m59Nl3jKnYnKLLfzhl13wImV9
# DF8N76ANkRyK6BYoc9I6hHF2MCTQYWbQ4fXgzKhgzj4zeabWgfu+ZJCiFLkogvc0
# RVb0x3DtyxMbl/3e45Eu+sn/x6EVwbJZVvtQYcmdGF1yAYht+JnNmWwAxL8MgHMz
# xEcoY1Q1JtstiY3+u3ulGMvhAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUiLhHjTKWzIqVIp+sM2rOHH11rfQw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDcwNTI5MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAeA8D
# sOAHS53MTIHYu8bbXrO6yQtRD6JfyMWeXaLu3Nc8PDnFc1efYq/F3MGx/aiwNbcs
# J2MU7BKNWTP5JQVBA2GNIeR3mScXqnOsv1XqXPvZeISDVWLaBQzceItdIwgo6B13
# vxlkkSYMvB0Dr3Yw7/W9U4Wk5K/RDOnIGvmKqKi3AwyxlV1mpefy729FKaWT7edB
# d3I4+hldMY8sdfDPjWRtJzjMjXZs41OUOwtHccPazjjC7KndzvZHx/0VWL8n0NT/
# 404vftnXKifMZkS4p2sB3oK+6kCcsyWsgS/3eYGw1Fe4MOnin1RhgrW1rHPODJTG
# AUOmW4wc3Q6KKr2zve7sMDZe9tfylonPwhk971rX8qGw6LkrGFv31IJeJSe/aUbG
# dUDPkbrABbVvPElgoj5eP3REqx5jdfkQw7tOdWkhn0jDUh2uQen9Atj3RkJyHuR0
# GUsJVMWFJdkIO/gFwzoOGlHNsmxvpANV86/1qgb1oZXdrURpzJp53MsDaBY/pxOc
# J0Cvg6uWs3kQWgKk5aBzvsX95BzdItHTpVMtVPW4q41XEvbFmUP1n6oL5rdNdrTM
# j/HXMRk1KCksax1Vxo3qv+13cCsZAaQNaIAvt5LvkshZkDZIP//0Hnq7NnWeYR3z
# 4oFiw9N2n3bb9baQWuWPswG0Dq9YT9kb+Cs4qIIwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIZjDCCGYgCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAsyOtZamvdHJTgAAAAACzDAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgki6lUI2P
# PmoFanok9dvmfNP4L7cxWg85P3BBOG/qbkMwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBUGLqn39YYzHd2GjR0bImHnnS9hJ891IDNAZk5vYl2
# ifBMkLFNRpB2WCoXsS2SVmL6e0hpdzd7VFOZkZzX2NQyo2At1GUwKCuuMgS+TJVg
# o2/8SNn6/Pgsq2URmuHmwGASIO/crLM1cil7hCzpLmJmu4YjoY0pUHDaizRqX5XJ
# GNkWXJhWjYOy9R1ZJVWqGqDH0geVqTD3lIKdpbX285ROYidr1LSYKfBMXgZoaRQt
# KXSWNziwLUz4GxPGeWchoyjjAZ+W+dSzQ+yO2eUhw8uonq3GeGIcBFbIH/vtBncy
# K+rNzAkwnJqj+BnaWfr34+gAA3EJ9y6QEtOMVzD2oUwHoYIXFjCCFxIGCisGAQQB
# gjcDAwExghcCMIIW/gYJKoZIhvcNAQcCoIIW7zCCFusCAQMxDzANBglghkgBZQME
# AgEFADCCAVkGCyqGSIb3DQEJEAEEoIIBSASCAUQwggFAAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIMcnU2/YQRDsWt8n8rUU3VkMGLAzYLBW/IsVHvQr
# 2Y5uAgZi/MfTnZcYEzIwMjIwODI5MTY0MzE0LjAyNFowBIACAfSggdikgdUwgdIx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046MkFENC00QjkyLUZBMDExJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WgghFlMIIHFDCCBPygAwIBAgITMwAAAYZ45RmJ+CRL
# zAABAAABhjANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0yMTEwMjgxOTI3MzlaFw0yMzAxMjYxOTI3MzlaMIHSMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQg
# SXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjJBRDQtNEI5Mi1GQTAxMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAwI3G2Wpv
# 6B4IjAfrgfJpndPOPYO1Yd8+vlfoIxMW3gdCDT+zIbafg14pOu0t0ekUQx60p7Pa
# dH4OjnqNIE1q6ldH9ntj1gIdl4Hq4rdEHTZ6JFdE24DSbVoqqR+R4Iw4w3GPbfc2
# Q3kfyyFyj+DOhmCWw/FZiTVTlT4bdejyAW6r/Jn4fr3xLjbvhITatr36VyyzgQ0Y
# 4Wr73H3gUcLjYu0qiHutDDb6+p+yDBGmKFznOW8wVt7D+u2VEJoE6JlK0EpVLZus
# dSzhecuUwJXxb2uygAZXlsa/fHlwW9YnlBqMHJ+im9HuK5X4x8/5B5dkuIoX5lWG
# jFMbD2A6Lu/PmUB4hK0CF5G1YaUtBrME73DAKkypk7SEm3BlJXwY/GrVoXWYUGEH
# yfrkLkws0RoEMpoIEgebZNKqjRynRJgR4fPCKrEhwEiTTAc4DXGci4HHOm64EQ1g
# /SDHMFqIKVSxoUbkGbdKNKHhmahuIrAy4we9s7rZJskveZYZiDmtAtBt/gQojxbZ
# 1vO9C11SthkrmkkTMLQf9cDzlVEBeu6KmHX2Sze6ggne3I4cy/5IULnHZ3rM4ZpJ
# c0s2KpGLHaVrEQy4x/mAn4yaYfgeH3MEAWkVjy/qTDh6cDCF/gyz3TaQDtvFnAK7
# 0LqtbEvBPdBpeCG/hk9l0laYzwiyyGY/HqMCAwEAAaOCATYwggEyMB0GA1UdDgQW
# BBQZtqNFA+9mdEu/h33UhHMN6whcLjAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJl
# pxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3Rh
# bXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMIMA0GCSqGSIb3DQEBCwUAA4ICAQDD7mehJY3fTHKC4hj+wBWB8544
# uaJiMMIHnhK9ONTM7VraTYzx0U/TcLJ6gxw1tRzM5uu8kswJNlHNp7RedsAiwviV
# QZV9AL8IbZRLJTwNehCwk+BVcY2gh3ZGZmx8uatPZrRueyhhTTD2PvFVLrfwh2li
# DG/dEPNIHTKj79DlEcPIWoOCUp7p0ORMwQ95kVaibpX89pvjhPl2Fm0CBO3pXXJg
# 0bydpQ5dDDTv/qb0+WYF/vNVEU/MoMEQqlUWWuXECTqx6TayJuLJ6uU7K5QyTkQ/
# l24IhGjDzf5AEZOrINYzkWVyNfUOpIxnKsWTBN2ijpZ/Tun5qrmo9vNIDT0lobgn
# ulae17NaEO9oiEJJH1tQ353dhuRi+A00PR781iYlzF5JU1DrEfEyNx8CWgERi90L
# KsYghZBCDjQ3DiJjfUZLqONeHrJfcmhz5/bfm8+aAaUPpZFeP0g0Iond6XNk4YiY
# bWPFoofc0LwcqSALtuIAyz6f3d+UaZZsp41U4hCIoGj6hoDIuU839bo/mZ/AgESw
# GxIXs0gZU6A+2qIUe60QdA969wWSzucKOisng9HCSZLF1dqc3QUawr0C0U41784K
# o9vckAG3akwYuVGcs6hM/SqEhoe9jHwe4Xp81CrTB1l9+EIdukCbP0kyzx0WZzte
# eiDN5rdiiQR9mBJuljCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUw
# DQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhv
# cml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg
# 4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aO
# RmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41
# JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5
# LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL
# 64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9
# QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj
# 0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqE
# UUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0
# kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435
# UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB
# 3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTE
# mr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwG
# A1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNV
# HSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNV
# HQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo
# 0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29m
# dC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5j
# cmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDAN
# BgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4
# sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th54
# 2DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRX
# ud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBew
# VIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0
# DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+Cljd
# QDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFr
# DZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFh
# bHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7n
# tdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+
# oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6Fw
# ZvKhggLUMIICPQIBATCCAQChgdikgdUwgdIxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046MkFENC00Qjky
# LUZBMDExJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoB
# ATAHBgUrDgMCGgMVAAGu2DRzWkKljmXySX1korHL4fMnoIGDMIGApH4wfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEFBQACBQDmtxfrMCIY
# DzIwMjIwODI5MTg0ODExWhgPMjAyMjA4MzAxODQ4MTFaMHQwOgYKKwYBBAGEWQoE
# ATEsMCowCgIFAOa3F+sCAQAwBwIBAAICItwwBwIBAAICEWUwCgIFAOa4aWsCAQAw
# NgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgC
# AQACAwGGoDANBgkqhkiG9w0BAQUFAAOBgQBhEgEQj1MmJuvJXgmK+OLV7BV7PuRx
# sv5bSXkybx5uR/1mp42xiqQI5mod7gLGsdQrGk4xsfnStkZDpXOuuK+j0jf9AE+9
# IKdFcDoyYM2GEoS2eg0vmSSSWX6myrNoc08710EUppPt6VBB5v4GvtR9ENvgXlrm
# +oYO8upAil52nDGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAABhnjlGYn4JEvMAAEAAAGGMA0GCWCGSAFlAwQCAQUAoIIBSjAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIP0en/eW
# 9x70g4PSq+IG3Z6BxEuwyELNwbSUftt4BhJPMIH6BgsqhkiG9w0BCRACLzGB6jCB
# 5zCB5DCBvQQgGpmI4LIsCFTGiYyfRAR7m7Fa2guxVNIw17mcAiq8Qn4wgZgwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAYZ45RmJ+CRLzAAB
# AAABhjAiBCBOO3b0zRvn3DxMozRUZp6v5azKfRgWrzymwNk0rcZ2vzANBgkqhkiG
# 9w0BAQsFAASCAgBv8bIRCD6dDxogTDDJ/DdEGOR6NkguGqRyuObs4V3bZXHeI9VP
# FiEq6pyz7g+Ild0S2yD0wRRuv7NR11SRmU1P8d7RUuNlmmo9EmLctmcgA8MX/1CQ
# nzxxrhNShSLEqHYgpMclnSAP8SwUeTu/NOW8VxeN62cwA8M2I6LInpkouPCmvmr8
# cI+YMXbxZRhofZwAqWxhmn9QtUbAQ2AwNiZsGq6bwr+rrjbKsJxIj3kzHV9CR8W4
# fzaRT651NLZnoQI8LHcIE7uUOuGxG0hMsHrrl95n6pMLNk21bYCBSoQiFuE/1Cgz
# 8/LUm31qgbOaprHc6pAGlzF1p3xyL0zLTN0DoWPWmXTQRqonL2LVTAzLA7YqM2VL
# z8JYZoxcd1o7sa9SG5cRWPhkgqabND8gyUWVxQnWVxlwYDbwhRO1XoK+1UEmBe6d
# mXejqtH1G/srT7zWG3oAtT7r2Qu7AFr0QNlvelFFlRsdXG884h+eRoRdpoUhjyzP
# aTbkgSO7yXAQPs6kn1GKNU6jdwcQmGWOdw+UnrYN23tQYBa3f4CCDfXVu0WyAsaA
# T2dhhR8uE05Q6N5/AqZs2R3loclAXAL2o8TlW9gYhhX6gJ2jGuFgu+qmLcKKWMYP
# vWhnebR+SZT3sn8bG6cRUsBW/iOSWq/XORPVBfOOoH0wYNPuUk0NCSjEhw==
# SIG # End signature block
