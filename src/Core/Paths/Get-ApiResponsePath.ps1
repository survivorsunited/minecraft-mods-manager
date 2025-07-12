# =============================================================================
# API Response Path Module
# =============================================================================
# This module handles path resolution for API response caching and storage.
# =============================================================================

<#
.SYNOPSIS
    Gets the API response path for a given domain and type.

.DESCRIPTION
    Constructs the appropriate file path for storing API responses based on
    the mod ID, response type, and domain. Creates directories as needed.

.PARAMETER ModId
    The mod ID to create a path for.

.PARAMETER ResponseType
    The type of response (project, versions, etc.).

.PARAMETER Domain
    The API domain (modrinth, curseforge, etc.).

.PARAMETER BaseResponseFolder
    The base folder for API responses.

.EXAMPLE
    Get-ApiResponsePath -ModId "fabric-api" -ResponseType "project" -Domain "modrinth"

.EXAMPLE
    Get-ApiResponsePath -ModId "357540" -ResponseType "versions" -Domain "curseforge"

.NOTES
    - Creates domain-specific subfolders automatically
    - Handles different filename patterns for different domains
    - Returns full path to the response file
#>
function Get-ApiResponsePath {
    param(
        [string]$ModId,
        [string]$ResponseType = "project", # or "versions"
        [string]$Domain = "modrinth", # or "curseforge"
        [string]$BaseResponseFolder = $ApiResponseFolder
    )
    
    # Get subfolder configuration from environment or use defaults
    $ModrinthApiResponseSubfolder = if ($env:APIRESPONSE_MODRINTH_SUBFOLDER) { $env:APIRESPONSE_MODRINTH_SUBFOLDER } else { "modrinth" }
    $CurseForgeApiResponseSubfolder = if ($env:APIRESPONSE_CURSEFORGE_SUBFOLDER) { $env:APIRESPONSE_CURSEFORGE_SUBFOLDER } else { "curseforge" }
    
    $subfolder = if ($Domain -eq "curseforge") { $CurseForgeApiResponseSubfolder } else { $ModrinthApiResponseSubfolder }
    $domainFolder = Join-Path $BaseResponseFolder $subfolder
    
    if (-not (Test-Path $domainFolder)) {
        New-Item -ItemType Directory -Path $domainFolder -Force | Out-Null
    }
    
    $filename = if ($Domain -eq "curseforge" -and $ResponseType -eq "versions") {
        "$ModId-curseforge-versions.json"
    } elseif ($ResponseType -eq "project") {
        "$ModId-project.json"
    } else {
        "$ModId-versions.json"
    }
    
    return Join-Path $domainFolder $filename
}

# Function is available for dot-sourcing 