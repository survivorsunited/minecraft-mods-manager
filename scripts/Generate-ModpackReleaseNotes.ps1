param(
    [string]$TagName = "local",
    [string]$Version = "local",
    [string]$CsvPath = "modlist.csv",
    [string]$ReleasePath = "releases",
    [string[]]$Versions = @(),
    [string]$ChecksumsPath = "release-hashes.txt",
    [string]$OutputPath = "release-notes.md"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$importModules = Join-Path $repoRoot 'src/Import-Modules.ps1'
if (Test-Path $importModules) { . $importModules | Out-Null }

function Normalize-Text($value) {
    if ($null -eq $value) { return '' }
    return $value.ToString().Trim()
}

function Get-BaseModKey([string]$relativePath) {
    if ([string]::IsNullOrWhiteSpace($relativePath)) { return $null }
    $file = [System.IO.Path]::GetFileName($relativePath)
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file)
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }
    $match = [System.Text.RegularExpressions.Regex]::Match($name, '^(.*?)(?:[-_]?)(?=\d)')
    $base = if ($match.Success -and $match.Groups.Count -gt 1 -and $match.Groups[1].Value.Trim().Length -gt 0) { $match.Groups[1].Value.TrimEnd('-','_') } else { $name }
    return $base.ToLowerInvariant()
}

function Get-ArtifactFilenameFromRow($row, [string]$targetVersion) {
    $jar = Normalize-Text $row.Jar
    if (-not [string]::IsNullOrWhiteSpace($jar)) { return $jar }

    $urlCandidates = @()
    if ((Normalize-Text $row.CurrentGameVersion) -eq $targetVersion) { $urlCandidates += (Normalize-Text $row.CurrentVersionUrl) }
    if ((Normalize-Text $row.NextGameVersion) -eq $targetVersion) { $urlCandidates += (Normalize-Text $row.NextVersionUrl) }
    if ((Normalize-Text $row.LatestGameVersion) -eq $targetVersion) { $urlCandidates += (Normalize-Text $row.LatestVersionUrl) }
    $urlCandidates += @((Normalize-Text $row.CurrentVersionUrl), (Normalize-Text $row.NextVersionUrl), (Normalize-Text $row.LatestVersionUrl), (Normalize-Text $row.UrlDirect))

    foreach ($url in $urlCandidates) {
        if ([string]::IsNullOrWhiteSpace($url)) { continue }
        try {
            $decoded = [System.Web.HttpUtility]::UrlDecode($url)
            $name = [System.IO.Path]::GetFileName($decoded)
            if (-not [string]::IsNullOrWhiteSpace($name)) { return $name }
        } catch { }
    }
    return $null
}

function Test-RowTargetsVersion($row, [string]$targetVersion) {
    if ((Normalize-Text $row.CurrentGameVersion) -eq $targetVersion) { return $true }
    if ((Normalize-Text $row.NextGameVersion) -eq $targetVersion) { return $true }
    if ((Normalize-Text $row.LatestGameVersion) -eq $targetVersion) { return $true }
    $available = Normalize-Text $row.AvailableGameVersions
    if ($available -and $available -match [Regex]::Escape($targetVersion)) { return $true }
    return $false
}

function Get-ExpectedRowPath($row, [string]$targetVersion) {
    $artifact = Get-ArtifactFilenameFromRow $row $targetVersion
    if ([string]::IsNullOrWhiteSpace($artifact)) { return $null }

    $type = (Normalize-Text $row.Type).ToLowerInvariant()
    $group = (Normalize-Text $row.Group).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($group)) { $group = 'required' }
    $clientSide = (Normalize-Text $row.ClientSide).ToLowerInvariant()

    if ($type -eq 'shaderpack') { return "shaderpacks/$artifact" }
    if ($type -eq 'datapack' -and [System.IO.Path]::GetExtension($artifact).ToLowerInvariant() -eq '.zip') { return "datapacks/$artifact" }
    if ($type -in @('server','launcher','installer','jdk')) { return $null }
    if ($clientSide -eq 'unsupported') { return "mods/$artifact" }

    switch ($group) {
        'admin' { return "mods/optional/$artifact" }
        'optional' { return "mods/optional/$artifact" }
        'block' { return "mods/block/$artifact" }
        default { return "mods/$artifact" }
    }
}

$csvFullPath = if ([System.IO.Path]::IsPathRooted($CsvPath)) { $CsvPath } else { Join-Path $repoRoot $CsvPath }
$releaseFullPath = if ([System.IO.Path]::IsPathRooted($ReleasePath)) { $ReleasePath } else { Join-Path $repoRoot $ReleasePath }
$outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $repoRoot $OutputPath }
$checksumsFullPath = if ([System.IO.Path]::IsPathRooted($ChecksumsPath)) { $ChecksumsPath } else { Join-Path $repoRoot $ChecksumsPath }

$rows = if (Test-Path $csvFullPath) { Import-Csv -Path $csvFullPath } else { @() }
if (-not $Versions -or $Versions.Count -eq 0) {
    if (Test-Path $releaseFullPath) {
        $Versions = Get-ChildItem -Path $releaseFullPath -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    }
}
$Versions = @($Versions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')
$notes = New-Object System.Collections.Generic.List[string]
$notes.Add("# Minecraft Modpack Release - $TagName")
$notes.Add('')
$notes.Add('## 📦 Included Packages')
$includedFiles = Get-ChildItem -Path $repoRoot -Filter 'modpack-*.zip' -File -ErrorAction SilentlyContinue | Sort-Object Name
if ($includedFiles.Count -eq 0) { $notes.Add('- (none)') } else { foreach ($f in $includedFiles) { $notes.Add("- **$($f.Name)**") } }
$notes.Add('')
$notes.Add('## 📋 Release Information')
$notes.Add("- **Tag**: ``$TagName``")
$notes.Add("- **Version**: $Version")
$notes.Add("- **Created**: $timestamp")
$notes.Add('- **Type**: Stable Release')
$notes.Add('- **Validation**: Server startup tested for each packaged version')
$notes.Add('')
$notes.Add('## ✅ Working and Not-Released Mods by Version')
$notes.Add('')

foreach ($targetVersion in $Versions) {
    $releaseDir = Join-Path $releaseFullPath $targetVersion
    $actualFiles = @()
    if (Test-Path $releaseDir) {
        $actualFiles = Get-ChildItem -Path $releaseDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension.ToLowerInvariant() -in @('.jar','.zip') -and $_.FullName -notmatch '[\\/]mods[\\/]block[\\/]'
        } | ForEach-Object {
            $relative = [System.IO.Path]::GetRelativePath($releaseDir, $_.FullName).Replace('\\','/')
            $relative
        }
    }
    $actualSet = New-Object System.Collections.Generic.HashSet[string]
    $actualBaseSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($actual in $actualFiles) {
        [void]$actualSet.Add($actual)
        $base = Get-BaseModKey $actual
        if ($base) { [void]$actualBaseSet.Add($base) }
    }

    $versionRows = @($rows | Where-Object { Test-RowTargetsVersion $_ $targetVersion -and (Normalize-Text $_.Type).ToLowerInvariant() -in @('mod','datapack','shaderpack') })
    $working = New-Object System.Collections.Generic.List[string]
    $notReleased = New-Object System.Collections.Generic.List[string]
    $matchedActual = New-Object System.Collections.Generic.HashSet[string]

    foreach ($row in $versionRows) {
        $name = Normalize-Text $row.Name
        if ([string]::IsNullOrWhiteSpace($name)) { $name = Normalize-Text $row.ID }
        $artifactPath = Get-ExpectedRowPath $row $targetVersion
        if ([string]::IsNullOrWhiteSpace($artifactPath)) { continue }
        $artifactName = [System.IO.Path]::GetFileName($artifactPath)
        $group = (Normalize-Text $row.Group).ToLowerInvariant()
        $rowVersion = Normalize-Text $row.CurrentVersion
        if ((Normalize-Text $row.NextGameVersion) -eq $targetVersion -and -not [string]::IsNullOrWhiteSpace($row.NextVersion)) { $rowVersion = Normalize-Text $row.NextVersion }
        if ((Normalize-Text $row.LatestGameVersion) -eq $targetVersion -and -not [string]::IsNullOrWhiteSpace($row.LatestVersion)) { $rowVersion = Normalize-Text $row.LatestVersion }
        $label = if ([string]::IsNullOrWhiteSpace($rowVersion)) { "**$name** — ``$artifactName``" } else { "**$name** ``$rowVersion`` — ``$artifactName``" }

        $base = Get-BaseModKey $artifactPath
        $exact = $actualSet.Contains($artifactPath)
        $relaxed = ($base -and $actualBaseSet.Contains($base))
        if ($group -eq 'block' -or $artifactPath -like 'mods/block/*') {
            $notReleased.Add("- $label — blocked/not released for this version")
        } elseif ($exact -or $relaxed) {
            $working.Add("- $label")
            if ($exact) { [void]$matchedActual.Add($artifactPath) }
        } else {
            $notReleased.Add("- $label — missing from packaged release")
        }
    }

    $additional = @($actualFiles | Where-Object {
        $_ -like 'mods/*' -or $_ -like 'shaderpacks/*' -or $_ -like 'datapacks/*'
    } | Where-Object {
        $actualBase = Get-BaseModKey $_
        $found = $false
        foreach ($row in $versionRows) {
            $expected = Get-ExpectedRowPath $row $targetVersion
            if (-not $expected) { continue }
            if ($_ -eq $expected -or ($actualBase -and (Get-BaseModKey $expected) -eq $actualBase)) { $found = $true; break }
        }
        -not $found
    } | Sort-Object)

    $notes.Add("### Minecraft $targetVersion")
    $notes.Add('')
    $notes.Add("- Working/released entries: **$($working.Count)**")
    $notes.Add("- Not released / needs attention: **$($notReleased.Count)**")
    if ($additional.Count -gt 0) { $notes.Add("- Additional packaged files not matched to modlist rows: **$($additional.Count)**") }
    $notes.Add('')
    $notes.Add("#### Working / released ($($working.Count))")
    if ($working.Count -eq 0) { $notes.Add('- (none)') } else { foreach ($line in $working) { $notes.Add($line) } }
    $notes.Add('')
    $notes.Add("#### Not released / needs attention ($($notReleased.Count))")
    if ($notReleased.Count -eq 0) { $notes.Add('- (none)') } else { foreach ($line in $notReleased) { $notes.Add($line) } }
    if ($additional.Count -gt 0) {
        $notes.Add('')
        $notes.Add("#### Additional packaged files ($($additional.Count))")
        foreach ($line in $additional) { $notes.Add("- ``$line``") }
    }
    $notes.Add('')
}

$notes.Add('## 🔑 Checksums')
if (Test-Path $checksumsFullPath) {
    $notes.Add('```')
    $notes.Add((Get-Content $checksumsFullPath -Raw).TrimEnd())
    $notes.Add('```')
} else {
    $notes.Add('(checksums unavailable)')
}
$notes.Add('')
$notes.Add('## 📥 Download Instructions')
$notes.Add('')
$notes.Add('1. Download ``modpack-[version].zip`` for your Minecraft version')
$notes.Add('2. Extract the ZIP file')
$notes.Add('3. Install mods from the ``mods/`` directory to ``.minecraft/mods/``')
$notes.Add('4. Optional mods are in ``mods/optional/``')
$notes.Add('5. Mods listed under “Not released / needs attention” are intentionally not part of that version package until fixed')
$notes.Add('6. Check ``hash.txt`` for file verification')
$notes.Add('7. See ``README.md`` for complete installation guide')
$notes.Add('')
$notes.Add('## 🔗 InertiaAntiCheat Integration')
$notes.Add('')
$notes.Add('Use included ``hash.txt`` to configure InertiaAntiCheat server validation.')
$notes.Add('See ``README.md`` for details.')

$outDir = Split-Path -Parent $outputFullPath
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$notes | Out-File -FilePath $outputFullPath -Encoding UTF8
Write-Host "Generated release notes: $outputFullPath" -ForegroundColor Green
Get-Content $outputFullPath
