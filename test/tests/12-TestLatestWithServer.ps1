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

    # Test 6: Attempt to start server (this should succeed if mods are compatible)
    Write-Host "=== Step 6: Attempting Server Startup ===" -ForegroundColor Magenta
    Test-LatestWithServer -TestName "Server Startup with Latest Mods" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -StartServer -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Server started successfully|Server is running" -ExpectedExitCode 0

    # Test 7: Analyze and report mod compatibility issues as errors
    Write-Host "=== Step 7: Analyzing Mod Compatibility Issues ===" -ForegroundColor Magenta
    Test-LatestWithServer -TestName "Mod Compatibility Analysis" -TestScript {
        # Check the server logs for actual compatibility errors
        $serverLogPath = Join-Path $TestDownloadDir "1.21.6\logs\console-*.log"
        $logFiles = Get-ChildItem -Path $serverLogPath -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        
        if ($logFiles.Count -gt 0) {
            $latestLog = $logFiles[0]
            $logContent = Get-Content $latestLog.FullName -Raw
            
            # Extract specific compatibility issues
            $compatibilityIssues = @()
            $missingFabricApi = @()
            $versionMismatches = @()
            $specificModIssues = @()
            
            # Check for missing Fabric API
            if ($logContent -match "requires.*fabric-api.*which is missing") {
                $missingFabricApi += "Fabric API is missing but required by multiple mods"
            }
            
            # Check for Minecraft version mismatches
            if ($logContent -match "requires.*minecraft.*but only the wrong version is present") {
                $versionMismatches += "Minecraft version mismatches detected"
            }
            
            # Extract specific mod issues
            if ($logContent -match "Remove mod '([^']+)'") {
                $specificModIssues += "Mod should be removed: $($matches[1])"
            }
            
            if ($logContent -match "Replace mod '([^']+)'") {
                $specificModIssues += "Mod should be replaced: $($matches[1])"
            }
            
            # Compile comprehensive error report
            $errorReport = @()
            if ($missingFabricApi.Count -gt 0) { $errorReport += $missingFabricApi }
            if ($versionMismatches.Count -gt 0) { $errorReport += $versionMismatches }
            if ($specificModIssues.Count -gt 0) { $errorReport += $specificModIssues }
            
            if ($errorReport.Count -gt 0) {
                "COMPATIBILITY ERRORS FOUND: " + ($errorReport -join "; ")
            } else {
                "No compatibility issues found - server should start successfully"
            }
        } else {
            "No server log files found - cannot analyze compatibility"
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
The test will identify and report any mod compatibility issues that prevent successful server startup.

Expected Behavior:
- Mod validation should succeed
- Latest mod downloads should succeed  
- Server file downloads should succeed
- Server start script should be added successfully
- Server startup should succeed if mods are compatible
- Any compatibility issues should be identified and reported as errors

Known Issues to Fix:
- Missing Fabric API dependencies
- Minecraft version mismatches (mods built for 1.21.5 running on 1.21.6)
- Specific mods that need to be removed or replaced
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

    return ($script:FailedTests -eq 0)
}

# Always execute tests when this file is run
Invoke-TestLatestWithServer -TestFileName $TestFileName 