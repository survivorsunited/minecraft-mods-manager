# Build a release package from already-downloaded mods without network or server validation

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [string]$CsvPath = "modlist.csv"
)

$ErrorActionPreference = 'Stop'

Write-Host "Packaging cached download into release: $Version" -ForegroundColor Cyan

$repoRoot = Split-Path -Parent $PSScriptRoot
$downloadPath = Join-Path $repoRoot (Join-Path 'download' $Version)
if (-not (Test-Path $downloadPath)) {
    throw "download/$Version not found at $downloadPath"
}

$sourceMods = Join-Path $downloadPath 'mods'
if (-not (Test-Path $sourceMods)) {
    throw "No mods folder found at $sourceMods"
}

# Shaderpacks source (optional)
$sourceShaderpacks = Join-Path $downloadPath 'shaderpacks'

# Create isolated, timestamped run directory to avoid overwriting previous runs
$baseReleaseDir = Join-Path $repoRoot (Join-Path 'releases' $Version)
$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$releaseDir = Join-Path $baseReleaseDir $runStamp
$releaseMods = Join-Path $releaseDir 'mods'
$releaseShaderpacks = Join-Path $releaseDir 'shaderpacks'
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

# Generate expected file list from DB and verify against actual
$expectedScript = Join-Path $repoRoot 'scripts/Get-ExpectedReleaseFiles.ps1'
if (-not (Test-Path $expectedScript)) { throw "Get-ExpectedReleaseFiles.ps1 not found at $expectedScript" }

$expectedFile = Join-Path $releaseDir 'expected-release-files.txt'
$expected = & $expectedScript -Version $Version -CsvPath (Join-Path $repoRoot $CsvPath) -OutputPath $expectedFile
# Don't trust $LASTEXITCODE for PowerShell scripts; validate output file instead
if (-not (Test-Path $expectedFile)) { throw "Get-ExpectedReleaseFiles.ps1 did not produce expected file at $expectedFile" }

# Build actual file listing (relative to release root) for required+optional mods and shaderpacks
$actualList = @()
if (Test-Path $releaseMods) {
    $actualList += (Get-ChildItem -Path $releaseMods -Filter '*.jar' -File -ErrorAction SilentlyContinue | ForEach-Object { "mods/" + $_.Name })
}
$optionalModsPath = Join-Path $releaseMods 'optional'
if (Test-Path $optionalModsPath) {
    $actualList += (Get-ChildItem -Path $optionalModsPath -Filter '*.jar' -File -ErrorAction SilentlyContinue | ForEach-Object { "mods/optional/" + $_.Name })
}
# Shaderpacks (zip/jar)
if (Test-Path $releaseShaderpacks) {
    $actualList += (Get-ChildItem -Path $releaseShaderpacks -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip','.jar') } | ForEach-Object { "shaderpacks/" + $_.Name })
}
$actualFile = Join-Path $releaseDir 'actual-release-files.txt'
$actualList | Sort-Object | Out-File -FilePath $actualFile -Encoding UTF8

# Filter expected to required+optional mods and shaderpacks only for comparison
$expectedCompare = Get-Content -Path $expectedFile | Where-Object { (($_ -like 'mods/*') -or ($_ -like 'shaderpacks/*')) -and ($_ -notlike 'mods/block/*') }
$actualCompare = Get-Content -Path $actualFile

# Compute set differences
$expectedSet = New-Object System.Collections.Generic.HashSet[string]
$null = $expectedCompare | ForEach-Object { $expectedSet.Add($_) | Out-Null }
$actualSet = New-Object System.Collections.Generic.HashSet[string]
$null = $actualCompare | ForEach-Object { $actualSet.Add($_) | Out-Null }

$missing = @()
foreach ($e in $expectedSet) { if (-not $actualSet.Contains($e)) { $missing += $e } }
$extra = @()
foreach ($a in $actualSet) { if (-not $expectedSet.Contains($a)) { $extra += $a } }

if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
    Write-Host "Verification differences detected:" -ForegroundColor Yellow
    if ($missing.Count -gt 0) {
        Write-Host "  Missing (expected but not found):" -ForegroundColor Red
        $missing | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    }
    if ($extra.Count -gt 0) {
        Write-Host "  Unexpected (present but not expected):" -ForegroundColor DarkYellow
        $extra | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkYellow }
    }
    throw "Release file verification failed"
} else {
    Write-Host "✓ Release files verified against DB expectations" -ForegroundColor Green
}

# Run hash tool to generate README/hash and modpack.zip
$hashScript = Join-Path $repoRoot 'tools/minecraft-mod-hash/hash.ps1'
if (-not (Test-Path $hashScript)) { throw "hash.ps1 not found at $hashScript" }

& $hashScript -ModsPath $releaseMods -OutputPath $releaseDir -CreateZip -UpdateConfig
if ($LASTEXITCODE -ne 0) { throw "hash.ps1 failed with exit code $LASTEXITCODE" }

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
