# Download Functionality Tests
# Tests mod downloading, validation with download, and server file downloads

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

Write-Host "Minecraft Mod Manager - Download Functionality Tests" -ForegroundColor $Colors.Header
Write-Host "=====================================================" -ForegroundColor $Colors.Header

# Note: This test file assumes a database with mods already exists
# It should be run after 01-BasicFunctionality.ps1

Initialize-TestEnvironment

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# SETUP: Add required mods to the database
Test-Command "& '$ModManagerPath' -AddMod -AddModUrl 'https://modrinth.com/mod/fabric-api' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Fabric API by URL" 1 @("Fabric API") $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModId 'sodium' -AddModName 'Sodium' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Sodium by ID" 2 @("Fabric API", "Sodium") $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModUrl 'https://modrinth.com/shader/complementary-reimagined' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Complementary Reimagined" 3 @("Fabric API", "Sodium", "Complementary Shaders - Reimagined") $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModId 'no-chat-reports' -AddModName 'No Chat Reports' -AddModGroup 'block' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add No Chat Reports to block group" 4 @("Fabric API", "Sodium", "Complementary Shaders - Reimagined", "No Chat Reports") $TestFileName

# Test 1: Download mods
Write-TestHeader "Download Mods"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestDownloadDir = Join-Path $TestOutputDir "download"
Test-Command "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -DownloadFolder '$TestDownloadDir' -UseCachedResponses" "Download Mods" 4 $null $TestFileName

# Test 2: Download mods with validation
Write-TestHeader "Download Mods with Validation"
Test-Command "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -DownloadFolder '$TestDownloadDir' -ValidateWithDownload -UseCachedResponses" "Download Mods with Validation" 4 $null $TestFileName

# Test 3: Download server files
Write-TestHeader "Download Server Files"
Test-Command "& '$ModManagerPath' -DownloadServer -DownloadFolder '$TestDownloadDir'" "Download Server Files" 4 $null $TestFileName

# Test 4: Test duplicate already exists fix
Write-TestHeader "Test Duplicate Already Exists Fix"
Test-Command "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -DownloadFolder '$TestDownloadDir' -UseCachedResponses" "Download to Test Duplicate Prevention" 4 $null $TestFileName

# Test 5: Test legacy download behavior
Write-TestHeader "Test Legacy Download Behavior"
Test-Command "& '$ModManagerPath' -Download -DatabaseFile '$TestDbPath' -DownloadFolder '$TestDownloadDir' -UseCachedResponses" "Legacy Download (Validation + Download)" 4 $null $TestFileName

# Final check: Ensure test/download is untouched
Write-TestHeader "Verify test/download is untouched"
$testDownloadPath = Join-Path $PSScriptRoot "..\download"
if (Test-Path $testDownloadPath) {
    $downloadContents = Get-ChildItem -Path $testDownloadPath -Recurse -File -ErrorAction SilentlyContinue
    if ($downloadContents.Count -gt 0) {
        Write-TestResult "test/download isolation" $false "test/download is not empty!"
    } else {
        Write-TestResult "test/download isolation" $true "test/download is empty"
    }
} else {
    Write-TestResult "test/download isolation" $true "test/download does not exist"
}

Write-Host "`nDownload Functionality Tests Complete" -ForegroundColor $Colors.Info

# Show test summary
Show-TestSummary 

# NOTE: Download folder is intentionally preserved for post-test validation. 