# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "55-TestModularStructure.ps1"

# Initialize test environment
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"

Write-Host "Minecraft Mod Manager - Modular Structure Tests" -ForegroundColor $Colors.Header
Write-Host "===============================================" -ForegroundColor $Colors.Header

# Test 1: Import modular functions
Write-TestHeader "Testing Modular Function Imports"
$importResult = Test-Command {
    . "$PSScriptRoot\..\..\src\Import-Modules.ps1"
    return $true
} "Import modular functions"
Write-TestResult "Import modular functions" $importResult

# Test 2: Test Core Environment functions
Write-TestHeader "Testing Core Environment Functions"
$envResult = Test-Command {
    Load-EnvironmentVariables
    return $true
} "Load environment variables"
Write-TestResult "Load environment variables" $envResult

# Test 3: Test Core Paths functions
Write-TestHeader "Testing Core Paths Functions"
$pathResult = Test-Command {
    $effectivePath = Get-EffectiveModListPath -DatabaseFile "test.csv" -ModListFile "mods.csv"
    return $effectivePath -eq "test.csv"
} "Get effective modlist path"
Write-TestResult "Get effective modlist path" $pathResult

# Test 4: Test File functions
Write-TestHeader "Testing File Functions"
$fileResult = Test-Command {
    $cleanName = Clean-Filename -Name "mod:api?*"
    return $cleanName -eq "mod_api___"
} "Clean filename"
Write-TestResult "Clean filename" $fileResult

# Test 5: Test Data Version functions
Write-TestHeader "Testing Data Version Functions"
$versionResult = Test-Command {
    $normalized = Normalize-Version -Version "1.21.5"
    return $normalized -eq "1.21.5"
} "Normalize version"
Write-TestResult "Normalize version" $versionResult

# Test 6: Test Data Utility functions
Write-TestHeader "Testing Data Utility Functions"
$utilityResult = Test-Command {
    $deps = @(
        @{ project_id = "mod1"; dependency_type = "required" },
        @{ project_id = "mod2"; dependency_type = "optional" }
    )
    $result = Convert-DependenciesToJson -Dependencies $deps
    return $result -like "*required: mod1*" -and $result -like "*optional: mod2*"
} "Convert dependencies to JSON"
Write-TestResult "Convert dependencies to JSON" $utilityResult

# Test 7: Test Provider functions (basic structure)
Write-TestHeader "Testing Provider Function Structure"
$providerResult = Test-Command {
    # Test that provider functions exist
    $functions = @(
        "Get-ModrinthProjectInfo",
        "Validate-ModrinthModVersion",
        "Get-CurseForgeProjectInfo",
        "Get-CurseForgeFileInfo",
        "Validate-CurseForgeModVersion",
        "Get-MojangServerInfo",
        "Get-FabricLoaderInfo"
    )
    
    $allExist = $true
    foreach ($func in $functions) {
        if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
            $allExist = $false
            break
        }
    }
    return $allExist
} "Provider functions exist"
Write-TestResult "Provider functions exist" $providerResult

# Summary
Show-TestSummary "Modular Structure Tests"

# Always execute tests when this file is run
Invoke-TestModularStructure -TestFileName $TestFileName 