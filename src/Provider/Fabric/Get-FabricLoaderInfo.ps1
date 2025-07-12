# =============================================================================
# Fabric Loader Info Module
# =============================================================================
# This module handles retrieving loader information from Fabric API.
# =============================================================================

<#
.SYNOPSIS
    Retrieves Fabric loader information from Fabric API.

.DESCRIPTION
    Fetches Fabric loader version information and download URLs from the Fabric API.
    Handles loader metadata and compatibility information.

.PARAMETER GameVersion
    The Minecraft version to get loader info for.

.PARAMETER UseCachedResponses
    Whether to use cached API responses.

.EXAMPLE
    Get-FabricLoaderInfo -GameVersion "1.21.5"

.NOTES
    - Uses Fabric meta API
    - Handles API rate limiting
    - Returns null if version not found or API unavailable
#>
function Get-FabricLoaderInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [bool]$UseCachedResponses = $false
    )
    
    try {
        $apiUrl = "https://meta.fabricmc.net/v2/versions/loader/$GameVersion"
        $cachePath = Join-Path $script:TestApiResponseDir "fabric" "loader-$GameVersion.json"
        
        # Use cached response if available and requested
        if ($UseCachedResponses -and (Test-Path $cachePath)) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            Write-Host "Using cached Fabric loader info for $GameVersion" -ForegroundColor Gray
            return $response
        }
        
        # Make API request
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
        
        # Cache response if directory exists
        if (Test-Path (Split-Path $cachePath)) {
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        }
        
        return $response
        
    } catch {
        Write-Host "Failed to get Fabric loader info for $GameVersion : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing 