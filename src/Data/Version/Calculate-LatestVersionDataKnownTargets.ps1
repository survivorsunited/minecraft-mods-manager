# Overrides Calculate-LatestVersionData so latest target comes from release-config.json
# and GitHub-hosted mods use GitHub release URLs instead of Modrinth routes.

if (-not $script:CalculateLatestVersionDataOriginalCommand) {
    $script:CalculateLatestVersionDataOriginalCommand = ${function:Calculate-LatestVersionData}
}

function Get-LatestKnownTargetVersion {
    param([string]$TargetLatestVersion)

    if (-not [string]::IsNullOrWhiteSpace($TargetLatestVersion)) { return $TargetLatestVersion }

    if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
        $targets = Get-ReleaseVersionTargets
        if ($targets -and -not [string]::IsNullOrWhiteSpace($targets.Latest)) {
            Write-Host "Latest target from release-config.json: $($targets.Latest)" -ForegroundColor Green
            return $targets.Latest
        }
    }

    Write-Host "Latest target fallback: 26.2" -ForegroundColor Yellow
    return "26.2"
}

function Get-HighestVersionToken {
    param([string]$AvailableGameVersions)

    if ([string]::IsNullOrWhiteSpace($AvailableGameVersions)) { return "" }

    $versions = $AvailableGameVersions -split ',' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^\d+(\.\d+){0,2}' }

    if (-not $versions) { return "" }

    try {
        return ($versions | Sort-Object { [version](($_ -replace '[^0-9\.]','').Trim('.')) } | Select-Object -Last 1)
    } catch {
        return ($versions | Sort-Object | Select-Object -Last 1)
    }
}

function Select-GitHubLatestCandidate {
    param(
        [pscustomobject]$Mod,
        [string]$TargetLatestVersion
    )

    $candidates = @(
        [PSCustomObject]@{ Source = 'Latest'; GameVersion = $Mod.LatestGameVersion; Version = $Mod.LatestVersion; Url = $Mod.LatestVersionUrl },
        [PSCustomObject]@{ Source = 'Current'; GameVersion = $Mod.CurrentGameVersion; Version = $Mod.CurrentVersion; Url = $Mod.CurrentVersionUrl },
        [PSCustomObject]@{ Source = 'Next'; GameVersion = $Mod.NextGameVersion; Version = $Mod.NextVersion; Url = $Mod.NextVersionUrl }
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Url) }

    $exact = $candidates | Where-Object {
        $_.GameVersion -eq $TargetLatestVersion -and $_.Url -match [regex]::Escape($TargetLatestVersion)
    } | Select-Object -First 1
    if ($exact) { return $exact }

    $withVersionInUrl = $candidates | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.GameVersion) -and $_.Url -match [regex]::Escape($_.GameVersion)
    } | Sort-Object { try { [version](($_.GameVersion -replace '[^0-9\.]','').Trim('.')) } catch { [version]'0.0' } } -Descending | Select-Object -First 1
    if ($withVersionInUrl) { return $withVersionInUrl }

    return ($candidates | Select-Object -First 1)
}

function Calculate-LatestVersionData {
    param(
        [string]$CsvPath = "modlist.csv",
        [string]$TargetLatestVersion = "",
        [switch]$DryRun,
        [switch]$ReturnData
    )

    try {
        $effectiveLatestVersion = Get-LatestKnownTargetVersion -TargetLatestVersion $TargetLatestVersion
        Write-Host "Calculating Latest Version Data" -ForegroundColor Cyan
        Write-Host "Target Latest Version: $effectiveLatestVersion" -ForegroundColor Gray

        if (-not (Test-Path $CsvPath)) { throw "Database file not found: $CsvPath" }
        $mods = Import-Csv -Path $CsvPath

        $updateCount = 0
        $skipCount = 0
        $actionSummary = @{}

        foreach ($mod in $mods) {
            if ($mod.Type -ne "mod") { $skipCount++; continue }

            $isGitHub = ($mod.Host -eq "github" -or $mod.ApiSource -eq "github" -or $mod.Url -match "github\.com")
            $loader = if (-not [string]::IsNullOrWhiteSpace($mod.Loader)) { $mod.Loader } else { "fabric" }
            $action = "Skipped"

            if ($isGitHub) {
                $candidate = Select-GitHubLatestCandidate -Mod $mod -TargetLatestVersion $effectiveLatestVersion
                if ($candidate) {
                    $mod.LatestGameVersion = if ($candidate.GameVersion) { $candidate.GameVersion } else { $mod.CurrentGameVersion }
                    $mod.LatestVersion = if ($candidate.Version) { $candidate.Version } else { $mod.CurrentVersion }
                    $mod.LatestVersionUrl = $candidate.Url
                    $action = "GitHub direct URL"
                    $updateCount++
                } else {
                    $skipCount++
                    $action = "GitHub no URL"
                }
            } else {
                $available = @()
                if (-not [string]::IsNullOrWhiteSpace($mod.AvailableGameVersions)) {
                    $available = $mod.AvailableGameVersions -split ',' | ForEach-Object { $_.Trim() }
                }

                $queryVersion = if ($available -contains $effectiveLatestVersion) { $effectiveLatestVersion } else { Get-HighestVersionToken -AvailableGameVersions $mod.AvailableGameVersions }

                if (-not [string]::IsNullOrWhiteSpace($queryVersion) -and $mod.Host -eq "modrinth") {
                    try {
                        $validation = Validate-ModVersion -ModId $mod.ID -Version "latest" -Loader $loader -GameVersion $queryVersion -ResponseFolder "apiresponse" -Jar $mod.Jar -CsvPath $CsvPath -Quiet
                        if ($validation -and $validation.Exists -and ($validation.VersionUrl -or $validation.LatestVersionUrl)) {
                            $mod.LatestGameVersion = $queryVersion
                            $mod.LatestVersion = if ($validation.LatestVersion) { $validation.LatestVersion } else { $mod.CurrentVersion }
                            $mod.LatestVersionUrl = if ($validation.VersionUrl) { $validation.VersionUrl } else { $validation.LatestVersionUrl }
                            $action = "Provider verified"
                            $updateCount++
                        } else {
                            $mod.LatestGameVersion = $mod.CurrentGameVersion
                            $mod.LatestVersion = $mod.CurrentVersion
                            $mod.LatestVersionUrl = $mod.CurrentVersionUrl
                            $action = "Fallback to Current"
                            $skipCount++
                        }
                    } catch {
                        $mod.LatestGameVersion = $mod.CurrentGameVersion
                        $mod.LatestVersion = $mod.CurrentVersion
                        $mod.LatestVersionUrl = $mod.CurrentVersionUrl
                        $action = "Error fallback"
                        $skipCount++
                    }
                } else {
                    $mod.LatestGameVersion = $mod.CurrentGameVersion
                    $mod.LatestVersion = $mod.CurrentVersion
                    $mod.LatestVersionUrl = $mod.CurrentVersionUrl
                    $action = "Fallback to Current"
                    $skipCount++
                }
            }

            try { $mod.RecordHash = Calculate-RecordHash -Record $mod } catch { }
            if (-not $actionSummary.ContainsKey($action)) { $actionSummary[$action] = 0 }
            $actionSummary[$action]++
        }

        if ($DryRun) {
            Write-Host "DRY RUN: Latest target $effectiveLatestVersion" -ForegroundColor Yellow
            Write-Host "Updated: $updateCount; Skipped/fallback: $skipCount" -ForegroundColor Gray
            return $true
        }

        if ($ReturnData) { return $mods }

        $backupDir = "backups"
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = Join-Path $backupDir "$timestamp-pre-latestversion-$(Split-Path $CsvPath -Leaf)"
        Copy-Item -Path $CsvPath -Destination $backupPath -Force
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation

        Write-Host "LATEST VERSION DATA CALCULATED" -ForegroundColor Green
        Write-Host "Latest target: $effectiveLatestVersion" -ForegroundColor Green
        Write-Host "Updated: $updateCount" -ForegroundColor Green
        Write-Host "Skipped/fallback: $skipCount" -ForegroundColor Yellow
        Write-Host "Backup: $backupPath" -ForegroundColor Green
        foreach ($key in $actionSummary.Keys) { Write-Host "   ${key}: $($actionSummary[$key])" -ForegroundColor Gray }
        return $true
    } catch {
        Write-Host "Failed to calculate latest version data: $($_.Exception.Message)" -ForegroundColor Red
        if ($ReturnData) { return @() }
        return $false
    }
}
