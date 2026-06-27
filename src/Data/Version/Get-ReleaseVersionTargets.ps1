# =============================================================================
# Release Version Targets Helper
# =============================================================================
# Reads current, next, and latest game-version targets from release-config.json.
# =============================================================================

function Get-ReleaseVersionTargets {
    param(
        [string]$ReleaseConfigPath = ""
    )

    function ConvertTo-ReleaseSortableVersion {
        param([string]$Version)
        try {
            $clean = ($Version -replace '[^0-9\.]', '')
            if ([string]::IsNullOrWhiteSpace($clean)) { return $null }
            return [version]$clean
        } catch { return $null }
    }

    try {
        if ([string]::IsNullOrWhiteSpace($ReleaseConfigPath)) {
            $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
            $ReleaseConfigPath = Join-Path $projectRoot "release-config.json"
        }

        if (-not (Test-Path $ReleaseConfigPath)) {
            return [PSCustomObject]@{ Current = ""; Next = ""; Latest = ""; Source = "missing" }
        }

        $config = Get-Content -Path $ReleaseConfigPath -Raw | ConvertFrom-Json

        $current = ""
        $next = ""
        $latest = ""

        if ($config.targets) {
            $current = [string]$config.targets.current
            $next = [string]$config.targets.next
            $latest = [string]$config.targets.latest
        }

        $versions = @()
        if ($config.versions) {
            $versions = @($config.versions | ForEach-Object { [string]$_.version } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }

        if ([string]::IsNullOrWhiteSpace($current) -and $config.versions) {
            $enabled = @($config.versions | Where-Object { $_.enabled -eq $true } | Select-Object -First 1)
            if ($enabled -and $enabled.Count -gt 0) { $current = [string]$enabled[0].version }
        }

        if ([string]::IsNullOrWhiteSpace($next) -and -not [string]::IsNullOrWhiteSpace($current) -and $versions.Count -gt 0) {
            $currentSortable = ConvertTo-ReleaseSortableVersion $current
            foreach ($candidate in ($versions | Sort-Object { ConvertTo-ReleaseSortableVersion $_ })) {
                $candidateSortable = ConvertTo-ReleaseSortableVersion $candidate
                if ($candidateSortable -and $currentSortable -and $candidateSortable -gt $currentSortable) {
                    $next = $candidate
                    break
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($latest) -and $versions.Count -gt 0) {
            $latest = ($versions | Sort-Object { ConvertTo-ReleaseSortableVersion $_ } | Select-Object -Last 1)
        }

        return [PSCustomObject]@{
            Current = $current
            Next = $next
            Latest = $latest
            Source = $ReleaseConfigPath
        }
    } catch {
        Write-Host "Failed to read release version targets: $($_.Exception.Message)" -ForegroundColor Yellow
        return [PSCustomObject]@{ Current = ""; Next = ""; Latest = ""; Source = "error" }
    }
}

# Function is available for dot-sourcing
