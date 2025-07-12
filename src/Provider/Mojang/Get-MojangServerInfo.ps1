# =============================================================================
# Mojang Server Info Module
# =============================================================================
# This module handles retrieving server information from Mojang API.
# =============================================================================

<#
.SYNOPSIS
    Retrieves server information from Mojang API.

.DESCRIPTION
    Fetches server version information and download URLs from the Mojang API.
    Handles version metadata and server file downloads.

.PARAMETER GameVersion
    The Minecraft version to get server info for.

.PARAMETER UseCachedResponses
    Whether to use cached API responses.

.EXAMPLE
    Get-MojangServerInfo -GameVersion "1.21.5"

.NOTES
    - Uses Mojang launcher metadata API
    - Handles API rate limiting
    - Returns null if version not found or API unavailable
#>
function Get-MojangServerInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [bool]$UseCachedResponses = $false
    )
    
    try {
        $apiUrl = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        $cachePath = Join-Path $script:TestApiResponseDir "mojang" "version-manifest.json"
        
        # Use cached response if available and requested
        if ($UseCachedResponses -and (Test-Path $cachePath)) {
            $manifest = Get-Content $cachePath | ConvertFrom-Json
            Write-Host "Using cached Mojang version manifest" -ForegroundColor Gray
        } else {
            # Get version manifest
            $manifest = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
            
            # Cache response if directory exists
            if (Test-Path (Split-Path $cachePath)) {
                $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
            }
        }
        
        # Find the specific version
        $versionInfo = $manifest.versions | Where-Object { $_.id -eq $GameVersion }
        if (-not $versionInfo) {
            Write-Host "Version $GameVersion not found in Mojang manifest" -ForegroundColor Red
            return $null
        }
        
        # Get detailed version info
        $versionUrl = $versionInfo.url
        $versionCachePath = Join-Path $script:TestApiResponseDir "mojang" "$GameVersion.json"
        
        if ($UseCachedResponses -and (Test-Path $versionCachePath)) {
            $detailedInfo = Get-Content $versionCachePath | ConvertFrom-Json
            Write-Host "Using cached Mojang version info for $GameVersion" -ForegroundColor Gray
        } else {
            $detailedInfo = Invoke-RestMethod -Uri $versionUrl -Method Get -TimeoutSec 30
            
            # Cache response if directory exists
            if (Test-Path (Split-Path $versionCachePath)) {
                $detailedInfo | ConvertTo-Json -Depth 10 | Out-File -FilePath $versionCachePath -Encoding UTF8
            }
        }
        
        return $detailedInfo
        
    } catch {
        Write-Host "Failed to get Mojang server info for $GameVersion : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing 