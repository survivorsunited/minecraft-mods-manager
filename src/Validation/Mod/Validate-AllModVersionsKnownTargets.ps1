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

function Repair-GitHubCurrentUrlsFromLatest {
    param([string]$CsvPath)

    if (-not (Test-Path $CsvPath)) { return }

    try {
        $mods = Import-Csv -Path $CsvPath
        $changed = $false
        $repairCount = 0

        foreach ($mod in $mods) {
            $isGitHub = ($mod.Host -eq "github" -or $mod.ApiSource -eq "github" -or $mod.Url -match "github\.com")
            if (-not $isGitHub) { continue }
            if ([string]::IsNullOrWhiteSpace($mod.CurrentGameVersion)) { continue }
            if ($mod.LatestGameVersion -ne $mod.CurrentGameVersion) { continue }
            if ([string]::IsNullOrWhiteSpace($mod.LatestVersionUrl)) { continue }
            if ($mod.LatestVersionUrl -notmatch [regex]::Escape($mod.CurrentGameVersion)) { continue }
            if ($mod.CurrentVersionUrl -eq $mod.LatestVersionUrl) { continue }

            $oldUrl = $mod.CurrentVersionUrl
            $mod.CurrentVersionUrl = $mod.LatestVersionUrl
            if (-not [string]::IsNullOrWhiteSpace($mod.LatestVersion)) { $mod.CurrentVersion = $mod.LatestVersion }

            try {
                $decoded = [System.Web.HttpUtility]::UrlDecode($mod.CurrentVersionUrl)
                $jar = [System.IO.Path]::GetFileName(($decoded -split '\?')[0])
                if (-not [string]::IsNullOrWhiteSpace($jar)) { $mod.Jar = $jar }
            } catch { }

            try { $mod.RecordHash = Calculate-RecordHash -Record $mod } catch { }

            Write-Host "Repaired GitHub current URL for $($mod.Name)" -ForegroundColor Green
            Write-Host "  Old: $oldUrl" -ForegroundColor DarkGray
            Write-Host "  New: $($mod.CurrentVersionUrl)" -ForegroundColor DarkGray
            $changed = $true
            $repairCount++
        }

        if ($changed) {
            $mods | Export-Csv -Path $CsvPath -NoTypeInformation
            Write-Host "Repaired $repairCount GitHub current URL(s) before validation." -ForegroundColor Green
        }
    } catch {
        Write-Host "Warning: GitHub URL repair failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
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

    try {
        $githubDirectWrapper = Join-Path $PSScriptRoot "..\..\Provider\GitHub\Validate-GitHubModVersionDirectUrls.ps1"
        if (Test-Path $githubDirectWrapper) { . $githubDirectWrapper }
    } catch {
        Write-Host "Warning: could not load GitHub direct URL validator: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $CsvPath

    $shouldUpdate = $UpdateModList -or $UpdateNextOnly -or $UpdateLatestOnly
    if ($shouldUpdate) { Repair-GitHubCurrentUrlsFromLatest -CsvPath $effectiveModListPath }

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

    # Always run the legacy validator in read-only mode here. Its built-in update path
    # still calculates Next as CurrentGameVersion + 1, which incorrectly targets 1.21.12.
    # Release-config-driven updates are applied below instead.
    $params = @{
        CsvPath = $effectiveModListPath
        ResponseFolder = $ResponseFolder
        UpdateModList = $false
        UpdateNextOnly = $false
        UpdateLatestOnly = $false
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
