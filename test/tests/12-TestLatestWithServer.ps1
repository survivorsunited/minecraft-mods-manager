# Test Latest Mods with Server Startup
# Tests the complete workflow: download latest mods, download server files, add start script, and attempt server startup

param([string]$TestFileName = $null)

# Import test framework
$TestFrameworkPath = Join-Path $PSScriptRoot "..\TestFramework.ps1"
. $TestFrameworkPath

# Test configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\12-TestLatestWithServer"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$RootModListPath = Join-Path $PSScriptRoot "..\..\modlist.csv"
$TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Initialize test environment with logging
Initialize-TestEnvironment

# Copy the root modlist to the test directory AFTER environment initialization
if (Test-Path $RootModListPath) {
    Copy-Item -Path $RootModListPath -Destination $TestModListPath -Force
    Write-Host "Copied root modlist to test directory: $TestModListPath" -ForegroundColor Green
} else {
    Write-Host "ERROR: Root modlist not found at $RootModListPath" -ForegroundColor Red
    exit 1
}

# Initialize test results at script level
$script:TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
}

# Initialize test counters
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0
$script:TestReport = @()

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
            $script:TestResults.Passed++
            $script:TestReport += "✅ PASS: $TestName`n"
        } else {
            Write-Host "  ❌ FAIL: $errorMessage" -ForegroundColor Red
            $script:FailedTests++
            $script:TestResults.Failed++
            $script:TestReport += "❌ FAIL: $TestName - $errorMessage`n"
        }
        
    } catch {
        Write-Host "  ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $script:FailedTests++
        $script:TestResults.Failed++
        $script:TestReport += "❌ ERROR: $TestName - $($_.Exception.Message)`n"
    }
    
    Write-Host ""
}

function Invoke-TestLatestWithServer {
    param([string]$TestFileName = $null)
    
    Write-Host "Starting Test Latest Mods with Server Startup" -ForegroundColor Yellow
    Write-Host "Test Output Directory: $TestOutputDir" -ForegroundColor Gray
    Write-Host "Test ModList: $TestModListPath" -ForegroundColor Gray
    Write-Host "Root ModList: $RootModListPath" -ForegroundColor Gray
    Write-Host ""

    # Test 1: Validate all mods first
    Write-Host "=== Step 1: Validating All Mods ===" -ForegroundColor Magenta
    Test-LatestWithServer -TestName "Validate All Mods" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -UseCachedResponses -DatabaseFile $TestModListPath
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Test 2: Update mods to latest versions
    Write-Host "=== Step 2: Updating Mods to Latest Versions ===" -ForegroundColor Magenta
    Test-LatestWithServer -TestName "Update Mods to Latest" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $TestModListPath -UseCachedResponses
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Test 3: Download everything (mods and server files) to the same folder
    Write-Host "=== Step 3: Downloading Everything to Same Folder ===" -ForegroundColor Magenta
    Test-LatestWithServer -TestName "Download Everything" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Download -UseLatestVersion -DownloadFolder $TestDownloadDir -DatabaseFile $TestModListPath -UseCachedResponses
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Test 4: Download server files to the same folder (in case they weren't included)
    Write-Host "=== Step 4: Downloading Server Files ===" -ForegroundColor Magenta
    Test-LatestWithServer -TestName "Download Server Files" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadServer -DownloadFolder $TestDownloadDir -UseCachedResponses
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Test 5: Add server start script to the download folder
    Write-Host "=== Step 5: Adding Server Start Script ===" -ForegroundColor Magenta
    Test-LatestWithServer -TestName "Add Server Start Script" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddServerStartScript -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Successfully copied start-server script" -ExpectedExitCode 0

    # Test 6: Attempt to start server (this should fail due to mod compatibility issues)
    Write-Host "=== Step 6: Attempting Server Startup (Expected to Fail) ===" -ForegroundColor Magenta
    Test-LatestWithServer -TestName "Server Startup with Latest Mods" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -StartServer -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Server started successfully|Server is running|Failed to start server|Error|Exception" -ExpectedExitCode 1

    # Test 7: Analyze and report mod compatibility issues as expected errors
    Write-Host "=== Step 7: Analyzing Mod Compatibility Issues (Expected) ===" -ForegroundColor Magenta
    
    # First, create the compatibility analysis log file
    $serverLogPath = Join-Path $TestDownloadDir "1.21.6\logs\console-*.log"
    $logFiles = Get-ChildItem -Path $serverLogPath -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    
    if ($logFiles.Count -gt 0) {
        $latestLog = $logFiles[0]
        $logContent = Get-Content $latestLog.FullName -Raw
        
        # Check for error markers
        $hasModResolutionFailed = $logContent -match "Mod resolution failed"
        $hasIncompatibleMods = $logContent -match "Incompatible mods found!"
        
        if ($hasModResolutionFailed -and $hasIncompatibleMods) {
            # Extract solution section using string operations
            $solutionSection = ""
            $solutionStart = $logContent.IndexOf("A potential solution has been determined, this may resolve your problem:")
            $solutionEnd = $logContent.IndexOf("More details:")
            
            if ($solutionStart -ge 0 -and $solutionEnd -ge 0 -and $solutionStart -lt $solutionEnd) {
                $solutionSection = $logContent.Substring($solutionStart + "A potential solution has been determined, this may resolve your problem:".Length, $solutionEnd - $solutionStart - "A potential solution has been determined, this may resolve your problem:".Length).Trim()
            }
            
            # Extract details section using string operations
            $detailsSection = ""
            $detailsStart = $logContent.IndexOf("More details:")
            $detailsEnd = $logContent.IndexOf("--- Server exited with code 1")
            
            if ($detailsStart -ge 0 -and $detailsEnd -ge 0 -and $detailsStart -lt $detailsEnd) {
                $detailsSection = $logContent.Substring($detailsStart + "More details:".Length, $detailsEnd - $detailsStart - "More details:".Length).Trim()
            }
            
            # Parse solution section
            $installCommands = @()
            $removeMods = @()
            $replaceMods = @()
            
            if ($solutionSection) {
                # Split into lines and parse each line
                $solutionLines = $solutionSection -split "`n"
                foreach ($line in $solutionLines) {
                    $line = $line.Trim()
                    if ($line -match "Install fabric-api, version ([^`n]+)") {
                        $installCommands += "fabric-api $($matches[1])"
                    }
                    elseif ($line -match "Install fabric, version ([^`n]+)") {
                        $installCommands += "fabric $($matches[1])"
                    }
                    elseif ($line -match "Remove mod '([^']+)'") {
                        $removeMods += $matches[1]
                    }
                    elseif ($line -match "Replace mod '([^']+)'") {
                        $replaceMods += $matches[1]
                    }
                }
            }
            
            # Parse details section
            $detailedIssues = @()
            
            if ($detailsSection) {
                # Split into lines and parse each line
                $detailLines = $detailsSection -split "`n"
                foreach ($line in $detailLines) {
                    $line = $line.Trim()
                    # Improved regex to catch all error patterns
                    if ($line -match "Mod '([^']+)' \([^)]+\) ([^!]+)!") {
                        $modName = $matches[1]
                        $issue = $matches[2].Trim()
                        $detailedIssues += "- Mod '$modName': $issue"
                    }
                    # Also catch the alternative pattern without parentheses
                    elseif ($line -match "Mod '([^']+)' ([^!]+)!") {
                        $modName = $matches[1]
                        $issue = $matches[2].Trim()
                        $detailedIssues += "- Mod '$modName': $issue"
                    }
                }
            }
            
            # Build comprehensive report
            $report = @()
            $report += "COMPATIBILITY ERRORS FOUND:"
            
            if ($installCommands.Count -gt 0 -or $removeMods.Count -gt 0 -or $replaceMods.Count -gt 0) {
                $report += ""
                $report += "SOLUTION REQUIRED:"
                if ($installCommands.Count -gt 0) {
                    $report += "- Install: " + ($installCommands -join ", ")
                }
                if ($removeMods.Count -gt 0) {
                    $report += "- Remove: " + ($removeMods -join ", ")
                }
                if ($replaceMods.Count -gt 0) {
                    $report += "- Replace: " + ($replaceMods -join ", ")
                }
            }
            
            if ($detailedIssues.Count -gt 0) {
                $report += ""
                $report += "DETAILED ISSUES:"
                $report += $detailedIssues
            }
            
            $fullReport = $report -join "`n"
            
            # Save to log file
            $compatibilityLogPath = Join-Path $TestOutputDir "Mod_Compatibility_Analysis.log"
            $fullReport | Out-File -FilePath $compatibilityLogPath -Encoding UTF8
        }
    }
    
    Test-LatestWithServer -TestName "Mod Compatibility Analysis" -TestScript {
        # Just output the compatibility analysis log file content
        $compatibilityLogPath = Join-Path $TestOutputDir "Mod_Compatibility_Analysis.log"
        
        if (Test-Path $compatibilityLogPath) {
            $logContent = Get-Content $compatibilityLogPath -Raw
            
            # Output to terminal so it's visible
            Write-Host "`nCOMPATIBILITY ANALYSIS RESULTS:" -ForegroundColor Yellow
            Write-Host "==============================" -ForegroundColor Yellow
            Write-Host $logContent -ForegroundColor Red
            Write-Host "==============================" -ForegroundColor Yellow
            Write-Host ""
            
            $logContent
        } else {
            "No compatibility analysis log found"
        }
    } -ExpectedOutput "No compatibility issues found" -ExpectedExitCode 0

    # Final check: Ensure test/download is empty or does not exist
    Write-Host "=== Final Step: Verifying test/download is untouched ===" -ForegroundColor Magenta
    $script:TotalTests++  # Increment total test count for this check
    $mainTestDownloadPath = Join-Path $PSScriptRoot "..\download"
    if (Test-Path $mainTestDownloadPath) {
        $downloadContents = Get-ChildItem -Path $mainTestDownloadPath -Recurse -File -ErrorAction SilentlyContinue
        if ($downloadContents.Count -gt 0) {
            Write-Host "  ❌ FAIL: main test/download is not empty!" -ForegroundColor Red
            $script:FailedTests++
            $script:TestResults.Failed++
            $script:TestReport += "❌ FAIL: main test/download is not empty!`n"
        } else {
            Write-Host "  ✅ PASS: main test/download is empty" -ForegroundColor Green
            $script:PassedTests++
            $script:TestResults.Passed++
            $script:TestReport += "✅ PASS: main test/download is empty`n"
        }
    } else {
        Write-Host "  ✅ PASS: main test/download does not exist" -ForegroundColor Green
        $script:PassedTests++
        $script:TestResults.Passed++
        $script:TestReport += "✅ PASS: main test/download does not exist`n"
    }

    # Generate final report
    $script:TestReport += @"

Test Summary:
=============
Total Tests: $($script:TotalTests)
Passed: $($script:PassedTests)
Failed: $($script:FailedTests)
Success Rate: $(if ($script:TotalTests -gt 0) { [math]::Round(($script:PassedTests / $script:TotalTests) * 100, 2) } else { 0 })%

Test Details:
=============
This test validates the complete workflow of downloading latest mods and attempting server startup.
The test uses the full modlist from the root directory to ensure comprehensive testing.

Expected Behavior:
- Mod validation should succeed
- Latest mod downloads should succeed  
- Server file downloads should succeed
- Server start script should be added successfully
- Server startup should FAIL due to mod compatibility issues (exit code 1)
- Compatibility issues should be identified and reported as expected errors

Test Validation:
- Tests that ModManager properly handles mod compatibility failures
- Validates that server startup fails gracefully when mods are incompatible
- Ensures compatibility analysis correctly identifies and reports issues
- Confirms that the StartServer parameter works but fails appropriately

Expected Issues to Detect:
- Missing Fabric API dependencies
- Minecraft version mismatches (mods built for 1.21.5 running on 1.21.6)
- Specific mods that need to be removed or replaced
- Loader version incompatibilities
- Missing required dependencies between mods

Note: This test is designed to FAIL on server startup, which is the expected behavior
when testing with the full modlist containing potentially incompatible mod versions.

COMPATIBILITY ANALYSIS RESULTS:
==============================
$(if (Test-Path (Join-Path $TestOutputDir "Mod_Compatibility_Analysis.log")) {
    Get-Content (Join-Path $TestOutputDir "Mod_Compatibility_Analysis.log") | Out-String
} else {
    "No compatibility analysis log found"
})
"@

    # Set global test results for the test runner
    $script:TestResults.Total = $script:TotalTests
    $script:TestResults.Passed = $script:PassedTests
    $script:TestResults.Failed = $script:FailedTests

    # Save test report
    $script:TestReport | Out-File -FilePath $TestReportPath -Encoding UTF8

    Write-Host "Test completed!" -ForegroundColor Green
    Write-Host "Total Tests: $script:TotalTests" -ForegroundColor Cyan
    Write-Host "Passed: $script:PassedTests" -ForegroundColor Green
    Write-Host "Failed: $script:FailedTests" -ForegroundColor Red
    Write-Host "Success Rate: $(if ($script:TotalTests -gt 0) { [math]::Round(($script:PassedTests / $script:TotalTests) * 100, 2) } else { 0 })%" -ForegroundColor Green
    Write-Host "Test report saved to: $TestReportPath" -ForegroundColor Gray

    # Cleanup test environment (stops logging)
    Cleanup-TestEnvironment

    return ($script:FailedTests -eq 0)
}

# Always execute tests when this file is run
Invoke-TestLatestWithServer -TestFileName $TestFileName 