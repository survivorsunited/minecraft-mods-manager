# =============================================================================
# Get Latest Version Function
# =============================================================================
# Returns the latest game version target.
# =============================================================================

function Get-LatestVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
            $targets = Get-ReleaseVersionTargets
            if ($targets -and -not [string]::IsNullOrWhiteSpace($targets.Latest)) {
                return $targets.Latest
            }
        }

        $mods = Import-Csv -Path $CsvPath
        $latestVersions = $mods | Where-Object { 
            $_.Type -eq "mod" -and 
            -not [string]::IsNullOrEmpty($_.LatestGameVersion) 
        } | Select-Object -ExpandProperty LatestGameVersion
        
        if ($latestVersions.Count -eq 0) {
            Write-Host "❌ No mods with LatestGameVersion found" -ForegroundColor Red
            return $null
        }
        
        $majorityVersion = ($latestVersions | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
        return $majorityVersion
        
    } catch {
        Write-Host "❌ Error getting latest version: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing
