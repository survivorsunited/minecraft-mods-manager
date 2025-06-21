# Parameter Validation Tests
# Tests all parameters and their combinations for the ModManager.ps1 script

param(
    [string]$TestOutputPath = "test-output/11-ParameterValidation",
    [switch]$Verbose
)

# Import test framework
. "$PSScriptRoot/../TestFramework.ps1"

# Test configuration
$TestName = "Parameter Validation Tests"
$TestDescription = "Comprehensive tests for all ModManager.ps1 parameters and their combinations"
$TestOutputDir = $TestOutputPath
$TestReportPath = Join-Path $TestOutputDir "parameter-validation-test-report.txt"

# Create test output directory
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Initialize test report
$TestReport = @"
Parameter Validation Test Report
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Test Output Directory: $TestOutputDir

"@

# Test counter
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

# Helper function to run parameter test
function Test-Parameter {
    param(
        [string]$TestName,
        [string]$Parameters,
        [string]$ExpectedOutput,
        [string]$ExpectedError = $null,
        [int]$ExpectedExitCode = 0
    )
    
    $TotalTests++
    Write-Host "Testing: $TestName" -ForegroundColor Cyan
    
    try {
        $command = ".\ModManager.ps1 $Parameters"
        Write-Host "  Command: $command" -ForegroundColor Gray
        
        $result = Invoke-Expression $command 2>&1
        $exitCode = $LASTEXITCODE
        
        $success = $true
        $errorMessage = ""
        
        # Check exit code
        if ($exitCode -ne $ExpectedExitCode) {
            $success = $false
            $errorMessage = "Exit code mismatch. Expected: $ExpectedExitCode, Got: $exitCode"
        }
        
        # Check for expected output
        if ($ExpectedOutput -and $result -notmatch $ExpectedOutput) {
            $success = $false
            $errorMessage = "Expected output not found: $ExpectedOutput"
        }
        
        # Check for expected error
        if ($ExpectedError -and $result -notmatch $ExpectedError) {
            $success = $false
            $errorMessage = "Expected error not found: $ExpectedError"
        }
        
        if ($success) {
            Write-Host "  ✅ PASS" -ForegroundColor Green
            $PassedTests++
            $TestReport += "✅ PASS: $TestName`n"
        } else {
            Write-Host "  ❌ FAIL: $errorMessage" -ForegroundColor Red
            $FailedTests++
            $TestReport += "❌ FAIL: $TestName - $errorMessage`n"
        }
        
        # Log output for debugging
        $outputLogPath = Join-Path $TestOutputDir "$($TestName -replace '[^a-zA-Z0-9]', '_').log"
        $result | Out-File -FilePath $outputLogPath -Encoding UTF8
        
    } catch {
        Write-Host "  ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $FailedTests++
        $TestReport += "❌ ERROR: $TestName - $($_.Exception.Message)`n"
    }
    
    Write-Host ""
}

# Helper function to test parameter validation
function Test-ParameterValidation {
    param(
        [string]$TestName,
        [string]$Parameters,
        [string]$ExpectedError
    )
    
    Test-Parameter -TestName $TestName -Parameters $Parameters -ExpectedError $ExpectedError -ExpectedExitCode 1
}

# Helper function to test parameter success
function Test-ParameterSuccess {
    param(
        [string]$TestName,
        [string]$Parameters,
        [string]$ExpectedOutput
    )
    
    Test-Parameter -TestName $TestName -Parameters $Parameters -ExpectedOutput $ExpectedOutput -ExpectedExitCode 0
}

Write-Host "Starting $TestName" -ForegroundColor Yellow
Write-Host "Test Output Directory: $TestOutputDir" -ForegroundColor Gray
Write-Host ""

# Test 1: Help parameters
Write-Host "=== Testing Help Parameters ===" -ForegroundColor Magenta
Test-ParameterSuccess -TestName "Help Parameter" -Parameters "-Help" -ExpectedOutput "Usage:"
Test-ParameterSuccess -TestName "ShowHelp Parameter" -Parameters "-ShowHelp" -ExpectedOutput "Usage:"

# Test 2: Core parameters
Write-Host "=== Testing Core Parameters ===" -ForegroundColor Magenta
Test-ParameterSuccess -TestName "Download Parameter" -Parameters "-Download" -ExpectedOutput "Starting mod downloads"
Test-ParameterSuccess -TestName "UseLatestVersion Parameter" -Parameters "-Download -UseLatestVersion" -ExpectedOutput "Using latest versions"
Test-ParameterSuccess -TestName "ForceDownload Parameter" -Parameters "-Download -ForceDownload" -ExpectedOutput "Force downloading"

# Test 3: Validation parameters
Write-Host "=== Testing Validation Parameters ===" -ForegroundColor Magenta
Test-ParameterValidation -TestName "ValidateMod without ModID" -Parameters "-ValidateMod" -ExpectedError "requires -ModID parameter"
Test-ParameterSuccess -TestName "ValidateMod with ModID" -Parameters "-ValidateMod -ModID fabric-api" -ExpectedOutput "Validating mod: fabric-api"
Test-ParameterSuccess -TestName "ValidateAllModVersions" -Parameters "-ValidateAllModVersions" -ExpectedOutput "Starting automatic validation"
Test-ParameterSuccess -TestName "ValidateWithDownload" -Parameters "-DownloadMods -ValidateWithDownload" -ExpectedOutput "Validating mod versions before download"

# Test 4: Download parameters
Write-Host "=== Testing Download Parameters ===" -ForegroundColor Magenta
Test-ParameterSuccess -TestName "DownloadMods" -Parameters "-DownloadMods" -ExpectedOutput "Starting mod downloads"
Test-ParameterSuccess -TestName "DownloadServer" -Parameters "-DownloadServer" -ExpectedOutput "Downloading server files"
Test-ParameterSuccess -TestName "StartServer" -Parameters "-StartServer" -ExpectedOutput "Starting Minecraft server"

# Test 5: Mod management parameters
Write-Host "=== Testing Mod Management Parameters ===" -ForegroundColor Magenta
Test-ParameterValidation -TestName "AddMod without AddModId" -Parameters "-AddMod" -ExpectedError "You must provide a mod ID"
Test-ParameterSuccess -TestName "AddMod with AddModId" -Parameters "-AddMod -AddModId fabric-api -AddModName 'Fabric API'" -ExpectedOutput "Resolving mod information"
Test-ParameterSuccess -TestName "AddMod with URL" -Parameters "-AddModId 'https://modrinth.com/mod/fabric-api'" -ExpectedOutput "Resolving mod information"
Test-ParameterValidation -TestName "DeleteModID without ID" -Parameters "-DeleteModID" -ExpectedError "You must provide a mod ID"

# Test 6: Information parameters
Write-Host "=== Testing Information Parameters ===" -ForegroundColor Magenta
Test-ParameterSuccess -TestName "GetModList" -Parameters "-GetModList" -ExpectedOutput "Mod List"

# Test 7: Configuration parameters
Write-Host "=== Testing Configuration Parameters ===" -ForegroundColor Magenta
Test-ParameterSuccess -TestName "ModListFile" -Parameters "-ModListFile modlist.csv" -ExpectedOutput "Starting automatic validation"
Test-ParameterSuccess -TestName "DatabaseFile" -Parameters "-DatabaseFile modlist.csv" -ExpectedOutput "Starting automatic validation"
Test-ParameterSuccess -TestName "UseCachedResponses" -Parameters "-ValidateAllModVersions -UseCachedResponses" -ExpectedOutput "Starting automatic validation"

# Test 8: Parameter combinations
Write-Host "=== Testing Parameter Combinations ===" -ForegroundColor Magenta
Test-ParameterSuccess -TestName "Download with Latest and Force" -Parameters "-Download -UseLatestVersion -ForceDownload" -ExpectedOutput "Using latest versions"
Test-ParameterSuccess -TestName "DownloadMods with Validation" -Parameters "-DownloadMods -ValidateWithDownload" -ExpectedOutput "Validating mod versions before download"
Test-ParameterSuccess -TestName "AddMod with All Parameters" -Parameters "-AddMod -AddModId sodium -AddModName Sodium -AddModLoader fabric -AddModGameVersion 1.21.6 -AddModGroup optional" -ExpectedOutput "Resolving mod information"

# Test 9: Error handling
Write-Host "=== Testing Error Handling ===" -ForegroundColor Magenta
Test-ParameterValidation -TestName "Invalid ModID" -Parameters "-ValidateMod -ModID invalid-mod-id" -ExpectedError "not found in the database"
Test-ParameterValidation -TestName "Invalid ModListFile" -Parameters "-ModListFile nonexistent.csv" -ExpectedError "Mod list CSV file not found"

# Test 10: Default behavior
Write-Host "=== Testing Default Behavior ===" -ForegroundColor Magenta
Test-ParameterSuccess -TestName "No Parameters" -Parameters "" -ExpectedOutput "Starting automatic validation"

# Test 11: Parameter validation edge cases
Write-Host "=== Testing Edge Cases ===" -ForegroundColor Magenta
Test-ParameterValidation -TestName "Empty ModID" -Parameters "-ValidateMod -ModID ''" -ExpectedError "requires -ModID parameter"
Test-ParameterValidation -TestName "Whitespace ModID" -Parameters "-ValidateMod -ModID '   '" -ExpectedError "requires -ModID parameter"

# Test 12: URL parsing
Write-Host "=== Testing URL Parsing ===" -ForegroundColor Magenta
Test-ParameterSuccess -TestName "Modrinth Mod URL" -Parameters "-AddModId 'https://modrinth.com/mod/fabric-api'" -ExpectedOutput "Resolving mod information"
Test-ParameterSuccess -TestName "Modrinth Shader URL" -Parameters "-AddModId 'https://modrinth.com/shader/complementary-reimagined'" -ExpectedOutput "Resolving mod information"
Test-ParameterValidation -TestName "Invalid URL" -Parameters "-AddModId 'https://invalid-url.com'" -ExpectedError "Failed to resolve mod information"

# Test 13: Delete functionality
Write-Host "=== Testing Delete Functionality ===" -ForegroundColor Magenta
Test-ParameterSuccess -TestName "Delete with Modrinth URL" -Parameters "-DeleteModID 'https://modrinth.com/mod/fabric-api'" -ExpectedOutput "Deleting mod: fabric-api"
Test-ParameterSuccess -TestName "Delete with Type" -Parameters "-DeleteModID fabric-api -DeleteModType mod" -ExpectedOutput "Deleting mod: fabric-api"

# Generate final report
$TestReport += @"

Test Summary:
=============
Total Tests: $TotalTests
Passed: $PassedTests
Failed: $FailedTests
Success Rate: $([math]::Round(($PassedTests / $TotalTests) * 100, 2))%

Test Details:
=============
All test outputs have been saved to individual log files in: $TestOutputDir

"@

# Save test report
$TestReport | Out-File -FilePath $TestReportPath -Encoding UTF8

# Display summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Yellow
Write-Host "Total Tests: $TotalTests" -ForegroundColor White
Write-Host "Passed: $PassedTests" -ForegroundColor Green
Write-Host "Failed: $FailedTests" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($PassedTests / $TotalTests) * 100, 2))%" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test report saved to: $TestReportPath" -ForegroundColor Gray
Write-Host "Individual test logs saved to: $TestOutputDir" -ForegroundColor Gray

# Return exit code based on test results
if ($FailedTests -eq 0) {
    Write-Host "All parameter validation tests passed! 🎉" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some parameter validation tests failed! ❌" -ForegroundColor Red
    exit 1
} 