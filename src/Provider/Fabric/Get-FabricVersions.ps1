# =============================================================================
# Fabric Meta API Module
# =============================================================================
# This module handles retrieval of Fabric loader versions from meta.fabricmc.net.
# =============================================================================

<#
.SYNOPSIS
    Gets available Fabric loader versions from meta.fabricmc.net.

.DESCRIPTION
    Retrieves Fabric loader versions from the Fabric Meta API for specific
    Minecraft game versions.

.PARAMETER GameVersion
    Minecraft game version to get Fabric loaders for (e.g., "1.21.5").

.PARAMETER StableOnly
    Only return stable loader versions (exclude beta/unstable).

.EXAMPLE
    Get-FabricVersions -GameVersion "1.21.5"

.EXAMPLE
    Get-FabricVersions -GameVersion "1.21.6" -StableOnly

.NOTES
    - Uses Fabric Meta API: https://meta.fabricmc.net/
    - Documentation: https://github.com/FabricMC/fabric-meta
    - Returns loader version info with mainClass for server
#>
function Get-FabricVersions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [switch]$StableOnly = $false
    )
    
    try {
        # Fabric Meta API endpoint for loader versions
        $apiUrl = "https://meta.fabricmc.net/v2/versions/loader/$GameVersion"
        
        Write-Host "   🔷 Fetching Fabric loader versions for $GameVersion..." -ForegroundColor Cyan
        
        # Make API request
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
        
        if (-not $response -or $response.Count -eq 0) {
            Write-Host "      ⚠️  No Fabric loaders found for $GameVersion" -ForegroundColor Yellow
            return $null
        }
        
        # Filter for stable versions if requested
        if ($StableOnly) {
            $stableLoaders = $response | Where-Object { 
                $_.loader.stable -eq $true 
            }
            
            if ($stableLoaders -and $stableLoaders.Count -gt 0) {
                # Get the latest stable loader
                $latestStable = $stableLoaders[0]
                Write-Host "      ✓ Found stable Fabric loader: $($latestStable.loader.version)" -ForegroundColor Green
                return $latestStable
            } else {
                Write-Host "      ⚠️  No stable Fabric loaders found, using latest" -ForegroundColor Yellow
            }
        }
        
        # Return latest loader (first in the array)
        $latestLoader = $response[0]
        Write-Host "      ✓ Found Fabric loader: $($latestLoader.loader.version)" -ForegroundColor Green
        return $latestLoader
        
    } catch {
        Write-Host "      ❌ Error fetching Fabric versions: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing

