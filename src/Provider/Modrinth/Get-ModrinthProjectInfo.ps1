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
    - Cached responses are stored in .cache/apiresponse/modrinth/
    - Handles API rate limiting automatically
    - Returns null if project not found or API unavailable
#>
function Get-ModrinthProjectInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectId,
        [bool]$UseCachedResponses = $false,
        [switch]$Quiet = $false
    )
    
    try {
        $apiUrl = "https://api.modrinth.com/v2/project/$ProjectId"
        
        # Determine cache path - use script variable if available, otherwise use .cache/apiresponse
        $cacheDir = if ($script:TestApiResponseDir) { $script:TestApiResponseDir } else { ".cache/apiresponse" }
        $cachePath = Join-Path $cacheDir "modrinth" "$ProjectId.json"
        
        # Use cached response if available and requested, or if cache file exists and is recent
        if (($UseCachedResponses -and (Test-Path $cachePath)) -or 
            ((Test-Path $cachePath) -and ((Get-Item $cachePath).LastWriteTime -gt (Get-Date).AddMinutes(-5)))) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            if (-not $Quiet) { Write-Host "Using cached response for $ProjectId" -ForegroundColor Gray }
            return $response
        }
        
    # Make API request with retry/backoff
    $response = Invoke-RestMethodWithRetry -Uri $apiUrl -Method Get -TimeoutSec 30
        
        # Cache response if directory exists, create it if needed
        $cacheDirPath = Split-Path $cachePath
        if (-not (Test-Path $cacheDirPath)) {
            New-Item -ItemType Directory -Path $cacheDirPath -Force | Out-Null
        }
        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        
        return $response
    } catch {
        Write-Host "Failed to get Modrinth project info for $ProjectId : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing 