# =============================================================================
# Test: Next Version Selection and URL Saving
# =============================================================================
# This test verifies:
# 1. StartServer uses "next version" instead of majority version
# 2. Resolved URLs are saved back to database
# =============================================================================

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name
$TestFileName = "74-TestNextVersionAndUrlSaving.ps1"

# Initialize test environment
Initialize-TestEnvironment $TestFileName

# Get test output folder
$TestOutputDir = Get-TestOutputFolder $TestFileName

# Import modules
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

function Test-NextVersionAndUrlSaving {
    Write-Host "🧪 Testing next version selection and URL saving..." -ForegroundColor Cyan
    
    try {
        # Test 1: Test Calculate-NextGameVersion function
        Write-Host "🔍 Test 1: Testing Calculate-NextGameVersion function..." -ForegroundColor Yellow
        
        $nextVersionResult = Calculate-NextGameVersion -CsvPath "modlist.csv"
        
        if ($nextVersionResult) {
            Write-Host "  ✅ Calculate-NextGameVersion function works" -ForegroundColor Green
            Write-Host "    - Majority version: $($nextVersionResult.MajorityVersion)" -ForegroundColor Gray
            Write-Host "    - Next version: $($nextVersionResult.NextVersion)" -ForegroundColor Gray
            Write-Host "    - Mod count for next: $($nextVersionResult.ModCount)" -ForegroundColor Gray
            Write-Host "    - Is highest: $($nextVersionResult.IsHighestVersion)" -ForegroundColor Gray
        } else {
            Write-Host "  ❌ Calculate-NextGameVersion function failed" -ForegroundColor Red
            return $false
        }
        
        # Test 2: Verify the next version logic
        Write-Host "🔍 Test 2: Verifying next version logic..." -ForegroundColor Yellow
        
        # Expected: Majority is 1.21.5, next should be 1.21.6
        if ($nextVersionResult.MajorityVersion -eq "1.21.5") {
            if ($nextVersionResult.NextVersion -eq "1.21.6") {
                Write-Host "  ✅ Correct next version: 1.21.6 after majority 1.21.5" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Wrong next version: Expected 1.21.6, got $($nextVersionResult.NextVersion)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "  ⚠️  Unexpected majority version: $($nextVersionResult.MajorityVersion)" -ForegroundColor Yellow
        }
        
        # Test 3: Test URL saving function
        Write-Host "🔍 Test 3: Testing Update-ModUrlInDatabase function..." -ForegroundColor Yellow
        
        # Create a test CSV file in test output directory
        $testCsvPath = Join-Path $TestOutputDir "test-modlist.csv"
        $testData = @"
Group,Type,GameVersion,ID,Loader,Name,Version,Url,Jar,VersionUrl,LatestVersion,LatestVersionUrl,LatestGameVersion,ClientSide,ServerSide,Host,ProjectUrl,IconUrl,Description,Category
required,server,1.21.7,minecraft-server-1.21.7,fabric,Minecraft Server,1.21.7,,minecraft_server.1.21.7.jar,,,1.21.7,required,required,mojang,https://minecraft.net,,"Official Minecraft server",server
"@
        $testData | Out-File -FilePath $testCsvPath -Encoding UTF8
        
        # Test updating URL
        $testUrl = "https://piston-data.mojang.com/v1/objects/test123/server.jar"
        $updateResult = Update-ModUrlInDatabase -ModId "minecraft-server-1.21.7" -NewUrl $testUrl -CsvPath $testCsvPath
        
        if ($updateResult) {
            Write-Host "  ✅ Update-ModUrlInDatabase function works" -ForegroundColor Green
            
            # Verify the URL was actually updated
            $updatedData = Import-Csv -Path $testCsvPath
            $updatedMod = $updatedData | Where-Object { $_.ID -eq "minecraft-server-1.21.7" }
            
            if ($updatedMod.Url -eq $testUrl) {
                Write-Host "  ✅ URL correctly saved to database" -ForegroundColor Green
            } else {
                Write-Host "  ❌ URL not saved correctly: Expected $testUrl, got $($updatedMod.Url)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "  ❌ Update-ModUrlInDatabase function failed" -ForegroundColor Red
            return $false
        }
        
        # Clean up test file
        Remove-Item -Path $testCsvPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$testCsvPath.backup.*" -Force -ErrorAction SilentlyContinue
        
        # Test 4: Verify StartServer logic changes
        Write-Host "🔍 Test 4: Verifying StartServer uses next version logic..." -ForegroundColor Yellow
        
        $modManagerContent = Get-Content "ModManager.ps1" -Raw
        
        # Check for next version logic
        if ($modManagerContent -match 'Calculate-NextGameVersion.*effectiveModListPath') {
            Write-Host "  ✅ ModManager.ps1 uses Calculate-NextGameVersion" -ForegroundColor Green
        } else {
            Write-Host "  ❌ ModManager.ps1 missing Calculate-NextGameVersion call" -ForegroundColor Red
            return $false
        }
        
        if ($modManagerContent -match 'next version after.*for testing') {
            Write-Host "  ✅ ModManager.ps1 has next version messaging" -ForegroundColor Green
        } else {
            Write-Host "  ❌ ModManager.ps1 missing next version messaging" -ForegroundColor Red
            return $false
        }
        
        # Test 5: Verify Start-MinecraftServer logic changes
        Write-Host "🔍 Test 5: Verifying Start-MinecraftServer uses next version logic..." -ForegroundColor Yellow
        
        $startServerContent = Get-Content "src/Download/Server/Start-MinecraftServer.ps1" -Raw
        
        if ($startServerContent -match 'Calculate-NextGameVersion.*ModListPath') {
            Write-Host "  ✅ Start-MinecraftServer.ps1 uses Calculate-NextGameVersion" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Start-MinecraftServer.ps1 missing Calculate-NextGameVersion call" -ForegroundColor Red
            return $false
        }
        
        # Test 6: Verify URL saving integration
        Write-Host "🔍 Test 6: Verifying URL saving integration..." -ForegroundColor Yellow
        
        $downloadServerContent = Get-Content "src/Download/Server/Download-ServerFilesFromDatabase.ps1" -Raw
        
        if ($downloadServerContent -match 'Update-ModUrlInDatabase.*NewUrl.*resolvedUrl') {
            Write-Host "  ✅ Download-ServerFilesFromDatabase.ps1 saves resolved URLs" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Download-ServerFilesFromDatabase.ps1 missing URL saving logic" -ForegroundColor Red
            return $false
        }
        
        if ($downloadServerContent -match 'URL saved to database for future use') {
            Write-Host "  ✅ Download-ServerFilesFromDatabase.ps1 has URL saving messaging" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Download-ServerFilesFromDatabase.ps1 missing URL saving messaging" -ForegroundColor Red
            return $false
        }
        
        Write-Host ""
        Write-Host "🎉 All next version and URL saving tests passed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 New Behavior:" -ForegroundColor Yellow
        Write-Host "  Default StartServer: .\ModManager.ps1 -StartServer" -ForegroundColor Cyan
        Write-Host "    - Now uses NEXT version ($($nextVersionResult.NextVersion)) for testing" -ForegroundColor Gray
        Write-Host "    - Tests if newer versions work with current mods" -ForegroundColor Gray
        Write-Host "    - Saves resolved URLs to database automatically" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Specific version: .\ModManager.ps1 -StartServer -GameVersion 1.21.5" -ForegroundColor Cyan
        Write-Host "    - Uses specified version (e.g., 1.21.5)" -ForegroundColor Gray
        
        return $true
        
    } catch {
        Write-Host "❌ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Run the test
$testResult = Test-NextVersionAndUrlSaving
if ($testResult) {
    exit 0
} else {
    exit 1
}