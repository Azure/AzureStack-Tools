param(
    [CmdletBinding(DefaultParameterSetName="relativeTime")]
    [Parameter(Position = 1, Mandatory = $false)]
    [string]$adminSubscriptionName = "Default Provider Subscription" ,
    [Parameter(Position = 2, Mandatory = $false)]
    [string]$jsonTemplateLocation = ".\templateJson" ,
    [Parameter(Mandatory = $false)]
    [System.Object]$DefaultProfile,
    [Parameter(ParameterSetName="relativeTime")]
    [ValidateSet('PT30M', 'PT4H', 'PT12H', 'P1D', 'P2D', 'P3D', 'P7D', 'P30D')]
    [string]$duration = 'P1D',
    [Parameter(Mandatory=$True, ParameterSetName="absoluteTime", HelpMessage="Please enter the start time of time range you want to see.")]
    [datetime]$startTime,
    [Parameter(Mandatory=$True, ParameterSetName="absoluteTime", HelpMessage="Please enter the end time of time range you want to see.")]
    [datetime]$endTime,
    [Parameter(Mandatory = $false)]
    [ValidateSet('Automatic', 'PT1M', 'PT1H', 'P1D', 'PT5M', 'PT15M', 'PT30M', 'PT6H', 'PT12H')]
    [string]$timeGrain = 'Automatic',
    [Parameter(Mandatory = $false)]
    [string]$outputLocation = '.',
    [Parameter(Mandatory = $false)]
    [Boolean]$capacityOnly = $false,
    [Parameter(Mandatory = $false)]
    [ValidateSet('all', 'object', 'infrastructure', 'vmtemp')]
    [string]$volumeType = 'all'
)

<#
.SYNOPSIS
    Generate json used in Azure Stack portal to show volumes performances.
.Description
    This function is used to generate dashboard jsons, which can be uploaded on Azure Stack Dashboard to create related dashboards.
    You can use this function without parameters to create jsons, showing last 1 day metrics, at the current folder.
    To set time range, you can define duration or pair of startTime and endTime.
.Inputs
    Charts' Time range and granularity settings. Json output location setting.
.Outputs
    Three jsons represent count, latency and throughput performance respectively.
.Parameter timeGrain
    The timespan defines the time granularity in charts, in ISO 8601 duration format.
.Parameter outputLocation
    The location to expose generated jsons.
.Parameter duration
    The timespan defines the time range of volume metrics, in ISO 8601 duration format.
.Parameter startTime
    The start time of time range shown on dashboard.
.Parameter endTime
    The start time of time range shown on dashboard.
.Example
    # default json save to spedified location
    Save-AzureStackVolumesPerformanceDashboardJson -outputLocation 'D:\dashboardJsons'
.Example
    # data of last day with 15min interval
    Save-AzureStackVolumesPerformanceDashboardJson -duration "P1D" -timeGrain "PT15M"
.Example
    # date from 4/1 to 4/8 with 1hr interval 
    Save-AzureStackVolumesPerformanceDashboardJson -startTime (Get-date("2019-04-01")) -endTime (Get-date("2019-04-08")) -timeGrain "PT1H"
.Notes
    Author: Azure Stack Azure Monitor Team
.Link
    Source Code: https://github.com/GTMer/AzureStack-VolumesPerformanceDashboard-Generator
#>
function Save-AzureStackVolumesPerformanceDashboardJson {
    [CmdletBinding(DefaultParameterSetName="relativeTime")]
    param (
        [Parameter(Mandatory = $false)]
        [System.Object]$DefaultProfile,
        [Parameter(ParameterSetName="relativeTime")]
        [ValidateSet('PT30M', 'PT4H', 'PT12H', 'P1D', 'P2D', 'P3D', 'P7D', 'P30D')]
        [string]$duration = 'P1D',
        [Parameter(Mandatory=$True, ParameterSetName="absoluteTime", HelpMessage="Please enter the start time of time range you want to see.")]
        [datetime]$startTime,
        [Parameter(Mandatory=$True, ParameterSetName="absoluteTime", HelpMessage="Please enter the end time of time range you want to see.")]
        [datetime]$endTime,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Automatic', 'PT1M', 'PT1H', 'P1D', 'PT5M', 'PT15M', 'PT30M', 'PT6H', 'PT12H')]
        [string]$timeGrain = 'Automatic',
        [Parameter(Mandatory = $false)]
        [string]$outputLocation = '.'
    )

    # check if Az Module is present
    $AzModule = Get-command -Name Get-AzContext -ErrorAction SilentlyContinue
    if($AzModule){
        # do nothing, cmdlets should work natively.
    } else {
        throw "Error: This script requires 'Az' PowerShell Module to be installed."
    }

    # If user do not input DefaultProfile
    if ($null -eq $DefaultProfile) {
        $script:context = Get-AzContext
    }
    else {
        $script:context = $DefaultProfile.Context
    }
    
    # if user hadn't added and login to AzEnvironment, exit
    if ($null -eq $script:context.Account) {
        throw "Please login in Az account first."
    }

    if ((Test-Path -Path $outputLocation) -eq $false) {
        throw "Output location not exist."
    }
    
    # $resourceId = Get-AzureStackResourceId
    $volumes = Get-AzureStackVolumes 

    if ($timeGrain -eq 'Automatic') {
        if ($PSCmdlet.ParameterSetName -eq "absoluteTime") {
            $timeRange = $endTime - $startTime
        }
        else {
            $timeRange = [System.Xml.XmlConvert]::ToTimeSpan($duration)
        }
        
        if ($timeRange -le (New-TimeSpan -Hours 4)) {
            $timeGrain = "PT1M"
        }
        if ($timeRange -lt (New-TimeSpan -Days 1)) {
            $timeGrain = "PT5M"
        }
        elseif ($timeRange -le (New-TimeSpan -Days 1)) {
            $timeGrain = "PT15M"
        }
        elseif ($timeRange -le (New-TimeSpan -Days 3)) {
            $timeGrain = "PT30M"
        }
        elseif ($timeRange -le (New-TimeSpan -Days 7)) {
            $timeGrain = "PT1H"
        }
        else {
            $timeGrain = "PT6H"
        }
    }
    $description = "timeGrain: $timeGrain;  `n"

    if ($PSCmdlet.ParameterSetName -eq "absoluteTime") {
        if ($startTime -gt $endTime) {
            throw ("StartTime should less than EndTime!")
        }
        if ($startTime -gt $(Get-Date)) {
            throw ("StartTime should less than Now!")
        }
        $description += "startTime: $($startTime.ToString('o'));  `nendTime: $($endTime.ToString('o'));  `n"
        $volumeTypes | ForEach-Object {
            Get-DashboardVolumesJson -volumeType $_ -startTime $startTime.ToString('o') -endTime $endTime.ToString('o') -timeGrain $timeGrain -description $description -volumes $volumes |
                ConvertTo-Json -Depth 100 | Format-Json > $($outputLocation.TrimEnd('\') + '\' + "DashboardVolume" + $_ + "_customTime.json")
            Write-Host "$($outputLocation.TrimEnd('\') + '\' + "DashboardVolume" + $_ + "_customTime.json") finished."
        }
    }
    else {
        $description += "duration: $duration;  `n"
        $durationTotalMilliseconds = ([System.Xml.XmlConvert]::ToTimeSpan($duration)).TotalMilliseconds
        $volumeTypes | ForEach-Object {
            Get-DashboardVolumesJson -duration $durationTotalMilliseconds -timeGrain $timeGrain -description $description -volumes $volumes -volumeType $_ |
                ConvertTo-Json -Depth 100 | Format-Json > $($outputLocation.TrimEnd('\') + '\' + "DashboardVolume" + $_ + "_"  + $duration + ".json")
            Write-Host "$($outputLocation.TrimEnd('\') + '\' + "DashboardVolume" + $_ + "_"  + $duration + ".json") finished."
        }
    }
}

function Get-AzureStackResourceId {
    [CmdletBinding()]
    param (
    )
    try {
        Write-Host "Getting resource Id from AzSubscription."
        $adminSubscription = $script:context.Subscription
        $location = Get-AzLocation -DefaultProfile $script:context -ErrorAction Stop -Verbose
    }
    catch {
        Write-Error $_
        throw "Please login in Az account. If still happens, check your environment settings in psm1 file."
    }
    "subscriptions/$($adminSubscription.Id)/resourceGroups/System.$($location.location)/providers/Microsoft.Fabric.Admin/fabricLocations/$($location.location)"
}

function Get-AzureStackVolumes {
    [CmdletBinding()]
    param (
    )
    try {
        Write-Host "Getting volumes data from ARM."

        $location = Get-AzLocation -DefaultProfile $script:context -ErrorAction Stop -Verbose
        $location = $location.Location
        $scaleUnits = Get-AzResource -DefaultProfile $script:context -ResourceName $location -ResourceType Microsoft.Fabric.Admin/fabricLocations/scaleunits -ResourceGroupName "System.$($location)" -ApiVersion "2016-05-01"
        $sotrageSubSystems = Get-AzResource -DefaultProfile $script:context -ResourceName $scaleUnits.Name -ResourceType Microsoft.Fabric.Admin/fabricLocations/scaleunits/storageSubSystems -ResourceGroupName "System.$($location)" -ApiVersion "2018-10-01"
        $volumes = Get-AzResource -DefaultProfile $script:context -ResourceName $sotrageSubSystems.Name -ResourceType Microsoft.Fabric.Admin/fabricLocations/scaleunits/storageSubSystems/volumes -ResourceGroupName "System.$($location)" -ApiVersion "2018-10-01"
    }
    catch {
        Write-Error $_.ToString()
        Write-Error "Cannot fetch data from ARM."
    }
    $volumes
}

<#
.SYNOPSIS
    Transform volumes into dictionary of list of tuple to show volume name namemaps, eg: $volumesByType["ObjStore"][2] = Tupe["Volume11", "Obj_store2"] .
#>
function Get-volumesByType {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [array]$volumes = ( Get-AzureStackVolumes )
    )
    Write-Host "Analyzing volumes data."

    if ($volumes.Count -eq 0) {
        return
    }

    $volumesByType = @{}


    $volumeTypes | ForEach-Object {
        $volumesByType.$_ = New-Object 'Collections.Generic.List[Tuple[String,String]]'
    }

    $volumes | ForEach-Object {
        $labelPrefix = [regex]::match($_.properties.volumeLabel, '(.*)_.*').Groups[1].Value
        if ($volumeTypes.Contains($labelPrefix)) {
            $volumeLocalName = [regex]::match($_.properties.volumeLocalName, '.*\/(.*)').Groups[1].Value
            $volumesByType.$labelPrefix.add([Tuple]::Create($volumeLocalName, $_.properties.volumeLabel))
        }
    }

    $volumeTypes | ForEach-Object {
        $volumesByType.$_ = $volumesByType.$_ | Sort-Object Item2
    }

    $volumesByType
}

<#
.SYNOPSIS
    Transform template json into PsCustomObject.
#>
function Initialize-TilePsCustomObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Throughput", "Count", "Latency", "Capacity")]
        [string]$metricType,
        [Parameter(ParameterSetName="relativeTime")]
        [Double]$duration = 86400000,
        [Parameter(ParameterSetName="absoluteTime")]
        [string]$startTime,
        [Parameter(ParameterSetName="absoluteTime")]
        [string]$endTime,
        [Parameter(Mandatory = $false)]
        [string]$timeGrain = "PT15M",
        [Parameter(Mandatory = $true)]
        [string]$resourceId
    )

    if ($metricType -eq "Capacity") {
        $tileTemplate = $Script:capacityTemplate.Replace("<resourceIdToBeReplaced>", '/' + $resourceId) | ConvertFrom-Json
    }
    else {
        if ($capacityOnly -eq $false) {
            $tileTemplate = $Script:tileTemplate.Replace("<resourceIdToBeReplaced>", '/' + $resourceId) | ConvertFrom-Json
        }
    }

    # set tile size
    $tileTemplate.position.colSpan = $tileColSpan
    $tileTemplate.position.rowSpan = $tileRowSpan

    $templateChart = $tileTemplate.metadata.inputs[0].value.charts[0]

    # set time range
    $templateChart.timeContext.psobject.properties.remove("relative")
    $templateChart.timeContext.psobject.properties.remove("absolute")
    if ($PSCmdlet.ParameterSetName -eq "relativeTime") {
        $templateChart.timeContext | Add-Member -MemberType NoteProperty -Name "relative" -Value ([psCustomObject]@{'duration'=$duration})
    }
    else {
        $templateChart.timeContext | Add-Member -MemberType NoteProperty -Name "absolute" -Value ([psCustomObject]@{'startTime'=$startTime; 'endTime'=$endTime})
    }

    # set time granularity
    $chartGrainMap = @{'Automatic' = 1; 'PT1M' = 2; 'PT1H' = 3; 'P1D' = 4; 'PT5M' = 7; 'PT15M' = 8; 'PT30M' = 9; 'PT6H' = 10; 'PT12H' = 11}
    $templateChart.itemDataModel.appliedISOGrain = $templateChart.timeContext.options.appliedISOGrain = $timeGrain
    $templateChart.timeContext.options.grain = $chartGrainMap.$timeGrain

    $tileTemplate
}

<#
.SYNOPSIS
    Get individual tile PsCustomObjects.
#>
function Get-TilePsCustomObject { 
    param (
        [Parameter(Mandatory = $true)]
        [psCustomObject]$tileTemplate,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Throughput", "Count", "Latency", "Capacity")]
        [string]$metricType,
        [Parameter(Mandatory = $true)]
        [string]$tileName,
        [Parameter(Mandatory = $true)]
        [string]$filterVolumeName,
        [Parameter(Mandatory = $true)]
        [int]$positionX,
        [Parameter(Mandatory = $true)]
        [int]$positionY
    )

    # deep copy
    $tileTemplate = $tileTemplate | ConvertTo-Json -Depth 100 | ConvertFrom-Json

    $templateChart = $tileTemplate.metadata.inputs[0].value.charts[0]

    #change aggregation type
    $aggregationTypeofMetric = @{'Throughput' = 'Sum'; 'Count' = 'Sum'; 'Latency' = 'Avg'; 'Capacity' = 'Avg'}
    $aggregationType = $aggregationTypeofMetric.$metricType
    if ($aggregationType -eq "Sum") {
        $templateChart.metrics | ForEach-Object { $_.aggregationType = 4 }
        $templateChart.itemDataModel.metrics | ForEach-Object {$_.metricAggregation = 1 }
    }
    else {
        $templateChart.metrics | ForEach-Object { $_.aggregationType = 1 }
        $templateChart.itemDataModel.metrics | ForEach-Object {$_.metricAggregation = 4 }
    }

    switch ($metricType) {
        Capacity { 
            
        }
        Default {
            #change metrics name 
            $templateChart.metrics[0].name = $templateChart.itemDataModel.metrics[0].id.name.id = "VolumeOperations" + $( if ($metricType -eq "Count") {""} else {$metricType} ) + "Read"
            $templateChart.metrics[1].name = $templateChart.itemDataModel.metrics[1].id.name.id = "VolumeOperations" + $( if ($metricType -eq "Count") {""} else {$metricType} ) + "Write"
            $templateChart.itemDataModel.metrics[0].id.name.displayName = $metricType + "Read"
            $templateChart.itemDataModel.metrics[1].id.name.displayName = $metricType + "Write"
        }
    }

    #change tile name
    $templateChart.title = $templateChart.itemDataModel.title = $tileName

    #change filter
    $templateChart.itemDataModel.filters.OperandFilters[0].OperandSelectedValues[0] = $filterVolumeName

    # change position
    $tileTemplate.position.x = $positionX
    $tileTemplate.position.Y = $positionY
    
    $tileTemplate
}

<#
.SYNOPSIS
    Get dashboard json in PsCustomObject format.
#>
function Get-DashboardVolumesJson {
    [CmdletBinding(DefaultParameterSetName="relativeTime")]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [array]$volumes = ( Get-AzureStackVolumes ),
        [Parameter(Mandatory = $false)]
        [ValidateSet("ObjStore", "Infrastructure", "VmTemp")]
        [string]$volumeType = "ObjStore",
        [Parameter(ParameterSetName="relativeTime")]
        [Double]$duration = 86400000,
        [Parameter(ParameterSetName="absoluteTime")]
        [string]$startTime,
        [Parameter(ParameterSetName="absoluteTime")]
        [string]$endTime,
        [Parameter(Mandatory = $false)]
        [string]$timeGrain = "PT15M",
        
        [Parameter(Mandatory = $false)]
        [string]$description = ""
    )

    if ($volumes.Count -eq 0) {
        return
    }

    $volumesByType = Get-volumesByType -volumes $volumes

    Write-Host "Generating dashboard json."

    $resourceId = ( Get-AzureStackResourceId )
    $dashboardBody = $Script:dashboardBody.Replace("<resourceIdToBeReplaced>", '/' + $resourceId) | ConvertFrom-Json

    # change dashboard title/name 
    $dashboardBody.name = $dashboardBody.tags."hidden-title" = $volumeType + " Volumes Operation Performance" 
    
    $Templates = @{}
    $metricTypes | ForEach-Object {
        if ($PSCmdlet.ParameterSetName -eq "relativeTime") {
            $Templates[$_] = Initialize-TilePsCustomObject -metricType $_ -duration $duration -timeGrain $timeGrain -resourceId $resourceId   
        }
        else {
            $Templates[$_] = Initialize-TilePsCustomObject -metricType $_ -startTime $startTime -endTime $endTime -timeGrain $timeGrain -resourceId $resourceId 
        }
    }

    # deprecated tiles
        # set markDown board content
        # $dashboardBody.properties.lenses."0".parts."0".metadata.settings.content.settings.content += $aggregationType + " Volume Operations " + $metricType + " by  `n" + $description

        # the tile of total performance
        # $tileJson = $tileTemplate | ConvertTo-Json -depth 100 | ConvertFrom-Json
        # $tileJson.metadata.inputs[0].value.charts[0].itemDataModel.psobject.properties.remove("filters")
        # $dashboardBody.properties.lenses."0".parts | Add-Member -MemberType NoteProperty -Name "1" -Value $tileJson

    $dashboardBody.properties.lenses."0".parts = [PSCustomObject]@{}    

    # create tiles
    if ($capacityOnly -eq $true) {
        $tileColCount = 3
        for ($($tileIndex = 0; $tileNum = 0); $tileIndex -lt $volumesByType.$volumeType.Count; $tileIndex++) {
            $positionY = $tileRowSpan * ([math]::floor($tileIndex/$tileColCount))
            $positionX = $tileColSpan * ($tileIndex%$tileColCount)

            $thisMetricType = $metricTypes[0]
            $tileName = $volumesByType.$volumeType[$tileIndex].Item2 + " " + $metricTypes[0]
            $filterVolumeName = $volumesByType.$volumeType[$tileIndex].Item2

            $tileJsonObj = Get-TilePsCustomObject -tileTemplate $Templates[$metricTypes[0]] -tileName $tileName -positionX $positionX -positionY $positionY -filterVolumeName $filterVolumeName -metricType $thisMetricType
            # $chart.itemDataModel.filters.OperandFilters[0].OperandSelectedValues[0] = $volumesByType.($volumeTypes[$rowNum])[$colNum].Item1         
            $dashboardBody.properties.lenses."0".parts | Add-Member -MemberType NoteProperty -Name $tileNum -Value $tileJsonObj
            $tileNum++
        }
    } else {
        for ($($rowNum = 0; $tileNum = 0); $rowNum -lt $volumesByType.$volumeType.Count; $rowNum++) {   
            $positionY = $tileRowSpan * $rowNum
            for ($colNum = 0; $colNum -lt $metricTypes.Count; $colNum++) {
                $posotionX = $tileColSpan * $colNum
                $thisMetricType = $metricTypes[$colNum]
                $tileName = $volumesByType.$volumeType[$rowNum].Item2 + " " + $( if ($thisMetricType -eq "Count") {"Operation"} else {""} ) + $metricTypes[$colNum]
                $filterVolumeName = $( if ($thisMetricType -eq "Capacity") { $volumesByType.$volumeType[$rowNum].Item2 } else { $volumesByType.$volumeType[$rowNum].Item1 } )
            
                $tileJsonObj = Get-TilePsCustomObject -tileTemplate $Templates[$metricTypes[$colNum]] -tileName $tileName -positionX $posotionX -positionY $positionY -filterVolumeName $filterVolumeName -metricType $thisMetricType
                # $chart.itemDataModel.filters.OperandFilters[0].OperandSelectedValues[0] = $volumesByType.($volumeTypes[$rowNum])[$colNum].Item1         
                $dashboardBody.properties.lenses."0".parts | Add-Member -MemberType NoteProperty -Name $tileNum -Value $tileJsonObj
                $tileNum++
            }        
        }
    }

    $dashboardBody 
}

# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
# To reduce JSON output file size for 12 and 16 node stamps.
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    ($json -Split "`n" | ForEach-Object {
        if ($_ -match '[\}\]]\s*,?\s*$') {
            # This line ends with ] or }, decrement the indentation level
            $indent--
        }
        $line = ('  ' * $indent) + $($_.TrimStart() -replace '":  (["{[])', '": $1' -replace ':  ', ': ')
        if ($_ -match '[\{\[]\s*$') {
            # This line ends with [ or {, increment the indentation level
            $indent++
        }
        $line
    }) -Join "`n"
}

#========Module Initalize========#
$context = $null

#size of tile
$tileColSpan = 6
$tileRowSpan = 4

# If you want to add new metrics, adapt function Initialize-TilePsCustomObject and Get-TilePsCustomObject, then register here 
if ($capacityOnly -eq $True) {
    $metricTypes = @('Capacity')
} else {
    $metricTypes = @('Capacity', 'Throughput', 'Count', 'Latency')
}

switch ($volumeType) {
    object {
        $volumeTypes = @("ObjStore")
    }
    infrastructure {
        $volumeTypes = @("Infrastructure")
    }
    vmtemp {
        $volumeTypes = @("VmTemp")
    }
    Default {
        $volumeTypes = @("ObjStore", "Infrastructure", "VmTemp")
    }
}

if (!((Test-Path -Path ($jsonTemplateLocation.TrimEnd('\') + '\dashboardBody.json'))  -and  (Test-Path -Path ($jsonTemplateLocation.TrimEnd('\') + '\tileTemplate.json' )))) {
    throw "Template location not exist."
}
try {
    $dashboardBody = Get-Content ($jsonTemplateLocation.TrimEnd('\') + '\dashboardBody.json') | Out-String 
    $tileTemplate = Get-Content ($jsonTemplateLocation.TrimEnd('\') + '\tileTemplate.json') | Out-String 
    $capacityTemplate = Get-Content ($jsonTemplateLocation.TrimEnd('\') + '\capacityTemplate.json') | Out-String 
}
catch {
    Write-Error $_
    throw "Template not exist"
}

if ($PSCmdlet.ParameterSetName -eq "absoluteTime") {
    Save-AzureStackVolumesPerformanceDashboardJson -DefaultProfile $DefaultProfile -startTime $startTime -endTime $endTime -timeGrain $timeGrain -outputLocation $outputLocation
}
else {
    Save-AzureStackVolumesPerformanceDashboardJson -DefaultProfile $DefaultProfile -duration $duration -timeGrain $timeGrain -outputLocation $outputLocation
}
