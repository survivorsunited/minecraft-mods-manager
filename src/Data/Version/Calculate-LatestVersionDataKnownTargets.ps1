# Overrides Calculate-LatestVersionData so the default latest target is 26.2.

if (-not $script:CalculateLatestVersionDataOriginalCommand) {
    $script:CalculateLatestVersionDataOriginalCommand = ${function:Calculate-LatestVersionData}
}

function Calculate-LatestVersionData {
    param(
        [string]$CsvPath = "modlist.csv",
        [string]$TargetLatestVersion = "26.2",
        [switch]$DryRun,
        [switch]$ReturnData
    )

    $params = @{
        CsvPath = $CsvPath
        TargetLatestVersion = $TargetLatestVersion
        DryRun = $DryRun
        ReturnData = $ReturnData
    }

    & $script:CalculateLatestVersionDataOriginalCommand @params
}
