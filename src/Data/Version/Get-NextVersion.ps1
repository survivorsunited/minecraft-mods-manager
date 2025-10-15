# =============================================================================
# Get Next Version Function
# =============================================================================
# Returns the majority NextGameVersion from mods in the database
# =============================================================================

<#
.SYNOPSIS
    Gets the majority next game version from the modlist.

.DESCRIPTION
    Analyzes the NextGameVersion column to find the most common next version
    available for mods.

.PARAMETER CsvPath
    Path to the CSV file containing mod data.

.EXAMPLE
    Get-NextVersion -CsvPath "modlist.csv"

.NOTES
    - Looks at NextGameVersion column only
    - Excludes infrastructure types (server, launcher, installer)
    - Returns the most common version or $null if none found
#>
function Get-NextVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        $mods = Import-Csv -Path $CsvPath
        
        # Get NextGameVersion from mods only (exclude infrastructure)
        $nextVersions = $mods | Where-Object { 
            $_.Type -eq "mod" -and 
            -not [string]::IsNullOrEmpty($_.NextGameVersion) 
        } | Select-Object -ExpandProperty NextGameVersion
        
        if ($nextVersions.Count -eq 0) {
            Write-Host "❌ No mods with NextGameVersion found" -ForegroundColor Red
            return $null
        }
        
        # Get the most common version
        $majorityVersion = ($nextVersions | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
        
        return $majorityVersion
        
    } catch {
        Write-Host "❌ Error getting next version: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing

