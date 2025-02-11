Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";

# Configuration variables
$script:PathsFile = "$env:ProgramData\SystemPathGroups\paths.json"
$script:EnvTarget = [System.EnvironmentVariableTarget]::Machine
$script:EnvVar = "Path"

function Add-ToPath {
	<#
	.SYNOPSIS
	Adds a new path to both to the known paths configuration and optionally to the system path (true by default).

	.DESCRIPTION
	This function adds a specified path to the paths configuration file with an associated path group. 
	If AddToSystemPath is true (default), also adds the path to the system path.
	If AddToSystemPath is false, the path will only be saved to the configuration file.

	.PARAMETER PathGroup
	The group name to associate with the path in the configuration file.

	.PARAMETER NewPath
	The file system path to add.

	.PARAMETER AddToSystemPath
	Optional. If true (default), adds the path to system path. If false, only stores in config.

	.EXAMPLE
	Add-ToPath "DevTools" "C:\Tools\bin"
	
	Adds C:\Tools\bin to the system path and associates it with the "DevTools" group.

	.EXAMPLE
	Add-ToPath -PathGroup "DevTools" -NewPath "C:\Tools\bin"
	
	Same as above using named parameters.

	.EXAMPLE
	Add-ToPath "DevTools" "C:\Tools\bin" $false
	
	Only adds C:\Tools\bin to the configuration file without modifying the system path.

	.EXAMPLE
	Add-ToPath -PathGroup "DevTools" -NewPath "C:\Tools\bin" -AddToSystemPath $false
	
	Same as above using named parameters.
	#>
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$PathGroup,
		[Parameter(Mandatory = $true, Position = 1)]
		[string]$NewPath,
		[Parameter(Mandatory = $false, Position = 2)]
		[bool]$AddToSystemPath = $true
	)
	if ($AddToSystemPath) {
		Add-ToSystemPath -Paths $NewPath
	}
	Save-PathToJson -Path $NewPath -PathGroup $PathGroup
}

function Remove-PathGroupsFromPath {
	<#
	.SYNOPSIS
	Removes paths associated with specified path groups from the system path.

	.DESCRIPTION
	This function removes paths from the system path environment variable based on their associated path groups.
	If no path groups are specified, all paths from the configuration will be removed.

	.PARAMETER PathGroups
	An optional array of path group names. If specified, only paths associated with these groups will be removed.
	If not specified, all paths from the configuration will be removed. Can be specified as multiple arguments.

	.EXAMPLE
	Remove-PathGroupsFromPath "DevTools","TestTools"
	
	Removes all paths associated with the "DevTools" and "TestTools" groups from the system path.

	.EXAMPLE
	Remove-PathGroupsFromPath "DevTools" "TestTools"
	
	Same as above, but using multiple arguments instead of an array.

	.EXAMPLE
	Remove-PathGroupsFromPath
	
	Removes all paths from the system path that are defined in the configuration file.
	#>
	param(
		[Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments = $true)]
		[string[]]$PathGroups
	)

	$pathsDict = Get-PathDict -ThrowIfNotFound $true
	if ($PathGroups -and $PathGroups.Count -gt 0) {
		$existingGroups = $pathsDict.Values | Select-Object -Unique
		$nonExistentGroups = $PathGroups | Where-Object { $_ -notin $existingGroups }
		if ($nonExistentGroups) {
			throw "Path groups not found: $($nonExistentGroups -join ', ')"
		}
		$pathsToRemove = $pathsDict.Keys | Where-Object { $PathGroups -contains $pathsDict[$_] }
	}
	else {
		$pathsToRemove = $pathsDict.Keys
	}
	if (-not $pathsToRemove) { return }
	Remove-FromSystemPath -Paths $pathsToRemove
}

function Add-PathGroupsToPath {
	<#
    .SYNOPSIS
    Adds paths associated with specified path groups to the system path.

    .DESCRIPTION
    This function adds paths to the system path environment variable based on their associated path groups
    from the paths configuration file. If no path groups are specified, all paths from the configuration will be added.

    .PARAMETER PathGroups
    An optional array of path group names. If specified, only paths associated with these groups will be added.
    If not specified, all paths from the configuration will be added.

    .EXAMPLE
    Add-PathGroupsToPath -PathGroups "DevTools","TestTools"
    
    Adds all paths associated with the "DevTools" and "TestTools" groups to the system path.

    .EXAMPLE
    Add-PathGroupsToPath
    
    Adds all paths from the configuration file to the system path.
    #>
	param(
		[Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments = $true)]
		[string[]]$PathGroups
	)
    
	$pathsDict = Get-PathDict -ThrowIfNotFound $true
	$pathsToAdd = @()
	if ($PathGroups -and $PathGroups.Count -gt 0) {
		$pathsToAdd = $pathsDict.Keys | Where-Object { $PathGroups -contains $pathsDict[$_] }
	}
	else {
		$pathsToAdd = $pathsDict.Keys
	}
	Add-ToSystemPath -Paths $pathsToAdd
}

function Save-PathToJson {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,
		[Parameter(Mandatory = $true)]
		[string]$PathGroup
	)
	$pathsDict = Get-PathDict
	$pathsDict[$Path.ToLower()] = $PathGroup
	$directory = Split-Path -Path $script:PathsFile -Parent
	if (-not (Test-Path $directory)) {
		New-Item -ItemType Directory -Path $directory -Force | Out-Null
	}
	$pathsDict | ConvertTo-Json | Set-Content $script:PathsFile
}

function Get-PathDict {
	param(
		[Parameter(Mandatory = $false)]
		[bool]$ThrowIfNotFound = $false
	)
	$pathsDict = @{}
	if (-not (Test-Path $script:PathsFile)) {
		if ($ThrowIfNotFound) {
			throw "Paths configuration file not found at: $script:PathsFile"
		}
	}
	else {
		try {
			$pathsDict = Get-Content $script:PathsFile | ConvertFrom-Json -AsHashtable
		}
		catch {
			Write-Error "Failed to parse paths configuration file: $_"
		}
	}
	return $pathsDict
}

function Add-ToSystemPath {
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Paths
	)
	$currentPath = [Environment]::GetEnvironmentVariable($script:EnvVar, $script:EnvTarget).Replace('/', '\')
	$pathChanged = $false
	foreach ($path in $Paths) {
		$normalizedPath = $path.Replace('/', '\')
		if (-not ($currentPath.Split(';') -contains $normalizedPath)) {
			$currentPath = $currentPath + ";" + $normalizedPath
			$pathChanged = $true
		}
	}
	if ($pathChanged) {
		[Environment]::SetEnvironmentVariable($script:EnvVar, $currentPath, $script:EnvTarget)
	}
}

function Remove-FromSystemPath {
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Paths
	)
	if (-not $Paths) { return }
	$currentPath = [Environment]::GetEnvironmentVariable($script:EnvVar, $script:EnvTarget).Replace('/', '\')
	$pathsArray = $currentPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
	$pathChanged = $false

	foreach ($path in $Paths) {
		$normalizedPath = $path.Replace('/', '\')
		if ($pathsArray -contains $normalizedPath) {
			$pathsArray = $pathsArray | Where-Object { $_ -ne $normalizedPath }
			$pathChanged = $true
		}
	}

	if ($pathChanged) {
		$newPath = $pathsArray -join ';'
		[Environment]::SetEnvironmentVariable($script:EnvVar, $newPath, $script:EnvTarget)
	}
}
Export-ModuleMember -Function Add-PathGroupsToPath, Remove-PathGroupsFromPath, Add-ToPath