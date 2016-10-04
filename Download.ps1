Param(
  [string]$RelPath = 'FILTER'
)

# Set Variabales
$LocalPath = 'c:\AzureStack_TP2_SupportFiles'
$Api = 'https://api.github.com/repos/Azure/AzureStack-Tools'
$Uri = 'https://raw.githubusercontent.com/Azure/AzureStack-Tools/master/'

# Get the Tree Recursively from the GitHub API
$Master = ConvertFrom-Json (invoke-webrequest ($Api + '/git/trees/master'))
$Content = (ConvertFrom-Json (invoke-webrequest ($Api + '/git/trees/' + $Master.sha + '?recursive=1'))).tree
if ($RelPath){$Content = $Content | where {$_.path -match $RelPath}}

# Create Folders and download files
New-Item $LocalPath -type directory -Force
($Content | where { ($_.type -eq 'tree') -and ($_.path -match $RelPath) }).path | ForEach { New-Item ($LocalPath + '\' + $_) -type directory -Force }
($Content | where { ($_.type -eq 'blob') -and ($_.path -match $RelPath) }).path | ForEach { Invoke-WebRequest ($Uri + $_) -OutFile ($LocalPath + '\' + $_) }