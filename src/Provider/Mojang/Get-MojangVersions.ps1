# =============================================================================
# Mojang Version Manifest Module
# =============================================================================
# This module handles retrieval of Minecraft versions from Mojang's official API.
# =============================================================================

<#
.SYNOPSIS
    Gets available Minecraft Java Edition versions from Mojang's official API.

.DESCRIPTION
    Retrieves Minecraft versions from the official Mojang version manifest,
    with filtering options for release type and minimum version.

.PARAMETER MinVersion
    Minimum version to include (e.g., "1.21.5"). Returns all versions >= this version.

.PARAMETER IncludeSnapshots
    Include snapshot/pre-release versions. Default: false (release only)

.PARAMETER Order
    Sort order: 'asc' (ascending) or 'desc' (descending). Default: desc

.EXAMPLE
    Get-MojangVersions -MinVersion "1.21.5"

.EXAMPLE
    Get-MojangVersions -MinVersion "1.21.0" -IncludeSnapshots

.NOTES
    - Uses Mojang's official API: https://piston-meta.mojang.com/mc/game/version_manifest_v2.json
    - Returns version objects with id, type, url, and download info
#>
function Get-MojangVersions {
    param(
        [string]$MinVersion = "1.21.5",
        [switch]$IncludeSnapshots = $false,
        [string]$Order = "desc"
    )
    
    try {
        $apiUrl = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
        
        Write-Host "🌐 Fetching Minecraft versions from Mojang API..." -ForegroundColor Cyan
        Write-Host "   API: $apiUrl" -ForegroundColor Gray
        
        # Make API request
        $manifest = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
        
        if (-not $manifest -or -not $manifest.versions) {
            Write-Host "❌ Failed to retrieve Minecraft version manifest" -ForegroundColor Red
            return @()
        }
        
        Write-Host "   ✓ Retrieved $($manifest.versions.Count) total versions" -ForegroundColor Green
        Write-Host "   ✓ Latest release: $($manifest.latest.release)" -ForegroundColor Green
        Write-Host "   ✓ Latest snapshot: $($manifest.latest.snapshot)" -ForegroundColor Green
        
        # Filter for release versions (exclude snapshots, pre-releases, RCs)
        $filteredVersions = if ($IncludeSnapshots) {
            $manifest.versions
        } else {
            $manifest.versions | Where-Object {
                $_.type -eq "release"
            }
        }
        
        Write-Host "   ✓ Filtered to $($filteredVersions.Count) release versions" -ForegroundColor Green
        
        # Filter by minimum version if specified
        if ($MinVersion) {
            try {
                $minVer = [System.Version]::Parse($MinVersion)
                $versionObjects = $filteredVersions | Where-Object {
                    try {
                        $currentVer = [System.Version]::Parse($_.id)
                        $currentVer -ge $minVer
                    } catch {
                        $false
                    }
                }
                
                Write-Host "   ✓ Filtered to $($versionObjects.Count) versions >= $MinVersion" -ForegroundColor Green
                
                # Sort based on order parameter
                if ($Order -eq "asc") {
                    $versionObjects = $versionObjects | Sort-Object { [System.Version]$_.id }
                } else {
                    $versionObjects = $versionObjects | Sort-Object { [System.Version]$_.id } -Descending
                }
                
                return $versionObjects
            } catch {
                Write-Host "   ⚠️  Invalid MinVersion format: $MinVersion, returning all versions" -ForegroundColor Yellow
                return $filteredVersions
            }
        }
        
        return $filteredVersions
        
    } catch {
        Write-Host "❌ Error fetching Mojang versions: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

# Function is available for dot-sourcing

