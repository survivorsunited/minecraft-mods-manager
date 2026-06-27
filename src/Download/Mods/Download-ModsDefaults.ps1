# =============================================================================
# Download Mods Defaults Wrapper
# =============================================================================
# This wrapper keeps the public Download-Mods command safe and predictable:
# - Plain -Download uses release-config.json targets.current before DB fallback.
# - Relative paths and .cache are anchored to the project root.
# - GitHub release asset URLs are made safe for the legacy downloader's UrlDecode call.
# =============================================================================

if (-not $script:DownloadModsOriginalCommand) {
    $script:DownloadModsOriginalCommand = ${function:Download-Mods}
}

function Resolve-ModManagerProjectPath {
    param(
        [string]$Path,
        [string]$ProjectRoot,
        [string]$DefaultRelativePath = ""
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        if ([string]::IsNullOrWhiteSpace($DefaultRelativePath)) { return $Path }
        $Path = $DefaultRelativePath
    }

    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $ProjectRoot $Path)
}

function Protect-GitHubReleaseAssetUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $Url }
    if ($Url -notmatch 'github\.com/.+/releases/download/.+') { return $Url }
    if ($Url -notmatch '\+') { return $Url }

    # The legacy downloader calls HttpUtility.UrlDecode before Invoke-WebRequest.
    # A literal + is decoded to a space, so preserve it by storing %2B in the
    # temporary download CSV. UrlDecode('%2B') becomes '+', not a space.
    return ($Url -replace '\+', '%2B')
}

function New-DownloadSafeCsv {
    param(
        [string]$CsvPath,
        [string]$ApiResponseFolder
    )

    if (-not (Test-Path $CsvPath)) { return $CsvPath }
    if (-not (Test-Path $ApiResponseFolder)) { New-Item -ItemType Directory -Path $ApiResponseFolder -Force | Out-Null }

    try {
        $rows = Import-Csv -Path $CsvPath
        $urlFields = @('Url', 'CurrentVersionUrl', 'NextVersionUrl', 'LatestVersionUrl', 'UrlDirect')
        $changed = $false

        foreach ($row in $rows) {
            foreach ($field in $urlFields) {
                if (-not ($row.PSObject.Properties.Name -contains $field)) { continue }
                $oldValue = [string]$row.$field
                $newValue = Protect-GitHubReleaseAssetUrl -Url $oldValue
                if ($newValue -ne $oldValue) {
                    $row.$field = $newValue
                    $changed = $true
                }
            }
        }

        if (-not $changed) { return $CsvPath }

        $safeCsvPath = Join-Path $ApiResponseFolder "download-safe-modlist.csv"
        $rows | Export-Csv -Path $safeCsvPath -NoTypeInformation
        Write-Host "🔧 Created download-safe CSV for GitHub release asset URLs: $safeCsvPath" -ForegroundColor Gray
        return $safeCsvPath
    } catch {
        Write-Host "⚠️  Failed to create download-safe CSV: $($_.Exception.Message). Using original CSV." -ForegroundColor Yellow
        return $CsvPath
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

    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path

    $effectiveCsvPath = Resolve-ModManagerProjectPath -Path $CsvPath -ProjectRoot $projectRoot -DefaultRelativePath "modlist.csv"
    $effectiveDownloadFolder = Resolve-ModManagerProjectPath -Path $DownloadFolder -ProjectRoot $projectRoot -DefaultRelativePath "download"
    $effectiveApiResponseFolder = Resolve-ModManagerProjectPath -Path $ApiResponseFolder -ProjectRoot $projectRoot -DefaultRelativePath "apiresponse"

    $effectiveTargetGameVersion = $TargetGameVersion
    if ([string]::IsNullOrWhiteSpace($effectiveTargetGameVersion) -and -not $UseLatestVersion -and -not $UseNextVersion) {
        if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
            $targets = Get-ReleaseVersionTargets
            if ($targets -and -not [string]::IsNullOrWhiteSpace($targets.Current)) {
                $effectiveTargetGameVersion = $targets.Current
                Write-Host "🎯 Targeting current game version from release-config.json: $effectiveTargetGameVersion" -ForegroundColor Green
            }
        }

        if ([string]::IsNullOrWhiteSpace($effectiveTargetGameVersion)) {
            $effectiveTargetGameVersion = Get-CurrentVersion -CsvPath $effectiveCsvPath
            if ($effectiveTargetGameVersion) {
                Write-Host "🎯 Targeting current game version from database: $effectiveTargetGameVersion" -ForegroundColor Green
            }
        }
    }

    $cacheRoot = Join-Path $projectRoot ".cache"
    if (-not (Test-Path $cacheRoot)) { New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null }

    $downloadCsvPath = New-DownloadSafeCsv -CsvPath $effectiveCsvPath -ApiResponseFolder $effectiveApiResponseFolder

    $params = @{
        CsvPath = $downloadCsvPath
        DownloadFolder = $effectiveDownloadFolder
        ApiResponseFolder = $effectiveApiResponseFolder
        ForceDownload = $ForceDownload
        SkipServerFiles = $SkipServerFiles
    }

    if ($UseLatestVersion) { $params.UseLatestVersion = $true }
    if ($UseNextVersion) { $params.UseNextVersion = $true }
    if ($effectiveTargetGameVersion) { $params.TargetGameVersion = $effectiveTargetGameVersion }

    Push-Location $projectRoot
    try {
        & $script:DownloadModsOriginalCommand @params
    } finally {
        Pop-Location
    }
}

# Function intentionally overrides Download-Mods after the original module is imported.
