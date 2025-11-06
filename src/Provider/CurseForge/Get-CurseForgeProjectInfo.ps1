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
# Ensure dependent helpers are available when dot-sourced directly (outside Import-Modules)
try {
    if (-not (Get-Command Invoke-RestMethodWithRetry -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\..\..\Net\Invoke-RestMethodWithRetry.ps1"
    }
} catch { }

function Get-CurseForgeProjectInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectId,
        [bool]$UseCachedResponses = $false,
        [switch]$Quiet = $false
    )
    
    try {
        $apiUrl = "https://api.curseforge.com/v1/mods/$ProjectId"
        
        # Determine cache path - use script variable if available, otherwise use current directory
        $cacheDir = if ($script:TestApiResponseDir) { $script:TestApiResponseDir } else { ".cache/apiresponse" }
        $cachePath = Join-Path $cacheDir "curseforge" "$ProjectId.json"
        
        # Use cached response if available and requested
        if ($UseCachedResponses -and (Test-Path $cachePath)) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            if (-not $Quiet) { Write-Host "Using cached response for CurseForge project $ProjectId" -ForegroundColor Gray }
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
        
    # Make API request with retry/backoff
    $response = Invoke-RestMethodWithRetry -Uri $apiUrl -Method Get -Headers $headers -TimeoutSec 30
        
        # Cache response if directory exists, create it if needed
        $cacheDirPath = Split-Path $cachePath
        if (-not (Test-Path $cacheDirPath)) {
            New-Item -ItemType Directory -Path $cacheDirPath -Force | Out-Null
        }
        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        
        return $response
    } catch {
        Write-Host "Failed to get CurseForge project info for $ProjectId : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing 