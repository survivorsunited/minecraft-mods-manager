# Cross-Platform Modpack Integration Functions
# (Placed after param block for CLI compatibility)
# ... (all the cross-platform modpack integration functions from lines ~4000-4547) ...

# Minecraft Mod Manager PowerShell Script
# Uses modlist.csv as data source and Modrinth API for version checking

# Command line parameters
param(
    [switch]$Download,
    [switch]$UseLatestVersion,
    [switch]$ForceDownload,
    [switch]$Help,
    [switch]$ValidateModVersion,
    [switch]$ValidateMod,
    [string]$ModID,
    [switch]$ValidateAllModVersions,
    [switch]$DownloadMods,
    [switch]$GetModList,
    [switch]$ShowHelp,
    [switch]$AddMod,
    [string]$AddModId,
    [string]$AddModUrl,
    [string]$AddModName,
    [string]$AddModLoader,
    [string]$AddModGameVersion,
    [string]$AddModType,
    [string]$AddModGroup,
    [string]$AddModDescription,
    [string]$AddModJar,
    [string]$AddModVersion,
    [string]$AddModUrlDirect,
    [string]$AddModCategory,
    [switch]$DownloadServer,
    [switch]$StartServer,
    [switch]$AddServerStartScript,
    [string]$DeleteModID,
    [string]$DeleteModType,
    [string]$ModListFile = "modlist.csv",
    [string]$DatabaseFile = $null,
    [string]$DownloadFolder = "download",
    [string]$ApiResponseFolder = "apiresponse",
    [switch]$UseCachedResponses,
    [switch]$ValidateWithDownload,
    [switch]$DownloadCurseForgeModpack,
    [string]$CurseForgeModpackId,
    [string]$CurseForgeFileId,
    [string]$CurseForgeModpackName,
    [string]$CurseForgeGameVersion,
    [switch]$ValidateCurseForgeModpack,
    # Cross-Platform Modpack Integration
    [Parameter(Mandatory=$false)]
    [string]$ImportModpack,
    
    [Parameter(Mandatory=$false)]
    [string]$ModpackType = "auto", # "modrinth", "curseforge", "auto"
    
    [Parameter(Mandatory=$false)]
    [string]$ExportModpack,
    
    [Parameter(Mandatory=$false)]
    [string]$ExportType = "modrinth", # "modrinth", "curseforge"
    
    [Parameter(Mandatory=$false)]
    [string]$ExportName = "Exported Modpack",
    
    [Parameter(Mandatory=$false)]
    [string]$ExportAuthor = "ModManager",
    
    [Parameter(Mandatory=$false)]
    [string]$ValidateModpack,
    
    [Parameter(Mandatory=$false)]
    [string]$ValidateType = "auto", # "modrinth", "curseforge", "auto"
    
    [Parameter(Mandatory=$false)]
    [bool]$ResolveConflicts = $true,
    
    # GUI Interface
    [switch]$Gui,
    
    # Advanced Server Management
    [switch]$MonitorServerPerformance,
    [int]$PerformanceSampleInterval = 5,
    [int]$PerformanceSampleCount = 12,
    [switch]$CreateServerBackup,
    [string]$BackupPath = "backups",
    [string]$BackupName,
    [string]$RestoreServerBackup,
    [switch]$ForceRestore,
    [switch]$ListServerPlugins,
    [string]$InstallPlugin,
    [string]$PluginUrl,
    [string]$RemovePlugin,
    [switch]$ForceRemovePlugin,
    [string]$CreateConfigTemplate,
    [string]$TemplateName = "default",
    [string]$TemplatesPath = "templates",
    [string]$ApplyConfigTemplate,
    [switch]$ForceApplyTemplate,
    [switch]$RunServerHealthCheck,
    [int]$HealthCheckTimeout = 30,
    [switch]$RunServerDiagnostics,
    [int]$DiagnosticsLogLines = 100
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
$ModListPath = $ModListFile
$BackupFolder = "backups"
$DefaultLoader = "fabric"
$DefaultGameVersion = "1.21.5"
$DefaultModType = "mod"

# API URLs from environment variables or defaults
$ModrinthApiBaseUrl = if ($env:MODRINTH_API_BASE_URL) { $env:MODRINTH_API_BASE_URL } else { "https://api.modrinth.com/v2" }
$CurseForgeApiBaseUrl = if ($env:CURSEFORGE_API_BASE_URL) { $env:CURSEFORGE_API_BASE_URL } else { "https://www.curseforge.com/api/v1" }
$CurseForgeApiKey = $env:CURSEFORGE_API_KEY

# API Response Subfolder Configuration
$ModrinthApiResponseSubfolder = if ($env:APIRESPONSE_MODRINTH_SUBFOLDER) { $env:APIRESPONSE_MODRINTH_SUBFOLDER } else { "modrinth" }
$CurseForgeApiResponseSubfolder = if ($env:APIRESPONSE_CURSEFORGE_SUBFOLDER) { $env:APIRESPONSE_CURSEFORGE_SUBFOLDER } else { "curseforge" }

# Helper: Get API response path for a given domain and type
function Get-ApiResponsePath {
    param(
        [string]$ModId,
        [string]$ResponseType = "project", # or "versions"
        [string]$Domain = "modrinth", # or "curseforge"
        [string]$BaseResponseFolder = $ApiResponseFolder
    )
    $subfolder = if ($Domain -eq "curseforge") { $CurseForgeApiResponseSubfolder } else { $ModrinthApiResponseSubfolder }
    $domainFolder = Join-Path $BaseResponseFolder $subfolder
    if (-not (Test-Path $domainFolder)) {
        New-Item -ItemType Directory -Path $domainFolder -Force | Out-Null
    }
    $filename = if ($Domain -eq "curseforge" -and $ResponseType -eq "versions") {
        "$ModId-curseforge-versions.json"
    } elseif ($ResponseType -eq "project") {
        "$ModId-project.json"
    } else {
        "$ModId-versions.json"
    }
    return Join-Path $domainFolder $filename
}

# Helper: Get the effective modlist file path
function Get-EffectiveModListPath {
    param(
        [string]$DatabaseFile,
        [string]$ModListFile,
        [string]$ModListPath = "modlist.csv"
    )
    if ($DatabaseFile) { return $DatabaseFile }
    if ($ModListFile) { return $ModListFile }
    if ($ModListPath) { return $ModListPath }
    return "modlist.csv"
}

# Function to calculate SHA256 hash of a file
function Calculate-FileHash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            return $null
        }
        
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        return $hash.Hash
    }
    catch {
        Write-Warning "Failed to calculate hash for $FilePath : $($_.Exception.Message)"
        return $null
    }
}

# Function to calculate hash of a CSV record
function Calculate-RecordHash {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Record
    )
    
    try {
        # Create a string representation of all record fields (excluding RecordHash itself)
        $recordData = @()
        $record.PSObject.Properties | Where-Object { $_.Name -ne "RecordHash" } | ForEach-Object {
            $recordData += "$($_.Name)=$($_.Value)"
        }
        
        # Sort the data to ensure consistent hashing
        $recordData = $recordData | Sort-Object
        
        # Create the hash
        $recordString = $recordData -join "|"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($recordString)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($bytes)
        $hash = [System.BitConverter]::ToString($hashBytes) -replace "-", ""
        
        return $hash.ToLower()
    }
    catch {
        Write-Warning "Failed to calculate record hash: $($_.Exception.Message)"
        return $null
    }
}

# Function to verify file hash
function Test-FileHash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [string]$ExpectedHash
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            return $false
        }
        
        $actualHash = Calculate-FileHash -FilePath $FilePath
        if (-not $actualHash) {
            return $false
        }
        
        return $actualHash -eq $ExpectedHash
    }
    catch {
        Write-Warning "Failed to verify hash for $FilePath : $($_.Exception.Message)"
        return $false
    }
}

# Function to verify CSV record hash
function Test-RecordHash {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Record
    )
    
    try {
        if (-not $Record.RecordHash) {
            return $false
        }
        
        $calculatedHash = Calculate-RecordHash -Record $Record
        if (-not $calculatedHash) {
            return $false
        }
        
        return $calculatedHash -eq $Record.RecordHash
    }
    catch {
        Write-Warning "Failed to verify record hash: $($_.Exception.Message)"
        return $false
    }
}
# Function to convert dependencies to JSON format for CSV storage
function Convert-DependenciesToJson {
    param(
        [Parameter(Mandatory=$true)]
        $Dependencies
    )
    
    try {
        if (-not $Dependencies -or $Dependencies.Count -eq 0) {
            return ""
        }
        
        $dependencyList = @()
        foreach ($dep in $Dependencies) {
            $dependencyInfo = @{
                project_id = $dep.project_id
                dependency_type = $dep.dependency_type
                version_id = if ($dep.version_id) { $dep.version_id } else { $null }
                version_range = if ($dep.version_range) { $dep.version_range } else { $null }
            }
            $dependencyList += $dependencyInfo
        }
        
        return $dependencyList | ConvertTo-Json -Compress
    }
    catch {
        Write-Warning "Failed to convert dependencies to JSON: $($_.Exception.Message)"
        return ""
    }
}


# Function to load mod list from CSV
function Get-ModList {
    param(
        [string]$CsvPath,
        [string]$ApiResponseFolder = $ApiResponseFolder
    )
    try {
        if (-not (Test-Path $CsvPath)) {
            throw "Mod list CSV file not found: $CsvPath"
        }
        $mods = Import-Csv -Path $CsvPath
        if ($mods -isnot [System.Collections.IEnumerable]) { $mods = @($mods) }
        
        # Ensure CSV has required columns including dependency columns
        $mods = Ensure-CsvColumns -CsvPath $CsvPath
        if (-not $mods) {
            throw "Failed to ensure CSV columns"
        }
        
        # Add RecordHash to records that don't have it and verify integrity
        $modifiedRecords = @()
        $externalChanges = @()
        foreach ($mod in $mods) {
            # Add RecordHash property if it doesn't exist
            if (-not $mod.PSObject.Properties.Match('RecordHash').Count) {
                $mod | Add-Member -MemberType NoteProperty -Name 'RecordHash' -Value $null
            }
            
            $recordHash = Calculate-RecordHash -Record $mod
            
            # Check if record has been modified externally
            if ($mod.RecordHash -and $mod.RecordHash -ne $recordHash) {
                Write-Host "⚠️  Warning: Record for '$($mod.Name)' has been modified externally" -ForegroundColor Yellow
                Write-Host "   Verifying and updating record..." -ForegroundColor Cyan
                $externalChanges += $mod
            }
            
            # Update hash if missing or if external change detected
            if (-not $mod.RecordHash -or $mod.RecordHash -ne $recordHash) {
                $mod.RecordHash = $recordHash
                $modifiedRecords += $mod
            }
        }
        
        # If external changes were detected, verify and update those records
        if ($externalChanges.Count -gt 0) {
            Write-Host "🔄 Verifying $($externalChanges.Count) externally modified records..." -ForegroundColor Cyan
            
            foreach ($changedMod in $externalChanges) {
                # For externally modified records, we should verify them
                if ($changedMod.Type -eq "mod" -or $changedMod.Type -eq "shaderpack" -or $changedMod.Type -eq "datapack") {
                    Write-Host "   Verifying: $($changedMod.Name) (ID: $($changedMod.ID))" -ForegroundColor Gray
                    
                    # Make API call to get current data for externally modified records
                    try {
                        Write-Host "   🔍 Fetching current data from API..." -ForegroundColor Cyan
                        
                        # Use the existing Validate-ModVersion function to get current data
                        $validationResult = Validate-ModVersion -ModId $changedMod.ID -Version $changedMod.Version -Loader $changedMod.Loader -Jar $changedMod.Jar -ResponseFolder $ApiResponseFolder
                        
                        if ($validationResult -and $validationResult.Exists) {
                            # Update the record with current API data
                            $changedMod.VersionUrl = $validationResult.VersionUrl
                            $changedMod.LatestVersionUrl = $validationResult.LatestVersionUrl
                            $changedMod.LatestVersion = $validationResult.LatestVersion
                            $changedMod.LatestGameVersion = $validationResult.LatestGameVersion
                            $changedMod.IconUrl = $validationResult.IconUrl
                            $changedMod.ClientSide = $validationResult.ClientSide
                            $changedMod.ServerSide = $validationResult.ServerSide
                            $changedMod.Title = $validationResult.Title
                            $changedMod.ProjectDescription = $validationResult.ProjectDescription
                            $changedMod.IssuesUrl = $validationResult.IssuesUrl
                            $changedMod.SourceUrl = $validationResult.SourceUrl
                            $changedMod.WikiUrl = $validationResult.WikiUrl
                            Write-Host "   ✅ Record updated with current API data" -ForegroundColor Green
                        } else {
                            Write-Host "   ⚠️  API validation failed - using existing data" -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host "   ⚠️  API verification error - using existing data: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "   ✅ System entry '$($changedMod.Name)' updated" -ForegroundColor Green
                }
            }
            
            Write-Host "✅ All externally modified records have been verified and updated" -ForegroundColor Green
        }
        
        # Save updated records if any were modified
        if ($modifiedRecords.Count -gt 0) {
            $mods | Export-Csv -Path $CsvPath -NoTypeInformation
            Write-Host "💾 Updated $($modifiedRecords.Count) records with new hash values" -ForegroundColor Cyan
        }
        
        return $mods
    }
    catch {
        Write-Error "Failed to load mod list from $CsvPath : $($_.Exception.Message)"
        return @()
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
        $responseFile = Get-ApiResponsePath -ModId $ModId -ResponseType "project" -Domain "modrinth" -BaseResponseFolder $ResponseFolder
        
        # Check if we should use cached responses
        if ($UseCachedResponses -and (Test-Path $responseFile)) {
            Write-Host ("  → Using cached project info for {0}..." -f $ModId) -ForegroundColor DarkGray
            $response = Get-Content -Path $responseFile -Raw | ConvertFrom-Json
        } else {
            # Make API request
            Write-Host ("  → Calling API for project info {0}..." -f $ModId) -ForegroundColor DarkGray
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
        $responseFile = Get-ApiResponsePath -ModId $ModId -ResponseType "versions" -Domain "modrinth" -BaseResponseFolder $ResponseFolder
        
        # Check if we should use cached responses
        if ($UseCachedResponses -and (Test-Path $responseFile)) {
            Write-Host ("  → Using cached response for {0}..." -f $ModId) -ForegroundColor DarkGray
            $response = Get-Content -Path $responseFile -Raw | ConvertFrom-Json
        } else {
            # Make API request for versions
            Write-Host ("  → Calling API for {0}..." -f $ModId) -ForegroundColor DarkGray
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ContentType "application/json"
            
            # Save full response to file
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        }
        
        # Filter versions by loader
        $filteredResponse = $response | Where-Object { $_.loaders -contains $Loader.Trim() }
        
        # Get project information to access game_versions field
        $projectInfo = Get-ModrinthProjectInfo -ModId $ModId -ResponseFolder $ResponseFolder
        
        # Determine the latest version using project API response game_versions field
        $latestVersion = "No $Loader versions found"
        $latestVerObj = $null
        
        if ($projectInfo.ProjectInfo -and $projectInfo.ProjectInfo.game_versions -and $projectInfo.ProjectInfo.game_versions.Count -gt 0) {
            # Get the last entry in the game_versions array as the latest
            $latestGameVersion = $projectInfo.ProjectInfo.game_versions[-1]
            
            # Find the version object that supports this game version
            $latestVerObj = $filteredResponse | Where-Object { 
                $_.game_versions -and $_.game_versions -contains $latestGameVersion 
            } | Select-Object -First 1
            
            if ($latestVerObj) {
                $latestVersion = $latestVerObj.version_number
            } elseif ($filteredResponse.Count -gt 0) {
                # Fallback: if no version matches the latest game version, use the first filtered version
                $latestVerObj = $filteredResponse[0]
                $latestVersion = $latestVerObj.version_number
            }
        } elseif ($filteredResponse.Count -gt 0) {
            # Fallback: if no project info or game_versions, use the first filtered version
            $latestVerObj = $filteredResponse[0]
            $latestVersion = $latestVerObj.version_number
        }
        
        $latestVersionStr = if ($latestVersion -ne "No $Loader versions found") { $latestVersion } else { "No $Loader versions found" }
        
        # Handle "latest" version parameter
        if ($Version -eq "latest") {
            # For "latest" requests, use the determined latest version
            $versionExists = $true
            $matchingVersion = $latestVerObj
            $normalizedExpectedVersion = Normalize-Version -Version $latestVersion
        } else {
            # Normalize the expected version for comparison
            $normalizedExpectedVersion = Normalize-Version -Version $Version
        }
        
        # Check if the specific version exists (in filtered results)
        if ($Version -ne "latest") {
            $versionExists = $false
            $matchingVersion = $null
            $versionUrl = $null
            $latestVersionUrl = $null
            $versionFoundByJar = $false
            
            # Find matching version and extract URL
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
        } else {
            # For "latest" requests, initialize variables
            $versionUrl = $null
            $latestVersionUrl = $null
            $versionFoundByJar = $false
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
        
        # Extract latest version URL using the determined latest version
        if ($latestVerObj -and $latestVerObj.files -and $latestVerObj.files.Count -gt 0) {
            $latestVersionUrl = $latestVerObj.files[0].url
        }
        
        # Extract dependencies from matching version and latest version
        $currentDependencies = $null
        $latestDependencies = $null
        
        if ($matchingVersion -and $matchingVersion.dependencies) {
            $currentDependencies = Convert-DependenciesToJson -Dependencies $matchingVersion.dependencies
        }
        
        if ($latestVerObj -and $latestVerObj.dependencies) {
            $latestDependencies = Convert-DependenciesToJson -Dependencies $latestVerObj.dependencies
        }
        
        # Display mod and latest version
        if ($versionExists) {
            # Get latest game version for the latest version
            $latestGameVersion = $null
            if ($latestVerObj -and $latestVerObj.game_versions -and $latestVerObj.game_versions.Count -gt 0) {
                # Get the last (highest) game version from the array
                $latestGameVersion = $latestVerObj.game_versions[-1]
            }

            return [PSCustomObject]@{
                Exists = $true
                AvailableVersions = ($filteredResponse.version_number -join ", ")
                LatestVersion = $latestVersion
                VersionUrl = $versionUrl
                LatestVersionUrl = $latestVersionUrl
                IconUrl = $projectInfo.IconUrl
                ClientSide = $projectInfo.ClientSide
                ServerSide = $projectInfo.ServerSide
                Title = $projectInfo.Title
                ProjectDescription = $projectInfo.ProjectDescription
                IssuesUrl = if ($projectInfo.IssuesUrl) { $projectInfo.IssuesUrl.ToString() } else { "" }
                SourceUrl = if ($projectInfo.SourceUrl) { $projectInfo.SourceUrl.ToString() } else { "" }
                WikiUrl = if ($projectInfo.WikiUrl) { $projectInfo.WikiUrl.ToString() } else { "" }
                VersionFoundByJar = $versionFoundByJar
                LatestGameVersion = $latestGameVersion
                CurrentDependencies = $currentDependencies
                LatestDependencies = $latestDependencies
            }
        } else {
            return [PSCustomObject]@{
                Exists = $false
                AvailableVersions = ($filteredResponse.version_number -join ", ")
                LatestVersion = $latestVersion
                VersionUrl = $null
                LatestVersionUrl = $latestVersionUrl
                IconUrl = $projectInfo.IconUrl
                ClientSide = $projectInfo.ClientSide
                ServerSide = $projectInfo.ServerSide
                Title = $projectInfo.Title
                ProjectDescription = $projectInfo.ProjectDescription
                IssuesUrl = if ($projectInfo.IssuesUrl) { $projectInfo.IssuesUrl.ToString() } else { "" }
                SourceUrl = if ($projectInfo.SourceUrl) { $projectInfo.SourceUrl.ToString() } else { "" }
                WikiUrl = if ($projectInfo.WikiUrl) { $projectInfo.WikiUrl.ToString() } else { "" }
                VersionFoundByJar = $false
                LatestGameVersion = $null
                CurrentDependencies = $null
                LatestDependencies = $latestDependencies
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
        $responseFile = Get-ApiResponsePath -ModId $ModId -ResponseType "versions" -Domain "curseforge" -BaseResponseFolder $ResponseFolder
        
        # Check if we should use cached responses
        if ($UseCachedResponses -and (Test-Path $responseFile)) {
            Write-Host ("  → Using cached CurseForge response for {0}..." -f $ModId) -ForegroundColor DarkGray
            $response = Get-Content -Path $responseFile -Raw | ConvertFrom-Json
        } else {
            # Make API request
            Write-Host ("  → Calling CurseForge API for {0}..." -f $ModId) -ForegroundColor DarkGray
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
                AvailableVersions = ($filteredResponse.displayName -join ", ")
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
                AvailableVersions = ($filteredResponse.displayName -join ", ")
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
        [string]$CsvPath
    )
    try {
        $mods = Import-Csv -Path $CsvPath
        if ($mods -isnot [System.Collections.IEnumerable]) { $mods = @($mods) }
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
        
        # Check if dependency columns exist
        $dependencyColumns = @("CurrentDependencies", "LatestDependencies")
        foreach ($col in $dependencyColumns) {
            if ($headers -notcontains $col) {
                foreach ($mod in $mods) {
                    $mod | Add-Member -MemberType NoteProperty -Name $col -Value ""
                }
                $needsUpdate = $true
            }
        }
        
        if ($needsUpdate) {
            # Create backup before updating
            $backupPath = Get-BackupPath -OriginalPath $CsvPath -BackupType "columns"
            Copy-Item -Path $CsvPath -Destination $backupPath
            Write-Host "Created backup: $backupPath" -ForegroundColor Yellow
            
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

# Helper: Get backup path in backups folder
function Get-BackupPath {
    param(
        [string]$OriginalPath,
        [string]$BackupType = "backup"
    )
    
    # Create backups folder if it doesn't exist
    if (-not (Test-Path $BackupFolder)) {
        New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null
        Write-Host "Created backups folder: $BackupFolder" -ForegroundColor Green
    }
    
    # Get original filename without path
    $originalFileName = [System.IO.Path]::GetFileName($OriginalPath)
    $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($originalFileName)
    $extension = [System.IO.Path]::GetExtension($originalFileName)
    
    # Create timestamp for unique backup names
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    
    # Create backup filename
    $backupFileName = "${fileNameWithoutExt}-${BackupType}-${timestamp}${extension}"
    
    # Return full path in backups folder
    return Join-Path $BackupFolder $backupFileName
}

# Function to clean up installer, launcher, and server entries
function Clean-SystemEntries {
    param(
        [array]$Mods
    )
    
    foreach ($mod in $Mods) {
        if ($mod.Type -in @("installer", "launcher", "server")) {
            # Ensure all API-related fields are empty strings for system entries
            $mod.IconUrl = ""
            $mod.ClientSide = ""
            $mod.ServerSide = ""
            $mod.Title = if ($mod.Title) { $mod.Title } else { $mod.Name }
            $mod.ProjectDescription = ""
            $mod.IssuesUrl = ""
            $mod.SourceUrl = ""
            $mod.WikiUrl = ""
            $mod.LatestGameVersion = ""
            $mod.CurrentDependencies = ""
            $mod.LatestDependencies = ""
            
            # Ensure ApiSource and Host are set correctly
            $mod.ApiSource = "direct"
            $mod.Host = "direct"
        }
    }
    
    return $Mods
}

# Function to update modlist with latest versions
function Update-ModListWithLatestVersions {
    param(
        [string]$CsvPath,
        [array]$ValidationResults
    )
    try {
        # Ensure CSV has required columns
        $mods = Ensure-CsvColumns -CsvPath $CsvPath
        if (-not $mods) {
            return 0
        }
        
        # Clean up system entries (installer, launcher, server) to ensure proper empty strings
        $mods = Clean-SystemEntries -Mods $mods
        
        # Create a backup of the original file
        $backupPath = Get-BackupPath -OriginalPath $CsvPath -BackupType "update"
        Copy-Item -Path $CsvPath -Destination $backupPath
        Write-Host "Created backup: $backupPath" -ForegroundColor Yellow
        
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
                    CurrentDependencies = $false
                    LatestDependencies = $false
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
                # Handle IssuesUrl - ensure it's a string, not null or array
                $issuesUrlValue = if ($result.IssuesUrl) { $result.IssuesUrl.ToString() } else { "" }
                if ($issuesUrlValue -ne $mod.IssuesUrl) {
                    $mod.IssuesUrl = $issuesUrlValue
                    $updatedFields.IssuesUrl = $true
                }
                # Handle SourceUrl - ensure it's a string, not null or array
                $sourceUrlValue = if ($result.SourceUrl) { $result.SourceUrl.ToString() } else { "" }
                if ($sourceUrlValue -ne $mod.SourceUrl) {
                    $mod.SourceUrl = $sourceUrlValue
                    $updatedFields.SourceUrl = $true
                }
                # Handle WikiUrl - ensure it's a string, not null or array
                $wikiUrlValue = if ($result.WikiUrl) { $result.WikiUrl.ToString() } else { "" }
                if ($wikiUrlValue -ne $mod.WikiUrl) {
                    $mod.WikiUrl = $wikiUrlValue
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
                
                # Update CurrentDependencies if available
                if ($result.CurrentDependencies -and $result.CurrentDependencies -ne $mod.CurrentDependencies) {
                    $mod.CurrentDependencies = $result.CurrentDependencies
                    $updatedFields.CurrentDependencies = $true
                }
                
                # Update LatestDependencies if available
                if ($result.LatestDependencies -and $result.LatestDependencies -ne $mod.LatestDependencies) {
                    $mod.LatestDependencies = $result.LatestDependencies
                    $updatedFields.LatestDependencies = $true
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
                        CurrentDependencies = if ($updatedFields.CurrentDependencies) { "✓" } else { "" }
                        LatestDependencies = if ($updatedFields.LatestDependencies) { "✓" } else { "" }
                    }
                }
            }
        }
        
        # Save updated modlist
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        
        # Display summary table (hidden for cleaner output)
        # if ($updateSummary.Count -gt 0) {
        #     Write-Host ""
        #     Write-Host "Update Summary:" -ForegroundColor Yellow
        #     Write-Host "==============" -ForegroundColor Yellow
        #     $updateSummary | Format-Table -AutoSize | Out-Host
        # }
        
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
    
    $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $CsvPath
    $mods = Get-ModList -CsvPath $effectiveModListPath
    if (-not $mods) {
        return
    }
    
    $results = @()
    
    # Count total mods to validate (excluding installer, launcher, server types)
    $modsToValidate = $mods | Where-Object { 
        -not [string]::IsNullOrEmpty($_.ID) -and 
        $_.Type -notin @("installer", "launcher", "server") 
    }
    $totalMods = $modsToValidate.Count
    $currentMod = 0
    
    Write-Host "Validating mod versions and saving API responses..." -ForegroundColor Yellow
    Write-Host "Total mods to validate: $totalMods" -ForegroundColor Yellow
    
    foreach ($mod in $modsToValidate) {
        $currentMod++
        Write-Host ("[{0:D3}/{1:D3}] Validating: {2} (ID: {3}, Type: {4}, Host: {5}, Version: {6})" -f $currentMod, $totalMods, $mod.Name, $mod.ID, $mod.Type, $mod.Host, $mod.Version) -ForegroundColor Cyan
        
        # Get loader from CSV, default to "fabric" if not specified
        $loader = if (-not [string]::IsNullOrEmpty($mod.Loader)) { $mod.Loader.Trim() } else { $DefaultLoader }
        # Get host from CSV, default to "modrinth" if not specified
        $modHost = if (-not [string]::IsNullOrEmpty($mod.Host)) { $mod.Host } else { "modrinth" }
        # Get game version from CSV, default to "1.21.5" if not specified
        $gameVersion = if (-not [string]::IsNullOrEmpty($mod.GameVersion)) { $mod.GameVersion } else { $DefaultGameVersion }
        # Get JAR filename from CSV
        $jarFilename = if (-not [string]::IsNullOrEmpty($mod.Jar)) { $mod.Jar } else { "" }
        
        Write-Host ("  → Calling API for {0}..." -f $modHost) -ForegroundColor DarkGray
        
        # Use appropriate API based on host
        if ($modHost -eq "curseforge") {
            $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.Version -Loader $loader -ResponseFolder $ResponseFolder -Jar $jarFilename -ModUrl $mod.URL
        } else {
            # If version is empty, treat as "get latest version" request
            $versionToCheck = if ([string]::IsNullOrEmpty($mod.Version)) { "latest" } else { $mod.Version }
            $result = Validate-ModVersion -ModId $mod.ID -Version $versionToCheck -Loader $loader -ResponseFolder $ResponseFolder -Jar $jarFilename
        }
        
        if ($result.Exists) {
            Write-Host ("  ✓ Found version: {0}" -f $result.LatestVersion) -ForegroundColor Green
        } else {
            Write-Host ("  ❌ Version not found or error: {0}" -f $result.Error) -ForegroundColor Red
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
            IssuesUrl = if ($result.IssuesUrl) { $result.IssuesUrl.ToString() } else { "" }
            SourceUrl = if ($result.SourceUrl) { $result.SourceUrl.ToString() } else { "" }
            WikiUrl = if ($result.WikiUrl) { $result.WikiUrl.ToString() } else { "" }
            VersionFoundByJar = $result.VersionFoundByJar
            LatestGameVersion = $result.LatestGameVersion
            CurrentDependencies = $result.CurrentDependencies
            LatestDependencies = $result.LatestDependencies
        }
    }
    
    # Save results to CSV
    $resultsFile = Join-Path $ResponseFolder "version-validation-results.csv"
    $results | Export-Csv -Path $resultsFile -NoTypeInformation
    
    # Analyze version differences and provide upgrade recommendations
    Write-Host ""
    Write-Host "Version Analysis and Upgrade Recommendations:" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    
    $modsWithUpdates = @()
    $modsCurrent = @()
    $modsNotFound = @()
    $modsWithErrors = @()
    
    foreach ($result in $results) {
        if (-not $result.VersionExists) {
            if ([string]::IsNullOrEmpty($result.Error)) {
                $modsNotFound += $result
            } else {
                $modsWithErrors += $result
            }
            continue
        }
        
        # Compare expected version with latest version
        $expectedVersion = $result.ExpectedVersion
        $latestVersion = $result.LatestVersion
        
        if ([string]::IsNullOrEmpty($expectedVersion)) {
            # No version specified, treat as "get latest"
            $modsCurrent += $result
        } elseif ($expectedVersion -eq $latestVersion) {
            # Versions match
            $modsCurrent += $result
        } else {
            # Different versions - potential upgrade
            $modsWithUpdates += $result
        }
    }
    
    # Display statistics
    Write-Host "📊 Validation Summary:" -ForegroundColor White
    Write-Host "   ✅ Current versions: $($modsCurrent.Count) mods" -ForegroundColor Green
    Write-Host "   🔄 Available updates: $($modsWithUpdates.Count) mods" -ForegroundColor Yellow
    Write-Host "   ❌ Not found: $($modsNotFound.Count) mods" -ForegroundColor Red
    Write-Host "   ⚠️  Errors: $($modsWithErrors.Count) mods" -ForegroundColor Red
    Write-Host ""
    
    # Show mods with available updates
    if ($modsWithUpdates.Count -gt 0) {
        Write-Host "🔄 Mods with Available Updates:" -ForegroundColor Yellow
        Write-Host "===============================" -ForegroundColor Yellow
        foreach ($mod in $modsWithUpdates) {
            Write-Host ("  {0}:" -f $mod.Name) -ForegroundColor Cyan
            Write-Host ("    Current: {0}" -f $mod.ExpectedVersion) -ForegroundColor Gray
            Write-Host ("    Latest:  {0}" -f $mod.LatestVersion) -ForegroundColor Green
            if (-not [string]::IsNullOrEmpty($mod.LatestVersionUrl)) {
                Write-Host ("    URL:     {0}" -f $mod.LatestVersionUrl) -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    }
    
    # Show mods not found
    if ($modsNotFound.Count -gt 0) {
        Write-Host "❌ Mods Not Found:" -ForegroundColor Red
        Write-Host "==================" -ForegroundColor Red
        foreach ($mod in $modsNotFound) {
            Write-Host ("  {0} (ID: {1}, Host: {2})" -f $mod.Name, $mod.ID, $mod.Host) -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Show mods with errors
    if ($modsWithErrors.Count -gt 0) {
        Write-Host "⚠️  Mods with Errors:" -ForegroundColor Red
        Write-Host "====================" -ForegroundColor Red
        foreach ($mod in $modsWithErrors) {
            Write-Host ("  {0}: {1}" -f $mod.Name, $mod.Error) -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Move upgrade recommendations to the very end and make them clearer
    Write-Host ""
    Write-Host "💡 Next Steps:" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    
    if ($modsWithUpdates.Count -gt 0) {
        Write-Host "🔄 $($modsWithUpdates.Count) mods have newer versions available!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To download the latest versions:" -ForegroundColor White
        Write-Host "  .\ModManager.ps1 -DownloadMods -UseLatestVersion" -ForegroundColor Green
        Write-Host "  → Downloads latest mod files to download/ folder" -ForegroundColor Gray
    } elseif ($modsCurrent.Count -gt 0 -and $modsNotFound.Count -eq 0 -and $modsWithErrors.Count -eq 0) {
        Write-Host "🎉 All mods are up to date!" -ForegroundColor Green
        Write-Host "All $($modsCurrent.Count) mods are using their latest available versions." -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Update modlist with latest versions if requested
    if ($UpdateModList) {
        Write-Host "Updating modlist with latest versions and URLs..." -ForegroundColor Yellow
        Write-Host ""
        
        # Load current modlist
        $currentMods = Get-ModList -CsvPath $effectiveModListPath
        if (-not $currentMods) {
            Write-Host "❌ Failed to load current modlist" -ForegroundColor Red
            return
        }
        
        # Ensure CSV has required columns including dependency columns
        $currentMods = Ensure-CsvColumns -CsvPath $effectiveModListPath
        if (-not $currentMods) {
            Write-Host "❌ Failed to ensure CSV columns" -ForegroundColor Red
            return
        }
        
        $updatedCount = 0
        $newMods = @()
        
        foreach ($currentMod in $currentMods) {
            # Find matching validation result
            $validationResult = $results | Where-Object { $_.ID -eq $currentMod.ID -and $_.Host -eq $currentMod.Host } | Select-Object -First 1
            
            if ($validationResult -and $validationResult.VersionExists) {
                # Update with latest information
                $updatedMod = $currentMod.PSObject.Copy()
                $updatedMod.LatestVersion = $validationResult.LatestVersion
                $updatedMod.VersionUrl = $validationResult.VersionUrl
                $updatedMod.LatestVersionUrl = $validationResult.LatestVersionUrl
                $updatedMod.IconUrl = $validationResult.IconUrl
                $updatedMod.ClientSide = $validationResult.ClientSide
                $updatedMod.ServerSide = $validationResult.ServerSide
                $updatedMod.Title = $validationResult.Title
                $updatedMod.ProjectDescription = $validationResult.ProjectDescription
                $updatedMod.IssuesUrl = $validationResult.IssuesUrl
                $updatedMod.SourceUrl = $validationResult.SourceUrl
                $updatedMod.WikiUrl = $validationResult.WikiUrl
                $updatedMod.LatestGameVersion = $validationResult.LatestGameVersion
                $updatedMod.CurrentDependencies = $validationResult.CurrentDependencies
                $updatedMod.LatestDependencies = $validationResult.LatestDependencies
                
                if ($newMods.Count -eq 0) {
                    $newMods = @($updatedMod)
                } else {
                    $newMods = @($newMods) + $updatedMod
                }
                $updatedCount++
            } else {
                # Keep existing mod as-is
                $newMods += $currentMod
            }
        }
        
        # Save updated modlist
        $newMods | Export-Csv -Path $effectiveModListPath -NoTypeInformation
        
        # Show what was updated (hidden for cleaner output)
        # Write-Host "Update Summary:" -ForegroundColor Cyan
        # Write-Host "===============" -ForegroundColor Cyan
        # Write-Host ""
        
        # Show what was updated
        $updateTable = @()
        foreach ($currentMod in $currentMods) {
            $validationResult = $results | Where-Object { $_.ID -eq $currentMod.ID -and $_.Host -eq $currentMod.Host } | Select-Object -First 1
            
            if ($validationResult -and $validationResult.VersionExists) {
                $updateTable += [PSCustomObject]@{
                    Name = $currentMod.Name
                    LatestVersion = $validationResult.LatestVersion
                    VersionUrl = $validationResult.VersionUrl
                    LatestVersionUrl = $validationResult.LatestVersionUrl
                    IconUrl = $validationResult.IconUrl
                    ClientSide = $validationResult.ClientSide
                    ServerSide = $validationResult.ServerSide
                    Title = $validationResult.Title
                    ProjectDescription = $validationResult.ProjectDescription
                    IssuesUrl = $validationResult.IssuesUrl
                    SourceUrl = $validationResult.SourceUrl
                    WikiUrl = $validationResult.WikiUrl
                    LatestGameVersion = $validationResult.LatestGameVersion
                }
            }
        }
        
        if ($updateTable.Count -gt 0) {
            # $updateTable | Format-Table -AutoSize
            # Write-Host ""
            Write-Host "✅ Database updated: $updatedCount mods now have latest version information" -ForegroundColor Green
        } else {
            Write-Host "✅ No updates needed - all mods already have latest version information" -ForegroundColor Green
        }
    }
    
    # Return summary for potential use by other functions
    $result = @{
        TotalMods = $results.Count
        CurrentVersions = $modsCurrent.Count
        AvailableUpdates = $modsWithUpdates.Count
        NotFound = $modsNotFound.Count
        Errors = $modsWithErrors.Count
        Results = $results
    }
    
    # Suppress output to avoid showing the object summary
    $result | Out-Null
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
    Write-Host "  [-UseCachedResponses]" -ForegroundColor White
    Write-Host "    - Debug option: Uses existing API response files instead of making new API calls"
    Write-Host "    - Speeds up testing by reusing cached responses from previous runs"
    Write-Host "    - Only makes API calls for mods that don't have cached responses"
    Write-Host "    - Useful for development and testing scenarios"
    Write-Host ""
    Write-Host "  Download-Mods [-CsvPath <path>] [-UseLatestVersion] [-ForceDownload]" -ForegroundColor White
    Write-Host "    - Downloads mods to local download folder organized by GameVersion"
    Write-Host "    - Creates subfolders for each GameVersion (e.g., download/1.21.5/mods/)"
    Write-Host "    - Creates block subfolder for mods in 'block' group (e.g., download/1.21.5/mods/block/)"
    Write-Host "    - Creates shaderpacks subfolder for shaderpacks (e.g., download/1.21.5/shaderpacks/)"
    Write-Host "    - Uses VersionUrl by default, or LatestVersionUrl with -UseLatestVersion"
    Write-Host "    - Skips existing files unless -ForceDownload is used"
    Write-Host "    - Saves download results to CSV"
    Write-Host ""
    Write-Host "  Download-ServerFiles [-ForceDownload]" -ForegroundColor White
    Write-Host "    - Downloads Minecraft server JARs and Fabric launchers"
    Write-Host "    - Downloads to download/[version]/ folder"
    Write-Host "    - Includes server JARs for 1.21.5 and 1.21.6"
    Write-Host "    - Includes Fabric launchers for 1.21.5 and 1.21.6"
    Write-Host "    - Skips existing files unless -ForceDownload is used"
    Write-Host ""
    Write-Host "  Add-Mod [-AddModId <id>] [-AddModUrl <url>] [-AddModName <name>] [-AddModLoader <loader>] [-AddModGameVersion <version>] [-AddModType <type>] [-AddModGroup <group>] [-AddModDescription <description>] [-AddModJar <jar>] [-AddModUrlDirect <url>] [-AddModCategory <category>] [-ForceDownload]" -ForegroundColor White
    Write-Host "    - Adds a new mod to modlist.csv with minimal information"
    Write-Host "    - Auto-resolves latest version and metadata from APIs"
    Write-Host "    - Supports Modrinth URLs (e.g., https://modrinth.com/mod/fabric-api)"
    Write-Host "    - Supports Modrinth and CurseForge mods"
    Write-Host "    - Supports shaderpacks (auto-uses 'iris' loader)"
    Write-Host "    - Supports installers (direct URL downloads)"
    Write-Host "    - Auto-downloads if -ForceDownload is specified"
    Write-Host "    - Default loader: fabric (or iris for shaderpacks)"
    Write-Host "    - Default game version: $DefaultGameVersion"
    Write-Host "    - Default type: mod"
    Write-Host "    - Default group: optional"
    Write-Host ""
    Write-Host "  [-AddModId <id>] (without -AddMod flag)" -ForegroundColor White
    Write-Host "    - Shortcut: Just provide a Modrinth URL as -AddModUrl"
    Write-Host "    - Automatically detects and adds the mod"
    Write-Host "    - Example: .\ModManager.ps1 -AddModUrl 'https://modrinth.com/mod/sodium'"
    Write-Host "  Show-Help" -ForegroundColor White
    Write-Host "    - Shows this help information"
    Write-Host ""
    Write-Host "USAGE EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\ModManager.ps1" -ForegroundColor White
    Write-Host "    - Runs automatic validation of all mods and updates modlist with download URLs"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -ModListFile 'my-mods.csv'" -ForegroundColor White
    Write-Host "    - Uses custom CSV file 'my-mods.csv' instead of default 'modlist.csv'"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -Download" -ForegroundColor White
    Write-Host "    - Validates all mods and downloads them to download/ folder organized by GameVersion"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -Download -UseLatestVersion" -ForegroundColor White
    Write-Host "    - Downloads latest versions of all mods instead of current versions"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -Download -ForceDownload" -ForegroundColor White
    Write-Host "    - Downloads all mods, overwriting existing files"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -DownloadServer" -ForegroundColor White
    Write-Host "    - Downloads Minecraft server JARs and Fabric launchers"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -StartServer" -ForegroundColor White
    Write-Host "    - Starts Minecraft server with error checking and log monitoring"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -AddMod -AddModId 'fabric-api' -AddModName 'Fabric API'" -ForegroundColor White
    Write-Host "    - Adds Fabric API with auto-resolved latest version and metadata"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -AddMod -AddModUrl 'https://modrinth.com/mod/fabric-api'" -ForegroundColor White
    Write-Host "    - Adds Fabric API using Modrinth URL (auto-detects type and ID)"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -AddModUrl 'https://modrinth.com/mod/sodium'" -ForegroundColor White
    Write-Host "    - Shortcut: Adds Sodium using Modrinth URL"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -AddMod -AddModUrl 'https://modrinth.com/shader/complementary-reimagined'" -ForegroundColor White
    Write-Host "    - Adds shaderpack with auto-detected type and iris loader"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -AddMod -AddModUrl 'https://modrinth.com/modpack/fabulously-optimized'" -ForegroundColor White
    Write-Host "    - Adds modpack with auto-detected type"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -AddMod -AddModId '238222' -AddModName 'Inventory HUD+' -AddModType 'curseforge'" -ForegroundColor White
    Write-Host "    - Adds CurseForge mod with project ID"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -AddMod -AddModUrl 'complementary-reimagined' -AddModName 'Complementary Reimagined' -AddModType 'shaderpack'" -ForegroundColor White
    Write-Host "    - Adds shaderpack with Modrinth ID"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -AddMod -AddModUrl 'no-chat-reports' -AddModName 'No Chat Reports' -AddModGroup 'block'" -ForegroundColor White
    Write-Host "    - Adds mod to 'block' group (won't be downloaded)"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -AddMod -AddModUrl 'fabric-installer-1.0.3' -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.5'" -ForegroundColor White
    Write-Host "    - Adds installer with direct URL download (downloads to installer subfolder)"
    Write-Host ""
    Write-Host "  Validate-ModVersion -ModId 'fabric-api' -Version '0.91.0+1.20.1'" -ForegroundColor White
    Write-Host "    - Validates Fabric API version 0.91.0+1.20.1 and extracts download URLs"
    Write-Host ""
    Write-Host "  Validate-AllModVersions -UpdateModList" -ForegroundColor White
    Write-Host "    - Validates all mods and updates modlist.csv with download URLs (preserves Version column)"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -ValidateAllModVersions -UseCachedResponses" -ForegroundColor White
    Write-Host "    - Validates all mods using cached API responses (faster for testing)"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -DownloadMods" -ForegroundColor White
    Write-Host "    - Downloads mods using existing URLs in CSV (no validation, fast)"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -DownloadMods -ValidateWithDownload" -ForegroundColor White
    Write-Host "    - Downloads mods with validation first (updates URLs, slower)"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -DownloadMods -UseLatestVersion" -ForegroundColor White
    Write-Host "    - Downloads latest versions of all mods to download/ folder (no validation)"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -DownloadMods -UseLatestVersion -ValidateWithDownload" -ForegroundColor White
    Write-Host "    - Downloads latest versions with validation first"
    Write-Host ""
    Write-Host "  .\ModManager.ps1 -Download" -ForegroundColor White
    Write-Host "    - Validates all mods then downloads (legacy behavior)"
    Write-Host ""
    Write-Host "  Get-ModList" -ForegroundColor White
    Write-Host "    - Shows all mods from modlist.csv"
    Write-Host ""
    Write-Host "OUTPUT FORMAT:" -ForegroundColor Yellow
    Write-Host "  ✓ ModID | Expected: version | Latest (loader): latest_version" -ForegroundColor Green
    Write-Host "  ✗ ModID | Expected: version | Latest (loader): latest_version" -ForegroundColor Red
    Write-Host ""
    Write-Host "CSV COLUMNS:" -ForegroundColor Yellow
    Write-Host "  Group, Type, GameVersion, ID, Loader, Version, Name, Description, Jar, Url, Category, VersionUrl, LatestVersionUrl, LatestVersion, ApiSource, Host, IconUrl, ClientSide, ServerSide, Title, ProjectDescription, IssuesUrl, SourceUrl, WikiUrl, LatestGameVersion, RecordHash" -ForegroundColor White
    Write-Host "  - VersionUrl: Direct download URL for the current version" -ForegroundColor Gray
    Write-Host "  - LatestVersionUrl: Direct download URL for the latest available version" -ForegroundColor Gray
    Write-Host "  - Group: Mod category (required, optional, admin, block)" -ForegroundColor Gray
    Write-Host "  - Type: Mod type (mod, datapack, shaderpack, installer, server, launcher)" -ForegroundColor Gray
    Write-Host "  - RecordHash: SHA256 hash of the record data for integrity verification" -ForegroundColor Gray
    Write-Host ""
    Write-Host "FILES:" -ForegroundColor Yellow
    Write-Host "  Input:  $ModListPath" -ForegroundColor White
    Write-Host "  Output: $ApiResponseFolder\*.json (API responses)" -ForegroundColor White
    Write-Host "  Output: $ApiResponseFolder\version-validation-results.csv (validation results)" -ForegroundColor White
    Write-Host "  Output: $ApiResponseFolder\mod-download-results.csv (download results)" -ForegroundColor White
    Write-Host "  Output: $DownloadFolder\GameVersion\mods\*.jar (downloaded mods)" -ForegroundColor White
    Write-Host "  Output: $DownloadFolder\GameVersion\mods\block\*.jar (block group mods)" -ForegroundColor White
    Write-Host "  Output: $DownloadFolder\GameVersion\shaderpacks\*.zip (shaderpacks)" -ForegroundColor White
    Write-Host "  Output: $DownloadFolder\GameVersion\installer\*.exe (installers)" -ForegroundColor White
    Write-Host "  Output: $DownloadFolder\GameVersion\minecraft_server.*.jar (server JARs)" -ForegroundColor White
    Write-Host "  Output: $DownloadFolder\GameVersion\fabric-server-*.jar (Fabric launchers)" -ForegroundColor White
    Write-Host "  Backup: $BackupFolder\*.csv (timestamped backups created before updates)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Delete a mod by Modrinth URL or ID/type:" -ForegroundColor White
    Write-Host "    .\\ModManager.ps1 -DeleteModID 'https://modrinth.com/mod/phosphor'" -ForegroundColor White
    Write-Host "    .\\ModManager.ps1 -DeleteModID 'phosphor' -DeleteModType 'mod'" -ForegroundColor White
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

# Helper function to clean filenames (decode URL, remove Minecraft formatting codes, and non-printable characters)
function Clean-Filename {
    param([string]$filename)
    # Decode URL-encoded characters
    $decoded = [System.Uri]::UnescapeDataString($filename)
    # Remove Minecraft formatting codes (e.g., §r, §l, etc.)
    $cleaned = $decoded -replace "§[0-9a-fl-or]", ""
    # Remove any non-printable or control characters
    $cleaned = -join ($cleaned.ToCharArray() | Where-Object { [int]$_ -ge 32 -and [int]$_ -le 126 })
    return $cleaned
}

# Function to download modpacks
function Download-Modpack {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        [Parameter(Mandatory=$true)]
        [string]$VersionUrl,
        [Parameter(Mandatory=$true)]
        [string]$ModName,
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder,
        [bool]$ForceDownload = $false
    )
    try {
        Write-Host "📦 Downloading modpack: $ModName" -ForegroundColor Cyan
        Write-Host "   URL: $VersionUrl" -ForegroundColor Gray
        
        # Create download directory structure using the passed DownloadFolder parameter
        $downloadDir = Join-Path $DownloadFolder $GameVersion
        $modpackDir = Join-Path $downloadDir "modpacks\$ModName"
        if (-not (Test-Path $downloadDir)) {
            New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
        }
        if (-not (Test-Path $modpackDir)) {
            New-Item -ItemType Directory -Path $modpackDir -Force | Out-Null
        }
        
        # Download the .mrpack file
        $mrpackFileName = "$ModName.mrpack"
        $mrpackPath = Join-Path $modpackDir $mrpackFileName
        if ((Test-Path $mrpackPath) -and (-not $ForceDownload)) {
            Write-Host "⏭️  Modpack file already exists, skipping download" -ForegroundColor Yellow
        } else {
            Write-Host "⬇️  Downloading modpack file..." -ForegroundColor Yellow
            try {
                Invoke-WebRequest -Uri $VersionUrl -OutFile $mrpackPath -UseBasicParsing
                Write-Host "✅ Downloaded modpack file" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to download modpack file: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
        
        # Extract the .mrpack file (it's just a zip file)
        Write-Host "📂 Extracting modpack..." -ForegroundColor Yellow
        try {
            Expand-Archive -Path $mrpackPath -DestinationPath $modpackDir -Force
        } catch {
            Write-Host "❌ Failed to extract modpack: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
        
        # Find and process modrinth.index.json
        $indexPath = Join-Path $modpackDir "modrinth.index.json"
        if (-not (Test-Path $indexPath)) {
            Write-Host "❌ modrinth.index.json not found in extracted modpack" -ForegroundColor Red
            Write-Host "   Expected path: $indexPath" -ForegroundColor Gray
            Write-Host "   Available files:" -ForegroundColor Gray
            Get-ChildItem $modpackDir | ForEach-Object { Write-Host "     $($_.Name)" -ForegroundColor Gray }
            return 0
        }
        
        $indexContent = Get-Content $indexPath | ConvertFrom-Json
        Write-Host "📋 Processing modpack index with $($indexContent.files.Count) files..." -ForegroundColor Cyan
        
        # Download files from the index
        $successCount = 0
        $errorCount = 0
        foreach ($file in $indexContent.files) {
            $filePath = $file.path
            $downloadUrl = $file.downloads[0]  # Use first download URL
            
            # Create the target directory
            $targetDir = Split-Path -Path (Join-Path $downloadDir $filePath) -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            $targetPath = Join-Path $downloadDir $filePath
            
            # Download the file
            try {
                if ((Test-Path $targetPath) -and (-not $ForceDownload)) {
                    Write-Host "  ⏭️  Skipped: $filePath (already exists)" -ForegroundColor Gray
                } else {
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $targetPath -UseBasicParsing
                    Write-Host "  ✅ Downloaded: $filePath" -ForegroundColor Green
                    $successCount++
                }
            } catch {
                Write-Host "  ❌ Failed: $filePath - $($_.Exception.Message)" -ForegroundColor Red
                $errorCount++
            }
        }
        
        # Handle overrides folder
        $overridesPath = Join-Path $modpackDir "overrides"
        if (Test-Path $overridesPath) {
            Write-Host "📁 Copying overrides folder contents..." -ForegroundColor Yellow
            Copy-Item -Path "$overridesPath\*" -Destination $downloadDir -Recurse -Force
            Write-Host "✅ Copied overrides to $downloadDir" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "📦 Modpack installation complete!" -ForegroundColor Green
        Write-Host "✅ Successfully downloaded: $successCount files" -ForegroundColor Green
        Write-Host "⏭️  Skipped (already exists): $(($indexContent.files.Count - $successCount - $errorCount))" -ForegroundColor Yellow
        Write-Host "❌ Failed: $errorCount files" -ForegroundColor Red
        return $successCount
    } catch {
        Write-Host "❌ Modpack download failed: $($_.Exception.Message)" -ForegroundColor Red
        return 0
    }
}

# Function to download mods
function Download-Mods {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$DownloadFolder = "download",
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
        if (-not (Test-Path $DownloadFolder)) {
            New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
            Write-Host "Created mods folder: $DownloadFolder" -ForegroundColor Green
        }
        
        # Determine which version folders need to be cleared
        $versionsToClear = @()
        if ($UseLatestVersion) {
            # For latest versions, only clear the majority version folder
            $versionsToClear = @($targetGameVersion)
            Write-Host "Will clear version folder: $targetGameVersion" -ForegroundColor Yellow
        } else {
            # For current versions, clear all version folders that will be written to
            $versionsToClear = $mods | Where-Object { -not [string]::IsNullOrEmpty($_.GameVersion) } | 
                              Select-Object -ExpandProperty GameVersion | Sort-Object -Unique
            Write-Host "Will clear version folders: $($versionsToClear -join ', ')" -ForegroundColor Yellow
        }
        
        # Clear the specific version folders
        foreach ($version in $versionsToClear) {
            $versionFolder = Join-Path $DownloadFolder $version
            if (Test-Path $versionFolder) {
                Remove-Item -Recurse -Force $versionFolder -ErrorAction SilentlyContinue
                Write-Host "Cleared version folder: $version" -ForegroundColor Yellow
            }
        }
        
        $downloadResults = @()
        $successCount = 0
        $errorCount = 0
        $missingSystemFiles = @()
        
        Write-Host "Starting mod downloads..." -ForegroundColor Yellow
        Write-Host ""
        
        # Track files that existed before the download loop
        $preExistingFiles = @{}
        $downloadedThisRun = @{}
        foreach ($mod in $mods) {
            # Determine filename as in the main loop
            $loader = if (-not [string]::IsNullOrEmpty($mod.Loader)) { $mod.Loader.Trim() } else { $DefaultLoader }
            $modHost = if (-not [string]::IsNullOrEmpty($mod.Host)) { $mod.Host } else { "modrinth" }
            $gameVersion = if (-not [string]::IsNullOrEmpty($mod.GameVersion)) { $mod.GameVersion } else { $DefaultGameVersion }
            $jarFilename = if (-not [string]::IsNullOrEmpty($mod.Jar)) { $mod.Jar } else { "" }
            $downloadUrl = $mod.Url
            $filename = $null
            if ($mod.Type -in @("installer", "launcher", "server")) {
                if ($jarFilename) {
                    $filename = $jarFilename
                } else {
                    $filename = [System.IO.Path]::GetFileName($downloadUrl)
                    if (-not $filename -or $filename -eq "") {
                        $filename = "$($mod.ID)-$($mod.Version).jar"
                    }
                }
            } elseif ($jarFilename -and -not $UseLatestVersion) {
                $filename = $jarFilename
            } else {
                $filename = [System.IO.Path]::GetFileName($downloadUrl)
                if (-not $filename -or $filename -eq "") {
                    $filename = "$($mod.ID)-$($mod.Version).jar"
                }
            }
            if ($mod.Type -eq "shaderpack") {
                $filename = Clean-Filename $filename
            }
            $gameVersionFolder = if ($UseLatestVersion) { Join-Path $DownloadFolder $targetGameVersion } else { Join-Path $DownloadFolder $gameVersion }
            if ($mod.Type -eq "shaderpack") {
                $gameVersionFolder = Join-Path $gameVersionFolder "shaderpacks"
            } elseif ($mod.Type -eq "installer") {
                $gameVersionFolder = Join-Path $gameVersionFolder "installer"
            } elseif ($mod.Type -eq "modpack") {
                $gameVersionFolder = Join-Path $gameVersionFolder "modpacks"
            } elseif ($mod.Type -eq "launcher" -or $mod.Type -eq "server") {
                # No subfolder
            } else {
                $gameVersionFolder = Join-Path $gameVersionFolder "mods"
                if ($mod.Group -eq "block") {
                    $gameVersionFolder = Join-Path $gameVersionFolder "block"
                }
            }
            $downloadPath = Join-Path $gameVersionFolder $filename
            if (Test-Path $downloadPath) {
                $preExistingFiles[$downloadPath] = $true
            }
        }
        
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
                
                # For system entries (installer, launcher, server), handle differently based on UseLatestVersion
                if ($mod.Type -in @("installer", "launcher", "server")) {
                    if ($UseLatestVersion) {
                        # When using latest version, find system entry that matches target game version
                        $matchingSystemEntry = $mods | Where-Object { 
                            $_.Type -eq $mod.Type -and 
                            $_.GameVersion -eq $targetGameVersion -and
                            $_.Name -eq $mod.Name 
                        } | Select-Object -First 1
                        
                        if ($matchingSystemEntry) {
                            $downloadUrl = $matchingSystemEntry.Url
                            $downloadVersion = $matchingSystemEntry.Version
                            $jarFilename = $matchingSystemEntry.Jar
                        } else {
                            Write-Host "❌ $($mod.Name): No $($mod.Type) found for game version $targetGameVersion" -ForegroundColor Red
                            $missingSystemFiles += [PSCustomObject]@{
                                Name = $mod.Name
                                Type = $mod.Type
                                RequiredVersion = $targetGameVersion
                                AvailableVersions = ($mods | Where-Object { $_.Type -eq $mod.Type -and $_.Name -eq $mod.Name } | Select-Object -ExpandProperty GameVersion) -join ", "
                            }
                            $errorCount++
                            continue
                        }
                    } else {
                        # For current versions, use the direct URL from the current entry
                        if ($mod.Url) {
                            $downloadUrl = $mod.Url
                            $downloadVersion = $mod.Version
                            # Keep the original jarFilename for system entries when not using latest version
                        } else {
                            Write-Host "❌ $($mod.Name): No direct URL available for system entry" -ForegroundColor Red
                            $errorCount++
                            continue
                        }
                    }
                } elseif ($UseLatestVersion -and $mod.LatestVersionUrl) {
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
                    # For latest versions, use majority version for migration
                    Join-Path $DownloadFolder $targetGameVersion 
                } else { 
                    # For current versions, use the GameVersion column from CSV
                    Join-Path $DownloadFolder $gameVersion 
                }
                
                # Create appropriate subfolder based on mod type and group
                if ($mod.Type -eq "shaderpack") {
                    # Shaderpacks go directly in the game version folder
                    $gameVersionFolder = Join-Path $gameVersionFolder "shaderpacks"
                } elseif ($mod.Type -eq "installer") {
                    # Installers go in the installer subfolder
                    $gameVersionFolder = Join-Path $gameVersionFolder "installer"
                } elseif ($mod.Type -eq "modpack") {
                    # Modpacks use special download process - call Download-Modpack function
                    Write-Host "📦 $($mod.Name): Processing modpack..." -ForegroundColor Cyan
                    
                    $modpackResult = Download-Modpack -ModId $mod.ID -VersionUrl $downloadUrl -ModName $mod.Name -GameVersion $gameVersion -DownloadFolder $DownloadFolder -ForceDownload:$ForceDownload
                    
                    if ($modpackResult -gt 0) {
                        $downloadResults += [PSCustomObject]@{
                            Name = $mod.Name
                            Status = "Success"
                            Version = $downloadVersion
                            File = "modpack"
                            Path = "$gameVersionFolder\modpacks\$($mod.Name)"
                            Size = "modpack"
                            Error = $null
                        }
                        $successCount++
                    } else {
                        $downloadResults += [PSCustomObject]@{
                            Name = $mod.Name
                            Status = "Failed"
                            Version = $downloadVersion
                            File = "modpack"
                            Path = "$gameVersionFolder\modpacks\$($mod.Name)"
                            Size = $null
                            Error = "Modpack download failed"
                        }
                        $errorCount++
                    }
                    continue  # Skip normal download process for modpacks
                } elseif ($mod.Type -eq "launcher" -or $mod.Type -eq "server") {
                    # Launchers and server JARs go directly in the game version folder (root)
                    # No subfolder needed
                } else {
                    # Mods go in the mods subfolder
                    $gameVersionFolder = Join-Path $gameVersionFolder "mods"
                    
                    # Create block subfolder if mod is in "block" group
                    if ($mod.Group -eq "block") {
                        $gameVersionFolder = Join-Path $gameVersionFolder "block"
                    }
                }
                
                if (-not (Test-Path $gameVersionFolder)) {
                    New-Item -ItemType Directory -Path $gameVersionFolder -Force | Out-Null
                }
                
                # Determine filename for download
                $filename = $null
                if ($mod.Type -in @("installer", "launcher", "server")) {
                    if ($jarFilename) {
                        $filename = $jarFilename
                    } else {
                        $filename = [System.IO.Path]::GetFileName($downloadUrl)
                        if (-not $filename -or $filename -eq "") {
                            $filename = "$($mod.ID)-$downloadVersion.jar"
                        }
                    }
                } elseif ($jarFilename -and -not $UseLatestVersion) {
                    # Use the JAR filename from CSV if available and not using latest version
                    $filename = $jarFilename
                } else {
                    # Extract filename from URL or use mod ID
                    $filename = [System.IO.Path]::GetFileName($downloadUrl)
                    if (-not $filename -or $filename -eq "") {
                        $filename = "$($mod.ID)-$downloadVersion.jar"
                    }
                }
                # Clean filename for shaderpacks
                if ($mod.Type -eq "shaderpack") {
                    $filename = Clean-Filename $filename
                }
                
                $downloadPath = Join-Path $gameVersionFolder $filename
                
                # Check if file already exists
                if ((Test-Path $downloadPath) -and -not $ForceDownload) {
                    if ($preExistingFiles[$downloadPath] -and -not $downloadedThisRun[$downloadPath]) {
                        Write-Host "⏭️  $($mod.Name): Already exists ($filename)" -ForegroundColor Yellow
                        $downloadResults += [PSCustomObject]@{
                            Name = $mod.Name
                            Status = "Skipped"
                            Version = $downloadVersion
                            File = $filename
                            Path = $downloadPath
                            Error = "File already exists"
                        }
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
                        $preExistingFiles[$downloadPath] = $true
                        $downloadedThisRun[$downloadPath] = $true
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
        
        # Ensure the ApiResponseFolder directory exists
        if (-not (Test-Path $ApiResponseFolder)) {
            New-Item -ItemType Directory -Path $ApiResponseFolder -Force | Out-Null
            Write-Host "Created API response directory: $ApiResponseFolder" -ForegroundColor Cyan
        }
        
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
        
        # Show missing system files if using latest version
        if ($UseLatestVersion -and $missingSystemFiles.Count -gt 0) {
            Write-Host ""
            Write-Host "Missing System Files for ${targetGameVersion}:" -ForegroundColor Red
            Write-Host "=============================================" -ForegroundColor Red
            foreach ($missing in $missingSystemFiles) {
                Write-Host "❌ $($missing.Name) ($($missing.Type))" -ForegroundColor Red
                Write-Host "   Required version: $($missing.RequiredVersion)" -ForegroundColor Yellow
                Write-Host "   Available versions: $($missing.AvailableVersions)" -ForegroundColor Yellow
                Write-Host "   Please add missing $($missing.Type) for $($missing.RequiredVersion)" -ForegroundColor Cyan
                Write-Host ""
            }
        }
        
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
            $versionFolder = Join-Path $DownloadFolder $targetGameVersion
            Write-DownloadReadme -FolderPath $versionFolder -Analysis $versionAnalysis -DownloadResults $downloadResults -TargetVersion $targetGameVersion -UseLatestVersion $UseLatestVersion
        }
        
        return
    }
    catch {
        Write-Error "Failed to download mods: $($_.Exception.Message)"
        return 0
    }
}

# Function to download server JARs and Fabric launchers
function Download-ServerFiles {
    param(
        [string]$DownloadFolder = "download",
        [switch]$ForceDownload
    )
    
    try {
        Write-Host "Downloading server files..." -ForegroundColor Yellow
        
        # Create download folder if it doesn't exist
        if (-not (Test-Path $DownloadFolder)) {
            New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
        }
        
        $downloadResults = @()
        $successCount = 0
        $errorCount = 0
        
        # Server JARs to download
        $serverFiles = @(
            @{
                Version = "1.21.5"
                Url = "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar"
                Filename = "minecraft_server.1.21.5.jar"
            },
            @{
                Version = "1.21.6"
                Url = "https://piston-data.mojang.com/v1/objects/6e64dcabba3c01a7271b4fa6bd898483b794c59b/server.jar"
                Filename = "minecraft_server.1.21.6.jar"
            }
        )
        
        # Fabric launchers to download
        $launcherFiles = @(
            @{
                Version = "1.21.5"
                Url = "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar"
                Filename = "fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar"
            },
            @{
                Version = "1.21.6"
                Url = "https://meta.fabricmc.net/v2/versions/loader/1.21.6/0.16.14/1.0.3/server/jar"
                Filename = "fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar"
            }
        )
        
        # Download server JARs
        foreach ($server in $serverFiles) {
            $versionFolder = Join-Path $DownloadFolder $server.Version
            if (-not (Test-Path $versionFolder)) {
                New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
            }
            
            $downloadPath = Join-Path $versionFolder $server.Filename
            
            # Check if file already exists
            if ((Test-Path $downloadPath) -and -not $ForceDownload) {
                Write-Host "⏭️  $($server.Filename): Already exists" -ForegroundColor Yellow
                $downloadResults += [PSCustomObject]@{
                    Name = $server.Filename
                    Status = "Skipped"
                    Version = $server.Version
                    File = $server.Filename
                    Path = $downloadPath
                    Error = "File already exists"
                }
                continue
            }
            
            # Download the file
            Write-Host "⬇️  $($server.Filename): Downloading..." -ForegroundColor Cyan
            
            try {
                $webRequest = Invoke-WebRequest -Uri $server.Url -OutFile $downloadPath -UseBasicParsing
                
                if (Test-Path $downloadPath) {
                    $fileSize = (Get-Item $downloadPath).Length
                    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                    
                    Write-Host "✅ $($server.Filename): Downloaded successfully ($fileSizeMB MB)" -ForegroundColor Green
                    
                    $downloadResults += [PSCustomObject]@{
                        Name = $server.Filename
                        Status = "Success"
                        Version = $server.Version
                        File = $server.Filename
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
                Write-Host "❌ $($server.Filename): Download failed - $($_.Exception.Message)" -ForegroundColor Red
                
                # Clean up partial download if it exists
                if (Test-Path $downloadPath) {
                    Remove-Item $downloadPath -Force
                }
                
                $downloadResults += [PSCustomObject]@{
                    Name = $server.Filename
                    Status = "Failed"
                    Version = $server.Version
                    File = $server.Filename
                    Path = $downloadPath
                    Size = $null
                    Error = $_.Exception.Message
                }
                $errorCount++
            }
        }
        
        # Download Fabric launchers
        foreach ($launcher in $launcherFiles) {
            $versionFolder = Join-Path $DownloadFolder $launcher.Version
            if (-not (Test-Path $versionFolder)) {
                New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
            }
            
            $downloadPath = Join-Path $versionFolder $launcher.Filename
            
            # Check if file already exists
            if ((Test-Path $downloadPath) -and -not $ForceDownload) {
                Write-Host "⏭️  $($launcher.Filename): Already exists" -ForegroundColor Yellow
                $downloadResults += [PSCustomObject]@{
                    Name = $launcher.Filename
                    Status = "Skipped"
                    Version = $launcher.Version
                    File = $launcher.Filename
                    Path = $downloadPath
                    Error = "File already exists"
                }
                continue
            }
            
            # Download the file
            Write-Host "⬇️  $($launcher.Filename): Downloading..." -ForegroundColor Cyan
            
            try {
                $webRequest = Invoke-WebRequest -Uri $launcher.Url -OutFile $downloadPath -UseBasicParsing
                
                if (Test-Path $downloadPath) {
                    $fileSize = (Get-Item $downloadPath).Length
                    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                    
                    Write-Host "✅ $($launcher.Filename): Downloaded successfully ($fileSizeMB MB)" -ForegroundColor Green
                    
                    $downloadResults += [PSCustomObject]@{
                        Name = $launcher.Filename
                        Status = "Success"
                        Version = $launcher.Version
                        File = $launcher.Filename
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
                Write-Host "❌ $($launcher.Filename): Download failed - $($_.Exception.Message)" -ForegroundColor Red
                
                # Clean up partial download if it exists
                if (Test-Path $downloadPath) {
                    Remove-Item $downloadPath -Force
                }
                
                $downloadResults += [PSCustomObject]@{
                    Name = $launcher.Filename
                    Status = "Failed"
                    Version = $launcher.Version
                    File = $launcher.Filename
                    Path = $downloadPath
                    Size = $null
                    Error = $_.Exception.Message
                }
                $errorCount++
            }
        }
        
        # Display summary
        Write-Host ""
        Write-Host "Server Files Download Summary:" -ForegroundColor Yellow
        Write-Host "=============================" -ForegroundColor Yellow
        Write-Host "✅ Successfully downloaded: $successCount" -ForegroundColor Green
        Write-Host "⏭️  Skipped (already exists): $(($downloadResults | Where-Object { $_.Status -eq "Skipped" }).Count)" -ForegroundColor Yellow
        Write-Host "❌ Failed: $errorCount" -ForegroundColor Red
        
        # Show failed downloads
        if ($errorCount -gt 0) {
            Write-Host ""
            Write-Host "Failed downloads:" -ForegroundColor Red
            foreach ($result in $downloadResults | Where-Object { $_.Status -eq "Failed" }) {
                Write-Host "  ❌ $($result.Name): $($result.Error)" -ForegroundColor Red
            }
        }
        
        return $successCount
    }
    catch {
        Write-Error "Failed to download server files: $($_.Exception.Message)"
        return 0
    }
}

# Function to start Minecraft server with error checking
function Start-MinecraftServer {
    param(
        [string]$DownloadFolder = "download",
        [string]$ScriptSource = (Join-Path $PSScriptRoot "tools/start-server.ps1")
    )
    
    Write-Host "🚀 Starting Minecraft server..." -ForegroundColor Green
    
    # Check Java version first
    Write-Host "🔍 Checking Java version..." -ForegroundColor Cyan
    try {
        $javaVersion = java -version 2>&1 | Select-String "version" | Select-Object -First 1
        if (-not $javaVersion) {
            Write-Host "❌ Java is not installed or not in PATH" -ForegroundColor Red
            Write-Host "💡 Please install Java 22+ and ensure it's in your PATH" -ForegroundColor Yellow
            return $false
        }
        
        # Extract version number
        if ($javaVersion -match '"([^"]+)"') {
            $versionString = $matches[1]
            Write-Host "📋 Found Java version: $versionString" -ForegroundColor Gray
            
            # Parse version to check if it's 22+
            if ($versionString -match "^(\d+)") {
                $majorVersion = [int]$matches[1]
                if ($majorVersion -lt 22) {
                    Write-Host "❌ Java version $majorVersion is too old" -ForegroundColor Red
                    Write-Host "💡 Minecraft server requires Java 22+ (found version $majorVersion)" -ForegroundColor Yellow
                    Write-Host "💡 Please upgrade to Java 22 or later" -ForegroundColor Yellow
                    return $false
                } else {
                    Write-Host "✅ Java version $majorVersion is compatible" -ForegroundColor Green
                }
            } else {
                Write-Host "⚠️  Could not parse Java version: $versionString" -ForegroundColor Yellow
                Write-Host "💡 Please ensure you have Java 22+ installed" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠️  Could not determine Java version" -ForegroundColor Yellow
            Write-Host "💡 Please ensure you have Java 22+ installed" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Error checking Java version: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Please ensure Java 22+ is installed and in PATH" -ForegroundColor Yellow
        return $false
    }
    
    # Check if download folder exists
    if (-not (Test-Path $DownloadFolder)) {
        Write-Host "❌ Download folder not found: $DownloadFolder" -ForegroundColor Red
        Write-Host "💡 Run -DownloadMods first to create the download folder" -ForegroundColor Yellow
        return $false
    }
    
    # Check if start-server script exists
    if (-not (Test-Path $ScriptSource)) {
        Write-Host "❌ Start server script not found: $ScriptSource" -ForegroundColor Red
        return $false
    }
    
    # Find the most recent version folder
    $versionFolders = Get-ChildItem -Path $DownloadFolder -Directory -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Name -match "^\d+\.\d+\.\d+" } |
                     Sort-Object Name -Descending
    
    if ($versionFolders.Count -eq 0) {
        Write-Host "❌ No version folders found in $DownloadFolder" -ForegroundColor Red
        Write-Host "💡 Run -DownloadMods first to download server files" -ForegroundColor Yellow
        return $false
    }
    
    $targetVersion = $versionFolders[0].Name
    $targetFolder = Join-Path $DownloadFolder $targetVersion
    
    Write-Host "📁 Using version folder: $targetFolder" -ForegroundColor Cyan
    
    # Copy start-server script to target folder
    $serverScript = Join-Path $targetFolder "start-server.ps1"
    try {
        Copy-Item -Path $ScriptSource -Destination $serverScript -Force
        Write-Host "✅ Copied start-server script to: $serverScript" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to copy start-server script: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Check for Fabric server JAR in target folder
    $fabricJars = Get-ChildItem -Path $targetFolder -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue
    if ($fabricJars.Count -eq 0) {
        Write-Host "❌ No Fabric server JAR found in $targetFolder" -ForegroundColor Red
        Write-Host "💡 Make sure you have downloaded the Fabric server launcher" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "✅ Found Fabric server JAR: $($fabricJars[0].Name)" -ForegroundColor Green
    
    # Create logs directory
    $logsDir = Join-Path $targetFolder "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        Write-Host "📁 Created logs directory: $logsDir" -ForegroundColor Green
    }
    
    # Start the server as a background job
    Write-Host "🔄 Starting server as background job..." -ForegroundColor Cyan
    Write-Host "📋 Server logs will be saved to: $logsDir" -ForegroundColor Gray
    
    try {
        # Start the server as a background job
        $job = Start-Job -ScriptBlock {
            param($ScriptPath, $WorkingDir)
            Set-Location $WorkingDir
            & $ScriptPath
        } -ArgumentList $serverScript, $targetFolder
        
        Write-Host "✅ Server job started successfully (Job ID: $($job.Id))" -ForegroundColor Green
        Write-Host "🔄 Monitoring server logs for errors..." -ForegroundColor Cyan
        
        # Monitor logs for errors
        $logFile = $null
        $startTime = Get-Date
        $timeout = 60  # Wait up to 60 seconds for log file to appear
        
        # Wait for log file to be created
        while ((Get-Date) -lt ($startTime.AddSeconds($timeout))) {
            $logFiles = Get-ChildItem -Path $logsDir -Filter "console-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
            if ($logFiles.Count -gt 0) {
                $logFile = $logFiles[0].FullName
                break
            }
            Start-Sleep -Seconds 1
        }
        
        if (-not $logFile) {
            Write-Host "⚠️  No log file found after $timeout seconds" -ForegroundColor Yellow
            Write-Host "💡 Checking job status..." -ForegroundColor Cyan
            
            # Check job status
            $jobStatus = Get-Job -Id $job.Id
            if ($jobStatus.State -eq "Failed") {
                Write-Host "❌ Server job failed: $($jobStatus.JobStateInfo.Reason)" -ForegroundColor Red
                $jobOutput = Receive-Job -Id $job.Id -ErrorAction SilentlyContinue
                if ($jobOutput) {
                    Write-Host "📄 Job output: $jobOutput" -ForegroundColor Gray
                }
            }
            return $false
        }
        
        Write-Host "📄 Monitoring log file: $logFile" -ForegroundColor Gray
        
        # Monitor for errors for a longer period
        $monitorTime = 60  # Monitor for 60 seconds
        $monitorStart = Get-Date
        $errorFound = $false
        $lastLogSize = 0
        
        while ((Get-Date) -lt ($monitorStart.AddSeconds($monitorTime)) -and -not $errorFound) {
            # Check if job is still running
            $jobStatus = Get-Job -Id $job.Id
            if ($jobStatus.State -eq "Failed" -or $jobStatus.State -eq "Completed") {
                Write-Host "❌ Server job stopped unexpectedly (State: $($jobStatus.State))" -ForegroundColor Red
                $jobOutput = Receive-Job -Id $job.Id -ErrorAction SilentlyContinue
                if ($jobOutput) {
                    Write-Host "📄 Job output: $jobOutput" -ForegroundColor Gray
                }
                $errorFound = $true
                break
            }
            
            # Check log file for errors
            if (Test-Path $logFile) {
                $currentLogSize = (Get-Item $logFile).Length
                if ($currentLogSize -gt $lastLogSize) {
                    $newLines = Get-Content $logFile -Tail 10 -ErrorAction SilentlyContinue
                    foreach ($line in $newLines) {
                        if ($line -match "(ERROR|FATAL|Exception|Failed|Error)" -and $line -notmatch "Server exited") {
                            Write-Host "❌ Error detected in logs: $line" -ForegroundColor Red
                            $errorFound = $true
                            break
                        }
                    }
                    $lastLogSize = $currentLogSize
                }
            }
            
            Start-Sleep -Seconds 2
        }
        
        if ($errorFound) {
            Write-Host "⚠️  Errors detected during server startup" -ForegroundColor Yellow
            Write-Host "🛑 Stopping server job..." -ForegroundColor Cyan
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -ErrorAction SilentlyContinue
            Write-Host "📄 Check the log file for details: $logFile" -ForegroundColor Gray
            exit 1
        } else {
            Write-Host "✅ No errors detected in server startup" -ForegroundColor Green
            Write-Host "🎮 Server appears to be running successfully" -ForegroundColor Green
            Write-Host "💡 Use 'Get-Job -Id $($job.Id)' to check server status" -ForegroundColor Gray
            Write-Host "💡 Use 'Stop-Job -Id $($job.Id)' to stop the server" -ForegroundColor Gray
            Write-Host "💡 Use 'Remove-Job -Id $($job.Id)' to clean up the job" -ForegroundColor Gray
            return $true
        }
    }
    catch {
        Write-Host "❌ Failed to start server: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to download CurseForge modpack
function Download-CurseForgeModpack {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModpackId,
        [Parameter(Mandatory=$true)]
        [string]$FileId,
        [Parameter(Mandatory=$true)]
        [string]$ModpackName,
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder,
        [bool]$ForceDownload = $false
    )
    try {
        Write-Host "📦 Downloading CurseForge modpack: $ModpackName" -ForegroundColor Cyan
        Write-Host "   Modpack ID: $ModpackId, File ID: $FileId" -ForegroundColor Gray
        
        # Create download directory structure
        $downloadDir = Join-Path $DownloadFolder $GameVersion
        $modpackDir = Join-Path $downloadDir "modpacks\$ModpackName"
        if (-not (Test-Path $downloadDir)) {
            New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
        }
        if (-not (Test-Path $modpackDir)) {
            New-Item -ItemType Directory -Path $modpackDir -Force | Out-Null
        }
        
        # Download the modpack ZIP file
        $zipFileName = "$ModpackName.zip"
        $zipPath = Join-Path $modpackDir $zipFileName
        
        if ((Test-Path $zipPath) -and (-not $ForceDownload)) {
            Write-Host "⏭️  Modpack file already exists, skipping download" -ForegroundColor Yellow
        } else {
            Write-Host "⬇️  Downloading modpack file..." -ForegroundColor Yellow
            
            # Construct download URL
            $downloadUrl = "https://www.curseforge.com/api/v1/mods/$ModpackId/files/$FileId/download"
            
            try {
                $headers = @{ "Content-Type" = "application/json" }
                if ($CurseForgeApiKey) { $headers["X-API-Key"] = $CurseForgeApiKey }
                
                Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -Headers $headers -UseBasicParsing
                Write-Host "✅ Downloaded modpack file" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to download modpack file: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
        
        # Extract the ZIP file
        Write-Host "📂 Extracting modpack..." -ForegroundColor Yellow
        try {
            Expand-Archive -Path $zipPath -DestinationPath $modpackDir -Force
        } catch {
            Write-Host "❌ Failed to extract modpack: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
        
        # Find and process manifest.json
        $manifestPath = Join-Path $modpackDir "manifest.json"
        if (-not (Test-Path $manifestPath)) {
            Write-Host "❌ manifest.json not found in extracted modpack" -ForegroundColor Red
            Write-Host "   Expected path: $manifestPath" -ForegroundColor Gray
            Write-Host "   Available files:" -ForegroundColor Gray
            Get-ChildItem $modpackDir | ForEach-Object { Write-Host "     $($_.Name)" -ForegroundColor Gray }
            return 0
        }
        
        $manifestContent = Get-Content $manifestPath | ConvertFrom-Json
        Write-Host "📋 Processing modpack manifest with $($manifestContent.files.Count) files..." -ForegroundColor Cyan
        
        # Parse dependencies for database storage
        $dependencies = Parse-CurseForgeModpackDependencies -ManifestPath $manifestPath
        Write-Host "📋 Parsed $($manifestContent.files.Count) dependencies for database storage" -ForegroundColor Cyan
        
        # Download files from the manifest
        $successCount = 0
        $errorCount = 0
        foreach ($file in $manifestContent.files) {
            $projectId = $file.fileID
            $fileId = $file.fileID
            
            # Get file information from CurseForge API
            $fileInfo = Get-CurseForgeFileInfo -ModId $projectId -FileId $fileId
            if (-not $fileInfo) {
                Write-Host "  ❌ Failed to get file info for project $projectId, file $fileId" -ForegroundColor Red
                $errorCount++
                continue
            }
            
            # Determine target path based on file type
            $targetPath = $null
            if ($fileInfo.fileName -match "\.jar$") {
                $targetPath = Join-Path $downloadDir "mods\$($fileInfo.fileName)"
            } elseif ($fileInfo.fileName -match "\.zip$") {
                $targetPath = Join-Path $downloadDir "resourcepacks\$($fileInfo.fileName)"
            } else {
                $targetPath = Join-Path $downloadDir "overrides\$($fileInfo.fileName)"
            }
            
            # Create the target directory
            $targetDir = Split-Path -Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            
            # Download the file
            try {
                if ((Test-Path $targetPath) -and (-not $ForceDownload)) {
                    Write-Host "  ⏭️  Skipped: $($fileInfo.fileName) (already exists)" -ForegroundColor Gray
                } else {
                    $fileDownloadUrl = "https://www.curseforge.com/api/v1/mods/$projectId/files/$fileId/download"
                    Invoke-WebRequest -Uri $fileDownloadUrl -OutFile $targetPath -Headers $headers -UseBasicParsing
                    Write-Host "  ✅ Downloaded: $($fileInfo.fileName)" -ForegroundColor Green
                    $successCount++
                }
            } catch {
                Write-Host "  ❌ Failed: $($fileInfo.fileName) - $($_.Exception.Message)" -ForegroundColor Red
                $errorCount++
            }
        }
        
        # Handle overrides folder
        $overridesPath = Join-Path $modpackDir "overrides"
        if (Test-Path $overridesPath) {
            Write-Host "📁 Copying overrides folder contents..." -ForegroundColor Yellow
            Copy-Item -Path "$overridesPath\*" -Destination $downloadDir -Recurse -Force
            Write-Host "✅ Copied overrides to $downloadDir" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "📦 CurseForge modpack installation complete!" -ForegroundColor Green
        Write-Host "✅ Successfully downloaded: $successCount files" -ForegroundColor Green
        Write-Host "⏭️  Skipped (already exists): $(($manifestContent.files.Count - $successCount - $errorCount))" -ForegroundColor Yellow
        Write-Host "❌ Failed: $errorCount files" -ForegroundColor Red
        return $successCount
    } catch {
        Write-Host "❌ CurseForge modpack download failed: $($_.Exception.Message)" -ForegroundColor Red
        return 0
    }
}

# Function to get CurseForge file information
function Get-CurseForgeFileInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        [Parameter(Mandatory=$true)]
        [string]$FileId
    )
    try {
        $apiUrl = "$CurseForgeApiBaseUrl/mods/$ModId/files/$FileId"
        $responseFile = Get-ApiResponsePath -ModId "$ModId-$FileId" -ResponseType "file" -Domain "curseforge" -BaseResponseFolder $ApiResponseFolder
        
        # Check if we should use cached responses
        if ($UseCachedResponses -and (Test-Path $responseFile)) {
            Write-Host ("  → Using cached CurseForge file response for {0}-{1}..." -f $ModId, $FileId) -ForegroundColor DarkGray
            $response = Get-Content -Path $responseFile -Raw | ConvertFrom-Json
        } else {
            # Make API request
            Write-Host ("  → Calling CurseForge API for file {0}-{1}..." -f $ModId, $FileId) -ForegroundColor DarkGray
            $headers = @{ "Content-Type" = "application/json" }
            if ($CurseForgeApiKey) { $headers["X-API-Key"] = $CurseForgeApiKey }
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers
            
            # Save response to file
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        }
        
        return $response.data
    } catch {
        Write-Host "❌ Failed to get CurseForge file info: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to parse CurseForge modpack dependencies
function Parse-CurseForgeModpackDependencies {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ManifestPath
    )
    try {
        if (-not (Test-Path $ManifestPath)) {
            Write-Host "❌ Manifest file not found: $ManifestPath" -ForegroundColor Red
            return @()
        }
        
        $manifest = Get-Content $ManifestPath | ConvertFrom-Json
        $dependencies = @()
        
        foreach ($file in $manifest.files) {
            $dependency = @{
                ProjectId = $file.fileID
                FileId = $file.fileID
                Required = $true
                Type = "required"
                Host = "curseforge"
            }
            $dependencies += $dependency
        }
        
        # Convert to JSON string for storage in CSV
        $dependenciesJson = $dependencies | ConvertTo-Json -Compress
        return $dependenciesJson
    } catch {
        Write-Host "❌ Failed to parse CurseForge modpack dependencies: $($_.Exception.Message)" -ForegroundColor Red
        return ""
    }
}

# Function to validate CurseForge modpack
function Validate-CurseForgeModpack {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModpackId,
        [Parameter(Mandatory=$true)]
        [string]$FileId
    )
    try {
        Write-Host "🔍 Validating CurseForge modpack: $ModpackId, File: $FileId" -ForegroundColor Cyan
        
        # Get modpack information
        $apiUrl = "$CurseForgeApiBaseUrl/mods/$ModpackId"
        $responseFile = Get-ApiResponsePath -ModId $ModpackId -ResponseType "project" -Domain "curseforge" -BaseResponseFolder $ApiResponseFolder
        
        # Check if we should use cached responses
        if ($UseCachedResponses -and (Test-Path $responseFile)) {
            Write-Host ("  → Using cached CurseForge response for modpack {0}..." -f $ModpackId) -ForegroundColor DarkGray
            $response = Get-Content -Path $responseFile -Raw | ConvertFrom-Json
        } else {
            # Make API request
            Write-Host ("  → Calling CurseForge API for modpack {0}..." -f $ModpackId) -ForegroundColor DarkGray
            $headers = @{ "Content-Type" = "application/json" }
            if ($CurseForgeApiKey) { $headers["X-API-Key"] = $CurseForgeApiKey }
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers
            
            # Save response to file
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
        }
        
        $modpackInfo = $response.data
        
        # Get file information
        $fileInfo = Get-CurseForgeFileInfo -ModId $ModpackId -FileId $FileId
        if (-not $fileInfo) {
            return [PSCustomObject]@{
                Valid = $false
                Error = "Failed to get file information"
                ModpackName = $null
                GameVersion = $null
                FileName = $null
                DownloadUrl = $null
            }
        }
        
        return [PSCustomObject]@{
            Valid = $true
            ModpackName = $modpackInfo.name
            GameVersion = $fileInfo.gameVersions[0]
            FileName = $fileInfo.fileName
            DownloadUrl = $fileInfo.downloadUrl
            ModpackId = $ModpackId
            FileId = $FileId
        }
    } catch {
        return [PSCustomObject]@{
            Valid = $false
            Error = $_.Exception.Message
            ModpackName = $null
            GameVersion = $null
            FileName = $null
            DownloadUrl = $null
        }
    }
}

# Function to handle CurseForge API rate limits
function Invoke-CurseForgeApiWithRateLimit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [string]$Method = "Get",
        [hashtable]$Headers = @{},
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 5
    )
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            # Add API key if available
            if ($CurseForgeApiKey) { $Headers["X-API-Key"] = $CurseForgeApiKey }
            
            $response = Invoke-RestMethod -Uri $Url -Method $Method -Headers $Headers -UseBasicParsing
            return $response
        } catch {
            if ($_.Exception.Response.StatusCode -eq 429) {
                Write-Host "⚠️  Rate limited by CurseForge API. Waiting $RetryDelaySeconds seconds before retry $attempt/$MaxRetries..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelaySeconds
                $RetryDelaySeconds *= 2  # Exponential backoff
            } else {
                throw
            }
        }
    }
    
    throw "Failed to complete API request after $MaxRetries attempts"
}

# Function to add CurseForge modpack to modlist.csv
function Add-CurseForgeModpackToDatabase {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModpackId,
        [Parameter(Mandatory=$true)]
        [string]$FileId,
        [Parameter(Mandatory=$true)]
        [string]$ModpackName,
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [string]$Dependencies = ""
    )
    try {
        # Load existing mods
        $mods = @()
        if (Test-Path $CsvPath) {
            $mods = Import-Csv $CsvPath
        }
        
        # Ensure CSV has required columns
        $mods = Ensure-CsvColumns -CsvPath $CsvPath
        
        # Create new modpack entry
        $newModpack = [PSCustomObject]@{
            Group = "required"
            Type = "modpack"
            GameVersion = $GameVersion
            ID = $ModpackId
            Loader = "fabric"  # Default, can be updated later
            Version = "1.0.0"  # Default version
            Name = $ModpackName
            Description = "CurseForge modpack"
            Jar = ""
            Url = "https://www.curseforge.com/minecraft/modpacks/$ModpackId"
            Category = "Modpack"
            VersionUrl = ""
            LatestVersionUrl = ""
            LatestVersion = "1.0.0"
            ApiSource = "curseforge"
            Host = "curseforge"
            IconUrl = ""
            ClientSide = "optional"
            ServerSide = "optional"
            Title = $ModpackName
            ProjectDescription = "CurseForge modpack"
            IssuesUrl = ""
            SourceUrl = ""
            WikiUrl = ""
            LatestGameVersion = $GameVersion
            RecordHash = ""
            CurrentDependencies = $Dependencies
            LatestDependencies = $Dependencies
        }
        
        # Add to mods array
        $mods += $newModpack
        
        # Save updated CSV
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        
        Write-Host "✅ Successfully added CurseForge modpack '$ModpackName' to database" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to add CurseForge modpack to database: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Minecraft Mod Manager PowerShell Script" -ForegroundColor Magenta
    Write-Host "Starting automatic validation of all mods..." -ForegroundColor Yellow
    Write-Host ""

    if ($Help -or $ShowHelp) {
        Show-Help
        return
    }
    
    # Auto-detect Modrinth URLs and treat them as AddMod commands
    if ($AddModUrl -and $AddModUrl -match "^https://modrinth\.com/([^/]+)/([^/]+)$") {
        $AddMod = $true
        Write-Host "🔍 Auto-detected Modrinth URL, treating as AddMod command" -ForegroundColor Cyan
    }
    
    # Auto-detect if AddModId is provided without AddMod flag
    if ($AddModId -and -not $AddMod) {
        $AddMod = $true
        Write-Host "🔍 Auto-detected Modrinth ID, treating as AddMod command" -ForegroundColor Cyan
    }
    
    if ($AddMod) {
        $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
        $mods = @()
        if (Test-Path $effectiveModListPath) {
            $mods = Import-Csv $effectiveModListPath
            if ($mods -isnot [System.Collections.IEnumerable]) { $mods = @($mods) }
            if ($mods.Count -eq 1 -and ($mods[0].PSObject.Properties.Name -contains 'Group')) {
                $allEmpty = $true
                foreach ($prop in $mods[0].PSObject.Properties) {
                    if ($prop.Value) { $allEmpty = $false; break }
                }
                if ($allEmpty) { $mods = @() }
            }
        }
        # Add a new mod entry to modlist.csv with minimal info and auto-resolve details
        $id = $AddModId
        $url = $AddModUrl
        $name = $AddModName
        $type = if ($AddModType) { $AddModType } else { $DefaultModType }
        $loader = if ($AddModLoader) { $AddModLoader } else { 
            # Auto-detect loader based on type
            if ($type -eq "shaderpack") { "iris" } else { $DefaultLoader }
        }
        $gameVersion = if ($AddModGameVersion) { $AddModGameVersion } else { $DefaultGameVersion }
        $group = if ($AddModGroup) { $AddModGroup } else { "optional" }  # Changed default to optional
        $description = if ($AddModDescription) { $AddModDescription } else { "" }
        $jar = if ($AddModJar) { $AddModJar } else { "" }
        $urlDirect = if ($AddModUrlDirect) { $AddModUrlDirect } else { "" }
        $category = if ($AddModCategory) { $AddModCategory } else { "" }
        
        # If AddModId is not provided but AddModUrl is, try to extract ID from URL
        if (-not $id -and $url) {
            if ($url -match "^https://modrinth\.com/([^/]+)/([^/]+)$") {
                $modrinthType = $matches[1]
                $modrinthId = $matches[2]
                $id = $modrinthId
                Write-Host "🔍 Extracted Modrinth ID '$id' from URL" -ForegroundColor Cyan
            } else {
                # Assume the URL itself is the ID
                $id = $url
                Write-Host "🔍 Using URL as ID: $id" -ForegroundColor Cyan
            }
        }
        
        # Check if the URL is a Modrinth URL and parse it
        $parsedModrinth = $null
        if ($url -and $url -match "^https://modrinth\.com/([^/]+)/([^/]+)$") {
            $modrinthType = $matches[1]
            $modrinthId = $matches[2]
            
            # Map Modrinth types to our types
            $typeMapping = @{
                "mod" = "mod"
                "shader" = "shaderpack"
                "datapack" = "datapack"
                "resourcepack" = "resourcepack"
                "plugin" = "plugin"
                "modpack" = "modpack"
            }
            
            if ($typeMapping.ContainsKey($modrinthType)) {
                $parsedModrinth = @{
                    Type = $typeMapping[$modrinthType]
                    ID = $modrinthId
                    Url = $url
                }
                Write-Host "🔍 Detected Modrinth URL: $modrinthType/$modrinthId" -ForegroundColor Cyan
            } else {
                Write-Host "❌ Unsupported Modrinth type: $modrinthType" -ForegroundColor Red
                Write-Host "   Supported types: $($typeMapping.Keys -join ', ')" -ForegroundColor Yellow
                return
            }
        }
        
        # Use parsed Modrinth data if available
        if ($parsedModrinth) {
            $id = $parsedModrinth.ID
            $type = $parsedModrinth.Type
            $loader = if ($type -eq "shaderpack") { "iris" } else { $DefaultLoader }
            
            # If no name provided, we'll get it from the API
            if (-not $name) {
                $name = "Loading..."  # Placeholder, will be updated from API
            }
        }
        
        if (-not $id) {
            Write-Host "You must provide at least -AddModId or -AddModUrl." -ForegroundColor Red
            return
        }
        
        Write-Host "Adding mod: $name ($id)" -ForegroundColor Cyan
        Write-Host "Auto-resolving latest version and metadata..." -ForegroundColor Yellow
        
        # Auto-resolve latest version and metadata based on type
        $resolvedMod = $null
        
        if ($type -eq "installer") {
            # For installers, use the provided URL and parameters
            $resolvedMod = [PSCustomObject]@{
                Group = $group
                Type = $type
                GameVersion = $gameVersion
                ID = $id
                Loader = $loader
                Version = if ($AddModVersion) { $AddModVersion } else { "1.0.0" }
                Name = $name
                Description = $description
                Jar = $jar
                Url = if ($urlDirect) { $urlDirect } else { $url }
                Category = $category
                VersionUrl = if ($urlDirect) { $urlDirect } else { $url }
                LatestVersionUrl = if ($urlDirect) { $urlDirect } else { $url }
                LatestVersion = if ($AddModVersion) { $AddModVersion } else { "1.0.0" }
                ApiSource = "direct"
                Host = "direct"
                IconUrl = ""
                ClientSide = ""
                ServerSide = ""
                Title = $name
                ProjectDescription = ""
                IssuesUrl = ""
                SourceUrl = ""
                WikiUrl = ""
                LatestGameVersion = $gameVersion
            }
        } elseif ($type -eq "launcher") {
            # For launchers, use the provided URL and parameters
            $resolvedMod = [PSCustomObject]@{
                Group = $group
                Type = $type
                GameVersion = $gameVersion
                ID = $id
                Loader = $loader
                Version = if ($AddModVersion) { $AddModVersion } else { "1.0.0" }
                Name = $name
                Description = $description
                Jar = $jar
                Url = if ($urlDirect) { $urlDirect } else { $url }
                Category = $category
                VersionUrl = if ($urlDirect) { $urlDirect } else { $url }
                LatestVersionUrl = if ($urlDirect) { $urlDirect } else { $url }
                LatestVersion = if ($AddModVersion) { $AddModVersion } else { "1.0.0" }
                ApiSource = "direct"
                Host = "direct"
                IconUrl = ""
                ClientSide = ""
                ServerSide = ""
                Title = $name
                ProjectDescription = ""
                IssuesUrl = ""
                SourceUrl = ""
                WikiUrl = ""
                LatestGameVersion = $gameVersion
            }
        } elseif ($type -eq "server") {
            # For server JARs, use the provided URL and parameters
            $resolvedMod = [PSCustomObject]@{
                Group = $group
                Type = $type
                GameVersion = $gameVersion
                ID = $id
                Loader = $loader
                Version = if ($AddModVersion) { $AddModVersion } else { $gameVersion }
                Name = $name
                Description = $description
                Jar = $jar
                Url = if ($urlDirect) { $urlDirect } else { $url }
                Category = $category
                VersionUrl = if ($urlDirect) { $urlDirect } else { $url }
                LatestVersionUrl = if ($urlDirect) { $urlDirect } else { $url }
                LatestVersion = if ($AddModVersion) { $AddModVersion } else { $gameVersion }
                ApiSource = "direct"
                Host = "direct"
                IconUrl = ""
                ClientSide = ""
                ServerSide = ""
                Title = $name
                ProjectDescription = ""
                IssuesUrl = ""
                SourceUrl = ""
                WikiUrl = ""
                LatestGameVersion = $gameVersion
            }
        } elseif ($type -eq "curseforge") {
            # For CurseForge mods, we need to validate with "latest" to get metadata
            $result = Validate-CurseForgeModVersion -ModId $id -Version "latest" -Loader $loader -ResponseFolder $ApiResponseFolder -Jar $jar -ModUrl $urlDirect
            if ($result.Exists) {
                $resolvedMod = [PSCustomObject]@{
                    Group = $group
                    Type = $type
                    GameVersion = $gameVersion
                    ID = $id
                    Loader = $loader
                    Version = $result.LatestVersion
                    Name = $name
                    Description = $description
                    Jar = $jar
                    Url = if ($urlDirect) { $urlDirect } else { "https://www.curseforge.com/minecraft/mc-mods/$id" }
                    Category = $category
                    VersionUrl = $result.VersionUrl
                    LatestVersionUrl = $result.LatestVersionUrl
                    LatestVersion = $result.LatestVersion
                    ApiSource = "curseforge"
                    Host = "curseforge"
                    IconUrl = $result.IconUrl
                    ClientSide = $result.ClientSide
                    ServerSide = $result.ServerSide
                    Title = $result.Title
                    ProjectDescription = $result.ProjectDescription
                    IssuesUrl = if ($result.IssuesUrl) { $result.IssuesUrl.ToString() } else { "" }
                    SourceUrl = if ($result.SourceUrl) { $result.SourceUrl.ToString() } else { "" }
                    WikiUrl = if ($result.WikiUrl) { $result.WikiUrl.ToString() } else { "" }
                    LatestGameVersion = $result.LatestGameVersion
                }
            }
        } elseif ($type -eq "modpack") {
            # For Modrinth modpacks, validate with "latest" to get metadata
            $result = Validate-ModVersion -ModId $id -Version "latest" -Loader $loader -ResponseFolder $ApiResponseFolder
            if ($result.Exists) {
                # Use API data for name if we have a placeholder
                $finalName = if ($name -eq "Loading...") { $result.Title } else { $name }
                
                $resolvedMod = [PSCustomObject]@{
                    Group = $group
                    Type = $type
                    GameVersion = $gameVersion
                    ID = $id
                    Loader = $loader
                    Version = $result.LatestVersion
                    Name = $finalName
                    Description = $description
                    Jar = $jar
                    Url = if ($urlDirect) { $urlDirect } else { if ($parsedModrinth) { $parsedModrinth.Url } else { "https://modrinth.com/modpack/$id" } }
                    Category = $category
                    VersionUrl = $result.VersionUrl
                    LatestVersionUrl = $result.LatestVersionUrl
                    LatestVersion = $result.LatestVersion
                    ApiSource = "modrinth"
                    Host = "modrinth"
                    IconUrl = $result.IconUrl
                    ClientSide = $result.ClientSide
                    ServerSide = $result.ServerSide
                    Title = $result.Title
                    ProjectDescription = $result.ProjectDescription
                    IssuesUrl = if ($result.IssuesUrl) { $result.IssuesUrl.ToString() } else { "" }
                    SourceUrl = if ($result.SourceUrl) { $result.SourceUrl.ToString() } else { "" }
                    WikiUrl = if ($result.WikiUrl) { $result.WikiUrl.ToString() } else { "" }
                    LatestGameVersion = $result.LatestGameVersion
                }
            }
        } else {
            # For Modrinth mods (including shaderpacks), validate with "latest"
            $result = Validate-ModVersion -ModId $id -Version "latest" -Loader $loader -ResponseFolder $ApiResponseFolder
            if ($result.Exists) {
                # Use API data for name if we have a placeholder
                $finalName = if ($name -eq "Loading...") { $result.Title } else { $name }
                
                $resolvedMod = [PSCustomObject]@{
                    Group = $group
                    Type = $type
                    GameVersion = $gameVersion
                    ID = $id
                    Loader = $loader
                    Version = $result.LatestVersion
                    Name = $finalName
                    Description = $description
                    Jar = $jar
                    Url = if ($urlDirect) { $urlDirect } else { if ($parsedModrinth) { $parsedModrinth.Url } else { "https://modrinth.com/modpack/$id" } }
                    Category = $category
                    VersionUrl = $result.VersionUrl
                    LatestVersionUrl = $result.LatestVersionUrl
                    LatestVersion = $result.LatestVersion
                    ApiSource = "modrinth"
                    Host = "modrinth"
                    IconUrl = $result.IconUrl
                    ClientSide = $result.ClientSide
                    ServerSide = $result.ServerSide
                    Title = $result.Title
                    ProjectDescription = $result.ProjectDescription
                    IssuesUrl = if ($result.IssuesUrl) { $result.IssuesUrl.ToString() } else { "" }
                    SourceUrl = if ($result.SourceUrl) { $result.SourceUrl.ToString() } else { "" }
                    WikiUrl = if ($result.WikiUrl) { $result.WikiUrl.ToString() } else { "" }
                    LatestGameVersion = $result.LatestGameVersion
                }
            }
        }
        
        if ($resolvedMod) {
            # Check for existing record before adding
            $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
            $mods = @()
            if (Test-Path $effectiveModListPath) {
                $mods = Import-Csv $effectiveModListPath
            }
            
            # Look for existing record with same ID and type
            $existingIndex = -1
            for ($i = 0; $i -lt $mods.Count; $i++) {
                if ($mods[$i].ID -eq $resolvedMod.ID -and $mods[$i].Type -eq $resolvedMod.Type) {
                    $existingIndex = $i
                    break
                }
            }
            
            if ($existingIndex -ne -1) {
                $existingMod = $mods[$existingIndex]
                Write-Host "🔍 Found existing record for $($resolvedMod.ID) ($($resolvedMod.Type))" -ForegroundColor Yellow
                
                # Check if version and JAR are the same
                if ($existingMod.Version -eq $resolvedMod.Version -and $existingMod.Jar -eq $resolvedMod.Jar) {
                    Write-Host "ℹ️  Mod already exists with same version and JAR. Skipping addition." -ForegroundColor Cyan
                    Write-Host "   Existing: $($existingMod.Name) v$($existingMod.Version) in group '$($existingMod.Group)'" -ForegroundColor Gray
                    return
                } else {
                    # Update existing record with new information
                    Write-Host "🔄 Updating existing record with new information..." -ForegroundColor Yellow
                    $mods[$existingIndex] = $resolvedMod
                    $mods | Export-Csv -Path $effectiveModListPath -NoTypeInformation
                    
                    Write-Host "✅ Successfully updated $($resolvedMod.Name) in $effectiveModListPath" -ForegroundColor Green
                    Write-Host "📋 Updated information:" -ForegroundColor Cyan
                    Write-Host "   Version: $($existingMod.Version) → $($resolvedMod.Version)" -ForegroundColor Gray
                    Write-Host "   Title: $($resolvedMod.Title)" -ForegroundColor Gray
                    Write-Host "   Latest Game Version: $($resolvedMod.LatestGameVersion)" -ForegroundColor Gray
                    Write-Host "   Icon URL: $($resolvedMod.IconUrl)" -ForegroundColor Gray
                }
            } else {
                # Add new record
                if ($mods.Count -eq 0) {
                    $mods = @($resolvedMod)
                } else {
                    $mods = @($mods) + $resolvedMod
                }
                $mods | Export-Csv -Path $effectiveModListPath -NoTypeInformation
                
                Write-Host "✅ Successfully added $($resolvedMod.Name) to $effectiveModListPath in group '$($resolvedMod.Group)'" -ForegroundColor Green
                Write-Host "📋 Resolved information:" -ForegroundColor Cyan
                Write-Host "   Latest Version: $($resolvedMod.LatestVersion)" -ForegroundColor Gray
                Write-Host "   Title: $($resolvedMod.Title)" -ForegroundColor Gray
                Write-Host "   Latest Game Version: $($resolvedMod.LatestGameVersion)" -ForegroundColor Gray
                Write-Host "   Icon URL: $($resolvedMod.IconUrl)" -ForegroundColor Gray
            }
            
            # Auto-download if requested
            if ($ForceDownload) {
                Write-Host ""
                Write-Host "Auto-downloading the mod..." -ForegroundColor Yellow
                $downloadParams = @{
                    CsvPath = $effectiveModListPath
                    DownloadFolder = $DownloadFolder
                    UseLatestVersion = $true
                    ForceDownload = $true
                }
                $downloadedCount = Download-Mods @downloadParams
                if ($downloadedCount -gt 0) {
                    Write-Host "✅ Successfully downloaded $downloadedCount mods!" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "❌ Failed to resolve mod information for $name ($id)" -ForegroundColor Red
            Write-Host "   Check if the mod ID is correct and the mod exists on $type" -ForegroundColor Yellow
        }
        return
    }
    
    # Delete mod logic
    if ($DeleteModID) {
        $deleteId = $DeleteModID
        $deleteType = $DeleteModType
        $parsedDelete = $null
        
        # Parse Modrinth URL if provided
        if ($deleteId -match "^https://modrinth\.com/([^/]+)/([^/]+)$") {
            $modrinthType = $matches[1]
            $modrinthId = $matches[2]
            $typeMapping = @{ 
                "mod" = "mod"; 
                "shader" = "shaderpack"; 
                "datapack" = "datapack"; 
                "resourcepack" = "resourcepack"; 
                "plugin" = "plugin";
                "modpack" = "modpack"
            }
            if ($typeMapping.ContainsKey($modrinthType)) {
                $parsedDelete = @{ Type = $typeMapping[$modrinthType]; ID = $modrinthId }
                Write-Host "🔍 Parsed Modrinth URL: $modrinthType/$modrinthId" -ForegroundColor Cyan
            } else {
                Write-Host "❌ Unsupported Modrinth type: $modrinthType" -ForegroundColor Red
                Write-Host "   Supported types: $($typeMapping.Keys -join ', ')" -ForegroundColor Yellow
                return
            }
        }
        
        # Use parsed data if available
        if ($parsedDelete) {
            $deleteId = $parsedDelete.ID
            $deleteType = $parsedDelete.Type
        }
        
        if (-not $deleteId) {
            Write-Host "❌ You must provide a mod ID or a valid Modrinth URL." -ForegroundColor Red
            return
        }
        
        Write-Host "🗑️  Deleting mod: $deleteId ($deleteType)" -ForegroundColor Cyan
        
        # Load and filter mods
        $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
        $mods = @()
        if (Test-Path $effectiveModListPath) {
            $mods = Import-Csv $effectiveModListPath
        }
        
        $originalCount = $mods.Count
        
        # Filter out the matching mod(s)
        if ($deleteType) {
            $mods = $mods | Where-Object { $_.ID -ne $deleteId -or $_.Type -ne $deleteType }
        } else {
            $mods = $mods | Where-Object { $_.ID -ne $deleteId }
        }
        
        # Check if any mods were removed
        if ($mods.Count -lt $originalCount) {
            $removedCount = $originalCount - $mods.Count
            $mods | Export-Csv -Path $effectiveModListPath -NoTypeInformation
            Write-Host "✅ Successfully deleted $removedCount mod(s) with ID '$deleteId' ($deleteType) from $effectiveModListPath" -ForegroundColor Green
        } else {
            Write-Host "ℹ️  No matching mod found for '$deleteId' ($deleteType) in $effectiveModListPath" -ForegroundColor Yellow
        }
        return
    }
    
    if ($ValidateMod) {
        if (-not $ModID) {
            Write-Host "❌ Error: -ValidateMod requires -ModID parameter" -ForegroundColor Red
            Write-Host "   Example: .\ModManager.ps1 -ValidateMod -ModID 'fabric-api'" -ForegroundColor White
            return
        }
        
        Write-Host "🔍 Validating mod: $ModID" -ForegroundColor Cyan
        
        # Load the mod list
        $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
        if (-not (Test-Path $effectiveModListPath)) {
            Write-Host "❌ Error: Mod list file not found: $effectiveModListPath" -ForegroundColor Red
            return
        }
        
        $mods = Import-Csv $effectiveModListPath
        $targetMod = $mods | Where-Object { $_.ID -eq $ModID } | Select-Object -First 1
        
        if (-not $targetMod) {
            Write-Host "❌ Error: Mod with ID '$ModID' not found in the database" -ForegroundColor Red
            return
        }
        
        Write-Host "📋 Current mod information:" -ForegroundColor Yellow
        Write-Host "   Name: $($targetMod.Name)" -ForegroundColor Gray
        Write-Host "   Current Version: $($targetMod.Version)" -ForegroundColor Gray
        Write-Host "   Latest Version: $($targetMod.LatestVersion)" -ForegroundColor Gray
        Write-Host "   Latest Game Version: $($targetMod.LatestGameVersion)" -ForegroundColor Gray
        
        # Validate the mod and get latest information
        $loader = if ($targetMod.Loader) { $targetMod.Loader } else { $DefaultLoader }
        $result = Validate-ModVersion -ModId $ModID -Version "latest" -Loader $loader -ResponseFolder $ApiResponseFolder
        
        if ($result.Exists) {
            Write-Host ""
            Write-Host "✅ Validation successful!" -ForegroundColor Green
            Write-Host "📋 Latest information:" -ForegroundColor Yellow
            Write-Host "   Latest Version: $($result.LatestVersion)" -ForegroundColor Gray
            Write-Host "   Latest Game Version: $($result.LatestGameVersion)" -ForegroundColor Gray
            Write-Host "   Title: $($result.Title)" -ForegroundColor Gray
            
            # Update the mod in the database
            $updated = $false
            for ($i = 0; $i -lt $mods.Count; $i++) {
                if ($mods[$i].ID -eq $ModID) {
                    $mods[$i].LatestVersion = $result.LatestVersion
                    $mods[$i].LatestVersionUrl = $result.LatestVersionUrl
                    $mods[$i].LatestGameVersion = $result.LatestGameVersion
                    $mods[$i].Title = $result.Title
                    $mods[$i].ProjectDescription = $result.ProjectDescription
                    $mods[$i].IconUrl = $result.IconUrl
                    $mods[$i].IssuesUrl = $result.IssuesUrl
                    $mods[$i].SourceUrl = $result.SourceUrl
                    $mods[$i].WikiUrl = $result.WikiUrl
                    $updated = $true
                    break
                }
            }
            
            if ($updated) {
                $mods | Export-Csv -Path $effectiveModListPath -NoTypeInformation
                Write-Host ""
                Write-Host "✅ Successfully updated mod information in database!" -ForegroundColor Green
                Write-Host "   Latest Version: $($result.LatestVersion)" -ForegroundColor Gray
                Write-Host "   Latest Game Version: $($result.LatestGameVersion)" -ForegroundColor Gray
            } else {
                Write-Host "❌ Failed to update mod in database" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Validation failed: $($result.Error)" -ForegroundColor Red
        }
        return
    }
    
    if ($ValidateModVersion) {
        # Example: Validate-ModVersion -ModId "fabric-api" -Version "0.91.0+1.20.1"
        Write-Host "Validating mod version..." -ForegroundColor Cyan
        # User must provide -ModId and -Version as extra params
        return
    }
    if ($ValidateAllModVersions) {
        $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
        Validate-AllModVersions -CsvPath $effectiveModListPath -UpdateModList
        return
    }
    if ($DownloadMods) {
        $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
        
        # Validate first if requested
        if ($ValidateWithDownload) {
            Write-Host "Validating mod versions before download..." -ForegroundColor Cyan
            Validate-AllModVersions -CsvPath $effectiveModListPath -UpdateModList
        }
        
        Download-Mods -CsvPath $effectiveModListPath -DownloadFolder $DownloadFolder -UseLatestVersion:$UseLatestVersion -ForceDownload:$ForceDownload
        return
    }
    if ($GetModList) {
        $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
        Get-ModList -CsvPath $effectiveModListPath -ApiResponseFolder $ApiResponseFolder
        return
    }
    if ($DownloadServer) {
        Download-ServerFiles -DownloadFolder $DownloadFolder -ForceDownload:$ForceDownload
        return
    }
    if ($StartServer) {
        Start-MinecraftServer -DownloadFolder $DownloadFolder
        return
    }
    if ($AddServerStartScript) {
        Write-Host "🔧 Adding server start script to download folder..." -ForegroundColor Cyan
        
        # Check if download folder exists
        if (-not (Test-Path $DownloadFolder)) {
            Write-Host "❌ Download folder not found: $DownloadFolder" -ForegroundColor Red
            Write-Host "💡 Run -DownloadMods or -DownloadServer first to create the download folder" -ForegroundColor Yellow
            return
        }
        
        # Find the most recent version folder
        $versionFolders = Get-ChildItem -Path $DownloadFolder -Directory -ErrorAction SilentlyContinue | 
                         Where-Object { $_.Name -match "^\d+\.\d+\.\d+" } |
                         Sort-Object Name -Descending
        
        if ($versionFolders.Count -eq 0) {
            Write-Host "❌ No version folders found in $DownloadFolder" -ForegroundColor Red
            Write-Host "💡 Run -DownloadMods or -DownloadServer first to download server files" -ForegroundColor Yellow
            return
        }
        
        $targetVersion = $versionFolders[0].Name
        $targetFolder = Join-Path $DownloadFolder $targetVersion
        
        Write-Host "📁 Using version folder: $targetFolder" -ForegroundColor Cyan
        
        # Copy start-server script to target folder
        $scriptSource = Join-Path $PSScriptRoot "tools/start-server.ps1"
        $serverScript = Join-Path $targetFolder "start-server.ps1"
        
        if (-not (Test-Path $scriptSource)) {
            Write-Host "❌ Start server script not found: $scriptSource" -ForegroundColor Red
            return
        }
        
        try {
            Copy-Item -Path $scriptSource -Destination $serverScript -Force
            Write-Host "✅ Successfully copied start-server script to: $serverScript" -ForegroundColor Green
            Write-Host "💡 You can now run the server from: $targetFolder" -ForegroundColor Yellow
        }
        catch {
            Write-Host "❌ Failed to copy start-server script: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
        return
    }
    if ($ValidateCurseForgeModpack) {
        if (-not $CurseForgeModpackId -or -not $CurseForgeFileId) {
            Write-Host "❌ Error: -ValidateCurseForgeModpack requires -CurseForgeModpackId and -CurseForgeFileId parameters" -ForegroundColor Red
            Write-Host "   Example: .\ModManager.ps1 -ValidateCurseForgeModpack -CurseForgeModpackId '123456' -CurseForgeFileId '789012'" -ForegroundColor White
            return
        }
        
        Write-Host "🔍 Validating CurseForge modpack: $CurseForgeModpackId, File: $CurseForgeFileId" -ForegroundColor Cyan
        
        $result = Validate-CurseForgeModpack -ModpackId $CurseForgeModpackId -FileId $CurseForgeFileId
        
        if ($result.Valid) {
            Write-Host "✅ CurseForge modpack validation successful!" -ForegroundColor Green
            Write-Host "📋 Modpack information:" -ForegroundColor Yellow
            Write-Host "   Name: $($result.ModpackName)" -ForegroundColor Gray
            Write-Host "   Game Version: $($result.GameVersion)" -ForegroundColor Gray
            Write-Host "   File Name: $($result.FileName)" -ForegroundColor Gray
            Write-Host "   Download URL: $($result.DownloadUrl)" -ForegroundColor Gray
        } else {
            Write-Host "❌ CurseForge modpack validation failed: $($result.Error)" -ForegroundColor Red
        }
        return
    }
    
    if ($DownloadCurseForgeModpack) {
        if (-not $CurseForgeModpackId -or -not $CurseForgeFileId -or -not $CurseForgeModpackName) {
            Write-Host "❌ Error: -DownloadCurseForgeModpack requires -CurseForgeModpackId, -CurseForgeFileId, and -CurseForgeModpackName parameters" -ForegroundColor Red
            Write-Host "   Example: .\ModManager.ps1 -DownloadCurseForgeModpack -CurseForgeModpackId '123456' -CurseForgeFileId '789012' -CurseForgeModpackName 'My Modpack'" -ForegroundColor White
            return
        }
        
        $gameVersion = if ($CurseForgeGameVersion) { $CurseForgeGameVersion } else { $DefaultGameVersion }
        
        Write-Host "📦 Starting CurseForge modpack download..." -ForegroundColor Cyan
        Write-Host "   Modpack: $CurseForgeModpackName" -ForegroundColor Gray
        Write-Host "   Game Version: $gameVersion" -ForegroundColor Gray
        
        $downloadedCount = Download-CurseForgeModpack -ModpackId $CurseForgeModpackId -FileId $CurseForgeFileId -ModpackName $CurseForgeModpackName -GameVersion $gameVersion -DownloadFolder $DownloadFolder -ForceDownload:$ForceDownload
        
        if ($downloadedCount -gt 0) {
            Write-Host ""
            Write-Host "✅ Successfully downloaded CurseForge modpack with $downloadedCount files!" -ForegroundColor Green
            
            # Add modpack to database
            $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
            
            # Parse dependencies from the downloaded manifest
            $modpackDir = Join-Path $DownloadFolder "$gameVersion\modpacks\$CurseForgeModpackName"
            $manifestPath = Join-Path $modpackDir "manifest.json"
            
            if (Test-Path $manifestPath) {
                $dependencies = Parse-CurseForgeModpackDependencies -ManifestPath $manifestPath
                $added = Add-CurseForgeModpackToDatabase -ModpackId $CurseForgeModpackId -FileId $CurseForgeFileId -ModpackName $CurseForgeModpackName -GameVersion $gameVersion -CsvPath $effectiveModListPath -Dependencies $dependencies
                
                if ($added) {
                    Write-Host "✅ Successfully added modpack to database with dependencies" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Downloaded modpack but failed to add to database" -ForegroundColor Yellow
                }
            } else {
                Write-Host "⚠️  Downloaded modpack but manifest.json not found for database entry" -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ Failed to download CurseForge modpack" -ForegroundColor Red
        }
        return
    }
    
    # Default: Run validation and update modlist
    $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
    Validate-AllModVersions -CsvPath $effectiveModListPath -UpdateModList
    if ($Download) {
        Write-Host ""; Write-Host "Starting mod downloads..." -ForegroundColor Yellow
        $downloadParams = @{
            CsvPath = $effectiveModListPath
            DownloadFolder = $DownloadFolder
        }
        if ($UseLatestVersion) { $downloadParams.UseLatestVersion = $true; Write-Host "Using latest versions for downloads" -ForegroundColor Cyan }
        if ($ForceDownload) { $downloadParams.ForceDownload = $true; Write-Host "Force downloading (will overwrite existing files)" -ForegroundColor Cyan }
        $downloadedCount = Download-Mods @downloadParams
        if ($downloadedCount -gt 0) { Write-Host ""; Write-Host "Successfully downloaded $downloadedCount mods!" -ForegroundColor Green }
    }

    # Cross-Platform Modpack Integration
    if ($ImportModpack) {
        Write-Host "📦 Cross-Platform Modpack Integration" -ForegroundColor Cyan
        Write-Host "=====================================" -ForegroundColor Cyan
        
        if (-not (Test-Path $ImportModpack)) {
            Write-Host "❌ Modpack file not found: $ImportModpack" -ForegroundColor Red
            exit 1
        }
        
        $success = Import-UnifiedModpack -ModpackPath $ImportModpack -ModpackType $ModpackType -DownloadFolder $DownloadFolder -CsvPath $DatabaseFile -ResolveConflicts:$ResolveConflicts
        
        if ($success) {
            Write-Host "✅ Modpack import completed successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Modpack import failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($ExportModpack) {
        Write-Host "📦 Export Mod List as Modpack" -ForegroundColor Cyan
        Write-Host "=============================" -ForegroundColor Cyan
        
        $success = Export-ModListAsModpack -CsvPath $DatabaseFile -OutputPath $ExportModpack -ModpackType $ExportType -ModpackName $ExportName -Author $ExportAuthor
        
        if ($success) {
            Write-Host "✅ Modpack export completed successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Modpack export failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($ValidateModpack) {
        Write-Host "🔍 Validate Modpack Integrity" -ForegroundColor Cyan
        Write-Host "=============================" -ForegroundColor Cyan
        
        if (-not (Test-Path $ValidateModpack)) {
            Write-Host "❌ Modpack file not found: $ValidateModpack" -ForegroundColor Red
            exit 1
        }
        
        # Auto-detect type if needed
        if ($ValidateType -eq "auto") {
            $ValidateType = Detect-ModpackType -ModpackPath $ValidateModpack
            Write-Host "Auto-detected modpack type: $ValidateType" -ForegroundColor Yellow
        }
        
        $success = Test-ModpackIntegrity -ModpackPath $ValidateModpack -ModpackType $ValidateType
        
        if ($success) {
            Write-Host "✅ Modpack integrity validation passed" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Modpack integrity validation failed" -ForegroundColor Red
            exit 1
        }
    }
} 

# Function to handle cross-platform modpack integration
function Import-UnifiedModpack {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModpackPath,
        [Parameter(Mandatory=$true)]
        [string]$ModpackType, # "modrinth", "curseforge", "auto"
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder,
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [bool]$ForceDownload = $false,
        [bool]$ResolveConflicts = $true
    )
    try {
        Write-Host "📦 Importing unified modpack: $ModpackPath" -ForegroundColor Cyan
        Write-Host "   Type: $ModpackType" -ForegroundColor Gray
        
        # Auto-detect modpack type if not specified
        if ($ModpackType -eq "auto") {
            $ModpackType = Detect-ModpackType -ModpackPath $ModpackPath
            Write-Host "   Auto-detected type: $ModpackType" -ForegroundColor Yellow
        }
        
        # Import based on type
        switch ($ModpackType.ToLower()) {
            "modrinth" {
                return Import-ModrinthModpack -ModpackPath $ModpackPath -DownloadFolder $DownloadFolder -CsvPath $CsvPath -ForceDownload:$ForceDownload -ResolveConflicts:$ResolveConflicts
            }
            "curseforge" {
                return Import-CurseForgeModpack -ModpackPath $ModpackPath -DownloadFolder $DownloadFolder -CsvPath $CsvPath -ForceDownload:$ForceDownload -ResolveConflicts:$ResolveConflicts
            }
            default {
                throw "Unsupported modpack type: $ModpackType"
            }
        }
    } catch {
        Write-Host "❌ Unified modpack import failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to detect modpack type automatically
function Detect-ModpackType {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModpackPath
    )
    
    try {
        if ($ModpackPath -match "\.mrpack$") {
            return "modrinth"
        } elseif ($ModpackPath -match "\.zip$") {
            # Check if it's a CurseForge modpack by looking for manifest.json
            $tempDir = Join-Path $env:TEMP "modpack-detect-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            try {
                Expand-Archive -Path $ModpackPath -DestinationPath $tempDir -Force
                if (Test-Path (Join-Path $tempDir "manifest.json")) {
                    return "curseforge"
                } else {
                    return "modrinth" # Default fallback
                }
            } finally {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        } else {
            return "modrinth" # Default fallback
        }
    } catch {
        return "modrinth" # Default fallback
    }
}

# Function to import Modrinth modpack
function Import-ModrinthModpack {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModpackPath,
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder,
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [bool]$ForceDownload = $false,
        [bool]$ResolveConflicts = $true
    )
    try {
        Write-Host "📦 Importing Modrinth modpack..." -ForegroundColor Cyan
        
        # Extract modpack to temporary directory
        $tempDir = Join-Path $env:TEMP "modrinth-import-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        try {
            Expand-Archive -Path $ModpackPath -DestinationPath $tempDir -Force
            
            # Find modrinth.index.json
            $indexPath = Join-Path $tempDir "modrinth.index.json"
            if (-not (Test-Path $indexPath)) {
                throw "modrinth.index.json not found in modpack"
            }
            
            $indexContent = Get-Content $indexPath | ConvertFrom-Json
            
            # Parse dependencies
            $dependencies = Parse-ModrinthModpackDependencies -IndexPath $indexPath
            
            # Add modpack to database
            $modpackName = [System.IO.Path]::GetFileNameWithoutExtension($ModpackPath)
            $gameVersion = $indexContent.dependencies.minecraft
            
            $added = Add-ModrinthModpackToDatabase -ModpackName $modpackName -GameVersion $gameVersion -CsvPath $CsvPath -Dependencies $dependencies
            
            if ($added) {
                Write-Host "✅ Successfully imported Modrinth modpack" -ForegroundColor Green
                return $true
            } else {
                Write-Host "❌ Failed to add Modrinth modpack to database" -ForegroundColor Red
                return $false
            }
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "❌ Modrinth modpack import failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to import CurseForge modpack
function Import-CurseForgeModpack {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModpackPath,
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder,
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [bool]$ForceDownload = $false,
        [bool]$ResolveConflicts = $true
    )
    try {
        Write-Host "📦 Importing CurseForge modpack..." -ForegroundColor Cyan
        
        # Extract modpack to temporary directory
        $tempDir = Join-Path $env:TEMP "curseforge-import-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        try {
            Expand-Archive -Path $ModpackPath -DestinationPath $tempDir -Force
            
            # Find manifest.json
            $manifestPath = Join-Path $tempDir "manifest.json"
            if (-not (Test-Path $manifestPath)) {
                throw "manifest.json not found in modpack"
            }
            
            # Parse dependencies
            $dependencies = Parse-CurseForgeModpackDependencies -ManifestPath $manifestPath
            
            # Add modpack to database
            $manifestContent = Get-Content $manifestPath | ConvertFrom-Json
            $modpackName = $manifestContent.name
            $gameVersion = $manifestContent.minecraft.version
            
            $added = Add-CurseForgeModpackToDatabase -ModpackId "imported" -FileId "imported" -ModpackName $modpackName -GameVersion $gameVersion -CsvPath $CsvPath -Dependencies $dependencies
            
            if ($added) {
                Write-Host "✅ Successfully imported CurseForge modpack" -ForegroundColor Green
                return $true
            } else {
                Write-Host "❌ Failed to add CurseForge modpack to database" -ForegroundColor Red
                return $false
            }
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "❌ CurseForge modpack import failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to parse Modrinth modpack dependencies
function Parse-ModrinthModpackDependencies {
    param(
        [Parameter(Mandatory=$true)]
        [string]$IndexPath
    )
    try {
        if (-not (Test-Path $IndexPath)) {
            return ""
        }
        
        $index = Get-Content $IndexPath | ConvertFrom-Json
        $dependencies = @()
        
        foreach ($file in $index.files) {
            $dependency = @{
                ProjectId = $file.path
                FileId = $file.path
                Required = $true
                Type = "required"
                Host = "modrinth"
                DownloadUrl = $file.downloads[0]
            }
            $dependencies += $dependency
        }
        
        # Convert to JSON string for storage in CSV
        $dependenciesJson = $dependencies | ConvertTo-Json -Compress
        return $dependenciesJson
    } catch {
        Write-Host "❌ Failed to parse Modrinth modpack dependencies: $($_.Exception.Message)" -ForegroundColor Red
        return ""
    }
}

# Function to add Modrinth modpack to database
function Add-ModrinthModpackToDatabase {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModpackName,
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [string]$Dependencies = ""
    )
    try {
        # Load existing mods
        $mods = @()
        if (Test-Path $CsvPath) {
            $mods = Import-Csv $CsvPath
        }
        
        # Ensure CSV has required columns
        $mods = Ensure-CsvColumns -CsvPath $CsvPath
        
        # Create new modpack entry
        $newModpack = [PSCustomObject]@{
            Group = "required"
            Type = "modpack"
            GameVersion = $GameVersion
            ID = "modrinth-$($ModpackName.ToLower() -replace '[^a-z0-9]', '-')"
            Loader = "fabric"  # Default, can be updated later
            Version = "1.0.0"  # Default version
            Name = $ModpackName
            Description = "Modrinth modpack"
            Jar = ""
            Url = "https://modrinth.com/modpack/$($ModpackName.ToLower() -replace '[^a-z0-9]', '-')"
            Category = "Modpack"
            VersionUrl = ""
            LatestVersionUrl = ""
            LatestVersion = "1.0.0"
            ApiSource = "modrinth"
            Host = "modrinth"
            IconUrl = ""
            ClientSide = "optional"
            ServerSide = "optional"
            Title = $ModpackName
            ProjectDescription = "Modrinth modpack"
            IssuesUrl = ""
            SourceUrl = ""
            WikiUrl = ""
            LatestGameVersion = $GameVersion
            RecordHash = ""
            CurrentDependencies = $Dependencies
            LatestDependencies = $Dependencies
        }
        
        # Add to mods array
        $mods += $newModpack
        
        # Save updated CSV
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        
        Write-Host "✅ Successfully added Modrinth modpack '$ModpackName' to database" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to add Modrinth modpack to database: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to resolve dependency conflicts
function Resolve-DependencyConflicts {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Dependencies,
        [Parameter(Mandatory=$true)]
        [string]$CsvPath
    )
    try {
        Write-Host "🔍 Resolving dependency conflicts..." -ForegroundColor Cyan
        
        $conflicts = @()
        $resolved = @()
        
        # Load existing mods
        $existingMods = Import-Csv $CsvPath
        
        foreach ($dependency in $Dependencies) {
            $projectId = $dependency.ProjectId
            $existingMod = $existingMods | Where-Object { $_.ID -eq $projectId } | Select-Object -First 1
            
            if ($existingMod) {
                # Check for version conflicts
                if ($dependency.Version -and $existingMod.Version -and $dependency.Version -ne $existingMod.Version) {
                    $conflicts += @{
                        ProjectId = $projectId
                        ExistingVersion = $existingMod.Version
                        NewVersion = $dependency.Version
                        Resolution = "keep-existing" # Default resolution
                    }
                }
            }
            
            $resolved += $dependency
        }
        
        if ($conflicts.Count -gt 0) {
            Write-Host "⚠️  Found $($conflicts.Count) dependency conflicts:" -ForegroundColor Yellow
            foreach ($conflict in $conflicts) {
                Write-Host "   $($conflict.ProjectId): $($conflict.ExistingVersion) vs $($conflict.NewVersion)" -ForegroundColor Gray
            }
        } else {
            Write-Host "✅ No dependency conflicts found" -ForegroundColor Green
        }
        
        return @{
            Conflicts = $conflicts
            Resolved = $resolved
        }
    } catch {
        Write-Host "❌ Failed to resolve dependency conflicts: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Conflicts = @()
            Resolved = $Dependencies
        }
    }
}

# Function to export mod list as modpack
function Export-ModListAsModpack {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        [Parameter(Mandatory=$true)]
        [string]$ModpackType, # "modrinth", "curseforge"
        [string]$ModpackName = "Exported Modpack",
        [string]$GameVersion = "1.21.5",
        [string]$Author = "ModManager"
    )
    try {
        Write-Host "📦 Exporting mod list as $ModpackType modpack..." -ForegroundColor Cyan
        
        # Load mods from CSV
        $mods = Import-Csv $CsvPath
        
        # Filter to only include mods (not installers, launchers, etc.)
        $modMods = $mods | Where-Object { $_.Type -eq "mod" }
        
        switch ($ModpackType.ToLower()) {
            "modrinth" {
                return Export-ModrinthModpack -Mods $modMods -OutputPath $OutputPath -ModpackName $ModpackName -GameVersion $GameVersion -Author $Author
            }
            "curseforge" {
                return Export-CurseForgeModpack -Mods $modMods -OutputPath $OutputPath -ModpackName $ModpackName -GameVersion $GameVersion -Author $Author
            }
            default {
                throw "Unsupported export type: $ModpackType"
            }
        }
    } catch {
        Write-Host "❌ Modpack export failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to export as Modrinth modpack
function Export-ModrinthModpack {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Mods,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        [Parameter(Mandatory=$true)]
        [string]$ModpackName,
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [string]$Author = "ModManager"
    )
    try {
        # Create modrinth.index.json
        $index = @{
            formatVersion = 1
            game = "minecraft"
            versionId = "1.0.0"
            name = $ModpackName
            summary = "Exported modpack from ModManager"
            files = @()
            dependencies = @{
                minecraft = $GameVersion
                "fabric-loader" = "0.16.14"
            }
        }
        
        foreach ($mod in $Mods) {
            if ($mod.VersionUrl) {
                $index.files += @{
                    path = "mods/$($mod.Jar)"
                    hashes = @{
                        sha256 = ""
                    }
                    env = @{
                        client = "optional"
                        server = "optional"
                    }
                    downloads = @($mod.VersionUrl)
                    fileSize = 0
                }
            }
        }
        
        # Create temporary directory
        $tempDir = Join-Path $env:TEMP "modrinth-export-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        try {
            # Save index file
            $indexPath = Join-Path $tempDir "modrinth.index.json"
            $index | ConvertTo-Json -Depth 10 | Out-File -FilePath $indexPath -Encoding UTF8
            
            # Create ZIP file
            $zipPath = $OutputPath
            if (-not $zipPath.EndsWith(".mrpack")) {
                $zipPath = $zipPath + ".mrpack"
            }
            
            Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
            
            Write-Host "✅ Successfully exported Modrinth modpack: $zipPath" -ForegroundColor Green
            return $true
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "❌ Modrinth modpack export failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to export as CurseForge modpack
function Export-CurseForgeModpack {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Mods,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        [Parameter(Mandatory=$true)]
        [string]$ModpackName,
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [string]$Author = "ModManager"
    )
    try {
        # Create manifest.json
        $manifest = @{
            minecraft = @{
                version = $GameVersion
                modLoaders = @(
                    @{
                        id = "fabric-0.16.14"
                        primary = $true
                    }
                )
            }
            manifestType = "minecraftModpack"
            manifestVersion = 1
            name = $ModpackName
            version = "1.0.0"
            author = $Author
            files = @()
            overrides = "overrides"
        }
        
        foreach ($mod in $Mods) {
            if ($mod.ID -match "^\d+$") {
                # CurseForge mod
                $manifest.files += @{
                    fileID = $mod.ID
                    projectID = $mod.ID
                    required = $true
                }
            }
        }
        
        # Create temporary directory
        $tempDir = Join-Path $env:TEMP "curseforge-export-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        try {
            # Save manifest file
            $manifestPath = Join-Path $tempDir "manifest.json"
            $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding UTF8
            
            # Create ZIP file
            $zipPath = $OutputPath
            if (-not $zipPath.EndsWith(".zip")) {
                $zipPath = $zipPath + ".zip"
            }
            
            Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
            
            Write-Host "✅ Successfully exported CurseForge modpack: $zipPath" -ForegroundColor Green
            return $true
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "❌ CurseForge modpack export failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to validate modpack integrity
function Test-ModpackIntegrity {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModpackPath,
        [Parameter(Mandatory=$true)]
        [string]$ModpackType
    )
    try {
        Write-Host "🔍 Validating modpack integrity: $ModpackPath" -ForegroundColor Cyan
        
        $issues = @()
        $tempDir = Join-Path $env:TEMP "modpack-integrity-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        try {
            Expand-Archive -Path $ModpackPath -DestinationPath $tempDir -Force
            
            switch ($ModpackType.ToLower()) {
                "modrinth" {
                    $indexPath = Join-Path $tempDir "modrinth.index.json"
                    if (-not (Test-Path $indexPath)) {
                        $issues += "Missing modrinth.index.json"
                    } else {
                        $index = Get-Content $indexPath | ConvertFrom-Json
                        if (-not $index.files) {
                            $issues += "No files defined in modrinth.index.json"
                        }
                        if (-not $index.dependencies.minecraft) {
                            $issues += "Missing Minecraft version in dependencies"
                        }
                    }
                }
                "curseforge" {
                    $manifestPath = Join-Path $tempDir "manifest.json"
                    if (-not (Test-Path $manifestPath)) {
                        $issues += "Missing manifest.json"
                    } else {
                        $manifest = Get-Content $manifestPath | ConvertFrom-Json
                        if (-not $manifest.files) {
                            $issues += "No files defined in manifest.json"
                        }
                        if (-not $manifest.minecraft.version) {
                            $issues += "Missing Minecraft version"
                        }
                    }
                }
            }
            
            if ($issues.Count -eq 0) {
                Write-Host "✅ Modpack integrity check passed" -ForegroundColor Green
                return $true
            } else {
                Write-Host "❌ Modpack integrity issues found:" -ForegroundColor Red
                foreach ($issue in $issues) {
                    Write-Host "   - $issue" -ForegroundColor Gray
                }
                return $false
            }
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "❌ Modpack integrity check failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Invoke-ModManagerCli {
    # Advanced Server Management
    if ($MonitorServerPerformance) {
        Write-Host "📊 Server Performance Monitoring" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        
        $performanceData = Get-ServerPerformance -ServerPath $DownloadFolder -SampleInterval $PerformanceSampleInterval -SampleCount $PerformanceSampleCount
        
        if ($performanceData) {
            Write-Host "✅ Performance monitoring completed" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Performance monitoring failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($CreateServerBackup) {
        Write-Host "📦 Server Backup Creation" -ForegroundColor Cyan
        Write-Host "========================" -ForegroundColor Cyan
        
        $success = New-ServerBackup -ServerPath $DownloadFolder -BackupPath $BackupPath -BackupName $BackupName
        
        if ($success) {
            Write-Host "✅ Server backup created successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Server backup creation failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($RestoreServerBackup) {
        Write-Host "🔄 Server Backup Restoration" -ForegroundColor Cyan
        Write-Host "============================" -ForegroundColor Cyan
        
        $success = Restore-ServerBackup -BackupFile $RestoreServerBackup -ServerPath $DownloadFolder -Force:$ForceRestore
        
        if ($success) {
            Write-Host "✅ Server backup restored successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Server backup restoration failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($ListServerPlugins) {
        Write-Host "🔌 Server Plugin Management" -ForegroundColor Cyan
        Write-Host "===========================" -ForegroundColor Cyan
        
        $plugins = Get-ServerPlugins -ServerPath $DownloadFolder
        
        if ($plugins.Count -gt 0) {
            Write-Host "Found $($plugins.Count) plugins:" -ForegroundColor Green
            foreach ($plugin in $plugins) {
                Write-Host "  - $($plugin.Name) ($([math]::Round($plugin.Size / 1KB, 2))KB)" -ForegroundColor Gray
            }
            exit 0
        } else {
            Write-Host "ℹ️  No plugins found" -ForegroundColor Yellow
            exit 0
        }
    }

    if ($InstallPlugin -and $PluginUrl) {
        Write-Host "📥 Plugin Installation" -ForegroundColor Cyan
        Write-Host "======================" -ForegroundColor Cyan
        
        $success = Install-ServerPlugin -PluginUrl $PluginUrl -ServerPath $DownloadFolder -PluginName $InstallPlugin
        
        if ($success) {
            Write-Host "✅ Plugin installed successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Plugin installation failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($RemovePlugin) {
        Write-Host "🗑️  Plugin Removal" -ForegroundColor Cyan
        Write-Host "=================" -ForegroundColor Cyan
        
        $success = Remove-ServerPlugin -PluginName $RemovePlugin -ServerPath $DownloadFolder -Force:$ForceRemovePlugin
        
        if ($success) {
            Write-Host "✅ Plugin removed successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Plugin removal failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($CreateConfigTemplate) {
        Write-Host "📝 Server Config Template Creation" -ForegroundColor Cyan
        Write-Host "===================================" -ForegroundColor Cyan
        
        $success = New-ServerConfigTemplate -TemplateName $TemplateName -ServerPath $DownloadFolder -OutputPath $TemplatesPath
        
        if ($success) {
            Write-Host "✅ Server config template created successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Server config template creation failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($ApplyConfigTemplate) {
        Write-Host "🔧 Server Config Template Application" -ForegroundColor Cyan
        Write-Host "=====================================" -ForegroundColor Cyan
        
        $success = Apply-ServerConfigTemplate -TemplateName $ApplyConfigTemplate -ServerPath $DownloadFolder -TemplatesPath $TemplatesPath -Force:$ForceApplyTemplate
        
        if ($success) {
            Write-Host "✅ Server config template applied successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Server config template application failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($RunServerHealthCheck) {
        Write-Host "🏥 Server Health Check" -ForegroundColor Cyan
        Write-Host "=====================" -ForegroundColor Cyan
        
        $healthResults = Test-ServerHealth -ServerPath $DownloadFolder -Timeout $HealthCheckTimeout
        
        if ($healthResults) {
            $passedChecks = ($healthResults.Values | Where-Object { $_ -eq $true }).Count
            $totalChecks = $healthResults.Count
            
            if ($passedChecks -eq $totalChecks) {
                Write-Host "✅ All health checks passed" -ForegroundColor Green
                exit 0
            } else {
                Write-Host "⚠️  Some health checks failed" -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "❌ Health check failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($RunServerDiagnostics) {
        Write-Host "🔍 Server Diagnostics" -ForegroundColor Cyan
        Write-Host "====================" -ForegroundColor Cyan
        
        $diagnostics = Get-ServerDiagnostics -ServerPath $DownloadFolder -LogLines $DiagnosticsLogLines
        
        if ($diagnostics) {
            Write-Host "✅ Server diagnostics completed" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Server diagnostics failed" -ForegroundColor Red
            exit 1
        }
    }

    # GUI Interface
    if ($Gui) {
        Write-Host "🖥️  Starting GUI Interface" -ForegroundColor Cyan
        Write-Host "========================" -ForegroundColor Cyan
        
        $effectiveDatabaseFile = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
        
        $success = Show-ModManagerGui -DatabaseFile $effectiveDatabaseFile -DownloadFolder $DownloadFolder
        
        if ($success) {
            Write-Host "✅ GUI closed successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ GUI encountered an error" -ForegroundColor Red
            exit 1
        }
    }

    # Cross-Platform Modpack Integration
    if ($ImportModpack) {
        Write-Host "📦 Cross-Platform Modpack Integration" -ForegroundColor Cyan
        Write-Host "=====================================" -ForegroundColor Cyan
        
        if (-not (Test-Path $ImportModpack)) {
            Write-Host "❌ Modpack file not found: $ImportModpack" -ForegroundColor Red
            exit 1
        }
        
        $success = Import-UnifiedModpack -ModpackPath $ImportModpack -ModpackType $ModpackType -DownloadFolder $DownloadFolder -CsvPath $DatabaseFile -ResolveConflicts:$ResolveConflicts
        
        if ($success) {
            Write-Host "✅ Modpack import completed successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Modpack import failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($ExportModpack) {
        Write-Host "📦 Export Mod List as Modpack" -ForegroundColor Cyan
        Write-Host "=============================" -ForegroundColor Cyan
        
        $success = Export-ModListAsModpack -CsvPath $DatabaseFile -OutputPath $ExportModpack -ModpackType $ExportType -ModpackName $ExportName -Author $ExportAuthor
        
        if ($success) {
            Write-Host "✅ Modpack export completed successfully" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Modpack export failed" -ForegroundColor Red
            exit 1
        }
    }

    if ($ValidateModpack) {
        Write-Host "🔍 Validate Modpack Integrity" -ForegroundColor Cyan
        Write-Host "=============================" -ForegroundColor Cyan
        
        if (-not (Test-Path $ValidateModpack)) {
            Write-Host "❌ Modpack file not found: $ValidateModpack" -ForegroundColor Red
            exit 1
        }
        
        # Auto-detect type if needed
        if ($ValidateType -eq "auto") {
            $ValidateType = Detect-ModpackType -ModpackPath $ValidateModpack
            Write-Host "Auto-detected modpack type: $ValidateType" -ForegroundColor Yellow
        }
        
        $success = Test-ModpackIntegrity -ModpackPath $ValidateModpack -ModpackType $ValidateType
        
        if ($success) {
            Write-Host "✅ Modpack integrity validation passed" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ Modpack integrity validation failed" -ForegroundColor Red
            exit 1
        }
    }
    # ... (other CLI logic as needed) ...
}

# Only run CLI logic if this script is being run directly, not dot-sourced
if ($MyInvocation.InvocationName -eq $null -or $MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Invoke-ModManagerCli
}

# GUI Interface Functions
function Show-ModManagerGui {
    param(
        [string]$DatabaseFile = "modlist.csv",
        [string]$DownloadFolder = "download"
    )
    
    try {
        # Check if Windows Forms is available
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        # Create main form
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Minecraft Mods Manager"
        $form.Size = New-Object System.Drawing.Size(1000, 700)
        $form.StartPosition = "CenterScreen"
        $form.FormBorderStyle = "FixedSingle"
        $form.MaximizeBox = $false
        
        # Create tab control
        $tabControl = New-Object System.Windows.Forms.TabControl
        $tabControl.Location = New-Object System.Drawing.Point(10, 10)
        $tabControl.Size = New-Object System.Drawing.Size(960, 640)
        
        # Mod Management Tab
        $modTab = New-Object System.Windows.Forms.TabPage
        $modTab.Text = "Mod Management"
        
        # Mod list view
        $modListView = New-Object System.Windows.Forms.ListView
        $modListView.Location = New-Object System.Drawing.Point(10, 10)
        $modListView.Size = New-Object System.Drawing.Size(600, 400)
        $modListView.View = "Details"
        $modListView.FullRowSelect = $true
        $modListView.GridLines = $true
        
        # Add columns
        $modListView.Columns.Add("Name", 150)
        $modListView.Columns.Add("Current Version", 100)
        $modListView.Columns.Add("Latest Version", 100)
        $modListView.Columns.Add("Type", 80)
        $modListView.Columns.Add("Status", 100)
        
        # Mod action buttons
        $refreshButton = New-Object System.Windows.Forms.Button
        $refreshButton.Location = New-Object System.Drawing.Point(620, 10)
        $refreshButton.Size = New-Object System.Drawing.Size(120, 30)
        $refreshButton.Text = "Refresh List"
        $refreshButton.Add_Click({ Load-ModList })
        
        $downloadButton = New-Object System.Windows.Forms.Button
        $downloadButton.Location = New-Object System.Drawing.Point(620, 50)
        $downloadButton.Size = New-Object System.Drawing.Size(120, 30)
        $downloadButton.Text = "Download Selected"
        $downloadButton.Add_Click({ Download-SelectedMods })
        
        $updateButton = New-Object System.Windows.Forms.Button
        $updateButton.Location = New-Object System.Drawing.Point(620, 90)
        $updateButton.Size = New-Object System.Drawing.Size(120, 30)
        $updateButton.Text = "Update Database"
        $updateButton.Add_Click({ Update-ModDatabase })
        
        $addModButton = New-Object System.Windows.Forms.Button
        $addModButton.Location = New-Object System.Drawing.Point(620, 130)
        $addModButton.Size = New-Object System.Drawing.Size(120, 30)
        $addModButton.Text = "Add Mod"
        $addModButton.Add_Click({ Show-AddModDialog })
        
        $deleteModButton = New-Object System.Windows.Forms.Button
        $deleteModButton.Location = New-Object System.Drawing.Point(620, 170)
        $deleteModButton.Size = New-Object System.Drawing.Size(120, 30)
        $deleteModButton.Text = "Delete Selected"
        $deleteModButton.Add_Click({ Delete-SelectedMods })
        
        # Progress bar
        $progressBar = New-Object System.Windows.Forms.ProgressBar
        $progressBar.Location = New-Object System.Drawing.Point(10, 420)
        $progressBar.Size = New-Object System.Drawing.Size(600, 20)
        $progressBar.Visible = $false
        
        # Status label
        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Location = New-Object System.Drawing.Point(10, 450)
        $statusLabel.Size = New-Object System.Drawing.Size(600, 20)
        $statusLabel.Text = "Ready"
        
        # Add controls to mod tab
        $modTab.Controls.AddRange(@($modListView, $refreshButton, $downloadButton, $updateButton, $addModButton, $deleteModButton, $progressBar, $statusLabel))
        
        # Server Management Tab
        $serverTab = New-Object System.Windows.Forms.TabPage
        $serverTab.Text = "Server Management"
        
        # Server controls
        $downloadServerButton = New-Object System.Windows.Forms.Button
        $downloadServerButton.Location = New-Object System.Drawing.Point(10, 10)
        $downloadServerButton.Size = New-Object System.Drawing.Size(150, 30)
        $downloadServerButton.Text = "Download Server"
        $downloadServerButton.Add_Click({ Download-ServerFiles })
        
        $startServerButton = New-Object System.Windows.Forms.Button
        $startServerButton.Location = New-Object System.Drawing.Point(170, 10)
        $startServerButton.Size = New-Object System.Drawing.Size(150, 30)
        $startServerButton.Text = "Start Server"
        $startServerButton.Add_Click({ Start-MinecraftServer })
        
        $serverLogTextBox = New-Object System.Windows.Forms.TextBox
        $serverLogTextBox.Location = New-Object System.Drawing.Point(10, 50)
        $serverLogTextBox.Size = New-Object System.Drawing.Size(600, 400)
        $serverLogTextBox.Multiline = $true
        $serverLogTextBox.ScrollBars = "Vertical"
        $serverLogTextBox.ReadOnly = $true
        $serverLogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
        
        # Add controls to server tab
        $serverTab.Controls.AddRange(@($downloadServerButton, $startServerButton, $serverLogTextBox))
        
        # Modpack Management Tab
        $modpackTab = New-Object System.Windows.Forms.TabPage
        $modpackTab.Text = "Modpack Management"
        
        # Modpack controls
        $importModpackButton = New-Object System.Windows.Forms.Button
        $importModpackButton.Location = New-Object System.Drawing.Point(10, 10)
        $importModpackButton.Size = New-Object System.Drawing.Size(150, 30)
        $importModpackButton.Text = "Import Modpack"
        $importModpackButton.Add_Click({ Import-ModpackFromGui })
        
        $exportModpackButton = New-Object System.Windows.Forms.Button
        $exportModpackButton.Location = New-Object System.Drawing.Point(170, 10)
        $exportModpackButton.Size = New-Object System.Drawing.Size(150, 30)
        $exportModpackButton.Text = "Export Modpack"
        $exportModpackButton.Add_Click({ Export-ModpackFromGui })
        
        $validateModpackButton = New-Object System.Windows.Forms.Button
        $validateModpackButton.Location = New-Object System.Drawing.Point(330, 10)
        $validateModpackButton.Size = New-Object System.Drawing.Size(150, 30)
        $validateModpackButton.Text = "Validate Modpack"
        $validateModpackButton.Add_Click({ Validate-ModpackFromGui })
        
        # Modpack list view
        $modpackListView = New-Object System.Windows.Forms.ListView
        $modpackListView.Location = New-Object System.Drawing.Point(10, 50)
        $modpackListView.Size = New-Object System.Drawing.Size(600, 400)
        $modpackListView.View = "Details"
        $modpackListView.FullRowSelect = $true
        $modpackListView.GridLines = $true
        
        # Add columns
        $modpackListView.Columns.Add("Name", 200)
        $modpackListView.Columns.Add("Type", 100)
        $modpackListView.Columns.Add("Game Version", 100)
        $modpackListView.Columns.Add("Mod Count", 80)
        $modpackListView.Columns.Add("Status", 100)
        
        # Add controls to modpack tab
        $modpackTab.Controls.AddRange(@($importModpackButton, $exportModpackButton, $validateModpackButton, $modpackListView))
        
        # Settings Tab
        $settingsTab = New-Object System.Windows.Forms.TabPage
        $settingsTab.Text = "Settings"
        
        # Settings controls
        $databaseFileLabel = New-Object System.Windows.Forms.Label
        $databaseFileLabel.Location = New-Object System.Drawing.Point(10, 20)
        $databaseFileLabel.Size = New-Object System.Drawing.Size(120, 20)
        $databaseFileLabel.Text = "Database File:"
        
        $databaseFileTextBox = New-Object System.Windows.Forms.TextBox
        $databaseFileTextBox.Location = New-Object System.Drawing.Point(140, 20)
        $databaseFileTextBox.Size = New-Object System.Drawing.Size(300, 20)
        $databaseFileTextBox.Text = $DatabaseFile
        
        $downloadFolderLabel = New-Object System.Windows.Forms.Label
        $downloadFolderLabel.Location = New-Object System.Drawing.Point(10, 50)
        $downloadFolderLabel.Size = New-Object System.Drawing.Size(120, 20)
        $downloadFolderLabel.Text = "Download Folder:"
        
        $downloadFolderTextBox = New-Object System.Windows.Forms.TextBox
        $downloadFolderTextBox.Location = New-Object System.Drawing.Point(140, 50)
        $downloadFolderTextBox.Size = New-Object System.Drawing.Size(300, 20)
        $downloadFolderTextBox.Text = $DownloadFolder
        
        $saveSettingsButton = New-Object System.Windows.Forms.Button
        $saveSettingsButton.Location = New-Object System.Drawing.Point(140, 90)
        $saveSettingsButton.Size = New-Object System.Drawing.Size(100, 30)
        $saveSettingsButton.Text = "Save Settings"
        $saveSettingsButton.Add_Click({ Save-GuiSettings })
        
        # Add controls to settings tab
        $settingsTab.Controls.AddRange(@($databaseFileLabel, $databaseFileTextBox, $downloadFolderLabel, $downloadFolderTextBox, $saveSettingsButton))
        
        # Add tabs to control
        $tabControl.TabPages.AddRange(@($modTab, $serverTab, $modpackTab, $settingsTab))
        
        # Add tab control to form
        $form.Controls.Add($tabControl)
        
        # Load initial data
        Load-ModList
        Load-ModpackList
        
        # Show form
        $form.ShowDialog()
    }
    catch {
        Write-Error "Failed to create GUI: $($_.Exception.Message)"
        return $false
    }
}

function Load-ModList {
    try {
        $modListView.Items.Clear()
        
        if (-not (Test-Path $DatabaseFile)) {
            $statusLabel.Text = "Database file not found"
            return
        }
        
        $mods = Import-Csv -Path $DatabaseFile
        $progressBar.Maximum = $mods.Count
        $progressBar.Value = 0
        $progressBar.Visible = $true
        $statusLabel.Text = "Loading mod list..."
        
        foreach ($mod in $mods) {
            $item = New-Object System.Windows.Forms.ListViewItem($mod.Name)
            $item.SubItems.Add($mod.CurrentVersion)
            $item.SubItems.Add($mod.LatestVersion)
            $item.SubItems.Add($mod.Type)
            
            # Determine status
            $status = if ($mod.CurrentVersion -eq $mod.LatestVersion) { "Up to date" } else { "Update available" }
            $item.SubItems.Add($status)
            
            $modListView.Items.Add($item)
            $progressBar.Value++
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        $progressBar.Visible = $false
        $statusLabel.Text = "Loaded $($mods.Count) mods"
    }
    catch {
        $statusLabel.Text = "Error loading mod list: $($_.Exception.Message)"
        $progressBar.Visible = $false
    }
}

function Download-SelectedMods {
    try {
        $selectedItems = $modListView.SelectedItems
        if ($selectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select mods to download", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        
        $progressBar.Maximum = $selectedItems.Count
        $progressBar.Value = 0
        $progressBar.Visible = $true
        $statusLabel.Text = "Downloading selected mods..."
        
        foreach ($item in $selectedItems) {
            $modName = $item.Text
            $statusLabel.Text = "Downloading $modName..."
            
            # Call ModManager download function
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadMods -DatabaseFile $DatabaseFile -DownloadFolder $DownloadFolder -UseCachedResponses
            
            $progressBar.Value++
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        $progressBar.Visible = $false
        $statusLabel.Text = "Download completed"
        Load-ModList
    }
    catch {
        $statusLabel.Text = "Error downloading mods: $($_.Exception.Message)"
        $progressBar.Visible = $false
    }
}

function Update-ModDatabase {
    try {
        $statusLabel.Text = "Updating mod database..."
        $progressBar.Visible = $true
        $progressBar.Style = "Marquee"
        
        # Call ModManager update function
        $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $DatabaseFile -UseCachedResponses
        
        $progressBar.Style = "Blocks"
        $progressBar.Visible = $false
        $statusLabel.Text = "Database updated"
        Load-ModList
    }
    catch {
        $statusLabel.Text = "Error updating database: $($_.Exception.Message)"
        $progressBar.Visible = $false
    }
}

function Show-AddModDialog {
    try {
        $addForm = New-Object System.Windows.Forms.Form
        $addForm.Text = "Add New Mod"
        $addForm.Size = New-Object System.Drawing.Size(400, 300)
        $addForm.StartPosition = "CenterParent"
        $addForm.FormBorderStyle = "FixedDialog"
        $addForm.MaximizeBox = $false
        $addForm.MinimizeBox = $false
        
        # Mod ID
        $modIdLabel = New-Object System.Windows.Forms.Label
        $modIdLabel.Location = New-Object System.Drawing.Point(10, 20)
        $modIdLabel.Size = New-Object System.Drawing.Size(100, 20)
        $modIdLabel.Text = "Mod ID:"
        
        $modIdTextBox = New-Object System.Windows.Forms.TextBox
        $modIdTextBox.Location = New-Object System.Drawing.Point(120, 20)
        $modIdTextBox.Size = New-Object System.Drawing.Size(250, 20)
        
        # Mod Name
        $modNameLabel = New-Object System.Windows.Forms.Label
        $modNameLabel.Location = New-Object System.Drawing.Point(10, 50)
        $modNameLabel.Size = New-Object System.Drawing.Size(100, 20)
        $modNameLabel.Text = "Mod Name:"
        
        $modNameTextBox = New-Object System.Windows.Forms.TextBox
        $modNameTextBox.Location = New-Object System.Drawing.Point(120, 50)
        $modNameTextBox.Size = New-Object System.Drawing.Size(250, 20)
        
        # Game Version
        $gameVersionLabel = New-Object System.Windows.Forms.Label
        $gameVersionLabel.Location = New-Object System.Drawing.Point(10, 80)
        $gameVersionLabel.Size = New-Object System.Drawing.Size(100, 20)
        $gameVersionLabel.Text = "Game Version:"
        
        $gameVersionTextBox = New-Object System.Windows.Forms.TextBox
        $gameVersionTextBox.Location = New-Object System.Drawing.Point(120, 80)
        $gameVersionTextBox.Size = New-Object System.Drawing.Size(250, 20)
        $gameVersionTextBox.Text = $DefaultGameVersion
        
        # Mod Type
        $modTypeLabel = New-Object System.Windows.Forms.Label
        $modTypeLabel.Location = New-Object System.Drawing.Point(10, 110)
        $modTypeLabel.Size = New-Object System.Drawing.Size(100, 20)
        $modTypeLabel.Text = "Mod Type:"
        
        $modTypeComboBox = New-Object System.Windows.Forms.ComboBox
        $modTypeComboBox.Location = New-Object System.Drawing.Point(120, 110)
        $modTypeComboBox.Size = New-Object System.Drawing.Size(250, 20)
        $modTypeComboBox.Items.AddRange(@("mod", "resourcepack", "datapack", "shaderpack"))
        $modTypeComboBox.SelectedIndex = 0
        
        # Buttons
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Location = New-Object System.Drawing.Point(200, 220)
        $okButton.Size = New-Object System.Drawing.Size(75, 25)
        $okButton.Text = "OK"
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        
        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Location = New-Object System.Drawing.Point(285, 220)
        $cancelButton.Size = New-Object System.Drawing.Size(75, 25)
        $cancelButton.Text = "Cancel"
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        
        # Add controls
        $addForm.Controls.AddRange(@($modIdLabel, $modIdTextBox, $modNameLabel, $modNameTextBox, $gameVersionLabel, $gameVersionTextBox, $modTypeLabel, $modTypeComboBox, $okButton, $cancelButton))
        
        # Show dialog
        $result = $addForm.ShowDialog()
        
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            # Add mod using ModManager
            $addResult = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModId $modIdTextBox.Text -AddModName $modNameTextBox.Text -AddModGameVersion $gameVersionTextBox.Text -AddModType $modTypeComboBox.Text -DatabaseFile $DatabaseFile
            
            if ($LASTEXITCODE -eq 0) {
                Load-ModList
                $statusLabel.Text = "Mod added successfully"
            } else {
                $statusLabel.Text = "Error adding mod"
            }
        }
    }
    catch {
        $statusLabel.Text = "Error showing add mod dialog: $($_.Exception.Message)"
    }
}

function Delete-SelectedMods {
    try {
        $selectedItems = $modListView.SelectedItems
        if ($selectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select mods to delete", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to delete the selected mods?", "Confirm Delete", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            $progressBar.Maximum = $selectedItems.Count
            $progressBar.Value = 0
            $progressBar.Visible = $true
            $statusLabel.Text = "Deleting selected mods..."
            
            foreach ($item in $selectedItems) {
                $modName = $item.Text
                $statusLabel.Text = "Deleting $modName..."
                
                # Call ModManager delete function
                $deleteResult = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DeleteModID $modName -DatabaseFile $DatabaseFile
                
                $progressBar.Value++
                [System.Windows.Forms.Application]::DoEvents()
            }
            
            $progressBar.Visible = $false
            $statusLabel.Text = "Delete completed"
            Load-ModList
        }
    }
    catch {
        $statusLabel.Text = "Error deleting mods: $($_.Exception.Message)"
        $progressBar.Visible = $false
    }
}

function Download-ServerFiles {
    try {
        $statusLabel.Text = "Downloading server files..."
        $progressBar.Visible = $true
        $progressBar.Style = "Marquee"
        
        # Call ModManager server download function
        $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadServer -DownloadFolder $DownloadFolder -UseCachedResponses
        
        $progressBar.Style = "Blocks"
        $progressBar.Visible = $false
        $statusLabel.Text = "Server files downloaded"
    }
    catch {
        $statusLabel.Text = "Error downloading server files: $($_.Exception.Message)"
        $progressBar.Visible = $false
    }
}

function Start-MinecraftServer {
    try {
        $statusLabel.Text = "Starting Minecraft server..."
        $serverLogTextBox.Clear()
        
        # Call ModManager server start function
        $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -StartServer -DownloadFolder $DownloadFolder 2>&1
        
        $serverLogTextBox.AppendText($result)
        $statusLabel.Text = "Server started"
    }
    catch {
        $statusLabel.Text = "Error starting server: $($_.Exception.Message)"
        $serverLogTextBox.AppendText("Error: $($_.Exception.Message)")
    }
}

function Load-ModpackList {
    try {
        $modpackListView.Items.Clear()
        
        # This would load modpacks from a database or scan for modpack files
        # For now, just show a placeholder
        $item = New-Object System.Windows.Forms.ListViewItem("No modpacks found")
        $item.SubItems.Add("")
        $item.SubItems.Add("")
        $item.SubItems.Add("")
        $item.SubItems.Add("")
        
        $modpackListView.Items.Add($item)
    }
    catch {
        Write-Error "Error loading modpack list: $($_.Exception.Message)"
    }
}

function Import-ModpackFromGui {
    try {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "Modpack files (*.mrpack;*.zip)|*.mrpack;*.zip|All files (*.*)|*.*"
        $openFileDialog.Title = "Select Modpack File"
        
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $statusLabel.Text = "Importing modpack..."
            $progressBar.Visible = $true
            $progressBar.Style = "Marquee"
            
            # Call ModManager import function
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ImportModpack $openFileDialog.FileName -DatabaseFile $DatabaseFile -UseCachedResponses
            
            $progressBar.Style = "Blocks"
            $progressBar.Visible = $false
            $statusLabel.Text = "Modpack imported"
            Load-ModList
        }
    }
    catch {
        $statusLabel.Text = "Error importing modpack: $($_.Exception.Message)"
        $progressBar.Visible = $false
    }
}

function Export-ModpackFromGui {
    try {
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Filter = "Modrinth modpack (*.mrpack)|*.mrpack|All files (*.*)|*.*"
        $saveFileDialog.Title = "Save Modpack As"
        $saveFileDialog.FileName = "exported-modpack.mrpack"
        
        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $statusLabel.Text = "Exporting modpack..."
            $progressBar.Visible = $true
            $progressBar.Style = "Marquee"
            
            # Call ModManager export function
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ExportModpack $saveFileDialog.FileName -ExportType "modrinth" -ExportName "Exported Modpack" -DatabaseFile $DatabaseFile -UseCachedResponses
            
            $progressBar.Style = "Blocks"
            $progressBar.Visible = $false
            $statusLabel.Text = "Modpack exported"
        }
    }
    catch {
        $statusLabel.Text = "Error exporting modpack: $($_.Exception.Message)"
        $progressBar.Visible = $false
    }
}

function Validate-ModpackFromGui {
    try {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "Modpack files (*.mrpack;*.zip)|*.mrpack;*.zip|All files (*.*)|*.*"
        $openFileDialog.Title = "Select Modpack File to Validate"
        
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $statusLabel.Text = "Validating modpack..."
            $progressBar.Visible = $true
            $progressBar.Style = "Marquee"
            
            # Call ModManager validate function
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateModpack $openFileDialog.FileName -DatabaseFile $DatabaseFile -UseCachedResponses
            
            $progressBar.Style = "Blocks"
            $progressBar.Visible = $false
            $statusLabel.Text = "Modpack validation completed"
        }
    }
    catch {
        $statusLabel.Text = "Error validating modpack: $($_.Exception.Message)"
        $progressBar.Visible = $false
    }
}

function Save-GuiSettings {
    try {
        $DatabaseFile = $databaseFileTextBox.Text
        $DownloadFolder = $downloadFolderTextBox.Text
        
        $statusLabel.Text = "Settings saved"
    }
    catch {
        $statusLabel.Text = "Error saving settings: $($_.Exception.Message)"
    }
}

# Advanced Server Management Functions
function Get-ServerPerformance {
    param(
        [string]$ServerPath = "download",
        [int]$SampleInterval = 5,
        [int]$SampleCount = 12
    )
    
    try {
        $serverJar = Get-ChildItem -Path $ServerPath -Filter "minecraft_server*.jar" | Select-Object -First 1
        if (-not $serverJar) {
            Write-Host "❌ No server JAR found in $ServerPath" -ForegroundColor Red
            return $null
        }
        
        $performanceData = @()
        
        for ($i = 0; $i -lt $SampleCount; $i++) {
            $process = Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq "java" }
            
            if ($process) {
                $cpu = $process.CPU
                $memory = $process.WorkingSet64 / 1MB
                $threads = $process.Threads.Count
                
                $performanceData += [PSCustomObject]@{
                    Timestamp = Get-Date
                    CPU = $cpu
                    MemoryMB = [math]::Round($memory, 2)
                    Threads = $threads
                    ProcessId = $process.Id
                }
                
                Write-Host "Sample $($i + 1): CPU=$cpu%, Memory=${memory}MB, Threads=$threads" -ForegroundColor Yellow
            } else {
                Write-Host "Sample $($i + 1): Server not running" -ForegroundColor Gray
            }
            
            if ($i -lt ($SampleCount - 1)) {
                Start-Sleep -Seconds $SampleInterval
            }
        }
        
        return $performanceData
    }
    catch {
        Write-Host "❌ Error monitoring server performance: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function New-ServerBackup {
    param(
        [string]$ServerPath = "download",
        [string]$BackupPath = "backups",
        [string]$BackupName = $null
    )
    
    try {
        if (-not (Test-Path $ServerPath)) {
            Write-Host "❌ Server path not found: $ServerPath" -ForegroundColor Red
            return $false
        }
        
        if (-not (Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $backupName = if ($BackupName) { $BackupName } else { "server-backup-$timestamp" }
        $backupFile = Join-Path $BackupPath "$backupName.zip"
        
        Write-Host "📦 Creating server backup: $backupFile" -ForegroundColor Cyan
        
        # Create backup of server files
        $serverFiles = Get-ChildItem -Path $ServerPath -Recurse | Where-Object { 
            $_.Name -match "\.(jar|properties|json|txt|log)$" -or 
            $_.Name -eq "mods" -or 
            $_.Name -eq "config" -or 
            $_.Name -eq "worlds"
        }
        
        if ($serverFiles) {
            Compress-Archive -Path $serverFiles.FullName -DestinationPath $backupFile -Force
            Write-Host "✅ Server backup created: $backupFile" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ No server files found to backup" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Error creating server backup: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Restore-ServerBackup {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupFile,
        [string]$ServerPath = "download",
        [switch]$Force
    )
    
    try {
        if (-not (Test-Path $BackupFile)) {
            Write-Host "❌ Backup file not found: $BackupFile" -ForegroundColor Red
            return $false
        }
        
        if (-not (Test-Path $ServerPath)) {
            New-Item -ItemType Directory -Path $ServerPath -Force | Out-Null
        }
        
        if (-not $Force) {
            $response = Read-Host "This will overwrite existing server files. Continue? (y/N)"
            if ($response -ne "y" -and $response -ne "Y") {
                Write-Host "❌ Backup restore cancelled" -ForegroundColor Yellow
                return $false
            }
        }
        
        Write-Host "🔄 Restoring server backup: $BackupFile" -ForegroundColor Cyan
        
        # Stop server if running
        $javaProcess = Get-Process -Name "java" -ErrorAction SilentlyContinue
        if ($javaProcess) {
            Write-Host "⚠️  Stopping running server..." -ForegroundColor Yellow
            Stop-Process -Name "java" -Force
            Start-Sleep -Seconds 3
        }
        
        # Extract backup
        Expand-Archive -Path $BackupFile -DestinationPath $ServerPath -Force
        
        Write-Host "✅ Server backup restored successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Error restoring server backup: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-ServerPlugins {
    param(
        [string]$ServerPath = "download"
    )
    
    try {
        $pluginsPath = Join-Path $ServerPath "plugins"
        if (-not (Test-Path $pluginsPath)) {
            Write-Host "ℹ️  No plugins directory found" -ForegroundColor Gray
            return @()
        }
        
        $plugins = Get-ChildItem -Path $pluginsPath -Filter "*.jar" | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Size = $_.Length
                LastModified = $_.LastWriteTime
                Path = $_.FullName
            }
        }
        
        return $plugins
    }
    catch {
        Write-Host "❌ Error getting server plugins: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Install-ServerPlugin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PluginUrl,
        [string]$ServerPath = "download",
        [string]$PluginName = $null
    )
    
    try {
        $pluginsPath = Join-Path $ServerPath "plugins"
        if (-not (Test-Path $pluginsPath)) {
            New-Item -ItemType Directory -Path $pluginsPath -Force | Out-Null
        }
        
        $pluginName = if ($PluginName) { $PluginName } else { [System.IO.Path]::GetFileName($PluginUrl) }
        $pluginPath = Join-Path $pluginsPath $pluginName
        
        Write-Host "📥 Installing plugin: $pluginName" -ForegroundColor Cyan
        
        # Download plugin
        Invoke-WebRequest -Uri $PluginUrl -OutFile $pluginPath
        
        if (Test-Path $pluginPath) {
            Write-Host "✅ Plugin installed: $pluginPath" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Failed to install plugin" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Error installing plugin: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-ServerPlugin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PluginName,
        [string]$ServerPath = "download",
        [switch]$Force
    )
    
    try {
        $pluginsPath = Join-Path $ServerPath "plugins"
        $pluginPath = Join-Path $pluginsPath $PluginName
        
        if (-not (Test-Path $pluginPath)) {
            Write-Host "❌ Plugin not found: $PluginName" -ForegroundColor Red
            return $false
        }
        
        if (-not $Force) {
            $response = Read-Host "Remove plugin '$PluginName'? (y/N)"
            if ($response -ne "y" -and $response -ne "Y") {
                Write-Host "❌ Plugin removal cancelled" -ForegroundColor Yellow
                return $false
            }
        }
        
        Write-Host "🗑️  Removing plugin: $PluginName" -ForegroundColor Cyan
        
        Remove-Item -Path $pluginPath -Force
        
        Write-Host "✅ Plugin removed: $PluginName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Error removing plugin: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function New-ServerConfigTemplate {
    param(
        [string]$TemplateName = "default",
        [string]$ServerPath = "download",
        [string]$OutputPath = "templates"
    )
    
    try {
        $serverProperties = Join-Path $ServerPath "server.properties"
        if (-not (Test-Path $serverProperties)) {
            Write-Host "❌ server.properties not found" -ForegroundColor Red
            return $false
        }
        
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        $templateFile = Join-Path $OutputPath "$TemplateName-template.properties"
        
        Write-Host "📝 Creating server config template: $templateFile" -ForegroundColor Cyan
        
        # Copy server.properties as template
        Copy-Item -Path $serverProperties -Destination $templateFile
        
        Write-Host "✅ Server config template created: $templateFile" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Error creating server config template: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Apply-ServerConfigTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TemplateName,
        [string]$ServerPath = "download",
        [string]$TemplatesPath = "templates",
        [switch]$Force
    )
    
    try {
        $templateFile = Join-Path $TemplatesPath "$TemplateName-template.properties"
        if (-not (Test-Path $templateFile)) {
            Write-Host "❌ Template not found: $templateFile" -ForegroundColor Red
            return $false
        }
        
        $serverProperties = Join-Path $ServerPath "server.properties"
        
        if (-not $Force) {
            $response = Read-Host "This will overwrite existing server.properties. Continue? (y/N)"
            if ($response -ne "y" -and $response -ne "Y") {
                Write-Host "❌ Template application cancelled" -ForegroundColor Yellow
                return $false
            }
        }
        
        Write-Host "🔧 Applying server config template: $TemplateName" -ForegroundColor Cyan
        
        Copy-Item -Path $templateFile -Destination $serverProperties -Force
        
        Write-Host "✅ Server config template applied: $TemplateName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Error applying server config template: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-ServerHealth {
    param(
        [string]$ServerPath = "download",
        [int]$Timeout = 30
    )
    
    try {
        Write-Host "🏥 Running server health check..." -ForegroundColor Cyan
        
        $healthResults = @{
            ServerJar = $false
            ServerProperties = $false
            ModsDirectory = $false
            ConfigDirectory = $false
            JavaProcess = $false
            PortAvailable = $false
            DiskSpace = $false
            MemoryAvailable = $false
        }
        
        # Check server JAR
        $serverJar = Get-ChildItem -Path $ServerPath -Filter "minecraft_server*.jar" | Select-Object -First 1
        if ($serverJar) {
            $healthResults.ServerJar = $true
            Write-Host "✅ Server JAR found: $($serverJar.Name)" -ForegroundColor Green
        } else {
            Write-Host "❌ Server JAR not found" -ForegroundColor Red
        }
        
        # Check server.properties
        $serverProperties = Join-Path $ServerPath "server.properties"
        if (Test-Path $serverProperties) {
            $healthResults.ServerProperties = $true
            Write-Host "✅ server.properties found" -ForegroundColor Green
        } else {
            Write-Host "❌ server.properties not found" -ForegroundColor Red
        }
        
        # Check mods directory
        $modsPath = Join-Path $ServerPath "mods"
        if (Test-Path $modsPath) {
            $healthResults.ModsDirectory = $true
            $modCount = (Get-ChildItem -Path $modsPath -Filter "*.jar").Count
            Write-Host "✅ Mods directory found with $modCount mods" -ForegroundColor Green
        } else {
            Write-Host "❌ Mods directory not found" -ForegroundColor Red
        }
        
        # Check config directory
        $configPath = Join-Path $ServerPath "config"
        if (Test-Path $configPath) {
            $healthResults.ConfigDirectory = $true
            Write-Host "✅ Config directory found" -ForegroundColor Green
        } else {
            Write-Host "❌ Config directory not found" -ForegroundColor Red
        }
        
        # Check Java process
        $javaProcess = Get-Process -Name "java" -ErrorAction SilentlyContinue
        if ($javaProcess) {
            $healthResults.JavaProcess = $true
            Write-Host "✅ Java process running (PID: $($javaProcess.Id))" -ForegroundColor Green
        } else {
            Write-Host "❌ Java process not running" -ForegroundColor Red
        }
        
        # Check port availability (default 25565)
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.ConnectAsync("localhost", 25565).Wait($Timeout * 1000)
            if ($tcpClient.Connected) {
                $healthResults.PortAvailable = $true
                Write-Host "✅ Port 25565 is available" -ForegroundColor Green
            } else {
                Write-Host "❌ Port 25565 is not available" -ForegroundColor Red
            }
            $tcpClient.Close()
        } catch {
            Write-Host "❌ Port 25565 is not available" -ForegroundColor Red
        }
        
        # Check disk space
        $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$((Get-Location).Drive.Name):'"
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        if ($freeSpaceGB -gt 1) {
            $healthResults.DiskSpace = $true
            Write-Host "✅ Sufficient disk space: ${freeSpaceGB}GB free" -ForegroundColor Green
        } else {
            Write-Host "❌ Low disk space: ${freeSpaceGB}GB free" -ForegroundColor Red
        }
        
        # Check available memory
        $memory = Get-WmiObject -Class Win32_OperatingSystem
        $availableMemoryGB = [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
        if ($availableMemoryGB -gt 2) {
            $healthResults.MemoryAvailable = $true
            Write-Host "✅ Sufficient memory: ${availableMemoryGB}GB available" -ForegroundColor Green
        } else {
            Write-Host "❌ Low memory: ${availableMemoryGB}GB available" -ForegroundColor Red
        }
        
        $passedChecks = ($healthResults.Values | Where-Object { $_ -eq $true }).Count
        $totalChecks = $healthResults.Count
        
        Write-Host "🏥 Health Check Summary: $passedChecks/$totalChecks checks passed" -ForegroundColor Cyan
        
        return $healthResults
    }
    catch {
        Write-Host "❌ Error running server health check: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-ServerDiagnostics {
    param(
        [string]$ServerPath = "download",
        [int]$LogLines = 100
    )
    
    try {
        Write-Host "🔍 Running server diagnostics..." -ForegroundColor Cyan
        
        $diagnostics = @{
            ServerInfo = $null
            RecentLogs = $null
            ErrorLogs = $null
            PerformanceData = $null
            PluginStatus = $null
        }
        
        # Get server information
        $serverJar = Get-ChildItem -Path $ServerPath -Filter "minecraft_server*.jar" | Select-Object -First 1
        if ($serverJar) {
            $diagnostics.ServerInfo = [PSCustomObject]@{
                JarFile = $serverJar.Name
                Size = $serverJar.Length
                LastModified = $serverJar.LastWriteTime
                Version = $serverJar.Name -replace "minecraft_server\.", "" -replace "\.jar", ""
            }
        }
        
        # Get recent logs
        $logFiles = Get-ChildItem -Path $ServerPath -Filter "*.log" | Sort-Object LastWriteTime -Descending
        if ($logFiles) {
            $latestLog = $logFiles[0]
            $diagnostics.RecentLogs = Get-Content -Path $latestLog.FullName -Tail $LogLines
        }
        
        # Get error logs
        if ($diagnostics.RecentLogs) {
            $diagnostics.ErrorLogs = $diagnostics.RecentLogs | Where-Object { 
                $_ -match "ERROR|FATAL|Exception|Failed" 
            }
        }
        
        # Get performance data
        $diagnostics.PerformanceData = Get-ServerPerformance -ServerPath $ServerPath -SampleCount 3
        
        # Get plugin status
        $diagnostics.PluginStatus = Get-ServerPlugins -ServerPath $ServerPath
        
        return $diagnostics
    }
    catch {
        Write-Host "❌ Error running server diagnostics: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}
