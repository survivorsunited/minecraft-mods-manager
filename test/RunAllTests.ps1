# Main Test Runner for ModManager CLI Tests
# Can run all tests or individual test files

param(
    [string[]]$TestFiles = @(),
    [switch]$All,
    [switch]$Cleanup,
    [switch]$Help
)

# Import test framework
. ".\TestFramework.ps1"

function Show-Usage {
    Write-Host "ModManager CLI Test Runner" -ForegroundColor $Colors.Header
    Write-Host "=========================" -ForegroundColor $Colors.Header
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\RunAllTests.ps1 -All                    # Run all test files" -ForegroundColor Gray
    Write-Host "  .\RunAllTests.ps1 -TestFiles '01-BasicFunctionality.ps1'  # Run specific test file" -ForegroundColor Gray
    Write-Host "  .\RunAllTests.ps1 -TestFiles '01-BasicFunctionality.ps1','02-DownloadFunctionality.ps1'  # Run multiple test files" -ForegroundColor Gray
    Write-Host "  .\RunAllTests.ps1 -Cleanup                # Clean up test files after completion" -ForegroundColor Gray
    Write-Host "  .\RunAllTests.ps1 -Help                   # Show this help message" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Available Test Files:" -ForegroundColor White
    # Dynamically list test files
    $testFiles = Get-ChildItem -Path "tests" -File -Name | Where-Object { $_ -match '^\d{2}-.*\.ps1$' } | Sort-Object
    foreach ($file in $testFiles) {
        Write-Host "  $file" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($Help) {
    Show-Usage
    exit 0
}

# Dynamically discover all test files matching '??-*.ps1', sorted
function Get-AllTestFiles {
    return Get-ChildItem -Path "tests" -File -Name | Where-Object { $_ -match '^\d{2}-.*\.ps1$' } | Sort-Object
}

# Determine which test files to run
$testFilesToRun = @()

if ($All) {
    $testFilesToRun = Get-AllTestFiles
} elseif ($TestFiles.Count -gt 0) {
    $testFilesToRun = $TestFiles
} else {
    $testFilesToRun = Get-AllTestFiles
}

Write-Host "Minecraft Mod Manager - Complete Test Suite" -ForegroundColor $Colors.Header
Write-Host "===========================================" -ForegroundColor $Colors.Header
Write-Host "Running tests: $($testFilesToRun -join ', ')" -ForegroundColor $Colors.Info
Write-Host ""

# Initialize global test results
$GlobalTestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    TestFiles = @()
}

# Run each test file
foreach ($testFile in $testFilesToRun) {
    $testFilePath = ".\tests\$testFile"
    
    if (-not (Test-Path $testFilePath)) {
        Write-Host "❌ ERROR: Test file not found: $testFile" -ForegroundColor Red
        continue
    }
    
    Write-Host "🚀 Running test file: $testFile" -ForegroundColor $Colors.Header
    Write-Host ("─" * 60) -ForegroundColor Gray
    
    try {
        # Reset test results for this file
        $TestResults.Total = 0
        $TestResults.Passed = 0
        $TestResults.Failed = 0
        
        # Run the test file
        & $testFilePath
        
        # Add results to global counter
        $GlobalTestResults.Total += $TestResults.Total
        $GlobalTestResults.Passed += $TestResults.Passed
        $GlobalTestResults.Failed += $TestResults.Failed
        
        # Record test file result
        $GlobalTestResults.TestFiles += @{
            Name = $testFile
            Total = $TestResults.Total
            Passed = $TestResults.Passed
            Failed = $TestResults.Failed
        }
        
        Write-Host ""
        Write-Host "✅ Completed: $testFile" -ForegroundColor Green
        Write-Host "   Passed: $($TestResults.Passed), Failed: $($TestResults.Failed), Total: $($TestResults.Total)" -ForegroundColor Gray
        
    } catch {
        Write-Host "❌ ERROR running $testFile : $($_.Exception.Message)" -ForegroundColor Red
        $GlobalTestResults.TestFiles += @{
            Name = $testFile
            Total = 0
            Passed = 0
            Failed = 1
            Error = $_.Exception.Message
        }
    }
    
    Write-Host ""
}

# Show final summary
Write-Host ("=" * 80) -ForegroundColor $Colors.Header
Write-Host "FINAL TEST SUMMARY" -ForegroundColor $Colors.Header
Write-Host ("=" * 80) -ForegroundColor $Colors.Header

Write-Host "Overall Results:" -ForegroundColor White
Write-Host "  Total Tests: $($GlobalTestResults.Total)" -ForegroundColor White
Write-Host "  Passed: $($GlobalTestResults.Passed)" -ForegroundColor $Colors.Pass
Write-Host "  Failed: $($GlobalTestResults.Failed)" -ForegroundColor $Colors.Fail

Write-Host ""
Write-Host "Test File Results:" -ForegroundColor White
foreach ($fileResult in $GlobalTestResults.TestFiles) {
    $status = if ($fileResult.Failed -eq 0) { "✅" } else { "❌" }
    Write-Host "  $status $($fileResult.Name): $($fileResult.Passed)/$($fileResult.Total) passed" -ForegroundColor $(if ($fileResult.Failed -eq 0) { $Colors.Pass } else { $Colors.Fail })
    if ($fileResult.Error) {
        Write-Host "    Error: $($fileResult.Error)" -ForegroundColor Red
    }
}

Write-Host ""
if ($GlobalTestResults.Failed -eq 0) {
    Write-Host "🎉 ALL TESTS PASSED! 🎉" -ForegroundColor $Colors.Pass
    $exitCode = 0
} else {
    Write-Host "❌ SOME TESTS FAILED! ❌" -ForegroundColor $Colors.Fail
    $exitCode = 1
}

# Cleanup if requested
if ($Cleanup) {
    Cleanup-TestEnvironment -Cleanup
}

Write-Host ""
Write-Host "Test suite completed with exit code: $exitCode" -ForegroundColor $Colors.Info
exit $exitCode 