# Build a release package from already-downloaded mods without network or server validation

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [string]$CsvPath = "modlist.csv",
    # Verification behavior:
    # - strict: require exact match of expected vs actual (default)
    # - warn: report differences but continue
    # - relaxed-version: ignore version-only differences for mods (treat as match if base mod name matches)
    [ValidateSet('strict','warn','relaxed-version')]
    [string]$VerificationMode = 'strict'
)

$ErrorActionPreference = 'Stop'

Write-Host "Packaging cached download into release: $Version" -ForegroundColor Cyan

$repoRoot = Split-Path -Parent $PSScriptRoot
$downloadPath = Join-Path $repoRoot (Join-Path 'download' $Version)
if (-not (Test-Path $downloadPath)) {
    throw "download/$Version not found at $downloadPath"
}

# Ensure cache is populated for this version (mods, shaderpacks, datapacks) before building
try {
    Write-Host "Ensuring cache is populated for $Version (downloading any missing files)..." -ForegroundColor Cyan
    # Import modular functions and run the downloader targeting this version; skip server files for cache-only build
    . (Join-Path $repoRoot 'src/Import-Modules.ps1') | Out-Null
    $csvResolved = (Join-Path $repoRoot $CsvPath)
    $apiResponse = Join-Path $repoRoot 'apiresponse'
    $dlRoot = Join-Path $repoRoot 'download'
    Download-Mods -CsvPath $csvResolved -DownloadFolder $dlRoot -ApiResponseFolder $apiResponse -TargetGameVersion $Version -SkipServerFiles | Out-Null
    Write-Host "✓ Cache ensured for $Version" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Warning: Failed to pre-download missing files: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "    Continuing with existing cache contents..." -ForegroundColor Yellow
}

$sourceMods = Join-Path $downloadPath 'mods'
if (-not (Test-Path $sourceMods)) {
    throw "No mods folder found at $sourceMods"
}

# Shaderpacks source (optional)
$sourceShaderpacks = Join-Path $downloadPath 'shaderpacks'
 # Datapacks source (optional)
$sourceDatapacks = Join-Path $downloadPath 'datapacks'

# Create isolated, timestamped run directory to avoid overwriting previous runs
$baseReleaseDir = Join-Path $repoRoot (Join-Path 'releases' $Version)
$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$releaseDir = Join-Path $baseReleaseDir $runStamp
$releaseMods = Join-Path $releaseDir 'mods'
$releaseShaderpacks = Join-Path $releaseDir 'shaderpacks'
$releaseDatapacks = Join-Path $releaseDir 'datapacks'
New-Item -ItemType Directory -Path $releaseMods -Force | Out-Null

# Import Copy-ModsToRelease and run
. (Join-Path $repoRoot 'src/Release/Copy-ModsToRelease.ps1')
$ok = Copy-ModsToRelease -SourcePath $sourceMods -DestinationPath $releaseMods -CsvPath (Join-Path $repoRoot $CsvPath) -TargetGameVersion $Version
if (-not $ok) { throw "Copy-ModsToRelease failed" }

# Copy shaderpacks if present (as-is, no optional/block grouping)
if (Test-Path $sourceShaderpacks) {
    New-Item -ItemType Directory -Path $releaseShaderpacks -Force | Out-Null
    $shaderFiles = Get-ChildItem -Path $sourceShaderpacks -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip','.jar') }
    foreach ($sp in $shaderFiles) {
        Copy-Item -Path $sp.FullName -Destination (Join-Path $releaseShaderpacks $sp.Name) -Force
    }
    Write-Host "Copied $($shaderFiles.Count) shaderpack file(s) to $releaseShaderpacks" -ForegroundColor Gray
} else {
    Write-Host "No shaderpacks source found at $sourceShaderpacks (skipping)" -ForegroundColor DarkGray
}

# Copy datapack JARs into mods (respect Group from CSV) and ZIPs into datapacks
if (Test-Path $sourceDatapacks) {
    # Load CSV and filter datapacks for this version
    $csvPathResolved = (Join-Path $repoRoot $CsvPath)
    $rows = Import-Csv -Path $csvPathResolved
    function Normalize($s) { if ($null -eq $s) { return $null } ($s.ToString()).Trim() }
    $versionFilter = {
        param($r)
        $cur = Normalize $r.CurrentGameVersion
        $avail = Normalize $r.AvailableGameVersions
        if ([string]::IsNullOrWhiteSpace($cur) -and [string]::IsNullOrWhiteSpace($avail)) { return $false }
        if ($cur -eq $Version) { return $true }
        if ($avail -and $avail -match [Regex]::Escape($Version)) { return $true }
        return $false
    }
    $dpRows = $rows | Where-Object { (Normalize $_.Type) -eq 'datapack' -and (& $versionFilter $_) }

    $copiedJarCount = 0
    $copiedZipCount = 0
    foreach ($d in $dpRows) {
        $jarName = Normalize $d.Jar
        if ([string]::IsNullOrWhiteSpace($jarName)) { continue }
        $src = Join-Path $sourceDatapacks $jarName
        if (-not (Test-Path $src)) { continue }
        $ext = [System.IO.Path]::GetExtension($jarName).ToLower()
        if ($ext -eq '.jar') {
            $grp = (Normalize $d.Group)
            if ([string]::IsNullOrWhiteSpace($grp)) { $grp = 'required' }
            $destDir = switch ($grp.ToLower()) {
                'optional' { Join-Path $releaseMods 'optional' }
                'block'    { Join-Path $releaseMods 'block' }
                default    { $releaseMods }
            }
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            Copy-Item -Path $src -Destination (Join-Path $destDir $jarName) -Force
            $copiedJarCount++
        } elseif ($ext -eq '.zip') {
            if (-not (Test-Path $releaseDatapacks)) { New-Item -ItemType Directory -Path $releaseDatapacks -Force | Out-Null }
            Copy-Item -Path $src -Destination (Join-Path $releaseDatapacks $jarName) -Force
            $copiedZipCount++
        }
    }
    Write-Host "Datapacks copied -> jars to mods: $copiedJarCount, zips to datapacks: $copiedZipCount" -ForegroundColor Gray
} else {
    Write-Host "No datapacks source found at $sourceDatapacks (skipping)" -ForegroundColor DarkGray
}

# Generate expected file list from DB and verify against actual
$expectedScript = Join-Path $repoRoot 'scripts/Get-ExpectedReleaseFiles.ps1'
if (-not (Test-Path $expectedScript)) { throw "Get-ExpectedReleaseFiles.ps1 not found at $expectedScript" }

$expectedFile = Join-Path $releaseDir 'expected-release-files.txt'
& $expectedScript -Version $Version -CsvPath (Join-Path $repoRoot $CsvPath) -OutputPath $expectedFile
# Don't trust $LASTEXITCODE for PowerShell scripts; validate output file instead
if (-not (Test-Path $expectedFile)) { throw "Get-ExpectedReleaseFiles.ps1 did not produce expected file at $expectedFile" }

# Build actual file listing (relative to release root) for required+optional mods, shaderpacks, and datapacks
$actualList = @()
if (Test-Path $releaseMods) {
    # Include JARs and ZIPs to surface any misclassified artifacts
    $actualList += (Get-ChildItem -Path $releaseMods -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.jar', '.zip') } | ForEach-Object { "mods/" + $_.Name })
}
$optionalModsPath = Join-Path $releaseMods 'optional'
if (Test-Path $optionalModsPath) {
    $actualList += (Get-ChildItem -Path $optionalModsPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.jar', '.zip') } | ForEach-Object { "mods/optional/" + $_.Name })
}
# Shaderpacks (zip/jar)
if (Test-Path $releaseShaderpacks) {
    $actualList += (Get-ChildItem -Path $releaseShaderpacks -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip','.jar') } | ForEach-Object { "shaderpacks/" + $_.Name })
}
# Datapacks (zip only) — jar datapacks are placed under mods
if (Test-Path $releaseDatapacks) {
    $actualList += (Get-ChildItem -Path $releaseDatapacks -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip') } | ForEach-Object { "datapacks/" + $_.Name })
}
$actualFile = Join-Path $releaseDir 'actual-release-files.txt'
$actualList | Sort-Object | Out-File -FilePath $actualFile -Encoding UTF8

# Filter expected to required+optional mods, shaderpacks, and datapacks (exclude mods/block)
$expectedCompare = Get-Content -Path $expectedFile | Where-Object { (($_ -like 'mods/*') -or ($_ -like 'shaderpacks/*') -or ($_ -like 'datapacks/*')) -and ($_ -notlike 'mods/block/*') }
$actualCompare = Get-Content -Path $actualFile

# Compute set differences (exact path comparison)
$expectedSet = New-Object System.Collections.Generic.HashSet[string]
$null = $expectedCompare | ForEach-Object { $expectedSet.Add($_) | Out-Null }
$actualSet = New-Object System.Collections.Generic.HashSet[string]
$null = $actualCompare | ForEach-Object { $actualSet.Add($_) | Out-Null }

$missing = @()
foreach ($e in $expectedSet) { if (-not $actualSet.Contains($e)) { $missing += $e } }
$extra = @()
foreach ($a in $actualSet) { if (-not $expectedSet.Contains($a)) { $extra += $a } }

# If in relaxed-version mode, attempt to pair up missing/extra mods that differ only by version in file name
if ($VerificationMode -eq 'relaxed-version') {
    function Get-BaseModKey([string]$relPath) {
        # Only apply to mods (mods/ or mods/optional/). Keep folder prefix to avoid clashes.
        if ($relPath -notlike 'mods/*') { return $null }
        # Extract folder and file
        $folder = if ($relPath.StartsWith('mods/optional/')) { 'mods/optional/' } else { 'mods/' }
        $file = $relPath.Substring($folder.Length)
        # Remove extension
        $name = [System.IO.Path]::GetFileNameWithoutExtension($file)
        # Heuristic: base is substring before first numeric version token (digits) that appears after a hyphen/underscore
        # Examples:
        #  - fabric-api-0.134.0+1.21.8 => fabric-api
        #  - litematica-fabric-1.21.4-0.23.4 => litematica-fabric
        #  - sodium-fabric-mc1.21.4-0.6.0 => sodium-fabric-mc
        $base = $name
        $m = [System.Text.RegularExpressions.Regex]::Match($name, '^(.*?)(?:[-_]?)(?=\d)')
        if ($m.Success -and $m.Groups.Count -gt 1 -and $m.Groups[1].Value.Trim().Length -gt 0) {
            $base = $m.Groups[1].Value.TrimEnd('-','_')
        }
        return $folder + $base.ToLower()
    }

    # Build lookup of bases present in expected and actual
    $expectedByBase = @{}
    foreach ($e in $missing) {
        $k = Get-BaseModKey $e
        if ($null -ne $k) {
            if (-not $expectedByBase.ContainsKey($k)) { $expectedByBase[$k] = @() }
            $expectedByBase[$k] += $e
        }
    }
    $actualByBase = @{}
    foreach ($a in $extra) {
        $k = Get-BaseModKey $a
        if ($null -ne $k) {
            if (-not $actualByBase.ContainsKey($k)) { $actualByBase[$k] = @() }
            $actualByBase[$k] += $a
        }
    }

    $pairedMissing = New-Object System.Collections.Generic.HashSet[string]
    $pairedExtra = New-Object System.Collections.Generic.HashSet[string]

    foreach ($k in $expectedByBase.Keys) {
        if ($actualByBase.ContainsKey($k)) {
            # We have an expected and an actual with same base in same folder; treat as version drift
            foreach ($eItem in $expectedByBase[$k]) { $pairedMissing.Add($eItem) | Out-Null }
            foreach ($aItem in $actualByBase[$k]) { $pairedExtra.Add($aItem) | Out-Null }
        }
    }

    if ($pairedMissing.Count -gt 0 -or $pairedExtra.Count -gt 0) {
        # Filter out paired items from missing/extra
        $missing = $missing | Where-Object { -not $pairedMissing.Contains($_) }
        $extra = $extra | Where-Object { -not $pairedExtra.Contains($_) }

        Write-Host "  ⚠️  Ignoring version-only differences for mods (relaxed-version):" -ForegroundColor DarkYellow
        foreach ($k in $expectedByBase.Keys) {
            if ($actualByBase.ContainsKey($k)) {
                $expList = ($expectedByBase[$k] | Sort-Object) -join ', '
                $actList = ($actualByBase[$k] | Sort-Object) -join ', '
                Write-Host "     base '$k' -> expected: [$expList] vs actual: [$actList]" -ForegroundColor DarkYellow
            }
        }
    }
}

if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
    Write-Host "Verification differences detected:" -ForegroundColor Yellow
    $missingPath = Join-Path $releaseDir 'verification-missing.txt'
    $extraPath = Join-Path $releaseDir 'verification-extra.txt'
    if ($missing.Count -gt 0) {
        Write-Host "  Missing (expected but not found):" -ForegroundColor Red
        $missing | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        $missing | Out-File -FilePath $missingPath -Encoding UTF8
    } else { '' | Out-File -FilePath $missingPath -Encoding UTF8 }
    if ($extra.Count -gt 0) {
        Write-Host "  Unexpected (present but not expected):" -ForegroundColor DarkYellow
        $extra | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkYellow }
        $extra | Out-File -FilePath $extraPath -Encoding UTF8
    } else { '' | Out-File -FilePath $extraPath -Encoding UTF8 }

    if ($VerificationMode -eq 'warn') {
        Write-Host "⚠️  Continuing despite differences (verification mode: warn)" -ForegroundColor DarkYellow
    } else {
        throw "Release file verification failed (mode: $VerificationMode)"
    }
} else {
    Write-Host "✓ Release files verified against DB expectations" -ForegroundColor Green
}

# Clean up build artifacts before packaging (these should not be in the release)
Write-Host "🧹 Cleaning up build artifacts..." -ForegroundColor Cyan
$buildArtifacts = @(
    'expected-release-files.txt',
    'actual-release-files.txt',
    'verification-missing.txt',
    'verification-extra.txt'
)
foreach ($artifact in $buildArtifacts) {
    $artifactPath = Join-Path $releaseDir $artifact
    if (Test-Path $artifactPath) {
        Remove-Item -Path $artifactPath -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed: $artifact" -ForegroundColor Gray
    }
}

# Run hash tool to generate README/hash and modpack.zip
$hashScript = Join-Path $repoRoot 'tools/minecraft-mod-hash/hash.ps1'
if (-not (Test-Path $hashScript)) { throw "hash.ps1 not found at $hashScript" }

& $hashScript -ModsPath $releaseMods -OutputPath $releaseDir -CreateZip -UpdateConfig
# Only enforce exit code if it's set and non-zero (PowerShell scripts may not set $LASTEXITCODE)
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "hash.ps1 failed with exit code $LASTEXITCODE" }

# Summarize results
$zip = Get-ChildItem -Path $releaseDir -Filter '*.zip' -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($zip) {
    Write-Host "Created: $($zip.FullName)" -ForegroundColor Green
    # List a few files included
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $tmp = Join-Path $env:TEMP ("mm-zip-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip.FullName, $tmp)
        $entries = Get-ChildItem -Path $tmp -Filter '*.jar' -File | Select-Object -First 10
        Write-Host "Sample JARs in zip:" -ForegroundColor Gray
        $entries | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    } catch {}
} else {
    throw "Expected modpack.zip was not created in $releaseDir"
}

Write-Host "Done. Output: $releaseDir" -ForegroundColor Cyan
