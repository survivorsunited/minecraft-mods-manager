# =============================================================================
# Get Next Version Function
# =============================================================================
# Returns the next game version target.
# =============================================================================

function Get-NextVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
            $targets = Get-ReleaseVersionTargets
            if ($targets -and -not [string]::IsNullOrWhiteSpace($targets.Next)) {
                return $targets.Next
            }
        }

        $mods = Import-Csv -Path $CsvPath
        $nextVersions = $mods | Where-Object { 
            $_.Type -eq "mod" -and 
            -not [string]::IsNullOrEmpty($_.NextGameVersion) 
        } | Select-Object -ExpandProperty NextGameVersion
        
        if ($nextVersions.Count -eq 0) {
            Write-Host "❌ No mods with NextGameVersion found" -ForegroundColor Red
            return $null
        }
        
        $majorityVersion = ($nextVersions | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
        return $majorityVersion
        
    } catch {
        Write-Host "❌ Error getting next version: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing
