# =============================================================================
# File Name Cleaning Module
# =============================================================================
# This module handles cleaning and sanitizing filenames for safe use.
# =============================================================================

<#
.SYNOPSIS
    Cleans a filename for safe use.

.DESCRIPTION
    Removes invalid characters from a filename to make it safe for file system use.
    Replaces problematic characters with underscores.

.PARAMETER Name
    The filename to clean.

.EXAMPLE
    Clean-Filename -Name "mod:api?*"

.NOTES
    - Removes characters that are invalid in Windows file systems
    - Replaces problematic characters with underscores
    - Ensures filename is safe for cross-platform use
#>
function Clean-Filename {
    param([Parameter(Mandatory=$true)][string]$Name)
    return ($Name -replace '[\\/:*?"<>|]', '_')
}

# Function is available for dot-sourcing 