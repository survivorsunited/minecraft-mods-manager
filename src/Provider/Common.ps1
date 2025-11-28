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

.PARAMETER GameVersion
    The Minecraft game version to check compatibility with.

.PARAMETER ResponseFolder
    The folder to store API responses.

.PARAMETER Jar
    The JAR filename (optional).

.PARAMETER CsvPath
    Path to the CSV database file to update.

.PARAMETER Quiet
    Whether to suppress output.

.EXAMPLE
    Validate-ModVersion -ModId "fabric-api" -Version "0.91.0+1.21.5" -Loader "fabric" -GameVersion "1.21.5"

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
        [string]$GameVersion = "",
        [string]$ResponseFolder = ".",
        [string]$Jar = "",
        [string]$CsvPath = "",
        [switch]$Quiet = $false
    )
    
    try {
        # Determine provider using CSV when available, else infer from ID pattern
        $provider = "modrinth"
        if ($CsvPath -and (Test-Path $CsvPath)) {
            try {
                $mods = Import-Csv -Path $CsvPath
                $row = $mods | Where-Object { $_.ID -eq $ModId } | Select-Object -First 1
                if ($row -and $row.ApiSource) {
                    $provider = $row.ApiSource.ToLower()
                } elseif ($row -and $row.Host) {
                    $provider = $row.Host.ToLower()
                } elseif ($row -and $row.Url -match 'curseforge\.com') {
                    $provider = 'curseforge'
                } elseif ($row -and $row.Url -match 'github\.com') {
                    $provider = 'github'
                }
            } catch { }
        } else {
            # Fallback inference: numeric IDs are typically CurseForge
            if ($ModId -match '^[0-9]+$') { 
                $provider = 'curseforge' 
            } elseif ($ModId -match 'github\.com') {
                $provider = 'github'
            }
        }
        
        # Route to appropriate provider function
        switch ($provider) {
            "modrinth" {
                # Handle version keywords: "current", "next", "latest"
                # Pass these through to Validate-ModrinthModVersion which handles them properly
                if ($Version -in @("current", "next", "latest")) {
                    # Keywords are handled by Validate-ModrinthModVersion
                    $result = Validate-ModrinthModVersion -ModID $ModId -Version $Version -Loader $Loader -GameVersion $GameVersion -UseCachedResponses $false -CsvPath $CsvPath -Quiet:$Quiet
                    
                    # Transform result to expected format
                    if ($result.Success) {
                        return @{
                            Exists = $true
                            LatestVersion = $result.Version
                            VersionUrl = $result.DownloadUrl
                            LatestVersionUrl = $result.DownloadUrl
                            LatestGameVersion = $GameVersion
                            CurrentDependencies = $result.Dependencies
                            LatestDependencies = $result.Dependencies
                            Jar = $result.Jar
                            Title = $result.Title
                            ProjectDescription = $result.ProjectDescription
                            IconUrl = $result.IconUrl
                            IssuesUrl = $result.IssuesUrl
                            SourceUrl = $result.SourceUrl
                            WikiUrl = $result.WikiUrl
                            ClientSide = $result.ClientSide
                            ServerSide = $result.ServerSide
                            ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                        }
                    } else {
                        return @{
                            Exists = $false
                            Error = $result.Error
                            ResponseFile = Join-Path $ResponseFolder "$ModId-$Version.json"
                        }
                    }
                } elseif ($Version -eq "latest-old-logic") {
                    # OLD LOGIC - kept for reference but not used
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
                
                $result = Validate-ModrinthModVersion -ModID $ModId -Version $Version -Loader $Loader -GameVersion $GameVersion -CsvPath $CsvPath -Quiet:$Quiet
                if ($result.Success) {
                    return @{
                        Exists = $true
                        LatestVersion = $result.Version
                        VersionUrl = $result.DownloadUrl
                        LatestVersionUrl = $result.DownloadUrl
                        LatestGameVersion = if ($result.LatestGameVersion) { $result.LatestGameVersion } else { $GameVersion }
                        CurrentDependencies = $result.Dependencies
                        LatestDependencies = $result.Dependencies
                        Jar = $result.Jar
                        Title = $result.Title
                        ProjectDescription = $result.ProjectDescription
                        IconUrl = $result.IconUrl
                        IssuesUrl = $result.IssuesUrl
                        SourceUrl = $result.SourceUrl
                        WikiUrl = $result.WikiUrl
                        ClientSide = $result.ClientSide
                        ServerSide = $result.ServerSide
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
                $result = Validate-CurseForgeModVersion -ModID $ModId -Version $Version -Loader $Loader -CsvPath $CsvPath -Quiet:$Quiet
                if ($result.Success) {
                    return @{
                        Exists = $true
                        LatestVersion = $result.LatestVersion
                        VersionUrl = $result.VersionUrl
                        LatestVersionUrl = $result.LatestVersionUrl
                        LatestGameVersion = $result.LatestGameVersion
                        CurrentDependencies = $result.CurrentDependencies
                        LatestDependencies = $result.LatestDependencies
                        Title = $result.Title
                        ProjectDescription = $result.ProjectDescription
                        IconUrl = $result.IconUrl
                        IssuesUrl = $result.IssuesUrl
                        SourceUrl = $result.SourceUrl
                        WikiUrl = $result.WikiUrl
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
            "github" {
                $result = Validate-GitHubModVersion -ModID $ModId -Version $Version -Loader $Loader -GameVersion $GameVersion -CsvPath $CsvPath -Quiet:$Quiet
                if ($result.Success) {
                    return @{
                        Exists = $true
                        LatestVersion = $result.Version
                        VersionUrl = $result.DownloadUrl
                        LatestVersionUrl = $result.DownloadUrl
                        LatestGameVersion = if ($result.LatestGameVersion) { $result.LatestGameVersion } else { $GameVersion }
                        CurrentDependencies = $result.Dependencies
                        LatestDependencies = $result.Dependencies
                        Jar = $result.Jar
                        Title = $result.Title
                        ProjectDescription = $result.ProjectDescription
                        IconUrl = $result.IconUrl
                        IssuesUrl = $result.IssuesUrl
                        SourceUrl = $result.SourceUrl
                        WikiUrl = $result.WikiUrl
                        ClientSide = $result.ClientSide
                        ServerSide = $result.ServerSide
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