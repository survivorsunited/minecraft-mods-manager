# Final download wrapper that applies local mod patch scripts after download.
# Patch scripts live under patches/mods/<mod-id>/<minecraft-version>/*.ps1.

if (-not $script:DownloadModsBeforePatchRunner) {
    $script:DownloadModsBeforePatchRunner = ${function:Download-Mods}
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

    $params = @{
        CsvPath = $CsvPath
        DownloadFolder = $DownloadFolder
        ForceDownload = $ForceDownload
        SkipServerFiles = $SkipServerFiles
    }
    if ($ApiResponseFolder) { $params.ApiResponseFolder = $ApiResponseFolder }
    if ($UseLatestVersion) { $params.UseLatestVersion = $true }
    if ($UseNextVersion) { $params.UseNextVersion = $true }
    if ($TargetGameVersion) { $params.TargetGameVersion = $TargetGameVersion }

    & $script:DownloadModsBeforePatchRunner @params

    $effectiveTargetGameVersion = $TargetGameVersion
    if ([string]::IsNullOrWhiteSpace($effectiveTargetGameVersion) -and -not $UseLatestVersion -and -not $UseNextVersion) {
        if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
            $targets = Get-ReleaseVersionTargets
            if ($targets -and $targets.Current) { $effectiveTargetGameVersion = $targets.Current }
        }
    }

    if (Get-Command Apply-ModPatches -ErrorAction SilentlyContinue) {
        Apply-ModPatches -DownloadFolder $DownloadFolder -TargetGameVersion $effectiveTargetGameVersion -ModListPath $CsvPath
    }
}
