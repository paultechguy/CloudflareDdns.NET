# create app release (car)
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("windows", "linux")]
    [string]$platform,

    [Parameter(Mandatory=$true)]
    [string]$output
)

function WriteLineDelimiter {
    param (
        [char]$char,

        [int]$length,

        [string]$color
    )

    Write-Host ($char.ToString() * $length) -ForegroundColor $color
}

function WriteMessage {
    param (
        [string]$message,

        [bool]$bracketed = $false,

        [string]$color = 'Black'
    )

    if ($bracketed) {
        WriteLineDelimiter '-' 80 $color
    }

    if ($message) {
        Write-Host "$message" -ForegroundColor $color
    }

    if ($bracketed) {
        WriteLineDelimiter '-' 80 $color
    }
}

function WriteInfo {
    param (
        [string]$message,

        [bool]$bracketed = $false,

        [string]$color = 'Cyan'
    )

    WriteMessage -message $message -color 'Cyan' -bracketed $bracketed
}

function WriteError {
    param (
        [string]$message,

        [bool]$bracketed = $false
    )

    WriteMessage -message $message -color 'Red' -bracketed $bracketed
}

function GetApplicationVersion {
    param (
        [Parameter(Mandatory=$true)]
        [string]$path
    )

    if (!(Test-Path $path)) {
        Write-Error "File not found: $path"

        return $null
    }

    [xml]$xmlContent = Get-Content -Path $path

    $versionNode = $xmlContent.Project.PropertyGroup.Version

    if ($versionNode) {
        return $versionNode
    }
    else {
        return $null
    }
}

function UpdateTimestamps {
    param (
        [string]$directoryPath,

        [System.DateTime]$newDate
    )

    try {
        # recursively update timestamps for files and directories
        Get-ChildItem -Path $directoryPath -Recurse | ForEach-Object {
            $_.CreationTime = $newDate
            $_.LastWriteTime = $newDate
            $_.LastAccessTime = $newDate
        }
    }
    catch {
        WriteError "Error updating timestamps: $_"
        exit 1
    }
}

function GetMainAppDirectory {
    $mainAppName = 'DdnsUpdate.Application'
    $path = [IO.Path]::Combine($slnDirectory, $mainAppName)

    return $path
}

function GetMainAppProjectPath {
    $mainAppName = 'DdnsUpdate.Application'
    $appDir = GetMainAppDirectory
    $slnProjectPath = [IO.Path]::Combine($slnDirectory, $appDir, "$mainAppName.csproj")

    return $slnProjectPath
}

function GetMainAppPublishLocation {
    $appDir = GetMainAppDirectory
    $pubLocation = [IO.Path]::Combine($rootDirectory, $appDir, 'bin', 'release', 'net8.0', 'publish', $architecture)

    return $pubLocation
}

function BuildPlugins {
    $pluginProjects = @('PaulTechGuy.Cloudflare', 'PaulTechGuy.EmailOnly')
    foreach ($project in $pluginProjects) {
        $pluginProjectPath = [IO.Path]::Combine($rootDirectory, 'src', 'plugins', $project, "$project.csproj")
        WriteInfo "Building $pluginProjectPath..." $true

        dotnet clean $pluginProjectPath -c Release
        dotnet build $pluginProjectPath -c Release
    }
}

function BuildMainApp {
    WriteInfo "Building main app $slnProjectPath" $true
    $sln = GetMainAppProjectPath

    dotnet clean $sln -c Release
    dotnet build $sln -c Release
}

function PublishMainApp {
    WriteInfo "Publishing main app $slnProjectPath" $true

    switch ($platform) {
        "linux" {
            $publishXmlFileName = "FolderLinuxSingleFileRelease.pubxml"
        }
        "windows" {
            $publishXmlFileName = "FolderWindowsSingleFileRelease.pubxml"
        }
        default {
            WriteError "Invalid `$platform: $platform"
            exit 1
        }
    }

    # get the pubxml file path
    $publishXmlPath = [IO.Path]::Combine($rootDirectory, 'src', 'DdnsApplication', 'Projects', 'PublishProfiles', $publishXmlFileName)
    $sln = GetMainAppProjectPath

    # remove all files from the publish location before we begin
    $pubLocation = GetMainAppPublishLocation
	if (Test-Path -Path $pubLocation -PathType Container) {
        Remove-Item -Recurse -Force $pubLocation
    }

    # publish it
    dotnet publish $sln -c Release /p:PublishProfile=$publishXmlPath

    # final lil' task...let's set the last modified date on everything in the publish location
    $now = [System.DateTime]::Now
    UpdateTimestamps $pubLocation $now
}

function CreateAppPackage {
    try {
        WriteInfo "Creating main app package for service type $serviceType`nOutput directory: $outputDirectory" $true

        # because the package script writes to the local directory, we
        # move there while we run the script
        Set-Location $outputDirectory

        # get the location where the publish files exist
        $pubLocation = GetMainAppPublishLocation

        # create the script path
        $scriptPath = [IO.Path]::Combine($rootDirectory, 'tools', 'CreateLocalPackage', 'clp.ps1')

        # run the script to create a local package for this architecture/platform
        & $scriptPath $pubLocation $platform $applicationVersion
    }
    finally {
        Set-Location $rootDirectory
    }
}

try {
    # keep things tidy
    Clear-Host

	# remember starting location
	$rootDirectory = Get-Location

    # before we get too far, verify output directory exists
	if (!(Test-Path -Path $output -PathType Container)) {
		WriteError "Unable to find output directory, $output"
		exit 1
    }
    else {
        $outputDirectory = $output
    }
	
	# verify we're in the top-level folder
	$slnFileName = 'DdnsUpdate.sln'
	$slnDirectory = [IO.Path]::Combine($rootDirectory, 'src')
	$slnPath = [IO.Path]::Combine($rootDirectory, 'src', $slnFileName)
	if (!(Test-Path -Path $slnPath -PathType Leaf)) {
		WriteError "Unable to find main app solution file, $slnPath"
		exit 1
    }

    # we need the architecture
    switch ($platform) {
        "windows" {
            $architecture = 'win-x64'
        }
        "linux" {
            $architecture = 'linux-x64'
        }
        default {
            WriteError "Invalid architecture `$platform: $platform"
            exit 1
        }
    }
	
	# we need the version
	$mainAppProjectPath = GetMainAppProjectPath
	$applicationVersion = GetApplicationVersion $mainAppProjectPath

    BuildPlugins

    BuildMainApp

    PublishMainApp

    CreateAppPackage

    WriteInfo "`n"
    WriteMessage -message "`Main application package successfully built" -bracketed $true -color 'Yellow'
}
catch {
    Write-Host $_
    Write-Host $_.ScriptStackTrace
    exit 1
}
finally {
	Set-Location -Path $rootDirectory
}

exit 0
