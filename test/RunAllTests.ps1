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
$TestOutputDir = "test-output"
$LogFilePath = Join-Path $TestOutputDir $LogFileName

# Create test output directory if it doesn't exist
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Colors for output
$Colors = @{
    Pass = "Green"
    Fail = "Red"
    Info = "Cyan"
    Warning = "Yellow"
    Header = "Magenta"
}

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    
    # Write to console with color
    if ($Color -and $Color -ne "") {
        Write-Host $Message -ForegroundColor $Color
    } else {
        Write-Host $Message
    }
    
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
    $testFiles = Get-ChildItem -Path ".\tests" -File -Name | Where-Object { $_ -match '^\d{2}-.*\.ps1$' } | Sort-Object
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
    return Get-ChildItem -Path ".\tests" -File -Name | Where-Object { $_ -match '^\d{2}-.*\.ps1$' } | Sort-Object
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
        $script:TestResults = @{
            Total = 0
            Passed = 0
            Failed = 0
        }
        
        # Capture output from test file execution using dot-sourcing
        $testOutput = & {
            # Set the correct PSScriptRoot for the test file
            $script:PSScriptRoot = Join-Path $PWD "tests"
            
            # Dot-source the test file
            . $testFilePath
            
            # Explicitly call the main test function based on the test file name
            if ($testFile -eq "07-StartServerTests.ps1") {
                Invoke-StartServerTests -TestFileName $testFile
            } elseif ($testFile -eq "08-StartServerUnitTests.ps1") {
                Invoke-StartServerUnitTests -TestFileName $testFile
            } elseif ($testFile -eq "09-TestCurrent.ps1") {
                Invoke-TestCurrent -TestFileName $testFile
            } elseif ($testFile -eq "10-TestLatest.ps1") {
                Invoke-TestLatest -TestFileName $testFile
            } elseif ($testFile -eq "11-ParameterValidation.ps1") {
                # Parameter validation test runs independently
                & $testFilePath
            } elseif ($testFile -eq "12-TestLatestWithServer.ps1") {
                # Latest mods with server test runs independently
                & $testFilePath
            }
        } 2>&1
        
        # Display the captured output
        $testOutput | ForEach-Object { Write-Host $_ }
        
        # Log the captured output
        if (-not $NoLog) {
            $testOutput | ForEach-Object {
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "$timestamp - $($_)" | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
            }
        }
        
        # Get the test results from the script-scoped variable
        $fileResults = @{
            Total = $script:TestResults.Total
            Passed = $script:TestResults.Passed
            Failed = $script:TestResults.Failed
        }
        
        # Add results to global counter
        $GlobalTestResults.Total += $fileResults.Total
        $GlobalTestResults.Passed += $fileResults.Passed
        $GlobalTestResults.Failed += $fileResults.Failed
        
        # Record test file result
        $GlobalTestResults.TestFiles += @{
            Name = $testFile
            Total = $fileResults.Total
            Passed = $fileResults.Passed
            Failed = $fileResults.Failed
        }
        
        Write-Log ""
        Write-Log "✅ Completed: $testFile" "Green"
        Write-Log "   Passed: $($fileResults.Passed), Failed: $($fileResults.Failed), Total: $($fileResults.Total)" "Gray"
        
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

# Clean up old test run log files (keep only the last 5)
$oldLogFiles = Get-ChildItem -Path $TestOutputDir -Filter "test-run-*.log" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 5
if ($oldLogFiles) {
    $oldLogFiles | Remove-Item -Force
    Write-Log "Cleaned up $($oldLogFiles.Count) old test run log files" $Colors.Info
}

Write-Log ""
Write-Log "Test suite completed with exit code: $exitCode" $Colors.Info

# Final log entry
if (-not $NoLog) {
    Write-Log "=== ModManager Test Suite Completed ===" $Colors.Header
    Write-Log "Log file saved to: $LogFilePath" $Colors.Info
}

exit $exitCode 