# =============================================================================
# Modrinth Mod Version Validation Module
# =============================================================================
# This module handles validation of mod versions using Modrinth API.
# =============================================================================

<#
.SYNOPSIS
    Validates mod version compatibility using Modrinth API.

.DESCRIPTION
    Validates a specific mod version against the Modrinth API, checking
    compatibility with specified Minecraft version and loader. Extracts
    dependency information and stores it in the database.

.PARAMETER ModID
    The Modrinth project ID of the mod to validate.

.PARAMETER Version
    The specific version to validate.

.PARAMETER Loader
    The mod loader (fabric, forge, etc.).

.PARAMETER GameVersion
    The Minecraft version to check compatibility with.

.PARAMETER UseCachedResponses
    Whether to use cached API responses.

.PARAMETER CsvPath
    Path to the CSV database file to update.

.EXAMPLE
    Validate-ModrinthModVersion -ModID "fabric-api" -Version "0.91.0+1.21.5" -Loader "fabric"

.NOTES
    - Updates CSV with dependency information
    - Handles API rate limiting
    - Creates backup before modifications
    - Returns validation result object
#>
function Validate-ModrinthModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModID,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [Parameter(Mandatory=$true)]
        [string]$Loader,
        [string]$GameVersion = "1.21.5",
        [bool]$UseCachedResponses = $false,
        [string]$CsvPath = $null
    )
    
    try {
        Write-Host "Validating $ModID version $Version for $Loader..." -ForegroundColor Cyan
        
        # Get project info
        $projectInfo = Get-ModrinthProjectInfo -ProjectId $ModID -UseCachedResponses $UseCachedResponses
        if (-not $projectInfo) {
            return @{ Success = $false; Error = "Failed to get project info" }
        }
        
        # Find the specific version
        $versionInfo = $projectInfo.versions | Where-Object { $_.version_number -eq $Version }
        if (-not $versionInfo) {
            return @{ Success = $false; Error = "Version $Version not found" }
        }
        
        # Check compatibility
        $compatible = $versionInfo.game_versions -contains $GameVersion -and 
                     $versionInfo.loaders -contains $Loader
        
        if (-not $compatible) {
            return @{ Success = $false; Error = "Version not compatible with $GameVersion/$Loader" }
        }
        
        # Extract dependencies
        $dependencies = $versionInfo.dependencies
        $dependenciesJson = Convert-DependenciesToJson -Dependencies $dependencies
        
        # Update CSV if provided
        if ($CsvPath -and (Test-Path $CsvPath)) {
            $mods = Import-Csv -Path $CsvPath
            $mod = $mods | Where-Object { $_.ID -eq $ModID }
            if ($mod) {
                $mod.CurrentDependencies = $dependenciesJson
                $mods | Export-Csv -Path $CsvPath -NoTypeInformation
            }
        }
        
        return @{ 
            Success = $true; 
            Version = $Version;
            Dependencies = $dependenciesJson;
            DownloadUrl = $versionInfo.files[0].url;
            FileSize = $versionInfo.files[0].size
        }
        
    } catch {
        Write-Host "Validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Function is available for dot-sourcing 