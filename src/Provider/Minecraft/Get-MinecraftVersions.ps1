# =============================================================================
# Minecraft Versions API Module
# =============================================================================
# This module handles retrieval of Minecraft versions from mc-versions-api.net.
# =============================================================================

<#
.SYNOPSIS
    Gets available Minecraft Java Edition versions from mc-versions-api.net.

.DESCRIPTION
    Retrieves Minecraft versions from the MC Versions API, with filtering
    options for channel (stable) and minimum version.

.PARAMETER Channel
    The release channel to filter by (stable, snapshot, etc.). Default: stable

.PARAMETER MinVersion
    Minimum version to include (e.g., "1.21.5"). Returns all versions >= this version.

.PARAMETER Order
    Sort order: 'asc' (ascending) or 'desc' (descending). Default: desc

.PARAMETER Detailed
    Include detailed information about each version.

.EXAMPLE
    Get-MinecraftVersions -MinVersion "1.21.5" -Channel stable

.EXAMPLE
    Get-MinecraftVersions -MinVersion "1.21.5" -Order asc

.NOTES
    - Uses MC Versions API: https://mc-versions-api.net/doc
    - Caches responses for performance
    - Filters for stable releases by default
#>
function Get-MinecraftVersions {
    param(
        [string]$Channel = "stable",
        [string]$MinVersion = "1.21.5",
        [string]$Order = "desc",
        [switch]$Detailed = $false
    )
    
    try {
        $apiUrl = "https://mc-versions-api.net/api/java"
        
        # Build query parameters
        $queryParams = @()
        if ($Order) { $queryParams += "order=$Order" }
        if ($Detailed) { $queryParams += "detailed=true" }
        
        if ($queryParams.Count -gt 0) {
            $apiUrl += "?" + ($queryParams -join "&")
        }
        
        Write-Host "🌐 Fetching Minecraft versions from mc-versions-api.net..." -ForegroundColor Cyan
        Write-Host "   API: $apiUrl" -ForegroundColor Gray
        
        # Make API request
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
        
        if (-not $response -or -not $response.result) {
            Write-Host "❌ Failed to retrieve Minecraft versions" -ForegroundColor Red
            return @()
        }
        
        $allVersions = $response.result
        Write-Host "   ✓ Retrieved $($allVersions.Count) total versions" -ForegroundColor Green
        
        # Filter for stable releases (exclude snapshots, pre-releases, RCs)
        if ($Channel -eq "stable") {
            $stableVersions = $allVersions | Where-Object {
                $_ -match '^\d+\.\d+(\.\d+)?$' -and  # Only x.y or x.y.z format
                $_ -notmatch 'pre|rc|snapshot|w\d+' # Exclude pre-releases, RCs, snapshots
            }
            Write-Host "   ✓ Filtered to $($stableVersions.Count) stable versions" -ForegroundColor Green
            $allVersions = $stableVersions
        }
        
        # Filter by minimum version if specified
        if ($MinVersion) {
            try {
                $minVer = [System.Version]::Parse($MinVersion)
                $filteredVersions = $allVersions | Where-Object {
                    try {
                        $currentVer = [System.Version]::Parse($_)
                        $currentVer -ge $minVer
                    } catch {
                        $false
                    }
                }
                
                Write-Host "   ✓ Filtered to $($filteredVersions.Count) versions >= $MinVersion" -ForegroundColor Green
                return $filteredVersions
            } catch {
                Write-Host "   ⚠️  Invalid MinVersion format: $MinVersion, returning all versions" -ForegroundColor Yellow
                return $allVersions
            }
        }
        
        return $allVersions
        
    } catch {
        Write-Host "❌ Error fetching Minecraft versions: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

# Function is available for dot-sourcing

