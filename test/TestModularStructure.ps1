# =============================================================================
# Modular Structure Test
# =============================================================================
# This script tests the modular structure by importing modules and testing functions.
# =============================================================================

# Import test framework
. "$PSScriptRoot\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "TestModularStructure.ps1"

# Initialize test environment
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to the import script
$ImportScriptPath = Join-Path $PSScriptRoot "..\src\Import-Modules.ps1"

Write-Host "Minecraft Mod Manager - Modular Structure Tests" -ForegroundColor $Colors.Header
Write-Host "===============================================" -ForegroundColor $Colors.Header

# Test 1: Check if import script exists
Write-TestHeader "Test 1: Import Script Existence"
$importScriptExists = Test-Path $ImportScriptPath
Write-TestResult "Import script exists" $importScriptExists

# Test 2: Import modules
Write-TestHeader "Test 2: Module Import"
try {
    . $ImportScriptPath
    $importSuccess = $true
    Write-Host "✅ Modules imported successfully" -ForegroundColor Green
} catch {
    $importSuccess = $false
    Write-Host "❌ Module import failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-TestResult "Module import" $importSuccess

# Test 3: Test core functions
Write-TestHeader "Test 3: Core Functions"
$coreFunctions = @(
    "Get-ModList",
    "Load-EnvironmentVariables",
    "Get-ApiResponsePath"
)

$coreFunctionsWorking = $true
foreach ($function in $coreFunctions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "✅ $function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ $function is not available" -ForegroundColor Red
        $coreFunctionsWorking = $false
    }
}
Write-TestResult "Core functions available" $coreFunctionsWorking

# Test 4: Test validation functions
Write-TestHeader "Test 4: Validation Functions"
$validationFunctions = @(
    "Get-FileHash",
    "Get-RecordHash",
    "Validate-AllModVersions"
)

$validationFunctionsWorking = $true
foreach ($function in $validationFunctions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "✅ $function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ $function is not available" -ForegroundColor Red
        $validationFunctionsWorking = $false
    }
}
Write-TestResult "Validation functions available" $validationFunctionsWorking

# Test 5: Test download functions
Write-TestHeader "Test 5: Download Functions"
$downloadFunctions = @(
    "Download-Mods",
    "Download-Modpack",
    "Download-ServerFiles"
)

$downloadFunctionsWorking = $true
foreach ($function in $downloadFunctions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "✅ $function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ $function is not available" -ForegroundColor Red
        $downloadFunctionsWorking = $false
    }
}
Write-TestResult "Download functions available" $downloadFunctionsWorking

# Test 6: Test display functions
Write-TestHeader "Test 6: Display Functions"
$displayFunctions = @(
    "Show-Help",
    "Write-DownloadReadme"
)

$displayFunctionsWorking = $true
foreach ($function in $displayFunctions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "✅ $function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ $function is not available" -ForegroundColor Red
        $displayFunctionsWorking = $false
    }
}
Write-TestResult "Display functions available" $displayFunctionsWorking

# Test 7: Test utility functions
Write-TestHeader "Test 7: Utility Functions"
$utilityFunctions = @(
    "Clean-Filename",
    "Get-BackupPath"
)

$utilityFunctionsWorking = $true
foreach ($function in $utilityFunctions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "✅ $function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ $function is not available" -ForegroundColor Red
        $utilityFunctionsWorking = $false
    }
}
Write-TestResult "Utility functions available" $utilityFunctionsWorking

# Test 8: Test API functions
Write-TestHeader "Test 8: API Functions"
$apiFunctions = @(
    "Get-ModrinthModInfo",
    "Get-ModrinthModVersion",
    "Get-ModrinthProjectInfo",
    "Validate-ModVersion",
    "Validate-CurseForgeModVersion"
)

$apiFunctionsWorking = $true
foreach ($function in $apiFunctions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "✅ $function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ $function is not available" -ForegroundColor Red
        $apiFunctionsWorking = $false
    }
}
Write-TestResult "API functions available" $apiFunctionsWorking

# Test 9: Test data processing functions
Write-TestHeader "Test 9: Data Processing Functions"
$dataFunctions = @(
    "Normalize-Version",
    "Convert-Dependencies",
    "Get-MajorityGameVersion"
)

$dataFunctionsWorking = $true
foreach ($function in $dataFunctions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "✅ $function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ $function is not available" -ForegroundColor Red
        $dataFunctionsWorking = $false
    }
}
Write-TestResult "Data processing functions available" $dataFunctionsWorking

# Test 10: Test database functions
Write-TestHeader "Test 10: Database Functions"
$databaseFunctions = @(
    "Update-ModListWithLatestVersions",
    "Ensure-CsvColumns",
    "Clean-SystemEntries"
)

$databaseFunctionsWorking = $true
foreach ($function in $databaseFunctions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "✅ $function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ $function is not available" -ForegroundColor Red
        $databaseFunctionsWorking = $false
    }
}
Write-TestResult "Database functions available" $databaseFunctionsWorking

# Summary
Write-TestHeader "Test Summary"
$allTestsPassed = $importSuccess -and $coreFunctionsWorking -and $validationFunctionsWorking -and $downloadFunctionsWorking -and $displayFunctionsWorking -and $utilityFunctionsWorking -and $apiFunctionsWorking -and $dataFunctionsWorking -and $databaseFunctionsWorking

Write-Host ""
Write-Host "Modular Structure Test Results:" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow
Write-Host "✅ Import Script: $importSuccess" -ForegroundColor $(if ($importSuccess) { "Green" } else { "Red" })
Write-Host "✅ Core Functions: $coreFunctionsWorking" -ForegroundColor $(if ($coreFunctionsWorking) { "Green" } else { "Red" })
Write-Host "✅ Validation Functions: $validationFunctionsWorking" -ForegroundColor $(if ($validationFunctionsWorking) { "Green" } else { "Red" })
Write-Host "✅ Download Functions: $downloadFunctionsWorking" -ForegroundColor $(if ($downloadFunctionsWorking) { "Green" } else { "Red" })
Write-Host "✅ Display Functions: $displayFunctionsWorking" -ForegroundColor $(if ($displayFunctionsWorking) { "Green" } else { "Red" })
Write-Host "✅ Utility Functions: $utilityFunctionsWorking" -ForegroundColor $(if ($utilityFunctionsWorking) { "Green" } else { "Red" })
Write-Host "✅ API Functions: $apiFunctionsWorking" -ForegroundColor $(if ($apiFunctionsWorking) { "Green" } else { "Red" })
Write-Host "✅ Data Processing Functions: $dataFunctionsWorking" -ForegroundColor $(if ($dataFunctionsWorking) { "Green" } else { "Red" })
Write-Host "✅ Database Functions: $databaseFunctionsWorking" -ForegroundColor $(if ($databaseFunctionsWorking) { "Green" } else { "Red" })

Write-TestResult "All modular structure tests" $allTestsPassed

Show-TestSummary "Modular Structure Tests"

return $allTestsPassed 