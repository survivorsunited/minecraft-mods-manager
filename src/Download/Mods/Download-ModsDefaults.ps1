# =============================================================================
# Download Mods Defaults Wrapper
# =============================================================================
# This wrapper keeps the public Download-Mods command safe and predictable:
# - Plain -Download uses release-config.json targets.current before DB fallback.
# - Relative paths and .cache are anchored to the project root.
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

    $params = @{
        CsvPath = $effectiveCsvPath
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
