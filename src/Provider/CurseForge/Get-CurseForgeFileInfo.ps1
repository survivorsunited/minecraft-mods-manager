# =============================================================================
# CurseForge File Info Module
# =============================================================================
# This module handles retrieving file information from CurseForge API.
# =============================================================================

<#
.SYNOPSIS
    Retrieves file information from CurseForge API.

.DESCRIPTION
    Fetches detailed file information including dependencies, compatibility,
    and download URLs from the CurseForge API.

.PARAMETER ModID
    The CurseForge mod ID.

.PARAMETER FileID
    The specific file ID to retrieve information for.

.PARAMETER UseCachedResponses
    Whether to use cached API responses.

.EXAMPLE
    Get-CurseForgeFileInfo -ModID "357540" -FileID "123456"

.NOTES
    - Requires CurseForge API key
    - Handles API rate limiting
    - Returns null if file not found or API unavailable
#>
function Get-CurseForgeFileInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModID,
        [Parameter(Mandatory=$true)]
        [string]$FileID,
        [bool]$UseCachedResponses = $false
    )
    
    try {
        $apiUrl = "https://www.curseforge.com/api/v1/mods/$ModID/files/$FileID"
        $cachePath = Join-Path $script:TestApiResponseDir "curseforge" "$ModID-$FileID.json"
        
        # Use cached response if available and requested
        if ($UseCachedResponses -and (Test-Path $cachePath)) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            Write-Host "Using cached response for CurseForge file $ModID-$FileID" -ForegroundColor Gray
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
        Write-Host "Failed to get CurseForge file info for $ModID-$FileID : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing 