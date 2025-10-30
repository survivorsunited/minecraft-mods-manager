function Test-ModDatabase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [string]$OutputDir,
        [switch]$GitHubActions
    )

    if (-not (Test-Path $CsvPath)) {
        throw "CsvPath not found: $CsvPath"
    }

    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if (-not $OutputDir) {
        $outBase = Join-Path $repoRoot 'releases'
        if (-not (Test-Path $outBase)) { New-Item -ItemType Directory -Path $outBase -Force | Out-Null }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $OutputDir = Join-Path $outBase ("db-lint-" + $stamp)
    } elseif (-not ([System.IO.Path]::IsPathRooted($OutputDir))) {
        $OutputDir = Join-Path $repoRoot $OutputDir
    }
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

    $db = Import-Csv -Path $CsvPath
    # Misclassified ZIP artifacts where Type=mod
    $zipMods = $db | Where-Object {
        $_.Type -eq 'mod' -and (
            ([string]::IsNullOrWhiteSpace($_.Jar) -eq $false -and $_.Jar.ToLower().EndsWith('.zip')) -or
            ($_.CurrentVersionUrl -match '\.zip$') -or
            ($_.LatestVersionUrl -match '\.zip$') -or
            ($_.NextVersionUrl -match '\.zip$')
        )
    }

    $issues = @()
    foreach ($m in $zipMods) {
        $id = if ($m.ID) { $m.ID } else { $m.Name }
        $jar = if ($m.Jar) { $m.Jar } else { '(none)' }
        $issues += [pscustomobject]@{
            Id = $id
            Name = $m.Name
            Jar = $jar
            Type = $m.Type
            Reason = 'ZIP artifact detected for Type=mod'
        }
    }

    # Write machine-readable JSON
    $jsonPath = Join-Path $OutputDir 'database-lint.json'
    $issues | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonPath -Encoding UTF8

    # Write human summary (markdown)
    $summaryPath = Join-Path $OutputDir 'database-lint-summary.md'
    if ($issues.Count -gt 0) {
        $lines = @()
        $lines += "### ZIP Artifacts Detected in Database (Type=mod)"
        foreach ($i in $issues) { $lines += ("- {0} (ID: {1}) Jar: {2}" -f $i.Name, $i.Id, $i.Jar) }
        $lines | Out-File -FilePath $summaryPath -Encoding UTF8
    } else {
        "### No misclassified ZIP mods found in database" | Out-File -FilePath $summaryPath -Encoding UTF8
    }

    # Optionally emit GitHub Actions annotations and step summary
    if ($GitHubActions) {
        if ($issues.Count -gt 0) {
            foreach ($i in $issues) {
                Write-Host ("::warning title=ZIP artifact under mod type::{0} [ID: {1}] -> Jar: {2}" -f $i.Name, $i.Id, $i.Jar)
            }
        }
        if ($env:GITHUB_STEP_SUMMARY) {
            Get-Content -Path $summaryPath | Add-Content -Path $env:GITHUB_STEP_SUMMARY
            Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value ""
        }
    }

    return [pscustomobject]@{
        IssueCount = $issues.Count
        Issues = $issues
        OutputDir = $OutputDir
        SummaryPath = $summaryPath
        JsonPath = $jsonPath
    }
}
