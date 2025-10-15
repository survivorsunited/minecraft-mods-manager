# =============================================================================
# Get Current Version Function
# =============================================================================
# Returns the majority CurrentGameVersion from mods in the database
# =============================================================================

<#
.SYNOPSIS
    Gets the majority current game version from the modlist.

.DESCRIPTION
    Analyzes the CurrentGameVersion column to find the most common version
    currently in use by mods.

.PARAMETER CsvPath
    Path to the CSV file containing mod data.

.EXAMPLE
    Get-CurrentVersion -CsvPath "modlist.csv"

.NOTES
    - Looks at CurrentGameVersion column only
    - Excludes infrastructure types (server, launcher, installer)
    - Returns the most common version or $null if none found
#>
function Get-CurrentVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        $mods = Import-Csv -Path $CsvPath
        
        # Get CurrentGameVersion from mods only (exclude infrastructure)
        $currentVersions = $mods | Where-Object { 
            $_.Type -eq "mod" -and 
            -not [string]::IsNullOrEmpty($_.CurrentGameVersion) 
        } | Select-Object -ExpandProperty CurrentGameVersion
        
        if ($currentVersions.Count -eq 0) {
            Write-Host "❌ No mods with CurrentGameVersion found" -ForegroundColor Red
            return $null
        }
        
        # Get the most common version
        $majorityVersion = ($currentVersions | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
        
        return $majorityVersion
        
    } catch {
        Write-Host "❌ Error getting current version: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing

