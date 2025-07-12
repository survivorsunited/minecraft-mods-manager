# =============================================================================
# System Entries Cleaning Module
# =============================================================================
# This module handles cleaning up system entries in mod lists.
# =============================================================================

<#
.SYNOPSIS
    Cleans up installer, launcher, and server entries.

.DESCRIPTION
    Ensures all API-related fields are empty strings for system entries
    like installers, launchers, and servers.

.PARAMETER Mods
    Array of mod objects to clean.

.EXAMPLE
    Clean-SystemEntries -Mods $modList

.NOTES
    - Cleans installer, launcher, and server entries
    - Sets API-related fields to empty strings
    - Sets ApiSource and Host to "direct"
    - Returns cleaned mods array
#>
function Clean-SystemEntries {
    param(
        [array]$Mods
    )
    
    foreach ($mod in $Mods) {
        if ($mod.Type -in @("installer", "launcher", "server")) {
            # Ensure all API-related fields are empty strings for system entries
            $mod.IconUrl = ""
            $mod.ClientSide = ""
            $mod.ServerSide = ""
            $mod.Title = if ($mod.Title) { $mod.Title } else { $mod.Name }
            $mod.ProjectDescription = ""
            $mod.IssuesUrl = ""
            $mod.SourceUrl = ""
            $mod.WikiUrl = ""
            $mod.LatestGameVersion = ""
            $mod.CurrentDependencies = ""
            $mod.LatestDependencies = ""
            $mod.CurrentDependenciesRequired = ""
            $mod.CurrentDependenciesOptional = ""
            $mod.LatestDependenciesRequired = ""
            $mod.LatestDependenciesOptional = ""
            
            # Ensure ApiSource and Host are set correctly
            $mod.ApiSource = "direct"
            $mod.Host = "direct"
        }
    }
    
    return $Mods
}

# Function is available for dot-sourcing 