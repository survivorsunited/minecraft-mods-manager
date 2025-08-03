# =============================================================================
# Server Files Download Module
# =============================================================================
# This module handles downloading Minecraft server JARs and Fabric launchers.
# =============================================================================

<#
.SYNOPSIS
    Downloads server JARs and Fabric launchers.

.DESCRIPTION
    Downloads Minecraft server JARs and Fabric launcher files
    for different game versions.

.PARAMETER DownloadFolder
    The base download folder.

.PARAMETER ForceDownload
    Whether to force download even if files exist.

.EXAMPLE
    Download-ServerFiles -DownloadFolder "download" -ForceDownload

.NOTES
    - Downloads server JARs for multiple game versions
    - Downloads Fabric launchers for server setup
    - Creates organized folder structure by version
    - Provides detailed download reports
#>
# Function to download server JARs and Fabric launchers
function Download-ServerFiles {
    param(
        [string]$DownloadFolder = "download",
        [switch]$ForceDownload,
        [string]$CsvPath = "modlist.csv",
        [string]$GameVersion = ""
    )
    
    # Use the database-driven approach
    return Download-ServerFilesFromDatabase -DownloadFolder $DownloadFolder -ForceDownload:$ForceDownload -CsvPath $CsvPath -GameVersion $GameVersion
}

# Function is available for dot-sourcing 