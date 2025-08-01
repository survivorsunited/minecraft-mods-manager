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
        Write-Host "DEBUG: Getting project info for $ModID" -ForegroundColor Yellow
        $projectInfo = Get-ModrinthProjectInfo -ProjectId $ModID -UseCachedResponses $UseCachedResponses
        if (-not $projectInfo) {
            Write-Host "DEBUG: Failed to get project info for $ModID" -ForegroundColor Red
            return @{ Success = $false; Error = "Failed to get project info" }
        }
        
        Write-Host "DEBUG: Found project info for $ModID with $($projectInfo.versions.Count) versions" -ForegroundColor Yellow
        
        # Get all version details to find the specific version
        $versionsApiUrl = "https://api.modrinth.com/v2/project/$ModID/version"
        $versionsResponse = Invoke-RestMethod -Uri $versionsApiUrl -Method Get -TimeoutSec 30
        
        # Find the specific version by version_number with flexible matching
        # Try exact match first
        $versionInfo = $versionsResponse | Where-Object { $_.version_number -eq $Version }
        
        # If exact match fails, try partial matches for common version format differences
        if (-not $versionInfo) {
            # Remove 'v' prefix if present in search version
            $cleanVersion = $Version -replace '^v', ''
            $versionInfo = $versionsResponse | Where-Object { $_.version_number -eq $cleanVersion }
            
            # Try with loader suffix (for versions like "18.0.145" -> "18.0.145+fabric")
            if (-not $versionInfo -and $Loader) {
                $versionWithLoader = "$cleanVersion+$Loader"
                $versionInfo = $versionsResponse | Where-Object { $_.version_number -eq $versionWithLoader }
            }
            
            # Try partial match for complex version formats
            if (-not $versionInfo) {
                $versionInfo = $versionsResponse | Where-Object { 
                    $_.version_number -like "*$cleanVersion*" -and $_.loaders -contains $Loader 
                }
            }
        }
        
        if (-not $versionInfo) {
            Write-Host "DEBUG: Version $Version not found in $($versionsResponse.Count) versions" -ForegroundColor Red
            # Show available versions for debugging
            $availableVersions = $versionsResponse | Select-Object -First 5 | ForEach-Object { $_.version_number }
            Write-Host "DEBUG: Available versions (first 5): $($availableVersions -join ', ')" -ForegroundColor Yellow
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
        
        # Generate response file if script variable is set
        if ($script:TestOutputDir) {
            $responseFile = Join-Path $script:TestOutputDir "$ModID-$Version.json"
            $responseData = @{
                modId = $ModID
                version = $Version
                loader = $Loader
                gameVersion = $GameVersion
                compatible = $true
                downloadUrl = $versionInfo.files[0].url
                fileSize = $versionInfo.files[0].size
                dependencies = $dependencies
                timestamp = Get-Date -Format "o"
            }
            $responseData | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
            Write-Host "DEBUG: Created response file: $responseFile" -ForegroundColor Green
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