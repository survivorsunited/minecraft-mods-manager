# =============================================================================
# Latest Game Version Calculation Module
# =============================================================================
# This module handles calculation of latest game versions from available API data.
# =============================================================================

<#
.SYNOPSIS
    Calculates Latest Game Version and Latest Available Game Versions from actual API data.

.DESCRIPTION
    Uses the actual available game versions from the API response to determine:
    - Latest Game Version: The next version after the current GameVersion in the available versions list
    - Latest Available Game Versions: All versions above the Latest Game Version

.PARAMETER AvailableGameVersions
    Array of available game versions from the API (ordered from oldest to newest).

.PARAMETER CurrentGameVersion
    The current GameVersion to find the next version for.

.EXAMPLE
    $result = Calculate-LatestGameVersionFromAvailableVersions -AvailableGameVersions @("1.20.1", "1.20.2", "1.21.1", "1.21.2") -CurrentGameVersion "1.21.1"

.NOTES
    - Filters out non-version strings (like "fabric", "forge", etc.)
    - Sorts versions for proper ordering
    - Returns both latest game version and all available versions above it
    - Falls back to current version if no newer version found
#>
function Calculate-LatestGameVersionFromAvailableVersions {
    param(
        [Parameter(Mandatory=$true)][string[]]$AvailableGameVersions,
        [Parameter(Mandatory=$true)][string]$CurrentGameVersion
    )
    
    # Filter out non-version strings (like "fabric", "forge", etc.)
    $validVersions = $AvailableGameVersions | Where-Object { $_ -match '^\d+\.\d+\.\d+' } | Sort-Object
    
    if ($validVersions.Count -eq 0) {
        return @{
            LatestGameVersion = $CurrentGameVersion
            LatestAvailableGameVersions = @()
        }
    }
    
    # Find the current GameVersion in the list
    $currentIndex = -1
    for ($i = 0; $i -lt $validVersions.Count; $i++) {
        if ($validVersions[$i] -eq $CurrentGameVersion) {
            $currentIndex = $i
            break
        }
    }
    
    # If current version not found, use the first version as baseline
    if ($currentIndex -eq -1) {
        $currentIndex = 0
    }
    
    # Latest Game Version is the next version in the list
    $latestGameVersion = if ($currentIndex -lt ($validVersions.Count - 1)) {
        $validVersions[$currentIndex + 1]
    } else {
        $validVersions[$currentIndex]  # If at the end, use the current version
    }
    
    # Latest Available Game Versions are all versions above the Latest Game Version
    # For newer versions, we want to show the most recent versions regardless of format
    $latestAvailableGameVersions = $validVersions | Where-Object { 
        try {
            # Try to parse as version and compare
            [System.Version]$_ -gt [System.Version]$latestGameVersion
        } catch {
            # If version parsing fails, it might be a newer format (like 25w21a)
            # Check if it looks like a newer version
            if ($_ -match '^\d+w\d+[a-z]?$' -or $_ -match '^\d+\.\d+\.\d+-pre\d+$' -or $_ -match '^\d+\.\d+\.\d+-rc\d+$') {
                # These are newer snapshot/pre-release versions, include them
                $true
            } else {
                $false
            }
        }
    }
    
    # If no versions found with the above logic, include the most recent versions
    if ($latestAvailableGameVersions.Count -eq 0) {
        # Get the most recent versions (last 10)
        $latestAvailableGameVersions = $validVersions | Sort-Object | Select-Object -Last 10
    }
    
    return @{
        LatestGameVersion = $latestGameVersion
        LatestAvailableGameVersions = $latestAvailableGameVersions
    }
}

# Function is available for dot-sourcing 