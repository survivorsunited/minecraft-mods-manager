# Quick Server Mod Validation Script
# Validates current mods for server compatibility without downloading

param(
    [string]$DatabaseFile = "modlist.csv",
    [string]$GameVersion = "1.21.6",
    [string]$Loader = "fabric",
    [switch]$ShowDetails,
    [switch]$ServerSideOnly
)

Write-Host "Minecraft Server Mod Validation" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Get the directory of this script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir

# Set paths
$DbPath = Join-Path $RootDir $DatabaseFile
$ApiResponseDir = Join-Path $RootDir "apiresponse"

if (-not (Test-Path $DbPath)) {
    Write-Host "❌ Database file not found: $DbPath" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Database: $DatabaseFile" -ForegroundColor Gray
Write-Host "🎮 Target: Minecraft $GameVersion with $Loader" -ForegroundColor Gray
Write-Host ""

# Load the database
$mods = Import-Csv $DbPath

# Filter for server-side mods if requested
if ($ServerSideOnly) {
    $mods = $mods | Where-Object { $_.ServerSide -eq "required" -or $_.ServerSide -eq "optional" }
    Write-Host "🔍 Filtering for server-side mods only..." -ForegroundColor Yellow
}

$totalMods = $mods.Count
Write-Host "📊 Found $totalMods mods to validate" -ForegroundColor Gray
Write-Host ""

# Quick validation without full API calls
Write-Host "🔍 Running quick validation..." -ForegroundColor Yellow

# Counters
$serverCompatible = 0
$clientOnlyMods = 0
$unknownCompatibility = 0
$potentialIssues = @()

foreach ($mod in $mods) {
    $modName = $mod.Name
    $serverSide = $mod.ServerSide
    $clientSide = $mod.ClientSide
    $modGameVersion = $mod.GameVersion
    $modLoader = $mod.Loader
    
    # Check server compatibility
    switch ($serverSide) {
        "required" { 
            $serverCompatible++
            if ($ShowDetails) {
                Write-Host "  ✓ $modName (required on server)" -ForegroundColor Green
            }
        }
        "optional" { 
            $serverCompatible++
            if ($ShowDetails) {
                Write-Host "  ○ $modName (optional on server)" -ForegroundColor Yellow
            }
        }
        "unsupported" { 
            $clientOnlyMods++
            $potentialIssues += "$modName is client-only (unsupported on server)"
            if ($ShowDetails) {
                Write-Host "  ✗ $modName (client-only)" -ForegroundColor Red
            }
        }
        default { 
            $unknownCompatibility++
            $potentialIssues += "$modName has unknown server compatibility"
            if ($ShowDetails) {
                Write-Host "  ? $modName (unknown compatibility)" -ForegroundColor Magenta
            }
        }
    }
    
    # Check version compatibility
    if ($modGameVersion -ne $GameVersion) {
        $potentialIssues += "$modName targets $($modGameVersion) but server is $GameVersion"
    }
    
    # Check loader compatibility
    if ($modLoader -ne $Loader) {
        $potentialIssues += "$modName uses $($modLoader) but server uses $Loader"
    }
}

Write-Host ""
Write-Host "📊 Validation Results:" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host "  Server-compatible mods: $serverCompatible" -ForegroundColor Green
Write-Host "  Client-only mods: $clientOnlyMods" -ForegroundColor Red
Write-Host "  Unknown compatibility: $unknownCompatibility" -ForegroundColor Yellow
Write-Host "  Total issues found: $($potentialIssues.Count)" -ForegroundColor $(if ($potentialIssues.Count -gt 0) { "Red" } else { "Green" })

if ($potentialIssues.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️ Potential Issues:" -ForegroundColor Yellow
    Write-Host "===================" -ForegroundColor Yellow
    foreach ($issue in $potentialIssues) {
        Write-Host "  • $issue" -ForegroundColor Yellow
    }
}

Write-Host ""

# Server readiness assessment
$serverReadiness = [math]::Round(($serverCompatible / $totalMods) * 100, 1)

if ($clientOnlyMods -eq 0 -and $unknownCompatibility -eq 0 -and $potentialIssues.Count -eq 0) {
    Write-Host "🎉 Server is ready for deployment!" -ForegroundColor Green
    Write-Host "   All $totalMods mods are server-compatible" -ForegroundColor Green
} elseif ($clientOnlyMods -gt 0) {
    Write-Host "⚠️ Server deployment needs attention" -ForegroundColor Yellow
    Write-Host "   $clientOnlyMods client-only mods should be removed from server" -ForegroundColor Yellow
} else {
    Write-Host "🔍 Server may work but needs verification" -ForegroundColor Yellow
    Write-Host "   $unknownCompatibility mods have unknown server compatibility" -ForegroundColor Yellow
}

Write-Host "   Server readiness: $serverReadiness%" -ForegroundColor $(if ($serverReadiness -ge 90) { "Green" } elseif ($serverReadiness -ge 70) { "Yellow" } else { "Red" })

Write-Host ""
Write-Host "💡 Recommendations:" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan

if ($clientOnlyMods -gt 0) {
    Write-Host "  1. Remove client-only mods before server deployment" -ForegroundColor Yellow
}

if ($unknownCompatibility -gt 0) {
    Write-Host "  2. Verify server compatibility for unknown mods" -ForegroundColor Yellow
}

if ($potentialIssues.Count -gt 0) {
    Write-Host "  3. Review version and loader mismatches" -ForegroundColor Yellow
}

Write-Host "  4. Test server startup with a subset of mods first" -ForegroundColor Gray
Write-Host "  5. Monitor server performance after deployment" -ForegroundColor Gray

Write-Host ""
Write-Host "🚀 To continue with full validation and download:" -ForegroundColor Gray
Write-Host "   ./ModManager.ps1 -ValidateAllModVersions" -ForegroundColor Gray
Write-Host "   ./ModManager.ps1 -DownloadServer -DownloadMods" -ForegroundColor Gray