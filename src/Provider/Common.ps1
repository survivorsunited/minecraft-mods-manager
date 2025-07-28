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
        [switch]$Quiet = $false
    )
    
    try {
        # Determine the provider based on the mod ID or other criteria
        # For now, assume Modrinth for most cases
        $provider = "modrinth"
        
        # Route to appropriate provider function
        switch ($provider) {
            "modrinth" {
                # Handle "latest" version specially
                if ($Version -eq "latest") {
                    # Get project info to find latest version
                    $projectInfo = Get-ModrinthProjectInfo -ProjectId $ModId -UseCachedResponses $false
                    if ($projectInfo -and $projectInfo.versions) {
                        # Find the latest version for the specified loader
                        if ($Loader -and $Loader.Trim() -ne "") {
                            # If loader is specified, filter by loader
                            $latestVersion = $projectInfo.versions | 
                                Where-Object { $_.loaders -contains $Loader } |
                                Sort-Object { 
                                    try { 
                                        [System.Version]::Parse($_.version_number) 
                                    } catch { 
                                        # For non-standard version strings, use string comparison
                                        [System.Version]::new(0, 0, 0, 0) 
                                    }
                                } -Descending |
                                Select-Object -First 1
                        } else {
                            # If no loader specified, get the latest version regardless of loader
                            $latestVersion = $projectInfo.versions | 
                                Sort-Object { 
                                    try { 
                                        [System.Version]::Parse($_.version_number) 
                                    } catch { 
                                        # For non-standard version strings, use string comparison
                                        [System.Version]::new(0, 0, 0, 0) 
                                    }
                                } -Descending |
                                Select-Object -First 1
                        }
                        
                        if ($latestVersion) {
                            $Version = $latestVersion.version_number
                        } else {
                            $loaderMsg = if ($Loader -and $Loader.Trim() -ne "") { " for loader: $Loader" } else { "" }
                            return @{
                                Exists = $false
                                Error = "No versions found$loaderMsg"
                                ResponseFile = Join-Path $ResponseFolder "$ModId-latest.json"
                            }
                        }
                    } else {
                        return @{
                            Exists = $false
                            Error = "Failed to get project info"
                            ResponseFile = Join-Path $ResponseFolder "$ModId-latest.json"
                        }
                    }
                }
                
                $result = Validate-ModrinthModVersion -ModID $ModId -Version $Version -Loader $Loader
                if ($result.Success) {
                    return @{
                        Exists = $true
                        LatestVersion = $result.Version
                        VersionUrl = $result.DownloadUrl
                        LatestVersionUrl = $result.DownloadUrl
                        LatestGameVersion = "1.21.5"  # Default for now
                        CurrentDependencies = $result.Dependencies
                        LatestDependencies = $result.Dependencies
                        ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                    }
                } else {
                    return @{
                        Exists = $false
                        Error = $result.Error
                        ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                    }
                }
            }
            "curseforge" {
                $result = Validate-CurseForgeModVersion -ModID $ModId -Version $Version -Loader $Loader
                if ($result.Success) {
                    return @{
                        Exists = $true
                        LatestVersion = $result.Version
                        VersionUrl = $result.DownloadUrl
                        LatestVersionUrl = $result.DownloadUrl
                        LatestGameVersion = "1.21.5"  # Default for now
                        CurrentDependencies = $result.Dependencies
                        LatestDependencies = $result.Dependencies
                        ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                    }
                } else {
                    return @{
                        Exists = $false
                        Error = $result.Error
                        ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                    }
                }
            }
            default {
                return @{
                    Exists = $false
                    Error = "Unknown provider: $provider"
                    ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                }
            }
        }
    } catch {
        return @{
            Exists = $false
            Error = $_.Exception.Message
            ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
        }
    }
} 