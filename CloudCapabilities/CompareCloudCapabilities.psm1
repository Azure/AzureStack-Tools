# Copyright (c) Microsoft Corporation. All rights reserved.

# See LICENSE.txt in the project root for license information.

<#

    .SYNOPSIS
	
    Compare the capabilities of two clouds to determine resources and API versions that are commonly available in both. 
    Can be used to compare the availability of resource types in Azure and Azure Stack.

#>

function Compare-CloudCapabilities()
{
	[CmdletBinding()]
    Param(
		[Parameter(Mandatory=$true, HelpMessage = 'Cloud A Capabilties File Path. This cloud will be the comparison superset.')]
        [String] $aPath,

		[Parameter(Mandatory=$true, HelpMessage= 'Cloud B Capabilties File Path. ')]
		[String] $bPath,

		[Parameter(HelpMessage = 'Restrict the comparision to only provider namespaces available in Cloud B')]
		[Switch] $restrictNamespaces,

        [Parameter(HelpMessage = 'Restrict the comparison to top level resources and do not examine nested resources')]
		[Switch] $excludeNestedResources
    )

    $cloudACapabilities = ConvertFrom-Json (Get-Content -Path $aPath -Raw) -ErrorAction Stop
    $cloudBCapabilities = ConvertFrom-Json (Get-Content -Path $bPath -Raw) -ErrorAction Stop

    Write-Verbose "Loaded cloud A and B capabilities."
    Write-Verbose "Now comparing..."

    $commonResources = @()
    $AonlyResources = @()


    if($restrictNamespaces){
        $namespaces = @()
        foreach ($bResource in $cloudBCapabilities.resources) {
            $namespaces += $bResource.providerNameSpace
        }
    }

    # Look for common resources and resources only available in cloud A
    foreach ($aResource in $cloudACapabilities.resources) {
        $validResourceToMatch = $false
        if($namespaces){
            #Check for whether this is in a valid Provider Namespace
            if($aResource.providerNameSpace -iin $namespaces){
                #Check to see if this is a nested resource and whether it should be accounted for
                if($excludeNestedResources -and ($aResource.ResourcetypeName -like "*/*")){
                    $validResourceToMatch = $false
                }else{
                    $validResourceToMatch = $true
                }

            }
        }else{
            #Check to see if this is a nested resource and whether it should be accounted for
            if($excludeNestedResources -and ($aResource.ResourcetypeName -like "*/*")){
                $validResourceToMatch = $false
            }else{
                $validResourceToMatch = $true
            }
        }
        if($validResourceToMatch){
            $bResource = $cloudBCapabilities.resources | Where-Object { $_.providerNameSpace -eq $aResource.providerNameSpace } | Where-Object { $_.ResourcetypeName -eq $aResource.ResourcetypeName }
            $commonAPIVersions = @()
            $aOnlyAPIVersions = @()
            $bOnlyAPIVersions = @()
            $validCommonResource = $false
            if($bResource){
                $commonAPIVersions = Compare-Object -ReferenceObject $aResource.ApiVersions -DifferenceObject $bResource.ApiVersions -IncludeEqual -ExcludeDifferent -PassThru
                $aOnlyAPIVersions = Compare-Object -ReferenceObject $aResource.ApiVersions -DifferenceObject $bResource.ApiVersions -PassThru | Where-Object { $_.SideIndicator -eq "<=" }
                $bOnlyAPIVersions = Compare-Object -ReferenceObject $aResource.ApiVersions -DifferenceObject $bResource.ApiVersions -PassThru | Where-Object { $_.SideIndicator -eq ">=" }

                if($commonAPIVersions){
                    $validCommonResource = $true
                }else{
                    Write-Verbose "A resource has been found as common, but without common API versions between clouds A and B"
                }
            }
            if($validCommonResource){
                #Construct common resource object
                $commonResource = $bResource
                $commonResource | Add-Member NoteProperty aOnlyAPIVersions($aOnlyAPIVersions)
                $commonResource | Add-Member NoteProperty bOnlyAPIVersions($bOnlyAPIVersions)
                $commonResource | Add-Member NoteProperty commonAPIVersions($commonAPIVersions)
                $commonResource = $commonResource  | Select-Object -Property * -ExcludeProperty ApiVersions
                $commonResource.locations += $aResource.locations
                
                #Find latest common API version
                $latestCommonAPIVersion = [datetime]::ParseExact("1900-01-01",'yyyy-MM-dd',$null)
                foreach ($version in $commonAPIVersions){
                    #Replace preview versions
                    $shortVersion = $version -replace "-preview",""
                    $dateVersion = [datetime]::ParseExact($shortVersion,'yyyy-MM-dd',$null)
                    if($dateVersion -gt $latestCommonAPIVersion){
                        $latestCommonAPIVersion = $shortVersion
                    }
                }

                #Count API versions in A ahead of the latest common version
                if($aOnlyAPIVersions){
                    $versionDiffCount = 0
                    $latestAonlyAPIVersion = [datetime]::ParseExact("1900-01-01",'yyyy-MM-dd',$null)
                    foreach ($version in $aOnlyAPIVersions){
                        #Replace preview versions
                        $shortVersion = $version -replace "-preview",""
                        $dateVersion = [datetime]::ParseExact($shortVersion,'yyyy-MM-dd',$null)
                        
                        #Preview versions should be considered previous to non-preview versions of the same date
                        #Only preview versions will be equal because other equal versions are filtered previously with Compare-Object
                        if($dateVersion -ge $latestCommonAPIVersion){
                            $versionDiffCount++
                        }

                        #Keep track of the date of the latest API version available only in Cloud A so that a time span can be completed
                        if($dateVersion -gt $latestAonlyAPIVersion){
                            $latestAonlyAPIVersion = $shortVersion
                        }
                    } 
                }

                $commonResource | Add-Member NoteProperty APIVersionsBehindA($versionDiffCount)

                #Compute timespan between latest API version available in A and the latest commonly available version
                $APIVersionTimeDelta = New-Timespan -Start $latestCommonAPIVersion -End $latestAonlyAPIVersion
                $TimeDeltaMonths = $APIVersionTimeDelta.Days / 30.5;
                if($TimeDeltaMonths > 0){
                    $commonResource | Add-Member NoteProperty TimeDeltaBehindAMonths($TimeDeltaMonths)
                }else{
                    $commonResource | Add-Member NoteProperty TimeDeltaBehindAMonths(0)
                }


                $commonResources += $commonResource
            }else{
                $AonlyResources+= $aResource
            }
        }
    }


    Write-Output "Common resources available in both clouds:"
    $commonResources.count
    foreach ($commonResource in $commonResources) {
        $commonResource.locations = $commonResource.locations -join ","
        $commonResource.commonAPIVersions = $commonResource.commonAPIVersions -join ","
        $commonResource.aOnlyAPIVersions = $commonResource.aOnlyAPIVersions -join ","
        $commonResource.bOnlyAPIVersions = $commonResource.bOnlyAPIVersions -join ","
    }
    $commonResources | Export-Csv "CommonResources.csv" -NoTypeInformation

    Write-Output "--------------------------------------"

    Write-Output "Resources only available in Cloud A:"
    $AonlyResources.count
    foreach ($AonlyResource in $AonlyResources) {
        $AonlyResource.locations = $AonlyResource.locations -join ","
        $AonlyResource.apiVersions = $AonlyResource.apiVersions -join ","
    }
    $AonlyResources | Export-Csv "AResources.csv" -NoTypeInformation
}