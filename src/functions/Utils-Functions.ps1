# =============================================================================
# Utility Functions Module
# =============================================================================
# This module contains all utility/helper functions used throughout the project.
# Includes hashing, file operations, version normalization, and other helpers.
# =============================================================================

<#
.SYNOPSIS
    Calculates the SHA256 hash of a file.
.DESCRIPTION
    Computes the SHA256 hash for the specified file path.
.PARAMETER FilePath
    The path to the file to hash.
.EXAMPLE
    Calculate-FileHash -FilePath "mod.jar"
#>
function Calculate-FileHash {
    param([Parameter(Mandatory=$true)][string]$FilePath)
    try {
        if (-not (Test-Path $FilePath)) { return $null }
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($FilePath)
        try {
            $hash = $sha256.ComputeHash($stream)
            return ([BitConverter]::ToString($hash) -replace '-', '').ToLower()
        } finally {
            $stream.Dispose()
        }
    } catch {
        Write-Host "Failed to hash $($FilePath): $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

<#
.SYNOPSIS
    Calculates a record hash for a mod entry.
.DESCRIPTION
    Computes a unique hash for a mod record based on its key fields.
.PARAMETER Mod
    The mod object/record to hash.
.EXAMPLE
    Calculate-RecordHash -Mod $mod
#>
function Calculate-RecordHash {
    param([Parameter(Mandatory=$true)]$Mod)
    $fields = @('ID','Version','GameVersion','Loader','Type')
    $concat = ($fields | ForEach-Object { $Mod.($_)} ) -join '|'
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($concat)
    $hash = $sha256.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLower()
}

<#
.SYNOPSIS
    Normalizes a version string.
.DESCRIPTION
    Cleans and normalizes a version string for comparison.
.PARAMETER Version
    The version string to normalize.
.EXAMPLE
    Normalize-Version -Version "1.21.5"
#>
function Normalize-Version {
    param([Parameter(Mandatory=$true)][string]$Version)
    return ($Version -replace '[^0-9a-zA-Z\.-]', '').ToLower()
}

<#
.SYNOPSIS
    Cleans a filename for safe use.
.DESCRIPTION
    Removes invalid characters from a filename.
.PARAMETER Name
    The filename to clean.
.EXAMPLE
    Clean-Filename -Name "mod:api?*"
#>
function Clean-Filename {
    param([Parameter(Mandatory=$true)][string]$Name)
    return ($Name -replace '[\\/:*?"<>|]', '_')
}

<#
.SYNOPSIS
    Filters out ancient/irrelevant game versions from a list.
.DESCRIPTION
    Removes versions that are too old to be relevant for current mod management.
    Filters out versions like "1", "1.0", "1.1", etc. that are completely outdated.
.PARAMETER GameVersions
    Array of game version strings to filter.
.PARAMETER MinimumRelevantVersion
    The minimum version to consider relevant (default: "1.20.0").
.EXAMPLE
    $filteredVersions = Filter-RelevantGameVersions -GameVersions @("1", "1.21.5", "1.21.6")
#>
function Filter-RelevantGameVersions {
    param(
        [Parameter(Mandatory=$true)][string[]]$GameVersions,
        [string]$MinimumRelevantVersion = "1.20.0"
    )
    
    # Define ancient versions to filter out
    $ancientVersions = @(
        "1", "1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9",
        "1.10", "1.11", "1.12", "1.13", "1.14", "1.15", "1.16", "1.17", "1.18", "1.19"
    )
    
    # Filter out ancient versions and unknown
    $filteredVersions = $GameVersions | Where-Object {
        $_ -and 
        $_ -ne "unknown" -and 
        $ancientVersions -notcontains $_
    }
    
    # If we have a minimum version, also filter by that
    if ($MinimumRelevantVersion) {
        $filteredVersions = $filteredVersions | Where-Object {
            try {
                [System.Version]$_ -ge [System.Version]$MinimumRelevantVersion
            } catch {
                # If version parsing fails, keep it (might be a special version)
                $true
            }
        }
    }
    
    return $filteredVersions
}

# Functions are available for dot-sourcing, no Export-ModuleMember needed

<#
.SYNOPSIS
    Calculates Latest Game Version and Latest Available Game Versions from actual API data.
.DESCRIPTION
    Uses the actual available game versions from the API response to determine:
    - Latest Game Version: The next version after the current GameVersion in the available versions list
    - Latest Available Game Versions: All versions above the Latest Game Version
.PARAMETER AvailableGameVersions
    Array of available game versions from the API (ordered from oldest to newest).
.PARAMETER CurrentGameVersion
    The current GameVersion to find the next version for.
.EXAMPLE
    $result = Calculate-LatestGameVersionFromAvailableVersions -AvailableGameVersions @("1.20.1", "1.20.2", "1.21.1", "1.21.2") -CurrentGameVersion "1.21.1"
#>
function Calculate-LatestGameVersionFromAvailableVersions {
    param(
        [Parameter(Mandatory=$true)][string[]]$AvailableGameVersions,
        [Parameter(Mandatory=$true)][string]$CurrentGameVersion
    )
    
    # Filter out non-version strings (like "fabric", "forge", etc.)
    $validVersions = $AvailableGameVersions | Where-Object { $_ -match '^\d+\.\d+\.\d+' } | Sort-Object
    
    if ($validVersions.Count -eq 0) {
        return @{
            LatestGameVersion = $CurrentGameVersion
            LatestAvailableGameVersions = @()
        }
    }
    
    # Find the current GameVersion in the list
    $currentIndex = -1
    for ($i = 0; $i -lt $validVersions.Count; $i++) {
        if ($validVersions[$i] -eq $CurrentGameVersion) {
            $currentIndex = $i
            break
        }
    }
    
    # If current version not found, use the first version as baseline
    if ($currentIndex -eq -1) {
        $currentIndex = 0
    }
    
    # Latest Game Version is the next version in the list
    $latestGameVersion = if ($currentIndex -lt ($validVersions.Count - 1)) {
        $validVersions[$currentIndex + 1]
    } else {
        $validVersions[$currentIndex]  # If at the end, use the current version
    }
    
    # Latest Available Game Versions are all versions above the Latest Game Version
    $latestAvailableGameVersions = $validVersions | Where-Object { 
        try {
            [System.Version]$_ -gt [System.Version]$latestGameVersion
        } catch {
            $false
        }
    }
    
    return @{
        LatestGameVersion = $latestGameVersion
        LatestAvailableGameVersions = $latestAvailableGameVersions
    }
} 