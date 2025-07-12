# =============================================================================
# System Entries Cleaning Module
# =============================================================================
# This module handles cleaning up installer, launcher, and server entries.
# =============================================================================

<#
.SYNOPSIS
    Cleans up installer, launcher, and server entries.

.DESCRIPTION
    Ensures all API-related fields are empty strings for system entries
    (installer, launcher, server) to maintain data consistency.

.PARAMETER Mods
    The array of mod objects to clean.

.EXAMPLE
    Clean-SystemEntries -Mods $modList

.NOTES
    - Clears API-related fields for system entries
    - Sets ApiSource and Host to "direct"
    - Returns cleaned mod list
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