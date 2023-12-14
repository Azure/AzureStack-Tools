<#############################################################
 #                                                           #
 # Copyright (C) Microsoft Corporation. All rights reserved. #
 #                                                           #
 #############################################################>

# Script to create AD objects from domain admin context prior to azurestack hci deployment driver execution.
#
# Requirements:
#  - Ensure that the following parameters must be unquie in AD per cluster instance
#     - Azurestack hci lifecycle management user.
#     - Azurestack hci organization unit name.
#     - Azurestack hci deployment prefix (must be at the max 8 characters).
#     - Azurestack hci deployment cluster name.
#  - Physical nodes objects (if already created) must be available under hci ou computers organization unit.
#
# Objects to be created:
#  - Hci Organizational Unit that will be the parent to an organizational unit for each instance and 2 sub organizational units (Computers and Users) with group policy inheritance blocked.
#  - A user account (under users OU) that will have full control to that organizational unit.
#  - Computer objects (if provided under Computers OU else all computer objects must be present under Computer OU)
#  - Security groups (under users OU)
#  - Azurestack Hci cluster object (under computers OU)
#
# This script should be run by a user that has domain admin privileges to the domain.
#
# Parameter Ex:
#  -AsHciOUName "OU=Hci001,OU=HciDeployments,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com" [Hci001 OU will be created under OU=HciDeployments,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com]
#  -DomainFQDN "v.masd.stbtest.microsoft.com"
#  -AsHciClusterName "s-cluster"
#
# Usage Ex:
#
# Hci cluster Deployment
#
# New-HciAdObjectsPreCreation -Deploy -AzureStackLCMUserCredential (get-credential) -AsHciOUName "OU=Hci001,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com" -AsHciPhysicalNodeList @("Physical Machine1", "Physical Machine2") -AsHciDeploymentPrefix "Hci001" -DomainFQDN "v.masd.stbtest.microsoft.com" -AsHciClusterName "s-cluster"
#
#
# Hci cluster Upgrade
# New-HciAdObjectsPreCreation -Upgrade -AzureStackLCMUserCredential (get-credential) -AsHciOUName "OU=Hci001,DC=v,DC=masd,DC=stbtest,DC=microsoft,DC=com" -AsHciPhysicalNodeList @("Physical Machine1", "Physical Machine2") -AsHciDeploymentPrefix "Hci001" -DomainFQDN "v.masd.stbtest.microsoft.com" -AsHciClusterName "s-cluster"
#


$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop


<#
 .Synopsis
  Tests hci organization unit.

 .Parameter AsHciOUPath
  The hci ou path.
#>

function Test-AsHciOU
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AsHciOUPath
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    try
    {
        if (-not [adsi]::Exists("LDAP://$AsHciOUPath"))
        {
            Write-Error "'$AsHciOUPath' does not exist. Exception ::  $_"
        }
        Write-Verbose "Successfully verified $AsHciOUPath"
    }
    catch
    {
        Write-Error "Unable to verify organization unit '$AsHciOUPath'. Exception ::  $_"
    }
}

<#
 .Synopsis
  Verifies deployment prefix uniqueness.

 .Parameter AsHciOUPath
  The hci ou path.

 .Parameter AsHciDeploymentPrefix
  The hci deployment prefix.

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

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::continue
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
        $Rerun =$false
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    $ouPath = Get-ADOrganizationalUnit -SearchBase $DomainOUPath -Filter { Name -eq $OUName } | Select-Object DistinguishedName
    if ($ouPath)
    {
        Write-Error "Hci organizational unit '$OUName' exists under '$DomainOUPath', to continue with '$OUName' OU please remove it and execute the tool."
    }

    try
    {
        New-ADOrganizationalUnit -Name $OUName -Path $DomainOUPath
        Write-Verbose "Successfully created $OUName organization unit under '$DomainOUPath' "
    }
    catch
    {
        Write-Error "Failed to create organization unit. Exception :: $_"
    }
}


<#
 .Synopsis
  Remove hci organization unit.

 .Parameter AsHciOUPath
  The hci ou path.
#>

function Remove-AsHciOU
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AsHciOUPath
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    try
    {
        if ([adsi]::Exists("LDAP://$AsHciOUPath"))
        {
            Get-ADOrganizationalUnit -Identity $AsHciOUPath |
                Set-ADObject -ProtectedFromAccidentalDeletion:$false -PassThru |
                Remove-ADOrganizationalUnit -Recursive -Confirm:$false
            Write-Verbose "Successfully deleted $AsHciOUPath"
        }
        else
        {
            Write-Verbose "OU $AsHciOUPath not found, skipping the remove operation."
        }
    }
    catch
    {
        Write-Error "Unable to delete '$AsHciOUPath'. Exception ::  $_"
    }
}

<#
 .Synopsis
  Creates new secruity groups and gMSA accounts if required during update process.

 .Parameter AsHciLCMUserName
  The azure stack hci lifecycle management user names

 .Parameter DeploymentPrefix
  The hci deployment prefix.

 .Parameter AsHciOUName
  The hci ou name.

 .Parameter DomainFQDN
  The active directory domain fqdn
#>

function Update-SecurityGroupsandGMSAAccounts
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $AsHciLCMUserName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $AsHciDeploymentPrefix,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AsHciOUName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DomainFQDN
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    # OU names
    $hciParentOUPath = $AsHciOUName.Split(",",2)[1]
    $hciOUName = ($AsHciOUName.Split(",",2)[0]).split("=")[1]
    $computersOU = "Computers"
    $usersOU = "Users"

    # Create Hci organization units
    $asHciOUPath = Get-ADOrganizationalUnit -SearchBase $hciParentOUPath -Filter { Name -eq $hciOUName }
    $asHciComputersOUPath = Get-ADOrganizationalUnit -SearchBase $asHciOUPath.DistinguishedName -Filter { Name -eq $computersOU }
    $asHciUsersOUPath = Get-ADOrganizationalUnit -SearchBase $asHciOUPath.DistinguishedName -Filter { Name -eq $usersOU }

    # Create security groups
    New-AsHciSecurityGroup -AsHciUsersOuPath $asHciUsersOUPath -AsHciComputersOuPath $asHciComputersOUPath -DeploymentPrefix $AsHciDeploymentPrefix -AsHciLCMUserName $AsHciLCMUserName -Verbose

    # Create gMSA accounts
    New-AsHciGmsaAccount -DomainFQDN $DomainFQDN -DeploymentPrefix $AsHciDeploymentPrefix -AsHciUsersOuPath $AsHciUsersOuPath -Verbose
}


<#
 .Synopsis
  Creates hci lifecycle management users under hci users organization unit path.

 .Parameter AsHciLCMUserName
  The azure stack hci lifecycle management user names

 .Parameter DomainFQDN
  The active directory domain fqdn

 .Parameter AsHciLCMUserPassword
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
        $AsHciLCMUserName,

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
        $Rerun = $false
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    try
    {
        $user = Get-ADUser -SearchBase $AsHciUsersOUPath -Filter { Name -eq $AsHciLCMUserName }
        if ($user -and (-not $Rerun))
        {
            Write-Error "$AsHciLCMUserName exists, please provide an unique username."
        }
        if ($user)
        {
            Write-verbose "$AsHciLCMUserName exists under $AsHciUsersOUPath, skipping."
        }
        else
        {
            New-ADUser -Name $AsHciLCMUserName -AccountPassword $AsHciUserPassword -UserPrincipalName "$AsHciLCMUserName@$DomainFQDN" -Enabled $true -PasswordNeverExpires $true -path $AsHciUsersOUPath.DistinguishedName
            Write-Verbose "Successfully created '$AsHciLCMUserName' under '$AsHciUsersOUPath'"
        }
    }
    catch
    {
        if ($_ -match 'The operation failed because UPN value provided for addition/modification is not unique forest-wide')
        {
            Write-Error "UserPrincipalName '$AsHciLCMUserName@$DomainFQDN' already exists, please provide a different user name"
        }
        elseif ($_ -match 'The specified account already exists')
        {
            Write-Error "$AsHciLCMUserName already exists, please provide a different user name"
        }
        else
        {
            Write-Error "Unable to create $AsHciLCMUserName. Exception :: $_ "
        }
    }
}

<#
 .Synopsis
  Grants full access permissions of hci organization unit to hci lifecycle management user.

 .Parameter AsHciLCMUserName
  The hci lifecycle management user name.

 .Parameter AsHciOUPath
  The hci organization unit path.
#>
function Grant-HciOuPermissionsToHciLCMUser
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $AsHciLCMUserName,

        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciOUPath

    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    try
    {
        $ouPath = "AD:\$($AsHciOUPath.DistinguishedName)"

        $userSecurityIdentifier = Get-ADuser -Identity $AsHciLCMUserName
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
        Write-Verbose "Successfully granted access permissions '$($AsHciOUPath.DistinguishedName)' to '$AsHciLCMUserName'"
    }
    catch
    {
        Write-Error "Failed to grant access permissions '$($AsHciOUPath.DistinguishedName)' to '$AsHciLCMUserName'. Error :: $_"
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

 .Example
  $ou = Get-ADOrganizationalUnit -Filter 'Name -eq "testou"'
  New-ADPrestagedCluster -OrganizationalUnit $ou -ClusterName 's-cluster'
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
          $ClusterName
    )

    $ErrorActionPreference = "Stop"

    Write-Verbose "Checking computer '$ClusterName' under OU '$($OrganizationalUnit.DistinguishedName)' ..." -Verbose

    $cno = Get-ADComputer -Filter "Name -eq '$ClusterName'" -SearchBase $OrganizationalUnit

    if ($cno)
    {
        Write-Verbose "Found existing computer with name '$ClusterName', skip creation."
    }
    else
    {
        Write-Verbose "Creating computer '$ClusterName' under OU '$($OrganizationalUnit.DistinguishedName)' ..." -Verbose
        $cno = New-ADComputer -Name $ClusterName -Description 'Cluster Name Object of HCI deployment' -Path $OrganizationalUnit.DistinguishedName -Enabled $false -PassThru -Verbose
    }

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

 .Parameter AsHciUsersOuPath
  The hci users organization unit object.

 .Parameter AsHciComputersOuPath
  The hci computers organization unit object.

 .Parameter DeploymentPrefix
  The hci deployment prefix.

 .Parameter PhysicalMachines
  The hci cluster physical machines.

 .Parameter AsHciLCMUserName
  The hci lifecycle management username.
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
        $AsHciLCMUserName
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    Write-Verbose "Creating security groups under '$($AsHciUsersOuPath.DistinguishedName)'"
    # List of security groups required for hci deployment.
    $securityGroups = @("$($DeploymentPrefix)-Sto-SG",
                     "$($DeploymentPrefix)-OpsAdmin"
                     )


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
                Write-Verbose "$securityGroup successfully created."
            }
        }
        catch
        {
            Write-Error "$SecurityGroup creation failed. Error :: $_ "
        }
    }

    Write-Verbose "Successfully created security groups under '$($AsHciUsersOuPath.DistinguishedName)'"

    $physicalMachineSecurityGroups = @("$($DeploymentPrefix)-Sto-SG")
    #Add physical machines to the security groups.
    foreach ($physicalMachine in $PhysicalMachines)
    {
        $machineObject = Get-ADComputer -SearchBase $($AsHciComputersOuPath.DistinguishedName) -Filter {Name -eq $physicalMachine}
        Add-Membership -IdentityObject $machineObject -SecurityGroupNames $physicalMachineSecurityGroups -AsHciUsersOUPath $($AsHciUsersOuPath.DistinguishedName)
    }

    #Add user membership.
    $AsHciUserSecurityGroups = @("$($AsHciDeploymentPrefix)-OpsAdmin")
    $userIdentity = Get-ADUser -SearchBase $AsHciUsersOuPath.DistinguishedName -Filter { Name -eq $AsHciLCMUserName }
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
        [String]
        $DeploymentPrefix,

        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciUsersOuPath

    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    return

    # List of gMSA accounts, it's membership, principals allowed to retrieve the password and service principal names if any.
    $gmsaAccounts =
    @([pscustomobject]@{ GmsaName="$($DeploymentPrefix)-BM-ECE";
                         PrincipalsAllowedToRetrieveManagedPassword= @("$($DeploymentPrefix)-Sto-SG");
                         ServicePrincipalName=@("$($DeploymentPrefix)/ae3299a9-3e87-4186-bd99-c43c9ae6a571");
                         MemberOf=@("$($DeploymentPrefix)-EceSG", "$($DeploymentPrefix)-BM-ECESG", "$($DeploymentPrefix)-FsAcl-InfraSG")},

    [pscustomobject]@{ GmsaName="$($DeploymentPrefix)-EceSA";
                         PrincipalsAllowedToRetrieveManagedPassword= @("$($DeploymentPrefix)-Sto-SG");
                         ServicePrincipalName=@("$($DeploymentPrefix)/4dde37cc-6ee0-4d75-9444-7061e156507f");
                         MemberOf=@("$($DeploymentPrefix)-FsAcl-InfraSG", "$($DeploymentPrefix)-EceSG", "$($DeploymentPrefix)-BM-EceSG")})

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

<#
 .Synopsis
  Verfies the below obejcts are unique or not.
    Lifecycle management user
    Organizational unit
    Phyiscal machines
    Deployment prefix
    Cluster name

 .Parameter AzureStackLCMUserCredential
  Lifecycle management credentails.

 .Parameter AsHciOUName
  Organizational unit.

 .Parameter AsHciPhysicalNodeList
  Physical machines list.

 .Parameter AsHciDeploymentPrefix
  Deployment prefix.

 .Parameter AsHciClusterName
  Cluster name.

#>

function Test-UniqueAdObjects
{
    Param(
        [PSCredential] $AzureStackLCMUserCredential,

        [string] $AsHciOUName,

        [string[]] $AsHciPhysicalNodeList,

        [string] $AsHciDeploymentPrefix,

        [string] $AsHciClusterName
    )

    $Errors = New-Object System.Collections.Generic.List[System.Object]

    $asHciLCMUserName = $AzureStackLCMUserCredential.UserName

    if ( Get-ADUser -Filter { Name -eq $asHciLCMUserName })
    {
        $Errors.Add(" UserName :: '$asHciLCMUserName'")
    }

    if (-not ([string]::IsNullOrWhitespace($AsHciClusterName)))
    {
        if (Get-ADComputer -Filter "Name -eq '$AsHciClusterName'")
        {
            $Errors.Add(" Cluster Name :: '$AsHciClusterName'")
        }
    }

    foreach ($node in $AsHciPhysicalNodeList)
    {
        if (Get-ADComputer -Filter "Name -eq '$node'")
        {
            $Errors.Add(" Physical Node :: '$node'")
        }
    }

    $opsAdminGroup = "$AsHciDeploymentPrefix-OpsAdmin"
    if (Get-AdGroup -Filter { Name -eq $opsAdminGroup} )
    {
        $Errors.Add(" Deployment prefix :: '$AsHciDeploymentPrefix'")
    }


    if ($Errors.Count -ge 1)
    {
        Write-Warning "Below object/objects are already available on AD please provide unique values and run the tool."
        foreach ($error in $Errors)
        {
            Write-Warning "$error"
        }
        Write-Error "AD precreation object failed"
    }
}

<#
 .Synopsis
  Creates required active directory objects for deployment / upgrade driver execution.

 .Parameter Deploy
  Deployment.

 .Parameter Upgrade
  Upgrade.

 .Parameter AzureStackLCMUserCredential
  Lifecycle management credentails.

 .Parameter AsHciOUName
  Organizational unit.

 .Parameter AsHciPhysicalNodeList
  Physical machines list.

 .Parameter AsHciDeploymentPrefix
  Deployment prefix.

 .Parameter AsHciClusterName
  Cluster name.

 .Parameter DomainFQDN
  Domain FQDN.

 .Parameter DNSServerIP
  DNS server ipaddress,
#>

function New-AdObjectsForDeployOrUpgrade
{
    Param(
        [Switch] $Deploy,

        [Switch] $Upgrade,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $AzureStackLCMUserCredential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AsHciOUName,

        [Parameter(Mandatory = $true)]
        [ValidateLength(1,8)]
        [string] $AsHciDeploymentPrefix,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DomainFQDN,

        [string[]] $AsHciPhysicalNodeList,

        [Parameter(Mandatory = $true)]
        [ValidateLength(1,15)]
        [string] $AsHciClusterName,

        [string] $DNSServerIP

    )

    # OU names
    $hciOUName = ($AsHciOUName.Split(",",2)[0]).split("=")[1]
    $computersOU = "Computers"
    $usersOU = "Users"

    # Create Hci organization units
    New-AsHciOrganizationalUnit -DomainOUPath $hciParentOUPath -OUName $hciOUName -Verbose
    $asHciOUPath = Get-ADOrganizationalUnit -SearchBase $hciParentOUPath -Filter { Name -eq $hciOUName }

    # Create computers OU under $asHciOUPath
    New-AsHciOrganizationalUnit -DomainOUPath $($asHciOUPath.DistinguishedName) -OUName $computersOU -Verbose
    $asHciComputersOUPath = Get-ADOrganizationalUnit -SearchBase $asHciOUPath.DistinguishedName -Filter { Name -eq $computersOU }

    # Create users OU under $asHciOUPath
    New-AsHciOrganizationalUnit -DomainOUPath $($asHciOUPath.DistinguishedName) -OUName $usersOU -Verbose
    $asHciUsersOUPath = Get-ADOrganizationalUnit -SearchBase $asHciOUPath.DistinguishedName -Filter { Name -eq $usersOU }

    # Create Hci lifecycle management user under Hci users OU path
    $asHciLCMUserName = $AzureStackLCMUserCredential.UserName
    $asHciLCMUserPassword = $AzureStackLCMUserCredential.Password
    New-AsHciUser -AsHciLCMUserName $asHciLCMUserName -AsHciUserPassword $asHciLCMUserPassword -DomainFQDN $DomainFQDN -AsHciUsersOUPath $asHciUsersOUPath  -Verbose

    # Grant permissions to hci lifecycle management user
    Grant-HciOuPermissionsToHciLCMUser -AsHciLCMUserName $asHciLCMUserName -AsHciOUPath $asHciOUPath -Verbose

    if ($Deploy)
    {
        # Pre-create computer objects
        New-MachineObject -Machines $AsHciPhysicalNodeList -DomainFQDN $DomainFQDN -AsHciComputerOuPath $asHciComputersOUPath -Verbose
    }
    elseif ($Upgrade)
    {
        # Move cluster and physical machine objects to Hci OU
        Move-AsHciAdObjetToHciOU -AsHciPhysicalNodeList $AsHciPhysicalNodeList -AsHciClusterName $AsHciClusterName -AsHciComputerOuPath $asHciComputersOUPath -Verbose
    }

    # Pre-stage cluster objects
    New-PrestagedAsHciCluster -OrganizationalUnit $asHciComputersOUPath -ClusterName $AsHciClusterName -Verbose

    # Create security groups
    New-AsHciSecurityGroup -AsHciUsersOuPath $asHciUsersOUPath -AsHciComputersOuPath $asHciComputersOUPath -PhysicalMachines $AsHciPhysicalNodeList -DeploymentPrefix $AsHciDeploymentPrefix -AsHciLCMUserName $AsHciLCMUserName -Verbose

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

}

<#
 .Synopsis
  Move existing AD objects to Hci organizational units.
  E.g., Move the cluster name object, the host computer objects to the Hci Computers OU.

 .Parameter AsHciPhysicalNodeList
  Physical machines list.

 .Parameter AsHciClusterName
  Cluster name.

 .Parameter AsHciComputerOuPath
  The Hci Computers OrganizationalUnit where the AD computer objects should be moved to.

#>

function Move-AsHciAdObjetToHciOU
{
    Param(
        [Parameter(Mandatory = $true)]
        [string[]] $AsHciPhysicalNodeList,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AsHciClusterName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
        $AsHciComputerOuPath
    )

    $AsHciPhysicalNodeList + $AsHciClusterName | ForEach-Object {
        $computerObjName = $_

        # Check existence
        $adComputer = Get-ADComputer -Filter { Name -eq $computerObjName } -Property ProtectedFromAccidentalDeletion
        if (-not $adComputer) {
            Write-Error "Computer object '$computerObjName' not found in AD."
        }

        # Check whether it is in target OU
        if (-not (Get-ADComputer -Filter { Name -eq $computerObjName } -SearchBase $AsHciComputerOuPath))
        {
            # Unprotect the ad object before moving, otherwise access will be denied
            $isProtected = $adComputer.ProtectedFromAccidentalDeletion
            if ($isProtected)
            {
                Write-Verbose "Unprotect computer object '$computerObjName' before moving"
                $adComputer | Set-ADObject -ProtectedFromAccidentalDeletion:$false
            }

            Write-Verbose "Moving computer object '$computerObjName' to OU '$($AsHciComputerOuPath.DistinguishedName)'"
            $adComputer = $adComputer | Move-ADObject -TargetPath $AsHciComputerOuPath -PassThru

            # Reprotect after moving
            if ($isProtected)
            {
                Write-Verbose "Reprotect computer object '$computerObjName' after moving"
                $adComputer | Set-ADObject -ProtectedFromAccidentalDeletion:$true
            }
        }
        else
        {
            Write-Verbose "Computer object '$computerObjName' is already in OU '$($AsHciComputerOuPath.DistinguishedName)'"
        }
    }
}

<#
 .Synopsis
  Cmdlet to Create required active directory objects.

 .Parameter Deploy
  Deployment.

 .Parameter Upgrade
  Upgrade.

 .Parameter AzureStackLCMUserCredential
  Lifecycle management credentials.

 .Parameter AsHciOUName
  Organizational unit.

 .Parameter AsHciPhysicalNodeList
  Physical machines list.

 .Parameter AsHciDeploymentPrefix
  Deployment prefix.

 .Parameter AsHciClusterName
  Cluster name.

 .Parameter DomainFQDN
  Domain FQDN.

 .Parameter DNSServerIP
  DNS server ipaddress,
#>

function New-HciAdObjectsPreCreation
{
    [CmdletBinding(
        DefaultParameterSetName= 'Deploy'
    )]
    Param(
        [Parameter(ParameterSetName = 'Deploy', Mandatory=$true)]
        [Switch]
        $Deploy,

        [Parameter(ParameterSetName = 'Upgrade', Mandatory=$true)]
        [Switch]
        $Upgrade,

        [Parameter(ParameterSetName = 'Deploy', Mandatory=$true)]
        [Parameter(ParameterSetName = 'Upgrade', Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $AzureStackLCMUserCredential,

        [Parameter(ParameterSetName = 'Deploy', Mandatory=$true)]
        [Parameter(ParameterSetName = 'Upgrade', Mandatory=$true)]
        [validatePattern('^(OU=[^,]+,)+(DC=[^,]+,)*DC=[^,]+$')]
        [ValidateNotNullOrEmpty()]
        [string] $AsHciOUName,

        [Parameter(ParameterSetName = 'Deploy', Mandatory=$true)]
        [Parameter(ParameterSetName = 'Upgrade', Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1,15)]
        [validatePattern("^[0-9a-z]([0-9a-z\-]{0,61}[0-9a-z])")]
        [string[]] $AsHciPhysicalNodeList,

        [Parameter(ParameterSetName = 'Deploy', Mandatory=$true)]
        [Parameter(ParameterSetName = 'Upgrade', Mandatory=$true)]
        [ValidateLength(1,8)]
        [validatePattern('^([a-zA-Z])(\-?[a-zA-Z\d])*$')]
        [string] $AsHciDeploymentPrefix,

        [Parameter(ParameterSetName = 'Deploy', Mandatory=$true)]
        [Parameter(ParameterSetName = 'Upgrade', Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $DomainFQDN,

        [Parameter(ParameterSetName = 'Deploy', Mandatory=$true)]
        [Parameter(ParameterSetName = 'Upgrade', Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [validatePattern('^((?!-)[A-Za-z0-9-]+(?<!-))$')]
        [string] $AsHciClusterName,

        [Parameter(ParameterSetName = 'Deploy', Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $DNSServerIP

    )

    # import required modules
    $modules = @('ActiveDirectory','GroupPolicy','Kds')
    foreach ($module in $modules)
    {
        Import-Module -Name $module -Verbose:$false -ErrorAction Stop | Out-Null
    }

    $hciParentOUPath = $AsHciOUName.Split(",",2)[1]
    # Test hci parent ou path exists or not."
    Test-AsHciOU -AsHciOUPath $hciParentOUPath -Verbose

    Test-AsHciDeploymentPrefix -AsHciOUPath $AsHciOUName -AsHciDeploymentPrefix $AsHciDeploymentPrefix -Verbose

    # Create AD objects for a fresh HCI deployment.
    if ($Deploy)
    {
        Test-UniqueAdObjects -AzureStackLCMUserCredential $AzureStackLCMUserCredential `
                             -AsHciOUName $AsHciOUName `
                             -AsHciPhysicalNodeList $AsHciPhysicalNodeList `
                             -AsHciClusterName $AsHciClusterName `
                             -AsHciDeploymentPrefix $AsHciDeploymentPrefix

        New-AdObjectsForDeployOrUpgrade -Deploy `
                                        -AzureStackLCMUserCredential $AzureStackLCMUserCredential `
                                        -AsHciOUName $AsHciOUName `
                                        -AsHciDeploymentPrefix $AsHciDeploymentPrefix `
                                        -DomainFQDN $DomainFQDN `
                                        -AsHciPhysicalNodeList $AsHciPhysicalNodeList `
                                        -AsHciClusterName $AsHciClusterName `
                                        -DNSServerIP $DNSServerIP
    }
    elseif ($Upgrade)
    {
        Test-UniqueAdObjects -AzureStackLCMUserCredential $AzureStackLCMUserCredential `
                             -AsHciOUName $AsHciOUName `
                             -AsHciDeploymentPrefix $AsHciDeploymentPrefix

        New-AdObjectsForDeployOrUpgrade -Upgrade `
                                        -AzureStackLCMUserCredential $AzureStackLCMUserCredential `
                                        -AsHciOUName $AsHciOUName `
                                        -AsHciDeploymentPrefix $AsHciDeploymentPrefix `
                                        -DomainFQDN $DomainFQDN `
                                        -AsHciPhysicalNodeList $AsHciPhysicalNodeList `
                                        -AsHciClusterName $AsHciClusterName `
                                        -DNSServerIP $DNSServerIP
    }
    else
    {
        Write-Error "Invalid operation"
    }
}

Export-ModuleMember -Function New-HciAdObjectsPreCreation
Export-ModuleMember -Function Remove-AsHciOU
Export-ModuleMember -Function Update-SecurityGroupsandGMSAAccounts
# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBAstvRzYxcAMBu
# e0H4rU1KFaundrhH3Ho9ar3Jz2P71KCCDXYwggX0MIID3KADAgECAhMzAAADTrU8
# esGEb+srAAAAAANOMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMwMzE2MTg0MzI5WhcNMjQwMzE0MTg0MzI5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDdCKiNI6IBFWuvJUmf6WdOJqZmIwYs5G7AJD5UbcL6tsC+EBPDbr36pFGo1bsU
# p53nRyFYnncoMg8FK0d8jLlw0lgexDDr7gicf2zOBFWqfv/nSLwzJFNP5W03DF/1
# 1oZ12rSFqGlm+O46cRjTDFBpMRCZZGddZlRBjivby0eI1VgTD1TvAdfBYQe82fhm
# WQkYR/lWmAK+vW/1+bO7jHaxXTNCxLIBW07F8PBjUcwFxxyfbe2mHB4h1L4U0Ofa
# +HX/aREQ7SqYZz59sXM2ySOfvYyIjnqSO80NGBaz5DvzIG88J0+BNhOu2jl6Dfcq
# jYQs1H/PMSQIK6E7lXDXSpXzAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUnMc7Zn/ukKBsBiWkwdNfsN5pdwAw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMDUxNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAD21v9pHoLdBSNlFAjmk
# mx4XxOZAPsVxxXbDyQv1+kGDe9XpgBnT1lXnx7JDpFMKBwAyIwdInmvhK9pGBa31
# TyeL3p7R2s0L8SABPPRJHAEk4NHpBXxHjm4TKjezAbSqqbgsy10Y7KApy+9UrKa2
# kGmsuASsk95PVm5vem7OmTs42vm0BJUU+JPQLg8Y/sdj3TtSfLYYZAaJwTAIgi7d
# hzn5hatLo7Dhz+4T+MrFd+6LUa2U3zr97QwzDthx+RP9/RZnur4inzSQsG5DCVIM
# pA1l2NWEA3KAca0tI2l6hQNYsaKL1kefdfHCrPxEry8onJjyGGv9YKoLv6AOO7Oh
# JEmbQlz/xksYG2N/JSOJ+QqYpGTEuYFYVWain7He6jgb41JbpOGKDdE/b+V2q/gX
# UgFe2gdwTpCDsvh8SMRoq1/BNXcr7iTAU38Vgr83iVtPYmFhZOVM0ULp/kKTVoir
# IpP2KCxT4OekOctt8grYnhJ16QMjmMv5o53hjNFXOxigkQWYzUO+6w50g0FAeFa8
# 5ugCCB6lXEk21FFB1FdIHpjSQf+LP/W2OV/HfhC3uTPgKbRtXo83TZYEudooyZ/A
# Vu08sibZ3MkGOJORLERNwKm2G7oqdOv4Qj8Z0JrGgMzj46NFKAxkLSpE5oHQYP1H
# tPx1lPfD7iNSbJsP6LiUHXH1MIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAANOtTx6wYRv6ysAAAAAA04wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJ7qZeFeIYAUp9W0DlmUOk2U
# DH6xxkdzumIvi8ngT3XwMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAi2hj3fg4Xp3l/4anHObIMt3OarzYc7jwF5HhyOEsor2DX2vQnqRWTlsh
# z9LL+fcInKMfPWbhpggN7L8aUWF0/EBzyma2JjsF6tvieCCKHuFFdp+YnSV8FHyO
# EgkZXtV58FTXMKDg4FXFp3CwgyHTuF5nqf4h8VQ3RdNkovx/ltCsKhVsolUhayFR
# 6zs8BpJvQRozFXoGCku5qQcnht73axOy475eh5o6K3y3ZMoCyqyzZEAXu1jDpsgz
# Xwh2Qv0vJ1gEj6KY5Yx6o3/rWlGW7RkNow9PH/bzue9jFHh0E3+6TRIj4Xq8tiQd
# RvjSNRhH2eafrT+a6LBx42aNujoB5qGCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBErtBQYLTHLyGkxu91Qa9lSuDQvyn/TpGWEIF7jDOCFQIGZVbKF6yW
# GBMyMDIzMTIwNDE5MjIzNy44OTlaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODkwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAdMdMpoXO0AwcwABAAAB0zANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzA1MjUxOTEy
# MjRaFw0yNDAyMDExOTEyMjRaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODkwMC0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQC0jquTN4g1xbhXCc8MV+dOu8Uqc3KbbaWti5vdsAWM
# 1D4fVSi+4NWgGtP/BVRYrVj2oVnnMy0eazidQOJ4uUscBMbPHaMxaNpgbRG9FEQR
# FncAUptWnI+VPl53PD6MPL0yz8cHC2ZD3weF4w+uMDAGnL36Bkm0srONXvnM9eNv
# nG5djopEqiHodWSauRye4uftBR2sTwGHVmxKu0GS4fO87NgbJ4VGzICRyZXw9+Rv
# vXMG/jhM11H8AWKzKpn0oMGm1MSMeNvLUWb31HSZekx/NBEtXvmdo75OV030NHgI
# XihxYEeSgUIxfbI5OmgMq/VDCQp2r/fy/5NVa3KjCQoNqmmEM6orAJ2XKjYhEJzo
# p4nWCcJ970U6rXpBPK4XGNKBFhhLa74TM/ysTFIrEXOJG1fUuXfcdWb0Ex0FAeTT
# r6gmmCqreJNejNHffG/VEeF7LNvUquYFRndiCUhgy624rW6ptcnQTiRfE0QL/gLF
# 41kA2vZMYzcc16EiYXQQBaF3XAtMduh1dpXqTPPQEO3Ms5/5B/KtjhSspMcPUvRv
# b35IWN+q+L+zEwiphmnCGFTuyOMqc5QE0ruGN3Mx0Vv6x/hcOmaXxrHQGpNKI5Pn
# 79Yk89AclqU2mXHz1ZHWp+KBc3D6VP7L32JlwxhJx3asa085xv0XPD58MRW1WaGv
# aQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFNLHIIa4FAD494z35hvzCmm0415iMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQBAYlhYoUQ+4aaQ54MFNfE6Ey8v4rWv+LtD
# RSjMM2X9g4uanA9cU7VitdpIPV/zE6v4AEhe/Vng2UAR5qj2SV3sz+fDqN6VLWUZ
# sKR0QR2JYXKnFPRVj16ezZyP7zd5H8IsvscEconeX+aRHF0xGGM4tDLrS84vj6Rm
# 0bgoWLXWnMTZ5kP4ownGmm0LsmInuu0GKrDZnkeTVmfk8gTTy8d1y3P2IYc2UI4i
# JYXCuSaKCuFeO0wqyscpvhGQSno1XAFK3oaybuD1mSoQxT9q77+LAGGQbiSoGlgT
# jQQayYsQaPcG1Q4QNwONGqkASCZTbzJlnmkHgkWlKSLTulOailWIY4hS1EZ+w+sX
# 0BJ9LcM142h51OlXLMoPLpzHAb6x22ipaAJ5Kf3uyFaOKWw4hnu0zWs+PKPd192n
# deK2ogWfaFdfnEvkWDDH2doL+ZA5QBd8Xngs/md3Brnll2BkZ/giZE/fKyolriR3
# aTAWCxFCXKIl/Clu2bbnj9qfVYLpAVQEcPaCfTAf7OZBlXmluETvq1Y/SNhxC6MJ
# 1QLCnkXSI//iXYpmRKT783QKRgmo/4ztj3uL9Z7xbbGxISg+P0HTRX15y4TReBbO
# 2RFNyCj88gOORk+swT1kaKXUfGB4zjg5XulxSby3uLNxQebE6TE3cAK0+fnY5UpH
# aEdlw4e7ijCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25Phdg
# M/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPF
# dvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6
# GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBp
# Dco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50Zu
# yjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3E
# XzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0
# lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1q
# GFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ
# +QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PA
# PBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkw
# EgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxG
# NSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARV
# MFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0x
# M7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmC
# VgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449
# xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wM
# nosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDS
# PeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2d
# Y3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxn
# GSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+Crvs
# QWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokL
# jzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNN
# MIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjg5MDAtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBS
# x23cMcNB1IQws/LYkRXa7I5JsKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6RhaQjAiGA8yMDIzMTIwNDE0MDEz
# OFoYDzIwMjMxMjA1MTQwMTM4WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDpGFpC
# AgEAMAcCAQACAhDcMAcCAQACAhNuMAoCBQDpGavCAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBACJFbf3RxhZOAf1DPCmUI5IcoDLu3ciNHJP9VJF4RdzVzAhV
# 8/pTedvLZvnRtt1OZLymBYmG0kuzfvfJhDJwVJs3kJ+F1Zl3ShvPG30AczyMdEUw
# UwcB0/jEFfokkpPBO30agq1F2Aem/4Oe4ES3NvvmyRzOH1Mw5rrpoQO89+T/GKWk
# SCINjnc28qugoYRTPG1nI3ir6jHTpd+2C4yn6IEBqSFMDqIsdKw532PEfyqzc3S2
# VVoBRrKB8xlZVw+GssoMFFX6AymAvPDkW6M/aTWDTWewBstSvSpTWYl/nHm0Ad0V
# cRKPFKmiq2Nwreh77nAUqVA+YLVaC/YArlNqYvIxggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAdMdMpoXO0AwcwABAAAB0zAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCAIvwBJScGQYUm00vFslw4buUc3jbzn+u2Cxnjyl3BktDCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIJJm9OrE4O5PWA1KaFaztr9uP96r
# QgEn+tgGtY3xOqr1MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAHTHTKaFztAMHMAAQAAAdMwIgQgi0a7i0P0ZZFQZFdDqaIQZEw0IjMT
# 0YFU3Uu1cK3JoRMwDQYJKoZIhvcNAQELBQAEggIAqPVpToPJnjiLtf6CGm/zUoR1
# 3tSkd8aupIT7prbFxTIrf2IWrBzpQ9ADPqO2qu0Bu2yBlMn1wC4t6SOlffQlG90B
# 0RK28/NB3hOHLymGXT4KYsX5MBEU2tiBgq1tASNwk1k5nzXDOsG9NIx4oRzTDlEn
# L1l/znraesnlzZ/NmwdIHHojkUTQ8mqFu5NC1AhzbZ0fl3T8YlH1AMIz7wuxSFxX
# N1l14nPGC2GFjP02aq3mdX/Z/+TbZr7IWx4JxhLgzaU/jdgfhRq7ix5LyLlGpgwG
# QpS6yMqNcy+kgAObfyG4ucAT1Wma3SWlscRBG4eNf2aqyCtAxvhSCyhqo+HMBFA/
# EKeGLQU/E5MM8QyIvecxHnT4kz1U3/uGYtCFry2u0zDSSd+n8jlJsQZPJU5dLCw5
# muwudbDO0QeFQeCVnBNuW1gA0b/H+nZj0DFe5WlFnDrIxb8d6glQijVS+mWgiuiF
# 01qPf9hkvhl1ZLW0GCj42rm0RnaAyqYBjIc4dkKx/zygg2Jo8oW3db3vCcW4Qfip
# igKWtPosGR7Kgf/iFOB2foMCHnIH+ga2NDqu2ND8xJoI2mFtR8+DCD+wy4eRqoGm
# jDaojgQBmqZ5IRx1/JhW1gRewrR2Jhj3HFGNGtFAlyvuu8SrkBMHrKd+tXZRHPmt
# I8DBB5whwIbcFevMmMo=
# SIG # End signature block
