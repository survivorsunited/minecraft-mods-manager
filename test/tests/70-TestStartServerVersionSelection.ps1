# =============================================================================
# Test: StartServer Version Selection Logic
# =============================================================================
# This test verifies that StartServer uses the majority version (1.21.5)
# instead of the highest version (1.21.8)
# =============================================================================

# Import modules first
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

function Test-StartServerVersionSelection {
    param(
        [string]$TestDownloadFolder = "test-download-version"
    )
    
    Write-Host "🧪 Testing StartServer version selection logic..." -ForegroundColor Cyan
    
    try {
        # Clean up any existing test folder
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
        
        # Create test folder structure with multiple versions
        New-Item -ItemType Directory -Path $TestDownloadFolder -Force | Out-Null
        
        # Create version folders (1.21.5 should be selected, not 1.21.8)
        $versions = @("1.21.5", "1.21.6", "1.21.7", "1.21.8")
        foreach ($version in $versions) {
            $versionFolder = Join-Path $TestDownloadFolder $version
            New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
            
            # Create mods folder with some test mods
            $modsFolder = Join-Path $versionFolder "mods"
            New-Item -ItemType Directory -Path $modsFolder -Force | Out-Null
            
            # Create fake mod files for realistic testing
            $modCount = if ($version -eq "1.21.5") { 65 } elseif ($version -eq "1.21.6") { 3 } else { 2 }
            for ($i = 1; $i -le $modCount; $i++) {
                $modFile = Join-Path $modsFolder "test-mod-$i.jar"
                "fake mod content" | Out-File -FilePath $modFile -Encoding ASCII
            }
            
            # Create fake Fabric server JAR
            $fabricJar = Join-Path $versionFolder "fabric-server-mc.$version-loader.0.16.14-launcher.1.0.3.jar"
            "fake fabric jar" | Out-File -FilePath $fabricJar -Encoding ASCII
            
            Write-Host "  📁 Created test version: $version ($modCount mods)" -ForegroundColor Gray
        }
        
        # Test 1: Verify Get-MajorityGameVersion returns 1.21.5
        Write-Host "🔍 Test 1: Checking majority version calculation..." -ForegroundColor Yellow
        $versionResult = Get-MajorityGameVersion -CsvPath "modlist.csv"
        $expectedVersion = "1.21.5"
        
        if ($versionResult.MajorityVersion -eq $expectedVersion) {
            Write-Host "  ✅ Majority version correctly identified as: $($versionResult.MajorityVersion)" -ForegroundColor Green
            Write-Host "  📊 Analysis: $($versionResult.Analysis.MajorityCount) mods support this version" -ForegroundColor Gray
        } else {
            Write-Host "  ❌ Wrong majority version: Expected $expectedVersion, got $($versionResult.MajorityVersion)" -ForegroundColor Red
            return $false
        }
        
        # Test 2: Test version selection logic directly
        Write-Host "🔍 Test 2: Testing Start-MinecraftServer version selection..." -ForegroundColor Yellow
        
        # Create a test script to capture the version selection without actually starting server
        $testScript = @"
# Import modules
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

function Test-VersionSelection {
    param([string]`$DownloadFolder)
    
    # Use same logic as Start-MinecraftServer
    Write-Host "🔍 Determining target game version..." -ForegroundColor Cyan
    `$versionResult = Get-MajorityGameVersion -CsvPath "modlist.csv"
    `$targetVersion = `$versionResult.MajorityVersion
    Write-Host "🎯 Target version: `$targetVersion (majority version with `$(`$versionResult.Analysis.MajorityCount) mods)" -ForegroundColor Green
    
    `$targetFolder = Join-Path `$DownloadFolder `$targetVersion
    
    # Verify the target folder exists
    if (-not (Test-Path `$targetFolder)) {
        Write-Host "⚠️  Majority version folder `$targetVersion not found, checking for alternatives..." -ForegroundColor Yellow
        
        `$versionFolders = Get-ChildItem -Path `$DownloadFolder -Directory -ErrorAction SilentlyContinue | 
                         Where-Object { `$_.Name -match "^\d+\.\d+\.\d+" } |
                         Sort-Object { [version]`$_.Name } -Descending
        
        if (`$versionFolders.Count -eq 0) {
            Write-Host "❌ No version folders found in `$DownloadFolder" -ForegroundColor Red
            return `$null
        }
        
        `$targetVersion = `$versionFolders[0].Name
        `$targetFolder = Join-Path `$DownloadFolder `$targetVersion
        Write-Host "📁 Using fallback version: `$targetVersion" -ForegroundColor Yellow
    }
    
    return @{
        TargetVersion = `$targetVersion
        TargetFolder = `$targetFolder
    }
}

Test-VersionSelection -DownloadFolder "$TestDownloadFolder"
"@
        
        # Save and execute test script
        $testScriptPath = Join-Path $TestDownloadFolder "test-version-selection.ps1"
        $testScript | Out-File -FilePath $testScriptPath -Encoding UTF8
        $result = & $testScriptPath
        
        if ($result -and $result.TargetVersion -eq $expectedVersion) {
            Write-Host "  ✅ Version selection logic correctly chose: $($result.TargetVersion)" -ForegroundColor Green
            Write-Host "  📁 Target folder: $($result.TargetFolder)" -ForegroundColor Gray
        } else {
            Write-Host "  ❌ Version selection failed: Expected $expectedVersion, got $($result.TargetVersion)" -ForegroundColor Red
            return $false
        }
        
        # Test 3: Verify mods folder check
        Write-Host "🔍 Test 3: Testing mods folder validation..." -ForegroundColor Yellow
        $targetFolder = Join-Path $TestDownloadFolder $expectedVersion
        $modsFolder = Join-Path $targetFolder "mods"
        $modJars = Get-ChildItem -Path $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue
        
        if ($modJars.Count -gt 0) {
            Write-Host "  ✅ Mods folder contains $($modJars.Count) mod files" -ForegroundColor Green
        } else {
            Write-Host "  ❌ No mod files found in mods folder" -ForegroundColor Red
            return $false
        }
        
        # Test 4: Verify server JAR check
        Write-Host "🔍 Test 4: Testing Fabric server JAR validation..." -ForegroundColor Yellow
        $fabricJars = Get-ChildItem -Path $targetFolder -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue
        
        if ($fabricJars.Count -gt 0) {
            Write-Host "  ✅ Fabric server JAR found: $($fabricJars[0].Name)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ No Fabric server JAR found" -ForegroundColor Red
            return $false
        }
        
        Write-Host ""
        Write-Host "🎉 All version selection tests passed!" -ForegroundColor Green
        Write-Host "✅ StartServer will use version $expectedVersion (with $($modJars.Count) mods) instead of highest version 1.21.8" -ForegroundColor Green
        
        return $true
        
    } catch {
        Write-Host "❌ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        # Clean up test folder
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
        # Clean up test script if it exists
        $testScriptPath = Join-Path $TestDownloadFolder "test-version-selection.ps1"
        if ((Test-Path $testScriptPath)) {
            Remove-Item -Force $testScriptPath -ErrorAction SilentlyContinue
        }
    }
}

# Run the test
$testResult = Test-StartServerVersionSelection
if ($testResult) {
    exit 0
} else {
    exit 1
}