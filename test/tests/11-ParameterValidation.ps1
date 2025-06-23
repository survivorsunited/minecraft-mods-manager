# Parameter Validation Tests
# Tests various parameter combinations and edge cases

param([string]$TestFileName = $null)

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "11-ParameterValidation.ps1"

Initialize-TestEnvironment $TestFileName

Write-Host "Minecraft Mod Manager - Parameter Validation Tests" -ForegroundColor $Colors.Header
Write-Host "==================================================" -ForegroundColor $Colors.Header

# Test configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\11-ParameterValidation"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Create test modlist with minimal test data
$testMods = @(
    @{
        Group = "test"
        Type = "mod"
        GameVersion = "1.21.5"
        ID = "fabric-api"
        Loader = "fabric"
        Version = "0.91.0+1.21.5"
        Name = "Fabric API"
        Description = "Test Fabric API"
        Jar = "fabric-api-0.91.0+1.21.5.jar"
        Url = "https://modrinth.com/mod/fabric-api"
        Category = "API"
        VersionUrl = "https://modrinth.com/mod/fabric-api/version/0.91.0+1.21.5"
        LatestVersionUrl = "https://modrinth.com/mod/fabric-api/version/0.91.0+1.21.5"
        LatestVersion = "0.91.0+1.21.5"
        ApiSource = "modrinth"
        Host = "modrinth.com"
        IconUrl = "https://cdn.modrinth.com/data/P7dR8mSH/icon.png"
        ClientSide = "required"
        ServerSide = "required"
        Title = "Fabric API"
        ProjectDescription = "Test Fabric API"
        IssuesUrl = "https://github.com/FabricMC/fabric/issues"
        SourceUrl = "https://github.com/FabricMC/fabric"
        WikiUrl = "https://fabricmc.net/wiki"
        LatestGameVersion = "1.21.5"
        RecordHash = "test-hash"
    }
)

# Create test modlist.csv
$testMods | Export-Csv -Path $TestModListPath -NoTypeInformation

# Test variables
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0
$TestReport = @()

# Test report file
$TestReportPath = Join-Path $TestOutputDir "parameter-validation-test-report.txt"

function Test-ParameterValidation {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$ExpectedOutput = "",
        [int]$ExpectedExitCode = $null
    )
    
    $script:TotalTests++
    Write-Host "Testing: $TestName" -ForegroundColor Yellow
    
    try {
        $result = & $TestScript 2>&1
        $exitCode = $LASTEXITCODE
        $output = $result -join "`n"
        
        # Save individual test log
        $logFile = Join-Path $TestOutputDir "$($TestName.Replace(' ', '_')).log"
        $output | Out-File -FilePath $logFile -Encoding UTF8
        
        # Check if test passed
        $passed = $true
        $errorMessage = ""
        
        if ($ExpectedExitCode -ne $null -and $exitCode -ne $ExpectedExitCode) {
            $passed = $false
            $errorMessage = "Expected exit code $ExpectedExitCode, got $exitCode"
        }
        
        if ($ExpectedOutput -and $output -notmatch $ExpectedOutput) {
            $passed = $false
            $errorMessage = "Expected output pattern '$ExpectedOutput' not found"
        }
        
        if ($passed) {
            Write-Host "  ✅ PASS" -ForegroundColor Green
            $script:PassedTests++
            $script:TestReport += "✅ PASS: $TestName`n"
        } else {
            Write-Host "  ❌ FAIL: $errorMessage" -ForegroundColor Red
            $script:FailedTests++
            $script:TestReport += "❌ FAIL: $TestName - $errorMessage`n"
        }
        
    } catch {
        Write-Host "  ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $script:FailedTests++
        $script:TestReport += "❌ ERROR: $TestName - $($_.Exception.Message)`n"
    }
    
    Write-Host ""
}

function Invoke-ParameterValidation {
    param([string]$TestFileName = $null)
    
    Write-Host "Starting Parameter Validation Tests" -ForegroundColor Yellow
    Write-Host "Test Output Directory: $TestOutputDir" -ForegroundColor Gray
    Write-Host "Test ModList: $TestModListPath" -ForegroundColor Gray
    Write-Host ""

    # Test 1: No parameters (should show help)
    Write-Host "=== Test 1: No Parameters (Help) ===" -ForegroundColor Magenta
    Test-ParameterValidation -TestName "No Parameters Help" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Test 2: Invalid parameter
    Write-Host "=== Test 2: Invalid Parameter ===" -ForegroundColor Magenta
    Test-ParameterValidation -TestName "Invalid Parameter" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -InvalidParam
    } -ExpectedOutput "error|Error|ERROR|Invalid|invalid" -ExpectedExitCode 1

    # Test 3: Missing required parameter (DatabaseFile)
    Write-Host "=== Test 3: Missing DatabaseFile Parameter ===" -ForegroundColor Magenta
    Test-ParameterValidation -TestName "Missing DatabaseFile" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Download -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "error|Error|ERROR|DatabaseFile|database" -ExpectedExitCode 1

    # Test 4: Invalid database file path
    Write-Host "=== Test 4: Invalid Database File Path ===" -ForegroundColor Magenta
    Test-ParameterValidation -TestName "Invalid Database Path" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Download -DatabaseFile "C:\Invalid\modlist.csv" -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "error|Error|ERROR|not found|does not exist" -ExpectedExitCode 1

    # Test 5: Invalid download folder path
    Write-Host "=== Test 5: Invalid Download Folder Path ===" -ForegroundColor Magenta
    Test-ParameterValidation -TestName "Invalid Download Folder" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Download -DatabaseFile $TestModListPath -DownloadFolder "C:\Invalid\Download\Path"
    } -ExpectedOutput "error|Error|ERROR|not found|does not exist|cannot create" -ExpectedExitCode 1

    # Test 6: Conflicting parameters (Download and DownloadMods)
    Write-Host "=== Test 6: Conflicting Parameters ===" -ForegroundColor Magenta
    Test-ParameterValidation -TestName "Conflicting Parameters" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Download -DownloadMods -DatabaseFile $TestModListPath -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "error|Error|ERROR|conflict|Conflicting|mutually exclusive" -ExpectedExitCode 1

    # Test 7: Valid parameter combination
    Write-Host "=== Test 7: Valid Parameter Combination ===" -ForegroundColor Magenta
    Test-ParameterValidation -TestName "Valid Parameters" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -DatabaseFile $TestModListPath -UseCachedResponses
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Test 8: Test with valid test modlist.csv
    Write-Host "=== Test 8: Valid Test ModList ===" -ForegroundColor Magenta
    Test-ParameterValidation -TestName "Valid Test ModList" -TestScript {
        if (Test-Path $TestModListPath) {
            $mods = Import-Csv $TestModListPath
            "Test modlist.csv found with $($mods.Count) mods"
            $mods | ForEach-Object { "  - $($_.Name): $($_.Version)" }
        } else {
            "Test modlist.csv not found"
        }
    } -ExpectedOutput "Test modlist.csv found" -ExpectedExitCode 0

    # Final check: Ensure test/download is empty or does not exist
    Write-Host "=== Final Step: Verifying test/download is untouched ===" -ForegroundColor Magenta
    $TotalTests++  # Increment total test count for this check
    $mainTestDownloadPath = Join-Path $PSScriptRoot "..\download"
    if (Test-Path $mainTestDownloadPath) {
        $downloadContents = Get-ChildItem -Path $mainTestDownloadPath -Recurse -File -ErrorAction SilentlyContinue
        if ($downloadContents.Count -gt 0) {
            Write-Host "  ❌ FAIL: main test/download is not empty!" -ForegroundColor Red
            $FailedTests++
            $TestReport += "❌ FAIL: main test/download is not empty!`n"
        } else {
            Write-Host "  ✅ PASS: main test/download is empty" -ForegroundColor Green
            $PassedTests++
            $TestReport += "✅ PASS: main test/download is empty`n"
        }
    } else {
        Write-Host "  ✅ PASS: main test/download does not exist" -ForegroundColor Green
        $PassedTests++
        $TestReport += "✅ PASS: main test/download does not exist`n"
    }

    # Generate final report
    $TestReport += @"

Test Summary:
=============
Total Tests: $TotalTests
Passed: $PassedTests
Failed: $FailedTests
Success Rate: $(if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 2) } else { 0 })%

Test Details:
=============
This test validates parameter handling and edge cases.
It uses a test-specific modlist.csv to avoid interfering with the main modlist.csv.

Expected Behavior:
- Help should display with no parameters
- Invalid parameters should be rejected
- Missing required parameters should be detected
- Invalid file paths should be handled gracefully
- Conflicting parameters should be detected
- Valid parameters should work correctly
- test/download should remain untouched
"@

    # Set global test results for the test runner
    $script:TestResults = @{
        Total = $TotalTests
        Passed = $PassedTests
        Failed = $FailedTests
    }

    # Save test report
    $TestReport | Out-File -FilePath $TestReportPath -Encoding UTF8

    Write-Host "Test completed!" -ForegroundColor Green
    Write-Host "Total Tests: $TotalTests" -ForegroundColor Cyan
    Write-Host "Passed: $PassedTests" -ForegroundColor Green
    Write-Host "Failed: $FailedTests" -ForegroundColor Red
    Write-Host "Success Rate: $(if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 2) } else { 0 })%" -ForegroundColor Green
    Write-Host "Test report saved to: $TestReportPath" -ForegroundColor Gray

    return ($FailedTests -eq 0)
}

# Execute tests if run directly
if ($MyInvocation.InvocationName -ne ".") {
    Invoke-ParameterValidation -TestFileName $TestFileName
} 