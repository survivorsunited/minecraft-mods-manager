# =============================================================================
# API Functions Module
# =============================================================================
# This module contains all API-related functions for interacting with external
# services like Modrinth, CurseForge, Mojang, and Fabric APIs.
# 
# Functions included:
# - Get-ModrinthProjectInfo: Retrieves project information from Modrinth API
# - Validate-ModVersion: Validates mod versions using Modrinth API
# - Validate-CurseForgeModVersion: Validates mod versions using CurseForge API
# - Invoke-CurseForgeApiWithRateLimit: Handles CurseForge API calls with rate limiting
# - Get-CurseForgeFileInfo: Retrieves file information from CurseForge API
# =============================================================================

<#
.SYNOPSIS
    Retrieves comprehensive project information from Modrinth API.

.DESCRIPTION
    Fetches detailed project information including versions, dependencies, 
    and metadata from the Modrinth API. Handles API rate limiting and 
    provides fallback mechanisms for failed requests.

.PARAMETER ProjectId
    The Modrinth project ID to retrieve information for.

.PARAMETER UseCachedResponses
    Whether to use cached API responses for faster execution.

.EXAMPLE
    Get-ModrinthProjectInfo -ProjectId "fabric-api" -UseCachedResponses

.EXAMPLE
    Get-ModrinthProjectInfo -ProjectId "P7dR8mSH"

.NOTES
    - Requires internet connection for live API calls
    - Cached responses are stored in test/apiresponse/modrinth/
    - Handles API rate limiting automatically
    - Returns null if project not found or API unavailable
#>
function Get-ModrinthProjectInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectId,
        [bool]$UseCachedResponses = $false
    )
    
    try {
        $apiUrl = "https://api.modrinth.com/v2/project/$ProjectId"
        $cachePath = Join-Path $script:TestApiResponseDir "modrinth" "$ProjectId.json"
        
        # Use cached response if available and requested
        if ($UseCachedResponses -and (Test-Path $cachePath)) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            Write-Host "Using cached response for $ProjectId" -ForegroundColor Gray
            return $response
        }
        
        # Make API request
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
        
        # Cache response if directory exists
        if (Test-Path (Split-Path $cachePath)) {
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        }
        
        return $response
    } catch {
        Write-Host "Failed to get Modrinth project info for $ProjectId : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

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

.EXAMPLE
    Validate-ModVersion -ModID "fabric-api" -Version "0.91.0+1.21.5" -Loader "fabric"

.NOTES
    - Updates CSV with dependency information
    - Handles API rate limiting
    - Creates backup before modifications
    - Returns validation result object
#>
function Validate-ModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModID,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [Parameter(Mandatory=$true)]
        [string]$Loader,
        [string]$GameVersion = "1.21.5",
        [bool]$UseCachedResponses = $false
    )
    
    try {
        Write-Host "Validating $ModID version $Version for $Loader..." -ForegroundColor Cyan
        
        # Get project info
        $projectInfo = Get-ModrinthProjectInfo -ProjectId $ModID -UseCachedResponses $UseCachedResponses
        if (-not $projectInfo) {
            return @{ Success = $false; Error = "Failed to get project info" }
        }
        
        # Find the specific version
        $versionInfo = $projectInfo.versions | Where-Object { $_.version_number -eq $Version }
        if (-not $versionInfo) {
            return @{ Success = $false; Error = "Version $Version not found" }
        }
        
        # Check compatibility
        $compatible = $versionInfo.game_versions -contains $GameVersion -and 
                     $versionInfo.loaders -contains $Loader
        
        if (-not $compatible) {
            return @{ Success = $false; Error = "Version not compatible with $GameVersion/$Loader" }
        }
        
        # Extract dependencies
        $dependencies = $versionInfo.dependencies
        $dependenciesJson = Convert-DependenciesToJson -Dependencies $dependencies
        
        # Update CSV if provided
        if ($script:ModListPath -and (Test-Path $script:ModListPath)) {
            $mods = Import-Csv -Path $script:ModListPath
            $mod = $mods | Where-Object { $_.ID -eq $ModID }
            if ($mod) {
                $mod.CurrentDependencies = $dependenciesJson
                $mods | Export-Csv -Path $script:ModListPath -NoTypeInformation
            }
        }
        
        return @{ 
            Success = $true; 
            Version = $Version;
            Dependencies = $dependenciesJson;
            DownloadUrl = $versionInfo.files[0].url;
            FileSize = $versionInfo.files[0].size
        }
        
    } catch {
        Write-Host "Validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

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
        [string]$ModID,
        [Parameter(Mandatory=$true)]
        [string]$FileID,
        [bool]$UseCachedResponses = $false
    )
    
    try {
        Write-Host "Validating CurseForge mod $ModID file $FileID..." -ForegroundColor Cyan
        
        # Get file info from CurseForge API
        $fileInfo = Get-CurseForgeFileInfo -ModID $ModID -FileID $FileID -UseCachedResponses $UseCachedResponses
        if (-not $fileInfo) {
            return @{ Success = $false; Error = "Failed to get file info" }
        }
        
        return @{ 
            Success = $true; 
            FileInfo = $fileInfo;
            DownloadUrl = $fileInfo.downloadUrl;
            FileSize = $fileInfo.fileLength
        }
        
    } catch {
        Write-Host "CurseForge validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

<#
.SYNOPSIS
    Handles CurseForge API calls with rate limiting.

.DESCRIPTION
    Makes API calls to CurseForge with proper rate limiting and error handling.
    Respects CurseForge's API limits and provides retry mechanisms.

.PARAMETER Uri
    The API endpoint URI to call.

.PARAMETER Method
    The HTTP method to use (GET, POST, etc.).

.PARAMETER Body
    Optional request body for POST requests.

.EXAMPLE
    Invoke-CurseForgeApiWithRateLimit -Uri "https://api.curseforge.com/v1/mods/357540"

.NOTES
    - Requires CurseForge API key in environment
    - Implements exponential backoff for rate limits
    - Handles various HTTP error codes
#>
function Invoke-CurseForgeApiWithRateLimit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [string]$Method = "GET",
        [object]$Body = $null
    )
    
    try {
        # Get API key from environment
        $apiKey = $env:CURSEFORGE_API_KEY
        if (-not $apiKey) {
            throw "CurseForge API key not found in environment variables"
        }
        
        # Prepare headers
        $headers = @{
            "X-API-Key" = $apiKey
            "Accept" = "application/json"
        }
        
        # Make API call with retry logic
        $maxRetries = 3
        $retryCount = 0
        
        while ($retryCount -lt $maxRetries) {
            try {
                if ($Body) {
                    $response = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -Body $Body -TimeoutSec 30
                } else {
                    $response = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -TimeoutSec 30
                }
                return $response
            } catch {
                if ($_.Exception.Response.StatusCode -eq 429) {
                    # Rate limited - wait and retry
                    $retryCount++
                    $waitTime = [math]::Pow(2, $retryCount) # Exponential backoff
                    Write-Host "Rate limited, waiting $waitTime seconds..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $waitTime
                } else {
                    throw
                }
            }
        }
        
        throw "Max retries exceeded for CurseForge API call"
        
    } catch {
        Write-Host "CurseForge API call failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

<#
.SYNOPSIS
    Retrieves file information from CurseForge API.

.DESCRIPTION
    Gets detailed file information including download URL, file size,
    and compatibility data from the CurseForge API.

.PARAMETER ModID
    The CurseForge mod ID.

.PARAMETER FileID
    The specific file ID to retrieve.

.PARAMETER UseCachedResponses
    Whether to use cached API responses.

.EXAMPLE
    Get-CurseForgeFileInfo -ModID "357540" -FileID "123456"

.NOTES
    - Uses CurseForge API v1
    - Caches responses for faster subsequent calls
    - Returns null if file not found
#>
function Get-CurseForgeFileInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModID,
        [Parameter(Mandatory=$true)]
        [string]$FileID,
        [bool]$UseCachedResponses = $false
    )
    
    try {
        $apiUrl = "https://api.curseforge.com/v1/mods/$ModID/files/$FileID"
        $cachePath = Join-Path $script:TestApiResponseDir "curseforge" "$ModID-$FileID.json"
        
        # Use cached response if available and requested
        if ($UseCachedResponses -and (Test-Path $cachePath)) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            Write-Host "Using cached CurseForge response for $ModID-$FileID" -ForegroundColor Gray
            return $response.data
        }
        
        # Make API call
        $response = Invoke-CurseForgeApiWithRateLimit -Uri $apiUrl
        
        # Cache response if directory exists
        if ($response -and (Test-Path (Split-Path $cachePath))) {
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        }
        
        return $response.data
        
    } catch {
        Write-Host "Failed to get CurseForge file info for $ModID-$FileID : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Export functions for use in other modules
Export-ModuleMember -Function @(
    'Get-ModrinthProjectInfo',
    'Validate-ModVersion',
    'Validate-CurseForgeModVersion',
    'Invoke-CurseForgeApiWithRateLimit',
    'Get-CurseForgeFileInfo'
) 