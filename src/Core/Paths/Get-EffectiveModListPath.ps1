# =============================================================================
# ModList Path Resolution Module
# =============================================================================
# This module handles path resolution for modlist database files.
# =============================================================================

<#
.SYNOPSIS
    Gets the effective modlist file path.

.DESCRIPTION
    Determines the correct modlist file path based on provided parameters.
    Prioritizes DatabaseFile over ModListFile over ModListPath.

.PARAMETER DatabaseFile
    The database file path (highest priority).

.PARAMETER ModListFile
    The modlist file path (medium priority).

.PARAMETER ModListPath
    The modlist path (lowest priority).

.EXAMPLE
    Get-EffectiveModListPath -DatabaseFile "custom.csv"

.EXAMPLE
    Get-EffectiveModListPath -ModListFile "mymods.csv"

.EXAMPLE
    Get-EffectiveModListPath -ModListPath "data/mods.csv"

.NOTES
    - Returns the first non-null parameter value
    - Falls back to "modlist.csv" if no parameters provided
    - Used for determining which database file to use
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