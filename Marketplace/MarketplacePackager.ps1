
Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [String] $source,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [String] $zipArchive

)

[System.Reflection.Assembly]::Load("WindowsBase,Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35")
#####

if(Test-Path $zipArchive) { Remove-Item $zipArchive}
try {
$ZipPackage=[System.IO.Packaging.Package]::Open($zipArchive, [System.IO.FileMode]"OpenOrCreate", [System.IO.FileAccess]"ReadWrite")

#region Manifest
   $partName=New-Object System.Uri("/Manifest.json", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "application/json")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/manifest")
   $bytes=[System.IO.File]::ReadAllBytes("$source\Manifest.json")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
#endregion Manifest

#region UI Definition
   $partName=New-Object System.Uri("/UIDefinition.json", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "text/json")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/uidefinition")
   $bytes=[System.IO.File]::ReadAllBytes("$source\UIDefinition.json")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
#endregion Manifest

#region Images
   $partName=New-Object System.Uri("/Icons/Small.png", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "image/png")
   $bytes=[System.IO.File]::ReadAllBytes("$source\Icons\Small.png")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
   $guid=[guid]::NewGuid()
   $guid=$guid.ToString("N")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/icon/small","DEFAULT_$guid")

   $partName=New-Object System.Uri("/Icons/Medium.png", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "image/png")
   $bytes=[System.IO.File]::ReadAllBytes("$source\Icons\Medium.png")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
   $guid=[guid]::NewGuid()
   $guid=$guid.ToString("N")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/icon/medium","DEFAULT_$guid")

   $partName=New-Object System.Uri("/Icons/Large.png", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "image/png")
   $bytes=[System.IO.File]::ReadAllBytes("$source\Icons\Large.png")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
   $guid=[guid]::NewGuid()
   $guid=$guid.ToString("N")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/icon/large","DEFAULT_$guid")

   $partName=New-Object System.Uri("/Icons/Wide.png", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "image/png")
   $bytes=[System.IO.File]::ReadAllBytes("$source\Icons\Wide.png")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
   $guid=[guid]::NewGuid()
   $guid=$guid.ToString("N")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/icon/wide","DEFAULT_$guid")

   $partName=New-Object System.Uri("/Icons/Hero.png", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "image/png")
   $bytes=[System.IO.File]::ReadAllBytes("$source\Icons\Hero.png")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
   $guid=[guid]::NewGuid()
   $guid=$guid.ToString("N")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/icon/hero","DEFAULT_$guid")
#endregion Images

#region resources
   $partName=New-Object System.Uri("/strings/resources.resjson", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "text/json")
   $bytes=[System.IO.File]::ReadAllBytes("$source\strings\resources.resjson")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
   $guid=[guid]::NewGuid()
   $guid=$guid.ToString("N")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/strings","DEFAULT_$guid")
#endregion resources

#region CreateUIDefinition
   $partName=New-Object System.Uri("/Artifacts/CreateUiDefinition.json", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "text/json")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/artifact")
   $bytes=[System.IO.File]::ReadAllBytes("$source\Artifacts\CreateUiDefinition.json")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()

   $guid=[guid]::NewGuid()
   $guid=$guid.ToString("N")
   $uri=New-Object System.Uri("/$guid/Artifact", [System.UriKind]"Relative")
   $relationship=$part.CreateRelationShip($uri , [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/deploymenttemplateproperties")
   $part=$ZipPackage.CreatePart($uri, "text/xml")
   $artifactContent = @"
<?xml version="1.0"?>
<Artifact xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <Name>createuidefinition</Name>
  <Type>Custom</Type>
  <Path>Artifacts\CreateUiDefinition.json</Path>
  <IsDefault>false</IsDefault>
</Artifact>
"@
   $enc = [system.Text.Encoding]::UTF8
   $bytes=$enc.GetBytes($artifactContent)
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
#endregion CreateUIDefinition

#region ARM Template
   $partName=New-Object System.Uri("/Artifacts/mainTemplate.json", [System.UriKind]"Relative")
   $part=$ZipPackage.CreatePart($partName, "text/json")
   $relationship=$ZipPackage.CreateRelationShip($partName, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/artifact")
   $bytes=[System.IO.File]::ReadAllBytes("$source\Artifacts\mainTemplate.json")
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()
   
   $guid=[guid]::NewGuid()
   $guid=$guid.ToString("N")
   $uri=New-Object System.Uri("/$guid/Artifact", [System.UriKind]"Relative")
   $relationship=$part.CreateRelationShip($uri , [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/azpkg/2013/12/deploymenttemplateproperties")
   $part=$ZipPackage.CreatePart($uri, "text/xml")

   $artifactContent = @"
<?xml version="1.0"?>
<Artifact xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <Name>DefaultTemplate</Name>
  <Type>Template</Type>
  <Path>Artifacts\mainTemplate.json</Path>
  <IsDefault>true</IsDefault>
</Artifact>
"@

   $enc = [system.Text.Encoding]::UTF8
   $bytes=$enc.GetBytes($artifactContent)
   $stream=$part.GetStream()
   $stream.Write($bytes, 0, $bytes.Length)
   $stream.Close()

   Write-Host "Azpkg is saved into '$zipArchive'" -ForegroundColor Green
#endregion ARM Template
} catch {
   Write-Host "Azpkg wasn't created. $_" -ForegroundColor Magenta
}
finally {
    $ZipPackage.Close()
}