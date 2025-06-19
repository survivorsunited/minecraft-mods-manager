# Minecraft Mod Manager PowerShell Script
# Uses modlist.csv as data source and Modrinth API for version checking

# Command line parameters
param(
    [switch]$Download,
    [switch]$UseLatestVersion,
    [switch]$ForceDownload,
    [switch]$Help,
    [switch]$ValidateModVersion,
    [switch]$ValidateAllModVersions,
    [switch]$DownloadMods,
    [switch]$GetModList,
    [switch]$ShowHelp,
    [switch]$AddMod,
    [string]$AddModID,
    [string]$AddModName,
    [string]$AddModLoader,
    [string]$AddModGameVersion,
    [string]$AddModType,
    [string]$AddModGroup
)

# Load environment variables from .env file
function Load-EnvironmentVariables {
    if (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            if ($_ -match "^([^#][^=]+)=(.*)$") {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                Set-Variable -Name $name -Value $value -Scope Global
            }
        }
    }
}

# Load environment variables
Load-EnvironmentVariables

# Configuration
$ModListPath = "modlist.csv"
$ApiResponseFolder = "apiresponse"

# API URLs from environment variables or defaults
$ModrinthApiBaseUrl = if ($env:MODRINTH_API_BASE_URL) { $env:MODRINTH_API_BASE_URL } else { "https://api.modrinth.com/v2" }
$CurseForgeApiBaseUrl = if ($env:CURSEFORGE_API_BASE_URL) { $env:CURSEFORGE_API_BASE_URL } else { "https://www.curseforge.com/api/v1" }
$CurseForgeApiKey = $env:CURSEFORGE_API_KEY

# Default settings from environment variables
$DefaultLoader = if ($env:DEFAULT_LOADER) { $env:DEFAULT_LOADER } else { "fabric" }
$DefaultGameVersion = if ($env:DEFAULT_GAME_VERSION) { $env:DEFAULT_GAME_VERSION } else { "1.21.5" }
$DefaultModType = if ($env:DEFAULT_MOD_TYPE) { $env:DEFAULT_MOD_TYPE } else { "mod" }

# Create API response folder if it doesn't exist
if (-not (Test-Path $ApiResponseFolder)) {
    New-Item -ItemType Directory -Path $ApiResponseFolder -Force | Out-Null
    Write-Host "Created API response folder: $ApiResponseFolder" -ForegroundColor Green
}

# Function to load mod list from CSV
function Get-ModList {
    param(
        [string]$CsvPath = $ModListPath
    )
    
    try {
        if (-not (Test-Path $CsvPath)) {
            throw "Mod list CSV file not found: $CsvPath"
        }
        
        $mods = Import-Csv -Path $CsvPath
        Write-Host "Loaded $($mods.Count) mods from $CsvPath" -ForegroundColor Green
        return $mods
    }
    catch {
        Write-Error "Failed to load mod list: $($_.Exception.Message)"
        return $null
    }
}

# Function to normalize version strings for comparison
function Normalize-Version {
    param(
        [string]$Version
    )
    
    if ([string]::IsNullOrEmpty($Version)) {
        return $Version
    }
    
    # Remove common prefixes
    $normalized = $Version.Trim()
    $normalized = $normalized -replace '^v', ''  # Remove 'v' prefix
    $normalized = $normalized -replace '^version', ''  # Remove 'version' prefix
    $normalized = $normalized -replace '^release', ''  # Remove 'release' prefix
    $normalized = $normalized.Trim()
    
    # Remove common suffixes that might be added by the API
    $normalized = $normalized -replace '\+fabric$', ''  # Remove '+fabric' suffix
    $normalized = $normalized -replace '\+neoforge$', ''  # Remove '+neoforge' suffix
    $normalized = $normalized -replace '\+forge$', ''  # Remove '+forge' suffix
    $normalized = $normalized -replace '\+mod$', ''  # Remove '+mod' suffix
    
    return $normalized
}

# Function to fetch project information from Modrinth API
function Get-ModrinthProjectInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        
        [string]$ResponseFolder = $ApiResponseFolder
    )
    
    try {
        $apiUrl = "$ModrinthApiBaseUrl/project/$ModId"
        $responseFile = Join-Path $ResponseFolder "$ModId-project.json"
        
        # Make API request
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ContentType "application/json"
        
        # Save full response to file
        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        
        # Extract fields
        $iconUrl = $response.icon_url
        $clientSide = $response.client_side
        $serverSide = $response.server_side
        $title = $response.title
        $projectDescription = $response.description
        $issuesUrl = $response.issues_url
        $sourceUrl = $response.source_url
        $wikiUrl = $response.wiki_url
        
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
            IconUrl = $null
            ClientSide = $null
            ServerSide = $null
            Title = $null
            ProjectDescription = $null
            IssuesUrl = $null
            SourceUrl = $null
            WikiUrl = $null
            ProjectInfo = $null
            ResponseFile = $null
            Error = $_.Exception.Message
        }
    }
}

# Function to validate version existence on Modrinth API
function Validate-ModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        
        [Parameter(Mandatory=$true)]
        [string]$Version,
        
        [string]$Loader = "fabric",
        
        [string]$ResponseFolder = $ApiResponseFolder,
        
        [string]$Jar
    )
    
    try {
        $apiUrl = "$ModrinthApiBaseUrl/project/$ModId/version"
        $responseFile = Join-Path $ResponseFolder "$ModId-versions.json"
        
        # Make API request for versions
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ContentType "application/json"
        
        # Filter versions by loader
        $filteredResponse = $response | Where-Object { $_.loaders -contains $Loader.Trim() }
        
        # Save full response to file
        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        
        # Get latest version for display (filtered by loader)
        $latestVersion = $filteredResponse.version_number | Select-Object -First 1
        $latestVersionStr = if ($latestVersion) { $latestVersion } else { "No $Loader versions found" }
        
        # Handle "latest" version parameter
        if ($Version -eq "latest") {
            # For "latest" requests, always return the latest version as found
            $versionExists = $true
            $matchingVersion = $filteredResponse | Select-Object -First 1
            $normalizedExpectedVersion = Normalize-Version -Version $latestVersion
        } else {
            # Normalize the expected version for comparison
            $normalizedExpectedVersion = Normalize-Version -Version $Version
        }
        
        # Check if the specific version exists (in filtered results)
        $versionExists = $false
        $matchingVersion = $null
        $versionUrl = $null
        $latestVersionUrl = $null
        $versionFoundByJar = $false
        
        # Find matching version and extract URL
        if ($Version -ne "latest") {
            foreach ($ver in $filteredResponse) {
                $normalizedApiVersion = Normalize-Version -Version $ver.version_number
                
                # Try exact match first
                if ($normalizedApiVersion -eq $normalizedExpectedVersion) {
                    $versionExists = $true
                    $matchingVersion = $ver
                    # Extract download URL
                    if ($ver.files -and $ver.files.Count -gt 0) {
                        $primaryFile = $ver.files | Where-Object { $_.primary -eq $true } | Select-Object -First 1
                        if (-not $primaryFile) {
                            $primaryFile = $ver.files | Select-Object -First 1
                        }
                        $versionUrl = $primaryFile.url
                    }
                    break
                }
            }
        }
        
        # If exact version match failed, try matching by JAR filename
        if (-not $versionExists -and -not [string]::IsNullOrEmpty($Jar)) {
            $jarToMatch = $Jar.ToLower().Trim()
            foreach ($ver in $filteredResponse) {
                if ($ver.files -and $ver.files.Count -gt 0) {
                    foreach ($file in $ver.files) {
                        if ($file.filename.ToLower().Trim() -eq $jarToMatch) {
                            $versionExists = $true
                            $matchingVersion = $ver
                            $versionUrl = $file.url
                            $versionFoundByJar = $true
                            # Update the expected version to match what we found
                            $normalizedExpectedVersion = Normalize-Version -Version $ver.version_number
                            break
                        }
                    }
                    if ($versionExists) { break }
                }
            }
        }
        
        # Extract download URL for matching version (including "latest")
        if ($versionExists -and $matchingVersion -and -not $versionUrl) {
            if ($matchingVersion.files -and $matchingVersion.files.Count -gt 0) {
                $primaryFile = $matchingVersion.files | Where-Object { $_.primary -eq $true } | Select-Object -First 1
                if (-not $primaryFile) {
                    $primaryFile = $matchingVersion.files | Select-Object -First 1
                }
                $versionUrl = $primaryFile.url
            }
        }
        
        # Extract latest version URL
        if ($filteredResponse.Count -gt 0) {
            $latestVer = $filteredResponse[0]  # First one is latest
            if ($latestVer.files -and $latestVer.files.Count -gt 0) {
                $latestVersionUrl = $latestVer.files[0].url
            }
        }
        
        # Fetch project information including icon URL
        $projectInfo = Get-ModrinthProjectInfo -ModId $ModId -ResponseFolder $ResponseFolder
        
        # Display mod and latest version
        if ($versionExists) {
            # Get latest game version for the latest version
            $latestGameVersion = $null
            if ($response -and $response.Count -gt 0) {
                # Always use the first entry (latest version) for LatestGameVersion
                $latestVerObj = $response | Select-Object -First 1
                if ($latestVerObj -and $latestVerObj.game_versions -and $latestVerObj.game_versions.Count -gt 0) {
                    # Get the last (highest) game version from the array
                    $latestGameVersion = $latestVerObj.game_versions[-1]
                }
            }

            return [PSCustomObject]@{
                Exists = $true
                AvailableVersions = $filteredResponse.version_number
                LatestVersion = $latestVersion
                VersionUrl = $versionUrl
                LatestVersionUrl = $latestVersionUrl
                IconUrl = $projectInfo.IconUrl
                ClientSide = $projectInfo.ClientSide
                ServerSide = $projectInfo.ServerSide
                Title = $projectInfo.Title
                ProjectDescription = $projectInfo.ProjectDescription
                IssuesUrl = $projectInfo.IssuesUrl
                SourceUrl = $projectInfo.SourceUrl
                WikiUrl = $projectInfo.WikiUrl
                ResponseFile = $responseFile
                VersionFoundByJar = $versionFoundByJar
                LatestGameVersion = $latestGameVersion
            }
        } else {
            return [PSCustomObject]@{
                Exists = $false
                AvailableVersions = $filteredResponse.version_number
                LatestVersion = $latestVersion
                VersionUrl = $null
                LatestVersionUrl = $latestVersionUrl
                IconUrl = $projectInfo.IconUrl
                ClientSide = $projectInfo.ClientSide
                ServerSide = $projectInfo.ServerSide
                Title = $projectInfo.Title
                ProjectDescription = $projectInfo.ProjectDescription
                IssuesUrl = $projectInfo.IssuesUrl
                SourceUrl = $projectInfo.SourceUrl
                WikiUrl = $projectInfo.WikiUrl
                ResponseFile = $responseFile
                VersionFoundByJar = $false
                LatestGameVersion = $null
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            AvailableVersions = $null
            LatestVersion = $null
            VersionUrl = $null
            LatestVersionUrl = $null
            IconUrl = $null
            ResponseFile = $null
            VersionFoundByJar = $false
            LatestGameVersion = $null
            Error = $_.Exception.Message
        }
    }
}

# Function to validate version existence on CurseForge API
function Validate-CurseForgeModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$Loader = "fabric",
        [string]$ResponseFolder = $ApiResponseFolder,
        [string]$Jar,
        [string]$ModUrl
    )
    try {
        $apiUrl = "$CurseForgeApiBaseUrl/mods/$ModId/files"
        $responseFile = Join-Path $ResponseFolder "$ModId-curseforge-versions.json"
        $headers = @{ "Content-Type" = "application/json" }
        if ($CurseForgeApiKey) { $headers["X-API-Key"] = $CurseForgeApiKey }
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers
        $filteredResponse = $response.data | Where-Object { $_.gameVersions -contains $Loader.Trim() -and $_.gameVersions -contains $DefaultGameVersion }
        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        $latestVersion = $filteredResponse.displayName | Select-Object -First 1
        $latestVersionStr = if ($latestVersion) { $latestVersion } else { "No $Loader versions found" }
        $normalizedExpectedVersion = Normalize-Version -Version $Version
        $versionExists = $false
        $matchingFile = $null
        $versionUrl = $null
        $latestVersionUrl = $null
        $versionFoundByJar = $false
        foreach ($file in $response.data) {
            $normalizedApiVersion = Normalize-Version -Version $file.displayName
            if ($normalizedApiVersion -eq $normalizedExpectedVersion) {
                $versionExists = $true
                $matchingFile = $file
                $versionUrl = $file.downloadUrl
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
        }
        if ($versionExists) {
            return [PSCustomObject]@{
                Exists = $true
                AvailableVersions = $filteredResponse.displayName
                LatestVersion = $latestVersion
                VersionUrl = $versionUrl
                LatestVersionUrl = $latestVersionUrl
                ResponseFile = $responseFile
                VersionFoundByJar = $versionFoundByJar
                FileName = $matchingFile.fileName
                LatestFileName = if ($filteredResponse.Count -gt 0) { $filteredResponse[0].fileName } else { $null }
            }
        } else {
            return [PSCustomObject]@{
                Exists = $false
                AvailableVersions = $filteredResponse.displayName
                LatestVersion = $latestVersion
                VersionUrl = $null
                LatestVersionUrl = $latestVersionUrl
                ResponseFile = $responseFile
                VersionFoundByJar = $versionFoundByJar
                FileName = $null
                LatestFileName = if ($filteredResponse.Count -gt 0) { $filteredResponse[0].fileName } else { $null }
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
            Error = $_.Exception.Message
        }
    }
}

# Function to ensure CSV has required columns
function Ensure-CsvColumns {
    param(
        [string]$CsvPath = $ModListPath
    )
    
    try {
        $mods = Import-Csv -Path $CsvPath
        $headers = $mods[0].PSObject.Properties.Name
        
        $needsUpdate = $false
        
        # Check if GameVersion column exists
        if ($headers -notcontains "GameVersion") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "GameVersion" -Value "1.21.5"
            }
            $needsUpdate = $true
        }
        
        # Check if Type column exists
        if ($headers -notcontains "Type") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "Type" -Value "mod"
            }
            $needsUpdate = $true
        }
        
        # Check if LatestVersion column exists
        if ($headers -notcontains "LatestVersion") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "LatestVersion" -Value ""
            }
            $needsUpdate = $true
        }
        
        # Check if VersionUrl column exists
        if ($headers -notcontains "VersionUrl") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "VersionUrl" -Value ""
            }
            $needsUpdate = $true
        }
        
        # Check if LatestVersionUrl column exists
        if ($headers -notcontains "LatestVersionUrl") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "LatestVersionUrl" -Value ""
            }
            $needsUpdate = $true
        }
        
        # Check if IconUrl column exists
        if ($headers -notcontains "IconUrl") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "IconUrl" -Value ""
            }
            $needsUpdate = $true
        }
        
        # Add new columns for Modrinth project info if missing
        $newColumns = @("ClientSide", "ServerSide", "Title", "ProjectDescription", "IssuesUrl", "SourceUrl", "WikiUrl")
        foreach ($col in $newColumns) {
            if ($headers -notcontains $col) {
                foreach ($mod in $mods) {
                    $mod | Add-Member -MemberType NoteProperty -Name $col -Value ""
                }
                $needsUpdate = $true
            }
        }
        
        # Check if Host column exists
        if ($headers -notcontains "Host") {
            foreach ($mod in $mods) {
                # Default to Modrinth, but set CurseForge for known CurseForge mods
                $modHost = "modrinth"
                if ($mod.ID -eq "357540" -or $mod.ID -eq "invhud_configurable") {
                    $modHost = "curseforge"
                }
                $mod | Add-Member -MemberType NoteProperty -Name "Host" -Value $modHost
            }
            $needsUpdate = $true
        }
        
        # Check if LatestGameVersion column exists
        if ($headers -notcontains "LatestGameVersion") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "LatestGameVersion" -Value ""
            }
            $needsUpdate = $true
        }
        
        if ($needsUpdate) {
            # Create backup before updating
            $backupPath = $CsvPath -replace '\.csv$', '-columns-backup.csv'
            Copy-Item -Path $CsvPath -Destination $backupPath
            
            # Save updated CSV
            $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        }
        
        return $mods
    }
    catch {
        Write-Error "Failed to ensure CSV columns: $($_.Exception.Message)"
        return $null
    }
}

# Function to update modlist with latest versions
function Update-ModListWithLatestVersions {
    param(
        [string]$CsvPath = $ModListPath,
        [array]$ValidationResults
    )
    
    try {
        # Ensure CSV has required columns
        $mods = Ensure-CsvColumns -CsvPath $CsvPath
        if (-not $mods) {
            return 0
        }
        
        # Create a backup of the original file
        $backupPath = $CsvPath -replace '\.csv$', '-backup.csv'
        Copy-Item -Path $CsvPath -Destination $backupPath
        
        # Update mods with URLs only (DO NOT UPDATE VERSION COLUMN)
        $updatedCount = 0
        $updateSummary = @()
        
        foreach ($mod in $mods) {
            $result = $ValidationResults | Where-Object { $_.ID -eq $mod.ID }
            if ($result) {
                $changes = @()
                $updatedFields = @{
                    LatestVersion = $false
                    VersionUrl = $false
                    LatestVersionUrl = $false
                    IconUrl = $false
                    ClientSide = $false
                    ServerSide = $false
                    Title = $false
                    ProjectDescription = $false
                    IssuesUrl = $false
                    SourceUrl = $false
                    WikiUrl = $false
                    Version = $false
                    LatestGameVersion = $false
                }
                
                # Update LatestVersion if available
                if ($result.LatestVersion -and $result.LatestVersion -ne $mod.LatestVersion) {
                    $mod.LatestVersion = $result.LatestVersion
                    $updatedFields.LatestVersion = $true
                }
                
                # Update VersionUrl if available (for current expected version)
                if ($result.VersionUrl -and $result.VersionUrl -ne $mod.VersionUrl) {
                    $mod.VersionUrl = $result.VersionUrl
                    $updatedFields.VersionUrl = $true
                }
                
                # Update LatestVersionUrl if available
                if ($result.LatestVersionUrl -and $result.LatestVersionUrl -ne $mod.LatestVersionUrl) {
                    $mod.LatestVersionUrl = $result.LatestVersionUrl
                    $updatedFields.LatestVersionUrl = $true
                }
                
                # Update IconUrl if available
                if ($result.IconUrl -and $result.IconUrl -ne $mod.IconUrl) {
                    $mod.IconUrl = $result.IconUrl
                    $updatedFields.IconUrl = $true
                }
                
                # Update new Modrinth project info fields if available
                if ($result.ClientSide -and $result.ClientSide -ne $mod.ClientSide) {
                    $mod.ClientSide = $result.ClientSide
                    $updatedFields.ClientSide = $true
                }
                if ($result.ServerSide -and $result.ServerSide -ne $mod.ServerSide) {
                    $mod.ServerSide = $result.ServerSide
                    $updatedFields.ServerSide = $true
                }
                if ($result.Title -and $result.Title -ne $mod.Title) {
                    $mod.Title = $result.Title
                    $updatedFields.Title = $true
                }
                if ($result.ProjectDescription -and $result.ProjectDescription -ne $mod.ProjectDescription) {
                    $mod.ProjectDescription = $result.ProjectDescription
                    $updatedFields.ProjectDescription = $true
                }
                if ($result.IssuesUrl -and $result.IssuesUrl -ne $mod.IssuesUrl) {
                    $mod.IssuesUrl = $result.IssuesUrl
                    $updatedFields.IssuesUrl = $true
                }
                if ($result.SourceUrl -and $result.SourceUrl -ne $mod.SourceUrl) {
                    $mod.SourceUrl = $result.SourceUrl
                    $updatedFields.SourceUrl = $true
                }
                if ($result.WikiUrl -and $result.WikiUrl -ne $mod.WikiUrl) {
                    $mod.WikiUrl = $result.WikiUrl
                    $updatedFields.WikiUrl = $true
                }
                
                # Special case: If version was found by JAR filename, update the Version column
                # This is needed for the patcher to work correctly
                if ($result.VersionFoundByJar -and $result.ExpectedVersion -ne $mod.Version) {
                    $mod.Version = $result.ExpectedVersion
                    $updatedFields.Version = $true
                }
                
                # Update LatestGameVersion if available
                if ($result.LatestGameVersion -and $result.LatestGameVersion -ne $mod.LatestGameVersion) {
                    $mod.LatestGameVersion = $result.LatestGameVersion
                    $changes += "LatestGameVersion: updated"
                }
                
                # Check if any fields were updated
                $anyUpdates = $updatedFields.Values -contains $true
                if ($anyUpdates) {
                    $updatedCount++
                    $updateSummary += [PSCustomObject]@{
                        Name = $mod.Name
                        LatestVersion = if ($updatedFields.LatestVersion) { "✓" } else { "" }
                        VersionUrl = if ($updatedFields.VersionUrl) { "✓" } else { "" }
                        LatestVersionUrl = if ($updatedFields.LatestVersionUrl) { "✓" } else { "" }
                        IconUrl = if ($updatedFields.IconUrl) { "✓" } else { "" }
                        ClientSide = if ($updatedFields.ClientSide) { "✓" } else { "" }
                        ServerSide = if ($updatedFields.ServerSide) { "✓" } else { "" }
                        Title = if ($updatedFields.Title) { "✓" } else { "" }
                        ProjectDescription = if ($updatedFields.ProjectDescription) { "✓" } else { "" }
                        IssuesUrl = if ($updatedFields.IssuesUrl) { "✓" } else { "" }
                        SourceUrl = if ($updatedFields.SourceUrl) { "✓" } else { "" }
                        WikiUrl = if ($updatedFields.WikiUrl) { "✓" } else { "" }
                        Version = if ($updatedFields.Version) { "✓" } else { "" }
                        LatestGameVersion = if ($updatedFields.LatestGameVersion) { "✓" } else { "" }
                    }
                }
            }
        }
        
        # Save updated modlist
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        
        # Display summary table
        if ($updateSummary.Count -gt 0) {
            Write-Host ""
            Write-Host "Update Summary:" -ForegroundColor Yellow
            Write-Host "==============" -ForegroundColor Yellow
            $updateSummary | Format-Table -AutoSize | Out-Host
        }
        
        return $updatedCount
    }
    catch {
        Write-Error "Failed to update modlist: $($_.Exception.Message)"
        return 0
    }
}

# Function to validate all mods in the list
function Validate-AllModVersions {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$ResponseFolder = $ApiResponseFolder,
        [switch]$UpdateModList
    )
    
    $mods = Get-ModList -CsvPath $CsvPath
    if (-not $mods) {
        return
    }
    
    $results = @()
    
    Write-Host "Validating mod versions and saving API responses..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($mod in $mods) {
        if (-not [string]::IsNullOrEmpty($mod.ID)) {
            # Get loader from CSV, default to "fabric" if not specified
            $loader = if (-not [string]::IsNullOrEmpty($mod.Loader)) { $mod.Loader.Trim() } else { $DefaultLoader }
            
            # Get host from CSV, default to "modrinth" if not specified
            $modHost = if (-not [string]::IsNullOrEmpty($mod.Host)) { $mod.Host } else { "modrinth" }
            
            # Get game version from CSV, default to "1.21.5" if not specified
            $gameVersion = if (-not [string]::IsNullOrEmpty($mod.GameVersion)) { $mod.GameVersion } else { $DefaultGameVersion }
            
            # Get JAR filename from CSV
            $jarFilename = if (-not [string]::IsNullOrEmpty($mod.Jar)) { $mod.Jar } else { "" }
            
            # Use appropriate API based on host
            if ($modHost -eq "curseforge") {
                $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.Version -Loader $loader -ResponseFolder $ResponseFolder -Jar $jarFilename -ModUrl $mod.URL
            } else {
                # If version is empty, treat as "get latest version" request
                $versionToCheck = if ([string]::IsNullOrEmpty($mod.Version)) { "latest" } else { $mod.Version }
                $result = Validate-ModVersion -ModId $mod.ID -Version $versionToCheck -Loader $loader -ResponseFolder $ResponseFolder -Jar $jarFilename
            }
            
            $results += [PSCustomObject]@{
                Name = $mod.Name
                ID = $mod.ID
                ExpectedVersion = $mod.Version
                Loader = $loader
                Host = $modHost
                VersionExists = $result.Exists
                ResponseFile = $result.ResponseFile
                Error = $result.Error
                AvailableVersions = if ($result.AvailableVersions) { $result.AvailableVersions -join ', ' } else { $null }
                LatestVersion = $result.LatestVersion
                VersionUrl = $result.VersionUrl
                LatestVersionUrl = $result.LatestVersionUrl
                IconUrl = $result.IconUrl
                ClientSide = $result.ClientSide
                ServerSide = $result.ServerSide
                Title = $result.Title
                ProjectDescription = $result.ProjectDescription
                IssuesUrl = $result.IssuesUrl
                SourceUrl = $result.SourceUrl
                WikiUrl = $result.WikiUrl
                VersionFoundByJar = $result.VersionFoundByJar
                LatestGameVersion = $result.LatestGameVersion
            }
        }
    }
    
    # Save results to CSV
    $resultsFile = Join-Path $ResponseFolder "version-validation-results.csv"
    $results | Export-Csv -Path $resultsFile -NoTypeInformation
    
    # Update modlist with latest versions if requested
    if ($UpdateModList) {
        Write-Host ""
        Write-Host "Updating modlist with latest versions and URLs..." -ForegroundColor Yellow
        $updatedCount = Update-ModListWithLatestVersions -CsvPath $CsvPath -ValidationResults $results
        if ($updatedCount -gt 0) {
            Write-Host "Updated $updatedCount mods with latest versions!" -ForegroundColor Green
        } else {
            Write-Host "No updates needed - all mods are already at latest versions." -ForegroundColor Yellow
        }
    }
    
    # Display summary
    $foundCount = ($results | Where-Object { $_.VersionExists }).Count
    $missingCount = ($results | Where-Object { -not $_.VersionExists }).Count
    
    Write-Host ""
    Write-Host "Summary: $foundCount found, $missingCount missing"

    # Only show missing mods/datapacks
    if ($missingCount -gt 0) {
        Write-Host ""
        Write-Host "Missing mods:"
        foreach ($result in $results | Where-Object { -not $_.VersionExists }) {
            $msg = "❌ $($result.Name) (ID: $($result.ID)) | Expected: $($result.ExpectedVersion) | Host: $($result.Host)"
            if ($result.Error) {
                $msg += " | Error: $($result.Error)"
            }
            Write-Host $msg
        }
    }
}

# Function to show help information
function Show-Help {
    Write-Host "`n=== MINECRAFT MOD MANAGER - HELP ===" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "FUNCTIONS:" -ForegroundColor Yellow
    Write-Host "  Get-ModList [-CsvPath <path>]" -ForegroundColor White
    Write-Host "    - Loads and displays mods from CSV file"
    Write-Host "    - Default path: $ModListPath"
    Write-Host ""
    Write-Host "  Validate-ModVersion -ModId <id> -Version <version> [-Loader <loader>] [-ResponseFolder <path>]" -ForegroundColor White
    Write-Host "    - Validates if a specific mod version exists on Modrinth"
    Write-Host "    - Extracts download URLs from API response"
    Write-Host "    - Saves API response to JSON file"
    Write-Host "    - Default loader: fabric"
    Write-Host "    - Default response folder: $ApiResponseFolder"
    Write-Host ""
    Write-Host "  Validate-AllModVersions [-CsvPath <path>] [-ResponseFolder <path>] [-UpdateModList]" -ForegroundColor White
    Write-Host "    - Validates all mods in the CSV file"
    Write-Host "    - Shows green output for existing versions, red for missing"
    Write-Host "    - Displays latest available version for each mod"
    Write-Host "    - Extracts VersionUrl and LatestVersionUrl from API responses"
    Write-Host "    - Saves validation results to CSV"
    Write-Host "    - -UpdateModList: Updates modlist.csv with download URLs (preserves Version column)"
    Write-Host "    - Creates backup before updating modlist"
    Write-Host ""
    Write-Host "  Download-Mods [-CsvPath <path>] [-ModsFolder <path>] [-UseLatestVersion] [-ForceDownload]" -ForegroundColor White
    Write-Host "    - Downloads mods to local mods folder organized by GameVersion"
    Write-Host "    - Creates subfolders for each GameVersion (e.g., mods/1.21.5/)"
    Write-Host "    - Uses VersionUrl by default, or LatestVersionUrl with -UseLatestVersion"
    Write-Host "    - Skips existing files unless -ForceDownload is used"
    Write-Host "    - Saves download results to CSV"
    Write-Host "    - Default mods folder: mods"
    Write-Host ""
    Write-Host "  Show-Help" -ForegroundColor White
    Write-Host "    - Shows this help information"
    Write-Host ""
    Write-Host "USAGE EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\ModManager.ps1" -ForegroundColor White
    Write-Host "    - Runs automatic validation of all mods and updates modlist with download URLs"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -Download" -ForegroundColor White
    Write-Host "    - Validates all mods and downloads them to mods/ folder organized by GameVersion"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -Download -UseLatestVersion" -ForegroundColor White
    Write-Host "    - Downloads latest versions of all mods instead of current versions"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -Download -ForceDownload" -ForegroundColor White
    Write-Host "    - Downloads all mods, overwriting existing files"
    Write-Host ""
    Write-Host "  Validate-ModVersion -ModId 'fabric-api' -Version '0.91.0+1.20.1'" -ForegroundColor White
    Write-Host "    - Validates Fabric API version 0.91.0+1.20.1 and extracts download URLs"
    Write-Host ""
    Write-Host "  Validate-AllModVersions -UpdateModList" -ForegroundColor White
    Write-Host "    - Validates all mods and updates modlist.csv with download URLs (preserves Version column)"
    Write-Host ""
    Write-Host "  Download-Mods -UseLatestVersion" -ForegroundColor White
    Write-Host "    - Downloads latest versions of all mods to mods/ folder"
    Write-Host ""
    Write-Host "  Get-ModList" -ForegroundColor White
    Write-Host "    - Shows all mods from modlist.csv"
    Write-Host ""
    Write-Host "OUTPUT FORMAT:" -ForegroundColor Yellow
    Write-Host "  ✓ ModID | Expected: version | Latest (loader): latest_version" -ForegroundColor Green
    Write-Host "  ✗ ModID | Expected: version | Latest (loader): latest_version" -ForegroundColor Red
    Write-Host ""
    Write-Host "CSV COLUMNS:" -ForegroundColor Yellow
    Write-Host "  Name, Version, URL, Description, Group, Category, Jar, ID, Loader, VersionUrl, LatestVersionUrl" -ForegroundColor White
    Write-Host "  - VersionUrl: Direct download URL for the current version" -ForegroundColor Gray
    Write-Host "  - LatestVersionUrl: Direct download URL for the latest available version" -ForegroundColor Gray
    Write-Host ""
    Write-Host "FILES:" -ForegroundColor Yellow
    Write-Host "  Input:  $ModListPath" -ForegroundColor White
    Write-Host "  Output: $ApiResponseFolder\*.json (API responses)" -ForegroundColor White
    Write-Host "  Output: $ApiResponseFolder\version-validation-results.csv (validation results)" -ForegroundColor White
    Write-Host "  Output: $ApiResponseFolder\mod-download-results.csv (download results)" -ForegroundColor White
    Write-Host "  Output: mods\GameVersion\*.jar (downloaded mods)" -ForegroundColor White
    Write-Host "  Backup: modlist-backup.csv (created before updates)" -ForegroundColor White
    Write-Host "  Backup: modlist-columns-backup.csv (created when adding new columns)" -ForegroundColor White
    Write-Host ""
}

# Function to determine the majority game version from modlist
function Get-MajorityGameVersion {
    param(
        [string]$CsvPath = $ModListPath
    )
    
    try {
        $mods = Get-ModList -CsvPath $CsvPath
        if (-not $mods) {
            return @{
                MajorityVersion = $DefaultGameVersion
                Analysis = $null
            }
        }
        
        # Get all LatestGameVersion values that are not null or empty
        $gameVersions = $mods | Where-Object { -not [string]::IsNullOrEmpty($_.LatestGameVersion) } | Select-Object -ExpandProperty LatestGameVersion
        
        if ($gameVersions.Count -eq 0) {
            return @{
                MajorityVersion = $DefaultGameVersion
                Analysis = $null
            }
        }
        
        # Group by version and count occurrences
        $versionCounts = $gameVersions | Group-Object | Sort-Object Count -Descending
        
        # Get the most common version
        $majorityVersion = $versionCounts[0].Name
        $majorityCount = $versionCounts[0].Count
        $totalCount = $gameVersions.Count
        
        # Calculate percentage
        $percentage = [math]::Round(($majorityCount / $totalCount) * 100, 1)
        
        # Create detailed analysis object
        $analysis = @{
            TotalMods = $totalCount
            MajorityVersion = $majorityVersion
            MajorityCount = $majorityCount
            MajorityPercentage = $percentage
            VersionDistribution = @()
            ModsByVersion = @{}
        }
        
        # Build version distribution and mod lists
        foreach ($versionGroup in $versionCounts) {
            $versionPercentage = [math]::Round(($versionGroup.Count / $totalCount) * 100, 1)
            $analysis.VersionDistribution += @{
                Version = $versionGroup.Name
                Count = $versionGroup.Count
                Percentage = $versionPercentage
            }
            
            # Get list of mods for this version
            $modsForVersion = $mods | Where-Object { $_.LatestGameVersion -eq $versionGroup.Name } | Select-Object Name, ID, Version, LatestVersion
            $analysis.ModsByVersion[$versionGroup.Name] = $modsForVersion
        }
        
        Write-Host "Game Version Analysis:" -ForegroundColor Cyan
        Write-Host "=====================" -ForegroundColor Cyan
        Write-Host "Total mods with LatestGameVersion: $totalCount" -ForegroundColor White
        Write-Host "Majority version: $majorityVersion ($majorityCount mods, $percentage%)" -ForegroundColor Green
        
        # Show all version distributions
        Write-Host ""
        Write-Host "Version distribution:" -ForegroundColor Yellow
        foreach ($versionGroup in $versionCounts) {
            $versionPercentage = [math]::Round(($versionGroup.Count / $totalCount) * 100, 1)
            Write-Host "  $($versionGroup.Name): $($versionGroup.Count) mods ($versionPercentage%)" -ForegroundColor White
        }
        Write-Host ""
        
        return @{
            MajorityVersion = $majorityVersion
            Analysis = $analysis
        }
    }
    catch {
        Write-Host "Error determining majority game version: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            MajorityVersion = $DefaultGameVersion
            Analysis = $null
        }
    }
}

# Function to create README file with download analysis
function Write-DownloadReadme {
    param(
        [string]$FolderPath,
        [object]$Analysis,
        [object]$DownloadResults,
        [string]$TargetVersion,
        [switch]$UseLatestVersion
    )
    
    $readmePath = Join-Path $FolderPath "README.md"
    $readmeContent = @"
# Minecraft Mod Pack - $TargetVersion

Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Game Version Analysis

**Total mods analyzed:** $($Analysis.TotalMods) (out of $($Analysis.TotalMods + 1), one had no LatestGameVersion)
**Majority version:** $($Analysis.MajorityVersion) ($($Analysis.MajorityCount) mods, $($Analysis.MajorityPercentage)%)
**Target version:** $TargetVersion (automatically selected)

## Version Distribution

"@

    foreach ($version in $Analysis.VersionDistribution) {
        $marker = if ($version.Version -eq $Analysis.MajorityVersion) { " ← Majority" } else { "" }
        $readmeContent += "`n**$($version.Version):** $($version.Count) mods ($($version.Percentage)%)$marker"
        
        # Add mod list for this version
        $readmeContent += "`n`n  **Mods for $($version.Version):**`n"
        foreach ($mod in $Analysis.ModsByVersion[$version.Version]) {
            $readmeContent += "  - $($mod.Name) (ID: $($mod.ID)) - Current: $($mod.Version), Latest: $($mod.LatestVersion)`n"
        }
        $readmeContent += "`n"
    }

    $readmeContent += @"

## Download Results

**✅ Successfully downloaded:** $(($DownloadResults | Where-Object { $_.Status -eq "Success" }).Count) mods
**⏭️ Skipped (already exists):** $(($DownloadResults | Where-Object { $_.Status -eq "Skipped" }).Count) mods  
**❌ Failed:** $(($DownloadResults | Where-Object { $_.Status -eq "Failed" }).Count) mods

**📁 All mods downloaded to:** mods/$TargetVersion/ folder

## Failed Downloads

"@

    $failedMods = $DownloadResults | Where-Object { $_.Status -eq "Failed" }
    if ($failedMods.Count -gt 0) {
        foreach ($failed in $failedMods) {
            $readmeContent += "`n- **$($failed.Name):** $($failed.Error)"
        }
    } else {
        $readmeContent += "`nNo failed downloads."
    }

    $readmeContent += @"

## Download Settings

- **Use Latest Version:** $UseLatestVersion
- **Force Download:** $ForceDownload
- **Target Game Version:** $TargetVersion

## Mod List

"@

    $successfulMods = $DownloadResults | Where-Object { $_.Status -eq "Success" } | Sort-Object Name
    foreach ($mod in $successfulMods) {
        $readmeContent += "`n- **$($mod.Name)** - Version: $($mod.Version) - Size: $($mod.Size)"
    }

    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    Write-Host "Created README.md in: $FolderPath" -ForegroundColor Green
}

# Function to download mods to local mods folder
function Download-Mods {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$ModsFolder = "mods",
        [switch]$UseLatestVersion,
        [switch]$ForceDownload
    )
    
    try {
        $mods = Get-ModList -CsvPath $CsvPath
        if (-not $mods) {
            return
        }
        
        # Determine target game version if using latest versions
        $targetGameVersion = $DefaultGameVersion
        $versionAnalysis = $null
        if ($UseLatestVersion) {
            $versionResult = Get-MajorityGameVersion -CsvPath $CsvPath
            $targetGameVersion = $versionResult.MajorityVersion
            $versionAnalysis = $versionResult.Analysis
            Write-Host "Targeting majority game version: $targetGameVersion" -ForegroundColor Green
            Write-Host ""
        }
        
        # Create mods folder if it doesn't exist
        if (-not (Test-Path $ModsFolder)) {
            New-Item -ItemType Directory -Path $ModsFolder -Force | Out-Null
            Write-Host "Created mods folder: $ModsFolder" -ForegroundColor Green
        } else {
            # Clear only subfolders and their contents, preserve .gitkeep file
            Get-ChildItem -Path $ModsFolder -Directory | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleared all subfolders in: $ModsFolder" -ForegroundColor Yellow
        }
        
        $downloadResults = @()
        $successCount = 0
        $errorCount = 0
        
        Write-Host "Starting mod downloads..." -ForegroundColor Yellow
        Write-Host ""
        
        foreach ($mod in $mods) {
            if (-not [string]::IsNullOrEmpty($mod.ID)) {
                # Get loader from CSV, default to "fabric" if not specified
                $loader = if (-not [string]::IsNullOrEmpty($mod.Loader)) { $mod.Loader.Trim() } else { $DefaultLoader }
                
                # Get host from CSV, default to "modrinth" if not specified
                $modHost = if (-not [string]::IsNullOrEmpty($mod.Host)) { $mod.Host } else { "modrinth" }
                
                # Get game version from CSV, default to "1.21.5" if not specified
                $gameVersion = if (-not [string]::IsNullOrEmpty($mod.GameVersion)) { $mod.GameVersion } else { $DefaultGameVersion }
                
                # Get JAR filename from CSV
                $jarFilename = if (-not [string]::IsNullOrEmpty($mod.Jar)) { $mod.Jar } else { "" }
                
                # Determine which URL to use for download
                $downloadUrl = $null
                $downloadVersion = $null
                $result = $null
                
                if ($UseLatestVersion -and $mod.LatestVersionUrl) {
                    $downloadUrl = $mod.LatestVersionUrl
                    $downloadVersion = $mod.LatestVersion
                    # For CurseForge mods, we still need to get the filename from API
                    if ($modHost -eq "curseforge") {
                        $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.Version -Loader $loader -ResponseFolder $ApiResponseFolder -Jar $jarFilename -ModUrl $mod.URL
                    }
                } elseif ($mod.VersionUrl) {
                    $downloadUrl = $mod.VersionUrl
                    $downloadVersion = $mod.Version
                    # For CurseForge mods, we still need to get the filename from API
                    if ($modHost -eq "curseforge") {
                        $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.Version -Loader $loader -ResponseFolder $ApiResponseFolder -Jar $jarFilename -ModUrl $mod.URL
                    }
                } else {
                    # Need to fetch the URL from API
                    Write-Host "Fetching download URL for $($mod.Name)..." -ForegroundColor Cyan
                    
                    if ($modHost -eq "curseforge") {
                        $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.Version -Loader $loader -ResponseFolder $ApiResponseFolder -Jar $jarFilename -ModUrl $mod.URL
                    } else {
                        $result = Validate-ModVersion -ModId $mod.ID -Version $mod.Version -Loader $loader -ResponseFolder $ApiResponseFolder -Jar $jarFilename
                    }
                    
                    if ($result.Exists) {
                        if ($UseLatestVersion) {
                            $downloadUrl = $result.LatestVersionUrl
                            $downloadVersion = $result.LatestVersion
                        } else {
                            $downloadUrl = $result.VersionUrl
                            $downloadVersion = $mod.Version
                        }
                    } else {
                        Write-Host "❌ $($mod.Name): Version not found" -ForegroundColor Red
                        $errorCount++
                        continue
                    }
                }
                
                if (-not $downloadUrl) {
                    Write-Host "❌ $($mod.Name): No download URL available" -ForegroundColor Red
                    $errorCount++
                    continue
                }
                
                # Create game version subfolder
                $gameVersionFolder = if ($UseLatestVersion) { 
                    Join-Path $ModsFolder $targetGameVersion 
                } else { 
                    $modGameVersion = if ($mod.LatestGameVersion) { $mod.LatestGameVersion } else { $gameVersion }
                    Join-Path $ModsFolder $modGameVersion 
                }
                
                # Create block subfolder if mod is in "block" group
                if ($mod.Group -eq "block") {
                    $gameVersionFolder = Join-Path $gameVersionFolder "block"
                }
                
                if (-not (Test-Path $gameVersionFolder)) {
                    New-Item -ItemType Directory -Path $gameVersionFolder -Force | Out-Null
                }
                
                # Determine filename for download
                $filename = $null
                if ($jarFilename -and -not $UseLatestVersion) {
                    # Use the JAR filename from CSV if available and not using latest version
                    $filename = $jarFilename
                } else {
                    # Extract filename from URL or use mod ID
                    $filename = [System.IO.Path]::GetFileName($downloadUrl)
                    if (-not $filename -or $filename -eq "") {
                        $filename = "$($mod.ID)-$downloadVersion.jar"
                    }
                }
                
                $downloadPath = Join-Path $gameVersionFolder $filename
                
                # Check if file already exists
                if ((Test-Path $downloadPath) -and -not $ForceDownload) {
                    Write-Host "⏭️  $($mod.Name): Already exists ($filename)" -ForegroundColor Yellow
                    $downloadResults += [PSCustomObject]@{
                        Name = $mod.Name
                        Status = "Skipped"
                        Version = $downloadVersion
                        File = $filename
                        Path = $downloadPath
                        Error = "File already exists"
                    }
                    continue
                }
                
                # Download the file
                Write-Host "⬇️  $($mod.Name): Downloading $downloadVersion..." -ForegroundColor Cyan
                
                try {
                    # For CurseForge downloads, use the filename from the API response
                    if ($modHost -eq "curseforge" -and $result.FileName) {
                        $filename = $result.FileName
                        $downloadPath = Join-Path $gameVersionFolder $filename
                        Write-Host "  📝 Using filename from API: $filename" -ForegroundColor Gray
                    }
                    
                    # Use Invoke-WebRequest for better error handling
                    $webRequest = Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
                    
                    if (Test-Path $downloadPath) {
                        $fileSize = (Get-Item $downloadPath).Length
                        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                        
                        Write-Host "✅ $($mod.Name): Downloaded successfully ($fileSizeMB MB)" -ForegroundColor Green
                        
                        $downloadResults += [PSCustomObject]@{
                            Name = $mod.Name
                            Status = "Success"
                            Version = $downloadVersion
                            File = $filename
                            Path = $downloadPath
                            Size = "$fileSizeMB MB"
                            Error = $null
                        }
                        $successCount++
                    } else {
                        throw "File was not created"
                    }
                }
                catch {
                    Write-Host "❌ $($mod.Name): Download failed - $($_.Exception.Message)" -ForegroundColor Red
                    
                    # Clean up partial download if it exists
                    if (Test-Path $downloadPath) {
                        Remove-Item $downloadPath -Force
                    }
                    
                    $downloadResults += [PSCustomObject]@{
                        Name = $mod.Name
                        Status = "Failed"
                        Version = $downloadVersion
                        File = $filename
                        Path = $downloadPath
                        Size = $null
                        Error = $_.Exception.Message
                    }
                    $errorCount++
                }
            }
        }
        
        # Save download results to CSV
        $downloadResultsFile = Join-Path $ApiResponseFolder "mod-download-results.csv"
        $downloadResults | Export-Csv -Path $downloadResultsFile -NoTypeInformation
        
        # Display summary
        Write-Host ""
        Write-Host "Download Summary:" -ForegroundColor Yellow
        Write-Host "=================" -ForegroundColor Yellow
        Write-Host "✅ Successfully downloaded: $successCount" -ForegroundColor Green
        Write-Host "⏭️  Skipped (already exists): $(($downloadResults | Where-Object { $_.Status -eq "Skipped" }).Count)" -ForegroundColor Yellow
        Write-Host "❌ Failed: $errorCount" -ForegroundColor Red
        Write-Host ""
        Write-Host "Download results saved to: $downloadResultsFile" -ForegroundColor Cyan
        
        # Show failed downloads
        if ($errorCount -gt 0) {
            Write-Host ""
            Write-Host "Failed downloads:" -ForegroundColor Red
            foreach ($result in $downloadResults | Where-Object { $_.Status -eq "Failed" }) {
                Write-Host "  ❌ $($result.Name): $($result.Error)" -ForegroundColor Red
            }
        }
        
        # Create README file with download analysis
        if ($versionAnalysis) {
            $versionFolder = Join-Path $ModsFolder $targetGameVersion
            Write-DownloadReadme -FolderPath $versionFolder -Analysis $versionAnalysis -DownloadResults $downloadResults -TargetVersion $targetGameVersion -UseLatestVersion $UseLatestVersion
        }
        
        return $successCount
    }
    catch {
        Write-Error "Failed to download mods: $($_.Exception.Message)"
        return 0
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Minecraft Mod Manager PowerShell Script" -ForegroundColor Magenta
    Write-Host "Starting automatic validation of all mods..." -ForegroundColor Yellow
    Write-Host "Use Show-Help for usage information" -ForegroundColor Yellow
    Write-Host "Available functions: Get-ModList, Validate-ModVersion, Validate-AllModVersions, Show-Help, Download-Mods, Add-Mod" -ForegroundColor Yellow
    Write-Host ""

    if ($Help -or $ShowHelp) {
        Show-Help
        return
    }
    if ($AddMod) {
        # Add a new mod entry to modlist.csv with minimal info
        $id = $AddModID
        $name = $AddModName
        $loader = if ($AddModLoader) { $AddModLoader } else { $DefaultLoader }
        $gameVersion = if ($AddModGameVersion) { $AddModGameVersion } else { $DefaultGameVersion }
        $type = if ($AddModType) { $AddModType } else { $DefaultModType }
        $group = if ($AddModGroup) { $AddModGroup } else { "required" }
        if (-not $id -or -not $name) {
            Write-Host "You must provide at least -AddModID and -AddModName." -ForegroundColor Red
            return
        }
        $newMod = [PSCustomObject]@{
            Group = $group
            Type = $type
            GameVersion = $gameVersion
            ID = $id
            Loader = $loader
            Version = ""
            Name = $name
            Description = ""
            Jar = ""
            Url = ""
            Category = ""
            VersionUrl = ""
            LatestVersionUrl = ""
            LatestVersion = ""
            ApiSource = "modrinth"
            Host = "modrinth"
            IconUrl = ""
            ClientSide = ""
            ServerSide = ""
            Title = ""
            ProjectDescription = ""
            IssuesUrl = ""
            SourceUrl = ""
            WikiUrl = ""
            LatestGameVersion = ""
        }
        $mods = @()
        if (Test-Path $ModListPath) {
            $mods = Import-Csv $ModListPath
        }
        $mods += $newMod
        $mods | Export-Csv -Path $ModListPath -NoTypeInformation
        Write-Host "Added mod $name ($id) to $ModListPath in group '$group'" -ForegroundColor Green
        return
    }
    if ($ValidateModVersion) {
        # Example: Validate-ModVersion -ModId "fabric-api" -Version "0.91.0+1.20.1"
        Write-Host "Validating mod version..." -ForegroundColor Cyan
        # User must provide -ModId and -Version as extra params
        return
    }
    if ($ValidateAllModVersions) {
        Validate-AllModVersions -UpdateModList
        return
    }
    if ($DownloadMods) {
        Download-Mods -UseLatestVersion:$UseLatestVersion -ForceDownload:$ForceDownload
        return
    }
    if ($GetModList) {
        Get-ModList
        return
    }
    # Default: Run validation and update modlist
    Validate-AllModVersions -UpdateModList
    if ($Download) {
        Write-Host ""; Write-Host "Starting mod downloads..." -ForegroundColor Yellow
        $downloadParams = @{}
        if ($UseLatestVersion) { $downloadParams.UseLatestVersion = $true; Write-Host "Using latest versions for downloads" -ForegroundColor Cyan }
        if ($ForceDownload) { $downloadParams.ForceDownload = $true; Write-Host "Force downloading (will overwrite existing files)" -ForegroundColor Cyan }
        $downloadedCount = Download-Mods @downloadParams
        if ($downloadedCount -gt 0) { Write-Host ""; Write-Host "Successfully downloaded $downloadedCount mods!" -ForegroundColor Green }
    }
} 

