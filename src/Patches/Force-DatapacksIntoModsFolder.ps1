# =============================================================================
# Datapack Download Placement Patch
# =============================================================================
# SurvivorsUnited packages mod rows and datapack rows together in the mods folder.
# This wrapper keeps the database Type=datapack for metadata, but presents those
# rows as Type=mod only to the existing Download-Mods implementation so its
# folder routing writes them to download/<version>/mods.
# =============================================================================

if (-not $script:OriginalDownloadMods -and (Get-Command Download-Mods -ErrorAction SilentlyContinue)) {
    $script:OriginalDownloadMods = ${function:Download-Mods}
}

function New-DatapacksAsModsCsvForDownload {
    param([string]$CsvPath)

    if ([string]::IsNullOrWhiteSpace($CsvPath) -or -not (Test-Path $CsvPath)) {
        return $null
    }

    $rows = @(Import-Csv -Path $CsvPath)
    $hasDatapacks = $false

    foreach ($row in $rows) {
        if ($row.Type -and $row.Type.Trim().ToLowerInvariant() -eq 'datapack') {
            $hasDatapacks = $true
            $row.Type = 'mod'
        }
    }

    if (-not $hasDatapacks) { return $null }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'minecraft-mods-manager'
    if (-not (Test-Path $tempRoot)) { New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null }

    $tempCsv = Join-Path $tempRoot ("modlist-datapacks-as-mods-{0}.csv" -f ([System.Guid]::NewGuid().ToString('N')))
    $rows | Export-Csv -Path $tempCsv -NoTypeInformation

    return $tempCsv
}

function Remove-LegacyDatapackDownloadFolder {
    param(
        [string]$DownloadFolder,
        [string]$TargetGameVersion
    )

    if ([string]::IsNullOrWhiteSpace($DownloadFolder) -or [string]::IsNullOrWhiteSpace($TargetGameVersion)) { return }

    $legacyPath = Join-Path (Join-Path $DownloadFolder $TargetGameVersion) 'datapacks'
    if (Test-Path $legacyPath) {
        Remove-Item -Path $legacyPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "🧹 Removed legacy datapack download folder: $legacyPath" -ForegroundColor DarkYellow
    }
}

function Download-Mods {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$DownloadFolder = "download",
        [switch]$UseLatestVersion,
        [switch]$UseNextVersion,
        [switch]$ForceDownload,
        [string]$TargetGameVersion = $null,
        [string]$ApiResponseFolder = $null,
        [switch]$SkipServerFiles
    )

    $effectiveCsvPath = $CsvPath
    $tempCsvPath = $null

    try {
        $tempCsvPath = New-DatapacksAsModsCsvForDownload -CsvPath $CsvPath
        if ($tempCsvPath) {
            $effectiveCsvPath = $tempCsvPath
            Write-Host "📦 Treating datapack rows as mods for download placement" -ForegroundColor Cyan
        }

        $params = @{
            CsvPath = $effectiveCsvPath
            DownloadFolder = $DownloadFolder
        }

        if ($UseLatestVersion) { $params.UseLatestVersion = $true }
        if ($UseNextVersion) { $params.UseNextVersion = $true }
        if ($ForceDownload) { $params.ForceDownload = $true }
        if ($TargetGameVersion) { $params.TargetGameVersion = $TargetGameVersion }
        if ($ApiResponseFolder) { $params.ApiResponseFolder = $ApiResponseFolder }
        if ($SkipServerFiles) { $params.SkipServerFiles = $true }

        $result = & $script:OriginalDownloadMods @params

        if ($tempCsvPath -and $TargetGameVersion) {
            Remove-LegacyDatapackDownloadFolder -DownloadFolder $DownloadFolder -TargetGameVersion $TargetGameVersion
        }

        return $result
    }
    finally {
        if ($tempCsvPath -and (Test-Path $tempCsvPath)) {
            Remove-Item -Path $tempCsvPath -Force -ErrorAction SilentlyContinue
        }
    }
}
