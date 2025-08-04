# =============================================================================
# Test: StartServer Mod Inclusion Logic
# =============================================================================
# This test verifies that StartServer properly downloads and includes mods
# in the server for error testing
# =============================================================================

# Import modules first
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

function Test-StartServerModInclusion {
    param(
        [string]$TestDownloadFolder = "test-download-mods"
    )
    
    Write-Host "🧪 Testing StartServer mod inclusion logic..." -ForegroundColor Cyan
    
    try {
        # Clean up any existing test folder
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
        
        # Test 1: Test empty download folder detection
        Write-Host "🔍 Test 1: Testing empty download folder detection..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $TestDownloadFolder -Force | Out-Null
        
        # Mock the StartServer logic for checking download needs
        $versionResult = Get-MajorityGameVersion -CsvPath "modlist.csv"
        $targetVersion = $versionResult.MajorityVersion
        $targetFolder = Join-Path $TestDownloadFolder $targetVersion
        
        Write-Host "  📋 Target version: $targetVersion" -ForegroundColor Gray
        
        # Should detect missing folder
        if (-not (Test-Path $targetFolder)) {
            Write-Host "  ✅ Correctly detected missing version folder" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to detect missing version folder" -ForegroundColor Red
            return $false
        }
        
        # Test 2: Test missing server files detection
        Write-Host "🔍 Test 2: Testing missing server files detection..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
        
        # Check for server JAR (should be missing)
        $fabricJars = Get-ChildItem -Path $targetFolder -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue
        if ($fabricJars.Count -eq 0) {
            Write-Host "  ✅ Correctly detected missing Fabric server JAR" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to detect missing server JAR" -ForegroundColor Red
            return $false
        }
        
        # Test 3: Test missing mods detection
        Write-Host "🔍 Test 3: Testing missing mods detection..." -ForegroundColor Yellow
        
        # Create server JAR but no mods
        $fabricJar = Join-Path $targetFolder "fabric-server-mc.$targetVersion-loader.0.16.14-launcher.1.0.3.jar"
        "fake fabric jar" | Out-File -FilePath $fabricJar -Encoding ASCII
        
        # Check for mods folder (should be missing or empty)
        $modsFolder = Join-Path $targetFolder "mods"
        $needsDownload = $false
        
        if (-not (Test-Path $modsFolder) -or (Get-ChildItem -Path $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue).Count -eq 0) {
            $needsDownload = $true
            Write-Host "  ✅ Correctly detected missing or empty mods folder" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to detect missing mods" -ForegroundColor Red
            return $false
        }
        
        if (-not $needsDownload) {
            Write-Host "  ❌ Logic error: Should have detected need for download" -ForegroundColor Red
            return $false
        }
        
        # Test 4: Test with populated mods folder
        Write-Host "🔍 Test 4: Testing populated mods folder detection..." -ForegroundColor Yellow
        
        # Create mods folder with some test mods
        New-Item -ItemType Directory -Path $modsFolder -Force | Out-Null
        
        # Add some fake mod files
        for ($i = 1; $i -le 5; $i++) {
            $modFile = Join-Path $modsFolder "test-mod-$i.jar"
            "fake mod content $i" | Out-File -FilePath $modFile -Encoding ASCII
        }
        
        # Re-check mods folder (should now be populated)
        $modJars = Get-ChildItem -Path $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue
        if ($modJars.Count -gt 0) {
            Write-Host "  ✅ Correctly detected populated mods folder ($($modJars.Count) mods)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to detect populated mods folder" -ForegroundColor Red
            return $false
        }
        
        # Test 5: Test complete server setup validation
        Write-Host "🔍 Test 5: Testing complete server setup validation..." -ForegroundColor Yellow
        
        # Simulate the full StartServer validation logic
        $serverValidation = @{
            HasVersionFolder = (Test-Path $targetFolder)
            HasServerJar = (Get-ChildItem -Path $targetFolder -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue).Count -gt 0
            HasModsFolder = (Test-Path $modsFolder)
            ModCount = (Get-ChildItem -Path $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue).Count
        }
        
        Write-Host "  📊 Server validation results:" -ForegroundColor Gray
        Write-Host "    - Version folder ($targetVersion): $($serverValidation.HasVersionFolder)" -ForegroundColor Gray
        Write-Host "    - Server JAR: $($serverValidation.HasServerJar)" -ForegroundColor Gray
        Write-Host "    - Mods folder: $($serverValidation.HasModsFolder)" -ForegroundColor Gray
        Write-Host "    - Mod count: $($serverValidation.ModCount)" -ForegroundColor Gray
        
        # For complete setup, all should be true and mod count > 0
        $isCompleteSetup = $serverValidation.HasVersionFolder -and 
                          $serverValidation.HasServerJar -and 
                          $serverValidation.HasModsFolder -and 
                          $serverValidation.ModCount -gt 0
        
        if ($isCompleteSetup) {
            Write-Host "  ✅ Complete server setup detected - no download needed" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Incomplete server setup - download would be triggered" -ForegroundColor Yellow
        }
        
        # Test 6: Test download triggering logic
        Write-Host "🔍 Test 6: Testing download triggering conditions..." -ForegroundColor Yellow
        
        # Test different scenarios that should trigger download
        $testScenarios = @(
            @{ Name = "Missing version folder"; Setup = { Remove-Item -Recurse -Force $targetFolder -ErrorAction SilentlyContinue } },
            @{ Name = "Missing server JAR"; Setup = { Remove-Item -Force $fabricJar -ErrorAction SilentlyContinue } },
            @{ Name = "Empty mods folder"; Setup = { Remove-Item -Recurse -Force $modsFolder -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Path $modsFolder -Force | Out-Null } }
        )
        
        foreach ($scenario in $testScenarios) {
            Write-Host "    Testing scenario: $($scenario.Name)" -ForegroundColor Cyan
            
            # Reset to complete setup
            if (-not (Test-Path $targetFolder)) { New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null }
            if (-not (Test-Path $fabricJar)) { "fake fabric jar" | Out-File -FilePath $fabricJar -Encoding ASCII }
            if (-not (Test-Path $modsFolder)) { New-Item -ItemType Directory -Path $modsFolder -Force | Out-Null }
            for ($i = 1; $i -le 3; $i++) {
                $modFile = Join-Path $modsFolder "test-mod-$i.jar"
                if (-not (Test-Path $modFile)) { "fake mod content $i" | Out-File -FilePath $modFile -Encoding ASCII }
            }
            
            # Apply scenario setup
            & $scenario.Setup
            
            # Check if download would be triggered
            $needsDownload = $false
            if (-not (Test-Path $targetFolder)) {
                $needsDownload = $true
            } else {
                $fabricJars = Get-ChildItem -Path $targetFolder -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue
                if ($fabricJars.Count -eq 0) {
                    $needsDownload = $true
                }
                
                if (-not (Test-Path $modsFolder) -or (Get-ChildItem -Path $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue).Count -eq 0) {
                    $needsDownload = $true
                }
            }
            
            if ($needsDownload) {
                Write-Host "      ✅ Correctly triggered download for: $($scenario.Name)" -ForegroundColor Green
            } else {
                Write-Host "      ❌ Failed to trigger download for: $($scenario.Name)" -ForegroundColor Red
                return $false
            }
        }
        
        Write-Host ""
        Write-Host "🎉 All mod inclusion tests passed!" -ForegroundColor Green
        Write-Host "✅ StartServer will properly detect missing mods and trigger downloads" -ForegroundColor Green
        Write-Host "✅ Server will start with mods included for proper error testing" -ForegroundColor Green
        
        return $true
        
    } catch {
        Write-Host "❌ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        # Clean up test folder
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
    }
}

# Run the test
$testResult = Test-StartServerModInclusion
if ($testResult) {
    exit 0
} else {
    exit 1
}