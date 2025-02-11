Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
Import-Module -Name "$PSScriptRoot\..\SystemPathGroups" -Verbose -Force

InModuleScope SystemPathGroups {
    BeforeAll {
    
        $script:PathsFile = Join-Path ([System.IO.Path]::GetTempPath()) "SystemPathGroups_test.json"
        $script:EnvTarget = [System.EnvironmentVariableTarget]::Process
        $script:EnvVar = "PathTest"
        [Environment]::SetEnvironmentVariable($script:EnvVar, "c:\windows\system32\;c:\users\some\domain\is;c:\users\bob\.cargo\bin;c:\windows", $script:EnvTarget)
        Function TestPathContains($checkPath, $shouldContain = $true) {
            $currentPath = [Environment]::GetEnvironmentVariable($script:EnvVar, $script:EnvTarget).Replace('/', '\')

            #Write-Host "check path: $checkPath and should contain: $shouldContain"
            $checkPath = $checkPath.Replace('/', '\')
            if ($shouldContain) {
                $currentPath.Split(';') | Should -Contain $checkPath
            }
            else {
                $currentPath.Split(';') | Should -Not -Contain $checkPath
            }
        }
    }


    Describe "Path Tests" {
        BeforeAll {

            # Clear paths.json if it exists
            if (Test-Path $script:pathsFile) {
                Remove-Item $script:pathsFile -Force
            }
        }
 
        Context "Add-ToPath Tests" {
            BeforeEach {
                if (Test-Path $script:PathsFile) {
                    Remove-Item $script:PathsFile -Force
                }
            }

            It "Should add a new path to system PATH and paths.json" {
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev"
                $pathsDict = Get-PathDict
                $pathsDict["c:\dev"] | Should -Be "dev"
                TestPathContains "c:\dev"
            }

            It "Should handle multiple paths for the same group" {
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev"
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev\tools"
                $pathsDict = Get-PathDict
                $pathsDict["c:\dev"] | Should -Be "dev"
                $pathsDict["c:\dev\tools"] | Should -Be "dev"
            }
            It "Should handle paths with forward slashes" {
                Add-ToPath -PathGroup "dev" -NewPath "c:/dev/forward/slash"
                TestPathContains "c:\dev\forward\slash"
            }
    
            It "Should handle duplicate path additions" {
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev"
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev"
                $pathsDict = Get-PathDict
                $pathsDict.Keys.Count | Should -Be 1
            }

            It "Should add a new path to system PATH and paths.json when AddToSystemPath is true (default)" {
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev"
                $pathsDict = Get-PathDict
                $pathsDict["c:\dev"] | Should -Be "dev"
                TestPathContains "c:\dev"
            }

            It "Should only add path to paths.json when AddToSystemPath is false" {
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev\special" -AddToSystemPath $false
                $pathsDict = Get-PathDict
                $pathsDict["c:\dev\special"] | Should -Be "dev"
                TestPathContains "c:\dev\special" $false
            }

            It "Should support positional parameters for required args" {
                Add-ToPath "dev" "c:\dev\positional"
                $pathsDict = Get-PathDict
                $pathsDict["c:\dev\positional"] | Should -Be "dev"
                TestPathContains "c:\dev\positional"
            }

            It "Should support positional parameters including optional arg" {
                Add-ToPath "dev" "c:\dev\positional2" $false
                $pathsDict = Get-PathDict
                $pathsDict["c:\dev\positional2"] | Should -Be "dev"
                TestPathContains "c:\dev\positional2" $false
            }

            It "Should support mixing positional and named parameters" {
                Add-ToPath "dev" -NewPath "c:\dev\mixed" -AddToSystemPath $false
                $pathsDict = Get-PathDict
                $pathsDict["c:\dev\mixed"] | Should -Be "dev"
                TestPathContains "c:\dev\mixed" $false
            }
        }

        Context "Remove-PathGroupsFromPath Tests" {
            BeforeEach {
                if (Test-Path $script:PathsFile) {
                    Remove-Item $script:PathsFile -Force
                }
                # Add some test paths
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev"
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev\tools"
                Add-ToPath -PathGroup "python" -NewPath "c:\python39"
            }

        
            It "Should remove all paths in specified path group" {
                Remove-PathGroupsFromPath -PathGroups @("dev")
                TestPathContains "c:\dev" $false 
                TestPathContains "c:\dev\tools" $false
                TestPathContains "c:\python39" $true
            }
            It "Should be able to remove multiple groups at once" {
                Remove-PathGroupsFromPath "dev" "python"
                TestPathContains "c:\dev" $false 
                TestPathContains "c:\dev\tools" $false
                TestPathContains "c:\python39" $false
            }

            It "Should throw error on invalid path group" {
                {
                    Remove-PathGroupsFromPath -PathGroups @("InvalidGroup")
                } | Should -Throw
            }
            It "Should remove all paths when no groups specified" {
                Remove-PathGroupsFromPath
                TestPathContains "c:\dev" $false
                TestPathContains "c:\python39" $false
            }
            It "Should handle removal of non-existent paths" {
                Remove-FromSystemPath -Paths @("non-existent-group")
                # Should not throw and PATH should remain unchanged
                TestPathContains "c:\python39" $true
            }        
        }

        Context "Add-PathGroupsToPath Tests" {
            BeforeEach {
                if (Test-Path $script:PathsFile) {
                    Remove-Item $script:PathsFile -Force
                }
                # Set up initial paths
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev"
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev\tools"
                Add-ToPath -PathGroup "python" -NewPath "c:\python39"
                # Remove all paths first
                Remove-PathGroupsFromPath
            }

            It "Should add all paths for specified group" {
                Add-PathGroupsToPath -PathGroups @("dev")
            
                TestPathContains "c:\dev" $true
                TestPathContains "c:\dev\tools" $true
                TestPathContains "c:\python39" $false
            }

            It "Should add paths for specified groups" {
                Add-PathGroupsToPath -PathGroups @("dev")
            
                TestPathContains "c:\dev"
                TestPathContains "c:\python349" $false
            }

            It "Should handle multiple groups" {
                Add-PathGroupsToPath -PathGroups @("dev", "python")
                TestPathContains "c:\dev"
                TestPathContains "c:\python39"
            }

            It "Should throw when paths.json doesn't exist" {
                Remove-Item $script:PathsFile -Force
                { Add-PathGroupsToPath -PathGroups @("dev") } | Should -Throw
            }
            It "Should handle empty PathGroups array" {
                Add-PathGroupsToPath -PathGroups @()
                TestPathContains "c:\dev" $true
                TestPathContains "c:\python39" $true
            }
        }

        Context "Get-PathDict Tests" {
            BeforeEach {
                if (Test-Path $script:PathsFile) {
                    Remove-Item $script:PathsFile -Force
                }
            }

            It "Should return empty hashtable when file doesn't exist and ThrowIfNotFound is false" {
                $result = Get-PathDict
                $result | Should -BeOfType [Hashtable]
                $result.Count | Should -Be 0
            }

            It "Should throw when file doesn't exist and ThrowIfNotFound is true" {
                { Get-PathDict -ThrowIfNotFound $true } | Should -Throw
            }

            It "Should return correct paths after adding entries" {
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev"
                $result = Get-PathDict
                $result["c:\dev"] | Should -Be "dev"
            }
        }

        Context "Path Validation Tests" {
            BeforeEach {
                if (Test-Path $script:PathsFile) {
                    Remove-Item $script:PathsFile -Force
                }
            }
    
            It "Should preserve path case in environment" {
                Add-ToPath -PathGroup "dev" -NewPath "C:\Program Files\MyApp"
                $currentPath = [Environment]::GetEnvironmentVariable($script:EnvVar, $script:EnvTarget)
                $currentPath | Should -Match "C:\\Program Files\\MyApp"
            }
    
            It "Should handle paths with spaces" {
                Add-ToPath -PathGroup "dev" -NewPath "c:\Program Files\Some Path"
                TestPathContains "c:\Program Files\Some Path"
            }
    
            It "Should handle paths with special characters" {
                Add-ToPath -PathGroup "dev" -NewPath "c:\dev\test(1)"
                TestPathContains "c:\dev\test(1)"
            }
        }
    }
}