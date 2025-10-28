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
        [bool]$UseCachedResponses = $false,
        [switch]$Quiet = $false
    )
    
    try {
        # Resolve slug to numeric ID if necessary
        $cfModId = $ModID
        if ($ModID -notmatch '^\d+$') {
            try {
                $resolved = Resolve-CurseForgeProjectId -Identifier $ModID -Quiet
                if ($resolved) { $cfModId = $resolved }
            } catch {}
        }

        $apiUrl = "https://api.curseforge.com/v1/mods/$cfModId/files/$FileID"
        
        # Determine cache path - use script variable if available, otherwise use current directory
        $cacheDir = if ($script:TestApiResponseDir) { $script:TestApiResponseDir } else { ".cache/apiresponse" }
    $cachePath = Join-Path $cacheDir "curseforge" "$cfModId-$FileID.json"
        
        # Use cached response if available and requested
        if ($UseCachedResponses -and (Test-Path $cachePath)) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            if (-not $Quiet) { Write-Host "Using cached response for CurseForge file $cfModId-$FileID" -ForegroundColor Gray }
            return $response
        }
        
        # Get API key from environment
        $apiKey = $env:CURSEFORGE_API_KEY
        if (-not $apiKey) {
            throw "CurseForge API key not found. Please set CURSEFORGE_API_KEY environment variable."
        }
        
        # Set up headers for CurseForge API
        $headers = @{
            "Accept" = "application/json"
            "x-api-key" = $apiKey
        }
        
        # Make API request
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers -TimeoutSec 30
        
        # Cache response if directory exists, create it if needed
        $cacheDirPath = Split-Path $cachePath
        if (-not (Test-Path $cacheDirPath)) {
            New-Item -ItemType Directory -Path $cacheDirPath -Force | Out-Null
        }
        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        
        return $response
    } catch {
        Write-Host "Failed to get CurseForge file info for $cfModId-$FileID : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing 