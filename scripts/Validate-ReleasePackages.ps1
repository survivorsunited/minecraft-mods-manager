# =============================================================================
# Validate-ReleasePackages.ps1
# =============================================================================
# Downloads modpack-*.zip from a GitHub release and validates that each package
# contains the correct mods (expected list from modlist.csv per version).
# Uses relaxed version matching: same mod base name counts as a match.
# Modpack does not include server JARs: server/launcher/installer entries are excluded
# from expected and root server JARs in zip are ignored (not counted as extra).
# Extra shaderpacks allowed.
# =============================================================================

param(
    [string]$ReleaseTag = "",
    [string]$DatabaseFile = "modlist.csv",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $OutputDir) { $OutputDir = Join-Path $ProjectRoot "release-validation" }

# Ensure we run from project root and load modules
Set-Location $ProjectRoot
. .\src\Import-Modules.ps1 | Out-Null

# Resolve database path
$CsvPath = if ([System.IO.Path]::IsPathRooted($DatabaseFile)) { $DatabaseFile } else { (Join-Path $ProjectRoot $DatabaseFile) }
if (-not (Test-Path $CsvPath)) { Write-Error "Database not found: $CsvPath"; exit 1 }

# Helper: get base mod key for relaxed matching (from New-Release.ps1 logic).
# Treat mods/server/X and mods/X as same key so release packs that put server mods in mods/ still validate.
function Get-BaseModKey([string]$relPath) {
    if ($relPath -notlike "mods/*" -and $relPath -notlike "shaderpacks/*" -and $relPath -notlike "datapacks/*") { return $null }
    $folder = if ($relPath.StartsWith("mods/optional/")) { "mods/optional/" } elseif ($relPath.StartsWith("mods/server/")) { "mods/" } elseif ($relPath.StartsWith("mods/")) { "mods/" } elseif ($relPath.StartsWith("shaderpacks/")) { "shaderpacks/" } else { "datapacks/" }
    $file = $relPath.Substring($relPath.IndexOf("/") + 1).TrimEnd("/")
    if ($file.StartsWith("server/")) { $file = $file.Substring(7) }
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $m = [System.Text.RegularExpressions.Regex]::Match($name, "^(.*?)(?:[-_]?)(?=\d)")
    $base = if ($m.Success -and $m.Groups.Count -gt 1 -and $m.Groups[1].Value.Trim().Length -gt 0) { $m.Groups[1].Value.TrimEnd("-", "_") } else { $name }
    return ($folder + $base.ToLower())
}
# Return primary base key and any aliases (e.g. xaerominimap-fabric <-> xaeros_minimap) for relaxed pairing.
function Get-BaseModKeyAndAliases([string]$relPath) {
    $primary = Get-BaseModKey $relPath
    if (-not $primary) { return @($primary) }
    $aliases = @($primary)
    $b = $primary -replace "^mods/optional/|^mods/|^shaderpacks/|^datapacks/", ""
    if ($b -match "xaerominimap") { $aliases += ($primary -replace "xaerominimap[^/]*$", "xaeros_minimap") }
    if ($b -match "xaeroworldmap") { $aliases += ($primary -replace "xaeroworldmap[^/]*$", "xaeros_world_map") }
    return $aliases
}

# Parse version from modpack zip name: modpack-1.21.8 -> 1.21.8, modpack-next-1.21.9 -> 1.21.9, modpack-latest-1.21.11 -> 1.21.11
function Get-VersionFromZipName([string]$zipName) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($zipName)
    if ($base -match "^modpack-next-(.+)$") { return $Matches[1].Trim() }
    if ($base -match "^modpack-latest-(.+)$") { return $Matches[1].Trim() }
    if ($base -match "^modpack-(.+)$") { return $Matches[1].Trim() }
    return $null
}

# Get expected file list for a version (mods, shaderpacks, datapacks only).
# Exclude mods/server/* - modpack does not include server/launcher/installer JARs.
$expectedFilter = { ($_ -like "mods/*" -or $_ -like "shaderpacks/*" -or $_ -like "datapacks/*") -and $_ -notlike "mods/server/*" }

# Download release assets: modpack-*.zip
if (-not $ReleaseTag) {
    $ReleaseTag = (gh release list --limit 1 --json tagName -q ".[0].tagName" 2>$null)
    if (-not $ReleaseTag) { Write-Error "No release found and -ReleaseTag not set"; exit 1 }
    Write-Host "Using latest release: $ReleaseTag" -ForegroundColor Cyan
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Push-Location $OutputDir
try {
    gh release download $ReleaseTag --pattern "modpack-*.zip" --clobber 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to download release $ReleaseTag"; exit 1 }
} finally {
    Pop-Location
}

$zips = Get-ChildItem -Path $OutputDir -Filter "modpack-*.zip" -File -ErrorAction SilentlyContinue
if (-not $zips -or $zips.Count -eq 0) { Write-Error "No modpack-*.zip found in $OutputDir"; exit 1 }

Write-Host ""
Write-Host "Validating $($zips.Count) package(s) against database: $CsvPath" -ForegroundColor Cyan
Write-Host ""

$allPass = $true
$report = @()

Add-Type -AssemblyName "System.IO.Compression.FileSystem"
foreach ($zip in $zips) {
    $version = Get-VersionFromZipName $zip.Name
    if (-not $version) { Write-Host "  Skip (no version): $($zip.Name)" -ForegroundColor Gray; continue }
    Write-Host "  Checking $($zip.Name) (version $version)..." -ForegroundColor Gray
    try {
        $expected = Get-ExpectedReleaseFiles -Version $version -CsvPath $CsvPath | Where-Object $expectedFilter
        $expectedSet = New-Object System.Collections.Generic.HashSet[string]
        $null = $expected | ForEach-Object { $expectedSet.Add($_) | Out-Null }
        $actualList = @()
        $zipFullPath = $zip.FullName
        $archive = [System.IO.Compression.ZipFile]::OpenRead($zipFullPath)
        try {
            foreach ($entry in $archive.Entries) {
                $name = $entry.FullName.TrimEnd("/")
                if ($name -eq "") { continue }
                if ($entry.Length -eq 0 -and $entry.FullName.EndsWith("/")) { continue }
                if ($name -match "^(mods/|shaderpacks/|datapacks/)" -and $name -notlike "mods/block/*") {
                    # Exclude mods/server/* - modpack does not need server JARs; ignore if present
                    if ($name -notlike "mods/server/*") { $actualList += $name }
                }
                # Root server JARs (minecraft_server*, fabric-server*): do not add to actualList - modpack does not need them; ignore
            }
        } finally {
            $archive.Dispose()
        }
        $actualSet = New-Object System.Collections.Generic.HashSet[string]
        $null = $actualList | ForEach-Object { $actualSet.Add($_) | Out-Null }
        $missing = @(); foreach ($e in $expectedSet) { if (-not $actualSet.Contains($e)) { $missing += $e } }
        $extra = @(); foreach ($a in $actualSet) { if (-not $expectedSet.Contains($a)) { $extra += $a } }
        # Relaxed matching: same base key (or alias) = version-only difference
        $expectedByBase = @{}; foreach ($e in $missing) { foreach ($k in (Get-BaseModKeyAndAliases $e)) { if ($k) { if (-not $expectedByBase.ContainsKey($k)) { $expectedByBase[$k] = @() }; $expectedByBase[$k] += $e } } }
        $actualByBase = @{}; foreach ($a in $extra) { $k = Get-BaseModKey $a; if ($k) { if (-not $actualByBase.ContainsKey($k)) { $actualByBase[$k] = @() }; $actualByBase[$k] += $a } }
        $pairedMissing = New-Object System.Collections.Generic.HashSet[string]
        $pairedExtra = New-Object System.Collections.Generic.HashSet[string]
        foreach ($k in $expectedByBase.Keys) {
            if ($actualByBase.ContainsKey($k)) {
                foreach ($eItem in $expectedByBase[$k]) { $pairedMissing.Add($eItem) | Out-Null }
                foreach ($aItem in $actualByBase[$k]) { $pairedExtra.Add($aItem) | Out-Null }
            }
        }
        $missing = $missing | Where-Object { -not $pairedMissing.Contains($_) }
        $extra = $extra | Where-Object { -not $pairedExtra.Contains($_) }
        # Allow extra shaderpacks (packs often bundle more than CSV lists)
        $extraNonShader = @($extra | Where-Object { $_ -notlike "shaderpacks/*" })
        $pass = ($missing.Count -eq 0 -and $extraNonShader.Count -eq 0)
        if ($pass) {
            Write-Host "    PASS (expected $($expectedSet.Count) items)" -ForegroundColor Green
            $report += [pscustomobject]@{ Package = $zip.Name; Version = $version; Result = "PASS"; Expected = $expectedSet.Count; Missing = 0; Extra = 0 }
        } else {
            $allPass = $false
            $missingCount = $missing.Count
            $extraCount = $extraNonShader.Count
            if ($extra.Count -ne $extraNonShader.Count) { Write-Host "    (ignoring $($extra.Count - $extraNonShader.Count) extra shaderpacks)" -ForegroundColor Gray }
            Write-Host "    FAIL (missing: $missingCount, extra: $extraCount)" -ForegroundColor Red
            if ($missing.Count -gt 0) { $missing | Select-Object -First 5 | ForEach-Object { Write-Host "      missing: $_" -ForegroundColor Red }; if ($missing.Count -gt 5) { Write-Host "      ... and $($missing.Count - 5) more" -ForegroundColor Red } }
            if ($extraNonShader.Count -gt 0) { $extraNonShader | Select-Object -First 5 | ForEach-Object { Write-Host "      extra: $_" -ForegroundColor DarkYellow }; if ($extraNonShader.Count -gt 5) { Write-Host "      ... and $($extraNonShader.Count - 5) more" -ForegroundColor DarkYellow } }
            $report += [pscustomobject]@{ Package = $zip.Name; Version = $version; Result = "FAIL"; Expected = $expectedSet.Count; Missing = $missing.Count; Extra = $extraNonShader.Count }
        }
    } catch {
        $allPass = $false
        Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $report += [pscustomobject]@{ Package = $zip.Name; Version = $version; Result = "ERROR"; Expected = 0; Missing = 0; Extra = 0 }
    }
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
$report | Format-Table -AutoSize
$reportPath = Join-Path $OutputDir "validation-report.txt"
$report | Format-Table -AutoSize | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Report saved: $reportPath" -ForegroundColor Gray
if (-not $allPass) { exit 1 }
exit 0
