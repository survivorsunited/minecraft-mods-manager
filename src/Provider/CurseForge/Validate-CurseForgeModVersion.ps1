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
        
        # Get project info from CurseForge API
        Load-EnvironmentVariables
    $projectInfo = Get-CurseForgeProjectInfo -ProjectId $cfModId -UseCachedResponses $false -Quiet:$Quiet
        
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
            if (-not $apiKey) {
                throw "CurseForge API key not found. Please set CURSEFORGE_API_KEY environment variable."
            }
            
            $headers = @{
                "Accept" = "application/json"
                "x-api-key" = $apiKey
            }
            
            $filesResponse = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers -TimeoutSec 30
            
            if (-not $filesResponse -or -not $filesResponse.data) {
                throw "No files found for mod $ModId"
            }
            
            $files = $filesResponse.data
            if (-not $Quiet) {
                Write-Host "DEBUG: Found $($files.Count) files for mod $ModId" -ForegroundColor Yellow
            }
            
            # Find the latest version for the specified loader and game version
            $latestFile = $null
            $requestedFile = $null
            
            foreach ($file in $files) {
                # Check if file supports the requested loader
                $supportsLoader = $false
                if ($file.gameVersions) {
                    # Check if any game version entry contains the loader
                    foreach ($gameVer in $file.gameVersions) {
                        if ($gameVer -eq $Loader -or $gameVer -like "*$Loader*") {
                            $supportsLoader = $true
                            break
                        }
                    }
                }
                
                if ($supportsLoader) {
                    # This is a potential latest file
                    if (-not $latestFile -or $file.fileDate -gt $latestFile.fileDate) {
                        $latestFile = $file
                    }
                    
                    # Check if this matches the requested version
                    if ($file.displayName -like "*$Version*" -or $file.fileName -like "*$Version*") {
                        $requestedFile = $file
                    }
                }
            }
            
            # Determine if the requested version exists
            $found = $null -ne $requestedFile
            $versionUrl = if ($requestedFile) { $requestedFile.downloadUrl } else { "" }
            $latestVersion = if ($latestFile) { $latestFile.displayName } else { "" }
            $latestVersionUrl = if ($latestFile) { $latestFile.downloadUrl } else { "" }
            
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
                Error = $null
                Title = $project.name
                ProjectDescription = $project.summary
                IconUrl = if ($project.logo) { $project.logo.url } else { "" }
                IssuesUrl = if ($project.links -and $project.links.issuesUrl) { $project.links.issuesUrl } else { "" }
                SourceUrl = if ($project.links -and $project.links.sourceUrl) { $project.links.sourceUrl } else { "" }
                WikiUrl = if ($project.links -and $project.links.wikiUrl) { $project.links.wikiUrl } else { "" }
            }
            
        } catch {
            if (-not $Quiet) {
                Write-Host "DEBUG: Failed to get files for mod $ModId : $($_.Exception.Message)" -ForegroundColor Red
            }
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