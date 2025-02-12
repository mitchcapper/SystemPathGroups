Import-Module Pester
Set-Location -Path $PSScriptRoot

# Use same configuration as GitHub Actions workflow
$config = New-PesterConfiguration
$config.Run.Path = './SystemPathGroups.Tests.ps1'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = "$PSScriptRoot\..\test-results.xml"
$config.TestResult.OutputFormat = "JUnitXml"
$config.Output.Verbosity = "Detailed"

Invoke-Pester -Configuration $config