# =============================================================================
# Validate All Mod Versions Known Targets Wrapper
# =============================================================================
# Keeps -UpdateMods aligned with release-config.json:
# - Current is the DB/release current target.
# - Next is release-config targets.next.
# - Latest is release-config targets.latest.
# Also accepts -UseCachedResponses from the CLI so -UpdateMods does not fail on an unknown parameter.
# =============================================================================

if (-not $script:ValidateAllModVersionsOriginalCommand) {
    $script:ValidateAllModVersionsOriginalCommand = ${function:Validate-AllModVersions}
}

function Validate-AllModVersions {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$DatabaseFile,
        [string]$ModListFile,
        [string]$ResponseFolder = $ApiResponseFolder,
        [switch]$UpdateModList,
        [switch]$UpdateNextOnly,
        [switch]$UpdateLatestOnly,
        [switch]$UseCachedResponses
    )

    # Load GitHub direct URL validator at call time, after provider modules have been imported.
    try {
        $githubDirectWrapper = Join-Path $PSScriptRoot "..\..\Provider\GitHub\Validate-GitHubModVersionDirectUrls.ps1"
        if (Test-Path $githubDirectWrapper) {
            . $githubDirectWrapper
        }
    } catch {
        Write-Host "Warning: could not load GitHub direct URL validator: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $CsvPath

    $releaseTargets = $null
    if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
        $releaseTargets = Get-ReleaseVersionTargets
        if ($releaseTargets) {
            Write-Host "Release targets: Current=$($releaseTargets.Current), Next=$($releaseTargets.Next), Latest=$($releaseTargets.Latest)" -ForegroundColor Cyan
        }
    }

    if ($UseCachedResponses) {
        Write-Host "Using cached responses when provider modules support them." -ForegroundColor Gray
    }

    $params = @{
        CsvPath = $effectiveModListPath
        ResponseFolder = $ResponseFolder
        UpdateModList = $UpdateModList
        UpdateNextOnly = $UpdateNextOnly
        UpdateLatestOnly = $UpdateLatestOnly
    }

    $result = & $script:ValidateAllModVersionsOriginalCommand @params

    if ($UpdateModList -or $UpdateNextOnly) {
        $nextLabel = if ($releaseTargets -and $releaseTargets.Next) { $releaseTargets.Next } else { "known target" }
        Write-Host "Refreshing Next* fields for $nextLabel from release-config.json..." -ForegroundColor Cyan
        $null = Calculate-NextVersionData -CsvPath $effectiveModListPath
    }

    if ($UpdateModList -or $UpdateLatestOnly) {
        $latestTarget = if ($releaseTargets -and $releaseTargets.Latest) { $releaseTargets.Latest } else { "" }
        $latestLabel = if ($latestTarget) { $latestTarget } else { "release-config latest" }
        Write-Host "Refreshing Latest* fields for $latestLabel..." -ForegroundColor Cyan
        if ($latestTarget) {
            $null = Calculate-LatestVersionData -CsvPath $effectiveModListPath -TargetLatestVersion $latestTarget
        } else {
            $null = Calculate-LatestVersionData -CsvPath $effectiveModListPath
        }
    }

    return $result
}
