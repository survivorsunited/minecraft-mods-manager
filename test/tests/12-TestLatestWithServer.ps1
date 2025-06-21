# Test Latest Mods with Server Startup
# Tests the complete workflow: download latest mods, download server files, add start script, and attempt server startup

param([string]$TestFileName = $null)

# Import test framework
$TestFrameworkPath = Join-Path $PSScriptRoot "..\TestFramework.ps1"
. $TestFrameworkPath

# Test configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$ModListPath = Join-Path $PSScriptRoot "..\..\modlist.csv"
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\12-TestLatestWithServer"
$TestDownloadDir = Join-Path $TestOutputDir "download"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Test variables
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0
$TestReport = @()

# Test report file
$TestReportPath = Join-Path $TestOutputDir "latest-with-server-test-report.txt"

function Test-LatestWithServer {
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

Write-Host "Starting Test Latest Mods with Server Startup" -ForegroundColor Yellow
Write-Host "Test Output Directory: $TestOutputDir" -ForegroundColor Gray
Write-Host ""

# Test 1: Validate all mods first
Write-Host "=== Step 1: Validating All Mods ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Validate All Mods" -TestScript {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -UseCachedResponses -DatabaseFile $ModListPath
} -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

# Test 2: Download latest mods to isolated folder
Write-Host "=== Step 2: Downloading Latest Mods ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Download Latest Mods" -TestScript {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadMods -DatabaseFile $ModListPath -DownloadFolder $TestDownloadDir -UseCachedResponses
} -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

# Test 3: Download server files to the same isolated folder
Write-Host "=== Step 3: Downloading Server Files ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Download Server Files" -TestScript {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadServer -DownloadFolder $TestDownloadDir -UseCachedResponses
} -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

# Test 4: Add server start script to the download folder
Write-Host "=== Step 4: Adding Server Start Script ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Add Server Start Script" -TestScript {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddServerStartScript -DownloadFolder $TestDownloadDir
} -ExpectedOutput "Successfully copied start-server script" -ExpectedExitCode 0

# Test 5: Attempt to start server (this should fail with mod compatibility issues)
Write-Host "=== Step 5: Attempting Server Startup (Expected to Fail) ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Server Startup with Latest Mods" -TestScript {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -StartServer -DownloadFolder $TestDownloadDir
} -ExpectedOutput "Errors detected|Server job failed|Java version" -ExpectedExitCode 1

# Test 6: Verify mod compatibility issues
Write-Host "=== Step 6: Verifying Mod Compatibility Issues ===" -ForegroundColor Magenta
Test-LatestWithServer -TestName "Mod Compatibility Verification" -TestScript {
    # Run in separate PowerShell process to isolate exit codes
    $script = {
        param($ModListPath)
        # Check the modlist.csv for potential compatibility issues
        if (Test-Path $ModListPath) {
            $mods = Import-Csv $ModListPath
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
    }
    
    & pwsh -NoProfile -ExecutionPolicy Bypass -Command $script -args $ModListPath
} -ExpectedOutput "Version mismatch|Game version mismatch" -ExpectedExitCode 0

# Final check: Ensure test/download is empty or does not exist
Write-Host "=== Final Step: Verifying test/download is untouched ===" -ForegroundColor Magenta
$TotalTests++  # Increment total test count for this check
$testDownloadPath = Join-Path $PSScriptRoot "..\download"
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
- Server file downloads should succeed
- Server start script should be added successfully
- Server startup should fail with compatibility errors
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

# NOTE: Download folders are intentionally preserved for post-test validation.

# Return exit code based on test results
if ($FailedTests -eq 0) {
    Write-Host "All latest mods with server tests passed! 🎉" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some latest mods with server tests failed! ❌" -ForegroundColor Red
    exit 1
} 