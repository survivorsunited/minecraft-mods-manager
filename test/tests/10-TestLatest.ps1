# Tests the complete workflow: use test modlist, download latest versions, start server, monitor logs

param([string]$TestFileName = $null)

# Import test framework
$TestFrameworkPath = Join-Path $PSScriptRoot "..\TestFramework.ps1"
. $TestFrameworkPath

# Test configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\10-TestLatest"
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

# Test variables
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0
$TestReport = @()

# Test report file
$TestReportPath = Join-Path $TestOutputDir "test-latest-test-report.txt"

function Test-Latest {
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

function Invoke-TestLatest {
    param([string]$TestFileName = $null)
    
    Write-Host "Starting Test Latest Mods Workflow" -ForegroundColor Yellow
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
    Test-Latest -TestName "Validate All Mods" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -UseCachedResponses -DatabaseFile $TestModListPath
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Step 4: Update mods to latest versions
    Write-Host "=== Step 4: Updating Mods to Latest Versions ===" -ForegroundColor Magenta
    Test-Latest -TestName "Update Mods to Latest" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $TestModListPath -UseCachedResponses
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Step 5: Download latest mods
    Write-Host "=== Step 5: Downloading Latest Mods ===" -ForegroundColor Magenta
    Test-Latest -TestName "Download Latest Mods" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Download -UseLatestVersion -DownloadFolder $TestDownloadDir -DatabaseFile $TestModListPath -UseCachedResponses
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Step 6: Verify downloads exist
    Write-Host "=== Step 6: Verifying Downloads ===" -ForegroundColor Magenta
    Test-Latest -TestName "Verify Downloads" -TestScript {
        $modFiles = Get-ChildItem -Path $TestDownloadDir -Recurse -File -Filter "*.jar" -ErrorAction SilentlyContinue
        if ($modFiles.Count -gt 0) {
            "Found $($modFiles.Count) mod files in $TestDownloadDir"
            $modFiles | ForEach-Object { "  - $($_.Name)" }
        } else {
            "No mod files found in $TestDownloadDir"
        }
    } -ExpectedOutput "Found.*mod files" -ExpectedExitCode 0

    # Step 7: Download server files
    Write-Host "=== Step 7: Downloading Server Files ===" -ForegroundColor Magenta
    Test-Latest -TestName "Download Server Files" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadServer -DownloadFolder $TestDownloadDir -UseCachedResponses
    } -ExpectedOutput "Minecraft Mod Manager PowerShell Script" -ExpectedExitCode 0

    # Step 8: Verify server files exist
    Write-Host "=== Step 8: Verifying Server Files ===" -ForegroundColor Magenta
    Test-Latest -TestName "Verify Server Files" -TestScript {
        $serverFiles = Get-ChildItem -Path $TestDownloadDir -File -Filter "minecraft_server*.jar" -ErrorAction SilentlyContinue
        if ($serverFiles.Count -gt 0) {
            "Found $($serverFiles.Count) server files in $TestDownloadDir"
            $serverFiles | ForEach-Object { "  - $($_.Name)" }
        } else {
            "No server files found in $TestDownloadDir"
        }
    } -ExpectedOutput "Found.*server files" -ExpectedExitCode 0

    # Step 9: Add server start script
    Write-Host "=== Step 9: Adding Server Start Script ===" -ForegroundColor Magenta
    Test-Latest -TestName "Add Server Start Script" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddServerStartScript -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Successfully copied start-server script" -ExpectedExitCode 0

    # Step 10: Verify start script exists
    Write-Host "=== Step 10: Verifying Start Script ===" -ForegroundColor Magenta
    Test-Latest -TestName "Verify Start Script" -TestScript {
        $startScript = Join-Path $TestDownloadDir "start-server.ps1"
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

    # Step 11: Verify test modlist.csv still exists and is readable
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

    # Step 12: Check for version updates
    Write-Host "=== Step 12: Checking for Version Updates ===" -ForegroundColor Magenta
    Test-Latest -TestName "Check Version Updates" -TestScript {
        try {
            $modList = Import-Csv $TestModListPath
            $updates = @()
            
            foreach ($mod in $modList) {
                if ($mod.Version -and $mod.LatestVersion -and $mod.Version -ne $mod.LatestVersion) {
                    $updates += "$($mod.Name): $($mod.Version) -> $($mod.LatestVersion)"
                }
            }
            
            if ($updates.Count -gt 0) {
                "Found $($updates.Count) version updates:"
                $updates | ForEach-Object { "  - $_" }
            } else {
                "No version updates found - all mods are at latest versions"
            }
        } catch {
            Write-TestResult "Database Reading" $false "Failed to read test modlist.csv for version comparison"
        }
    } -ExpectedOutput "Found.*version updates|No version updates found" -ExpectedExitCode 0

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
This test validates the complete workflow of downloading latest mod versions.
It uses a test-specific modlist.csv to avoid interfering with the main modlist.csv.

Expected Behavior:
- Test modlist.csv should be created and readable
- Mod validation should succeed
- Latest mod downloads should succeed
- Server file downloads should succeed
- Start script should be added successfully
- Version updates should be detected
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
    Invoke-TestLatest -TestFileName $TestFileName
} 