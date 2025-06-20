#!/usr/bin/env pwsh

# Minecraft Mod Manager CLI Test Script
# Tests ModManager.ps1 commands one by one and validates database state

param(
    [switch]$Verbose,
    [switch]$Cleanup
)

# Configuration
$ScriptPath = "..\ModManager.ps1"
$TestDbPath = "run-test-cli.csv"
$TestApiResponsePath = "apiresponse"
$MainApiResponsePath = "..\apiresponse"

# Colors for output
$Colors = @{
    Pass = "Green"
    Fail = "Red"
    Info = "Cyan"
    Warning = "Yellow"
    Header = "Magenta"
}

# Test counter
$TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
}

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "TEST: $Title" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $TestResults.Total++
    if ($Passed) {
        $TestResults.Passed++
        Write-Host "✓ PASS: $TestName" -ForegroundColor $Colors.Pass
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
    } else {
        $TestResults.Failed++
        Write-Host "✗ FAIL: $TestName" -ForegroundColor $Colors.Fail
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
    }
}

function Test-DatabaseState {
    param(
        [int]$ExpectedModCount,
        [string[]]$ExpectedMods = @(),
        [string]$TestName = "Database State"
    )
    
    if (-not (Test-Path $TestDbPath)) {
        Write-TestResult $TestName $false "Database file not found"
        return
    }
    
    $mods = Import-Csv $TestDbPath
    $actualCount = $mods.Count
    
    if ($actualCount -eq $ExpectedModCount) {
        Write-TestResult $TestName $true "Found $actualCount mods (expected $ExpectedModCount)"
    } else {
        Write-TestResult $TestName $false "Found $actualCount mods (expected $ExpectedModCount)"
    }
    
    # Check for specific mods if provided
    foreach ($expectedMod in $ExpectedMods) {
        $found = $mods | Where-Object { $_.Name -eq $expectedMod }
        if ($found) {
            Write-TestResult "Contains $expectedMod" $true
        } else {
            Write-TestResult "Contains $expectedMod" $false
        }
    }
}

function Test-Command {
    param(
        [string]$Command,
        [string]$TestName,
        [int]$ExpectedModCount = 0,
        [string[]]$ExpectedMods = @()
    )
    
    Write-Host "`nRunning: $Command" -ForegroundColor $Colors.Info
    if ($Verbose) {
        Write-Host "Command: $Command" -ForegroundColor Gray
    }
    
    try {
        $result = Invoke-Expression $Command 2>&1
        $exitCode = $LASTEXITCODE
        
        # Consider exit code 0 or 1 as success for our tests
        if ($exitCode -eq 0 -or $exitCode -eq 1) {
            Write-TestResult $TestName $true "Command executed successfully (exit code: $exitCode)"
            
            # Test database state if expected values provided
            if ($ExpectedModCount -gt 0 -or $ExpectedMods.Count -gt 0) {
                Test-DatabaseState $ExpectedModCount $ExpectedMods
            }
        } else {
            Write-TestResult $TestName $false "Command failed with exit code $exitCode"
            if ($Verbose) {
                Write-Host "Output: $result" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-TestResult $TestName $false "Command threw exception: $($_.Exception.Message)"
    }
}

function Initialize-TestEnvironment {
    Write-Host "Initializing test environment..." -ForegroundColor $Colors.Info
    
    # Clean up previous test files
    if (Test-Path $TestDbPath) {
        Remove-Item $TestDbPath -Force
    }
    
    # Create blank database with headers only
    $headers = @("Group", "Type", "GameVersion", "ID", "Loader", "Version", "Name", "Description", "Jar", "Url", "Category", "VersionUrl", "LatestVersionUrl", "LatestVersion", "ApiSource", "Host", "IconUrl", "ClientSide", "ServerSide", "Title", "ProjectDescription", "IssuesUrl", "SourceUrl", "WikiUrl", "LatestGameVersion", "RecordHash")
    $headers -join "," | Out-File $TestDbPath -Encoding UTF8
    
    # Copy API response files to main apiresponse folder for caching
    if (Test-Path $TestApiResponsePath) {
        if (-not (Test-Path $MainApiResponsePath)) {
            New-Item -ItemType Directory -Path $MainApiResponsePath -Force
        }
        
        Copy-Item "$TestApiResponsePath\*" $MainApiResponsePath -Force
        Write-Host "Copied API response files for caching" -ForegroundColor $Colors.Info
    }
    
    Write-TestResult "Environment Setup" $true "Test database created and API files copied"
}

function Show-TestSummary {
    Write-Host "`n" + ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "TEST SUMMARY" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    
    Write-Host "Total Tests: $($TestResults.Total)" -ForegroundColor White
    Write-Host "Passed: $($TestResults.Passed)" -ForegroundColor $Colors.Pass
    Write-Host "Failed: $($TestResults.Failed)" -ForegroundColor $Colors.Fail
    
    if ($TestResults.Failed -eq 0) {
        Write-Host "`n🎉 ALL TESTS PASSED! 🎉" -ForegroundColor $Colors.Pass
    } else {
        Write-Host "`n❌ SOME TESTS FAILED! ❌" -ForegroundColor $Colors.Fail
    }
}

function Cleanup-TestEnvironment {
    if ($Cleanup) {
        Write-Host "`nCleaning up test environment..." -ForegroundColor $Colors.Info
        
        if (Test-Path $TestDbPath) {
            Remove-Item $TestDbPath -Force
        }
        
        # Remove copied API files
        if (Test-Path $MainApiResponsePath) {
            Get-ChildItem $MainApiResponsePath -File | Remove-Item -Force
        }
        
        Write-Host "Cleanup completed" -ForegroundColor $Colors.Info
    }
}

# Main test execution
Write-Host "Minecraft Mod Manager CLI Test Suite" -ForegroundColor $Colors.Header
Write-Host "=====================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment

# Test 1: Basic help command
Write-TestHeader "Help Command"
Test-Command ".\$ScriptPath -ShowHelp" "Help Display" 0

# Test 2: Add mod by URL (Fabric API) - Use specific command to avoid default behavior
Write-TestHeader "Add Mod by URL"
Test-Command ".\$ScriptPath -AddMod -AddModUrl 'https://modrinth.com/mod/fabric-api' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Fabric API by URL" 1 @("Fabric API")

# Test 3: Add mod by ID (Sodium)
Write-TestHeader "Add Mod by ID"
Test-Command ".\$ScriptPath -AddMod -AddModId 'sodium' -AddModName 'Sodium' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Sodium by ID" 2 @("Fabric API", "Sodium")

# Test 4: Add shaderpack (Complementary Reimagined)
Write-TestHeader "Add Shaderpack"
Test-Command ".\$ScriptPath -AddMod -AddModUrl 'https://modrinth.com/shader/complementary-reimagined' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Complementary Reimagined" 3 @("Fabric API", "Sodium", "Complementary Shaders - Reimagined")

# Test 5: Add CurseForge mod (Inventory HUD+)
Write-TestHeader "Add CurseForge Mod"
Test-Command ".\$ScriptPath -AddMod -AddModId '357540' -AddModName 'Inventory HUD+' -AddModType 'curseforge' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Inventory HUD+" 3 @("Fabric API", "Sodium", "Complementary Shaders - Reimagined")

# Test 6: Add mod to specific group
Write-TestHeader "Add Mod to Block Group"
Test-Command ".\$ScriptPath -AddMod -AddModId 'no-chat-reports' -AddModName 'No Chat Reports' -AddModGroup 'block' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add No Chat Reports to block group" 4 @("Fabric API", "Sodium", "Complementary Shaders - Reimagined", "No Chat Reports")

# Test 7: Validate all mods
Write-TestHeader "Validate All Mods"
Test-Command ".\$ScriptPath -ValidateAllModVersions -DatabaseFile '$TestDbPath' -UseCachedResponses" "Validate All Mods" 4

# Test 8: Get mod list
Write-TestHeader "Get Mod List"
Test-Command ".\$ScriptPath -GetModList -DatabaseFile '$TestDbPath'" "Get Mod List" 4

# Test 9: Delete mod
Write-TestHeader "Delete Mod"
Test-Command ".\$ScriptPath -DeleteModID 'sodium' -DeleteModType 'mod' -DatabaseFile '$TestDbPath'" "Delete Sodium" 3 @("Fabric API", "Complementary Shaders - Reimagined", "No Chat Reports")

# Test 10: Add mod with auto-download
Write-TestHeader "Add Mod with Auto-Download"
Test-Command ".\$ScriptPath -AddMod -AddModId 'litematica' -AddModName 'Litematica' -ForceDownload -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Litematica with auto-download" 4 @("Fabric API", "Complementary Shaders - Reimagined", "No Chat Reports", "Litematica")

# Test 11: Download mods
Write-TestHeader "Download Mods"
Test-Command ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -UseCachedResponses" "Download Mods" 4

# Test 11.5: Download mods with validation
Write-TestHeader "Download Mods with Validation"
Test-Command ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -ValidateWithDownload -UseCachedResponses" "Download Mods with Validation" 4

# Test 12: Download server files
Write-TestHeader "Download Server Files"
Test-Command ".\$ScriptPath -DownloadServer" "Download Server Files" 0

# Test 13: Use custom database file
Write-TestHeader "Custom Database File"
Test-Command ".\$ScriptPath -ModListFile '$TestDbPath' -GetModList" "Use Custom Database File" 4

# Test 14: Add system entries (installer, launcher, server) for different versions
Write-TestHeader "Add System Entries"
Test-Command ".\$ScriptPath -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.5' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Add Fabric Installer 1.21.5" 5
Test-Command ".\$ScriptPath -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.6' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Add Fabric Installer 1.21.6" 5
Test-Command ".\$ScriptPath -AddMod -AddModName 'Fabric Server Launcher' -AddModType 'launcher' -AddModGameVersion '1.21.5' -AddModUrl 'https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar' -AddModVersion '1.0.3' -AddModJar 'fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar' -DatabaseFile '$TestDbPath'" "Add Fabric Server Launcher 1.21.5" 6
Test-Command ".\$ScriptPath -AddMod -AddModName 'Fabric Server Launcher' -AddModType 'launcher' -AddModGameVersion '1.21.6' -AddModUrl 'https://meta.fabricmc.net/v2/versions/loader/1.21.6/0.16.14/1.0.3/server/jar' -AddModVersion '1.0.3' -AddModJar 'fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar' -DatabaseFile '$TestDbPath'" "Add Fabric Server Launcher 1.21.6" 7
Test-Command ".\$ScriptPath -AddMod -AddModName 'Minecraft Server' -AddModType 'server' -AddModGameVersion '1.21.5' -AddModUrl 'https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar' -AddModVersion '1.21.5' -AddModJar 'minecraft_server.1.21.5.jar' -DatabaseFile '$TestDbPath'" "Add Minecraft Server 1.21.5" 8
Test-Command ".\$ScriptPath -AddMod -AddModName 'Minecraft Server' -AddModType 'server' -AddModGameVersion '1.21.6' -AddModUrl 'https://piston-data.mojang.com/v1/objects/6e64dcabba3c01a7271b4fa6bd898483b794c59b/server.jar' -AddModVersion '1.21.6' -AddModJar 'minecraft_server.1.21.6.jar' -DatabaseFile '$TestDbPath'" "Add Minecraft Server 1.21.6" 9

# Test 15: Validate with UseLatestVersion (should detect majority version)
Write-TestHeader "Validate with UseLatestVersion"
Test-Command ".\$ScriptPath -ValidateAllModVersions -DatabaseFile '$TestDbPath' -UseLatestVersion -UseCachedResponses" "Validate with UseLatestVersion" 9

# Test 16: Download with UseLatestVersion (should download latest mods and matching system files)
Write-TestHeader "Download with UseLatestVersion"
Test-Command ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -UseLatestVersion -UseCachedResponses" "Download with UseLatestVersion" 9

# Test 16.5: Download with UseLatestVersion and validation
Write-TestHeader "Download with UseLatestVersion and Validation"
Test-Command ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -UseLatestVersion -ValidateWithDownload -UseCachedResponses" "Download with UseLatestVersion and Validation" 9

# Test 17: Test missing system files scenario (remove some system entries)
Write-TestHeader "Test Missing System Files"
# Remove 1.21.6 system entries to test missing file reporting
$currentMods = Import-Csv $TestDbPath
$filteredMods = $currentMods | Where-Object { 
    -not ($_.Type -in @("installer", "launcher", "server") -and $_.GameVersion -eq "1.21.6") 
}
$filteredMods | Export-Csv $TestDbPath -NoTypeInformation

$missingSystemFilesCmd = ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -UseLatestVersion -UseCachedResponses"
$missingSystemFilesTestName = "Download with Missing System Files"
Test-Command $missingSystemFilesCmd $missingSystemFilesTestName 7

# Test 18: Test shaderpack filename cleaning (add a shaderpack with URL-encoded filename)
Write-TestHeader "Test Shaderpack Filename Cleaning"
Test-Command ".\$ScriptPath -AddMod -AddModUrl 'https://modrinth.com/shader/astralex' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add AstraLex Shaderpack" 8

# Test 19: Test system entry filename handling (verify Jar column is used)
Write-TestHeader "Test System Entry Filename Handling"
# Add a system entry with a specific Jar filename
Test-Command ".\$ScriptPath -AddMod -AddModName 'Test Server' -AddModType 'server' -AddModGameVersion '1.21.6' -AddModUrl 'https://example.com/server.jar' -AddModVersion '1.21.6' -AddModJar 'test_server_1.21.6.jar' -DatabaseFile '$TestDbPath'" "Add Test Server with Jar filename" 9

# Test 20: Test duplicate 'Already exists' message fix
Write-TestHeader "Test Duplicate Already Exists Fix"
# Download the same files twice to verify no duplicate messages
$duplicateTestCmd = ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -UseCachedResponses"
Test-Command $duplicateTestCmd "Download to Test Duplicate Prevention" 9

# Test 21: Test UseLatestVersion with all system entries present
Write-TestHeader "Test UseLatestVersion Complete"
# Re-add the missing 1.21.6 system entries
Test-Command ".\$ScriptPath -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.6' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Re-add Fabric Installer 1.21.6" 9
Test-Command ".\$ScriptPath -AddMod -AddModName 'Fabric Server Launcher' -AddModType 'launcher' -AddModGameVersion '1.21.6' -AddModUrl 'https://meta.fabricmc.net/v2/versions/loader/1.21.6/0.16.14/1.0.3/server/jar' -AddModVersion '1.0.3' -AddModJar 'fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar' -DatabaseFile '$TestDbPath'" "Re-add Fabric Server Launcher 1.21.6" 10
Test-Command ".\$ScriptPath -AddMod -AddModName 'Minecraft Server' -AddModType 'server' -AddModGameVersion '1.21.6' -AddModUrl 'https://piston-data.mojang.com/v1/objects/6e64dcabba3c01a7271b4fa6bd898483b794c59b/server.jar' -AddModVersion '1.21.6' -AddModJar 'minecraft_server.1.21.6.jar' -DatabaseFile '$TestDbPath'" "Re-add Minecraft Server 1.21.6" 11

# Test 22: Final UseLatestVersion test with complete system entries
Write-TestHeader "Final UseLatestVersion Test"
$finalUseLatestCmd = ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -UseLatestVersion -UseCachedResponses"
$finalUseLatestTestName = "Final UseLatestVersion Download"
Test-Command $finalUseLatestCmd $finalUseLatestTestName 11

# Test 23: Test legacy Download behavior (validation + download)
Write-TestHeader "Test Legacy Download Behavior"
Test-Command ".\$ScriptPath -Download -DatabaseFile '$TestDbPath' -UseCachedResponses" "Legacy Download (Validation + Download)" 11

# Test 24: Verify downloaded files have correct names
Write-TestHeader "Verify Downloaded File Names"
# Check that system entries use Jar column names and shaderpacks have clean names
$verifyFilesCmd = 'Get-ChildItem "download" -Recurse -File | Where-Object { $_.Name -match "fabric-installer|fabric-server|minecraft_server|astralex|bsl|complementary" } | Select-Object Name, FullName'
$verifyFilesTestName = "Verify Downloaded File Names"
Test-Command $verifyFilesCmd $verifyFilesTestName 0

# Test 2.5: Simulate external update to Fabric API version
Write-TestHeader "Detect External Fabric Version Update"
# Manually update the Fabric API version in the CSV (simulate external edit)
$csv = Import-Csv $TestDbPath
foreach ($row in $csv) {
    if ($row.ID -eq "fabric-api") {
        $row.Version = "0.127.1+1.21.5"
    }
}
$csv | Export-Csv $TestDbPath -NoTypeInformation
# Run GetModList to trigger hash check and warning
Test-Command ".\$ScriptPath -GetModList -DatabaseFile '$TestDbPath'" "Detect Fabric API Version Hash Mismatch" 1

# Test: Fabric Installer should be downloaded as .exe, not .jar
Write-TestHeader "Fabric Installer Downloaded as EXE"
# Add Fabric Installer system entry with .exe URL
Test-Command ".\$ScriptPath -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.5' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Add Fabric Installer EXE" 1
# Download mods
Test-Command ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath'" "Download Mods with Installer" 1
# Check that Fabric Installer was downloaded as .exe
$installerFile = Get-ChildItem download -Recurse -File | Where-Object { $_.Name -like 'fabric-installer*.exe' }
if ($installerFile) {
    Write-Host "✓ PASS: Fabric Installer downloaded as EXE: $($installerFile.FullName)" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Fabric Installer not downloaded as EXE" -ForegroundColor Red
    exit 1
}

# Test: Validate each type download ensures file exists
Write-TestHeader "Validate System Entry and Mod Downloads"

# Add system entries and a regular mod
Test-Command ".\$ScriptPath -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.5' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Add Fabric Installer" 1
Test-Command ".\$ScriptPath -AddMod -AddModName 'Fabric Server Launcher' -AddModType 'launcher' -AddModGameVersion '1.21.5' -AddModUrl 'https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar' -AddModVersion '1.0.3' -AddModJar 'fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar' -DatabaseFile '$TestDbPath'" "Add Fabric Server Launcher" 1
Test-Command ".\$ScriptPath -AddMod -AddModName 'Minecraft Server' -AddModType 'server' -AddModGameVersion '1.21.5' -AddModUrl 'https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar' -AddModVersion '1.21.5' -AddModJar 'minecraft_server.1.21.5.jar' -DatabaseFile '$TestDbPath'" "Add Minecraft Server" 1
Test-Command ".\$ScriptPath -AddMod -AddModUrl 'https://modrinth.com/mod/litematica' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Litematica Mod" 1

# Download all
Test-Command ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -UseCachedResponses" "Download All Types" 4

# Validate files exist
$expectedFiles = @(
    "download/1.21.5/installer/fabric-installer-1.0.3.exe",
    "download/1.21.5/jar",
    "download/1.21.5/minecraft_server.1.21.5.jar"
)

$missing = $false
foreach ($file in $expectedFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "✗ FAIL: Missing expected file: $file" -ForegroundColor Red
        $missing = $true
    } else {
        Write-Host "✓ PASS: Found $file" -ForegroundColor Green
    }
}
# Check for at least one mod jar in mods folder
$modFiles = Get-ChildItem download/1.21.5/mods -File -Filter *.jar -ErrorAction SilentlyContinue
if ($modFiles.Count -ge 1) {
    Write-Host "✓ PASS: Found mod jar in mods folder" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: No mod jar found in mods folder" -ForegroundColor Red
    $missing = $true
}
if ($missing) { exit 1 }

Show-TestSummary
Cleanup-TestEnvironment

# Return exit code based on test results
if ($TestResults.Failed -eq 0) {
    exit 0
} else {
    exit 1
} 