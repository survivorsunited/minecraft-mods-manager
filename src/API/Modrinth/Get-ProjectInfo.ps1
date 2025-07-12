# =============================================================================
# Modrinth Project Information Module
# =============================================================================
# This module handles fetching project information from Modrinth API.
# =============================================================================

<#
.SYNOPSIS
    Fetches project information from Modrinth API.

.DESCRIPTION
    Fetches project information from Modrinth API with caching support.

.PARAMETER ModId
    The Modrinth project ID.

.PARAMETER ResponseFolder
    The folder for API response caching.

.PARAMETER Quiet
    Suppresses output messages.

.EXAMPLE
    Get-ModrinthProjectInfo -ModId "fabric-api"

.NOTES
    - Uses cached responses when available
    - Extracts and flattens project fields
    - Returns structured project information
#>
function Get-ModrinthProjectInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        [string]$ResponseFolder = $ApiResponseFolder,
        [switch]$Quiet
    )
    
    try {
        $apiUrl = "$ModrinthApiBaseUrl/project/$ModId"
        $responseFile = Get-ApiResponsePath -ModId $ModId -ResponseType "project" -Domain "modrinth" -BaseResponseFolder $ResponseFolder
        
        # Check if we should use cached responses
        if ($UseCachedResponses -and (Test-Path $responseFile)) {
            if (-not $Quiet) {
                Write-Host ("  → Using cached project info for {0}..." -f $ModId) -ForegroundColor DarkGray
                Write-Host ("DEBUG: Processing {0} with Modrinth validation" -f $ModId) -ForegroundColor Blue
            }
            $response = Get-Content -Path $responseFile -Raw | ConvertFrom-Json
        } else {
            # Make API request
            if (-not $Quiet) {
                Write-Host ("  → Calling API for project info {0}..." -f $ModId) -ForegroundColor DarkGray
            }
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ContentType "application/json"
            
            # Save full response to file
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        }
        
        # Extract fields and ensure null values are converted to empty strings
        function Flatten-String($str) {
            if ($null -eq $str) { return "" }
            return ($str -replace "[\r\n]+", " " -replace "\s+", " ").Trim()
        }
        $iconUrl = Flatten-String $response.icon_url
        $clientSide = Flatten-String $response.client_side
        $serverSide = Flatten-String $response.server_side
        $title = Flatten-String $response.title
        $projectDescription = Flatten-String $response.description
        $issuesUrl = Flatten-String $response.issues_url
        $sourceUrl = Flatten-String $response.source_url
        $wikiUrl = Flatten-String $response.wiki_url
        
        return [PSCustomObject]@{
            IconUrl = $iconUrl
            ClientSide = $clientSide
            ServerSide = $serverSide
            Title = $title
            ProjectDescription = $projectDescription
            IssuesUrl = $issuesUrl
            SourceUrl = $sourceUrl
            WikiUrl = $wikiUrl
            ProjectInfo = $response
            ResponseFile = $responseFile
        }
    }
    catch {
        return [PSCustomObject]@{
            IconUrl = ""
            ClientSide = ""
            ServerSide = ""
            Title = ""
            ProjectDescription = ""
            IssuesUrl = ""
            SourceUrl = ""
            WikiUrl = ""
            ProjectInfo = $null
            ResponseFile = $null
            Error = $_.Exception.Message
        }
    }
}

# Function is available for dot-sourcing 