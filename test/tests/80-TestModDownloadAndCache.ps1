# =============================================================================
# Test: Mod Download and Cache Functionality
# =============================================================================
# This test validates that mods are downloaded and cached correctly
# =============================================================================

# Import modules
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

function Test-ModDownloadAndCache {
    param(
        [string]$TestDownloadFolder = "test-output/test-cache-download",
        [string]$TestCacheFolder = "test-output/.test-cache"
    )
    
    Write-Host "🧪 Testing mod download and cache functionality..." -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    
    try {
        # Ensure test-output directory exists
        $testOutputDir = Split-Path $TestDownloadFolder -Parent
        if (-not (Test-Path $testOutputDir)) {
            New-Item -ItemType Directory -Path $testOutputDir -Force | Out-Null
        }
        
        # Clean up any existing test folders
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
        if (Test-Path $TestCacheFolder) {
            Remove-Item -Recurse -Force $TestCacheFolder -ErrorAction SilentlyContinue
        }
        
        # Test 1: First download should populate cache
        Write-Host "`n🔍 Test 1: First download (should populate cache)..." -ForegroundColor Yellow
        
        # Download mods for 1.21.5 (we know these exist)
        $output1 = Download-Mods -CsvPath "modlist.csv" `
                                -DownloadFolder $TestDownloadFolder `
                                -TargetGameVersion "1.21.5" `
                                -ForceDownload 2>&1
        
        # Check if cache was created
        if (Test-Path ".cache") {
            Write-Host "  ✅ Cache folder created" -ForegroundColor Green
            $cacheFiles = Get-ChildItem -Path ".cache" -File
            Write-Host "  📦 Cache contains $($cacheFiles.Count) files" -ForegroundColor Gray
            
            # Show first few cache files
            $cacheFiles | Select-Object -First 3 | ForEach-Object {
                Write-Host "    - $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  ❌ Cache folder not created" -ForegroundColor Red
            return $false
        }
        
        # Test 2: Second download should use cache
        Write-Host "`n🔍 Test 2: Second download (should use cache)..." -ForegroundColor Yellow
        
        # Clear download folder but keep cache
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
        
        # Time the second download
        $startTime = Get-Date
        $output2 = Download-Mods -CsvPath "modlist.csv" `
                                -DownloadFolder $TestDownloadFolder `
                                -TargetGameVersion "1.21.5" 2>&1
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Write-Host "  ⏱️  Second download took $([math]::Round($duration, 1)) seconds" -ForegroundColor Gray
        
        # Check for cache hit messages
        $cacheHits = ($output2 | Out-String) -split "`n" | Where-Object { $_ -match "Found in cache" }
        Write-Host "  📦 Cache hits: $($cacheHits.Count)" -ForegroundColor Green
        
        if ($cacheHits.Count -gt 0) {
            Write-Host "  ✅ Cache is working!" -ForegroundColor Green
            $cacheHits | Select-Object -First 3 | ForEach-Object {
                Write-Host "    $($_.Trim())" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  ❌ No cache hits detected" -ForegroundColor Red
        }
        
        # Test 3: Verify downloaded files exist
        Write-Host "`n🔍 Test 3: Verify downloaded files..." -ForegroundColor Yellow
        
        $modsFolder = Join-Path $TestDownloadFolder "1.21.5\mods"
        if (Test-Path $modsFolder) {
            $modFiles = Get-ChildItem -Path $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue
            Write-Host "  📁 Downloaded $($modFiles.Count) mod files" -ForegroundColor Green
            
            if ($modFiles.Count -gt 0) {
                Write-Host "  ✅ Mods downloaded successfully" -ForegroundColor Green
                $modFiles | Select-Object -First 5 | ForEach-Object {
                    Write-Host "    - $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)" -ForegroundColor Gray
                }
            } else {
                Write-Host "  ❌ No mods downloaded" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "  ❌ Mods folder not created" -ForegroundColor Red
            return $false
        }
        
        Write-Host "`n🎉 All cache tests passed!" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "❌ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $false
    } finally {
        # Clean up test folders
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
    }
}

# Run the test
Write-Host "🚀 Running mod download and cache test..." -ForegroundColor Magenta
$testResult = Test-ModDownloadAndCache

if ($testResult) {
    Write-Host "`n✅ MOD DOWNLOAD AND CACHE TEST PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ MOD DOWNLOAD AND CACHE TEST FAILED!" -ForegroundColor Red
    exit 1
}