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
    [string]$AddModId,
    [string]$AddModUrl,
    [string]$AddModName,
    [string]$AddModLoader,
    [string]$AddModGameVersion,
    [string]$AddModType,
    [string]$AddModGroup,
    [string]$AddModDescription,
    [string]$AddModJar,
    [string]$AddModUrlDirect,
    [string]$AddModCategory,
    [switch]$DownloadServer,
    [string]$DeleteModID = $null,
    [string]$DeleteModType = $null,
    [string]$ModListFile = "modlist.csv",
    [string]$DatabaseFile = $null,
    [switch]$UseCachedResponses,
    [switch]$ValidateWithDownload
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
$ApiResponseFolder = "apiresponse"
$DownloadFolder = "download"
$BackupFolder = "backups"
$DefaultLoader = "fabric"
$DefaultGameVersion = "1.21.5"
$DefaultModType = "mod"

# API URLs from environment variables or defaults
$ModrinthApiBaseUrl = if ($env:MODRINTH_API_BASE_URL) { $env:MODRINTH_API_BASE_URL } else { "https://api.modrinth.com/v2" }
$CurseForgeApiBaseUrl = if ($env:CURSEFORGE_API_BASE_URL) { $env:CURSEFORGE_API_BASE_URL } else { "https://www.curseforge.com/api/v1" }
$CurseForgeApiKey = $env:CURSEFORGE_API_KEY

# Create API response folder if it doesn't exist
if (-not (Test-Path $ApiResponseFolder)) {
    New-Item -ItemType Directory -Path $ApiResponseFolder -Force | Out-Null
    Write-Host "Created API response folder: $ApiResponseFolder" -ForegroundColor Green
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

# Function to load mod list from CSV
function Get-ModList {
    param(
        [string]$CsvPath
    )
    try {
        if (-not (Test-Path $CsvPath)) {
            throw "Mod list CSV file not found: $CsvPath"
        }
        $mods = Import-Csv -Path $CsvPath
        if ($mods -isnot [System.Collections.IEnumerable]) { $mods = @($mods) }
        
        # Add RecordHash to records that don't have it and verify integrity
        $modifiedRecords = @()
        foreach ($mod in $mods) {
            # Add RecordHash property if it doesn't exist
            if (-not $mod.PSObject.Properties.Match('RecordHash').Count) {
                $mod | Add-Member -MemberType NoteProperty -Name 'RecordHash' -Value $null
            }
            
            $recordHash = Calculate-RecordHash -Record $mod
            
            # Check if record has been modified externally
            if ($mod.RecordHash -and $mod.RecordHash -ne $recordHash) {
                Write-Host "⚠️  Warning: Record for '$($mod.Name)' has been modified externally" -ForegroundColor Yellow
            }
            
            # Add or update RecordHash
            $mod.RecordHash = $recordHash
            $modifiedRecords += $mod
        }
        
        # Write-Host "Loaded $($mods.Count) mods from $CsvPath" -ForegroundColor Green
        return $modifiedRecords
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
        $responseFile = Join-Path $ResponseFolder "$ModId-versions.json"
        
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
        
        # Get latest version for display (filtered by loader)
        $latestVersion = if ($filteredResponse.Count -gt 0) { 
            $filteredResponse[0].version_number 
        } else { 
            "No $Loader versions found" 
        }
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
    Write-Host "  Download-Mods [-CsvPath <path>] [-DownloadFolder <path>] [-UseLatestVersion] [-ForceDownload]" -ForegroundColor White
    Write-Host "    - Downloads mods to local download folder organized by GameVersion"
    Write-Host "    - Creates subfolders for each GameVersion (e.g., download/1.21.5/mods/)"
    Write-Host "    - Creates block subfolder for mods in 'block' group (e.g., download/1.21.5/mods/block/)"
    Write-Host "    - Creates shaderpacks subfolder for shaderpacks (e.g., download/1.21.5/shaderpacks/)"
    Write-Host "    - Uses VersionUrl by default, or LatestVersionUrl with -UseLatestVersion"
    Write-Host "    - Skips existing files unless -ForceDownload is used"
    Write-Host "    - Saves download results to CSV"
    Write-Host "    - Default download folder: $DownloadFolder"
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

# Function to download mods to local mods folder
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
                    
                    $modpackResult = Download-Modpack -ModId $mod.ID -VersionUrl $downloadUrl -ModName $mod.Name -GameVersion $gameVersion -ForceDownload:$ForceDownload
                    
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

# Place Download-Modpack function before main execution
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
        [bool]$ForceDownload = $false
    )
    try {
        Write-Host "📦 Downloading modpack: $ModName" -ForegroundColor Cyan
        # Create download directory structure
        $downloadDir = "download\$GameVersion"
        $modpackDir = "$downloadDir\modpacks\$ModName"
        if (-not (Test-Path $downloadDir)) {
            New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
        }
        if (-not (Test-Path $modpackDir)) {
            New-Item -ItemType Directory -Path $modpackDir -Force | Out-Null
        }
        # Download the .mrpack file
        $mrpackFileName = "$ModName.mrpack"
        $mrpackPath = "$modpackDir\$mrpackFileName"
        if (Test-Path $mrpackPath -and -not $ForceDownload) {
            Write-Host "⏭️  Modpack file already exists, skipping download" -ForegroundColor Yellow
        } else {
            Write-Host "⬇️  Downloading modpack file..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $VersionUrl -OutFile $mrpackPath -UseBasicParsing
            Write-Host "✅ Downloaded modpack file" -ForegroundColor Green
        }
        # Extract the .mrpack file (it's just a zip file)
        Write-Host "📂 Extracting modpack..." -ForegroundColor Yellow
        Expand-Archive -Path $mrpackPath -DestinationPath $modpackDir -Force
        # Find and process modrinth.index.json
        $indexPath = "$modpackDir\modrinth.index.json"
        if (-not (Test-Path $indexPath)) {
            Write-Host "❌ modrinth.index.json not found in extracted modpack" -ForegroundColor Red
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
            $targetDir = Split-Path -Path "$downloadDir\$filePath" -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            $targetPath = "$downloadDir\$filePath"
            # Download the file
            try {
                if (Test-Path $targetPath -and -not $ForceDownload) {
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
        $overridesPath = "$modpackDir\overrides"
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
        Write-Error "Failed to download modpack: $($_.Exception.Message)"
        return 0
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
            # For installers, we expect the ID to be a direct URL or a special identifier
            # For the Fabric installer, we'll construct the URL based on the ID
            $installerUrl = $null
            $installerVersion = $null
            
            if ($id -eq "fabric-installer-1.0.3") {
                $installerUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe"
                $installerVersion = "1.0.3"
            } else {
                # Assume it's a direct URL
                $installerUrl = $id
                $installerVersion = "1.0.0"  # Default version for direct URLs
            }
            
            $resolvedMod = [PSCustomObject]@{
                Group = $group
                Type = $type
                GameVersion = $gameVersion
                ID = $id
                Loader = $loader
                Version = $installerVersion
                Name = $name
                Description = $description
                Jar = $jar
                Url = if ($urlDirect) { $urlDirect } else { $installerUrl }
                Category = $category
                VersionUrl = $installerUrl
                LatestVersionUrl = $installerUrl
                LatestVersion = $installerVersion
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
            # For launchers, we expect the ID to be a special identifier
            $launcherUrl = $null
            $launcherVersion = $null
            $launcherFilename = $null
            
            if ($id -eq "fabric-server-launcher-1.21.5") {
                $launcherUrl = "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar"
                $launcherVersion = "1.0.3"
                $launcherFilename = "fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar"
            } elseif ($id -eq "fabric-server-launcher-1.21.6") {
                $launcherUrl = "https://meta.fabricmc.net/v2/versions/loader/1.21.6/0.16.14/1.0.3/server/jar"
                $launcherVersion = "1.0.3"
                $launcherFilename = "fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar"
            } else {
                # Assume it's a direct URL
                $launcherUrl = $id
                $launcherVersion = "1.0.0"  # Default version for direct URLs
                $launcherFilename = ""
            }
            
            $resolvedMod = [PSCustomObject]@{
                Group = $group
                Type = $type
                GameVersion = $gameVersion
                ID = $id
                Loader = $loader
                Version = $launcherVersion
                Name = $name
                Description = $description
                Jar = $launcherFilename
                Url = if ($urlDirect) { $urlDirect } else { $launcherUrl }
                Category = $category
                VersionUrl = $launcherUrl
                LatestVersionUrl = $launcherUrl
                LatestVersion = $launcherVersion
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
        } elseif ($type -eq "server") {
            # For server JARs, use the provided ID to determine the URL and filename
            $serverUrl = $null
            $serverVersion = $null
            $serverFilename = $null
            if ($id -eq "minecraft-server-1.21.5") {
                $serverUrl = "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar"
                $serverVersion = "1.21.5"
                $serverFilename = "minecraft_server.1.21.5.jar"
            } elseif ($id -eq "minecraft-server-1.21.6") {
                $serverUrl = "https://piston-data.mojang.com/v1/objects/6e64dcabba3c01a7271b4fa6bd898483b794c59b/server.jar"
                $serverVersion = "1.21.6"
                $serverFilename = "minecraft_server.1.21.6.jar"
            } else {
                $serverUrl = $id
                $serverVersion = $gameVersion
                $serverFilename = "minecraft_server.$gameVersion.jar"
            }
            $resolvedMod = [PSCustomObject]@{
                Group = $group
                Type = $type
                GameVersion = $gameVersion
                ID = $id
                Loader = $loader
                Version = $serverVersion
                Name = $name
                Description = $description
                Jar = $serverFilename
                Url = if ($urlDirect) { $urlDirect } else { $serverUrl }
                Category = $category
                VersionUrl = $serverUrl
                LatestVersionUrl = $serverUrl
                LatestVersion = $serverVersion
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
        
        Download-Mods -CsvPath $effectiveModListPath -UseLatestVersion:$UseLatestVersion -ForceDownload:$ForceDownload
        return
    }
    if ($GetModList) {
        $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
        Get-ModList -CsvPath $effectiveModListPath
        return
    }
    if ($DownloadServer) {
        Download-ServerFiles -ForceDownload:$ForceDownload
        return
    }
    # Default: Run validation and update modlist
    $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath
    Validate-AllModVersions -CsvPath $effectiveModListPath -UpdateModList
    if ($Download) {
        Write-Host ""; Write-Host "Starting mod downloads..." -ForegroundColor Yellow
        $downloadParams = @{
            CsvPath = $effectiveModListPath
        }
        if ($UseLatestVersion) { $downloadParams.UseLatestVersion = $true; Write-Host "Using latest versions for downloads" -ForegroundColor Cyan }
        if ($ForceDownload) { $downloadParams.ForceDownload = $true; Write-Host "Force downloading (will overwrite existing files)" -ForegroundColor Cyan }
        $downloadedCount = Download-Mods @downloadParams
        if ($downloadedCount -gt 0) { Write-Host ""; Write-Host "Successfully downloaded $downloadedCount mods!" -ForegroundColor Green }
    }
} 

