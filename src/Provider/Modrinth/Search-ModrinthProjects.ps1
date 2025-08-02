# =============================================================================
# Modrinth Project Search Module
# =============================================================================
# This module handles searching for projects on Modrinth using the search API.
# =============================================================================

<#
.SYNOPSIS
    Searches for projects on Modrinth using the search API.

.DESCRIPTION
    Uses the Modrinth search API to find projects by name, with support for
    filtering by project type (mod, shader, datapack, etc.) and other criteria.

.PARAMETER Query
    The search query string to find projects.

.PARAMETER ProjectType
    Filter by project type (mod, shader, datapack, resourcepack, etc.).

.PARAMETER Categories
    Filter by categories (array of category names).

.PARAMETER Versions
    Filter by supported game versions (array of versions).

.PARAMETER Loaders
    Filter by supported loaders (fabric, forge, quilt, etc.).

.PARAMETER Limit
    Maximum number of results to return (default: 10, max: 100).

.PARAMETER Offset
    Number of results to skip for pagination (default: 0).

.PARAMETER SortBy
    Sort results by: relevance, downloads, follows, newest, updated (default: relevance).

.PARAMETER Interactive
    Show interactive selection menu for choosing from results.

.EXAMPLE
    Search-ModrinthProjects -Query "sodium" -ProjectType "mod" -Interactive

.EXAMPLE
    Search-ModrinthProjects -Query "shaders" -ProjectType "shader" -Limit 5

.NOTES
    - Uses Modrinth search API v2
    - Returns project objects with id, title, description, project_type, etc.
    - Interactive mode allows user to select from search results
#>
function Search-ModrinthProjects {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,
        
        [string]$ProjectType = "",
        [string[]]$Categories = @(),
        [string[]]$Versions = @(),
        [string[]]$Loaders = @(),
        [int]$Limit = 10,
        [int]$Offset = 0,
        [string]$SortBy = "relevance",
        [switch]$Interactive,
        [switch]$Quiet
    )
    
    try {
        # Build search URL with parameters
        $baseUrl = "https://api.modrinth.com/v2/search"
        $params = @()
        
        # Add query parameter
        $params += "query=" + [System.Web.HttpUtility]::UrlEncode($Query)
        
        # Add optional filters
        if ($ProjectType) {
            $params += "facets=[[`"project_type:$ProjectType`"]]"
        }
        
        if ($Categories.Count -gt 0) {
            $categoryFacets = $Categories | ForEach-Object { "`"categories:$_`"" }
            $params += "facets=[[" + ($categoryFacets -join ",") + "]]"
        }
        
        if ($Versions.Count -gt 0) {
            $versionFacets = $Versions | ForEach-Object { "`"versions:$_`"" }
            $params += "facets=[[" + ($versionFacets -join ",") + "]]"
        }
        
        if ($Loaders.Count -gt 0) {
            $loaderFacets = $Loaders | ForEach-Object { "`"categories:$_`"" }
            $params += "facets=[[" + ($loaderFacets -join ",") + "]]"
        }
        
        # Add pagination and sorting
        $params += "limit=$Limit"
        $params += "offset=$Offset"
        $params += "index=$SortBy"
        
        # Build final URL
        $searchUrl = $baseUrl + "?" + ($params -join "&")
        
        if (-not $Quiet) {
            Write-Host "Searching Modrinth for: '$Query'" -ForegroundColor Cyan
            if ($ProjectType) {
                Write-Host "  Filter: $ProjectType projects" -ForegroundColor Gray
            }
        }
        
        # Make API request
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 30
        
        if (-not $response -or -not $response.hits -or $response.hits.Count -eq 0) {
            if (-not $Quiet) {
                Write-Host "No projects found matching '$Query'" -ForegroundColor Yellow
            }
            return $null
        }
        
        $projects = $response.hits
        
        if (-not $Quiet) {
            Write-Host "Found $($projects.Count) projects" -ForegroundColor Green
        }
        
        if ($Interactive) {
            # Show interactive selection menu
            Write-Host "`nSearch Results:" -ForegroundColor Cyan
            Write-Host "===============" -ForegroundColor Cyan
            
            for ($i = 0; $i -lt $projects.Count; $i++) {
                $project = $projects[$i]
                $projectType = $project.project_type
                $downloads = if ($project.downloads -gt 1000000) { 
                    "{0:N1}M" -f ($project.downloads / 1000000) 
                } elseif ($project.downloads -gt 1000) { 
                    "{0:N1}K" -f ($project.downloads / 1000) 
                } else { 
                    $project.downloads.ToString() 
                }
                
                Write-Host "$($i + 1). " -NoNewline -ForegroundColor White
                Write-Host "$($project.title)" -NoNewline -ForegroundColor Green
                Write-Host " ($projectType)" -NoNewline -ForegroundColor Gray
                Write-Host " - $downloads downloads" -ForegroundColor Gray
                Write-Host "    ID: $($project.project_id)" -ForegroundColor DarkGray
                Write-Host "    $($project.description)" -ForegroundColor Gray
                Write-Host ""
            }
            
            # Get user selection
            do {
                $selection = Read-Host "Select a project (1-$($projects.Count)) or 'q' to quit"
                
                if ($selection -eq 'q' -or $selection -eq 'quit') {
                    Write-Host "Search cancelled" -ForegroundColor Yellow
                    return $null
                }
                
                if ([int]::TryParse($selection, [ref]$null) -and 
                    [int]$selection -ge 1 -and 
                    [int]$selection -le $projects.Count) {
                    $selectedProject = $projects[[int]$selection - 1]
                    
                    Write-Host "Selected: $($selectedProject.title) ($($selectedProject.project_id))" -ForegroundColor Green
                    return $selectedProject
                } else {
                    Write-Host "Invalid selection. Please enter a number between 1 and $($projects.Count), or 'q' to quit." -ForegroundColor Red
                }
            } while ($true)
            
        } else {
            # Return all results for non-interactive mode
            return $projects
        }
        
    } catch {
        Write-Host "Error searching Modrinth: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing