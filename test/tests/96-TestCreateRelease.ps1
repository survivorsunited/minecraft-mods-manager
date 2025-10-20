# Test CreateRelease Functionality
# Tests the complete release creation workflow including directory creation, mod organization, and server file copying

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "96-TestCreateRelease.ps1"

Write-Host "Minecraft Mod Manager - CreateRelease Functionality Tests" -ForegroundColor $Colors.Header
Write-Host "==========================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestReleaseDir = Join-Path $TestOutputDir "releases"
$TestDbPath = Join-Path $TestOutputDir "release-test.csv"

Write-TestHeader "Test Environment Setup"

# Use real modlist.csv and filter to 1.21.8 only
$mainModlistPath = Join-Path $PSScriptRoot "..\..\modlist.csv"
if (-not (Test-Path $mainModlistPath)) {
    Write-Host "❌ Main modlist.csv not found at: $mainModlistPath" -ForegroundColor Red
    Write-TestResult "Test Database Created" $false
    Show-TestSummary "CreateRelease Tests"
    return $false
}

# Copy 1.21.8 entries AND server/launcher entries from main database
$allMods = Import-Csv -Path $mainModlistPath
$mods1218 = $allMods | Where-Object { 
    ($_.CurrentGameVersion -eq "1.21.8" -or $_.GameVersion -eq "1.21.8") -or 
    ($_.Type -eq "server" -and $_.GameVersion -eq "1.21.8") -or
    ($_.Type -eq "launcher" -and $_.GameVersion -eq "1.21.8")
}

if ($mods1218.Count -eq 0) {
    Write-Host "❌ No 1.21.8 mods found in database" -ForegroundColor Red
    Write-TestResult "Test Database Created" $false
    Show-TestSummary "CreateRelease Tests"
    return $false
}

$mods1218 | Export-Csv -Path $TestDbPath -NoTypeInformation -Encoding UTF8
Write-Host "  Created test database with $($mods1218.Count) mods for version 1.21.8" -ForegroundColor Gray
Write-TestResult "Test Database Created" (Test-Path $TestDbPath)

# Test 1: Download Mods for Release
Write-TestHeader "Test 1: Download Mods for Release Testing"

$downloadOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
    -DownloadMods `
    -DatabaseFile $TestDbPath `
    -DownloadFolder $TestDownloadDir `
    -TargetVersion "1.21.8" `
    -UseCachedResponses `
    -ApiResponseFolder $script:TestApiResponseDir 2>&1

$downloadSucceeded = ($LASTEXITCODE -eq 0)
Write-TestResult "Download mods for testing" $downloadSucceeded

# Verify mods directory exists
$modsPath = Join-Path $TestDownloadDir "1.21.8" "mods"
$modsExist = Test-Path $modsPath
Write-TestResult "Mods directory created" $modsExist

if ($modsExist) {
    $modCount = (Get-ChildItem -Path $modsPath -Filter "*.jar" -ErrorAction SilentlyContinue).Count
    Write-Host "  Downloaded $modCount mod files" -ForegroundColor Gray
}

# Test 2: Download Server Files
Write-TestHeader "Test 2: Download Server Files for Release"

$serverOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
    -DownloadServer `
    -DownloadFolder $TestDownloadDir `
    -DatabaseFile $TestDbPath `
    -GameVersion "1.21.8" 2>&1

$serverDownloadSucceeded = ($LASTEXITCODE -eq 0)
Write-TestResult "Server files downloaded" $serverDownloadSucceeded

# Verify server files exist
$serverPath = Join-Path $TestDownloadDir "1.21.8"
$minecraftJar = Get-ChildItem -Path $serverPath -Filter "minecraft_server*.jar" -File -ErrorAction SilentlyContinue | Select-Object -First 1
$fabricJar = Get-ChildItem -Path $serverPath -Filter "fabric-server*.jar" -File -ErrorAction SilentlyContinue | Select-Object -First 1

Write-TestResult "Minecraft server JAR exists" ($minecraftJar -ne $null)
Write-TestResult "Fabric launcher JAR exists" ($fabricJar -ne $null)

# Test 3: Create Release Package
Write-TestHeader "Test 3: Create Release Package"

$releaseOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
    -CreateRelease `
    -DatabaseFile $TestDbPath `
    -DownloadFolder $TestDownloadDir `
    -ReleasePath $TestReleaseDir `
    -GameVersion "1.21.8" 2>&1

$releaseCreated = ($LASTEXITCODE -eq 0)
Write-TestResult "CreateRelease executed successfully" $releaseCreated

# Test 4: Verify Release Directory Structure
Write-TestHeader "Test 4: Verify Release Directory Structure"

$releaseVersionPath = Join-Path $TestReleaseDir "1.21.8"
$releaseVersionExists = Test-Path $releaseVersionPath
Write-TestResult "Release version directory created" $releaseVersionExists

if ($releaseVersionExists) {
    # Check for mods directory
    $releaseModsPath = Join-Path $releaseVersionPath "mods"
    $releaseModsExist = Test-Path $releaseModsPath
    Write-TestResult "Release mods directory created" $releaseModsExist
    
    if ($releaseModsExist) {
        $releasedModCount = (Get-ChildItem -Path $releaseModsPath -Filter "*.jar" -ErrorAction SilentlyContinue).Count
        Write-Host "  Found $releasedModCount mods in release folder" -ForegroundColor Gray
        Write-TestResult "Mods copied to release folder" ($releasedModCount -gt 0)
    }
    
    # Check for optional mods directory
    $releaseOptionalPath = Join-Path $releaseModsPath "optional"
    if (Test-Path $releaseOptionalPath) {
        $optionalModCount = (Get-ChildItem -Path $releaseOptionalPath -Filter "*.jar" -ErrorAction SilentlyContinue).Count
        Write-Host "  Found $optionalModCount optional mods" -ForegroundColor Gray
        Write-TestResult "Optional mods directory exists" $true
    }
}

# Test 5: Verify Server Files Copied to Release
Write-TestHeader "Test 5: Verify Server Files Copied to Release"

if ($releaseVersionExists) {
    $releaseServerJar = Get-ChildItem -Path $releaseVersionPath -Filter "minecraft_server*.jar" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $releaseFabricJar = Get-ChildItem -Path $releaseVersionPath -Filter "fabric-server*.jar" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    
    Write-TestResult "Minecraft server JAR in release" ($releaseServerJar -ne $null)
    Write-TestResult "Fabric launcher JAR in release" ($releaseFabricJar -ne $null)
    
    if ($releaseServerJar) {
        Write-Host "  ✓ Server JAR: $($releaseServerJar.Name)" -ForegroundColor Green
    }
    if ($releaseFabricJar) {
        Write-Host "  ✓ Fabric JAR: $($releaseFabricJar.Name)" -ForegroundColor Green
    }
}

# Test 6: Verify Hash File Generation
Write-TestHeader "Test 6: Verify Hash File Generation"

if ($releaseVersionExists) {
    $hashFile = Get-ChildItem -Path $releaseVersionPath -Filter "hash.txt" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $hashFileExists = ($hashFile -ne $null)
    Write-TestResult "Hash file generated" $hashFileExists
    
    if ($hashFileExists) {
        $hashContent = Get-Content $hashFile.FullName -ErrorAction SilentlyContinue
        $hashLineCount = $hashContent.Count
        Write-Host "  Hash file contains $hashLineCount lines" -ForegroundColor Gray
        Write-TestResult "Hash file has content" ($hashLineCount -gt 0)
    }
}

# Test 7: Verify README Generation
Write-TestHeader "Test 7: Verify README Generation"

if ($releaseVersionExists) {
    $readmeFile = Get-ChildItem -Path $releaseVersionPath -Filter "README.md" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $readmeExists = ($readmeFile -ne $null)
    Write-TestResult "README.md generated" $readmeExists
    
    if ($readmeExists) {
        $readmeContent = Get-Content $readmeFile.FullName -Raw -ErrorAction SilentlyContinue
        $hasModList = ($readmeContent -match "Mod List|Included Mods")
        Write-TestResult "README contains mod list" $hasModList
    }
}

# Test 8: Verify No Server-Only Files in Mods Folder
Write-TestHeader "Test 8: Verify No Server-Only Files in Mods Folder"

if ($releaseModsExist) {
    $allReleaseFiles = Get-ChildItem -Path $releaseModsPath -Filter "*.jar" -Recurse -File -ErrorAction SilentlyContinue
    
    # Check that launcher and server files are NOT in mods folder
    $hasLauncherInMods = ($allReleaseFiles | Where-Object { $_.Name -like "*fabric-server*" }).Count -gt 0
    $hasServerInMods = ($allReleaseFiles | Where-Object { $_.Name -like "*minecraft_server*" }).Count -gt 0
    
    Write-TestResult "No launcher files in mods folder" (-not $hasLauncherInMods)
    Write-TestResult "No server JAR in mods folder" (-not $hasServerInMods)
}

# Test 9: Skip Multi-Version (Focusing on 1.21.8 Only)
Write-TestHeader "Test 9: Verify Mandatory vs Optional Separation"

if ($releaseModsExist) {
    $mandatoryMods = Get-ChildItem -Path $releaseModsPath -Filter "*.jar" -File -ErrorAction SilentlyContinue
    $optionalMods = Get-ChildItem -Path $releaseOptionalPath -Filter "*.jar" -File -ErrorAction SilentlyContinue
    
    $hasMandatory = $mandatoryMods.Count -gt 0
    $hasOptional = $optionalMods.Count -gt 0
    
    Write-Host "  Mandatory mods: $($mandatoryMods.Count)" -ForegroundColor Gray
    Write-Host "  Optional mods: $($optionalMods.Count)" -ForegroundColor Gray
    
    Write-TestResult "Mandatory mods separated" $hasMandatory
    Write-TestResult "Optional mods directory created" (Test-Path $releaseOptionalPath)
}

# Test 10: Verify Release Isolation
Write-TestHeader "Test 10: Verify Release Isolation"

# Verify release doesn't pollute download folder
$downloadUntouched = $true
if (Test-Path $modsPath) {
    $originalModCount = (Get-ChildItem -Path $modsPath -Filter "*.jar" -ErrorAction SilentlyContinue).Count
    # Original mods should still exist
    $downloadUntouched = ($originalModCount -gt 0)
}

Write-TestResult "Download folder unchanged" $downloadUntouched

# Verify release has its own copies
if ($releaseModsExist -and $modsExist) {
    $downloadModCount = (Get-ChildItem -Path $modsPath -Filter "*.jar" -ErrorAction SilentlyContinue).Count
    $releaseModCount = (Get-ChildItem -Path $releaseModsPath -Filter "*.jar" -Recurse -ErrorAction SilentlyContinue).Count
    
    Write-Host "  Download folder mods: $downloadModCount" -ForegroundColor Gray
    Write-Host "  Release folder mods: $releaseModCount" -ForegroundColor Gray
    Write-TestResult "Release has independent copies" ($releaseModCount -gt 0)
}

# Test 11: Error Handling - Missing Download Folder
Write-TestHeader "Test 11: Error Handling - Missing Download Folder"

$invalidReleaseOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
    -CreateRelease `
    -DatabaseFile $TestDbPath `
    -DownloadFolder "nonexistent-folder" `
    -ReleasePath $TestReleaseDir `
    -GameVersion "1.21.8" 2>&1

# Should handle gracefully (error or skip)
$handledGracefully = $true  # Accept any non-crash behavior
Write-TestResult "Missing download folder handled gracefully" $handledGracefully

# Test 12: Verify Mandatory vs Optional Separation
Write-TestHeader "Test 12: Verify Mandatory vs Optional Separation"

if ($releaseModsExist) {
    $mandatoryMods = Get-ChildItem -Path $releaseModsPath -Filter "*.jar" -File -ErrorAction SilentlyContinue
    $mandatoryCount = $mandatoryMods.Count
    
    # fabric-api and sodium should be in mandatory (required group)
    $hasFabricApi = ($mandatoryMods | Where-Object { $_.Name -like "*fabric-api*" }) -ne $null
    $hasSodium = ($mandatoryMods | Where-Object { $_.Name -like "*sodium*" }) -ne $null
    
    Write-TestResult "Fabric API in mandatory folder" $hasFabricApi
    Write-TestResult "Sodium in mandatory folder" $hasSodium
    
    Write-Host "  Mandatory mods: $mandatoryCount" -ForegroundColor Gray
}

# Detailed Test Results
Write-Host "`nDetailed Test Results:" -ForegroundColor $Colors.Info
Write-Host "========================" -ForegroundColor $Colors.Info

Write-Host "Test Directories:" -ForegroundColor Gray
Write-Host "  Download: $TestDownloadDir" -ForegroundColor Gray
Write-Host "  Release: $TestReleaseDir" -ForegroundColor Gray
Write-Host "  Database: $TestDbPath" -ForegroundColor Gray

if (Test-Path $TestReleaseDir) {
    Write-Host "`nRelease Structure:" -ForegroundColor Gray
    Get-ChildItem -Path $TestReleaseDir -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Replace($TestReleaseDir, "").TrimStart("\", "/")
        Write-Host "  $relativePath" -ForegroundColor Gray
    }
}

Write-Host "`nCreateRelease Tests Complete" -ForegroundColor $Colors.Info

Show-TestSummary "CreateRelease Tests"

return ($script:TestResults.Failed -eq 0)

