# Run All Tests with Console Output Logging
# Wrapper script that executes RunAllTests.ps1 and captures all console output to a log file
#
# USAGE EXAMPLES:
#   .\Run-TestsWithLogging.ps1 -All                    # Run all tests with logging (foreground)
#   .\Run-TestsWithLogging.ps1 -All -Background        # Run all tests in background job
#   .\Run-TestsWithLogging.ps1 -Status                 # Show status of running test jobs
#   .\Run-TestsWithLogging.ps1 -Monitor                # Monitor running test job in real-time
#   .\Run-TestsWithLogging.ps1 -Stop                   # Stop running test job
#   .\Run-TestsWithLogging.ps1 -GetResults             # Get results from completed job
#   .\Run-TestsWithLogging.ps1 -CleanupJobs            # Clean up completed/failed jobs
#   .\Run-TestsWithLogging.ps1 -ViewLog                # View the latest console log file
#
# BACKGROUND JOB EXAMPLES:
#   .\Run-TestsWithLogging.ps1 -All -Background        # Start tests in background
#   .\Run-TestsWithLogging.ps1 -Monitor                # Watch progress
#   .\Run-TestsWithLogging.ps1 -Stop                   # Stop if needed
#   .\Run-TestsWithLogging.ps1 -GetResults             # Get final results
#
# OUTPUT:
#   - Console output is both displayed and saved to test-output/test-run-console-YYYY-MM-DD_HH-mm-ss.log
#   - With -NoConsole, output is only saved to log (silent mode)
#   - Exit code matches RunAllTests.ps1 exit code (0 = success, 1 = failure)
#
# FEATURES:
#   - Run tests in foreground or background
#   - Monitor running jobs in real-time
#   - Stop running jobs gracefully
#   - View results from completed jobs
#   - Clean up completed jobs
#   - Captures ALL console output streams (*>&1)
#   - Timestamped log files for each run

param(
    [string[]]$TestFiles = @(),
    [switch]$All,
    [switch]$Cleanup,
    [switch]$Help,
    [switch]$NoLog,
    [switch]$NoConsole,
    # Job management parameters
    [switch]$Background,
    [switch]$Status,
    [switch]$Monitor,
    [switch]$Stop,
    [switch]$GetResults,
    [switch]$CleanupJobs,
    [switch]$ViewLog
)

# Job name for test runs
$jobName = "RunAllTests"

# Ensure test-output directory exists
$testOutputDir = Join-Path $PSScriptRoot "test-output"
if (-not (Test-Path $testOutputDir)) {
    New-Item -ItemType Directory -Path $testOutputDir -Force | Out-Null
}

# Helper function to get test job
function Get-TestJob {
    return Get-Job -Name $jobName -ErrorAction SilentlyContinue
}

# Helper function to show job status
function Show-JobStatus {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Test Job Status" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    
    $job = Get-TestJob
    
    if ($null -eq $job) {
        Write-Host "No test job found (name: $jobName)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Start a background test job with:" -ForegroundColor Gray
        Write-Host "  .\Run-TestsWithLogging.ps1 -All -Background" -ForegroundColor Gray
    } else {
        Write-Host "Job Name: $($job.Name)" -ForegroundColor White
        Write-Host "Job ID: $($job.Id)" -ForegroundColor White
        Write-Host "State: $($job.State)" -ForegroundColor $(
            switch ($job.State) {
                "Running" { "Green" }
                "Completed" { "Cyan" }
                "Failed" { "Red" }
                default { "Yellow" }
            }
        )
        Write-Host "Has Data: $($job.HasMoreData)" -ForegroundColor White
        Write-Host "Started: $($job.PSBeginTime)" -ForegroundColor Gray
        
        if ($job.State -eq "Completed" -or $job.State -eq "Failed") {
            Write-Host "Finished: $($job.PSEndTime)" -ForegroundColor Gray
            $duration = $job.PSEndTime - $job.PSBeginTime
            Write-Host "Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
        }
    }
    
    Write-Host "=================================================================" -ForegroundColor Cyan
}

# Helper function to monitor job in real-time
function Monitor-TestJob {
    $job = Get-TestJob
    
    if ($null -eq $job) {
        Write-Host "No test job found to monitor" -ForegroundColor Red
        return
    }
    
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Monitoring Test Job (Ctrl+C to stop monitoring)" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        while ($job.State -eq "Running") {
            # Get any new output
            $output = Receive-Job -Job $job -Keep
            if ($output) {
                $output | ForEach-Object { Write-Host $_ }
            }
            
            Start-Sleep -Seconds 2
            $job = Get-TestJob
        }
        
        # Get final output
        $finalOutput = Receive-Job -Job $job
        if ($finalOutput) {
            $finalOutput | ForEach-Object { Write-Host $_ }
        }
        
        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "Job completed with state: $($job.State)" -ForegroundColor $(
            if ($job.State -eq "Completed") { "Green" } else { "Red" }
        )
        Write-Host "=================================================================" -ForegroundColor Cyan
        
    } catch {
        Write-Host ""
        Write-Host "Monitoring stopped" -ForegroundColor Yellow
    }
}

# Helper function to stop test job
function Stop-TestJob {
    $job = Get-TestJob
    
    if ($null -eq $job) {
        Write-Host "No test job found to stop" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Stopping test job..." -ForegroundColor Yellow
    Stop-Job -Job $job
    
    Write-Host "Test job stopped" -ForegroundColor Green
    Write-Host ""
    Write-Host "Use -GetResults to see partial results" -ForegroundColor Gray
    Write-Host "Use -CleanupJobs to remove the stopped job" -ForegroundColor Gray
}

# Helper function to get job results
function Get-TestJobResults {
    $job = Get-TestJob
    
    if ($null -eq $job) {
        Write-Host "No test job found" -ForegroundColor Yellow
        return
    }
    
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Test Job Results" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Job State: $($job.State)" -ForegroundColor White
    Write-Host ""
    
    $output = Receive-Job -Job $job
    if ($output) {
        $output | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No output available" -ForegroundColor Yellow
    }
}

# Helper function to cleanup completed jobs
function Cleanup-TestJobs {
    $jobs = Get-Job | Where-Object { $_.Name -eq $jobName }
    
    if ($jobs.Count -eq 0) {
        Write-Host "No test jobs to clean up" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Cleaning up test jobs..." -ForegroundColor Yellow
    
    foreach ($job in $jobs) {
        Write-Host "  Removing job $($job.Id) ($($job.State))" -ForegroundColor Gray
        Remove-Job -Job $job -Force
    }
    
    Write-Host "Cleanup complete" -ForegroundColor Green
}

# Helper function to view latest log
function View-LatestLog {
    $logFiles = Get-ChildItem -Path $testOutputDir -Filter "test-run-console-*.log" | 
        Sort-Object LastWriteTime -Descending
    
    if ($logFiles.Count -eq 0) {
        Write-Host "No log files found in $testOutputDir" -ForegroundColor Yellow
        return
    }
    
    $latestLog = $logFiles[0]
    
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Latest Test Log" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "File: $($latestLog.FullName)" -ForegroundColor White
    Write-Host "Size: $($latestLog.Length) bytes" -ForegroundColor White
    Write-Host "Modified: $($latestLog.LastWriteTime)" -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Get-Content $latestLog.FullName
}

# Handle job management commands first
if ($Status) {
    Show-JobStatus
    exit 0
}

if ($Monitor) {
    Monitor-TestJob
    exit 0
}

if ($Stop) {
    Stop-TestJob
    exit 0
}

if ($GetResults) {
    Get-TestJobResults
    exit 0
}

if ($CleanupJobs) {
    Cleanup-TestJobs
    exit 0
}

if ($ViewLog) {
    View-LatestLog
    exit 0
}

# If no test execution parameters provided, show help
if (-not ($All -or $TestFiles.Count -gt 0 -or $Help)) {
    Write-Host "No operation specified. Use -Help for usage information." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quick commands:" -ForegroundColor Cyan
    Write-Host "  -All              Run all tests" -ForegroundColor Gray
    Write-Host "  -Status           Show job status" -ForegroundColor Gray
    Write-Host "  -Monitor          Monitor running job" -ForegroundColor Gray
    Write-Host "  -Help             Show full help" -ForegroundColor Gray
    exit 0
}

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

# Generate timestamp and log file path
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFileName = "test-run-console-$timestamp.log"
$logFilePath = Join-Path $testOutputDir $logFileName

# Handle background execution
if ($Background) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Starting Tests in Background" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if job already exists
    $existingJob = Get-TestJob
    if ($null -ne $existingJob -and $existingJob.State -eq "Running") {
        Write-Host "A test job is already running!" -ForegroundColor Red
        Write-Host "Job ID: $($existingJob.Id)" -ForegroundColor Yellow
        Write-Host "State: $($existingJob.State)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Use -Stop to stop the current job first" -ForegroundColor Gray
        exit 1
    }
    
    # Remove any old completed jobs
    Get-Job -Name $jobName -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
    
    # Start the job
    $job = Start-Job -Name $jobName -ScriptBlock {
        param($scriptPath, $cmdArgs, $logPath)
        
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath @cmdArgs *>&1 |
            Tee-Object -FilePath $logPath
            
    } -ArgumentList $runAllTestsPath, $commandArgs, $logFilePath
    
    Write-Host "Test job started successfully!" -ForegroundColor Green
    Write-Host "Job Name: $jobName" -ForegroundColor White
    Write-Host "Job ID: $($job.Id)" -ForegroundColor White
    Write-Host "Log File: $logFilePath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Management commands:" -ForegroundColor Cyan
    Write-Host "  .\Run-TestsWithLogging.ps1 -Status       # Show job status" -ForegroundColor Gray
    Write-Host "  .\Run-TestsWithLogging.ps1 -Monitor      # Monitor in real-time" -ForegroundColor Gray
    Write-Host "  .\Run-TestsWithLogging.ps1 -Stop         # Stop the job" -ForegroundColor Gray
    Write-Host "  .\Run-TestsWithLogging.ps1 -GetResults   # Get results when complete" -ForegroundColor Gray
    Write-Host "  .\Run-TestsWithLogging.ps1 -ViewLog      # View the log file" -ForegroundColor Gray
    Write-Host ""
    
    exit 0
}

# Foreground execution
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
