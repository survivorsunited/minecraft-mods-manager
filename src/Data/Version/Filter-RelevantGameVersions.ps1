# =============================================================================
# Game Version Filtering Module
# =============================================================================
# This module handles filtering and validation of game versions.
# =============================================================================

<#
.SYNOPSIS
    Filters out ancient/irrelevant game versions from a list.

.DESCRIPTION
    Removes versions that are too old to be relevant for current mod management.
    Filters out versions like "1", "1.0", "1.1", etc. that are completely outdated.

.PARAMETER GameVersions
    Array of game version strings to filter.

.PARAMETER MinimumRelevantVersion
    The minimum version to consider relevant (default: "1.20.0").

.EXAMPLE
    $filteredVersions = Filter-RelevantGameVersions -GameVersions @("1", "1.21.5", "1.21.6")

.NOTES
    - Filters out ancient Minecraft versions that are no longer relevant
    - Removes "unknown" versions
    - Applies minimum version threshold if specified
    - Keeps special version strings that can't be parsed as versions
#>
function Filter-RelevantGameVersions {
    param(
        [Parameter(Mandatory=$true)][string[]]$GameVersions,
        [string]$MinimumRelevantVersion = "1.20.0"
    )
    
    # Define ancient versions to filter out
    $ancientVersions = @(
        "1", "1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9",
        "1.10", "1.11", "1.12", "1.13", "1.14", "1.15", "1.16", "1.17", "1.18", "1.19"
    )
    
    # Filter out ancient versions and unknown
    $filteredVersions = $GameVersions | Where-Object {
        $_ -and 
        $_ -ne "unknown" -and 
        $ancientVersions -notcontains $_
    }
    
    # If we have a minimum version, also filter by that
    if ($MinimumRelevantVersion) {
        $filteredVersions = $filteredVersions | Where-Object {
            try {
                [System.Version]$_ -ge [System.Version]$MinimumRelevantVersion
            } catch {
                # If version parsing fails, keep it (might be a special version)
                $true
            }
        }
    }
    
    return $filteredVersions
}

# Function is available for dot-sourcing 