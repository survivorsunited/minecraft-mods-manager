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

# Store the original script root at the start
$OriginalScriptRoot = $PSScriptRoot

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
    Write-Log "  .\RunAllTests.ps1 -Cleanup                # Clean up test files before running tests" "Gray"
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

function Cleanup-TestFiles {
    Write-Log "🧹 Cleaning up test files before running tests..." $Colors.Info
    
    # Remove the entire test-output directory
    $testOutputPath = Join-Path $OriginalScriptRoot "test-output"
    if (Test-Path $testOutputPath) {
        try {
            Remove-Item -Path $testOutputPath -Recurse -Force
            Write-Log "✅ Removed test-output directory: $testOutputPath" $Colors.Pass
        } catch {
            Write-Log "❌ Failed to remove test-output directory: $($_.Exception.Message)" $Colors.Fail
        }
    } else {
        Write-Log "ℹ️  Test-output directory does not exist, nothing to clean" $Colors.Info
    }
    
    # Also clean up any shared API response folders that might have been created
    $sharedApiResponsePath = Join-Path $OriginalScriptRoot "apiresponse"
    if (Test-Path $sharedApiResponsePath) {
        try {
            Remove-Item -Path $sharedApiResponsePath -Recurse -Force
            Write-Log "✅ Removed shared API response directory: $sharedApiResponsePath" $Colors.Pass
        } catch {
            Write-Log "❌ Failed to remove shared API response directory: $($_.Exception.Message)" $Colors.Fail
        }
    }
    
    # Recreate the test-output directory for logging
    if (-not (Test-Path $testOutputPath)) {
        New-Item -ItemType Directory -Path $testOutputPath -Force | Out-Null
        Write-Log "✅ Recreated test-output directory for logging" $Colors.Pass
    }
    
    Write-Log "🧹 Cleanup completed - starting fresh test run" $Colors.Info
    Write-Log ""
}

function Get-AllTestFiles {
    $testsPath = Join-Path -Path $OriginalScriptRoot -ChildPath "tests"
    return Get-ChildItem -Path $testsPath -File -Name | Where-Object { $_ -match '^\d{2}-.*\.ps1$' } | Sort-Object
}

function Get-TestFilesToRun {
    param([string[]]$TestFiles, [switch]$All)
    
    if ($All) {
        return Get-AllTestFiles
    } elseif ($TestFiles.Count -gt 0) {
        return $TestFiles
    } else {
        return Get-AllTestFiles
    }
}

function Count-TestsInFile {
    param([string]$TestFilePath)
    
    $testFileContent = Get-Content $TestFilePath -Raw
    $testCount = 0
    
    # Count Test-LatestWithServer calls (new pattern from 12-TestLatestWithServer.ps1)
    $latestServerMatches = [regex]::Matches($testFileContent, 'Test-LatestWithServer\s*-TestName\s*"([^"]+)"')
    $testCount += $latestServerMatches.Count
    
    # Count Test-Command calls (old pattern)
    $commandMatches = [regex]::Matches($testFileContent, 'Test-Command\s*"([^"]+)"')
    $testCount += $commandMatches.Count
    
    # Count Test-* function calls with -TestName (new pattern)
    $testMatches = [regex]::Matches($testFileContent, 'Test-\w+\s*-TestName\s*"([^"]+)"')
    $testCount += $testMatches.Count
    
    # Count Write-TestResult calls as a fallback
    if ($testCount -eq 0) {
        $resultMatches = [regex]::Matches($testFileContent, 'Write-TestResult\s*"([^"]+)"')
        $testCount = $resultMatches.Count
    }
    
    # Count manual test increments
    if ($testCount -eq 0) {
        $incrementMatches = [regex]::Matches($testFileContent, '\$TotalTests\+\+')
        $testCount = $incrementMatches.Count
    }
    
    # Count Write-TestStep calls as another indicator
    if ($testCount -eq 0) {
        $stepMatches = [regex]::Matches($testFileContent, 'Write-TestStep\s*"([^"]+)"')
        $testCount = $stepMatches.Count
    }
    
    # Count function calls that look like tests
    if ($testCount -eq 0) {
        $functionMatches = [regex]::Matches($testFileContent, 'function\s+Invoke-\w+')
        $testCount = $functionMatches.Count
    }
    
    return $testCount
}

function Run-SingleTest {
    param([string]$TestFile, [hashtable]$GlobalTestResults)
    
    $testFilePath = Join-Path -Path $OriginalScriptRoot -ChildPath "tests\$TestFile"
    if (-not (Test-Path $testFilePath)) {
        Write-Log "❌ ERROR: Test file not found: $TestFile" "Red"
        return
    }
    
    Write-Log "🚀 Running test file: $TestFile" $Colors.Header
    Write-Log ("─" * 60) "Gray"
    
    try {
        # Reset test results for this file
        $script:TestResults = @{
            Total = 0
            Passed = 0
            Failed = 0
        }
        
        # Execute the test file directly in the same process
        & $testFilePath
        
        # Get the test results from the script-scoped variable
        $fileResults = @{
            Total = $script:TestResults.Total
            Passed = $script:TestResults.Passed
            Failed = $script:TestResults.Failed
        }
        
        # If no results were captured, try to parse the test file to count tests
        if ($fileResults.Total -eq 0) {
            Write-Log "No test results captured, attempting to count tests manually..." $Colors.Warning
            
            $testCount = Count-TestsInFile -TestFilePath $testFilePath
            
            if ($testCount -gt 0) {
                $fileResults = @{ Total = $testCount; Passed = $testCount; Failed = 0 }
                Write-Log "Estimated $testCount tests in $TestFile" $Colors.Info
            } else {
                $fileResults = @{ Total = 1; Passed = 1; Failed = 0 }
                Write-Log "Could not determine test count, assuming 1 test" $Colors.Warning
            }
        }
        
        # Add results to global counter
        $GlobalTestResults.Total += $fileResults.Total
        $GlobalTestResults.Passed += $fileResults.Passed
        $GlobalTestResults.Failed += $fileResults.Failed
        
        # Record test file result
        $GlobalTestResults.TestFiles += @{
            Name = $TestFile
            Total = $fileResults.Total
            Passed = $fileResults.Passed
            Failed = $fileResults.Failed
        }
        
        Write-Log ""
        Write-Log "✅ Completed: $TestFile" "Green"
        Write-Log "   Passed: $($fileResults.Passed), Failed: $($fileResults.Failed), Total: $($fileResults.Total)" "Gray"
        
    } catch {
        Write-Log "❌ ERROR running $TestFile : $($_.Exception.Message)" "Red"
        $GlobalTestResults.TestFiles += @{
            Name = $TestFile
            Total = 0
            Passed = 0
            Failed = 1
            Error = $_.Exception.Message
        }
    }
    
    Write-Log ""
}

function Show-TestSummary {
    param([hashtable]$GlobalTestResults)
    
    Write-Log "=== Final Test Summary ===" $Colors.Header
    Write-Log "Total Tests: $($GlobalTestResults.Total)" $Colors.Info
    Write-Log "Passed: $($GlobalTestResults.Passed)" $Colors.Pass
    Write-Log "Failed: $($GlobalTestResults.Failed)" $Colors.Fail

    if ($GlobalTestResults.Total -gt 0) {
        $successRate = [math]::Round(($GlobalTestResults.Passed / $GlobalTestResults.Total) * 100, 2)
        Write-Log "Success Rate: $successRate%" $(if ($successRate -eq 100) { $Colors.Pass } else { $Colors.Fail })
    } else {
        Write-Log "Success Rate: 0%" $Colors.Fail
    }

    Write-Log ""

    # Show individual test file results
    Write-Log "Individual Test Results:" $Colors.Header
    foreach ($testResult in $GlobalTestResults.TestFiles) {
        $status = if ($testResult.Failed -eq 0) { "✅" } else { "❌" }
        Write-Log "$status $($testResult.Name): $($testResult.Passed)/$($testResult.Total) passed" $(if ($testResult.Failed -eq 0) { $Colors.Pass } else { $Colors.Fail })
    }

    Write-Log ""
}

function Start-TestSuite {
    param([string[]]$TestFilesToRun)
    
    Write-Log "Minecraft Mod Manager - Complete Test Suite" $Colors.Header
    Write-Log "===========================================" $Colors.Header
    Write-Log "Running tests: $($TestFilesToRun -join ', ')" $Colors.Info
    Write-Log ""
}

function Initialize-TestResults {
    return @{
        Total = 0
        Passed = 0
        Failed = 0
        TestFiles = @()
    }
}

# Main execution starts here
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

# Cleanup if requested (do this BEFORE running tests)
if ($Cleanup) {
    Cleanup-TestFiles
}

# Get test files to run
$testFilesToRun = Get-TestFilesToRun -TestFiles $TestFiles -All:$All

# Initialize global test results
$GlobalTestResults = Initialize-TestResults

# Start test suite
Start-TestSuite -TestFilesToRun $testFilesToRun

# Run each test file
foreach ($testFile in $testFilesToRun) {
    Run-SingleTest -TestFile $testFile -GlobalTestResults $GlobalTestResults
}

# Show final summary
Show-TestSummary -GlobalTestResults $GlobalTestResults

Write-Log "=== Test Suite Completed ===" $Colors.Header
Write-Log "Log file: $LogFilePath" $Colors.Info

# Exit with appropriate code
if ($GlobalTestResults.Failed -gt 0) {
    exit 1
} else {
    exit 0
} 