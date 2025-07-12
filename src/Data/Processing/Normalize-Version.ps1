# =============================================================================
# Version Normalization Module
# =============================================================================
# This module handles version string normalization for comparison.
# =============================================================================

<#
.SYNOPSIS
    Normalizes version strings for comparison.

.DESCRIPTION
    Normalizes version strings by removing common prefixes and suffixes
    to enable consistent version comparison.

.PARAMETER Version
    The version string to normalize.

.EXAMPLE
    Normalize-Version -Version "v1.2.3+fabric"

.NOTES
    - Removes common prefixes (v, version, release)
    - Removes common suffixes (+fabric, +neoforge, +forge, +mod)
    - Returns trimmed, normalized version string
#>
function Normalize-Version {
    param(
        [string]$Version
    )
    
    if ([string]::IsNullOrEmpty($Version)) {
        return $Version
    }
    
    # Remove common prefixes
    $normalized = $Version.Trim()
    $normalized = $normalized -replace '^v', ''  # Remove 'v' prefix
    $normalized = $normalized -replace '^version', ''  # Remove 'version' prefix
    $normalized = $normalized -replace '^release', ''  # Remove 'release' prefix
    $normalized = $normalized.Trim()
    
    # Remove common suffixes that might be added by the API
    $normalized = $normalized -replace '\+fabric$', ''  # Remove '+fabric' suffix
    $normalized = $normalized -replace '\+neoforge$', ''  # Remove '+neoforge' suffix
    $normalized = $normalized -replace '\+forge$', ''  # Remove '+forge' suffix
    $normalized = $normalized -replace '\+mod$', ''  # Remove '+mod' suffix
    
    return $normalized
}

# Function is available for dot-sourcing 