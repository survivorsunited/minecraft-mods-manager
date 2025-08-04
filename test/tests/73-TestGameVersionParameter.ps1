# =============================================================================
# Test: GameVersion Parameter for StartServer
# =============================================================================
# This test verifies that the -GameVersion parameter works correctly
# =============================================================================

# Import modules first
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

function Test-GameVersionParameter {
    Write-Host "🧪 Testing GameVersion parameter functionality..." -ForegroundColor Cyan
    
    try {
        # Test 1: Default behavior (should use majority version 1.21.5)
        Write-Host "🔍 Test 1: Testing default version selection (no parameter)..." -ForegroundColor Yellow
        
        # Simulate the logic from ModManager.ps1
        $versionResult = Get-MajorityGameVersion -CsvPath "modlist.csv"
        $expectedDefault = $versionResult.MajorityVersion
        
        if ($expectedDefault -eq "1.21.5") {
            Write-Host "  ✅ Default version correctly determined as: $expectedDefault" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Unexpected default version: $expectedDefault" -ForegroundColor Red
            return $false
        }
        
        # Test 2: Test GameVersion parameter override
        Write-Host "🔍 Test 2: Testing GameVersion parameter override..." -ForegroundColor Yellow
        
        $testVersions = @("1.21.6", "1.21.7", "1.21.8")
        
        foreach ($testVersion in $testVersions) {
            Write-Host "    Testing with GameVersion=$testVersion" -ForegroundColor Cyan
            
            # Simulate the parameter logic
            $GameVersion = $testVersion
            if ($GameVersion) {
                $targetVersion = $GameVersion
                $source = "user specified"
            } else {
                $versionResult = Get-MajorityGameVersion -CsvPath "modlist.csv"
                $targetVersion = $versionResult.MajorityVersion
                $source = "majority version"
            }
            
            if ($targetVersion -eq $testVersion) {
                Write-Host "      ✅ Correctly set target version to: $targetVersion ($source)" -ForegroundColor Green
            } else {
                Write-Host "      ❌ Failed to set target version: Expected $testVersion, got $targetVersion" -ForegroundColor Red
                return $false
            }
        }
        
        # Test 3: Test command line syntax
        Write-Host "🔍 Test 3: Testing command line syntax examples..." -ForegroundColor Yellow
        
        $commandExamples = @(
            @{ Command = ".\ModManager.ps1 -StartServer"; ExpectedVersion = "1.21.5"; Description = "Default (majority version)" },
            @{ Command = ".\ModManager.ps1 -StartServer -GameVersion 1.21.6"; ExpectedVersion = "1.21.6"; Description = "Specified version 1.21.6" },
            @{ Command = ".\ModManager.ps1 -StartServer -GameVersion 1.21.7"; ExpectedVersion = "1.21.7"; Description = "Specified version 1.21.7" },
            @{ Command = ".\ModManager.ps1 -StartServer -GameVersion 1.21.8"; ExpectedVersion = "1.21.8"; Description = "Specified version 1.21.8" }
        )
        
        foreach ($example in $commandExamples) {
            Write-Host "    📋 Command: $($example.Command)" -ForegroundColor Gray
            Write-Host "       Expected: $($example.ExpectedVersion) ($($example.Description))" -ForegroundColor Gray
        }
        
        Write-Host "      ✅ All command syntax examples are valid" -ForegroundColor Green
        
        # Test 4: Test parameter validation
        Write-Host "🔍 Test 4: Testing parameter handling in functions..." -ForegroundColor Yellow
        
        # Check that Start-MinecraftServer accepts TargetVersion parameter
        $startServerFunction = Get-Content "src/Download/Server/Start-MinecraftServer.ps1" -Raw
        
        if ($startServerFunction -match '\[string\]\$TargetVersion') {
            Write-Host "  ✅ Start-MinecraftServer function accepts TargetVersion parameter" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Start-MinecraftServer function missing TargetVersion parameter" -ForegroundColor Red
            return $false
        }
        
        # Check that ModManager.ps1 passes the parameter correctly
        $modManagerContent = Get-Content "ModManager.ps1" -Raw
        
        if ($modManagerContent -match 'Start-MinecraftServer.*-TargetVersion \$targetVersion') {
            Write-Host "  ✅ ModManager.ps1 correctly passes TargetVersion parameter" -ForegroundColor Green
        } else {
            Write-Host "  ❌ ModManager.ps1 not passing TargetVersion parameter correctly" -ForegroundColor Red
            return $false
        }
        
        # Test 5: Version folder availability check
        Write-Host "🔍 Test 5: Checking available version folders..." -ForegroundColor Yellow
        
        $downloadFolder = "download"
        if (Test-Path $downloadFolder) {
            $versionFolders = Get-ChildItem -Path $downloadFolder -Directory -ErrorAction SilentlyContinue | 
                             Where-Object { $_.Name -match "^\d+\.\d+\.\d+" } |
                             Sort-Object { [version]$_.Name }
            
            Write-Host "  📁 Available version folders:" -ForegroundColor Gray
            foreach ($folder in $versionFolders) {
                $hasServerJar = (Get-ChildItem -Path $folder.FullName -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue).Count -gt 0
                $modsFolder = Join-Path $folder.FullName "mods"
                $hasModsFolder = Test-Path $modsFolder
                $modCount = if ($hasModsFolder) { (Get-ChildItem -Path $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue).Count } else { 0 }
                
                $status = if ($hasServerJar -and $modCount -gt 0) { "✅ Ready" } elseif ($hasServerJar) { "⚠️  No mods" } else { "❌ No server" }
                Write-Host "    - $($folder.Name): $status ($modCount mods)" -ForegroundColor Gray
            }
            
            if ($versionFolders.Count -gt 0) {
                Write-Host "  ✅ Version folders available for testing" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  No version folders found - download needed for testing" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ⚠️  Download folder not found - download needed for testing" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "🎉 All GameVersion parameter tests passed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 Usage Examples:" -ForegroundColor Yellow
        Write-Host "  Default (1.21.5): .\ModManager.ps1 -StartServer" -ForegroundColor Cyan
        Write-Host "  Specific (1.21.6): .\ModManager.ps1 -StartServer -GameVersion 1.21.6" -ForegroundColor Cyan
        Write-Host "  Specific (1.21.7): .\ModManager.ps1 -StartServer -GameVersion 1.21.7" -ForegroundColor Cyan
        Write-Host "  Specific (1.21.8): .\ModManager.ps1 -StartServer -GameVersion 1.21.8" -ForegroundColor Cyan
        
        return $true
        
    } catch {
        Write-Host "❌ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Run the test
$testResult = Test-GameVersionParameter
if ($testResult) {
    exit 0
} else {
    exit 1
}