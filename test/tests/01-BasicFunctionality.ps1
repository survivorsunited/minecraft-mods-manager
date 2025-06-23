# Basic Functionality Tests
# Tests core ModManager functionality: help, add mods, validation, database operations

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "01-BasicFunctionality.ps1"

Write-Host "Minecraft Mod Manager - Basic Functionality Tests" -ForegroundColor $Colors.Header
Write-Host "=================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Add this at the top after importing the test framework:
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"

# DEBUG: Show the exact paths being used
Write-Host "DEBUG PATHS:" -ForegroundColor Red
Write-Host "TestFileName: $TestFileName" -ForegroundColor Red
Write-Host "TestOutputDir: $TestOutputDir" -ForegroundColor Red
Write-Host "TestApiResponseDir: $script:TestApiResponseDir" -ForegroundColor Red
Write-Host "TestDownloadDir: $TestDownloadDir" -ForegroundColor Red
Write-Host "DEBUG PATHS END" -ForegroundColor Red

# Test 1: Basic help command
Write-TestHeader "Help Command"
Test-Command "& '$ModManagerPath' -ShowHelp -ApiResponseFolder '$script:TestApiResponseDir'" "Help Display" 0 $null $TestFileName

# Test 2: Add mod by URL (Fabric API)
Write-TestHeader "Add Mod by URL"
Test-Command "& '$ModManagerPath' -AddMod -AddModUrl 'https://modrinth.com/mod/fabric-api' -DatabaseFile '$TestDbPath' -UseCachedResponses -ApiResponseFolder '$script:TestApiResponseDir'" "Add Fabric API by URL" 1 @("Fabric API") $TestFileName

# Test 3: Add mod by ID (Sodium)
Write-TestHeader "Add Mod by ID"
Test-Command "& '$ModManagerPath' -AddMod -AddModId 'sodium' -AddModName 'Sodium' -DatabaseFile '$TestDbPath' -UseCachedResponses -ApiResponseFolder '$script:TestApiResponseDir'" "Add Sodium by ID" 2 @("Fabric API", "Sodium") $TestFileName

# Test 4: Add shaderpack (Complementary Reimagined)
Write-TestHeader "Add Shaderpack"
Test-Command "& '$ModManagerPath' -AddMod -AddModUrl 'https://modrinth.com/shader/complementary-reimagined' -DatabaseFile '$TestDbPath' -UseCachedResponses -ApiResponseFolder '$script:TestApiResponseDir'" "Add Complementary Reimagined" 3 @("Fabric API", "Sodium", "Complementary Shaders - Reimagined") $TestFileName

# Test 5: Add CurseForge mod (Inventory HUD+)
Write-TestHeader "Add CurseForge Mod"
Test-Command "& '$ModManagerPath' -AddMod -AddModId '357540' -AddModName 'Inventory HUD+' -AddModType 'curseforge' -DatabaseFile '$TestDbPath' -UseCachedResponses -ApiResponseFolder '$script:TestApiResponseDir'" "Add Inventory HUD+" 3 @("Fabric API", "Sodium", "Complementary Shaders - Reimagined") $TestFileName

# Test 6: Add mod to specific group
Write-TestHeader "Add Mod to Block Group"
Test-Command "& '$ModManagerPath' -AddMod -AddModId 'no-chat-reports' -AddModName 'No Chat Reports' -AddModGroup 'block' -DatabaseFile '$TestDbPath' -UseCachedResponses -ApiResponseFolder '$script:TestApiResponseDir'" "Add No Chat Reports to block group" 4 @("Fabric API", "Sodium", "Complementary Shaders - Reimagined", "No Chat Reports") $TestFileName

# Test 7: Validate all mods
Write-TestHeader "Validate All Mods"
Test-Command "& '$ModManagerPath' -ValidateAllModVersions -DatabaseFile '$TestDbPath' -UseCachedResponses -ApiResponseFolder '$script:TestApiResponseDir'" "Validate All Mods" 4 $null $TestFileName

# Test 8: Get mod list
Write-TestHeader "Get Mod List"
Test-Command "& '$ModManagerPath' -GetModList -DatabaseFile '$TestDbPath' -ApiResponseFolder '$script:TestApiResponseDir'" "Get Mod List" 4 $null $TestFileName

# Test 9: Delete mod
Write-TestHeader "Delete Mod"
Test-Command "& '$ModManagerPath' -DeleteModID 'sodium' -DeleteModType 'mod' -DatabaseFile '$TestDbPath' -ApiResponseFolder '$script:TestApiResponseDir'" "Delete Sodium" 3 @("Fabric API", "Complementary Shaders - Reimagined", "No Chat Reports") $TestFileName

# Test 10: Add mod with auto-download
Write-TestHeader "Add Mod with Auto-Download"
Test-Command "& '$ModManagerPath' -AddMod -AddModId 'litematica' -AddModName 'Litematica' -ForceDownload -DatabaseFile '$TestDbPath' -UseCachedResponses -ApiResponseFolder '$script:TestApiResponseDir' -DownloadFolder '$TestDownloadDir'" "Add Litematica with auto-download" 4 @("Fabric API", "Complementary Shaders - Reimagined", "No Chat Reports", "Litematica") $TestFileName

# Test 11: Use custom database file
Write-TestHeader "Custom Database File"
Test-Command "& '$ModManagerPath' -ModListFile '$TestDbPath' -GetModList -ApiResponseFolder '$script:TestApiResponseDir'" "Use Custom Database File" 4 $null $TestFileName

Write-Host "`nBasic Functionality Tests Complete" -ForegroundColor $Colors.Info

# Show test summary
Show-TestSummary 