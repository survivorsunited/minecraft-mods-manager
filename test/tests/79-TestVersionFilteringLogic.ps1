# =============================================================================
# Test: Version Filtering Logic
# =============================================================================
# This test shows why no mods download for 1.21.6
# =============================================================================

# Import modules
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

function Test-VersionFilteringLogic {
    Write-Host "🧪 Testing version filtering logic..." -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    
    try {
        # Load all mods
        $allMods = Import-Csv "modlist.csv"
        
        # Test 1: Show mod distribution by version
        Write-Host "`n🔍 Test 1: Mod distribution by game version" -ForegroundColor Yellow
        $modsByVersion = $allMods | Where-Object { $_.Type -eq "mod" } | Group-Object GameVersion
        
        foreach ($group in $modsByVersion | Sort-Object Name) {
            Write-Host "  Version $($group.Name): $($group.Count) mods" -ForegroundColor Gray
        }
        
        # Test 2: What happens when filtering for 1.21.6
        Write-Host "`n🔍 Test 2: Filtering for version 1.21.6" -ForegroundColor Yellow
        $filtered = $allMods | Where-Object { 
            $_.GameVersion -eq "1.21.6" -or
            $_.Type -in @("server", "launcher") -or
            [string]::IsNullOrEmpty($_.GameVersion)
        }
        
        Write-Host "  Total mods: $($allMods.Count)" -ForegroundColor Gray
        Write-Host "  After filtering for 1.21.6: $($filtered.Count)" -ForegroundColor Gray
        
        # Show what's included
        $byType = $filtered | Group-Object Type
        Write-Host "`n  What's included after filtering:" -ForegroundColor Gray
        foreach ($type in $byType) {
            Write-Host "    - $($type.Name): $($type.Count) items" -ForegroundColor Gray
        }
        
        # Test 3: The REAL issue
        Write-Host "`n🔍 Test 3: THE REAL ISSUE" -ForegroundColor Red
        $actualMods = $filtered | Where-Object { $_.Type -eq "mod" }
        Write-Host "  Actual MODS for 1.21.6: $($actualMods.Count)" -ForegroundColor Red
        
        if ($actualMods.Count -eq 0) {
            Write-Host "`n❌ NO MODS EXIST FOR VERSION 1.21.6!" -ForegroundColor Red
            Write-Host "   This is why no mods download to the 1.21.6 folder!" -ForegroundColor Red
            Write-Host "`n📋 SOLUTION OPTIONS:" -ForegroundColor Yellow
            Write-Host "   1. Add 1.21.6 versions of mods to the database" -ForegroundColor Green
            Write-Host "   2. Use -GameVersion 1.21.5 to download 1.21.5 mods" -ForegroundColor Green
            Write-Host "   3. Use -UseLatestVersion flag (will check for 1.21.6 compatible versions)" -ForegroundColor Green
        }
        
        # Test 4: Show what versions are available
        Write-Host "`n🔍 Test 4: Available game versions in database" -ForegroundColor Yellow
        $versions = $allMods | Select-Object -ExpandProperty GameVersion | Where-Object { $_ } | Sort-Object -Unique
        Write-Host "  Available versions: $($versions -join ', ')" -ForegroundColor Gray
        
        return $true
        
    } catch {
        Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Run the test
$result = Test-VersionFilteringLogic

if ($result) {
    Write-Host "`n✅ Test completed successfully" -ForegroundColor Green
    exit 0
} else {
    exit 1
}