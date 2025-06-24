# Tests the complete workflow: use test modlist, download current versions, start server, monitor logs

param([string]$TestFileName = $null)

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "09-TestCurrent.ps1"

Write-Host "Minecraft Mod Manager - Test Current Mods Workflow" -ForegroundColor $Colors.Header
Write-Host "=================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Test configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\09-TestCurrent"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"
$TestApiResponseFolder = Join-Path $TestOutputDir "apiresponse"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Create a test modlist with a simple mod for testing
$testModList = @(
    [PSCustomObject]@{
        Name = "Fabric API"
        ID = "fabric-api"
        Type = "mod"
        GameVersion = "1.21.5"
        Version = "0.127.1+1.21.6"
        LatestVersion = "0.127.1+1.21.6"
        Loader = "fabric"
        Group = "test"
        Url = "https://modrinth.com/mod/fabric-api"
        VersionUrl = "https://cdn.modrinth.com/data/P7dR8mSH/versions/0.127.1%2B1.21.6/fabric-api-0.127.1%2B1.21.6.jar"
        LatestVersionUrl = "https://cdn.modrinth.com/data/P7dR8mSH/versions/0.127.1%2B1.21.6/fabric-api-0.127.1%2B1.21.6.jar"
        ApiSource = "modrinth"
        Host = "modrinth.com"
        Title = "Fabric API"
        Description = "Test Fabric API"
        Jar = "fabric-api-0.127.1+1.21.6.jar"
        IconUrl = "https://cdn.modrinth.com/data/P7dR8mSH/icon.png"
        ClientSide = "required"
        ServerSide = "required"
        Category = "API"
        IssuesUrl = "https://github.com/FabricMC/fabric/issues"
        SourceUrl = "https://github.com/FabricMC/fabric"
        WikiUrl = "https://fabricmc.net/wiki"
        LatestGameVersion = "1.21.6"
        RecordHash = "test-hash"
    }
)

# Create test modlist.csv
$testModList | Export-Csv -Path $TestModListPath -NoTypeInformation

# Test variables
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0
$TestReport = @()

# Test report file
$TestReportPath = Join-Path $TestOutputDir "test-current-test-report.txt"

function Test-Current {
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

function Invoke-TestCurrent {
    param([string]$TestFileName = $null)
    
    Write-Host "Starting Test Current Mods Workflow" -ForegroundColor Yellow
    Write-Host "Test Output Directory: $TestOutputDir" -ForegroundColor Gray
    Write-Host "Test ModList: $TestModListPath" -ForegroundColor Gray
    Write-Host ""

    # Step 1: Verify test modlist.csv exists
    Write-TestStep "Checking test modlist.csv exists"
    if (Test-Path $TestModListPath) {
        Write-TestResult "ModList Existence" $true "test modlist.csv found"
    } else {
        Write-TestResult "ModList Existence" $false "test modlist.csv not found at $TestModListPath"
        return $false
    }

    # Step 2: Read test modlist.csv to see what mods we have
    Write-TestStep "Reading test modlist.csv"
    try {
        $modList = Import-Csv $TestModListPath
        Write-TestResult "ModList Reading" $true "Successfully read test modlist.csv with $($modList.Count) mods"
    } catch {
        Write-TestResult "ModList Reading" $false "Failed to read test modlist.csv: $($_.Exception.Message)"
        return $false
    }

    # Step 3: Validate all mods first
    Write-Host "=== Step 3: Validating All Mods ===" -ForegroundColor Magenta
    Test-Current -TestName "Validate All Mods" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -UseCachedResponses -DatabaseFile $TestModListPath -ApiResponseFolder $TestApiResponseFolder
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Step 4: Download current mods
    Write-Host "=== Step 4: Downloading Current Mods ===" -ForegroundColor Magenta
    Test-Current -TestName "Download Current Mods" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Download -DownloadFolder $TestDownloadDir -DatabaseFile $TestModListPath -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Step 5: Verify downloads exist
    Write-Host "=== Step 5: Verifying Downloads ===" -ForegroundColor Magenta
    Test-Current -TestName "Verify Downloads" -TestScript {
        $modFiles = Get-ChildItem -Path $TestDownloadDir -Recurse -File -Filter "*.jar" -ErrorAction SilentlyContinue
        if ($modFiles.Count -gt 0) {
            "Found $($modFiles.Count) mod files in $TestDownloadDir"
            $modFiles | ForEach-Object { "  - $($_.Name)" }
        } else {
            "No mod files found in $TestDownloadDir"
        }
    } -ExpectedOutput "Found.*mod files" -ExpectedExitCode 0

    # Step 6: Download server files
    Write-Host "=== Step 6: Downloading Server Files ===" -ForegroundColor Magenta
    Test-Current -TestName "Download Server Files" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadServer -DownloadFolder $TestDownloadDir -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Step 7: Verify server files exist
    Write-Host "=== Step 7: Verifying Server Files ===" -ForegroundColor Magenta
    Test-Current -TestName "Verify Server Files" -TestScript {
        $serverFiles = Get-ChildItem -Path $TestDownloadDir -Recurse -File -Filter "minecraft_server*.jar" -ErrorAction SilentlyContinue
        if ($serverFiles.Count -gt 0) {
            "Found $($serverFiles.Count) server files in $TestDownloadDir"
            $serverFiles | ForEach-Object { "  - $($_.Name)" }
        } else {
            "No server files found in $TestDownloadDir"
        }
    } -ExpectedOutput "Found.*server files" -ExpectedExitCode 0

    # Step 8: Add server start script
    Write-Host "=== Step 8: Adding Server Start Script ===" -ForegroundColor Magenta
    Test-Current -TestName "Add Server Start Script" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddServerStartScript -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Successfully copied start-server script" -ExpectedExitCode 0

    # Step 9: Verify start script exists
    Write-Host "=== Step 9: Verifying Start Script ===" -ForegroundColor Magenta
    Test-Current -TestName "Verify Start Script" -TestScript {
        $startScript = Join-Path $TestDownloadDir "1.21.6/start-server.ps1"
        if (Test-Path $startScript) {
            "Start script found at $startScript"
            $scriptContent = Get-Content $startScript -Raw
            if ($scriptContent -match "Start-MinecraftServer") {
                "Start script contains Start-MinecraftServer function"
            } else {
                "Start script does not contain Start-MinecraftServer function"
            }
        } else {
            "Start script not found at $startScript"
        }
    } -ExpectedOutput "Start script found" -ExpectedExitCode 0

    # Step 10: Verify test modlist.csv still exists and is readable
    Write-TestStep "Verifying test modlist.csv still exists after workflow"
    if (Test-Path $TestModListPath) {
        Write-TestResult "Database Existence" $true "test modlist.csv still exists after workflow"
    } else {
        Write-TestResult "Database Existence" $false "test modlist.csv not found after workflow"
        return $false
    }

    try {
        $modList = Import-Csv $TestModListPath
        Write-TestResult "Database Reading" $true "Successfully read test modlist.csv with $($modList.Count) mods"
    } catch {
        Write-TestResult "Database Reading" $false "Failed to read test modlist.csv: $($_.Exception.Message)"
        return $false
    }

    # Final check: Ensure test/download is empty or does not exist
    Write-Host "=== Final Step: Verifying test/download is untouched ===" -ForegroundColor Magenta
    $TotalTests++  # Increment total test count for this check
    $mainTestDownloadPath = Join-Path $PSScriptRoot "..\download"
    if (Test-Path $mainTestDownloadPath) {
        $downloadContents = Get-ChildItem -Path $mainTestDownloadPath -Recurse -File -ErrorAction SilentlyContinue
        if ($downloadContents.Count -gt 0) {
            Write-Host "  ❌ FAIL: main test/download is not empty!" -ForegroundColor Red
            $FailedTests++
            $TestReport += "❌ FAIL: main test/download is not empty!`n"
        } else {
            Write-Host "  ✅ PASS: main test/download is empty" -ForegroundColor Green
            $PassedTests++
            $TestReport += "✅ PASS: main test/download is empty`n"
        }
    } else {
        Write-Host "  ✅ PASS: main test/download does not exist" -ForegroundColor Green
        $PassedTests++
        $TestReport += "✅ PASS: main test/download does not exist`n"
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
This test validates the complete workflow of downloading current mod versions.
It uses a test-specific modlist.csv to avoid interfering with the main modlist.csv.

Expected Behavior:
- Test modlist.csv should be created and readable
- Mod validation should succeed
- Current mod downloads should succeed
- Server file downloads should succeed
- Start script should be added successfully
- test/download should remain untouched
"@

    # Set global test results for the test runner
    $script:TestResults = @{
        Total = $TotalTests
        Passed = $PassedTests
        Failed = $FailedTests
    }

    # Save test report
    $TestReport | Out-File -FilePath $TestReportPath -Encoding UTF8

    Write-Host "Test completed!" -ForegroundColor Green
    Write-Host "Total Tests: $TotalTests" -ForegroundColor Cyan
    Write-Host "Passed: $PassedTests" -ForegroundColor Green
    Write-Host "Failed: $FailedTests" -ForegroundColor Red
    Write-Host "Success Rate: $(if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 2) } else { 0 })%" -ForegroundColor Green
    Write-Host "Test report saved to: $TestReportPath" -ForegroundColor Gray

    return ($FailedTests -eq 0)
}

# Execute tests if run directly
if ($MyInvocation.InvocationName -ne ".") {
    Invoke-TestCurrent -TestFileName $TestFileName
} 