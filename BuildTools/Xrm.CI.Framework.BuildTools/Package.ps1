#
# Package.ps1
# 
# Run this script to generate the tasks folder structure and extension
#

$ErrorActionPreference = "Stop"

Write-Host "Packaging Dynamics 365 Builds tools"

#Script Location
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
Write-Host "Script Path: $scriptPath"

.\Make.ps1

#Creating output directory
$OutputDir = $scriptPath + "\bin"
$PackageRoot = $scriptPath + "\bin"
$ManifestFile = "$PackageRoot\vss-extension.json"
$ManifestFilePrivate = "$scriptPath\vss-extension-dev.json"
$ManifestFilePreview = "$scriptPath\vss-extension-preview.json"

tfx extension create --manifest-globs $ManifestFile --output-path $OutputDir --root $OutputDir --overrides-file $ManifestFilePrivate

tfx extension create --manifest-globs $ManifestFile --output-path $OutputDir --root $OutputDir --overrides-file $ManifestFilePreview

tfx extension create --manifest-globs $ManifestFile --output-path $OutputDir --root $OutputDir

Copy-Item -Path $ManifestFile -Destination .\ -Force