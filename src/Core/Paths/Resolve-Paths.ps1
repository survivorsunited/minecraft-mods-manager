# =============================================================================
# Path Resolution Module
# =============================================================================
# This module handles path resolution and management.
# =============================================================================

<#
.SYNOPSIS
    Gets the effective modlist file path.

.DESCRIPTION
    Determines the correct modlist file path based on provided parameters,
    with fallback to default values.

.PARAMETER DatabaseFile
    The database file path.

.PARAMETER ModListFile
    The modlist file path.

.PARAMETER ModListPath
    The modlist path.

.EXAMPLE
    Get-EffectiveModListPath -DatabaseFile "custom.csv" -ModListFile "mods.csv"

.NOTES
    - Prioritizes DatabaseFile over ModListFile over ModListPath
    - Falls back to "modlist.csv" if no path is provided
#>
function Get-EffectiveModListPath {
    param(
        [string]$DatabaseFile,
        [string]$ModListFile,
        [string]$ModListPath = "modlist.csv"
    )
    if ($DatabaseFile) { return $DatabaseFile }
    if ($ModListFile) { return $ModListFile }
    if ($ModListPath) { return $ModListPath }
    return "modlist.csv"
}

# Function is available for dot-sourcing 