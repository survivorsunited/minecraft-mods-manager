# Modpack Tests
# Tests modpack functionality: adding modpacks, downloading, and extracting

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

Write-Host "Minecraft Mod Manager - Modpack Tests" -ForegroundColor $Colors.Header
Write-Host "=====================================" -ForegroundColor $Colors.Header

# Note: This test file can be run independently as it sets up its own database

Initialize-TestEnvironment

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

# Test 3: Download modpack
Write-TestHeader "Download Modpack"
Test-Command "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -DownloadFolder '$TestDownloadDir' -UseCachedResponses" "Download Modpack" 2 $null $TestFileName

# Test 4: Verify modpack extraction
Write-TestHeader "Verify Modpack Extraction"
# Check that modpack files were extracted correctly
$indexFile = Join-Path $ModpackDir "modrinth.index.json"

if (Test-Path $indexFile) {
    Write-Host "✓ PASS: Found modrinth.index.json" -ForegroundColor Green
    
    # Read and validate the index file
    try {
        $indexContent = Get-Content $indexFile | ConvertFrom-Json
        $fileCount = $indexContent.files.Count
        Write-Host "✓ PASS: Modpack contains $fileCount files" -ForegroundColor Green
        
        # Check for overrides folder
        $overridesPath = Join-Path $ModpackDir "overrides"
        if (Test-Path $overridesPath) {
            Write-Host "✓ PASS: Found overrides folder" -ForegroundColor Green
        } else {
            Write-Host "⚠️  WARNING: No overrides folder found (may be normal)" -ForegroundColor Yellow
        }
        
        # Check for mods folder
        $modsPath = Join-Path $ModpackDir "mods"
        if (Test-Path $modsPath) {
            $modFiles = Get-ChildItem $modsPath -File -Filter "*.jar" -ErrorAction SilentlyContinue
            Write-Host "✓ PASS: Found $($modFiles.Count) mod JAR files" -ForegroundColor Green
        } else {
            Write-Host "⚠️  WARNING: No mods folder found" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "✗ FAIL: Could not parse modrinth.index.json" -ForegroundColor Red
    }
} else {
    Write-Host "✗ FAIL: modrinth.index.json not found" -ForegroundColor Red
}

# Test 5: Test modpack with specific version
Write-TestHeader "Add Modpack with Specific Version"
Test-Command "& '$ModManagerPath' -AddMod -AddModId '1KVo5zza' -AddModName 'Fabulously Optimized v4.9.0' -AddModType 'modpack' -AddModVersion '4.9.0' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Modpack with Version" 2 $null $TestFileName

# Test 6: Download modpack with version
Write-TestHeader "Download Modpack with Version"
Test-Command "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -DownloadFolder '$TestDownloadDir' -UseCachedResponses" "Download Modpack with Version" 2 $null $TestFileName

# Test 7: Verify modpack structure
Write-TestHeader "Verify Modpack Structure"
$expectedModpackDirs = @(
    $ModpackDir
)

$allValid = $true
foreach ($dir in $expectedModpackDirs) {
    if (Test-Path $dir) {
        Write-Host "✓ PASS: Found modpack directory: $dir" -ForegroundColor Green
        
        # Check for essential files
        $indexFile = Join-Path $dir "modrinth.index.json"
        if (Test-Path $indexFile) {
            Write-Host "  ✓ Found modrinth.index.json" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Missing modrinth.index.json" -ForegroundColor Red
            $allValid = $false
        }
        
        # List contents
        $contents = Get-ChildItem $dir -Name
        Write-Host "  📁 Contents: $($contents -join ', ')" -ForegroundColor Gray
        
    } else {
        Write-Host "✗ FAIL: Missing modpack directory: $dir" -ForegroundColor Red
        $allValid = $false
    }
}

if (-not $allValid) {
    Write-Host "Modpack structure validation failed!" -ForegroundColor Red
} else {
    Write-Host "✓ PASS: All modpack structures are valid" -ForegroundColor Green
}

Write-Host "`nModpack Tests Complete" -ForegroundColor $Colors.Info 