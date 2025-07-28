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

# Import modules first (outside of Test-Command)
Write-TestHeader "Testing Modular Function Imports"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$importPath = Join-Path $projectRoot "src\Import-Modules.ps1"
try {
    . $importPath
    Write-TestResult "Import modular functions" $true
} catch {
    Write-TestResult "Import modular functions" $false "Failed to import: $($_.Exception.Message)"
}

# Test 2: Test Core Environment functions
Write-TestHeader "Testing Core Environment Functions"
try {
    Load-EnvironmentVariables
    Write-TestResult "Load environment variables" $true
} catch {
    Write-TestResult "Load environment variables" $false "Failed to load: $($_.Exception.Message)"
}

# Test 3: Test Core Paths functions
Write-TestHeader "Testing Core Paths Functions"
try {
    $effectivePath = Get-EffectiveModListPath -DatabaseFile "test.csv" -ModListFile "mods.csv"
    $result = $effectivePath -eq "test.csv"
    Write-TestResult "Get effective modlist path" $result
} catch {
    Write-TestResult "Get effective modlist path" $false "Failed to get path: $($_.Exception.Message)"
}

# Test 4: Test File functions
Write-TestHeader "Testing File Functions"
try {
    $cleanName = Clean-Filename -Name "mod:api?*"
    $result = $cleanName -eq "mod_api__"
    Write-TestResult "Clean filename" $result
} catch {
    Write-TestResult "Clean filename" $false "Failed to clean filename: $($_.Exception.Message)"
}

# Test 5: Test Data Version functions
Write-TestHeader "Testing Data Version Functions"
try {
    $normalized = Normalize-Version -Version "1.21.5"
    $result = $normalized -eq "1.21.5"
    Write-TestResult "Normalize version" $result
} catch {
    Write-TestResult "Normalize version" $false "Failed to normalize version: $($_.Exception.Message)"
}

# Test 6: Test Data Utility functions
Write-TestHeader "Testing Data Utility Functions"
try {
    $deps = @(
        @{ project_id = "mod1"; dependency_type = "required" },
        @{ project_id = "mod2"; dependency_type = "optional" }
    )
    $result = Convert-DependenciesToJson -Dependencies $deps
    $success = $result -like "*required: mod1*" -and $result -like "*optional: mod2*"
    Write-TestResult "Convert dependencies to JSON" $success
} catch {
    Write-TestResult "Convert dependencies to JSON" $false "Failed to convert dependencies: $($_.Exception.Message)"
}

# Test 7: Test Provider functions (basic structure)
Write-TestHeader "Testing Provider Function Structure"
try {
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
    Write-TestResult "Provider functions exist" $allExist
} catch {
    Write-TestResult "Provider functions exist" $false "Failed to check provider functions: $($_.Exception.Message)"
}

# Summary
Show-TestSummary "Modular Structure Tests" 