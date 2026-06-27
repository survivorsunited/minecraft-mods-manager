# Repairs stale Modrinth CurrentVersionUrl/Jar values in the real modlist.csv.
# If no exact artifact exists for CurrentGameVersion, the newest stable artifact
# below the target version is selected instead of leaving an old stale URL.

function Convert-ModrinthStableVersion {
    param([string]$Version)

    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    $v = $Version.Trim()
    if ($v -notmatch '^(\d+)\.(\d+)(?:\.(\d+))?$') { return $null }
    $patch = if ($matches[3]) { $matches[3] } else { '0' }
    try { return [version]"$($matches[1]).$($matches[2]).$patch" } catch { return $null }
}

function Get-ModrinthUrlFileName {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return "" }
    try {
        $decoded = [System.Web.HttpUtility]::UrlDecode($Url)
        return [System.IO.Path]::GetFileName(($decoded -split '\?')[0])
    } catch { return "" }
}

function Get-BestCompatibleModrinthVersion {
    param(
        [pscustomobject]$Row,
        [string]$TargetGameVersion
    )

    if ($Row.Host -ne 'modrinth') { return $null }
    if ($Row.Type -ne 'mod') { return $null }
    if ([string]::IsNullOrWhiteSpace($Row.ID)) { return $null }
    if ([string]::IsNullOrWhiteSpace($TargetGameVersion)) { return $null }

    $targetParsed = Convert-ModrinthStableVersion -Version $TargetGameVersion
    if (-not $targetParsed) { return $null }

    $loader = if (-not [string]::IsNullOrWhiteSpace($Row.Loader)) { $Row.Loader.Trim() } else { 'fabric' }

    try {
        $allVersions = Invoke-RestMethodWithRetry -Uri "https://api.modrinth.com/v2/project/$($Row.ID)/version" -Method Get -TimeoutSec 30 -ErrorAction SilentlyContinue
        if (-not $allVersions) { return $null }

        $candidates = @()
        foreach ($version in $allVersions) {
            if (-not ($version.loaders -contains $loader)) { continue }
            if (-not $version.files -or $version.files.Count -eq 0) { continue }

            foreach ($gameVersion in $version.game_versions) {
                $parsedGameVersion = Convert-ModrinthStableVersion -Version $gameVersion
                if (-not $parsedGameVersion) { continue }
                if ($parsedGameVersion -le $targetParsed) {
                    $file = ($version.files | Where-Object { $_.primary -eq $true } | Select-Object -First 1)
                    if (-not $file) { $file = $version.files[0] }
                    $candidates += [pscustomobject]@{
                        VersionNumber = $version.version_number
                        GameVersion = $gameVersion
                        ParsedGameVersion = $parsedGameVersion
                        Url = $file.url
                        FileName = $file.filename
                        DatePublished = $version.date_published
                    }
                }
            }
        }

        if ($candidates.Count -eq 0) { return $null }
        return $candidates | Sort-Object ParsedGameVersion, DatePublished -Descending | Select-Object -First 1
    } catch {
        return $null
    }
}

function Repair-StaleModrinthCurrentUrls {
    param([string]$CsvPath = 'modlist.csv')

    if (-not (Test-Path $CsvPath)) { return 0 }

    $rows = Import-Csv -Path $CsvPath
    $repairCount = 0

    foreach ($row in $rows) {
        if ($row.Host -ne 'modrinth') { continue }
        if ($row.Type -ne 'mod') { continue }
        if ([string]::IsNullOrWhiteSpace($row.CurrentGameVersion)) { continue }

        $currentUrl = [string]$row.CurrentVersionUrl
        $currentFileName = Get-ModrinthUrlFileName -Url $currentUrl

        $needsRepair = $false
        if ([string]::IsNullOrWhiteSpace($currentUrl)) {
            $needsRepair = $true
        } elseif (-not [string]::IsNullOrWhiteSpace($currentFileName) -and $currentFileName -notmatch [regex]::Escape($row.CurrentGameVersion)) {
            $needsRepair = $true
        }

        if (-not $needsRepair) { continue }

        $best = Get-BestCompatibleModrinthVersion -Row $row -TargetGameVersion $row.CurrentGameVersion
        if (-not $best) { continue }
        if ([string]::IsNullOrWhiteSpace($best.Url)) { continue }
        if ($best.Url -eq $row.CurrentVersionUrl -and $best.FileName -eq $row.Jar) { continue }

        $oldFile = if ($currentFileName) { $currentFileName } else { '<none>' }
        $row.CurrentVersion = $best.VersionNumber
        $row.CurrentVersionUrl = $best.Url
        $row.Jar = $best.FileName

        try { $row.RecordHash = Calculate-RecordHash -Record $row } catch { }

        Write-Host "Repaired Modrinth current URL for $($row.Name): $oldFile -> $($best.FileName) [$($best.GameVersion) for target $($row.CurrentGameVersion)]" -ForegroundColor Green
        $repairCount++
    }

    if ($repairCount -gt 0) {
        $backupDir = 'backups'
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = Join-Path $backupDir "$timestamp-pre-modrinth-url-repair-$(Split-Path $CsvPath -Leaf)"
        Copy-Item -Path $CsvPath -Destination $backupPath -Force
        $rows | Export-Csv -Path $CsvPath -NoTypeInformation
        Write-Host "Repaired $repairCount stale Modrinth current URL(s). Backup: $backupPath" -ForegroundColor Green
    }

    return $repairCount
}
