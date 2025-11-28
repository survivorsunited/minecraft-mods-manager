# =============================================================================
# GitHub Project Info Module
# =============================================================================
# This module handles retrieving project information from GitHub API.
# =============================================================================

<#
.SYNOPSIS
    Retrieves comprehensive project information from GitHub API.

.DESCRIPTION
    Fetches detailed project information including releases, repository metadata,
    and release assets from the GitHub API. Handles API rate limiting and 
    provides fallback mechanisms for failed requests.

.PARAMETER RepositoryUrl
    The GitHub repository URL (e.g., https://github.com/owner/repo).

.PARAMETER UseCachedResponses
    Whether to use cached API responses for faster execution.

.EXAMPLE
    Get-GitHubProjectInfo -RepositoryUrl "https://github.com/survivorsunited/mod-bigger-ender-chests" -UseCachedResponses

.NOTES
    - Requires internet connection for live API calls
    - Cached responses are stored in .cache/apiresponse/github/
    - Handles API rate limiting automatically
    - Returns null if repository not found or API unavailable
#>
function Get-GitHubProjectInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RepositoryUrl,
        [bool]$UseCachedResponses = $false,
        [switch]$Quiet = $false
    )
    
    try {
        # Parse repository URL to extract owner and repo
        if ($RepositoryUrl -match 'github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?/?$') {
            $owner = $matches[1]
            $repo = $matches[2]
        } else {
            Write-Host "Invalid GitHub repository URL: $RepositoryUrl" -ForegroundColor Red
            return $null
        }
        
        $apiUrl = "https://api.github.com/repos/$owner/$repo"
        
        # Determine cache path - use script variable if available, otherwise use .cache/apiresponse
        $cacheDir = if ($script:TestApiResponseDir) { $script:TestApiResponseDir } else { ".cache/apiresponse" }
        $cacheKey = "$owner-$repo"
        $cachePath = Join-Path $cacheDir "github" "$cacheKey.json"
        
        # Use cached response if available and requested, or if cache file exists and is recent
        if (($UseCachedResponses -and (Test-Path $cachePath)) -or 
            ((Test-Path $cachePath) -and ((Get-Item $cachePath).LastWriteTime -gt (Get-Date).AddMinutes(-5)))) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            if (-not $Quiet) { Write-Host "Using cached response for $owner/$repo" -ForegroundColor Gray }
            return $response
        }
        
        # Make API request with retry/backoff
        $response = Invoke-RestMethodWithRetry -Uri $apiUrl -Method Get -TimeoutSec 30
        
        # Cache response if directory exists, create it if needed
        $cacheDirPath = Split-Path $cachePath
        if (-not (Test-Path $cacheDirPath)) {
            New-Item -ItemType Directory -Path $cacheDirPath -Force | Out-Null
        }
        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        
        return $response
    } catch {
        Write-Host "Failed to get GitHub project info for $RepositoryUrl : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

<#
.SYNOPSIS
    Retrieves releases from GitHub repository.

.DESCRIPTION
    Fetches all releases from a GitHub repository, including release assets.
    Handles pagination and API rate limiting.

.PARAMETER RepositoryUrl
    The GitHub repository URL (e.g., https://github.com/owner/repo).

.PARAMETER UseCachedResponses
    Whether to use cached API responses for faster execution.

.EXAMPLE
    Get-GitHubReleases -RepositoryUrl "https://github.com/survivorsunited/mod-bigger-ender-chests"
#>
function Get-GitHubReleases {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RepositoryUrl,
        [bool]$UseCachedResponses = $false,
        [switch]$Quiet = $false
    )
    
    try {
        # Parse repository URL to extract owner and repo
        if ($RepositoryUrl -match 'github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?/?$') {
            $owner = $matches[1]
            $repo = $matches[2]
        } else {
            Write-Host "Invalid GitHub repository URL: $RepositoryUrl" -ForegroundColor Red
            return @()
        }
        
        $apiUrl = "https://api.github.com/repos/$owner/$repo/releases"
        
        # Determine cache path
        $cacheDir = if ($script:TestApiResponseDir) { $script:TestApiResponseDir } else { ".cache/apiresponse" }
        $cacheKey = "$owner-$repo-releases"
        $cachePath = Join-Path $cacheDir "github" "$cacheKey.json"
        
        # Use cached response if available and requested, or if cache file exists and is recent
        if (($UseCachedResponses -and (Test-Path $cachePath)) -or 
            ((Test-Path $cachePath) -and ((Get-Item $cachePath).LastWriteTime -gt (Get-Date).AddMinutes(-5)))) {
            $response = Get-Content $cachePath | ConvertFrom-Json
            if (-not $Quiet) { Write-Host "Using cached releases for $owner/$repo" -ForegroundColor Gray }
            return $response
        }
        
        # Make API request with retry/backoff
        $releases = @()
        $page = 1
        $perPage = 100
        
        do {
            $pageUrl = "${apiUrl}?page=$page&per_page=$perPage"
            $pageResponse = Invoke-RestMethodWithRetry -Uri $pageUrl -Method Get -TimeoutSec 30
            
            if ($pageResponse.Count -eq 0) {
                break
            }
            
            $releases += $pageResponse
            $page++
        } while ($pageResponse.Count -eq $perPage)
        
        # Cache response if directory exists, create it if needed
        $cacheDirPath = Split-Path $cachePath
        if (-not (Test-Path $cacheDirPath)) {
            New-Item -ItemType Directory -Path $cacheDirPath -Force | Out-Null
        }
        $releases | ConvertTo-Json -Depth 10 | Out-File -FilePath $cachePath -Encoding UTF8
        
        return $releases
    } catch {
        Write-Host "Failed to get GitHub releases for $RepositoryUrl : $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

# Function is available for dot-sourcing


