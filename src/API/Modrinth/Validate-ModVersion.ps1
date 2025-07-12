# =============================================================================
# Modrinth Mod Version Validation Module
# =============================================================================
# This module handles validation of mod versions on Modrinth API.
# =============================================================================

<#
.SYNOPSIS
    Validates version existence on Modrinth API.

.DESCRIPTION
    Validates if a specific mod version exists on Modrinth API,
    with support for loader filtering and JAR filename matching.

.PARAMETER ModId
    The Modrinth project ID.

.PARAMETER Version
    The version to validate.

.PARAMETER Loader
    The mod loader (fabric, forge, etc.).

.PARAMETER ResponseFolder
    The folder for API response caching.

.PARAMETER Jar
    The JAR filename for matching.

.PARAMETER Quiet
    Suppresses output messages.

.EXAMPLE
    Validate-ModVersion -ModId "fabric-api" -Version "1.0.0" -Loader "fabric"

.NOTES
    - Uses cached responses when available
    - Supports "latest" version requests
    - Matches by exact version or JAR filename
    - Returns comprehensive validation results
#>
function Validate-ModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        
        [Parameter(Mandatory=$true)]
        [string]$Version,
        
        [string]$Loader = "fabric",
        
        [string]$ResponseFolder = $ApiResponseFolder,
        
        [string]$Jar,
        
        [switch]$Quiet
    )
    
    try {
        $apiUrl = "$ModrinthApiBaseUrl/project/$ModId/version"
        $responseFile = Get-ApiResponsePath -ModId $ModId -ResponseType "versions" -Domain "modrinth" -BaseResponseFolder $ResponseFolder
        
        # Check if we should use cached responses
        if ($UseCachedResponses -and (Test-Path $responseFile)) {
            if (-not $Quiet) {
                Write-Host ("  → Using cached response for {0}..." -f $ModId) -ForegroundColor DarkGray
            }
            $response = Get-Content -Path $responseFile -Raw | ConvertFrom-Json
        } else {
            # Make API request for versions
            if (-not $Quiet) {
                Write-Host ("  → Calling API for {0}..." -f $ModId) -ForegroundColor DarkGray
            }
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ContentType "application/json"
            
            # Save full response to file
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        }
        
        # Filter versions by loader
        $filteredResponse = $response | Where-Object { $_.loaders -contains $Loader.Trim() }
        
        # Get project information to access game_versions field
        $projectInfo = Get-ModrinthProjectInfo -ModId $ModId -ResponseFolder $ResponseFolder -Quiet:$Quiet
        
        # Determine the latest version using project API response game_versions field
        $latestVersion = "No $Loader versions found"
        $latestVerObj = $null
        
        if ($projectInfo.ProjectInfo -and $projectInfo.ProjectInfo.game_versions -and $projectInfo.ProjectInfo.game_versions.Count -gt 0) {
            # Get the last entry in the game_versions array as the latest
            $latestGameVersion = $projectInfo.ProjectInfo.game_versions[-1]
            
            # Find the version object that supports this game version
            $latestVerObj = $filteredResponse | Where-Object { 
                $_.game_versions -and $_.game_versions -contains $latestGameVersion 
            } | Select-Object -First 1
            
            if ($latestVerObj) {
                $latestVersion = $latestVerObj.version_number
            } elseif ($filteredResponse.Count -gt 0) {
                # Fallback: if no version matches the latest game version, use the first filtered version
                $latestVerObj = $filteredResponse[0]
                $latestVersion = $latestVerObj.version_number
            }
        } elseif ($filteredResponse.Count -gt 0) {
            # Fallback: if no project info or game_versions, use the first filtered version
            $latestVerObj = $filteredResponse[0]
            $latestVersion = $latestVerObj.version_number
        }
        
        $latestVersionStr = if ($latestVersion -ne "No $Loader versions found") { $latestVersion } else { "No $Loader versions found" }
        
        # Handle "latest" version parameter
        if ($Version -eq "latest") {
            # For "latest" requests, use the determined latest version
            $versionExists = $true
            $matchingVersion = $latestVerObj
            $normalizedExpectedVersion = Normalize-Version -Version $latestVersion
        } else {
            # Normalize the expected version for comparison
            $normalizedExpectedVersion = Normalize-Version -Version $Version
        }
        
        # Check if the specific version exists (in filtered results)
        if ($Version -ne "latest") {
            $versionExists = $false
            $matchingVersion = $null
            $versionUrl = $null
            $latestVersionUrl = $null
            $versionFoundByJar = $false
            
            # Find matching version and extract URL
            foreach ($ver in $filteredResponse) {
                $normalizedApiVersion = Normalize-Version -Version $ver.version_number
                
                # Try exact match first
                if ($normalizedApiVersion -eq $normalizedExpectedVersion) {
                    $versionExists = $true
                    $matchingVersion = $ver
                    # Extract download URL
                    if ($ver.files -and $ver.files.Count -gt 0) {
                        $primaryFile = $ver.files | Where-Object { $_.primary -eq $true } | Select-Object -First 1
                        if (-not $primaryFile) {
                            $primaryFile = $ver.files | Select-Object -First 1
                        }
                        $versionUrl = $primaryFile.url
                    }
                    break
                }
            }
            
            # If exact version match failed, try matching by JAR filename
            if (-not $versionExists -and -not [string]::IsNullOrEmpty($Jar)) {
                $jarToMatch = $Jar.ToLower().Trim()
                foreach ($ver in $filteredResponse) {
                    if ($ver.files -and $ver.files.Count -gt 0) {
                        foreach ($file in $ver.files) {
                            if ($file.filename.ToLower().Trim() -eq $jarToMatch) {
                                $versionExists = $true
                                $matchingVersion = $ver
                                $versionUrl = $file.url
                                $versionFoundByJar = $true
                                # Update the expected version to match what we found
                                $normalizedExpectedVersion = Normalize-Version -Version $ver.version_number
                                break
                            }
                        }
                        if ($versionExists) { break }
                    }
                }
            }
        } else {
            # For "latest" requests, initialize variables
            $versionUrl = $null
            $latestVersionUrl = $null
            $versionFoundByJar = $false
        }
        
        # Extract download URL for matching version (including "latest")
        if ($versionExists -and $matchingVersion -and -not $versionUrl) {
            if ($matchingVersion.files -and $matchingVersion.files.Count -gt 0) {
                $primaryFile = $matchingVersion.files | Where-Object { $_.primary -eq $true } | Select-Object -First 1
                if (-not $primaryFile) {
                    $primaryFile = $matchingVersion.files | Select-Object -First 1
                }
                $versionUrl = $primaryFile.url
            }
        }
        
        # Extract latest version URL using the determined latest version
        if ($latestVerObj -and $latestVerObj.files -and $latestVerObj.files.Count -gt 0) {
            $latestVersionUrl = $latestVerObj.files[0].url
        }
        
        # Extract dependencies from matching version and latest version
        $currentDependenciesRequired = $null
        $currentDependenciesOptional = $null
        $latestDependenciesRequired = $null
        $latestDependenciesOptional = $null
        
        if ($matchingVersion -and $matchingVersion.dependencies) {
            $currentDependenciesRequired = Convert-DependenciesToJsonRequired -Dependencies $matchingVersion.dependencies
            $currentDependenciesOptional = Convert-DependenciesToJsonOptional -Dependencies $matchingVersion.dependencies
            Write-Output "DEBUG: $ModId has dependencies - Required: '$currentDependenciesRequired', Optional: '$currentDependenciesOptional'"
        } else {
            Write-Output "DEBUG: $ModId has no dependencies"
        }
        
        if ($latestVerObj -and $latestVerObj.dependencies) {
            $latestDependenciesRequired = Convert-DependenciesToJsonRequired -Dependencies $latestVerObj.dependencies
            $latestDependenciesOptional = Convert-DependenciesToJsonOptional -Dependencies $latestVerObj.dependencies
            Write-Output "DEBUG: $ModId latest dependencies - Required: '$latestDependenciesRequired', Optional: '$latestDependenciesOptional'"
        } else {
            Write-Output "DEBUG: $ModId has no latest dependencies"
        }
        
        # Display mod and latest version
        if ($versionExists) {
            # Get latest game version for the latest version
            $latestGameVersion = $null
            if ($latestVerObj -and $latestVerObj.game_versions -and $latestVerObj.game_versions.Count -gt 0) {
                # Get the last (highest) game version from the array
                $latestGameVersion = $latestVerObj.game_versions[-1]
            }

            # Collect all available game versions from all versions of this mod
            $allAvailableGameVersions = @()
            foreach ($ver in $filteredResponse) {
                if ($ver.game_versions -and $ver.game_versions.Count -gt 0) {
                    $allAvailableGameVersions += $ver.game_versions
                }
            }
            $allAvailableGameVersions = $allAvailableGameVersions | Select-Object -Unique | Sort-Object

            return [PSCustomObject]@{
                Exists = $true
                AvailableVersions = ($filteredResponse.version_number -join ", ")
                AvailableGameVersions = $allAvailableGameVersions
                LatestVersion = $latestVersion
                VersionUrl = $versionUrl
                LatestVersionUrl = $latestVersionUrl
                IconUrl = $projectInfo.IconUrl
                ClientSide = $projectInfo.ClientSide
                ServerSide = $projectInfo.ServerSide
                Title = $projectInfo.Title
                ProjectDescription = $projectInfo.ProjectDescription
                IssuesUrl = if ($projectInfo.IssuesUrl) { $projectInfo.IssuesUrl.ToString() } else { "" }
                SourceUrl = if ($projectInfo.SourceUrl) { $projectInfo.SourceUrl.ToString() } else { "" }
                WikiUrl = if ($projectInfo.WikiUrl) { $projectInfo.WikiUrl.ToString() } else { "" }
                VersionFoundByJar = $versionFoundByJar
                LatestGameVersion = $latestGameVersion
                CurrentDependenciesRequired = if ($currentDependenciesRequired) { $currentDependenciesRequired } else { "" }
                CurrentDependenciesOptional = if ($currentDependenciesOptional) { $currentDependenciesOptional } else { "" }
                LatestDependenciesRequired = if ($latestDependenciesRequired) { $latestDependenciesRequired } else { "" }
                LatestDependenciesOptional = if ($latestDependenciesOptional) { $latestDependenciesOptional } else { "" }
            }
        } else {
            # Collect all available game versions from all versions of this mod
            $allAvailableGameVersions = @()
            foreach ($ver in $filteredResponse) {
                if ($ver.game_versions -and $ver.game_versions.Count -gt 0) {
                    $allAvailableGameVersions += $ver.game_versions
                }
            }
            $allAvailableGameVersions = $allAvailableGameVersions | Select-Object -Unique | Sort-Object

            return [PSCustomObject]@{
                Exists = $false
                AvailableVersions = ($filteredResponse.version_number -join ", ")
                AvailableGameVersions = $allAvailableGameVersions
                LatestVersion = $latestVersion
                VersionUrl = $null
                LatestVersionUrl = $latestVersionUrl
                IconUrl = $projectInfo.IconUrl
                ClientSide = $projectInfo.ClientSide
                ServerSide = $projectInfo.ServerSide
                Title = $projectInfo.Title
                ProjectDescription = $projectInfo.ProjectDescription
                IssuesUrl = if ($projectInfo.IssuesUrl) { $projectInfo.IssuesUrl.ToString() } else { "" }
                SourceUrl = if ($projectInfo.SourceUrl) { $projectInfo.SourceUrl.ToString() } else { "" }
                WikiUrl = if ($projectInfo.WikiUrl) { $projectInfo.WikiUrl.ToString() } else { "" }
                VersionFoundByJar = $false
                LatestGameVersion = $null
                CurrentDependenciesRequired = $null
                CurrentDependenciesOptional = $null
                LatestDependenciesRequired = $null
                LatestDependenciesOptional = $null
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            AvailableVersions = $null
            LatestVersion = $null
            VersionUrl = $null
            LatestVersionUrl = $null
            IconUrl = $null
            ResponseFile = $null
            VersionFoundByJar = $false
            LatestGameVersion = $null
            CurrentDependencies = $null
            LatestDependencies = $null
            CurrentDependenciesRequired = $null
            CurrentDependenciesOptional = $null
            LatestDependenciesRequired = $null
            LatestDependenciesOptional = $null
            Error = $_.Exception.Message
        }
    }
}

# Function is available for dot-sourcing 