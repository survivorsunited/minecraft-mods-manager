# Generate expected release file list from the CSV database (module function)

function Get-ExpectedReleaseFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [string]$CsvPath = "modlist.csv",

        # Output file. Optional; when provided, writes the list there and also returns it
        [string]$OutputPath,

        # Include 'block' group entries in the output (they live under mods/block)
        [switch]$IncludeBlocked
    )

    $ErrorActionPreference = 'Stop'

    # Resolve paths
    if (-not ([System.IO.Path]::IsPathRooted($CsvPath))) {
        $CsvPath = Join-Path $PSScriptRoot (Join-Path '..\..' $CsvPath) | Resolve-Path | Select-Object -ExpandProperty Path
    }

    if (-not (Test-Path $CsvPath)) { throw "CSV not found: $CsvPath" }

    # Load CSV (database)
    $rows = Import-Csv -Path $CsvPath

    # Normalize helper
    function Normalize($s) { if ($null -eq $s) { return $null } ($s.ToString()).Trim() }

    # Derive an artifact filename when Jar is empty by decoding a known URL
    function Get-ArtifactFilename {
        param(
            [Parameter(Mandatory=$true)][psobject]$row
        )
        $jar = Normalize $row.Jar
        if (-not [string]::IsNullOrWhiteSpace($jar)) { return $jar }

        $cvu = Normalize $row.CurrentVersionUrl
        $nvu = Normalize $row.NextVersionUrl
        $lvu = Normalize $row.LatestVersionUrl
        $ud  = Normalize $row.UrlDirect
        $url = $cvu
        if ([string]::IsNullOrWhiteSpace($url)) { $url = $nvu }
        if ([string]::IsNullOrWhiteSpace($url)) { $url = $lvu }
        if ([string]::IsNullOrWhiteSpace($url)) { $url = $ud }
        if ([string]::IsNullOrWhiteSpace($url)) { return $null }

        try {
            $decoded = [System.Web.HttpUtility]::UrlDecode($url)
            $name = [System.IO.Path]::GetFileName($decoded)
            if ([string]::IsNullOrWhiteSpace($name)) { return $null }
            return $name
        } catch {
            return $null
        }
    }

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

    # Filter rows
    $mods = $rows | Where-Object {
        (Normalize $_.Type) -eq 'mod' -and
        $desiredGroups -contains ((Normalize $_.Group) ?? 'required') -and
        (& $versionFilter $_)
    }
    $shaderpacks = $rows | Where-Object { (Normalize $_.Type) -eq 'shaderpack' -and (& $versionFilter $_) }
    $datapacks = $rows | Where-Object { (Normalize $_.Type) -eq 'datapack' -and (& $versionFilter $_) }

    $seen = New-Object System.Collections.Generic.HashSet[string]
    $expected = @()

    foreach ($m in $mods) {
        $jar = Get-ArtifactFilename -row $m
        if ([string]::IsNullOrWhiteSpace($jar)) { continue }
        # Guard: a mod with a ZIP artifact is misclassified; exclude from expected list
        if ([System.IO.Path]::GetExtension($jar).ToLower() -eq '.zip') { continue }
        $grp = (Normalize $m.Group)
        if ([string]::IsNullOrWhiteSpace($grp)) { $grp = 'required' }
        # Determine if this is server-only (don't expect it in root mods folder)
        $clientSide = (Normalize $m.ClientSide)
        $serverSide = (Normalize $m.ServerSide)
        $isServerOnly = $false
        if ($clientSide -and $clientSide.ToLower() -eq 'unsupported') { $isServerOnly = $true }
        if ($grp -and $grp.ToLower() -eq 'admin') { $isServerOnly = $true }
        if (-not $isServerOnly -and $serverSide -and $serverSide.ToLower() -eq 'required' -and ($clientSide -ne 'required')) { $isServerOnly = $true }

        if ($isServerOnly) {
            $rel = "mods/server/$jar"
        } else {
            switch ($grp.ToLower()) {
                'optional' { $rel = "mods/optional/$jar" }
                'block'    { $rel = "mods/block/$jar" }
                default    { $rel = "mods/$jar" }
            }
        }
        if ($seen.Add($rel)) { $expected += $rel }
    }

    foreach ($s in $shaderpacks) {
        $zipName = Get-ArtifactFilename -row $s
        if ([string]::IsNullOrWhiteSpace($zipName)) { continue }
        $rel = "shaderpacks/$zipName"
        if ($seen.Add($rel)) { $expected += $rel }
    }

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

    $expected = $expected | Sort-Object

    if ($OutputPath) {
        $outDir = Split-Path -Parent $OutputPath
        if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
        $expected | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "Wrote expected file list -> $OutputPath" -ForegroundColor Green
        Write-Host "Count: $($expected.Count)" -ForegroundColor Gray
    }

    return $expected
}
