# =============================================================================
# Test: Actual Version Targeting (Small Integration Test)
# =============================================================================
# This test does a small-scale test to verify mods download to correct folder
# =============================================================================

# Import modules first
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

function Test-ActualVersionTargeting {
    param(
        [string]$TestDownloadFolder = "test-version-targeting",
        [string]$TestCsvPath = "test-modlist-targeting.csv"
    )
    
    Write-Host "🧪 Testing actual version targeting with small download..." -ForegroundColor Cyan
    
    try {
        # Clean up any existing test folder
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
        
        # Create a minimal test CSV with both 1.21.5 and 1.21.6 mods
        $testCsvContent = @"
Group,Type,GameVersion,ID,Loader,Name,Version,Url,Jar,VersionUrl,LatestVersion,LatestVersionUrl,LatestGameVersion,ClientSide,ServerSide,Host,ProjectUrl,IconUrl,Description,Category
required,mod,1.21.5,fabric-api,fabric,Fabric API,0.127.1+1.21.5,https://cdn.modrinth.com/data/P7dR8mSH/versions/qKKqagvD/fabric-api-0.127.1%2B1.21.5.jar,fabric-api-0.127.1+1.21.5.jar,https://cdn.modrinth.com/data/P7dR8mSH/versions/qKKqagvD/fabric-api-0.127.1%2B1.21.5.jar,0.127.2+1.21.6,https://cdn.modrinth.com/data/P7dR8mSH/versions/MuXpFqqE/fabric-api-0.127.2%2B1.21.6.jar,1.21.6,required,optional,modrinth,https://modrinth.com/mod/fabric-api,https://cdn.modrinth.com/data/P7dR8mSH/f82d2dfed32ccc6bc5d9e0b8b8a31503d4a82fd3.png,"Essential hooks for modding with Fabric.",api
required,mod,1.21.6,sodium,fabric,Sodium,mc1.21.6-0.6.13-fabric,https://cdn.modrinth.com/data/AANobbMI/versions/rE9Jlsho/sodium-fabric-0.6.13-mc1.21.6.jar,sodium-fabric-0.6.13-mc1.21.6.jar,https://cdn.modrinth.com/data/AANobbMI/versions/rE9Jlsho/sodium-fabric-0.6.13-mc1.21.6.jar,mc1.21.6-0.6.13-fabric,https://cdn.modrinth.com/data/AANobbMI/versions/rE9Jlsho/sodium-fabric-0.6.13-mc1.21.6.jar,1.21.6,required,unsupported,modrinth,https://modrinth.com/mod/sodium,https://cdn.modrinth.com/data/AANobbMI/6af1ca8c9e1de38a88dac9c98c7b19ad81d8c7b4.png,"The fastest and most compatible rendering optimization mod for Minecraft",optimization
required,server,1.21.6,minecraft-server-1.21.6,fabric,Minecraft Server,1.21.6,https://piston-data.mojang.com/v1/objects/efe20f3d6d83a4fd33e84e1bb98a13853b496e8e/server.jar,minecraft_server.1.21.6.jar,https://piston-data.mojang.com/v1/objects/efe20f3d6d83a4fd33e84e1bb98a13853b496e8e/server.jar,1.21.6,https://piston-data.mojang.com/v1/objects/efe20f3d6d83a4fd33e84e1bb98a13853b496e8e/server.jar,1.21.6,required,required,mojang,https://minecraft.net,,"Official Minecraft server",server
"@
        $testCsvContent | Out-File -FilePath $TestCsvPath -Encoding UTF8
        
        Write-Host "📋 Created test CSV with 3 entries (2 mods + 1 server)" -ForegroundColor Gray
        
        # Test 1: Download for version 1.21.5 (should get 1 mod)
        Write-Host "🔍 Test 1: Download for version 1.21.5..." -ForegroundColor Yellow
        
        Download-Mods -CsvPath $TestCsvPath -DownloadFolder $TestDownloadFolder -TargetGameVersion "1.21.5" -ForceDownload
        
        # Check results
        $modsFolder125 = Join-Path $TestDownloadFolder "1.21.5\mods"
        if (Test-Path $modsFolder125) {
            $modFiles125 = Get-ChildItem -Path $modsFolder125 -Filter "*.jar"
            Write-Host "  📊 Version 1.21.5 mods folder: $($modFiles125.Count) mods" -ForegroundColor Gray
            
            if ($modFiles125.Count -eq 1) {
                Write-Host "  ✅ Correct: 1.21.5 has 1 mod (fabric-api)" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Wrong: Expected 1 mod for 1.21.5, got $($modFiles125.Count)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "  ❌ No mods folder created for 1.21.5" -ForegroundColor Red
            return $false
        }
        
        # Test 2: Download for version 1.21.6 (should get 1 mod + existing server)
        Write-Host "🔍 Test 2: Download for version 1.21.6..." -ForegroundColor Yellow
        
        Download-Mods -CsvPath $TestCsvPath -DownloadFolder $TestDownloadFolder -TargetGameVersion "1.21.6" -ForceDownload
        
        # Check results
        $modsFolder126 = Join-Path $TestDownloadFolder "1.21.6\mods"
        if (Test-Path $modsFolder126) {
            $modFiles126 = Get-ChildItem -Path $modsFolder126 -Filter "*.jar"
            Write-Host "  📊 Version 1.21.6 mods folder: $($modFiles126.Count) mods" -ForegroundColor Gray
            
            if ($modFiles126.Count -eq 1) {
                Write-Host "  ✅ Correct: 1.21.6 has 1 mod (sodium)" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Wrong: Expected 1 mod for 1.21.6, got $($modFiles126.Count)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "  ❌ No mods folder created for 1.21.6" -ForegroundColor Red
            return $false
        }
        
        # Test 3: Verify server file is in correct location
        Write-Host "🔍 Test 3: Verify server file placement..." -ForegroundColor Yellow
        
        $serverFile126 = Join-Path $TestDownloadFolder "1.21.6\minecraft_server.1.21.6.jar"
        if (Test-Path $serverFile126) {
            Write-Host "  ✅ Server file correctly placed in 1.21.6 folder" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Server file not found in 1.21.6 folder" -ForegroundColor Red
            return $false
        }
        
        # Test 4: Verify version isolation
        Write-Host "🔍 Test 4: Verify version isolation..." -ForegroundColor Yellow
        
        # Check that 1.21.5 folder doesn't have sodium (1.21.6 mod)
        $sodiumIn125 = Get-ChildItem -Path $modsFolder125 -Filter "*sodium*" -ErrorAction SilentlyContinue
        if ($sodiumIn125.Count -eq 0) {
            Write-Host "  ✅ Version isolation works: 1.21.5 folder has no sodium (1.21.6 mod)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Version isolation failed: Found sodium in 1.21.5 folder" -ForegroundColor Red
            return $false
        }
        
        # Check that 1.21.6 folder doesn't have fabric-api from 1.21.5
        $fabricApiIn126 = Get-ChildItem -Path $modsFolder126 -Filter "*fabric-api*0.127.1*1.21.5*" -ErrorAction SilentlyContinue
        if ($fabricApiIn126.Count -eq 0) {
            Write-Host "  ✅ Version isolation works: 1.21.6 folder has no 1.21.5 fabric-api" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Version isolation failed: Found 1.21.5 fabric-api in 1.21.6 folder" -ForegroundColor Red
            return $false
        }
        
        Write-Host ""
        Write-Host "🎉 All actual version targeting tests passed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "✅ **CRITICAL FIX VERIFIED:**" -ForegroundColor Green
        Write-Host "  - Mods now download to the CORRECT version folder" -ForegroundColor Green
        Write-Host "  - Version isolation works properly" -ForegroundColor Green
        Write-Host "  - Server files placed in correct locations" -ForegroundColor Green
        Write-Host ""
        Write-Host "🚨 **THE BIG ISSUE IS FIXED!** 🚨" -ForegroundColor Green
        Write-Host "No more empty mods folders when specifying -GameVersion!" -ForegroundColor Green
        
        return $true
        
    } catch {
        Write-Host "❌ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        # Clean up test files
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
        if (Test-Path $TestCsvPath) {
            Remove-Item -Force $TestCsvPath -ErrorAction SilentlyContinue
        }
    }
}

# Run the test
$testResult = Test-ActualVersionTargeting
if ($testResult) {
    exit 0
} else {
    exit 1
}