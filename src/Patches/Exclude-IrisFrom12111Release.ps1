$script:IrisBlockedGameVersions = @('1.21.11')
$script:IrisBlockedIds = @('iris')

function Test-IrisReleaseBlockedRow {
    param($Row, [string]$TargetGameVersion)
    if (-not ($script:IrisBlockedGameVersions -contains $TargetGameVersion)) { return $false }
    if (-not $Row.ID) { return $false }
    return $script:IrisBlockedIds -contains $Row.ID.Trim().ToLowerInvariant()
}

function New-IrisSafeCsvForRelease {
    param([string]$CsvPath, [string]$TargetGameVersion)
    if ([string]::IsNullOrWhiteSpace($CsvPath) -or -not (Test-Path $CsvPath)) { return $null }
    if (-not ($script:IrisBlockedGameVersions -contains $TargetGameVersion)) { return $null }

    $rows = @(Import-Csv -Path $CsvPath)
    $kept = @($rows | Where-Object { -not (Test-IrisReleaseBlockedRow -Row $_ -TargetGameVersion $TargetGameVersion) })
    if ($kept.Count -eq $rows.Count) { return $null }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'minecraft-mods-manager'
    if (-not (Test-Path $tempRoot)) { New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null }
    $tempCsv = Join-Path $tempRoot ("modlist-without-iris-{0}.csv" -f ([System.Guid]::NewGuid().ToString('N')))
    $kept | Export-Csv -Path $tempCsv -NoTypeInformation
    return $tempCsv
}

if (-not $script:OriginalDownloadModsBeforeIrisExclusion -and (Get-Command Download-Mods -ErrorAction SilentlyContinue)) {
    $script:OriginalDownloadModsBeforeIrisExclusion = ${function:Download-Mods}
}

function Download-Mods {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$DownloadFolder = 'download',
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
        $tempCsvPath = New-IrisSafeCsvForRelease -CsvPath $CsvPath -TargetGameVersion $TargetGameVersion
        if ($tempCsvPath) {
            $effectiveCsvPath = $tempCsvPath
            Write-Host "Excluding Iris from $TargetGameVersion release payload" -ForegroundColor Yellow
        }
        $params = @{ CsvPath = $effectiveCsvPath; DownloadFolder = $DownloadFolder }
        if ($UseLatestVersion) { $params.UseLatestVersion = $true }
        if ($UseNextVersion) { $params.UseNextVersion = $true }
        if ($ForceDownload) { $params.ForceDownload = $true }
        if ($TargetGameVersion) { $params.TargetGameVersion = $TargetGameVersion }
        if ($ApiResponseFolder) { $params.ApiResponseFolder = $ApiResponseFolder }
        if ($SkipServerFiles) { $params.SkipServerFiles = $true }
        return & $script:OriginalDownloadModsBeforeIrisExclusion @params
    }
    finally {
        if ($tempCsvPath -and (Test-Path $tempCsvPath)) { Remove-Item -Path $tempCsvPath -Force -ErrorAction SilentlyContinue }
    }
}

if (-not $script:OriginalGetExpectedReleaseFilesBeforeIrisExclusion -and (Get-Command Get-ExpectedReleaseFiles -ErrorAction SilentlyContinue)) {
    $script:OriginalGetExpectedReleaseFilesBeforeIrisExclusion = ${function:Get-ExpectedReleaseFiles}
}

function Get-ExpectedReleaseFiles {
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [string]$CsvPath = 'modlist.csv',
        [string]$OutputPath,
        [switch]$IncludeBlocked
    )
    $effectiveCsvPath = $CsvPath
    $tempCsvPath = $null
    try {
        $tempCsvPath = New-IrisSafeCsvForRelease -CsvPath $CsvPath -TargetGameVersion $Version
        if ($tempCsvPath) { $effectiveCsvPath = $tempCsvPath }
        $params = @{ Version = $Version; CsvPath = $effectiveCsvPath }
        if ($OutputPath) { $params.OutputPath = $OutputPath }
        if ($IncludeBlocked) { $params.IncludeBlocked = $true }
        return & $script:OriginalGetExpectedReleaseFilesBeforeIrisExclusion @params
    }
    finally {
        if ($tempCsvPath -and (Test-Path $tempCsvPath)) { Remove-Item -Path $tempCsvPath -Force -ErrorAction SilentlyContinue }
    }
}
