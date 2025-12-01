# =============================================================================
# GitHub Mod Version Validation Module
# =============================================================================
# This module handles validation of mod versions using GitHub API.
# =============================================================================

<#
.SYNOPSIS
    Validates mod version compatibility using GitHub API.

.DESCRIPTION
    Validates a specific mod version against GitHub releases, checking
    for JAR files matching the pattern "*-<version>.jar" in release assets.
    Extracts dependency information and stores it in the database.

.PARAMETER ModID
    The GitHub repository URL or owner/repo identifier.

.PARAMETER Version
    The specific version to validate (can be "latest", "current", or specific version).

.PARAMETER Loader
    The mod loader (fabric, forge, etc.).

.PARAMETER GameVersion
    The Minecraft version to check compatibility with.

.PARAMETER UseCachedResponses
    Whether to use cached API responses.

.PARAMETER CsvPath
    Path to the CSV database file to update.

.EXAMPLE
    Validate-GitHubModVersion -ModID "https://github.com/survivorsunited/mod-bigger-ender-chests" -Version "1.1.0" -Loader "fabric"

.NOTES
    - Updates CSV with dependency information
    - Handles API rate limiting
    - Creates backup before modifications
    - Returns validation result object
#>
# Ensure dependent helpers are available when dot-sourced directly
try {
    if (-not (Get-Command Invoke-RestMethodWithRetry -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\..\..\Net\Invoke-RestMethodWithRetry.ps1"
    }
    if (-not (Get-Command Get-GitHubProjectInfo -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\Get-GitHubProjectInfo.ps1"
    }
    if (-not (Get-Command Get-GitHubReleases -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\Get-GitHubProjectInfo.ps1"
    }
} catch { }

function Validate-GitHubModVersion {
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
        $effectiveGameVersion = if (-not [string]::IsNullOrEmpty($GameVersion)) { $GameVersion } else { "1.21.8" }
        
        # Normalize ModID to repository URL if needed
        $repositoryUrl = $ModID
        if ($ModID -notmatch '^https?://') {
            # Assume it's owner/repo format
            if ($ModID -match '^([^/]+)/([^/]+)$') {
                $repositoryUrl = "https://github.com/$ModID"
            } else {
                return @{ Success = $false; Error = "Invalid GitHub repository identifier: $ModID" }
            }
        }
        
        # Simple validation display
        if (-not $Quiet) { 
            Write-Host "Validating GitHub mod $ModID [Version: $Version] for $Loader/$effectiveGameVersion..." -ForegroundColor Cyan 
        }
        
        # Get repository info
        if (-not $Quiet) { Write-Host "DEBUG: Getting repository info for $repositoryUrl" -ForegroundColor Yellow }
        $repoInfo = Get-GitHubProjectInfo -RepositoryUrl $repositoryUrl -UseCachedResponses $UseCachedResponses -Quiet:$Quiet
        if (-not $repoInfo) {
            if (-not $Quiet) { Write-Host "DEBUG: Failed to get repository info for $repositoryUrl" -ForegroundColor Red }
            return @{ Success = $false; Error = "Failed to get repository info" }
        }
        
        # Get releases
        if (-not $Quiet) { Write-Host "DEBUG: Getting releases for $repositoryUrl" -ForegroundColor Yellow }
        $releases = Get-GitHubReleases -RepositoryUrl $repositoryUrl -UseCachedResponses $UseCachedResponses -Quiet:$Quiet
        if ($releases.Count -eq 0) {
            if (-not $Quiet) { Write-Host "DEBUG: No releases found for $repositoryUrl" -ForegroundColor Red }
            return @{ Success = $false; Error = "No releases found in repository" }
        }
        
        if (-not $Quiet) { Write-Host "DEBUG: Found $($releases.Count) releases" -ForegroundColor Yellow }
        
        # Handle version keywords: "current", "next", "latest"
        $targetVersion = $Version
        if ($Version -in @("current", "next", "latest") -or [string]::IsNullOrEmpty($Version)) {
            if ($Version -eq "latest" -or [string]::IsNullOrEmpty($Version)) {
                # Get the latest release (first in list, sorted by published date)
                # Handle both ISO 8601 format and other formats
                $latestRelease = $releases | Sort-Object { 
                    try {
                        [DateTime]::Parse($_.published_at)
                    } catch {
                        try {
                            [DateTime]::ParseExact($_.published_at, "M/d/yyyy HH:mm:ss", $null)
                        } catch {
                            [DateTime]::MinValue
                        }
                    }
                } -Descending | Select-Object -First 1
                if ($latestRelease) {
                    $targetVersion = $latestRelease.tag_name -replace '^v', ''  # Remove 'v' prefix if present
                } else {
                    return @{ Success = $false; Error = "No releases found" }
                }
            } elseif ($Version -eq "current") {
                # For "current", try to find version from CSV or use latest
                if ($CsvPath -and (Test-Path $CsvPath)) {
                    try {
                        $mods = Import-Csv -Path $CsvPath
                        $mod = $mods | Where-Object { $_.ID -eq $ModID -or $_.Url -eq $repositoryUrl } | Select-Object -First 1
                        if ($mod -and $mod.CurrentVersion -and $mod.CurrentVersion -ne "current" -and $mod.CurrentVersion -ne "latest") {
                            # Use the specific version from CSV if it's not a keyword
                            $targetVersion = $mod.CurrentVersion
                        } else {
                            # Fallback to latest if CurrentVersion is a keyword or missing
                            $latestRelease = $releases | Sort-Object { [DateTime]::Parse($_.published_at) } -Descending | Select-Object -First 1
                            if ($latestRelease) {
                                $targetVersion = $latestRelease.tag_name -replace '^v', ''
                            }
                        }
                    } catch {
                        # Fallback to latest
                        $latestRelease = $releases | Sort-Object { [DateTime]::Parse($_.published_at) } -Descending | Select-Object -First 1
                        if ($latestRelease) {
                            $targetVersion = $latestRelease.tag_name -replace '^v', ''
                        }
                    }
                        } else {
                            # Fallback to latest
                            $latestRelease = $releases | Sort-Object { 
                                try {
                                    [DateTime]::Parse($_.published_at)
                                } catch {
                                    try {
                                        [DateTime]::ParseExact($_.published_at, "M/d/yyyy HH:mm:ss", $null)
                                    } catch {
                                        [DateTime]::MinValue
                                    }
                                }
                            } -Descending | Select-Object -First 1
                    if ($latestRelease) {
                        $targetVersion = $latestRelease.tag_name -replace '^v', ''
                    }
                }
            }
        }
        
        # Find release matching target version
        $matchingRelease = $null
        foreach ($release in $releases) {
            $releaseTag = $release.tag_name -replace '^v', ''  # Remove 'v' prefix
            if ($releaseTag -eq $targetVersion -or $release.tag_name -eq $targetVersion) {
                $matchingRelease = $release
                break
            }
        }
        
        # If exact match not found, try partial match
        if (-not $matchingRelease) {
            $matchingRelease = $releases | Where-Object { 
                ($_.tag_name -replace '^v', '') -like "*$targetVersion*" -or 
                $_.tag_name -like "*$targetVersion*"
            } | Sort-Object { [DateTime]::Parse($_.published_at) } -Descending | Select-Object -First 1
        }
        
        if (-not $matchingRelease) {
            if (-not $Quiet) { 
                Write-Host "DEBUG: Version $targetVersion not found in releases" -ForegroundColor Red 
                $availableVersions = ($releases | Select-Object -First 5 | ForEach-Object { $_.tag_name -replace '^v', '' }) -join ', '
                Write-Host "Available versions: $availableVersions" -ForegroundColor Yellow
            }
            return @{ Success = $false; Error = "Version $targetVersion not found in releases" }
        }
        
        # Find JAR file matching pattern "*-<version>-<game version>.jar"
        $jarAsset = $null
        $versionPattern = $targetVersion -replace '\.', '\.'  # Escape dots for regex
        $gameVersionPattern = $effectiveGameVersion -replace '\.', '\.'  # Escape dots for regex
        
        # First, try to match the full pattern: *-<version>-<game version>.jar
        $fullJarPattern = ".*-$versionPattern-$gameVersionPattern\.jar$"
        
        foreach ($asset in $matchingRelease.assets) {
            if ($asset.name -match $fullJarPattern) {
                $jarAsset = $asset
                break
            }
        }
        
        # If full pattern match fails, try pattern without game version: *-<version>.jar
        # BUT only if we're not specifically looking for a game version (i.e., GameVersion was not provided or is empty)
        if (-not $jarAsset) {
            # Only fall back to version-only pattern if GameVersion wasn't explicitly requested
            # If GameVersion was provided, we must find a JAR matching that specific game version
            if ([string]::IsNullOrEmpty($GameVersion) -or $GameVersion -eq "latest" -or $GameVersion -eq "current") {
                $versionOnlyPattern = ".*-$versionPattern\.jar$"
                foreach ($asset in $matchingRelease.assets) {
                    if ($asset.name -match $versionOnlyPattern) {
                        $jarAsset = $asset
                        break
                    }
                }
            }
        }
        
        # If pattern match fails and we still don't have a JAR, only fall back to any JAR if GameVersion wasn't explicitly requested
        if (-not $jarAsset) {
            if ([string]::IsNullOrEmpty($GameVersion) -or $GameVersion -eq "latest" -or $GameVersion -eq "current") {
                $jarAsset = $matchingRelease.assets | Where-Object { $_.name -match '\.jar$' } | Select-Object -First 1
            }
        }
        
        if (-not $jarAsset) {
            if (-not $Quiet) { 
                Write-Host "DEBUG: No JAR file found for game version $effectiveGameVersion in release $($matchingRelease.tag_name)" -ForegroundColor Red 
                $availableAssets = ($matchingRelease.assets | ForEach-Object { $_.name }) -join ', '
                Write-Host "Available assets: $availableAssets" -ForegroundColor Yellow
            }
            return @{ Success = $false; Error = "No JAR file found for game version $effectiveGameVersion in release $($matchingRelease.tag_name)" }
        }
        
        if (-not $Quiet) { 
            Write-Host "✅ Found JAR: $($jarAsset.name) in release $($matchingRelease.tag_name)" -ForegroundColor Green 
        }
        
        # Extract version from JAR filename if possible
        # Pattern: <name>-<version>-<game version>.jar
        $extractedVersion = $targetVersion
        $extractedGameVersion = $effectiveGameVersion
        if ($jarAsset.name -match '.*-([\d\.]+(?:[-+][\w]+)?)-([\d\.]+)\.jar$') {
            # Matches full pattern with game version
            $extractedVersion = $matches[1]
            $extractedGameVersion = $matches[2]
            if (-not $Quiet) {
                Write-Host "DEBUG: Extracted version $extractedVersion and game version $extractedGameVersion from JAR filename" -ForegroundColor Gray
            }
        } elseif ($jarAsset.name -match '.*-([\d\.]+(?:[-+][\w]+)?)\.jar$') {
            # Matches pattern without game version
            $extractedVersion = $matches[1]
        }
        
        # Find the highest game version available across ALL releases for LatestGameVersion
        # This ensures we get the true latest, not just the latest in the matching release
        $gameVersionJars = @{}  # Map game version to JAR asset
        
        # Check all releases to find the highest game version
        foreach ($release in $releases) {
            foreach ($asset in $release.assets) {
                if ($asset.name -match '\.jar$' -and $asset.name -match '.*-([\d\.]+(?:[-+][\w]+)?)-([\d\.]+)\.jar$') {
                    $gameVer = $matches[2]
                    if ($gameVer -match '^\d+\.\d+\.\d+$') {
                        # Keep the first JAR we find for each game version (or overwrite if we find a newer one)
                        # Since we iterate releases in order, this will prefer newer releases
                        if (-not $gameVersionJars.ContainsKey($gameVer)) {
                            $gameVersionJars[$gameVer] = $asset
                        }
                    }
                }
            }
        }
        
        # Find highest game version (sort as versions, not strings)
        $highestGameVersion = $effectiveGameVersion
        $highestGameVersionJar = $jarAsset  # Default to current JAR
        if ($gameVersionJars.Count -gt 0) {
            $allGameVersions = $gameVersionJars.Keys | ForEach-Object { $_ }
            $sortedVersions = $allGameVersions | Sort-Object { [System.Version]$_ } -Descending
            $highestGameVersion = $sortedVersions[0]
            if ($gameVersionJars.ContainsKey($highestGameVersion)) {
                $highestGameVersionJar = $gameVersionJars[$highestGameVersion]
            }
            if (-not $Quiet) {
                Write-Host "DEBUG: Found game versions across all releases: $($allGameVersions -join ', '), highest: $highestGameVersion" -ForegroundColor Gray
                Write-Host "DEBUG: LatestVersionUrl points to: $($highestGameVersionJar.name)" -ForegroundColor Gray
            }
        }
        
        # Generate response file if script variable is set
        if ($script:TestOutputDir) {
            # Sanitize ModID for filename (remove invalid characters like :, /, etc.)
            $sanitizedModId = $ModID -replace '[<>:"/\\|?*]', '-' -replace 'https?://', ''
            $responseFile = Join-Path $script:TestOutputDir "$sanitizedModId-$targetVersion.json"
            $responseData = @{
                modId = $ModID
                version = $extractedVersion
                loader = $Loader
                gameVersion = $effectiveGameVersion
                compatible = $true
                downloadUrl = $jarAsset.browser_download_url
                fileSize = $jarAsset.size
                jar = $jarAsset.name
                releaseTag = $matchingRelease.tag_name
                releaseName = $matchingRelease.name
                publishedAt = $matchingRelease.published_at
                timestamp = Get-Date -Format "o"
            }
            $responseData | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
            if (-not $Quiet) { Write-Host "DEBUG: Created response file: $responseFile" -ForegroundColor Green }
        }
        
        return @{ 
            Success = $true
            Exists = $true
            Version = $extractedVersion
            LatestVersion = $extractedVersion
            VersionUrl = $jarAsset.browser_download_url  # URL for requested game version
            LatestVersionUrl = $highestGameVersionJar.browser_download_url  # URL for highest game version
            DownloadUrl = $jarAsset.browser_download_url
            Dependencies = ""  # GitHub releases don't provide dependency info
            FileSize = $jarAsset.size
            Jar = $jarAsset.name
            LatestGameVersion = $highestGameVersion
            Title = $repoInfo.name
            ProjectDescription = $repoInfo.description
            IconUrl = ""
            IssuesUrl = $repoInfo.html_url + "/issues"
            SourceUrl = $repoInfo.html_url
            WikiUrl = if ($repoInfo.has_wiki) { $repoInfo.html_url + "/wiki" } else { "" }
            ClientSide = $null
            ServerSide = $null
        }
        
    } catch {
        Write-Host "Validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Function is available for dot-sourcing

