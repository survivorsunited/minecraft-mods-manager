# Test Latest Mods with Server Startup
# Tests downloading latest mods and attempting server startup to detect mod compatibility issues

param([string]$TestFileName = $null)

# Get the test root directory (parent of the tests folder)
$TestRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$TestOutputDir = Join-Path $TestRoot "test\test-output\12-TestLatestWithServer"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Test configuration
$ModManagerPath = Join-Path $TestRoot "ModManager.ps1"
$ModListPath = Join-Path $TestRoot "modlist.csv"
$TestReportPath = Join-Path $TestOutputDir "latest-with-server-test-report.txt"

# Test counters
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0
$TestReport = @()

# Test name
$TestName = "Test Latest Mods with Server Startup"

# Import test framework
. "$PSScriptRoot/../TestFramework.ps1"

# Test configuration
$TestDescription = "Downloads latest mods and attempts to start server to test for compatibility failures"
$TestReportPath = Join-Path $TestOutputDir "latest-with-server-test-report.txt"

# Initialize test report
$TestReport = @"
Test Latest Mods with Server Startup Test Report
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Test Output Directory: $TestOutputDir

"@

# Helper function to run test
function Test-LatestWithServer {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$ExpectedOutput = $null,
        [string]$ExpectedError = $null,
        [int]$ExpectedExitCode = 0
    )
    
    $TotalTests++
    Write-Host "Testing: $TestName" -ForegroundColor Cyan
    
    try {
        $result = & $TestScript 2>&1
        $exitCode = $LASTEXITCODE
        
        $success = $true
        $errorMessage = ""
        
        # Check exit code
        if ($exitCode -ne $ExpectedExitCode) {
            $success = $false
            $errorMessage = "Exit code mismatch. Expected: $ExpectedExitCode, Got: $exitCode"
        }
        
        # Check for expected output
        if ($ExpectedOutput) {
            $resultString = $result -join "`n"
            if ($resultString -notmatch $ExpectedOutput) {
                $success = $false
                $errorMessage = "Expected output not found: $ExpectedOutput"
            }
        }
        
        # Check for expected error
        if ($ExpectedError) {
            $resultString = $result -join "`n"
            if ($resultString -notmatch $ExpectedError) {
                $success = $false
                $errorMessage = "Expected error not found: $ExpectedError"
            }
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
        
        # Log output for debugging - ensure directory exists
        $outputLogPath = Join-Path $TestOutputDir "$($TestName -replace '[^a-zA-Z0-9]', '_').log"
        $result | Out-File -FilePath $outputLogPath -Encoding UTF8
        
    } catch {
        Write-Host "  ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $FailedTests++
        $TestReport += "❌ ERROR: $TestName - $($_.Exception.Message)`n"
    }
    
    Write-Host ""
}

Write-Host "Starting $TestName" -ForegroundColor Yellow
Write-Host "Test Output Directory: $TestOutputDir" -ForegroundColor Gray
Write-Host ""

# Test 1: Validate all mods first
Write-Host "=== Step 1: Validating All Mods ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Validate All Mods" -TestScript {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -UseCachedResponses -DatabaseFile $ModListPath
} -ExpectedOutput "Minecraft Mod Manager PowerShell Script"

# Test 2: Download latest mods to isolated folder
Write-Host "=== Step 2: Downloading Latest Mods ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Download Latest Mods" -TestScript {
    # Create isolated download folder for this test
    $isolatedDownloadDir = Join-Path $TestOutputDir "download-latest-mods"
    if (-not (Test-Path $isolatedDownloadDir)) {
        New-Item -ItemType Directory -Path $isolatedDownloadDir -Force | Out-Null
    }
    
    # Copy modlist.csv to isolated folder
    Copy-Item -Path $ModListPath -Destination $isolatedDownloadDir -Force
    
    # Run download from the test directory (not from isolated folder)
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadMods -DatabaseFile $ModListPath -DownloadFolder $isolatedDownloadDir -UseCachedResponses
} -ExpectedOutput "Minecraft Mod Manager PowerShell Script"

# Test 3: Download server files to isolated folder
Write-Host "=== Step 3: Downloading Server Files ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Download Server Files" -TestScript {
    # Create isolated download folder for server files
    $isolatedServerDir = Join-Path $TestOutputDir "download-server-files"
    if (-not (Test-Path $isolatedServerDir)) {
        New-Item -ItemType Directory -Path $isolatedServerDir -Force | Out-Null
    }
    
    # Run server download from the test directory
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadServer -DownloadFolder $isolatedServerDir -UseCachedResponses
} -ExpectedOutput "Minecraft Mod Manager PowerShell Script"

# Test 4: Attempt to start server (this should fail with mod compatibility issues)
Write-Host "=== Step 4: Attempting Server Startup (Expected to Fail) ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Server Startup with Latest Mods" -TestScript {
    # Create a temporary server directory for testing
    $tempServerDir = Join-Path $TestOutputDir "temp-server"
    if (-not (Test-Path $tempServerDir)) {
        New-Item -ItemType Directory -Path $tempServerDir -Force | Out-Null
    }
    
    # Copy mods from isolated download folder
    $modsDownloadDir = Join-Path $TestOutputDir "download-latest-mods"
    if (Test-Path $modsDownloadDir) {
        Copy-Item -Path "$modsDownloadDir\*" -Destination $tempServerDir -Recurse -Force
    }
    
    # Copy server files from isolated server folder
    $serverDownloadDir = Join-Path $TestOutputDir "download-server-files"
    if (Test-Path $serverDownloadDir) {
        Copy-Item -Path "$serverDownloadDir\*" -Destination $tempServerDir -Recurse -Force
    }
    
    # Change to temp directory and start server
    Push-Location $tempServerDir
    
    try {
        # Start server with timeout to prevent hanging
        $startServerPath = Join-Path (Join-Path $PSScriptRoot '../..') 'tools/start-server.ps1'
        $job = Start-Job -ScriptBlock {
            param($ServerDir, $StartServerPath)
            Set-Location $ServerDir
            & $StartServerPath
        } -ArgumentList $tempServerDir, $startServerPath
        
        # Wait for up to 60 seconds for the server to start and potentially fail
        $timeout = 60
        $startTime = Get-Date
        $serverOutput = ""
        
        while ((Get-Date) -lt ($startTime.AddSeconds($timeout))) {
            if ($job.State -eq "Completed") {
                $serverOutput = Receive-Job $job
                break
            }
            Start-Sleep -Seconds 2
        }
        
        # Stop the job if it's still running
        if ($job.State -eq "Running") {
            Stop-Job $job
            Remove-Job $job
            $serverOutput = "Server startup timed out after $timeout seconds"
        } else {
            Remove-Job $job
        }
        
        # Return the output
        $serverOutput
        
    } finally {
        Pop-Location
    }
} -ExpectedError "SERVER ERROR DETECTED|exit code 1|potential solution" -ExpectedExitCode 1

# Test 5: Check for specific error patterns in server logs
Write-Host "=== Step 5: Analyzing Server Error Patterns ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Server Error Pattern Analysis" -TestScript {
    # Look for server log files in the temp server directory
    $tempServerDir = Join-Path $TestOutputDir "temp-server"
    $logFiles = Get-ChildItem -Path $tempServerDir -Filter "*.log" -Recurse -ErrorAction SilentlyContinue
    
    $analysis = @()
    foreach ($logFile in $logFiles) {
        $logContent = Get-Content -Path $logFile.FullName -Raw -ErrorAction SilentlyContinue
        if ($logContent) {
            # Look for specific error patterns
            $patterns = @(
                "A potential solution has been determined",
                "Server exited with code 1",
                "mod compatibility",
                "version mismatch",
                "fabric-api",
                "modrinth"
            )
            
            foreach ($pattern in $patterns) {
                if ($logContent -match $pattern) {
                    $analysis += "Found '$pattern' in $($logFile.Name)"
                }
            }
        }
    }
    
    if ($analysis.Count -gt 0) {
        $analysis -join "`n"
    } else {
        "No specific error patterns found in server logs"
    }
} -ExpectedOutput "Found.*Server exited with code 1"

# Test 6: Verify mod compatibility issues
Write-Host "=== Step 6: Verifying Mod Compatibility Issues ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Mod Compatibility Verification" -TestScript {
    # Check the modlist.csv for potential compatibility issues
    $modlistPath = $ModListPath
    if (Test-Path $modlistPath) {
        $mods = Import-Csv $modlistPath
        $issues = @()
        
        foreach ($mod in $mods) {
            # Check for version mismatches
            if ($mod.Version -and $mod.LatestVersion -and $mod.Version -ne $mod.LatestVersion) {
                $issues += "Version mismatch for $($mod.Name): Current=$($mod.Version), Latest=$($mod.LatestVersion)"
            }
            
            # Check for game version mismatches
            if ($mod.GameVersion -and $mod.LatestGameVersion -and $mod.GameVersion -ne $mod.LatestGameVersion) {
                $issues += "Game version mismatch for $($mod.Name): Current=$($mod.GameVersion), Latest=$($mod.LatestGameVersion)"
            }
        }
        
        if ($issues.Count -gt 0) {
            $issues -join "`n"
        } else {
            "No obvious compatibility issues found in modlist.csv"
        }
    } else {
        "modlist.csv not found"
    }
} -ExpectedOutput "Version mismatch|Game version mismatch" -ExpectedExitCode 0

# Final check: Ensure test/download is empty or does not exist
Write-Host "=== Final Step: Verifying test/download is untouched ===" -ForegroundColor Magenta
$testDownloadPath = Join-Path $TestRoot "test\download"
if (Test-Path $testDownloadPath) {
    $downloadContents = Get-ChildItem -Path $testDownloadPath -Recurse -File -ErrorAction SilentlyContinue
    if ($downloadContents.Count -gt 0) {
        Write-Host "  ❌ FAIL: test/download is not empty!" -ForegroundColor Red
        $FailedTests++
        $TestReport += "❌ FAIL: test/download is not empty!`n"
    } else {
        Write-Host "  ✅ PASS: test/download is empty" -ForegroundColor Green
        $PassedTests++
        $TestReport += "✅ PASS: test/download is empty`n"
    }
} else {
    Write-Host "  ✅ PASS: test/download does not exist" -ForegroundColor Green
    $PassedTests++
    $TestReport += "✅ PASS: test/download does not exist`n"
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
This test validates the complete workflow of downloading latest mods and attempting server startup.
The server startup is expected to fail due to mod compatibility issues, which validates our error detection.

Expected Behavior:
- Mod validation should succeed
- Latest mod downloads should succeed  
- Server startup should fail with compatibility errors
- Error patterns should be detected in server logs
- Mod compatibility issues should be identified

"@

# Save test report
$TestReport | Out-File -FilePath $TestReportPath -Encoding UTF8

# Display summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Yellow
Write-Host "Total Tests: $TotalTests" -ForegroundColor White
Write-Host "Passed: $PassedTests" -ForegroundColor Green
Write-Host "Failed: $FailedTests" -ForegroundColor Red
Write-Host "Success Rate: $(if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 2) } else { 0 })%" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test report saved to: $TestReportPath" -ForegroundColor Gray
Write-Host "Individual test logs saved to: $TestOutputDir" -ForegroundColor Gray

# Cleanup temp server directory only (preserve downloads for validation)
$tempServerDir = Join-Path $TestOutputDir "temp-server"
if (Test-Path $tempServerDir) {
    Write-Host "Cleaning up: $tempServerDir" -ForegroundColor Gray
    Remove-Item -Path $tempServerDir -Recurse -Force -ErrorAction SilentlyContinue
}
# NOTE: Download folders are intentionally preserved for post-test validation.

# Return exit code based on test results
if ($FailedTests -eq 0) {
    Write-Host "All latest mods with server tests passed! 🎉" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some latest mods with server tests failed! ❌" -ForegroundColor Red
    exit 1
} 