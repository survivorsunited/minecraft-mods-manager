# =============================================================================
# Get Latest Version Function
# =============================================================================
# Returns the majority LatestGameVersion from mods in the database
# =============================================================================

<#
.SYNOPSIS
    Gets the majority latest game version from the modlist.

.DESCRIPTION
    Analyzes the LatestGameVersion column to find the most common latest version
    available for mods.

.PARAMETER CsvPath
    Path to the CSV file containing mod data.

.EXAMPLE
    Get-LatestVersion -CsvPath "modlist.csv"

.NOTES
    - Looks at LatestGameVersion column only
    - Excludes infrastructure types (server, launcher, installer)
    - Returns the most common version or $null if none found
#>
function Get-LatestVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        $mods = Import-Csv -Path $CsvPath
        
        # Get LatestGameVersion from mods only (exclude infrastructure)
        $latestVersions = $mods | Where-Object { 
            $_.Type -eq "mod" -and 
            -not [string]::IsNullOrEmpty($_.LatestGameVersion) 
        } | Select-Object -ExpandProperty LatestGameVersion
        
        if ($latestVersions.Count -eq 0) {
            Write-Host "❌ No mods with LatestGameVersion found" -ForegroundColor Red
            return $null
        }
        
        # Get the most common version
        $majorityVersion = ($latestVersions | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
        
        return $majorityVersion
        
    } catch {
        Write-Host "❌ Error getting latest version: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing

