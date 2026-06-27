# =============================================================================
# Get Current Version Function
# =============================================================================
# Returns the current game version target.
# =============================================================================

function Get-CurrentVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
            $targets = Get-ReleaseVersionTargets
            if ($targets -and -not [string]::IsNullOrWhiteSpace($targets.Current)) {
                return $targets.Current
            }
        }

        $mods = Import-Csv -Path $CsvPath
        $currentVersions = $mods | Where-Object { 
            $_.Type -eq "mod" -and 
            -not [string]::IsNullOrEmpty($_.CurrentGameVersion) 
        } | Select-Object -ExpandProperty CurrentGameVersion
        
        if ($currentVersions.Count -eq 0) {
            Write-Host "❌ No mods with CurrentGameVersion found" -ForegroundColor Red
            return $null
        }
        
        $majorityVersion = ($currentVersions | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
        return $majorityVersion
        
    } catch {
        Write-Host "❌ Error getting current version: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing
