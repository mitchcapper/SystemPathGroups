Import-Module Pester
Set-Location -Path $PSScriptRoot
Invoke-Pester -Script './SystemPathGroups.Tests.ps1'