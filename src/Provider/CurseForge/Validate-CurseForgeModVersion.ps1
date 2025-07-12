# =============================================================================
# CurseForge Mod Version Validation Module
# =============================================================================
# This module handles validation of mod versions using CurseForge API.
# =============================================================================

<#
.SYNOPSIS
    Validates CurseForge mod version using CurseForge API.

.DESCRIPTION
    Validates a specific CurseForge mod version, checking compatibility
    and retrieving file information. Handles CurseForge-specific API
    requirements and rate limiting.

.PARAMETER ModID
    The CurseForge mod ID to validate.

.PARAMETER FileID
    The specific file ID to validate.

.PARAMETER UseCachedResponses
    Whether to use cached API responses.

.EXAMPLE
    Validate-CurseForgeModVersion -ModID "357540" -FileID "123456"

.NOTES
    - Requires CurseForge API key
    - Handles CurseForge-specific rate limiting
    - Returns file information and compatibility data
#>
function Validate-CurseForgeModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModID,
        [Parameter(Mandatory=$true)]
        [string]$FileID,
        [bool]$UseCachedResponses = $false
    )
    
    try {
        Write-Host "Validating CurseForge mod $ModID file $FileID..." -ForegroundColor Cyan
        
        # Get file info
        $fileInfo = Get-CurseForgeFileInfo -ModID $ModID -FileID $FileID -UseCachedResponses $UseCachedResponses
        if (-not $fileInfo) {
            return @{ Success = $false; Error = "Failed to get file info" }
        }
        
        # Check compatibility
        $compatible = $fileInfo.gameVersions -contains $GameVersion -and 
                     $fileInfo.modLoaders -contains $Loader
        
        if (-not $compatible) {
            return @{ Success = $false; Error = "File not compatible with $GameVersion/$Loader" }
        }
        
        # Extract dependencies
        $dependencies = $fileInfo.dependencies
        $dependenciesJson = Convert-DependenciesToJson -Dependencies $dependencies
        
        return @{ 
            Success = $true; 
            Version = $fileInfo.displayName;
            Dependencies = $dependenciesJson;
            DownloadUrl = $fileInfo.downloadUrl;
            FileSize = $fileInfo.fileLength
        }
        
    } catch {
        Write-Host "CurseForge validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Function is available for dot-sourcing 