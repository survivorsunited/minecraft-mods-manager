# =============================================================================
# CurseForge Project Info Module
# =============================================================================
# This module handles retrieving project information from CurseForge API.
# =============================================================================

<#
.SYNOPSIS
    Retrieves comprehensive project information from CurseForge API.

.DESCRIPTION
    Fetches detailed project information including versions, dependencies, 
    and metadata from the CurseForge API. Handles API rate limiting and 
    provides fallback mechanisms for failed requests.

.PARAMETER ProjectId
    The CurseForge project ID to retrieve information for.

.PARAMETER UseCachedResponses
    Whether to use cached API responses for faster execution.

.EXAMPLE
    Get-CurseForgeProjectInfo -ProjectId "357540" -UseCachedResponses

.NOTES
    - Requires CurseForge API key
    - Cached responses are stored in test/apiresponse/curseforge/
    - Handles API rate limiting automatically
    - Returns null if project not found or API unavailable
#>
function Get-CurseForgeProjectInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectId,
        [bool]$UseCachedResponses = $false
    )
    
    try {
        $apiUrl = "https://www.curseforge.com/api/v1/mods/$ProjectId"
        $cachePath = Join-Path $script:TestApiResponseDir "curseforge" "$ProjectId.json"
        
        # Use cached response if available and requested
        if ($UseCachedResponses -and (Test-Path $cachePath)) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            Write-Host "Using cached response for CurseForge project $ProjectId" -ForegroundColor Gray
            return $response
        }
        
        # Set up headers for CurseForge API
        $headers = @{
            "Accept" = "application/json"
            "x-api-key" = $CurseForgeApiKey
        }
        
        # Make API request
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers -TimeoutSec 30
        
        # Cache response if directory exists
        if (Test-Path (Split-Path $cachePath)) {
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        }
        
        return $response
    } catch {
        Write-Host "Failed to get CurseForge project info for $ProjectId : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing 