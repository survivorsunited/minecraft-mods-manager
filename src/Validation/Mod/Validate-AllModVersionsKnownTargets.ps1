# =============================================================================
# Validate All Mod Versions Known Targets Wrapper
# =============================================================================
# Keeps -UpdateMods aligned with the release target model:
# - Current is whatever the DB says is current.
# - Next is the next known game version from Calculate-NextGameVersion (1.21.11 -> 26.1).
# - Latest defaults to 26.2.
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

    $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $CsvPath

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
        Write-Host "Refreshing Next* fields using known target version sequence..." -ForegroundColor Cyan
        $null = Calculate-NextVersionData -CsvPath $effectiveModListPath
    }

    if ($UpdateModList -or $UpdateLatestOnly) {
        Write-Host "Refreshing Latest* fields for target latest version 26.2..." -ForegroundColor Cyan
        $null = Calculate-LatestVersionData -CsvPath $effectiveModListPath -TargetLatestVersion "26.2"
    }

    return $result
}
