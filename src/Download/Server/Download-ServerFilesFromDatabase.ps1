# =============================================================================
# Server Files Download From Database Module
# =============================================================================
# This module handles downloading server and launcher files based on database entries.
# =============================================================================

<#
.SYNOPSIS
    Downloads server JARs and launchers based on database entries.

.DESCRIPTION
    Downloads all server and launcher entries found in the mod database
    instead of using hardcoded values.

.PARAMETER DownloadFolder
    The base download folder.

.PARAMETER ForceDownload
    Whether to force download even if files exist.

.PARAMETER CsvPath
    Path to the CSV database file.

.PARAMETER GameVersion
    Optional specific game version to download.

.EXAMPLE
    Download-ServerFilesFromDatabase -DownloadFolder "download" -CsvPath "modlist.csv"

.NOTES
    - Reads server and launcher entries from database
    - Downloads based on URL field in database
    - Creates organized folder structure by version
    - Handles missing URLs gracefully
#>
function Download-ServerFilesFromDatabase {
    param(
        [string]$DownloadFolder = "download",
        [switch]$ForceDownload,
        [string]$CsvPath = "modlist.csv",
        [string]$GameVersion = ""
    )
    
    try {
        Write-Host "Downloading server files from database..." -ForegroundColor Yellow
        
        # Create download folder if it doesn't exist
        if (-not (Test-Path $DownloadFolder)) {
            New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
        }
        
        # Load database
        if (-not (Test-Path $CsvPath)) {
            Write-Host "❌ Database file not found: $CsvPath" -ForegroundColor Red
            return 0
        }
        
        $database = Import-Csv -Path $CsvPath
        
        # Filter for server and launcher entries
        $serverEntries = $database | Where-Object { $_.Type -eq "server" -or $_.Type -eq "launcher" }
        
        # Filter by game version if specified
        if ($GameVersion) {
            $serverEntries = $serverEntries | Where-Object { $_.GameVersion -eq $GameVersion }
        }
        
        Write-Host "Found $($serverEntries.Count) server/launcher entries in database" -ForegroundColor Cyan
        
        $downloadResults = @()
        $successCount = 0
        $errorCount = 0
        $skippedNoUrl = 0
        
        foreach ($entry in $serverEntries) {
            # Skip entries without URLs
            if (-not $entry.Url -or $entry.Url -eq "") {
                Write-Host "⏭️  $($entry.Name) ($($entry.GameVersion)): No URL specified, attempting dynamic resolution..." -ForegroundColor Yellow
                
                # Try to resolve URL dynamically based on type and ID
                $resolvedUrl = $null
                $resolvedFilename = $null
                
                if ($entry.Type -eq "server" -and $entry.ID -match "minecraft-server") {
                    # For Minecraft server, we need to fetch from Mojang API
                    Write-Host "  🔍 Fetching Minecraft server URL for version $($entry.GameVersion)..." -ForegroundColor Gray
                    
                    try {
                        # Get version manifest
                        $manifestUrl = if ($env:MINECRAFT_SERVER_URL) { $env:MINECRAFT_SERVER_URL } else { "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" }
                        $manifest = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
                        
                        # Find the version
                        $versionInfo = $manifest.versions | Where-Object { $_.id -eq $entry.GameVersion }
                        
                        if ($versionInfo) {
                            # Get version details
                            $versionDetails = Invoke-RestMethod -Uri $versionInfo.url -UseBasicParsing
                            
                            if ($versionDetails.downloads.server.url) {
                                $resolvedUrl = $versionDetails.downloads.server.url
                                $resolvedFilename = "minecraft_server.$($entry.GameVersion).jar"
                                Write-Host "  ✅ Resolved URL: $resolvedUrl" -ForegroundColor Green
                            }
                        }
                    } catch {
                        Write-Host "  ❌ Failed to resolve Minecraft server URL: $($_.Exception.Message)" -ForegroundColor Red
                    }
                    
                } elseif ($entry.Type -eq "launcher" -and $entry.ID -match "fabric-server-launcher") {
                    # For Fabric launcher, we need to fetch from Fabric API
                    Write-Host "  🔍 Fetching Fabric launcher URL for version $($entry.GameVersion)..." -ForegroundColor Gray
                    
                    try {
                        # Get Fabric versions
                        $fabricUrl = if ($env:FABRIC_SERVER_URL) { $env:FABRIC_SERVER_URL } else { "https://meta.fabricmc.net/v2/versions" }
                        $fabricVersions = Invoke-RestMethod -Uri $fabricUrl -UseBasicParsing
                        
                        # Get latest loader version
                        $latestLoader = $fabricVersions.loader | Select-Object -First 1
                        $latestLauncher = $fabricVersions.launcher | Select-Object -First 1
                        
                        if ($latestLoader -and $latestLauncher) {
                            $resolvedUrl = "https://meta.fabricmc.net/v2/versions/loader/$($entry.GameVersion)/$($latestLoader.version)/$($latestLauncher.version)/server/jar"
                            $resolvedFilename = "fabric-server-mc.$($entry.GameVersion)-loader.$($latestLoader.version)-launcher.$($latestLauncher.version).jar"
                            Write-Host "  ✅ Resolved URL: $resolvedUrl" -ForegroundColor Green
                        }
                    } catch {
                        Write-Host "  ❌ Failed to resolve Fabric launcher URL: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                
                # If we resolved a URL, use it
                if ($resolvedUrl) {
                    $entry | Add-Member -MemberType NoteProperty -Name "ResolvedUrl" -Value $resolvedUrl -Force
                    $entry | Add-Member -MemberType NoteProperty -Name "ResolvedFilename" -Value $resolvedFilename -Force
                } else {
                    $skippedNoUrl++
                    $downloadResults += [PSCustomObject]@{
                        Name = $entry.Name
                        Status = "Skipped"
                        Version = $entry.GameVersion
                        File = ""
                        Path = ""
                        Error = "No URL available"
                    }
                    continue
                }
            }
            
            # Determine download URL and filename
            $downloadUrl = if ($entry.ResolvedUrl) { $entry.ResolvedUrl } else { $entry.Url }
            $filename = if ($entry.ResolvedFilename) { $entry.ResolvedFilename } elseif ($entry.Jar) { $entry.Jar } else {
                # Generate filename from entry data
                if ($entry.Type -eq "server") {
                    "minecraft_server.$($entry.GameVersion).jar"
                } else {
                    "fabric-server-launcher.$($entry.GameVersion).jar"
                }
            }
            
            # Create version folder
            $versionFolder = Join-Path $DownloadFolder $entry.GameVersion
            if (-not (Test-Path $versionFolder)) {
                New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
            }
            
            $downloadPath = Join-Path $versionFolder $filename
            
            # Check if file already exists
            if ((Test-Path $downloadPath) -and -not $ForceDownload) {
                Write-Host "⏭️  $($entry.Name) ($($entry.GameVersion)): Already exists" -ForegroundColor Yellow
                $downloadResults += [PSCustomObject]@{
                    Name = $entry.Name
                    Status = "Skipped"
                    Version = $entry.GameVersion
                    File = $filename
                    Path = $downloadPath
                    Error = "File already exists"
                }
                continue
            }
            
            # Download the file
            Write-Host "⬇️  $($entry.Name) ($($entry.GameVersion)): Downloading..." -ForegroundColor Cyan
            
            try {
                $webRequest = Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
                
                if (Test-Path $downloadPath) {
                    $fileSize = (Get-Item $downloadPath).Length
                    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                    
                    Write-Host "✅ $($entry.Name) ($($entry.GameVersion)): Downloaded successfully ($fileSizeMB MB)" -ForegroundColor Green
                    
                    $downloadResults += [PSCustomObject]@{
                        Name = $entry.Name
                        Status = "Success"
                        Version = $entry.GameVersion
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
                Write-Host "❌ $($entry.Name) ($($entry.GameVersion)): Download failed - $($_.Exception.Message)" -ForegroundColor Red
                
                # Clean up partial download if it exists
                if (Test-Path $downloadPath) {
                    Remove-Item $downloadPath -Force
                }
                
                $downloadResults += [PSCustomObject]@{
                    Name = $entry.Name
                    Status = "Failed"
                    Version = $entry.GameVersion
                    File = $filename
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
        Write-Host "⏭️  Skipped (already exists): $(($downloadResults | Where-Object { $_.Status -eq "Skipped" -and $_.Error -eq "File already exists" }).Count)" -ForegroundColor Yellow
        Write-Host "⏭️  Skipped (no URL): $skippedNoUrl" -ForegroundColor Yellow
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

# Function is available for dot-sourcing