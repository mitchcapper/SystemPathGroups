param(
    [Parameter(Mandatory=$false)]
    [string]$ModulePath = "$PSScriptRoot\SystemPathGroups",
    [Parameter(Mandatory=$false)]
    [string]$ReadmeInPath = "$PSScriptRoot\README.md.in",
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "$PSScriptRoot\README.md"
)

# Import the module to get documentation
Import-Module $ModulePath -Force -Verbose

# Read the template
$readmeContent = Get-Content $ReadmeInPath -Raw

# Get all exported commands and sort them with Add-ToPath first
$commands = Get-Command -Module SystemPathGroups | Sort-Object { 
    if ($_.Name -eq 'Add-ToPath') { 
        '0' + $_.Name 
    } else { 
        '1' + $_.Name 
    }
}

# Build Usage section
$usageContent = @"

## Cmdlet Reference

"@

# Build TOC entries for cmdlets
$tocEntries = @()
$seenAnchors = @{}  # Track seen anchor IDs and their count

function Get-AnchorId {
    param([string]$text)
    $anchor = $text.ToLower() -replace ' ','-'
    if ($seenAnchors.ContainsKey($anchor)) {
        $seenAnchors[$anchor]++
        return "$anchor-$($seenAnchors[$anchor])"
    } else {
        $seenAnchors[$anchor] = 0
        return $anchor
    }
}

foreach ($command in $commands) {
    $help = Get-Help $command.Name -Full
    # Add main command entry with deeper indentation
    $commandAnchor = Get-AnchorId $command.Name
    $tocEntries += "    - [$($command.Name)](#$commandAnchor)"
    
    # Add sub-sections with proper indentation and anchor names
    $syntaxAnchor = Get-AnchorId "syntax"
    $tocEntries += "        - [Syntax](#$syntaxAnchor)"
    if ($help.Description) {
        $descAnchor = Get-AnchorId "description"
        $tocEntries += "        - [Description](#$descAnchor)"
    }
    if ($help.Parameters.Parameter) {
        $paramsAnchor = Get-AnchorId "parameters"
        $tocEntries += "        - [Parameters](#$paramsAnchor)"
    }
    if ($help.Examples) {
        $examplesAnchor = Get-AnchorId "examples"
        $tocEntries += "        - [Examples](#$examplesAnchor)"
        # Add example entries with proper numbering
        $exampleCount = 0
        foreach ($example in $help.Examples.Example) {
            $exampleCount++
            $exampleAnchor = Get-AnchorId "example-$exampleCount"
            $tocEntries += "            - [EXAMPLE $exampleCount](#$exampleAnchor)"
        }
    }
}

# Update the table of contents
$tocPattern = '(?s)(<!-- MarkdownTOC -->.*?<!-- /MarkdownTOC -->)'
$readmeContent = $readmeContent -replace $tocPattern, @"
<!-- MarkdownTOC -->
- [Simple Example](#simple-example)
- [Features](#features)
- [Configuration](#configuration)
- [Installation](#installation)
- [Cmdlet Reference](#cmdlet-reference)
$($tocEntries -join "`n" -replace '    ',"`t")
<!-- /MarkdownTOC -->
"@

foreach ($command in $commands) {
    $help = Get-Help $command.Name -Full
    
    # Add command name and synopsis
    $usageContent += @"

### $($command.Name)

$($help.Synopsis)

#### Syntax

``````powershell
$($help.Syntax.SyntaxItem.Name)
``````

"@

    # Add description
    if ($help.Description) {
        $usageContent += @"
#### Description

$($help.Description.Text)

"@
    }

    # Add parameters
    if ($help.Parameters.Parameter) {
        $usageContent += @"
#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
"@
        foreach ($param in $help.Parameters.Parameter) {
            $usageContent += "`n|$($param.Name)|$($param.Type.Name)|$($param.Description.Text)|"
        }
        $usageContent += "`n`n"
    }

    # Add examples
    if ($help.Examples) {
        $usageContent += @"
#### Examples

"@
        $exampleCount = 0
        foreach ($example in $help.Examples.Example) {
            $exampleCount++
            $usageContent += @"
##### EXAMPLE $exampleCount
``````powershell
$($example.Code.Trim())
``````
$($example.Remarks.Text.Trim())
"@
            if ($example -ne $help.Examples.Example[-1]) {
                $usageContent += "`n`n"
            }
        }
        $usageContent += "`n"
    }
}

# Clean up any remaining extra whitespace
$usageContent = $usageContent -replace '\s+$', ''

# Replace the Usage section placeholder
$readmeContent = $readmeContent -replace "## Usage.*$", $usageContent

# Write the combined content
$readmeContent | Set-Content $OutputPath -Encoding UTF8

Write-Host "README.md has been generated at: $OutputPath"