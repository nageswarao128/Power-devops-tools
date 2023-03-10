[CmdletBinding()]

param()

$ErrorActionPreference = "Stop"

Write-Verbose 'Entering MSCRMToolInstaller.ps1'

#Inputs
$nugetFeed = Get-VstsInput -Name nugetFeed -Require
$nugetSource = Get-VstsInput -Name nugetSource
$nugetUsername = Get-VstsInput -Name nugetUsername
$nugetPassword = Get-VstsInput -Name nugetPassword
$nugetUseProxy = Get-VstsInput -Name nugetUseProxy -AsBool
$psFeed = Get-VstsInput -Name psFeed -Require
$psSource = Get-VstsInput -Name psSource
$psUsername = Get-VstsInput -Name psUsername
$psPassword = Get-VstsInput -Name psPassword
$psUseProxy = Get-VstsInput -Name psUseProxy -AsBool
$coreToolsVersion = Get-VstsInput -Name coreToolsVersion
$crmConnectorVersion = Get-VstsInput -Name crmConnectorVersion
$packageDeploymentVersion = Get-VstsInput -Name packageDeploymentVersion
$onlineAPIVersion = Get-VstsInput -Name onlineAPIVersion
$checkerVersion = Get-VstsInput -Name checkerVersion
$configMigrationVersion = Get-VstsInput -Name configMigrationVersion
$powerAppsAdminVersion = Get-VstsInput -Name powerAppsAdminVersion
$powerAppsVersion = Get-VstsInput -Name powerAppsVersion
$powerAppsCLIVersion = Get-VstsInput -Name powerAppsCLIVersion
$msalPSVersion = Get-VstsInput -Name msalPSVersion
$mgUsersVersion = Get-VstsInput -Name mgUsersVersion
$mgGroupsVersion = Get-VstsInput -Name mgGroupsVersion

#Script Location
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
Write-Verbose "Script Path: $scriptPath"
Write-Verbose "env VSTS_TOOLS_PATH: $env:VSTS_TOOLS_PATH"
Write-Verbose "env AGENT_TOOLSDIRECTORY: $env:AGENT_TOOLSDIRECTORY"
Write-Verbose "env AGENT_WORKFOLDER: $env:AGENT_WORKFOLDER"
Write-Verbose "env AGENT_TEMPDIRECTORY: $env:AGENT_TEMPDIRECTORY"
Write-Verbose "env TEMP: $env:TEMP"

#Tool Directory
if ($env:AGENT_TOOLSDIRECTORY)
{
	$toolPath = $env:AGENT_TOOLSDIRECTORY
}
elseif ($env:VSTS_TOOLS_PATH)
{
	$toolPath = $env:VSTS_TOOLS_PATH
}
else
{
	$toolPath = $env:AGENT_WORKFOLDER + "\tools"
}
Write-Host "Using Tools Path: $toolPath"

$frameworkCache = $toolPath + "\MSCRMBuildTools"
Write-Verbose "Framework Cache: $frameworkCache"

$taskVersion = $(ConvertFrom-Json (Get-Content -Path .\task.json -Raw)).Version
$taskFullVersion = "$($taskVersion.Major).$($taskVersion.Minor).$($taskVersion.Patch)"

Write-Verbose "Current Task Version: $taskFullVersion"

$currentVersion = $($taskVersion.Major)
$currentVersionPath = "$frameworkCache\$taskFullVersion"

Write-Host "Tools Directory: $currentVersionPath"

Write-Host "##vso[task.setvariable variable=MSCRM_Tools_Path]$currentVersionPath"
$env:MSCRM_Tools_Path = $currentVersionPath
Write-Host "##vso[task.setvariable variable=MSCRM_Tools_Task_Version]$currentVersion"

if (Test-Path $frameworkCache)
{
	Write-Verbose "$frameworkCache already created"
}
else
{
	New-Item "$frameworkCache" -ItemType directory | Out-Null
}

if (Test-Path $currentVersionPath)
{
	Write-Verbose "$currentVersion already cached" | Out-Null
}
else
{
	New-Item "$currentVersionPath" -ItemType directory | Out-Null
	Copy-Item -Path "$scriptPath\Lib\**" -Destination $currentVersionPath -Force -Recurse

	Write-Verbose "Lib Copy completed"
}

."$scriptPath\MSCRMToolsFunctions.ps1"

#Temp Directory
if ($env:AGENT_TEMPDIRECTORY)
{
	$tempDir = $env:AGENT_TEMPDIRECTORY
}
else
{
	$tempDir = $env:TEMP
}
$tempDir =  "$tempDir\$(New-Guid)"
New-Item $tempDir -ItemType directory | Out-Null
Write-Verbose "Using Temp Directory: $tempDir"

#Nuget Path
$nugetPath = "$currentVersionPath\Nuget\4.9.4\nuget.exe"
$nugetConfigPath = "$tempDir\nuget.config"
$psConfigPath = "$tempDir\ps.nuget.config"

Copy-Item -Path "$scriptPath\*nuget.config" -Destination "$tempDir"
Copy-Item -Path "$scriptPath\Tools.json" -Destination "$currentVersionPath" -Force
Copy-Item -Path "$scriptPath\MSCRMToolsFunctions.ps1" -Destination "$currentVersionPath" -Force

#Proxy

if ($nugetUseProxy)
{
	Write-Verbose "Attempting to use agent proxy settings for nuget feed"

	$nugetProxyUrl = $env:AGENT_PROXYURL
	$nugetProxyUsername = $env:AGENT_PROXYUSERNAME
	$nugetProxyPassword = $env:AGENT_PROXYPASSWORD
}
else
{
	Write-Verbose "Skipping using agent proxy settings for nuget feed"
}

if ($psUseProxy)
{
	Write-Verbose "Attempting to use agent proxy settings for powershell gallery feed"

	$psProxyUrl = $env:AGENT_PROXYURL
	$psProxyUsername = $env:AGENT_PROXYUSERNAME
	$psProxyPassword = $env:AGENT_PROXYPASSWORD
}
else
{
	Write-Verbose "Skipping using agent proxy settings for powershell gallery feed"
}

#Nuget Feed
if ($nugetFeed -eq 'official')
{
	Write-Verbose "Using offical Nuget source"

	$nugetSource = 'https://api.nuget.org/v3/index.json'
	$nugetUsername = ''
	$nugetPassword = ''
}
elseif ($nugetFeed -eq 'custom')
{
	Write-Verbose "Using custom Nuget source"
}
else
{
	throw "Unknown nuget source: $nugetFeed"
}

$params = @{
	nugetPath = "$nugetPath"
	nugetConfigPath = "$nugetConfigPath"
	sourceName = "Nuget"
	source = "$nugetSource"
	username = "$nugetUsername"
	password = "$nugetPassword"
	nugetProxyUrl = "$nugetProxyUrl"
	nugetProxyUsername = "$nugetProxyUsername"
	nugetProxyPassword = "$nugetProxyPassword"
}

Configure-Nuget @params

#PowerShell Gallery Feed
if ($psFeed -eq 'official')
{
	Write-Verbose "Using offical PowerShell Gallery source"

	$psSource = 'https://www.powershellgallery.com/api/v2'
	$psUsername = ''
	$psPassword = ''
}
elseif ($psFeed -eq 'custom')
{
	Write-Verbose "Using custom PowerShell Gallery source"
}
else
{
	throw "Unknown PowerShell Gallery source: $psFeed"
}

$params = @{
	nugetPath = "$nugetPath"
	nugetConfigPath = "$psConfigPath"
	sourceName = "PowerShell Gallery"
	source = "$psSource"
	username = "$psUsername"
	password = "$psPassword"
	nugetProxyUrl = "$psProxyUrl"
	nugetProxyUsername = "$psProxyUsername"
	nugetProxyPassword = "$psProxyPassword"
}

Configure-Nuget @params

Write-Host "##vso[task.setvariable variable=$nugetConfigVariable]$nugetConfigPath"
Write-Host "##vso[task.setvariable variable=$psConfigVariable]$psConfigPath"

$env:MSCRM_Tools_NugetConfig_Path = $nugetConfigPath
$env:MSCRM_Tools_PSGalleryConfig_Path = $psConfigPath

Set-MSCRMToolVersionVariable -toolName 'Microsoft.CrmSdk.CoreTools' -version $coreToolsVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.Xrm.Tooling.CrmConnector.PowerShell' -version $crmConnectorVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.Xrm.Tooling.PackageDeployment.Powershell' -version $packageDeploymentVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.Xrm.OnlineManagementAPI' -version $onlineAPIVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.PowerApps.Checker.PowerShell' -version $checkerVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.Xrm.Tooling.ConfigurationMigration' -version $configMigrationVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.PowerApps.Administration.PowerShell' -version $powerAppsAdminVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.PowerApps.PowerShell' -version $powerAppsVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.PowerApps.CLI' -version $powerAppsCLIVersion
Set-MSCRMToolVersionVariable -toolName 'MSAL.PS' -version $msalPSVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.Graph.Users' -version $mgUsersVersion
Set-MSCRMToolVersionVariable -toolName 'Microsoft.Graph.Groups' -version $mgGroupsVersion


Write-Verbose 'Leaving MSCRMToolInstaller.ps1'