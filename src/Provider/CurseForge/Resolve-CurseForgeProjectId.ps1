# =============================================================================
# CurseForge Project ID Resolver
# =============================================================================
# Resolves a CurseForge slug or URL to a numeric project ID using the
# CurseForge API search endpoint.
# =============================================================================

<#!
.SYNOPSIS
    Resolves a CurseForge project slug or URL to a numeric project ID.

.DESCRIPTION
    Accepts a CurseForge identifier which can be:
    - A numeric project ID (returned as-is)
    - A project slug (e.g. "basic-storage")
    - A full project URL (e.g. https://www.curseforge.com/minecraft/mc-mods/basic-storage)

    If a slug/URL is provided, this function queries the CurseForge API
    search endpoint to find the project and returns its numeric ID.

.PARAMETER Identifier
    CurseForge project identifier (ID, slug, or URL).

.EXAMPLE
    Resolve-CurseForgeProjectId -Identifier "basic-storage"

.EXAMPLE
    Resolve-CurseForgeProjectId -Identifier "https://www.curseforge.com/minecraft/mc-mods/basic-storage"

.NOTES
    - Requires CURSEFORGE_API_KEY environment variable
    - Uses gameId 432 for Minecraft
#>
function Resolve-CurseForgeProjectId {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identifier,
        [switch]$Quiet
    )

    try {
        # If it's already numeric, return as-is
        if ($Identifier -match '^[0-9]+$') {
            if (-not $Quiet) { Write-Host "  Using numeric CurseForge ID: $Identifier" -ForegroundColor Gray }
            return $Identifier
        }

        # Extract slug from URL or accept raw slug
        $slug = $Identifier
        if ($Identifier -match 'curseforge\.com/.+?/([^/]+)/([^/]+)/([^/]+)$') {
            # General pattern, last segment is slug
            $slug = $matches[3]
        } elseif ($Identifier -match 'curseforge\.com/.+/([^/]+)$') {
            $slug = $matches[1]
        } elseif ($Identifier -match '^https?://') {
            # Unknown URL pattern
            throw "Unsupported CurseForge URL format: $Identifier"
        }

        if (-not $slug -or $slug.Trim() -eq '') {
            throw "Unable to determine CurseForge slug from identifier: $Identifier"
        }

        # Prepare API request
        $apiKey = $env:CURSEFORGE_API_KEY
        if (-not $apiKey) {
            throw "CurseForge API key not found. Please set CURSEFORGE_API_KEY environment variable."
        }

        $headers = @{
            "Accept" = "application/json"
            "x-api-key" = $apiKey
        }

    # Use search endpoint filtered by gameId and searchFilter=slug
    $encoded = [System.Web.HttpUtility]::UrlEncode($slug)
    $searchUrl = "https://api.curseforge.com/v1/mods/search?gameId=432&searchFilter=$encoded"

        $resp = Invoke-RestMethod -Uri $searchUrl -Method Get -Headers $headers -TimeoutSec 30 -ErrorAction Stop
        if (-not $resp -or -not $resp.data -or $resp.data.Count -eq 0) {
            throw "No CurseForge project found for slug '$slug'"
        }

        # Prefer exact slug match, otherwise first result
        $match = $resp.data | Where-Object { $_.slug -eq $slug } | Select-Object -First 1
        if (-not $match) { $match = $resp.data | Select-Object -First 1 }

        if (-not $match -or -not $match.id) {
            throw "Failed to resolve numeric ID for slug '$slug'"
        }

        $id = [string]$match.id
        if (-not $Quiet) { Write-Host "  Resolved CurseForge slug '$slug' -> ID $id" -ForegroundColor Gray }
        return $id
    } catch {
        if (-not $Quiet) { Write-Host "  Warning: Could not resolve CurseForge ID: $($_.Exception.Message)" -ForegroundColor Yellow }
        return $null
    }
}

# Function is available for dot-sourcing 
