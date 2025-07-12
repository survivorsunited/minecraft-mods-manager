# Function to validate version existence on Modrinth API
function Validate-ModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        
        [Parameter(Mandatory=$true)]
        [string]$Version,
        
        [string]$Loader = "fabric",
        
        [string]$ResponseFolder = $ApiResponseFolder,
        
        [string]$Jar,
        
        [switch]$Quiet
    )
    
    try {
        $apiUrl = "$ModrinthApiBaseUrl/project/$ModId/version"
        $responseFile = Get-ApiResponsePath -ModId $ModId -ResponseType "versions" -Domain "modrinth" -BaseResponseFolder $ResponseFolder
        
        # Check if we should use cached responses
        if ($UseCachedResponses -and (Test-Path $responseFile)) {
            if (-not $Quiet) {
                Write-Host ("  → Using cached response for {0}..." -f $ModId) -ForegroundColor DarkGray
            }
            $response = Get-Content -Path $responseFile -Raw | ConvertFrom-Json
        } else {
            # Make API request for versions
            if (-not $Quiet) {
                Write-Host ("  → Calling API for {0}..." -f $ModId) -ForegroundColor DarkGray
            }
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ContentType "application/json"
            
            # Save full response to file
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        }
        
        # Filter versions by loader
        $filteredResponse = $response | Where-Object { $_.loaders -contains $Loader.Trim() }
        
        # Get project information to access game_versions field
        $projectInfo = Get-ModrinthProjectInfo -ModId $ModId -ResponseFolder $ResponseFolder -Quiet:$Quiet
        
        # Determine the latest version using project API response game_versions field
        $latestVersion = "No $Loader versions found"
        $latestVerObj = $null
        
        if ($projectInfo.ProjectInfo -and $projectInfo.ProjectInfo.game_versions -and $projectInfo.ProjectInfo.game_versions.Count -gt 0) {
            # Get the last entry in the game_versions array as the latest
            $latestGameVersion = $projectInfo.ProjectInfo.game_versions[-1]
            
            # Find the latest version for this game version and loader
            $latestVerObj = $filteredResponse | Where-Object { 
                $_.game_versions -contains $latestGameVersion 
            } | Sort-Object -Property "date_published" -Descending | Select-Object -First 1
            
            if ($latestVerObj) {
                $latestVersion = $latestVerObj.version_number
            }
        }
        
        # Find the specific version we're looking for
        $normalizedVersion = Normalize-Version -Version $Version
        $foundVersion = $filteredResponse | Where-Object { 
            Normalize-Version -Version $_.version_number -eq $normalizedVersion 
        } | Select-Object -First 1
        
        if ($foundVersion) {
            $versionUrl = $foundVersion.files | Where-Object { $_.primary } | Select-Object -First 1 -ExpandProperty url
            $latestVersionUrl = if ($latestVerObj) { 
                $latestVerObj.files | Where-Object { $_.primary } | Select-Object -First 1 -ExpandProperty url 
            } else { "" }
            
            return [PSCustomObject]@{
                Exists = $true
                VersionUrl = $versionUrl
                LatestVersionUrl = $latestVersionUrl
                LatestVersion = $latestVersion
                LatestGameVersion = if ($projectInfo.ProjectInfo.game_versions) { $projectInfo.ProjectInfo.game_versions[-1] } else { "" }
                IconUrl = $projectInfo.IconUrl
                ClientSide = $projectInfo.ClientSide
                ServerSide = $projectInfo.ServerSide
                Title = $projectInfo.Title
                ProjectDescription = $projectInfo.ProjectDescription
                IssuesUrl = $projectInfo.IssuesUrl
                SourceUrl = $projectInfo.SourceUrl
                WikiUrl = $projectInfo.WikiUrl
                AvailableGameVersions = if ($projectInfo.ProjectInfo.game_versions) { $projectInfo.ProjectInfo.game_versions -join "," } else { "" }
            }
        } else {
            return [PSCustomObject]@{
                Exists = $false
                VersionUrl = ""
                LatestVersionUrl = ""
                LatestVersion = $latestVersion
                LatestGameVersion = if ($projectInfo.ProjectInfo.game_versions) { $projectInfo.ProjectInfo.game_versions[-1] } else { "" }
                IconUrl = $projectInfo.IconUrl
                ClientSide = $projectInfo.ClientSide
                ServerSide = $projectInfo.ServerSide
                Title = $projectInfo.Title
                ProjectDescription = $projectInfo.ProjectDescription
                IssuesUrl = $projectInfo.IssuesUrl
                SourceUrl = $projectInfo.SourceUrl
                WikiUrl = $projectInfo.WikiUrl
                AvailableGameVersions = if ($projectInfo.ProjectInfo.game_versions) { $projectInfo.ProjectInfo.game_versions -join "," } else { "" }
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            VersionUrl = ""
            LatestVersionUrl = ""
            LatestVersion = "Error"
            LatestGameVersion = ""
            IconUrl = ""
            ClientSide = ""
            ServerSide = ""
            Title = ""
            ProjectDescription = ""
            IssuesUrl = ""
            SourceUrl = ""
            WikiUrl = ""
            AvailableGameVersions = ""
            Error = $_.Exception.Message
        }
    }
} 