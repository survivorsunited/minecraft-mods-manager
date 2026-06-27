# =============================================================================
# Download Mods Defaults Wrapper
# =============================================================================
# This wrapper keeps the public Download-Mods command safe and predictable:
# - Plain -Download uses release-config.json targets.current before DB fallback.
# - Relative paths and .cache are anchored to the project root.
# - GitHub release asset URLs are made safe for the legacy downloader's UrlDecode call.
# - Stale Modrinth URLs are cleared or replaced in the temporary download CSV.
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

function Convert-ModManagerStableVersion {
    param([string]$Version)

    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    $v = $Version.Trim()
    if ($v -notmatch '^(\d+)\.(\d+)(?:\.(\d+))?$') { return $null }
    $patch = if ($matches[3]) { $matches[3] } else { '0' }
    try { return [version]"$($matches[1]).$($matches[2]).$patch" } catch { return $null }
}

function Protect-GitHubReleaseAssetUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $Url }
    if ($Url -notmatch 'github\.com/.+/releases/download/.+') { return $Url }
    if ($Url -notmatch '\+') { return $Url }

    return ($Url -replace '\+', '%2B')
}

function Get-UrlFileNameSafe {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return "" }
    try {
        $decoded = [System.Web.HttpUtility]::UrlDecode($Url)
        return [System.IO.Path]::GetFileName(($decoded -split '\?')[0])
    } catch { return "" }
}

function Find-BestCompatibleModrinthArtifact {
    param(
        [pscustomobject]$Row,
        [string]$TargetGameVersion
    )

    if ($Row.Host -ne 'modrinth') { return $null }
    if ($Row.Type -ne 'mod') { return $null }
    if ([string]::IsNullOrWhiteSpace($Row.ID)) { return $null }
    if ([string]::IsNullOrWhiteSpace($TargetGameVersion)) { return $null }

    $targetParsed = Convert-ModManagerStableVersion -Version $TargetGameVersion
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
                $parsedGameVersion = Convert-ModManagerStableVersion -Version $gameVersion
                if (-not $parsedGameVersion) { continue }
                if ($parsedGameVersion -le $targetParsed) {
                    $file = ($version.files | Where-Object { $_.primary -eq $true } | Select-Object -First 1)
                    if (-not $file) { $file = $version.files[0] }
                    $candidates += [PSCustomObject]@{
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

        return $candidates |
            Sort-Object ParsedGameVersion, DatePublished -Descending |
            Select-Object -First 1
    } catch {
        return $null
    }
}

function Use-BestCompatibleModrinthArtifactForTarget {
    param(
        [pscustomobject]$Row,
        [string]$TargetGameVersion
    )

    if ([string]::IsNullOrWhiteSpace($TargetGameVersion)) { return $false }
    if ($Row.Host -ne 'modrinth') { return $false }
    if ($Row.Type -ne 'mod') { return $false }

    $currentUrl = [string]$Row.CurrentVersionUrl
    $currentFileName = Get-UrlFileNameSafe -Url $currentUrl
    $currentLooksCorrect = (-not [string]::IsNullOrWhiteSpace($currentUrl) -and $currentFileName -match [regex]::Escape($TargetGameVersion))
    if ($currentLooksCorrect) { return $false }

    $artifact = Find-BestCompatibleModrinthArtifact -Row $Row -TargetGameVersion $TargetGameVersion
    if (-not $artifact) { return $false }

    $Row.CurrentGameVersion = $TargetGameVersion
    $Row.CurrentVersion = $artifact.VersionNumber
    $Row.CurrentVersionUrl = $artifact.Url
    $Row.Jar = $artifact.FileName

    Write-Host "🔁 $($Row.Name): using best compatible Modrinth artifact $($artifact.GameVersion) for target $TargetGameVersion ($($artifact.VersionNumber))" -ForegroundColor Yellow
    return $true
}

function Clear-StaleModrinthUrl {
    param(
        [pscustomobject]$Row,
        [string]$UrlField,
        [string]$GameVersionField
    )

    if ($Row.Host -ne 'modrinth') { return $false }
    if (-not ($Row.PSObject.Properties.Name -contains $UrlField)) { return $false }
    if (-not ($Row.PSObject.Properties.Name -contains $GameVersionField)) { return $false }

    $url = [string]$Row.$UrlField
    $gameVersion = [string]$Row.$GameVersionField
    if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($gameVersion)) { return $false }
    if ($url -notmatch 'cdn\.modrinth\.com/.+\.(jar|zip)') { return $false }

    $fileName = Get-UrlFileNameSafe -Url $url
    if ([string]::IsNullOrWhiteSpace($fileName)) { return $false }

    if ($fileName -notmatch [regex]::Escape($gameVersion)) {
        $Row.$UrlField = ""
        return $true
    }

    return $false
}

function New-DownloadSafeCsv {
    param(
        [string]$CsvPath,
        [string]$ApiResponseFolder,
        [string]$TargetGameVersion = ""
    )

    if (-not (Test-Path $CsvPath)) { return $CsvPath }
    if (-not (Test-Path $ApiResponseFolder)) { New-Item -ItemType Directory -Path $ApiResponseFolder -Force | Out-Null }

    try {
        $rows = Import-Csv -Path $CsvPath
        $urlFields = @('Url', 'CurrentVersionUrl', 'NextVersionUrl', 'LatestVersionUrl', 'UrlDirect')
        $changed = $false
        $staleCount = 0
        $compatibleFallbackCount = 0

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

            $usedCompatibleFallback = Use-BestCompatibleModrinthArtifactForTarget -Row $row -TargetGameVersion $TargetGameVersion
            if ($usedCompatibleFallback) {
                $changed = $true
                $compatibleFallbackCount++
            } else {
                if (Clear-StaleModrinthUrl -Row $row -UrlField 'CurrentVersionUrl' -GameVersionField 'CurrentGameVersion') { $changed = $true; $staleCount++ }
            }

            if (Clear-StaleModrinthUrl -Row $row -UrlField 'NextVersionUrl' -GameVersionField 'NextGameVersion') { $changed = $true; $staleCount++ }
            if (Clear-StaleModrinthUrl -Row $row -UrlField 'LatestVersionUrl' -GameVersionField 'LatestGameVersion') { $changed = $true; $staleCount++ }
        }

        if (-not $changed) { return $CsvPath }

        $safeCsvPath = Join-Path $ApiResponseFolder "download-safe-modlist.csv"
        $rows | Export-Csv -Path $safeCsvPath -NoTypeInformation
        Write-Host "🔧 Created download-safe CSV: $safeCsvPath" -ForegroundColor Gray
        if ($staleCount -gt 0) { Write-Host "🔧 Cleared $staleCount stale Modrinth URL(s) in download-safe CSV so API resolution can pick the right file." -ForegroundColor Gray }
        if ($compatibleFallbackCount -gt 0) { Write-Host "🔧 Selected best compatible Modrinth artifact for $compatibleFallbackCount row(s) without exact target support." -ForegroundColor Gray }
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

    $downloadCsvPath = New-DownloadSafeCsv -CsvPath $effectiveCsvPath -ApiResponseFolder $effectiveApiResponseFolder -TargetGameVersion $effectiveTargetGameVersion

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
