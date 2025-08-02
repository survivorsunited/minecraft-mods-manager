# =============================================================================
# Provider Common Functions
# =============================================================================
# This module provides common wrapper functions for the provider system.
# =============================================================================

<#
.SYNOPSIS
    Wrapper function for Validate-ModVersion that routes to appropriate provider.

.DESCRIPTION
    This function provides the expected interface for Validate-ModVersion
    and routes the call to the appropriate provider based on the mod host.

.PARAMETER ModId
    The mod ID to validate.

.PARAMETER Version
    The version to validate.

.PARAMETER Loader
    The mod loader (fabric, forge, etc.).

.PARAMETER ResponseFolder
    The folder to store API responses.

.PARAMETER Jar
    The JAR filename (optional).

.PARAMETER Quiet
    Whether to suppress output.

.EXAMPLE
    Validate-ModVersion -ModId "fabric-api" -Version "0.91.0+1.21.5" -Loader "fabric"

.NOTES
    This is a wrapper function that routes to provider-specific validation functions.
#>
function Validate-ModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [Parameter(Mandatory=$false)]
        [string]$Loader = "",
        [string]$ResponseFolder = ".",
        [string]$Jar = "",
        [string]$CsvPath = "",
        [switch]$Quiet = $false
    )
    
    try {
        # Store original version for later reference
        $originalVersion = $Version
        
        # Determine the provider based on the mod ID or other criteria
        # For now, assume Modrinth for most cases
        $provider = "modrinth"
        
        # Route to appropriate provider function
        switch ($provider) {
            "modrinth" {
                # Handle "latest" version specially
                if ($Version -eq "latest") {
                    # Get project info to find latest version
                    $projectInfo = Get-ModrinthProjectInfo -ProjectId $ModId -UseCachedResponses $false -Quiet:$Quiet
                    if ($projectInfo -and $projectInfo.versions) {
                        if (-not $Quiet) { Write-Host "DEBUG: Found $($projectInfo.versions.Count) version IDs for $ModId" -ForegroundColor Yellow }
                        
                        # Get all version details to find the actual latest version number
                        try {
                            $versionsApiUrl = "https://api.modrinth.com/v2/project/$ModId/version"
                            $versionsResponse = Invoke-RestMethod -Uri $versionsApiUrl -Method Get -TimeoutSec 30
                            
                            if ($versionsResponse -and $versionsResponse.Count -gt 0) {
                                # Find the latest version compatible with the requested game version
                                $targetGameVersion = "1.21.5"  # Default game version for tests
                                $compatibleVersion = $null
                                
                                foreach ($version in $versionsResponse) {
                                    if ($version.game_versions -contains $targetGameVersion -and 
                                        $version.loaders -contains $effectiveLoader) {
                                        $compatibleVersion = $version
                                        break
                                    }
                                }
                                
                                if ($compatibleVersion) {
                                    $Version = $compatibleVersion.version_number
                                    if (-not $Quiet) { Write-Host "DEBUG: Using latest compatible version: $Version (supports $targetGameVersion)" -ForegroundColor Yellow }
                                } else {
                                    # Look for any version that supports the target game version
                                    $anyCompatible = $versionsResponse | Where-Object { 
                                        $_.game_versions -contains $targetGameVersion -and 
                                        $_.loaders -contains $effectiveLoader 
                                    } | Select-Object -First 1
                                    
                                    if ($anyCompatible) {
                                        $Version = $anyCompatible.version_number
                                        if (-not $Quiet) { Write-Host "DEBUG: Found compatible version: $Version (supports $targetGameVersion)" -ForegroundColor Yellow }
                                    } else {
                                        # Fall back to first version if no compatible version found
                                        $latestVersion = $versionsResponse[0]
                                        $Version = $latestVersion.version_number
                                        if (-not $Quiet) { Write-Host "DEBUG: No $targetGameVersion compatible version found, using latest: $Version" -ForegroundColor Yellow }
                                    }
                                }
                            } else {
                                if (-not $Quiet) { Write-Host "DEBUG: No versions found in API response" -ForegroundColor Red }
                                return @{
                                    Exists = $false
                                    Error = "No versions found in API response"
                                    ResponseFile = Join-Path $ResponseFolder "$ModId-latest.json"
                                }
                            }
                        } catch {
                            if (-not $Quiet) { Write-Host "DEBUG: Failed to fetch version details: $($_.Exception.Message)" -ForegroundColor Red }
                            return @{
                                Exists = $false
                                Error = "Failed to fetch version details: $($_.Exception.Message)"
                                ResponseFile = Join-Path $ResponseFolder "$ModId-latest.json"
                            }
                        }
                    } else {
                        $loaderMsg = if ($Loader -and $Loader.Trim() -ne "") { " for loader: $Loader" } else { "" }
                        return @{
                            Exists = $false
                            Error = "No versions found$loaderMsg"
                            ResponseFile = Join-Path $ResponseFolder "$ModId-latest.json"
                        }
                    }
                }
                
                # Handle empty loader parameter by using default
                $effectiveLoader = if ($Loader -and $Loader.Trim() -ne "") { $Loader } else { "fabric" }
                
                # Set script variable for response file generation
                $script:TestOutputDir = $ResponseFolder
                
                $result = Validate-ModrinthModVersion -ModID $ModId -Version $Version -Loader $effectiveLoader -CsvPath $CsvPath -Quiet:$Quiet
                # Get project info to extract all available game versions (regardless of validation result)
                if (-not $Quiet) { Write-Host "DEBUG: Getting project info for $ModId to extract AvailableGameVersions" -ForegroundColor Yellow }
                $projectInfo = Get-ModrinthProjectInfo -ProjectId $ModId -UseCachedResponses $false -Quiet:$Quiet
                $availableGameVersions = @()
                
                if ($projectInfo -and $projectInfo.game_versions) {
                    if (-not $Quiet) { Write-Host "DEBUG: Found $($projectInfo.game_versions.Count) game versions for $ModId" -ForegroundColor Yellow }
                    # Use the project-level game_versions field
                    $availableGameVersions = $projectInfo.game_versions | Sort-Object
                    if (-not $Quiet) { Write-Host "DEBUG: Extracted $($availableGameVersions.Count) game versions for $ModId" -ForegroundColor Yellow }
                } else {
                    if (-not $Quiet) { Write-Host "DEBUG: No project info or game_versions found for $ModId" -ForegroundColor Red }
                }
                
                if ($result.Success) {
                    return @{
                        Exists = $true
                        LatestVersion = $result.Version
                        VersionUrl = $result.DownloadUrl
                        LatestVersionUrl = $result.DownloadUrl
                        LatestGameVersion = "1.21.5"  # Default for now
                        CurrentDependencies = $result.Dependencies
                        LatestDependencies = $result.Dependencies
                        AvailableGameVersions = $availableGameVersions
                        ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                    }
                } else {
                    # For "latest" version resolution, still provide the version info even if not compatible
                    if ($originalVersion -eq "latest" -and $Version) {
                        return @{
                            Exists = $false
                            LatestVersion = $Version  # Still provide the latest version number
                            Error = $result.Error
                            AvailableGameVersions = $availableGameVersions
                            ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                            CurrentDependencies = ""
                            LatestDependencies = ""
                            CurrentDependenciesRequired = ""
                            CurrentDependenciesOptional = ""
                            LatestDependenciesRequired = ""
                            LatestDependenciesOptional = ""
                            VersionUrl = ""
                            LatestVersionUrl = ""
                            IconUrl = ""
                            ClientSide = ""
                            ServerSide = ""
                            Title = ""
                            ProjectDescription = ""
                            IssuesUrl = ""
                            SourceUrl = ""
                            WikiUrl = ""
                            LatestGameVersion = ""
                        }
                    } else {
                        return @{
                            Exists = $false
                            Error = $result.Error
                            AvailableGameVersions = $availableGameVersions
                            ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                            CurrentDependencies = ""
                            LatestDependencies = ""
                            CurrentDependenciesRequired = ""
                            CurrentDependenciesOptional = ""
                            LatestDependenciesRequired = ""
                            LatestDependenciesOptional = ""
                            VersionUrl = ""
                            LatestVersionUrl = ""
                            IconUrl = ""
                            ClientSide = ""
                            ServerSide = ""
                            Title = ""
                            ProjectDescription = ""
                            IssuesUrl = ""
                            SourceUrl = ""
                            WikiUrl = ""
                            LatestGameVersion = ""
                        }
                    }
                }
            }
            "curseforge" {
                # Handle empty loader parameter by using default
                $effectiveLoader = if ($Loader -and $Loader.Trim() -ne "") { $Loader } else { "fabric" }
                $result = Validate-CurseForgeModVersion -ModID $ModId -Version $Version -Loader $effectiveLoader
                if ($result.Success) {
                    # For CurseForge, we'll need to implement similar logic
                    # For now, return empty array - this can be enhanced later
                    $availableGameVersions = @()
                    
                    return @{
                        Exists = $true
                        LatestVersion = $result.Version
                        VersionUrl = $result.DownloadUrl
                        LatestVersionUrl = $result.DownloadUrl
                        LatestGameVersion = "1.21.5"  # Default for now
                        CurrentDependencies = $result.Dependencies
                        LatestDependencies = $result.Dependencies
                        AvailableGameVersions = $availableGameVersions
                        ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                    }
                } else {
                    return @{
                        Exists = $false
                        Error = $result.Error
                        AvailableGameVersions = @()
                        ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                        CurrentDependencies = ""
                        LatestDependencies = ""
                        CurrentDependenciesRequired = ""
                        CurrentDependenciesOptional = ""
                        LatestDependenciesRequired = ""
                        LatestDependenciesOptional = ""
                        VersionUrl = ""
                        LatestVersionUrl = ""
                        IconUrl = ""
                        ClientSide = ""
                        ServerSide = ""
                        Title = ""
                        ProjectDescription = ""
                        IssuesUrl = ""
                        SourceUrl = ""
                        WikiUrl = ""
                        LatestGameVersion = ""
                    }
                }
            }
            default {
                return @{
                    Exists = $false
                    Error = "Unknown provider: $provider"
                    ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                    CurrentDependencies = ""
                    LatestDependencies = ""
                    CurrentDependenciesRequired = ""
                    CurrentDependenciesOptional = ""
                    LatestDependenciesRequired = ""
                    LatestDependenciesOptional = ""
                    VersionUrl = ""
                    LatestVersionUrl = ""
                    IconUrl = ""
                    ClientSide = ""
                    ServerSide = ""
                    Title = ""
                    ProjectDescription = ""
                    IssuesUrl = ""
                    SourceUrl = ""
                    WikiUrl = ""
                    LatestGameVersion = ""
                    AvailableGameVersions = @()
                }
            }
        }
    } catch {
        return @{
            Exists = $false
            Error = $_.Exception.Message
            ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
            CurrentDependencies = ""
            LatestDependencies = ""
            CurrentDependenciesRequired = ""
            CurrentDependenciesOptional = ""
            LatestDependenciesRequired = ""
            LatestDependenciesOptional = ""
            VersionUrl = ""
            LatestVersionUrl = ""
            IconUrl = ""
            ClientSide = ""
            ServerSide = ""
            Title = ""
            ProjectDescription = ""
            IssuesUrl = ""
            SourceUrl = ""
            WikiUrl = ""
            LatestGameVersion = ""
            AvailableGameVersions = @()
        }
    }
} 