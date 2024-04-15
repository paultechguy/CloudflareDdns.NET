# This script is executed from the DdnsUpdate.Application project (.csproj)
# when the project is built. The purpose of the script is to copy the
# default plugins into the DdnsUpdate.Application's plugin directory. When
# plugins are modified and the main application is [re]built, it will have
# the latest plugin files to dynamically load.
#
# Note: plugins can be disabled (not loaded) by starting their directory name
# with a '#'. If the script can't locate the normal plugin directory in the
# application plugin directory, it will attept to location the commented-out
# directory and copy the latest plugin files to that location, so the latest
# plugin files will be available if a plugin is uncommented-out.

param(
    [string]$OS,
    [string]$ProjectDir,
    [string]$TargetDir,
    [string]$PublishUrl
)

function EnsurePathEndsWithSlash {
    param (
        [string]$path
    )

    if (-not $path.EndsWith($pathSeparator)) {
        $path += $pathSeparator
    }

    return $path
}

function EnsurePathEndsWithoutSlash {
    param (
        [string]$path
    )

    if ($path.EndsWith($pathSeparator)) {
        $path = $path.Substring(0, $path.Length - 1)
    }

    return $path
}

# OS specific stuff
switch ($OS) {
    "Windows_NT" {
        $pathSeparator = '\'
    }
    "Unix" {
        $pathSeparator = '/'
    }
    default {
        Write-Host "OS not supported: $OS"
    }
}

# invoking from VS build causes extra quotes at end; remove
$ProjectDir = $ProjectDir.Trim('"')
$TargetDir = $TargetDir.Trim('"')

# adjust to remove any ending slashes
$ProjectDir = EnsurePathEndsWithoutSlash $ProjectDir
$TargetDir = EnsurePathEndsWithoutSlash $TargetDir

#Write-Host "ProjectDir: $ProjectDir"
#Write-Host "TargetDir: $TargetDir"

# define the default plugins; these names need to match the directory
# names of the plugin projects
$pluginNames = @('PaulTechGuy.Cloudflare', 'PaulTechGuy.EmailOnly')

# for each plugin, set the source and destination copy paths
$pluginNames | ForEach-Object {
    $sourcePath = $TargetDir.Replace('DdnsUpdate.Application', "plugins$pathSeparator$_")
    $sourcePath = Split-Path -Parent $sourcePath
    $destPath = $TargetDir + "$($pathSeparator)plugins$($pathSeparator)$_$($pathSeparator)"
    write-host "TargetDir: $TargetDir"
    write-host "SourcePath: $sourcePath"
    write-host "DestPath: $destPath"
    #exit 1

    # adjust if dest is commented out
    if (-not (Test-Path -Path $destPath -PathType Container)) {
        $commentedDestPath = EnsurePathEndsWithSlash "$($TargetDir)$($pathSeparator)plugins$($pathSeparator)#$_"
        if (Test-Path -Path $commentedDestPath) {
            $destPath = $commentedDestPath
        }
    }

     # create the destination folder if it doesn't exist yet
    if (-not (Test-Path -Path $destPath -PathType Container)) {
        New-Item -Path $destPath -ItemType "directory"
    }

    # if both source and destination directories exist, copy the plugin
    # files from source to the application plugins directory
    if ((Test-Path -Path $sourcePath -PathType Container) -and (Test-Path -Path $destPath -PathType Container)) {
        Copy-item -Force -Recurse "$($sourcePath)$pathSeparator*" -Destination $destPath
    }
    else {
        Write-Host "sourcePath: $sourcePath"
        Write-Host "destPath: $destPath"
        Write-Host "Missing either source and/or dest directories"
        exit 1
    }
}

Write-Host 'Default plugins have been copied to the main application "plugins" directory.'

exit 0