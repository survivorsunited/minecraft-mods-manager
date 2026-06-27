# Overrides Calculate-LatestVersionData so the default latest target comes from release-config.json.

if (-not $script:CalculateLatestVersionDataOriginalCommand) {
    $script:CalculateLatestVersionDataOriginalCommand = ${function:Calculate-LatestVersionData}
}

function Calculate-LatestVersionData {
    param(
        [string]$CsvPath = "modlist.csv",
        [string]$TargetLatestVersion = "",
        [switch]$DryRun,
        [switch]$ReturnData
    )

    $effectiveLatestVersion = $TargetLatestVersion
    if ([string]::IsNullOrWhiteSpace($effectiveLatestVersion) -and (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue)) {
        $targets = Get-ReleaseVersionTargets
        if ($targets -and -not [string]::IsNullOrWhiteSpace($targets.Latest)) {
            $effectiveLatestVersion = $targets.Latest
            Write-Host "Latest target from release-config.json: $effectiveLatestVersion" -ForegroundColor Green
        }
    }

    if ([string]::IsNullOrWhiteSpace($effectiveLatestVersion)) {
        $effectiveLatestVersion = "26.2"
        Write-Host "Latest target fallback: $effectiveLatestVersion" -ForegroundColor Yellow
    }

    $params = @{
        CsvPath = $CsvPath
        TargetLatestVersion = $effectiveLatestVersion
        DryRun = $DryRun
        ReturnData = $ReturnData
    }

    & $script:CalculateLatestVersionDataOriginalCommand @params
}
