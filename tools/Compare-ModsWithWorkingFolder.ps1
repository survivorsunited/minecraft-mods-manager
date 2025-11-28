# Compare mods in modlist.csv with mods in working folder
# This script analyzes differences between the modpack database and a working mod folder

param(
    [string]$WorkingFolder = "temp\mods-arkadi\mods",
    [string]$ModListPath = "modlist.csv",
    [string]$OutputPath = "temp\mod-comparison-report.txt"
)

Write-Host "=== Mod Comparison Analysis ===" -ForegroundColor Cyan
Write-Host "Working Folder: $WorkingFolder" -ForegroundColor Gray
Write-Host "Mod List: $ModListPath" -ForegroundColor Gray
Write-Host ""

# Function to extract mod ID from filename
function Get-ModIdFromFilename {
    param([string]$Filename)
    
    # Remove .jar extension
    $name = $Filename -replace '\.jar$', ''
    
    # Common patterns to extract mod ID:
    # - fabric-api-0.134.0+1.21.8.jar -> fabric-api
    # - cloth-config-19.0.147-fabric.jar -> cloth-config
    # - CraterLib-Fabric-1.21.6-2.1.5.jar -> craterlib
    # - Xaeros_Minimap_25.2.16_Fabric_1.21.8.jar -> xaeros-minimap
    # - inventoryhud.fabric.1.21.8-3.4.27.jar -> inventoryhud
    
    # Try to match known patterns
    if ($name -match '^fabric-api') { return 'fabric-api' }
    if ($name -match '^cloth-config') { return 'cloth-config' }
    if ($name -match '^CraterLib') { return 'craterlib' }
    if ($name -match '^Xaeros_Minimap') { return 'xaeros-minimap' }
    if ($name -match '^XaerosWorldMap') { return 'xaeros-world-map' }
    if ($name -match '^journeymap') { return 'journeymap' }
    if ($name -match '^waystones') { return 'waystones' }
    if ($name -match '^balm-fabric') { return 'balm' }
    if ($name -match '^architectury') { return 'architectury-api' }
    if ($name -match '^collective') { return 'collective' }
    if ($name -match '^jamlib') { return 'jamlib' }
    if ($name -match '^libIPN') { return 'libipn' }
    if ($name -match '^ukulib') { return 'ukulib' }
    if ($name -match '^placeholder-api') { return 'placeholder-api' }
    if ($name -match '^modmenu') { return 'modmenu' }
    if ($name -match '^ForgeConfigAPIPort') { return 'forge-config-api-port' }
    if ($name -match '^fabric-language-kotlin') { return 'fabric-language-kotlin' }
    if ($name -match '^inventoryhud') { return 'inventoryhud' }
    if ($name -match '^inventorymanagement') { return 'inventorymanagement' }
    if ($name -match '^inventorytotem') { return 'inventorytotem' }
    if ($name -match '^litematica') { return 'litematica' }
    if ($name -match '^malilib') { return 'malilib' }
    if ($name -match '^lithium') { return 'lithium' }
    if ($name -match '^sodium') { return 'sodium' }
    if ($name -match '^iris') { return 'iris' }
    if ($name -match '^spark') { return 'spark' }
    if ($name -match '^ferritecore') { return 'ferritecore' }
    if ($name -match '^c2me') { return 'c2me' }
    if ($name -match '^LuckPerms') { return 'luckperms' }
    if ($name -match '^FabricProxy-Lite') { return 'fabricproxy-lite' }
    if ($name -match '^SimpleDiscordLink') { return 'simplediscordlink' }
    if ($name -match '^voicechat') { return 'voicechat' }
    if ($name -match '^servux') { return 'servux' }
    if ($name -match '^open-parties-and-claims') { return 'open-parties-and-claims' }
    if ($name -match '^ItemLocks') { return 'itemlocks' }
    if ($name -match '^Jade') { return 'jade' }
    if ($name -match '^shulkerboxtooltip') { return 'shulkerboxtooltip' }
    if ($name -match '^travelersbackpack') { return 'travelersbackpack' }
    if ($name -match '^toms_storage') { return 'toms-storage' }
    if ($name -match '^reinforced-chests') { return 'reinforced-chests' }
    if ($name -match '^basicstorage') { return 'basicstorage' }
    if ($name -match '^biggerenderchests') { return 'biggerenderchests' }
    if ($name -match '^syncmatica') { return 'syncmatica' }
    if ($name -match '^worldedit') { return 'worldedit' }
    if ($name -match '^lambdynamiclights') { return 'lambdynamiclights' }
    if ($name -match '^BetterF3') { return 'betterf3' }
    if ($name -match '^Clumps') { return 'clumps' }
    if ($name -match '^styled-chat') { return 'styled-chat' }
    if ($name -match '^styledplayerlist') { return 'styledplayerlist' }
    if ($name -match '^stackrefill') { return 'stackrefill' }
    if ($name -match '^graves') { return 'graves' }
    if ($name -match '^custom-portals') { return 'custom-portals' }
    if ($name -match '^blast') { return 'blast' }
    if ($name -match '^CraftableNameTag') { return 'craftablenametag' }
    if ($name -match '^armored-elytra') { return 'armored-elytra' }
    if ($name -match '^pets-dont-die') { return 'pets-dont-die' }
    if ($name -match '^InertiaAntiCheat') { return 'inertiaanticheat' }
    if ($name -match '^appleskin') { return 'appleskin' }
    if ($name -match '^antixray') { return 'antixray' }
    if ($name -match '^Amecs-Reborn') { return 'amecs' }
    if ($name -match '^baleofsugarcane') { return 'baleofsugarcane' }
    if ($name -match '^better-gold-recycling') { return 'better-gold-recycling' }
    if ($name -match '^copper-recycling') { return 'copper-recycling' }
    if ($name -match '^diamond-recycling') { return 'diamond-recycling' }
    if ($name -match '^netherite-recycling') { return 'netherite-recycling' }
    if ($name -match '^sandstone-recycling') { return 'sandstone-recycling' }
    if ($name -match '^furnacerecycle') { return 'furnacerecycle' }
    if ($name -match '^recycle-blast') { return 'recycle-blast' }
    if ($name -match '^su-compostables') { return 'su-compostables' }
    if ($name -match '^wooltostring') { return 'wooltostring' }
    if ($name -match '^mastercutter') { return 'mastercutter' }
    if ($name -match '^egg-of-capitalism') { return 'egg-of-capitalism' }
    if ($name -match '^owo-lib') { return 'owo-lib' }
    if ($name -match '^yet_another_config_lib') { return 'yet-another-config-lib' }
    
    # Generic fallback: take first part before version numbers or special chars
    $parts = $name -split '[_\-\+\.]'
    if ($parts.Count -gt 0) {
        $firstPart = $parts[0].ToLower()
        # Skip common prefixes
        if ($firstPart -notin @('fabric', 'mc', 'mod')) {
            return $firstPart
        }
        if ($parts.Count -gt 1) {
            return ($parts[0..1] -join '-').ToLower()
        }
    }
    
    return $name.ToLower()
}

# Read working folder mods
Write-Host "Reading mods from working folder..." -ForegroundColor Yellow
$workingMods = @{}
if (Test-Path $WorkingFolder) {
    $jarFiles = Get-ChildItem -Path $WorkingFolder -Filter "*.jar" -ErrorAction SilentlyContinue
    foreach ($jar in $jarFiles) {
        $modId = Get-ModIdFromFilename $jar.Name
        $workingMods[$modId] = @{
            Filename = $jar.Name
            ModId = $modId
            FullPath = $jar.FullName
        }
    }
    Write-Host "  Found $($workingMods.Count) mods in working folder" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Working folder not found: $WorkingFolder" -ForegroundColor Red
    exit 1
}

# Read modlist.csv
Write-Host "Reading mods from modlist.csv..." -ForegroundColor Yellow
$modListMods = @{}
if (Test-Path $ModListPath) {
    $csv = Import-Csv -Path $ModListPath
    $modEntries = $csv | Where-Object { $_.Type -eq "mod" }
    foreach ($mod in $modEntries) {
        $modId = $mod.ID.ToLower()
        if (-not $modListMods.ContainsKey($modId)) {
            $modListMods[$modId] = @()
        }
        $modListMods[$modId] += @{
            ModId = $modId
            Name = $mod.Name
            CurrentVersion = $mod.CurrentVersion
            CurrentGameVersion = $mod.CurrentGameVersion
            LatestVersion = $mod.LatestVersion
            LatestGameVersion = $mod.LatestGameVersion
            Jar = $mod.Jar
            Group = $mod.Group
        }
    }
    Write-Host "  Found $($modListMods.Count) unique mod IDs in modlist.csv" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Mod list not found: $ModListPath" -ForegroundColor Red
    exit 1
}

# Compare mods
Write-Host ""
Write-Host "=== Comparison Results ===" -ForegroundColor Cyan
Write-Host ""

$report = @()
$report += "=== MOD COMPARISON REPORT ==="
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Working Folder: $WorkingFolder"
$report += "Mod List: $ModListPath"
$report += ""

# Find mods in working folder but not in modlist
$missingFromModList = @()
$report += "=== MODS IN WORKING FOLDER BUT NOT IN MODLIST ==="
$report += ""
foreach ($modId in $workingMods.Keys | Sort-Object) {
    if (-not $modListMods.ContainsKey($modId)) {
        $missingFromModList += $modId
        $report += "  MISSING: $modId (File: $($workingMods[$modId].Filename))"
        Write-Host "  MISSING: $modId (File: $($workingMods[$modId].Filename))" -ForegroundColor Red
    }
}
if ($missingFromModList.Count -eq 0) {
    $report += "  (None - all working folder mods are in modlist)"
    Write-Host "  (None - all working folder mods are in modlist)" -ForegroundColor Green
}
$report += ""

# Find mods in modlist but not in working folder
$missingFromWorking = @()
$report += "=== MODS IN MODLIST BUT NOT IN WORKING FOLDER ==="
$report += ""
foreach ($modId in $modListMods.Keys | Sort-Object) {
    if (-not $workingMods.ContainsKey($modId)) {
        $missingFromWorking += $modId
        $modInfo = $modListMods[$modId][0]
        $report += "  MISSING: $modId ($($modInfo.Name)) - Current: $($modInfo.CurrentVersion) for $($modInfo.CurrentGameVersion)"
        Write-Host "  MISSING: $modId ($($modInfo.Name))" -ForegroundColor Yellow
    }
}
if ($missingFromWorking.Count -eq 0) {
    $report += "  (None - all modlist mods are in working folder)"
    Write-Host "  (None - all modlist mods are in working folder)" -ForegroundColor Green
}
$report += ""

# Compare versions for mods in both
$report += "=== VERSION COMPARISONS (Mods in Both) ==="
$report += ""
$versionMismatches = @()
$versionMatches = @()

foreach ($modId in $workingMods.Keys | Sort-Object) {
    if ($modListMods.ContainsKey($modId)) {
        $workingFile = $workingMods[$modId].Filename
        $modInfo = $modListMods[$modId][0]
        
        # Try to extract version from filename
        $fileVersion = $null
        if ($workingFile -match '(\d+\.\d+\.\d+[^\.]*?)(?:\.jar|$)') {
            $fileVersion = $matches[1]
        } elseif ($workingFile -match '(\d+\.\d+[^\.]*?)(?:\.jar|$)') {
            $fileVersion = $matches[1]
        }
        
        # Compare with modlist versions
        $currentVersion = $modInfo.CurrentVersion
        $latestVersion = $modInfo.LatestVersion
        
        $matchStatus = "UNKNOWN"
        if ($fileVersion -and $currentVersion) {
            if ($workingFile -match [regex]::Escape($currentVersion)) {
                $matchStatus = "MATCHES_CURRENT"
                $versionMatches += $modId
            } elseif ($workingFile -match [regex]::Escape($latestVersion)) {
                $matchStatus = "MATCHES_LATEST"
                $versionMatches += $modId
            } else {
                $matchStatus = "VERSION_MISMATCH"
                $versionMismatches += @{
                    ModId = $modId
                    FileVersion = $fileVersion
                    CurrentVersion = $currentVersion
                    LatestVersion = $latestVersion
                    Filename = $workingFile
                }
            }
        }
        
        if ($matchStatus -ne "UNKNOWN") {
            $report += "  $modId :"
            $report += "    File: $workingFile"
            $report += "    ModList Current: $currentVersion ($($modInfo.CurrentGameVersion))"
            $report += "    ModList Latest: $latestVersion ($($modInfo.LatestGameVersion))"
            $report += "    Status: $matchStatus"
            $report += ""
        }
    }
}

if ($versionMismatches.Count -gt 0) {
    Write-Host ""
    Write-Host "  VERSION MISMATCHES FOUND: $($versionMismatches.Count)" -ForegroundColor Red
    foreach ($mismatch in $versionMismatches) {
        Write-Host "    $($mismatch.ModId): File has different version" -ForegroundColor Yellow
        Write-Host "      File: $($mismatch.Filename)" -ForegroundColor Gray
        Write-Host "      Current in DB: $($mismatch.CurrentVersion)" -ForegroundColor Gray
        Write-Host "      Latest in DB: $($mismatch.LatestVersion)" -ForegroundColor Gray
    }
} else {
    Write-Host "  All version comparisons completed" -ForegroundColor Green
}

# Summary
$report += ""
$report += "=== SUMMARY ==="
$report += "Total mods in working folder: $($workingMods.Count)"
$report += "Total unique mod IDs in modlist: $($modListMods.Count)"
$report += "Mods in working folder but not in modlist: $($missingFromModList.Count)"
$report += "Mods in modlist but not in working folder: $($missingFromWorking.Count)"
$report += "Version mismatches: $($versionMismatches.Count)"
$report += "Version matches: $($versionMatches.Count)"

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total mods in working folder: $($workingMods.Count)" -ForegroundColor White
Write-Host "Total unique mod IDs in modlist: $($modListMods.Count)" -ForegroundColor White
Write-Host "Mods in working folder but not in modlist: $($missingFromModList.Count)" -ForegroundColor $(if ($missingFromModList.Count -eq 0) { "Green" } else { "Red" })
Write-Host "Mods in modlist but not in working folder: $($missingFromWorking.Count)" -ForegroundColor $(if ($missingFromWorking.Count -eq 0) { "Green" } else { "Yellow" })
Write-Host "Version mismatches: $($versionMismatches.Count)" -ForegroundColor $(if ($versionMismatches.Count -eq 0) { "Green" } else { "Red" })
Write-Host "Version matches: $($versionMatches.Count)" -ForegroundColor Green

# Save report
$reportDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$report | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host ""
Write-Host "Report saved to: $OutputPath" -ForegroundColor Green


