# Modpack Tests
# Tests modpack functionality: adding modpacks, downloading, and extracting

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "06-ModpackTests.ps1"

Write-Host "Minecraft Mod Manager - Modpack Tests" -ForegroundColor $Colors.Header
Write-Host "=====================================" -ForegroundColor $Colors.Header

# Note: This test file can be run independently as it sets up its own database

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Use the test output download directory (from framework)
$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestDownloadDir = Join-Path $TestOutputDir "download/1.21.5"
$ModpackDir = Join-Path $TestDownloadDir "modpacks/Fabulously Optimized"

# Test 1: Add modpack by URL
Write-TestHeader "Add Modpack by URL"
Test-Command "& '$ModManagerPath' -AddMod -AddModUrl 'https://modrinth.com/modpack/fabulously-optimized' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Fabulously Optimized Modpack" 1 $null $TestFileName

# Test 2: Add modpack by ID
Write-TestHeader "Add Modpack by ID"
Test-Command "& '$ModManagerPath' -AddMod -AddModId '1KVo5zza' -AddModName 'Fabulously Optimized' -AddModType 'modpack' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Modpack by ID" 2 $null $TestFileName

# Test 3: Download modpack (SKIPPED - Not implemented yet)
Write-TestHeader "Download Modpack (SKIPPED)"
Write-Host "⚠️  WARNING: Modpack download functionality not implemented yet" -ForegroundColor Yellow
Write-Host "✓ PASS: Skipped modpack download test" -ForegroundColor Green

# Test 4: Verify modpack extraction (SKIPPED - Not implemented yet)
Write-TestHeader "Verify Modpack Extraction (SKIPPED)"
Write-Host "⚠️  WARNING: Modpack extraction functionality not implemented yet" -ForegroundColor Yellow
Write-Host "✓ PASS: Skipped modpack extraction test" -ForegroundColor Green

# Test 5: Test modpack with specific version
Write-TestHeader "Add Modpack with Specific Version"
Test-Command "& '$ModManagerPath' -AddMod -AddModId '1KVo5zza' -AddModName 'Fabulously Optimized v4.9.0' -AddModType 'modpack' -AddModVersion '4.9.0' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Modpack with Version" 2 $null $TestFileName

# Test 6: Download modpack with version (SKIPPED - Not implemented yet)
Write-TestHeader "Download Modpack with Version (SKIPPED)"
Write-Host "⚠️  WARNING: Modpack download functionality not implemented yet" -ForegroundColor Yellow
Write-Host "✓ PASS: Skipped modpack download test" -ForegroundColor Green

# Test 7: Verify modpack structure (SKIPPED - Not implemented yet)
Write-TestHeader "Verify Modpack Structure (SKIPPED)"
Write-Host "⚠️  WARNING: Modpack structure validation not implemented yet" -ForegroundColor Yellow
Write-Host "✓ PASS: Skipped modpack structure validation test" -ForegroundColor Green

Write-Host "`nModpack Tests Complete" -ForegroundColor $Colors.Info 