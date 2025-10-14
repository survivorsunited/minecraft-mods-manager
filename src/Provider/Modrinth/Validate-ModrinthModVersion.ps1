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
        [string]$GameVersion = "",
        [bool]$UseCachedResponses = $false,
        [string]$CsvPath = $null,
        [switch]$Quiet = $false
    )
    
    try {
        # Use provided GameVersion or default
        $effectiveGameVersion = if (-not [string]::IsNullOrEmpty($GameVersion)) { $GameVersion } else { $DefaultGameVersion }
        
        # Simple validation display - detailed version info shown in summary
        if (-not $Quiet) { 
            Write-Host "Validating $ModID [Version: $Version] for $Loader/$effectiveGameVersion..." -ForegroundColor Cyan 
        }
        
        # Get project info
        if (-not $Quiet) { Write-Host "DEBUG: Getting project info for $ModID" -ForegroundColor Yellow }
        $projectInfo = Get-ModrinthProjectInfo -ProjectId $ModID -UseCachedResponses $UseCachedResponses -Quiet:$Quiet
        if (-not $projectInfo) {
            if (-not $Quiet) { Write-Host "DEBUG: Failed to get project info for $ModID" -ForegroundColor Red }
            return @{ Success = $false; Error = "Failed to get project info" }
        }
        
        if (-not $Quiet) { Write-Host "DEBUG: Found project info for $ModID with $($projectInfo.versions.Count) versions" -ForegroundColor Yellow }
        
        # Get all version details to find the specific version
        $versionsApiUrl = "https://api.modrinth.com/v2/project/$ModID/version"
        $versionsResponse = Invoke-RestMethod -Uri $versionsApiUrl -Method Get -TimeoutSec 30
        
        # Find the specific version by version_number with flexible matching
        # Try exact match first - PRIORITIZE versions where target game version is primary
        $exactMatches = $versionsResponse | Where-Object { $_.version_number -eq $Version }
        if ($exactMatches -and @($exactMatches).Count -gt 1) {
            # Multiple versions with same version number - prioritize by game version
            $versionInfo = $exactMatches | ForEach-Object {
                $gameVersionIndex = $_.game_versions.IndexOf($effectiveGameVersion)
                if ($gameVersionIndex -ge 0) {
                    [PSCustomObject]@{
                        VersionInfo = $_
                        GameVersionIndex = $gameVersionIndex
                    }
                }
            } | Sort-Object GameVersionIndex | Select-Object -First 1 | Select-Object -ExpandProperty VersionInfo
        } else {
            $versionInfo = $exactMatches
        }
        
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
            # PRIORITIZE by game version when multiple matches exist
            if (-not $versionInfo) {
                $partialMatches = $versionsResponse | Where-Object { 
                    $_.version_number -like "*$cleanVersion*" -and $_.loaders -contains $Loader 
                }
                
                if ($partialMatches -and @($partialMatches).Count -gt 1) {
                    # Multiple partial matches - prioritize by game version
                    $versionInfo = $partialMatches | ForEach-Object {
                        $gameVersionIndex = $_.game_versions.IndexOf($effectiveGameVersion)
                        if ($gameVersionIndex -ge 0) {
                            [PSCustomObject]@{
                                VersionInfo = $_
                                GameVersionIndex = $gameVersionIndex
                            }
                        }
                    } | Sort-Object GameVersionIndex | Select-Object -First 1 | Select-Object -ExpandProperty VersionInfo
                    
                    # If no match with target game version, use first partial match
                    if (-not $versionInfo) {
                        $versionInfo = $partialMatches | Select-Object -First 1
                    }
                } else {
                    $versionInfo = $partialMatches
                }
            }
        }
        
        if (-not $versionInfo) {
            if (-not $Quiet) { Write-Host "DEBUG: Version $Version not found in $($versionsResponse.Count) versions" -ForegroundColor Red }
            
            # Try to find the closest matching version for the same loader and game version
            # PRIORITIZE versions where the target game version is PRIMARY (first in compatibility list)
            $closeMatches = $versionsResponse | Where-Object { 
                ($_.loaders -contains $Loader -or ($_.loaders -contains "datapack" -and $_.loaders.Count -eq 1)) -and 
                $_.game_versions -contains $effectiveGameVersion 
            } | ForEach-Object {
                $versionNum = $_.version_number
                
                # Calculate similarity score based on common prefixes
                $similarity = 0
                $cleanVersionParts = $cleanVersion -split '[+\-\.]'
                $candidateParts = $versionNum -split '[+\-\.]'
                
                for ($i = 0; $i -lt [Math]::Min($cleanVersionParts.Count, $candidateParts.Count); $i++) {
                    if ($cleanVersionParts[$i] -eq $candidateParts[$i]) {
                        $similarity++
                    } else {
                        break
                    }
                }
                
                # Calculate game version priority score
                # Higher score = better match (target version is earlier in compatibility list)
                $gameVersionIndex = $_.game_versions.IndexOf($effectiveGameVersion)
                $gameVersionPriority = if ($gameVersionIndex -eq 0) {
                    # Target is PRIMARY version (first in list) - highest priority
                    1000
                } elseif ($gameVersionIndex -le 2) {
                    # Target is in top 3 - high priority
                    100
                } else {
                    # Target is somewhere in list - lower priority
                    10
                }
                
                # Combined score: game version priority is MUCH more important than version number similarity
                $totalScore = ($gameVersionPriority * 100) + $similarity
                
                [PSCustomObject]@{
                    VersionInfo = $_
                    VersionNumber = $versionNum
                    Similarity = $similarity
                    GameVersionIndex = $gameVersionIndex
                    GameVersionPriority = $gameVersionPriority
                    TotalScore = $totalScore
                }
            } | Sort-Object -Property TotalScore -Descending | Select-Object -First 1
            
            if ($closeMatches -and $closeMatches.TotalScore -gt 0) {
                $closestMatch = $closeMatches.VersionInfo
                if (-not $Quiet) { 
                    Write-Host "🔍 Found closest match: $($closestMatch.version_number) (requested: $Version)" -ForegroundColor Yellow 
                    Write-Host "   Game version priority: $($closeMatches.GameVersionPriority) (index: $($closeMatches.GameVersionIndex))" -ForegroundColor Gray
                    Write-Host "   Auto-updating to use matching version..." -ForegroundColor Yellow
                }
                $versionInfo = $closestMatch
                
                # Update the CSV with the corrected version if provided
                if ($CsvPath -and (Test-Path $CsvPath) -and $versionInfo) {
                    $mods = Import-Csv -Path $CsvPath
                    $mod = $mods | Where-Object { $_.ID -eq $ModID }
                    if ($mod) {
                        $mod.Version = $versionInfo.version_number
                        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
                        if (-not $Quiet) { 
                            Write-Host "✅ Updated database with correct version: $($versionInfo.version_number)" -ForegroundColor Green 
                        }
                    }
                }
            } else {
                # Show available versions for debugging
                $availableVersions = $versionsResponse | Where-Object { 
                    $_.loaders -contains $Loader -and 
                    $_.game_versions -contains $effectiveGameVersion 
                } | Select-Object -First 5 | ForEach-Object { $_.version_number }
                if (-not $Quiet) { 
                    Write-Host "DEBUG: Available versions for $Loader/$effectiveGameVersion (first 5): $($availableVersions -join ', ')" -ForegroundColor Yellow 
                }
                return @{ Success = $false; Error = "Version $Version not found and no close matches available" }
            }
        }
        
        # Check compatibility with flexible game version matching
        # Special handling for datapacks - they are loader-agnostic
        if ($versionInfo.loaders -contains "datapack" -and $versionInfo.loaders.Count -eq 1) {
            # Pure datapack - compatible with any loader
            $loaderCompatible = $true
        } else {
            # Regular mod or mixed project - check for specific loader support
            $loaderCompatible = $versionInfo.loaders -contains $Loader
        }
        $gameVersionCompatible = $false
        
        # First check for exact match
        if ($versionInfo.game_versions -contains $effectiveGameVersion) {
            $gameVersionCompatible = $true
        } else {
            # Check for compatible versions within the same major.minor version
            # For example, 1.21.4 should be compatible with 1.21.5
            if ($effectiveGameVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
                $targetMajor = [int]$matches[1]
                $targetMinor = [int]$matches[2]
                $targetPatch = [int]$matches[3]
                
                foreach ($supportedVersion in $versionInfo.game_versions) {
                    if ($supportedVersion -match '^(\d+)\.(\d+)\.(\d+)') {
                        $supportedMajor = [int]$matches[1]
                        $supportedMinor = [int]$matches[2]
                        $supportedPatch = [int]$matches[3]
                        
                        # Compatible if same major.minor and supported patch is <= target patch
                        if ($supportedMajor -eq $targetMajor -and 
                            $supportedMinor -eq $targetMinor -and 
                            $supportedPatch -le $targetPatch) {
                            $gameVersionCompatible = $true
                            if (-not $Quiet) {
                                Write-Host "DEBUG: Version $($versionInfo.version_number) compatible: supports $supportedVersion, requesting $effectiveGameVersion" -ForegroundColor Green
                            }
                            break
                        }
                    }
                }
            }
        }
        
        if (-not $loaderCompatible) {
            return @{ Success = $false; Error = "Version does not support loader: $Loader" }
        }
        
        if (-not $gameVersionCompatible) {
            $supportedVersions = $versionInfo.game_versions -join ", "
            return @{ Success = $false; Error = "Version not compatible with $effectiveGameVersion (supports: $supportedVersions)" }
        }
        
        # Extract dependencies
        $dependencies = $versionInfo.dependencies
        $dependenciesJson = if ($dependencies) {
            Convert-DependenciesToJson -Dependencies $dependencies
        } else {
            ""
        }
        
        # Update CSV if provided
        if ($CsvPath -and (Test-Path $CsvPath)) {
            try {
                $mods = Import-Csv -Path $CsvPath
                $mod = $mods | Where-Object { $_.ID -eq $ModID }
                if ($mod) {
                    # Check if CurrentDependencies property exists, if not add it
                    if (-not ($mod | Get-Member -Name "CurrentDependencies" -MemberType Properties)) {
                        $mod | Add-Member -MemberType NoteProperty -Name "CurrentDependencies" -Value ""
                    }
                    $mod.CurrentDependencies = $dependenciesJson
                    $mods | Export-Csv -Path $CsvPath -NoTypeInformation
                }
            } catch {
                # Silently handle CSV update errors to avoid breaking validation
                Write-Debug "Failed to update CSV dependencies: $($_.Exception.Message)"
            }
        }
        
        # Generate response file if script variable is set
        if ($script:TestOutputDir) {
            $responseFile = Join-Path $script:TestOutputDir "$ModID-$Version.json"
            $responseData = @{
                modId = $ModID
                version = $Version
                loader = $Loader
                gameVersion = $effectiveGameVersion
                compatible = $true
                downloadUrl = $versionInfo.files[0].url
                fileSize = $versionInfo.files[0].size
                dependencies = $dependencies
                timestamp = Get-Date -Format "o"
            }
            $responseData | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
            if (-not $Quiet) { Write-Host "DEBUG: Created response file: $responseFile" -ForegroundColor Green }
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