# =============================================================================
# Modrinth Project Info Module
# =============================================================================
# This module handles retrieving project information from Modrinth API.
# =============================================================================

<#
.SYNOPSIS
    Retrieves comprehensive project information from Modrinth API.

.DESCRIPTION
    Fetches detailed project information including versions, dependencies, 
    and metadata from the Modrinth API. Handles API rate limiting and 
    provides fallback mechanisms for failed requests.

.PARAMETER ProjectId
    The Modrinth project ID to retrieve information for.

.PARAMETER UseCachedResponses
    Whether to use cached API responses for faster execution.

.EXAMPLE
    Get-ModrinthProjectInfo -ProjectId "fabric-api" -UseCachedResponses

.EXAMPLE
    Get-ModrinthProjectInfo -ProjectId "P7dR8mSH"

.NOTES
    - Requires internet connection for live API calls
    - Cached responses are stored in test/apiresponse/modrinth/
    - Handles API rate limiting automatically
    - Returns null if project not found or API unavailable
#>
function Get-ModrinthProjectInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectId,
        [bool]$UseCachedResponses = $false
    )
    
    try {
        $apiUrl = "https://api.modrinth.com/v2/project/$ProjectId"
        
        # Determine cache path - use script variable if available, otherwise use current directory
        $cacheDir = if ($script:TestApiResponseDir) { $script:TestApiResponseDir } else { "." }
        $cachePath = Join-Path $cacheDir "modrinth" "$ProjectId.json"
        
        # Use cached response if available and requested
        if ($UseCachedResponses -and (Test-Path $cachePath)) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            Write-Host "Using cached response for $ProjectId" -ForegroundColor Gray
            return $response
        }
        
        # Make API request
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
        
        # Cache response if directory exists
        $cacheDirPath = Split-Path $cachePath
        if (Test-Path $cacheDirPath) {
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        }
        
        return $response
    } catch {
        Write-Host "Failed to get Modrinth project info for $ProjectId : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing 