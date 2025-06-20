# Main Test Runner for ModManager CLI Tests
# Can run all tests or individual test files

param(
    [string[]]$TestFiles = @(),
    [switch]$All,
    [switch]$Cleanup,
    [switch]$Help,
    [switch]$NoLog
)

# Import test framework
. ".\TestFramework.ps1"

# Setup logging
$LogTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFileName = "test-run-$LogTimestamp.log"
$LogFilePath = Join-Path $PSScriptRoot $LogFileName

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    
    # Write to console with color
    Write-Host $Message -ForegroundColor $Color
    
    # Write to log file (without color codes)
    if (-not $NoLog) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - $Message" | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
    }
}

function Show-Usage {
    Write-Log "ModManager CLI Test Runner" $Colors.Header
    Write-Log "=========================" $Colors.Header
    Write-Log ""
    Write-Log "Usage:" "White"
    Write-Log "  .\RunAllTests.ps1 -All                    # Run all test files" "Gray"
    Write-Log "  .\RunAllTests.ps1 -TestFiles '01-BasicFunctionality.ps1'  # Run specific test file" "Gray"
    Write-Log "  .\RunAllTests.ps1 -TestFiles '01-BasicFunctionality.ps1','02-DownloadFunctionality.ps1'  # Run multiple test files" "Gray"
    Write-Log "  .\RunAllTests.ps1 -Cleanup                # Clean up test files after completion" "Gray"
    Write-Log "  .\RunAllTests.ps1 -Help                   # Show this help message" "Gray"
    Write-Log "  .\RunAllTests.ps1 -NoLog                  # Disable logging to file" "Gray"
    Write-Log ""
    Write-Log "Available Test Files:" "White"
    # Dynamically list test files
    $testFiles = Get-ChildItem -Path "tests" -File -Name | Where-Object { $_ -match '^\d{2}-.*\.ps1$' } | Sort-Object
    foreach ($file in $testFiles) {
        Write-Log "  $file" "Gray"
    }
    Write-Log ""
}

if ($Help) {
    Show-Usage
    exit 0
}

# Start logging
if (-not $NoLog) {
    Write-Log "=== ModManager Test Suite Started ===" $Colors.Header
    Write-Log "Log file: $LogFilePath" $Colors.Info
    Write-Log "Timestamp: $LogTimestamp" $Colors.Info
    Write-Log ""
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

Write-Log "Minecraft Mod Manager - Complete Test Suite" $Colors.Header
Write-Log "===========================================" $Colors.Header
Write-Log "Running tests: $($testFilesToRun -join ', ')" $Colors.Info
Write-Log ""

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
        Write-Log "❌ ERROR: Test file not found: $testFile" "Red"
        continue
    }
    
    Write-Log "🚀 Running test file: $testFile" $Colors.Header
    Write-Log ("─" * 60) "Gray"
    
    try {
        # Reset test results for this file
        $TestResults.Total = 0
        $TestResults.Passed = 0
        $TestResults.Failed = 0
        
        # Capture output from test file execution
        $testOutput = & $testFilePath 2>&1 | Tee-Object -Variable capturedOutput
        
        # Log the captured output
        if (-not $NoLog) {
            $capturedOutput | ForEach-Object {
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "$timestamp - $($_)" | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
            }
        }
        
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
        
        Write-Log ""
        Write-Log "✅ Completed: $testFile" "Green"
        Write-Log "   Passed: $($TestResults.Passed), Failed: $($TestResults.Failed), Total: $($TestResults.Total)" "Gray"
        
    } catch {
        Write-Log "❌ ERROR running $testFile : $($_.Exception.Message)" "Red"
        $GlobalTestResults.TestFiles += @{
            Name = $testFile
            Total = 0
            Passed = 0
            Failed = 1
            Error = $_.Exception.Message
        }
    }
    
    Write-Log ""
}

# Show final summary
Write-Log ("=" * 80) $Colors.Header
Write-Log "FINAL TEST SUMMARY" $Colors.Header
Write-Log ("=" * 80) $Colors.Header

Write-Log "Overall Results:" "White"
Write-Log "  Total Tests: $($GlobalTestResults.Total)" "White"
Write-Log "  Passed: $($GlobalTestResults.Passed)" $Colors.Pass
Write-Log "  Failed: $($GlobalTestResults.Failed)" $Colors.Fail

Write-Log ""
Write-Log "Test File Results:" "White"
foreach ($fileResult in $GlobalTestResults.TestFiles) {
    $status = if ($fileResult.Failed -eq 0) { "✅" } else { "❌" }
    Write-Log "  $status $($fileResult.Name): $($fileResult.Passed)/$($fileResult.Total) passed" $(if ($fileResult.Failed -eq 0) { $Colors.Pass } else { $Colors.Fail })
    if ($fileResult.Error) {
        Write-Log "    Error: $($fileResult.Error)" "Red"
    }
}

Write-Log ""
if ($GlobalTestResults.Failed -eq 0) {
    Write-Log "🎉 ALL TESTS PASSED! 🎉" $Colors.Pass
    $exitCode = 0
} else {
    Write-Log "❌ SOME TESTS FAILED! ❌" $Colors.Fail
    $exitCode = 1
}

# Cleanup if requested
if ($Cleanup) {
    Cleanup-TestEnvironment -Cleanup
}

Write-Log ""
Write-Log "Test suite completed with exit code: $exitCode" $Colors.Info

# Final log entry
if (-not $NoLog) {
    Write-Log "=== ModManager Test Suite Completed ===" $Colors.Header
    Write-Log "Log file saved to: $LogFilePath" $Colors.Info
}

exit $exitCode 