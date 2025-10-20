# Run All Tests with Console Output Logging
# Wrapper script that executes RunAllTests.ps1 and captures all console output to a log file
#
# USAGE EXAMPLES:
#   .\Run-TestsWithLogging.ps1 -All                    # Run all tests with logging
#   .\Run-TestsWithLogging.ps1 -TestFiles "01-BasicFunctionality.ps1" # Run specific test with logging
#   .\Run-TestsWithLogging.ps1 -All -NoConsole        # Run tests silently (log only, no console output)
#   .\Run-TestsWithLogging.ps1 -Cleanup -All          # Clean and run all tests with logging
#
# OUTPUT:
#   - Console output is both displayed and saved to test-output/test-run-console-YYYY-MM-DD_HH-mm-ss.log
#   - With -NoConsole, output is only saved to log (silent mode)
#   - Exit code matches RunAllTests.ps1 exit code (0 = success, 1 = failure)
#
# FEATURES:
#   - Captures ALL console output streams (*>&1)
#   - Timestamped log files for each run
#   - Passes through all parameters to RunAllTests.ps1
#   - Shows clear header and footer with log file location
#   - Preserves exit codes for CI/CD integration

param(
    [string[]]$TestFiles = @(),
    [switch]$All,
    [switch]$Cleanup,
    [switch]$Help,
    [switch]$NoLog,
    [switch]$NoConsole
)

# Generate timestamp for log file
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFileName = "test-run-console-$timestamp.log"

# Ensure test-output directory exists
$testOutputDir = Join-Path $PSScriptRoot "test-output"
if (-not (Test-Path $testOutputDir)) {
    New-Item -ItemType Directory -Path $testOutputDir -Force | Out-Null
}

$logFilePath = Join-Path $testOutputDir $logFileName

# Build the command to run RunAllTests.ps1
$runAllTestsPath = Join-Path $PSScriptRoot "RunAllTests.ps1"
$commandArgs = @()

if ($TestFiles.Count -gt 0) {
    $commandArgs += "-TestFiles"
    $commandArgs += ($TestFiles -join ",")
}

if ($All) {
    $commandArgs += "-All"
}

if ($Cleanup) {
    $commandArgs += "-Cleanup"
}

if ($Help) {
    $commandArgs += "-Help"
}

if ($NoLog) {
    $commandArgs += "-NoLog"
}

# Show header
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Run All Tests with Console Output Logging" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Script: $runAllTestsPath" -ForegroundColor Gray
Write-Host "Log File: $logFilePath" -ForegroundColor Gray
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Execute RunAllTests.ps1 and capture all output
try {
    if ($NoConsole) {
        # Run without showing console output (log only)
        Write-Host "Running tests silently (output to log only)..." -ForegroundColor Yellow
        Write-Host ""
        
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $runAllTestsPath @commandArgs *>&1 | 
            Out-File -FilePath $logFilePath -Encoding UTF8
        
        $exitCode = $LASTEXITCODE
        
        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "Tests completed with exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
        Write-Host "Full output saved to: $logFilePath" -ForegroundColor Gray
        Write-Host "=================================================================" -ForegroundColor Cyan
    } else {
        # Run with both console output and logging
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $runAllTestsPath @commandArgs *>&1 | 
            Tee-Object -FilePath $logFilePath
        
        $exitCode = $LASTEXITCODE
        
        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "Tests completed with exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
        Write-Host "Console output saved to: $logFilePath" -ForegroundColor Gray
        Write-Host "=================================================================" -ForegroundColor Cyan
    }
    
    # Return the exit code from RunAllTests.ps1
    exit $exitCode
    
} catch {
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Red
    Write-Host "Error running tests: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "=================================================================" -ForegroundColor Red
    exit 1
}

