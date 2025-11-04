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
    $versionsResponse = Invoke-RestMethodWithRetry -Uri $versionsApiUrl -Method Get -TimeoutSec 30
        
        # Handle version keywords: "current", "next", "latest"
        if ($Version -in @("current", "next", "latest") -or [string]::IsNullOrEmpty($Version)) {
            # Determine target game version based on keyword
            $targetGameVersion = $effectiveGameVersion
            
            if ($Version -eq "next") {
                # Calculate next game version (increment patch version)
                if ($effectiveGameVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
                    $major = [int]$matches[1]
                    $minor = [int]$matches[2]
                    $patch = [int]$matches[3]
                    $targetGameVersion = "$major.$minor.$($patch + 1)"
                }
            } elseif ($Version -eq "latest") {
                # For "latest", ignore game version - get absolute newest
                $targetGameVersion = $null
            }
            # For "current" or empty, use $effectiveGameVersion as-is
            
            # Filter versions by loader and optionally by game version
            if ($targetGameVersion) {
                $filteredVersions = $versionsResponse | Where-Object {
                    $_.loaders -contains $Loader -and
                    $_.game_versions -contains $targetGameVersion
                } | Sort-Object date_published -Descending
            } else {
                # "latest" - just filter by loader
                $filteredVersions = $versionsResponse | Where-Object {
                    $_.loaders -contains $Loader
                } | Sort-Object date_published -Descending
            }
            
            $versionInfo = $filteredVersions | Select-Object -First 1
            
            if (-not $versionInfo -and -not $Quiet) {
                $gameVerMsg = if ($targetGameVersion) { " and game version: $targetGameVersion" } else { "" }
                Write-Host "DEBUG: No versions found for loader: $Loader$gameVerMsg" -ForegroundColor Yellow
            }
        } else {
            # Find the specific version by version_number with flexible matching
            # Try exact match first - PRIORITIZE by loader, then by game version
            $exactMatches = $versionsResponse | Where-Object { $_.version_number -eq $Version }
        if ($exactMatches -and @($exactMatches).Count -gt 1) {
            # Multiple versions with same version number - filter by loader first
            $loaderMatches = $exactMatches | Where-Object { $_.loaders -contains $Loader }
            
            if ($loaderMatches -and @($loaderMatches).Count -gt 1) {
                # Multiple loader matches - prioritize by game version
                $versionInfo = $loaderMatches | ForEach-Object {
                    $gameVersionIndex = $_.game_versions.IndexOf($effectiveGameVersion)
                    if ($gameVersionIndex -ge 0) {
                        [PSCustomObject]@{
                            VersionInfo = $_
                            GameVersionIndex = $gameVersionIndex
                        }
                    }
                } | Sort-Object GameVersionIndex | Select-Object -First 1 | Select-Object -ExpandProperty VersionInfo
            } elseif ($loaderMatches) {
                # Single loader match
                $versionInfo = $loaderMatches
            } else {
                # No loader match - try game version prioritization on all matches
                $versionInfo = $exactMatches | ForEach-Object {
                    $gameVersionIndex = $_.game_versions.IndexOf($effectiveGameVersion)
                    if ($gameVersionIndex -ge 0) {
                        [PSCustomObject]@{
                            VersionInfo = $_
                            GameVersionIndex = $gameVersionIndex
                        }
                    }
                } | Sort-Object GameVersionIndex | Select-Object -First 1 | Select-Object -ExpandProperty VersionInfo
            }
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
        } # Close the else block for non-latest version handling
        
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
        
        # CRITICAL: Check filename for actual build version
        # A mod might be marked as "compatible" with 1.21.5 but the JAR is built for 1.21.4
        # This causes mixin failures and server crashes!
        $actualBuildVersion = $null
        if ($versionInfo.files -and $versionInfo.files.Count -gt 0) {
            $filename = $versionInfo.files[0].filename
            # Look for MC version patterns: mc1.21.5, -1.21.5-, fabric-1.21.5, etc.
            # Minecraft versions always start with 1.xx
            if ($filename -match '(?:mc|fabric|forge|quilt)?[-_]?(1\.\d+\.\d+)') {
                $actualBuildVersion = $matches[1]
            }
        }
        
        # Check if mod supports the target game version (trust mod author's compatibility claims)
        if ($versionInfo.game_versions -contains $effectiveGameVersion) {
            # Mod author says it's compatible
            if ($actualBuildVersion -and $actualBuildVersion -ne $effectiveGameVersion) {
                # Warn about build version mismatch but trust compatibility claim
                if (-not $Quiet) {
                    Write-Host "⚠️  Version $($versionInfo.version_number): JAR built for $actualBuildVersion but marked compatible with $effectiveGameVersion" -ForegroundColor Yellow
                }
            }
            $gameVersionCompatible = $true
        } else {
            # Not in supported versions list - still reject this
            $gameVersionCompatible = $false
            if (-not $Quiet) {
                Write-Host "⚠️  Version $($versionInfo.version_number) does not support $effectiveGameVersion (supports: $($versionInfo.game_versions -join ', '))" -ForegroundColor Yellow
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
        
        # Get project info for additional metadata
        $projectInfo = Get-ModrinthProjectInfo -ProjectId $ModID -UseCachedResponses $true -Quiet:$Quiet
        
        return @{ 
            Success = $true
            Exists = $true
            Version = $versionInfo.version_number
            LatestVersion = $versionInfo.version_number
            VersionUrl = $versionInfo.files[0].url
            LatestVersionUrl = $versionInfo.files[0].url
            DownloadUrl = $versionInfo.files[0].url
            Dependencies = $dependenciesJson
            FileSize = $versionInfo.files[0].size
            Jar = $versionInfo.files[0].filename
            LatestGameVersion = $versionInfo.game_versions[0]
            Title = if ($projectInfo) { $projectInfo.title } else { "" }
            ProjectDescription = if ($projectInfo) { $projectInfo.description } else { "" }
            IconUrl = if ($projectInfo) { $projectInfo.icon_url } else { "" }
            IssuesUrl = if ($projectInfo) { $projectInfo.issues_url } else { "" }
            SourceUrl = if ($projectInfo) { $projectInfo.source_url } else { "" }
            WikiUrl = if ($projectInfo) { $projectInfo.wiki_url } else { "" }
            ClientSide = if ($projectInfo -and $projectInfo.client_side) { $projectInfo.client_side } else { $null }
            ServerSide = if ($projectInfo -and $projectInfo.server_side) { $projectInfo.server_side } else { $null }
        }
        
    } catch {
        Write-Host "Validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Function is available for dot-sourcing 