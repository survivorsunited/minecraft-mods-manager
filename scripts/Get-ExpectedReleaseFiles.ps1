# Generate expected release file list from the CSV database

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$CsvPath = "modlist.csv",

    # Output file. Defaults to releases/<Version>/expected-release-files.txt
    [string]$OutputPath,

    # Include 'block' group entries in the output (they live under mods/block)
    [switch]$IncludeBlocked
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not ([System.IO.Path]::IsPathRooted($CsvPath))) {
    $CsvPath = Join-Path $repoRoot $CsvPath
}

$releaseDir = Join-Path $repoRoot (Join-Path 'releases' $Version)
if (-not $OutputPath) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    $OutputPath = Join-Path $releaseDir 'expected-release-files.txt'
} elseif (-not ([System.IO.Path]::IsPathRooted($OutputPath))) {
    $OutputPath = Join-Path $repoRoot $OutputPath
}

if (-not (Test-Path $CsvPath)) { throw "CSV not found: $CsvPath" }

# Load CSV (database)
$rows = Import-Csv -Path $CsvPath

# Normalize helper
function Normalize($s) { if ($null -eq $s) { return $null } ($s.ToString()).Trim() }

# Decide inclusion by version:
# - Prefer rows where CurrentGameVersion == $Version
# - Also include rows whose AvailableGameVersions contains the $Version (covers libs built for nearby patch)
$versionFilter = {
    param($r)
    $cur = Normalize $r.CurrentGameVersion
    $avail = Normalize $r.AvailableGameVersions
    if ([string]::IsNullOrWhiteSpace($cur) -and [string]::IsNullOrWhiteSpace($avail)) { return $false }
    if ($cur -eq $Version) { return $true }
    if ($avail -and $avail -match [Regex]::Escape($Version)) { return $true }
    return $false
}

# Groups of interest (for mods)
$desiredGroups = @('required','optional')
if ($IncludeBlocked) { $desiredGroups += 'block' }

# Filter mod rows (JARs under mods/ structure)
$mods = $rows | Where-Object {
    (Normalize $_.Type) -eq 'mod' -and
    $desiredGroups -contains ((Normalize $_.Group) ?? 'required') -and
    (& $versionFilter $_)
}

# Filter shaderpack rows (ZIPs under shaderpacks/)
$shaderpacks = $rows | Where-Object {
    (Normalize $_.Type) -eq 'shaderpack' -and
    (& $versionFilter $_)
}

# Filter datapack rows (ZIPs/JARs under datapacks/)
$datapacks = $rows | Where-Object {
    (Normalize $_.Type) -eq 'datapack' -and
    (& $versionFilter $_)
}

# Build expected relative paths using the Jar column and Group
$seen = New-Object System.Collections.Generic.HashSet[string]
$expected = @()

# Mods -> mods/, mods/optional/, mods/block/
foreach ($m in $mods) {
    $jar = Normalize $m.Jar
    if ([string]::IsNullOrWhiteSpace($jar)) { continue }
    $grp = (Normalize $m.Group)
    if ([string]::IsNullOrWhiteSpace($grp)) { $grp = 'required' }
    switch ($grp.ToLower()) {
        'optional' { $rel = "mods/optional/$jar" }
        'block'    { $rel = "mods/block/$jar" }
        default    { $rel = "mods/$jar" }
    }
    if ($seen.Add($rel)) { $expected += $rel }
}

# Shaderpacks -> shaderpacks/
foreach ($s in $shaderpacks) {
    $zipName = Normalize $s.Jar
    if ([string]::IsNullOrWhiteSpace($zipName)) { continue }
    $rel = "shaderpacks/$zipName"
    if ($seen.Add($rel)) { $expected += $rel }
}

# Datapacks:
# - If JAR, treat as mods (respect Group like mods)
# - If ZIP, treat as datapacks/
foreach ($d in $datapacks) {
    $dpName = Normalize $d.Jar
    if ([string]::IsNullOrWhiteSpace($dpName)) { continue }
    $ext = [System.IO.Path]::GetExtension($dpName).ToLower()
    if ($ext -eq '.jar') {
        $grp = (Normalize $d.Group)
        if ([string]::IsNullOrWhiteSpace($grp)) { $grp = 'required' }
        switch ($grp.ToLower()) {
            'optional' { $rel = "mods/optional/$dpName" }
            'block'    { $rel = "mods/block/$dpName" }
            default    { $rel = "mods/$dpName" }
        }
    } else {
        $rel = "datapacks/$dpName"
    }
    if ($seen.Add($rel)) { $expected += $rel }
}

# Sort stable
$expected = $expected | Sort-Object

# Write file
$expected | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "Wrote expected file list -> $OutputPath" -ForegroundColor Green
Write-Host "Count: $($expected.Count)" -ForegroundColor Gray

# Also emit on pipeline for reuse
$expected
