# Overrides Calculate-NextVersionData so NextGameVersion comes from the known version sequence.
# This handles the 1.21.11 -> 26.1 / 26.1.2 transition.

if (-not $script:CalculateNextVersionDataOriginalCommand) {
    $script:CalculateNextVersionDataOriginalCommand = ${function:Calculate-NextVersionData}
}

function Calculate-NextVersionData {
    param(
        [string]$CsvPath = "modlist.csv",
        [switch]$DryRun,
        [switch]$ReturnData
    )

    try {
        Write-Host "Calculating Next Version Data" -ForegroundColor Cyan
        if (-not (Test-Path $CsvPath)) { throw "Database file not found: $CsvPath" }

        try {
            $modrinthRepairModule = Join-Path $PSScriptRoot "..\..\Database\Operations\Repair-StaleModrinthCurrentUrls.ps1"
            if (Test-Path $modrinthRepairModule) {
                . $modrinthRepairModule
                if (-not $DryRun -and (Get-Command Repair-StaleModrinthCurrentUrls -ErrorAction SilentlyContinue)) {
                    $null = Repair-StaleModrinthCurrentUrls -CsvPath $CsvPath
                }
            }
        } catch {
            Write-Host "Warning: Modrinth current URL repair failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        $mods = Import-Csv -Path $CsvPath
        $nextInfo = Calculate-NextGameVersion -CsvPath $CsvPath
        if (-not $nextInfo -or [string]::IsNullOrWhiteSpace($nextInfo.NextVersion)) {
            throw "Could not determine next game version"
        }
        $nextGameVersion = $nextInfo.NextVersion
        Write-Host "Next game version target: $nextGameVersion" -ForegroundColor Green

        $updateCount = 0
        $skipCount = 0

        foreach ($mod in $mods) {
            if ($mod.Type -ne "mod") { $skipCount++; continue }

            $loader = if (-not [string]::IsNullOrWhiteSpace($mod.Loader)) { $mod.Loader } else { "fabric" }
            $mod.NextGameVersion = $nextGameVersion
            $mod.NextVersion = ""
            $mod.NextVersionUrl = ""

            if ($mod.LatestGameVersion -eq $nextGameVersion -and -not [string]::IsNullOrWhiteSpace($mod.LatestVersionUrl)) {
                $mod.NextVersion = $mod.LatestVersion
                $mod.NextVersionUrl = $mod.LatestVersionUrl
            } elseif ($mod.CurrentGameVersion -eq $nextGameVersion -and -not [string]::IsNullOrWhiteSpace($mod.CurrentVersionUrl)) {
                $mod.NextVersion = $mod.CurrentVersion
                $mod.NextVersionUrl = $mod.CurrentVersionUrl
            } elseif ($mod.AvailableGameVersions -and (($mod.AvailableGameVersions -split ',') | ForEach-Object { $_.Trim() }) -contains $nextGameVersion) {
                try {
                    $validation = Validate-ModVersion -ModId $mod.ID -Version "latest" -Loader $loader -GameVersion $nextGameVersion -ResponseFolder "apiresponse" -Jar $mod.Jar -CsvPath $CsvPath -Quiet
                    if ($validation -and $validation.Exists -and $validation.VersionUrl) {
                        $mod.NextVersion = $validation.LatestVersion
                        $mod.NextVersionUrl = $validation.VersionUrl
                    } elseif ($validation -and $validation.Exists -and $validation.LatestVersionUrl) {
                        $mod.NextVersion = $validation.LatestVersion
                        $mod.NextVersionUrl = $validation.LatestVersionUrl
                    }
                } catch { }
            }

            if ($mod.NextVersionUrl) { $updateCount++ } else { $skipCount++ }
            try { $mod.RecordHash = Calculate-RecordHash -Record $mod } catch { }
        }

        if ($DryRun) {
            Write-Host "DRY RUN: Next Game Version: $nextGameVersion" -ForegroundColor Yellow
            Write-Host "Mods with next version: $updateCount" -ForegroundColor Green
            Write-Host "Skipped/no support: $skipCount" -ForegroundColor Gray
            return $true
        }

        if ($ReturnData) { return $mods }

        $backupDir = "backups"
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = Join-Path $backupDir "$timestamp-pre-nextversion-$(Split-Path $CsvPath -Leaf)"
        Copy-Item -Path $CsvPath -Destination $backupPath -Force
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation

        Write-Host "NEXT VERSION DATA CALCULATED" -ForegroundColor Green
        Write-Host "Next Game Version: $nextGameVersion" -ForegroundColor Green
        Write-Host "Mods with next version: $updateCount" -ForegroundColor Green
        Write-Host "Skipped/no support: $skipCount" -ForegroundColor Yellow
        Write-Host "Backup: $backupPath" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Failed to calculate next version data: $($_.Exception.Message)" -ForegroundColor Red
        if ($ReturnData) { return @() }
        return $false
    }
}
