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
# Ensure dependent helpers are available when dot-sourced directly (outside Import-Modules)
try {
    if (-not (Get-Command Invoke-RestMethodWithRetry -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\..\..\Net\Invoke-RestMethodWithRetry.ps1"
    }
    if (-not (Get-Command Resolve-CurseForgeProjectId -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\Resolve-CurseForgeProjectId.ps1"
    }
    if (-not (Get-Command Load-EnvironmentVariables -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\..\..\Core\Environment\Load-EnvironmentVariables.ps1"
    }
} catch { }

function Validate-CurseForgeModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$Loader = "fabric",
        [string]$ResponseFolder = ".",
        [string]$Jar = "",
        [string]$ModUrl = "",
        [string]$CsvPath = "",
        [switch]$Quiet = $false
    )
    
    try {
        # Resolve slug to numeric ID if necessary
        $cfModId = $ModId
        if ($ModId -notmatch '^\d+$') {
            try {
                $resolved = Resolve-CurseForgeProjectId -Identifier $ModId -Quiet
                if ($resolved) { $cfModId = $resolved }
            } catch {}
        }

        if (-not $Quiet) {
            # Try to get Next and Latest versions from CSV if available
            $displayVersionInfo = "Current: $Version"
            if ($CsvPath -and (Test-Path $CsvPath)) {
                try {
                    $mods = Import-Csv -Path $CsvPath
                    $mod = $mods | Where-Object { $_.ID -eq $ModId } | Select-Object -First 1
                    if ($mod) {
                        # Always show Next version if available
                        if ($mod.NextVersion -and $mod.NextVersion -ne "") {
                            $displayVersionInfo += " | Next: $($mod.NextVersion)"
                        } else {
                            $displayVersionInfo += " | Next: none"
                        }
                        
                        # Always show Latest version if available
                        if ($mod.LatestVersion -and $mod.LatestVersion -ne "") {
                            $displayVersionInfo += " | Latest: $($mod.LatestVersion)"
                        } else {
                            $displayVersionInfo += " | Latest: none"
                        }
                    }
                } catch {
                    # Silently ignore CSV read errors - fallback to basic display
                    $displayVersionInfo += " | Next: unknown | Latest: unknown"
                }
            } else {
                $displayVersionInfo += " | Next: unknown | Latest: unknown"
            }
            
            Write-Host "Validating $ModId [$displayVersionInfo] for $Loader..." -ForegroundColor Cyan
        }
        
        # Get project info from CurseForge API (prefer cache when available)
        Load-EnvironmentVariables
        # Prefer cached project info to reduce API/key dependency; live calls will still be used for files below
        $projectInfo = Get-CurseForgeProjectInfo -ProjectId $cfModId -UseCachedResponses $true -Quiet:$Quiet
        
        if (-not $projectInfo -or -not $projectInfo.data) {
            return @{
                Success = $false
                ModId = $cfModId
                Version = $Version
                Loader = $Loader
                Found = $false
                VersionUrl = ""
                LatestVersion = ""
                LatestVersionUrl = ""
                Error = "Failed to get project info from CurseForge API"
            }
        }
        
        # Extract project data
        $project = $projectInfo.data
        
        if (-not $Quiet) { Write-Host "DEBUG: Found CurseForge project: $($project.name)" -ForegroundColor Yellow }
        
        # Get versions/files for this mod
        try {
            $apiUrl = "https://api.curseforge.com/v1/mods/$cfModId/files"
            $apiKey = $env:CURSEFORGE_API_KEY
            $headers = @{ "Accept" = "application/json" }
            if ($apiKey) { $headers["x-api-key"] = $apiKey }

            $files = $null
            $filesResponse = $null
            try {
                $filesResponse = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers -TimeoutSec 30
                if ($filesResponse -and $filesResponse.data) {
                    $files = $filesResponse.data
                }
            } catch {
                if (-not $Quiet) { Write-Host "DEBUG: Live files API failed, will try project.latestFiles fallback: $($_.Exception.Message)" -ForegroundColor DarkYellow }
            }

            # Fallback: use latestFiles from project info when live API isn't available
            if (-not $files -and $project -and $project.latestFiles) {
                $files = $project.latestFiles
            }

            if (-not $files) {
                throw "No files available for mod $ModId"
            }

            if (-not $Quiet) { Write-Host "DEBUG: Found $($files.Count) files for mod $ModId" -ForegroundColor Yellow }

            # Find the latest version for the specified loader; fallback to any latest when no match
            $latestFile = $null
            $latestAnyFile = $null
            $requestedFile = $null

            foreach ($file in $files) {
                # Track absolute latest as fallback
                if (-not $latestAnyFile -or $file.fileDate -gt $latestAnyFile.fileDate) { $latestAnyFile = $file }

                # Check if file supports the requested loader
                $supportsLoader = $false
                if ($file.gameVersions) {
                    foreach ($gameVer in $file.gameVersions) {
                        if ($gameVer -eq $Loader -or $gameVer -like "*$Loader*") { $supportsLoader = $true; break }
                    }
                }

                if ($supportsLoader) {
                    if (-not $latestFile -or $file.fileDate -gt $latestFile.fileDate) { $latestFile = $file }
                    if ($file.displayName -like "*$Version*" -or $file.fileName -like "*$Version*") { $requestedFile = $file }
                }
            }

            if (-not $latestFile) { $latestFile = $latestAnyFile }

            # Determine if the requested version exists
            $found = $null -ne $requestedFile
            $versionUrl = if ($requestedFile -and $requestedFile.downloadUrl) { $requestedFile.downloadUrl } else { "" }
            $latestVersion = if ($latestFile -and $latestFile.displayName) { $latestFile.displayName } elseif ($latestFile -and $latestFile.fileName) { $latestFile.fileName } else { "" }
            $latestVersionUrl = if ($latestFile -and $latestFile.downloadUrl) { $latestFile.downloadUrl } else { "" }
            $latestGameVersion = ""
            if ($latestFile -and $latestFile.gameVersions -and $latestFile.gameVersions.Count -gt 0) {
                # Prefer the first semantic-looking game version
                $latestGameVersion = ($latestFile.gameVersions | Where-Object { $_ -match '^[0-9]+\.[0-9]+' } | Select-Object -First 1)
                if (-not $latestGameVersion) { $latestGameVersion = $latestFile.gameVersions[0] }
            }

            if (-not $Quiet) {
                Write-Host "DEBUG: Requested version found: $found" -ForegroundColor Yellow
                Write-Host "DEBUG: Latest version: $latestVersion" -ForegroundColor Yellow
            }

            return @{
                Success = $true
                ModId = $cfModId
                Version = $Version
                Loader = $Loader
                Found = $found
                Exists = $found
                VersionUrl = $versionUrl
                LatestVersion = $latestVersion
                LatestVersionUrl = $latestVersionUrl
                LatestGameVersion = $latestGameVersion
                Error = $null
                Title = $project.name
                ProjectDescription = $project.summary
                IconUrl = if ($project.logo) { $project.logo.url } else { "" }
                IssuesUrl = if ($project.links -and $project.links.issuesUrl) { $project.links.issuesUrl } else { "" }
                SourceUrl = if ($project.links -and $project.links.sourceUrl) { $project.links.sourceUrl } else { "" }
                WikiUrl = if ($project.links -and $project.links.wikiUrl) { $project.links.wikiUrl } else { "" }
            }

        } catch {
            if (-not $Quiet) { Write-Host "DEBUG: Failed to get files for mod $ModId : $($_.Exception.Message)" -ForegroundColor Red }
            return @{
                Success = $false
                ModId = $cfModId
                Version = $Version
                Loader = $Loader
                Found = $false
                VersionUrl = ""
                LatestVersion = ""
                LatestVersionUrl = ""
                Error = "Failed to get files: $($_.Exception.Message)"
            }
        }
        
    } catch {
        Write-Host "CurseForge validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ 
            Success = $false
            ModId = $cfModId
            Version = $Version
            Loader = $Loader
            Found = $false
            VersionUrl = ""
            LatestVersion = ""  
            LatestVersionUrl = ""
            Error = $_.Exception.Message 
        }
    }
}

# Function is available for dot-sourcing 