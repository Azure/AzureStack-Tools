$global:AzureStackSub
$global:AzureTenantId
$global:AzureSubscriptionId
$global:AzureStackCred

function foundVersionLister($inputList)
{
    $output = "`tFound`r`n"
    foreach($location in $inputList)
    {
        $output += "`t`tlocation: "+$location.location+"`r`n"
        foreach ($version in $location.versions)
        {
            $output += "`t`t`tVersion: "+$version+"`r`n"
        }
    }
    return $output
}

function versionTest($item, $testLocation, $name, $type, [ref]$failDict){
    $compatibleInner = 0
    $outbuf = ""
    $errorReport = ""
    foreach ($locObj in $item.locationList){
        if (($locObj.location -eq $testLocation) -or ($locObj.location -eq "all")  -or ($testLocation -ne "local" -and $locObj.location -eq "global")){
            foreach ($presentVersion in $locObj.versions)
            {
                if (($presentVersion -like $item.version+"*") -or (($item.version -eq "latest") -and ($locObj.versions.Count -gt 0))`
                     -or ($item.autoUpgradeMinorVersion -and ([version]$item.version -le [version]$presentVersion)`
                     -and ($presentVersion.Split(".")[0] -eq $item.version.Split(".")[0]))){
                    $compatibleInner = 1
                }
            }
        }
    }

    if (!$compatibleInner){
        if ($item.lineNum -ne $null)
        {
            if ($item.source -ne $null)
            {
                $outbuf += "@"+$item.source+"`r`n"
            }
            $outbuf += "line num "+$item.lineNum+": "
        }
        $outbuf += $type+": "+$name +" is not compatible. Version "+$item.version+" not found at location "+$testLocation+"`r`n"
        if ($item.locationList.versions.count -le 0)
        {
            $outbuf += "`tNo entries found`r`n"
            if ($type -eq "Resource")
            {
                $errorReport = "ServiceNotFound - "+$name+"`r`n"
            }
            elseif ($type -eq "Extension")
            {
                $errorReport = "ExtensionNotFound`r`n"
            }
            elseif ($type -eq "Image")
            {
                $errorReport = "ImageNotFound`r`n"
            }
        }
        else
        {
            $outbuf += foundVersionLister $item.locationList
            if ($type -eq "Resource")
            {
                $errorReport = "ServiceVersionMismatch - "+$name+"`r`n"
            }
            elseif ($type -eq "Extension")
            {
                $errorReport = "ExtensionVersionMismatch`r`n"
            }
            elseif ($type -eq "Image")
            {
                $errorReport = "ImageVersionMismatch`r`n"
            }
        }

        if ($errorReport)
        {
            $failDict.Value[$errorReport] += 1
        }
                
    }

    $errorReport
    $outbuf
    return $compatibleInner
}

function StaticConsistency($TemplatePath, $CapabilitiesPath, $ProcessImageExtensions, [ref]$failDict)
{
    $parseResults = Compare-TemplateCapability $TemplatePath $CapabilitiesPath -ImageExtensions $ProcessImageExtensions
    

    $errorMsgs = $parseResults[-5]
    $parsedResources = $parseResults[-4]
    $parsedFunctions = $parseResults[-3]
    $errorReport = ""
    $outbuf = ""
    $compatible = 1

    #check resource compatibility
    foreach ($item in $parsedResources){
        $name = $item.namespaceAttr + "/" + $item.name

        $testRet = versionTest $item $testLocation $name "Resource" ([ref]($failDict.Value))
        $errorReport += $testRet[$testRet.count - 3]
        $outbuf += $testRet[$testRet.count - 2]
        $compatibleInner = $testRet[$testRet.count - 1]

        $compatible = $compatible -band $compatibleInner
    }

    #check function compatibility
    foreach ($item in $parsedfunctions){
        $name = $item.name

        $testRet = versionTest $item $testLocation $name "Function" ([ref]($failDict.Value))
        $errorReport += $testRet[$testRet.count - 3]
        $outbuf += $testRet[$testRet.count - 2]
        $compatibleInner = $testRet[$testRet.count - 1]

        $compatible = $compatible -band $compatibleInner
    }

    #check extension compatibility
    try{
        if ($parseResults[-2])
        {
            $parsedExtensions = $parseResults[-2]
            foreach ($item in $parsedExtensions)
            {
                $name = $item.pulisher+"/"+$item.type+"/"+$item.version

                $testRet = versionTest $item $testLocation $name "Extension" ([ref]($failDict.Value))
                $errorReport += $testRet[$testRet.count - 3]
                $outbuf += $testRet[$testRet.count - 2]
                $compatibleInner = $testRet[$testRet.count - 1]

                $compatible = $compatible -band $compatibleInner
            }
        }
    }
    catch
    {
        Write-Information "No Extensions found"
    }

    #check image compatibility
    
    try
    {
        if ($parseResults[-1])
        {
            $parsedImages = $parseResults[-1]

            foreach ($item in $parsedImages)
            {
                $name = $item.pulisher+"/"+$item.offer+"/"+$item.sku+"/"+$item.version

                $testRet = versionTest $item $testLocation $name "Image" ([ref]($failDict.Value))
                $errorReport += $testRet[$testRet.count - 3]
                $outbuf += $testRet[$testRet.count - 2]
                $compatibleInner = $testRet[$testRet.count - 1]
                    
                $compatible = $compatible -band $compatibleInner
            }
        }
    }
    catch
    {
        Write-Information "No Extensions found"
    }

    $errorMsgs
    $errorReport
    $outbuf
    return $compatible
}

#TODO named parameters
function TestConsistency()
{
    Param(
        [Parameter(Mandatory=$true)][String] $topLevelDir,
        [Parameter(Mandatory=$true)][String] $TemplatePattern,
        [Parameter(Mandatory=$true)][String] $CapabilitiesPath,
        [Parameter(Mandatory=$true)][String] $outputPath,
        [Parameter(Mandatory=$true)][String] $testLocation,
        [Parameter(Mandatory=$true)][String[]] $DeployLocations,
        [Parameter(Mandatory=$true)][String] $RunMode,        
        [Parameter(Mandatory=$False)][bool] $ProcessImageExtensions=$False
    )
    $outputString = ""
    $outputList = New-Object System.Collections.ArrayList
    $passedNum = 0
    $failedNum = 0
    $abortNum = 0
    $DynamicPassedNum = @(0)*$DeployLocations.Count
    $DynamicFailedNum = @(0)*$DeployLocations.Count
    $failDict = @{}
    $excelLogging = $False
    $htmlLogging = $False
    $outputTable = New-Object System.Collections.ArrayList

    $dynamicOffset = 0
    if ($RunMode -ne "Static")
    {
        $dynamicOffset = $DeployLocations.Count
    }

    if ($outputPath.Split('.')[-1] -eq "html")
    {
        $htmlLogging = $True
    }
    elseif ($outputPath.Split('.')[-1] -eq "xlsx")
    {
        $excelLogging = $True
    }

	if ($excelLogging)
	{
		$xl=New-Object -ComObject Excel.Application
		$wb=$xl.WorkBooks.Add(1)
		$wsSummary=$wb.WorkSheets.item(1)
        $wsSummary.Name = "Result Summary"
        $ws = $wb.WorkSheets.Add()
        $ws.Name = "Template Results"
		$xl.Visible=$true
		$xl.DisplayAlerts = $FALSE

		$ws.Columns.Item(1).columnWidth = 30
        $ws.Columns.Item(2).columnWidth = 30
		$ws.Columns.Item(3 + $dynamicOffset).columnWidth = 30
		$ws.Columns.Item(4 + $dynamicOffset).columnWidth = 75

		$ws.Cells.Item(1,1) = "Template Name"
		$ws.Cells.Item(1,2) = "Static Analysis"
        $i = 0
        if ($RunMode -ne "Static")
        {
            foreach ($loc in $DeployLocations)
            {
                $ws.Cells.Item(1,3 + $i) = "Dynamic Analysis @ "+$loc
                $ws.Cells.Item(1,3 + $i).Font.Bold = $True
                $ws.Columns.Item(3 + $i).columnWidth = 30

                $ws.Cells.Item(1,5 + $dynamicOffset + $i) = "Dynamic Errors @ "+$loc
                $ws.Cells.Item(1,5 + $dynamicOffset + $i).Font.Bold = $True
                $ws.Columns.Item(5  + $dynamicOffset+ $i).columnWidth = 30
                $i += 1
            }
        }
		$ws.Cells.Item(1,3 + $dynamicOffset) = "Static Errors"
		$ws.Cells.Item(1,4 + $dynamicOffset) = "Static Output Messages"
		$ws.Cells.Item(1,1).Font.Bold = $True
		$ws.Cells.Item(1,2).Font.Bold = $True
		$ws.Cells.Item(1,3 + $dynamicOffset).Font.Bold = $True
		$ws.Cells.Item(1,4 + $dynamicOffset).Font.Bold = $True

	}

    $currentLocObj = Get-Location
    $currentLoc = $currentLocObj.ToString()
    $fullTestPath = $currentLoc+"\"+$topLevelDir+"\"+$TemplatePattern
    $fullTestPath = $fullTestPath.replace(".\", "")


    $directories = Get-ChildItem -Path $topLevelDir -Recurse | Where-Object {$_.FullName -like $topLevelDir+"\"+$TemplatePattern -or $_.FullName -like $fullTestPath}

    #initialize output
    foreach ($dirObj in $directories){
	    $dir = $dirObj.FullName
        $templateName = $dir.Replace($topLevelDir+"\", "")
        $TemplatePath = $dir
        $TemplateFileTest = Test-Path $TemplatePath

    
        if ($TemplateFileTest)
        {
            $rowOutput = @{"name" = $templateName}
            $outputTable.Add($rowOutput) | Out-Null
            if ($excelLogging)
            {
                $ws.Cells.Item($row+2,1) = $templateName
            }
        }
    }

    $row = 0
    if ($RunMode -eq "Static" -or $RunMode -eq "All")
    {
        foreach ($dirObj in $directories){
	        $dir = $dirObj.FullName
            $templateName = $dir.Replace($topLevelDir+"\", "")
            $TemplatePath = $dir#+"\azuredeploy.json"
            $ParameterPath = $TemplatePath.Replace(".json", ".parameters.json")
            $TemplateFileTest = Test-Path $TemplatePath
            $success = 0

    
            if ($TemplateFileTest)
            {
                Write-Verbose $TemplatePath

                $success = 0
                $abort = 0
                $outbuf = ""
                $outputList.Add("Testing "+$TemplatePath+"`r`n") | Out-Null

                if ($excelLogging)
                {
                    $ws.Cells.Item($row+2,1) = $templateName
                }

            
                try
                {
                    $staticRes = StaticConsistency $TemplatePath $CapabilitiesPath $ProcessImageExtensions ([ref]$failDict)
                    
                    $errorMsgs = $staticRes[-4]
                    $errorReport = $staticRes[-3]
                    $outbuf = $staticRes[-2]
                    $compatible = $staticRes[-1]

                    if ($errorMsgs.Count -ge 1)
                    {
                        $abort = 1
                        $abortNum += 1
                        $outbuf = "Parser Abort:`r`n"+$errorMsgs
                        $compatible = $False
                        $errorReport += "Parser Abort`r`n"
                    }
                    else
                    {
                        if ($compatible){
                            $outputList[$row] += "`tPassed in Static Check`r`n"
                            $success = 1
                            $passedNum += 1
                        }
                        else{
                            $outputList[$row] += "`tFailed in Static Check`r`n"
                            $success = 0
                            $failedNum += 1
                        }
                    }
                }
                catch
                {
                    $success = 0
                    $errorReport = "Exception`r`n"
                    $outbuf = $_.Exception.ItemName + $_.Exception.Message
                }

                #outputTable output
                if ($abort -eq 1)
                {
                    $outputTable[$row].Set_Item("status", "Parser Abort")
                }
				elseif ($success -eq 1)
				{
                    $outputTable[$row].Set_Item("status", "Passed")
				}
				else
				{
                    $outputTable[$row].Set_Item("status", "Failed")
				}

				$outputTable[$row].Set_Item("errorReport", $errorReport)
				    
				$outputTable[$row].Set_Item("message", $outbuf)

                if ($excelLogging)
			    {
                    if ($abort -eq 1)
                    {
                        $ws.Cells.Item($row+2,2) = "Parser Abort"
					    $ws.Cells.Item($row+2,2).Interior.ColorIndex = 45
                    }
				    elseif ($success -eq 1)
				    {
					    $ws.Cells.Item($row+2,2) = "Passed"
					    $ws.Cells.Item($row+2,2).Interior.ColorIndex = 4
				    }
				    else
				    {
					    $ws.Cells.Item($row+2,2) = "Failed"
					    $ws.Cells.Item($row+2,2).Interior.ColorIndex = 3
				    }

				    $ws.Cells.Item($row+2,3 + $dynamicOffset) = $errorReport
				    
				    $ws.Cells.Item($row+2,4 + $dynamicOffset) = $outbuf

			    }

                $txtOutBuf = $outbuf.split("`n")
                $it = 0
                foreach ($line in $txtOutBuf)
                {
                    $txtOutBuf[$it] = "`t`t" + $line
                    $it += 1
                }

                $outputList[$row] += ($txtOutBuf[0..($txtOutBuf.Count - 2)] -join "`n" ) + "`r`n"

                $row += 1
            
            }
        
        }
    }

    $inAzure = $False
    if ($RunMode -eq "Dynamic" -or $RunMode -eq "All")
    {
        #Autogenerate Parameters
        foreach ($dirObj in $directories){
	        $dir = $dirObj.FullName
            $templateName = $dir.Replace($topLevelDir+"\", "")
            $TemplatePath = $dir
            $ParameterPath = $TemplatePath.Replace(".json", ".parameters.json")
            $ParameterAutoPath = $TemplatePath.Replace(".json", ".parameters.auto.json")
            $TemplateFileTest = Test-Path $TemplatePath
            $ParameterFileTest = Test-Path $ParameterPath

            if ($TemplateFileTest -and $ParameterFileTest)
            {
                "Generate Parameters For "+$templateName
                Get-GeneratedParameters $TemplatePath $ParameterPath $ParameterAutoPath            
            }
        }
        $i = 0
        foreach ($DepLoc in $DeployLocations)
        {
            if ($DepLoc -eq "local")
            {
                SelectAzureStack
                $inAzure = $False
            }
            else
            {
                if (-Not $inAzure)
                {
                    SelectAzure
                    $inAzure = $True
                }
            }
            $row = 0
            foreach ($dirObj in $directories){
                $dir = $dirObj.FullName
                $templateName = $dir.Replace($topLevelDir+"\", "")
                $TemplatePath = $dir#+"\azuredeploy.json"
                $ParameterPath = $TemplatePath.Replace(".json", ".parameters.auto.json");
                $TemplateFileTest = Test-Path $TemplatePath

                if ($TemplateFileTest)
                {
                    Write-Verbose $TemplatePath
                    $success = 0
                    $DeployRes = 0
                    $DeployMessage = ""
                    try{
                        $DynamicRes = DeployTemplate $TemplatePath $ParameterPath $DepLoc
                        $DeployMessage = $DynamicRes[-2]
                        $DeployRes = $DynamicRes[-1]
                        if ($DeployRes)
                        {
                            $outputList[$row] += "`tPassed in Deployment @"+$Deploc+"`r`n"
                            $success = 1
                            $DynamicPassedNum[$i] += 1
                        }
                        else
                        {
                            $outputList[$row] += "`tFailed in Deployment @"+$Deploc+"`r`n"
                            $success = 0
                            $DynamicFailedNum[$i] += 1
                        }
                    }
                    catch{
                        $outputList[$row] += "`tFailed in Deployment @"+$Deploc+"`r`n"
                        $outputList[$row] += "Exceptopn:"+$_.Exception.Message+"`r`n"
                        $DynamicFailedNum[$i] += 1
                        $success = 0
                    }
                    $outputList[$row] += "`t`t"+$DeployMessage+"`r`n"

                    #outputTable output
                    if ($success -eq 1)
			        {
                        $outputTable[$row].Set_Item($Deploc+"status", "Passed")
			        }
			        else
			        {
                        $outputTable[$row].Set_Item($Deploc+"status", "Failed")
			        }
                    $outputTable[$row].Set_Item($Deploc+"message", $DeployMessage)

                    if ($excelLogging)
			        {

				        if ($success -eq 1)
				        {
					        $ws.Cells.Item($row+2,3 + $i) = "Passed"
					        $ws.Cells.Item($row+2,3 + $i).Interior.ColorIndex = 4
				        }
				        else
				        {
					        $ws.Cells.Item($row+2,3 + $i) = "Failed"
					        $ws.Cells.Item($row+2,3 + $i).Interior.ColorIndex = 3
				        }
                        $ws.Cells.Item($row+2,5 + $dynamicOffset + $i) = $DeployMessage

			        }
                    $row += 1
                }
           }
           $i += 1
        }
    }

    $outputString  = $outputList -join "`r`n`r`n"

    if ($htmlLogging)
    {
        #html output
        $htmlString = "<!DOCTYPE html><html>"
        $htmlString += "<head><style>"
        $htmlString += "td { white-space:pre }table {border-collapse: collapse;}`
            table, th, td {border: 1px solid black;}"
        $htmlString += "</head></style><body>"
        $htmlString += "<table>"

        #column names
        $htmlString += "<tr style='font-weight:bold;'>"

        $htmlString += "<td>"
        $htmlString += "Template Name"
        $htmlString += "</td>"

        if ($RunMode -eq "Static" -or $RunMode -eq "All")
        {
            $htmlString += "<td>Static Analysis</td>"
        }

        if ($RunMode -eq "Dynamic" -or $RunMode -eq "All")
        {
            foreach ($DepLoc in $DeployLocations)
            {
                $htmlString += "<td>Dynamic Analysis @$DepLoc</td>"
            }
        }

        if ($RunMode -eq "Static" -or $RunMode -eq "All")
        {
            $htmlString += "<td>Static Errors</td>"
            $htmlString += "<td>Static Output Messages</td>"
        }

        if ($RunMode -eq "Dynamic" -or $RunMode -eq "All")
        {
            foreach ($DepLoc in $DeployLocations)
            {
                $htmlString += "<td>Dynamic Errors @$DepLoc</td>"
            }
        }
        $htmlString += "</tr>"

        foreach ($rowOutput in $outputTable)
        {
            $htmlString += "<tr>"

            $htmlString += "<td>"
            $htmlString += $rowOutput["name"]
            $htmlString += "</td>"

            #status color
            $statusColor = "#FFFFFF"
            if ($rowOutput["status"] -eq "Passed")
            {
                $statusColor = "#00FF00"
            }
            elseif ($rowOutput["status"] -eq "Failed")
            {
                $statusColor = "#FF0000"
            }
            else
            {
                $statusColor = "#FF9900"
            }

            $htmlString += "<td bgcolor = '"+$statusColor+"'>"
            $htmlString += $rowOutput["status"]
            $htmlString += "</td>"

            if ($RunMode -eq "Dynamic" -or $RunMode -eq "All")
            {
                foreach ($DepLoc in $DeployLocations)
                {
                    $depStatus = $rowOutput[$Deploc+"status"]
                    $statusColor = "#FFFFFF"
                    if ($depStatus -eq "Passed")
                    {
                        $statusColor = "#00FF00"
                    }
                    else
                    {
                        $statusColor = "#FF0000"
                    }
                    $htmlString += "<td bgcolor = '"+$statusColor+"'>"
                    $htmlString += $depStatus
                    $htmlString += "</td>"
                }
            }

            $htmlString += "<td>"
            $htmlString += $rowOutput["errorReport"]
            $htmlString += "</td>"

            $htmlString += "<td>"
            $htmlString += $rowOutput["message"]
            $htmlString += "</td>"

            if ($RunMode -eq "Dynamic" -or $RunMode -eq "All")
            {
                foreach ($DepLoc in $DeployLocations)
                {
                    $depMessage = $rowOutput[$Deploc+"message"]
                    $htmlString += "<td>$depMessage</td>"
                }
            }

            $htmlString += "</tr>"
        }
        $htmlString += "</table>"
        $htmlString += "</body></html>"

        $htmlString | Out-File $outputPath
    }
	elseif ($excelLogging)
	{
		$wsSummary.Columns.Item(1).columnWidth = 50

		$wsSummary.Cells.Item(1,1) = "Result"
		$wsSummary.Cells.Item(2, 1) = "Passed"
		$wsSummary.Cells.Item(3, 1) = "Failed"
        $wsSummary.Cells.Item(4, 1) = "Abort"
		$wsSummary.Cells.Item(1, 1).Font.Bold = $True
		$wsSummary.Cells.Item(2, 1).Interior.ColorIndex = 4
		$wsSummary.Cells.Item(3, 1).Interior.ColorIndex = 3
        $wsSummary.Cells.Item(4, 1).Interior.ColorIndex = 45

		$wsSummary.Cells.Item(1, 2) = "Number"
		$wsSummary.Cells.Item(2, 2) = $passedNum
		$wsSummary.Cells.Item(3, 2) = $failedNum
        $wsSummary.Cells.Item(4, 2) = $AbortNum
		$wsSummary.Cells.Item(1, 2).Font.Bold = $True

		$wsSummary.Cells.Item(1, 3) = "Percentage"
		$wsSummary.Cells.Item(2, 3) = ($passedNum / ($passedNum + $failedNum + $abortNum) * 100).ToString() + "%"
		$wsSummary.Cells.Item(3, 3) = ($failedNum / ($passedNum + $failedNum + $abortNum) * 100).ToString() + "%"
        $wsSummary.Cells.Item(4, 3) = ($abortNum / ($passedNum + $failedNum + $abortNum) * 100).ToString() + "%"
		$wsSummary.Cells.Item(1, 3).Font.Bold = $True

		$row = 5
		foreach ($failure in $failDict.GetEnumerator())
		{
			$wsSummary.Cells.Item($row, 1) = $failure.Name
			$wsSummary.Cells.Item($row, 2) = $failure.Value
			$row += 1
		}

		#$outputString | Out-File $outputPath
		$wb.SaveAs($outputPath)
		$xl.Quit()
	}
	else
	{
        $outputString | Out-File $outputPath
	}

    "Completed Template Consistency Test"
    if ($RunMode -eq "Static" -or $RunMode -eq "All")
    {
        "Static Analysis Result Summary:"
        "`tPassed: "+$passedNum
        "`tFailed: "+$failedNum
        "`tParser Abort: "+$abortNum
    }
    if ($RunMode -eq "Dynamic" -or $RunMode -eq "All")
    {
        "Dynamic Analysis Result Summary:"
        $i = 0
        foreach ($loc in $DeployLocations)
        {
            "@"+$loc
            "`tPassed: "+$DynamicPassedNum[$i]
            "`tFailed: "+$DynamicFailedNum[$i]
            $i += 1
        }
    }
}

function CreateEnvironmentAzure($TenantId, $SubscriptionId)
{
    
    $global:AzureTenantId = $TenantId
    $global:AzureSubscriptionId = $SubscriptionId
}

function SelectAzure()
{
    Write-Verbose "Creating Azure Environment"
    Login-AzureRmAccount
    Select-AzureRmSubscription -TenantId $global:AzureTenantId -SubscriptionId $global:AzureSubscriptionId
}

function SelectAzureStack()
{
    AuthenticateAzureStack -Domain $env:USERDNSDOMAIN -aadCredential $global:AzureStackCred
}

function AuthenticateAzureStack()
{
    Param(
        [Parameter(Mandatory=$true)][String] $Domain,
		$aadCredential
    )

	$AADGuid = "5454420b-2e38-4b9e-8b56-1712d321cf33"

	#defaults
	$VerbosePreference="SilentlyContinue"; $WarningPreference="SilentlyContinue"

	#Endpoints
	"ARM: GET ENDPOINTS AND ADD ENVIRONMENT"
	$envName = "AzureStackCloud" 
	$ResourceManagerEndpoint = $("https://api.$Domain".ToLowerInvariant())
	$endptres = Invoke-RestMethod "${ResourceManagerEndpoint}/metadata/endpoints?api-version=1.0"

	Add-AzureRmEnvironment -Name ($envName) `
			-ActiveDirectoryEndpoint ($($endptres.authentication.loginEndpoint) + $AADGuid  + "/") `
			-ActiveDirectoryServiceEndpointResourceId ($($endptres.authentication.audiences[0])) `
			-ResourceManagerEndpoint ($ResourceManagerEndpoint) `
			-GalleryEndpoint ($endptres.galleryEndpoint) `
			-GraphEndpoint ($endptres.graphEndpoint) `
		   -StorageEndpointSuffix ("$($Domain)".ToLowerInvariant()) `
		   -AzureKeyVaultDnsSuffix ("vault.$($Domain)".ToLowerInvariant()) | Out-Null

	"ARM: LOGIN AAD CREDENTIALS AND SELECT SUBSCRIPTION" | Write-Verbose  -Verbose
	Add-AzureRmAccount -Environment (Get-AzureRmEnvironment -Name ($envName)) -Credential $aadCredential -TenantId $AADGuid | Out-Null
	Get-AzureRmSubscription -SubscriptionName "Default Provider Subscription" | Select-AzureRmSubscription | Out-Null
}

function CleanupEnvironmentAzureStack()
{
    Param($envName)
    Write-Verbose "Cleaning up Azure Stack Environment"
	Remove-AzureRmEnvironment -Name $envName -Verbose -Force | Out-Null
}

function DeployTemplate()
{
    Param($TemplatePath, $ParamPath, $locName)
    $ExceptionMessage = ""

    #ResourceGroup
	Write-Verbose "Creating Resource Group"
    try
    {
	    New-AzureRmResourceGroup -Name ($rgName = "tstrg" + (Get-Random -Minimum 100 -Maximum 999)) -Location $locName -ErrorAction Stop -Verbose -Force | Out-Null
    
        $result = New-AzureRmResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $TemplatePath -TemplateParameterFile $ParamPath -Name "testVMDeployment" -ErrorAction Stop -Verbose -Force

        #Cleanup
	    Get-AzureRmResource | where {$_.ResourceGroupName -eq $rgName} -ErrorAction Stop | Select ResourceType, ResourceName, Location, ResourceGroupName, SubscriptionId | ft
	
	
	    Write-Verbose  "Removing Resource Group"
	    Remove-AzureRmResourceGroup -Name $rgName -ErrorAction Stop -Verbose -Force  | Out-Null
    }
    catch{
        $ExceptionMessage = $_.Exception.Message
        $ExceptionMessage
        return $False
    }

    $ExceptionMessage
    return $result.ProvisioningState -eq "Succeeded"
}

function Test-TemplateCapability()
{
    [CmdletBinding(PositionalBinding=$false)]

    Param(
        [Parameter(Mandatory=$true, ParameterSetName = "Default")][String] $CapabilitiesPath,
        [Parameter(Mandatory=$true, ParameterSetName = "Default")][String] $TemplateDirectory, 
        [Parameter(Mandatory=$true, ParameterSetName = "Default")][String] $TemplatePattern,
        [Parameter(Mandatory=$true, ParameterSetName = "Default")][String] $OutputPath,
        [Parameter(ParameterSetName = "Default")][ValidateSet("Static","Dynamic","All")][String] $RunMode = "Static",
        [Parameter(ParameterSetName = "Default")][String] $StaticLocation = "local",
        [Parameter(ParameterSetName = "Default")][String[]] $DeployLocations = @("local"),
        [Parameter(ParameterSetName = "Default")][bool] $ProcessImageExtensions = $False,
        [String]$TenantId,
        [String]$SubscriptionId,
		$aadCredential
    )

    $sw = [Diagnostics.Stopwatch]::StartNew()

    $AzureStackEnvName = "AzureStackTestEnv"

    #git clone "https://github.com/Azure/AzureStack-QuickStart-Templates.git" $gitPath
    if ($RunMode -eq "Dynamic" -or $RunMode -eq "All")
    { 
		$global:AzureStackCred = $aadCredential
        # match string which does not contain "local"
        if ($DeployLocations -match "^((?!local).)*$")
        {
            CreateEnvironmentAzure $TenantId $SubscriptionId
        }
    }
    $topLevelDir, $TemplatePattern, $CapabilitiesPath, $outputPath, $testLocation, $DeployLocations, $RunMode
    TestConsistency -topLevelDir $TemplateDirectory -TemplatePattern $TemplatePattern -CapabilitiesPath $CapabilitiesPath `
        -outputPath $outputPath -testLocation $StaticLocation -DeployLocations $DeployLocations -RunMode $RunMode -ProcessImageExtensions $ProcessImageExtensions

    $sw.Stop()
	$time = $sw.Elapsed
	"Time Elapsed = "+[math]::floor($time.TotalMinutes)+" min "+$time.Seconds+" sec"
}
export-modulemember -function Test-TemplateCapability