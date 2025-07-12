# =============================================================================
# CurseForge Mod Version Validation Module
# =============================================================================
# This module handles validation of mod versions on CurseForge API.
# =============================================================================

<#
.SYNOPSIS
    Validates version existence on CurseForge API.

.DESCRIPTION
    Validates if a specific mod version exists on CurseForge API,
    with support for loader filtering and JAR filename matching.

.PARAMETER ModId
    The CurseForge mod ID.

.PARAMETER Version
    The version to validate.

.PARAMETER Loader
    The mod loader (fabric, forge, etc.).

.PARAMETER ResponseFolder
    The folder for API response caching.

.PARAMETER Jar
    The JAR filename for matching.

.PARAMETER ModUrl
    The mod URL.

.PARAMETER Quiet
    Suppresses output messages.

.EXAMPLE
    Validate-CurseForgeModVersion -ModId "12345" -Version "1.0.0" -Loader "fabric"

.NOTES
    - Uses cached responses when available
    - Requires CurseForge API key for authentication
    - Matches by exact version or JAR filename
    - Returns comprehensive validation results
#>
function Validate-CurseForgeModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$Loader = "fabric",
        [string]$ResponseFolder = $ApiResponseFolder,
        [string]$Jar,
        [string]$ModUrl,
        [switch]$Quiet
    )
    try {
        $apiUrl = "$CurseForgeApiBaseUrl/mods/$ModId/files"
        $responseFile = Get-ApiResponsePath -ModId $ModId -ResponseType "versions" -Domain "curseforge" -BaseResponseFolder $ResponseFolder
        
        # Check if we should use cached responses
        if ($UseCachedResponses -and (Test-Path $responseFile)) {
            if (-not $Quiet) {
                Write-Host ("  → Using cached CurseForge response for {0}..." -f $ModId) -ForegroundColor DarkGray
            }
            $response = Get-Content -Path $responseFile -Raw | ConvertFrom-Json
        } else {
            # Make API request
            if (-not $Quiet) {
                Write-Host ("  → Calling CurseForge API for {0}..." -f $ModId) -ForegroundColor DarkGray
            }
            $headers = @{ "Content-Type" = "application/json" }
            if ($CurseForgeApiKey) { $headers["X-API-Key"] = $CurseForgeApiKey }
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers
            
            # Save full response to file
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        }
        
        $filteredResponse = $response.data | Where-Object { $_.gameVersions -contains $Loader.Trim() -and $_.gameVersions -contains $DefaultGameVersion }
        $latestVersion = $filteredResponse.displayName | Select-Object -First 1
        $latestVersionStr = if ($latestVersion) { $latestVersion } else { "No $Loader versions found" }
        $normalizedExpectedVersion = Normalize-Version -Version $Version
        $versionExists = $false
        $matchingFile = $null
        $versionUrl = $null
        $latestVersionUrl = $null
        $versionFoundByJar = $false
        $currentDependenciesRequired = $null
        $currentDependenciesOptional = $null
        $latestDependenciesRequired = $null
        $latestDependenciesOptional = $null
        foreach ($file in $response.data) {
            $normalizedApiVersion = Normalize-Version -Version $file.displayName
            if ($normalizedApiVersion -eq $normalizedExpectedVersion) {
                $versionExists = $true
                $matchingFile = $file
                $versionUrl = $file.downloadUrl
                # Extract dependencies for current version
                if ($file.relations -and $file.relations.Count -gt 0) {
                    $currentDependenciesRequired = Convert-DependenciesToJsonRequired -Dependencies $file.relations
                    $currentDependenciesOptional = Convert-DependenciesToJsonOptional -Dependencies $file.relations
                    Write-Output "DEBUG: $ModId (CurseForge) current dependencies - Required: '$currentDependenciesRequired', Optional: '$currentDependenciesOptional'"
                } else {
                    Write-Output "DEBUG: $ModId (CurseForge) has no current dependencies"
                }
                break
            }
        }
        if (-not $versionExists -and -not [string]::IsNullOrEmpty($Jar)) {
            $jarToMatch = $Jar.ToLower().Trim()
            foreach ($file in $response.data) {
                if ($file.fileName.ToLower().Trim() -eq $jarToMatch) {
                    $versionExists = $true
                    $matchingFile = $file
                    $versionUrl = $file.downloadUrl
                    $versionFoundByJar = $true
                    $normalizedExpectedVersion = Normalize-Version -Version $file.displayName
                    # Extract dependencies for current version
                    if ($file.relations -and $file.relations.Count -gt 0) {
                        $currentDependenciesRequired = Convert-DependenciesToJsonRequired -Dependencies $file.relations
                        $currentDependenciesOptional = Convert-DependenciesToJsonOptional -Dependencies $file.relations
                    }
                    break
                }
            }
        }
        # If downloadUrl is missing but file id is present, construct the download URL
        if ($versionExists -and -not $versionUrl -and $matchingFile.id) {
            $versionUrl = "https://www.curseforge.com/api/v1/mods/$ModId/files/$($matchingFile.id)/download"
        }
        if ($filteredResponse.Count -gt 0) {
            $latestVer = $filteredResponse[0]
            $latestVersionUrl = $latestVer.downloadUrl
            if (-not $latestVersionUrl -and $latestVer.id) {
                $latestVersionUrl = "https://www.curseforge.com/api/v1/mods/$ModId/files/$($latestVer.id)/download"
            }
            
            # Extract game version from latest version
            $latestGameVersion = $null
            if ($latestVer.gameVersions -and $latestVer.gameVersions.Count -gt 0) {
                # Find the highest game version (excluding loaders like 'fabric', 'forge', etc.)
                $gameVersions = $latestVer.gameVersions | Where-Object { $_ -match '^\d+\.\d+\.\d+' } | Sort-Object -Descending
                if ($gameVersions.Count -gt 0) {
                    $latestGameVersion = $gameVersions[0]
                }
            }
            
            # Extract dependencies for latest version
            if ($latestVer.relations -and $latestVer.relations.Count -gt 0) {
                $latestDependenciesRequired = Convert-DependenciesToJsonRequired -Dependencies $latestVer.relations
                $latestDependenciesOptional = Convert-DependenciesToJsonOptional -Dependencies $latestVer.relations
                Write-Output "DEBUG: $ModId (CurseForge) latest dependencies - Required: '$latestDependenciesRequired', Optional: '$latestDependenciesOptional'"
            } else {
                Write-Output "DEBUG: $ModId (CurseForge) has no latest dependencies"
            }
        }
        if ($versionExists) {
            return [PSCustomObject]@{
                Exists = $true
                AvailableVersions = ($filteredResponse.displayName -join ", ")
                LatestVersion = $latestVersion
                VersionUrl = $versionUrl
                LatestVersionUrl = $latestVersionUrl
                ResponseFile = $responseFile
                VersionFoundByJar = $versionFoundByJar
                FileName = $matchingFile.fileName
                LatestFileName = if ($filteredResponse.Count -gt 0) { $filteredResponse[0].fileName } else { $null }
                LatestGameVersion = $latestGameVersion
                CurrentDependencies = ""
                LatestDependencies = ""
                CurrentDependenciesRequired = if ($currentDependenciesRequired) { $currentDependenciesRequired } else { "" }
                CurrentDependenciesOptional = if ($currentDependenciesOptional) { $currentDependenciesOptional } else { "" }
                LatestDependenciesRequired = if ($latestDependenciesRequired) { $latestDependenciesRequired } else { "" }
                LatestDependenciesOptional = if ($latestDependenciesOptional) { $latestDependenciesOptional } else { "" }
            }
        } else {
            return [PSCustomObject]@{
                Exists = $false
                AvailableVersions = ($filteredResponse.displayName -join ", ")
                LatestVersion = $latestVersion
                VersionUrl = $null
                LatestVersionUrl = $latestVersionUrl
                ResponseFile = $responseFile
                VersionFoundByJar = $versionFoundByJar
                FileName = $null
                LatestFileName = if ($filteredResponse.Count -gt 0) { $filteredResponse[0].fileName } else { $null }
                LatestGameVersion = $latestGameVersion
                CurrentDependencies = ""
                LatestDependencies = ""
                CurrentDependenciesRequired = ""
                CurrentDependenciesOptional = ""
                LatestDependenciesRequired = ""
                LatestDependenciesOptional = ""
            }
        }
    } catch {
        return [PSCustomObject]@{
            Exists = $false
            AvailableVersions = $null
            LatestVersion = $null
            VersionUrl = $null
            LatestVersionUrl = $null
            ResponseFile = $null
            VersionFoundByJar = $false
            CurrentDependencies = ""
            LatestDependencies = ""
            CurrentDependenciesRequired = ""
            CurrentDependenciesOptional = ""
            LatestDependenciesRequired = ""
            LatestDependenciesOptional = ""
            Error = $_.Exception.Message
        }
    }
}

# Function is available for dot-sourcing 