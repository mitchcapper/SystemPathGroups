Import-Module Pester
Set-Location -Path $PSScriptRoot
Invoke-Pester './SystemPathGroups.Tests.ps1' -Output Detailed