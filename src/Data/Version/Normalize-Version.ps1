# =============================================================================
# Version Normalization Module
# =============================================================================
# This module handles version string normalization and comparison.
# =============================================================================

<#
.SYNOPSIS
    Normalizes a version string.

.DESCRIPTION
    Cleans and normalizes a version string for consistent comparison and processing.
    Removes invalid characters and converts to lowercase.

.PARAMETER Version
    The version string to normalize.

.EXAMPLE
    Normalize-Version -Version "1.21.5"

.NOTES
    - Removes non-alphanumeric characters except dots and hyphens
    - Converts to lowercase for consistent comparison
    - Ensures version strings are in a standard format
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