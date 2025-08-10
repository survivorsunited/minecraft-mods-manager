# =============================================================================
# Mods Download Module
# =============================================================================
# This module handles downloading mods from various sources.
# =============================================================================

<#
.SYNOPSIS
    Downloads mods from the modlist.

.DESCRIPTION
    Downloads mods from the modlist to organized folders by game version,
    supporting both current and latest versions.

.PARAMETER CsvPath
    The path to the CSV file containing mod information.

.PARAMETER DownloadFolder
    The base download folder.

.PARAMETER UseLatestVersion
    Whether to download latest versions instead of current versions.

.PARAMETER ForceDownload
    Whether to force download even if files exist.

.EXAMPLE
    Download-Mods -CsvPath "modlist.csv" -UseLatestVersion

.NOTES
    - Downloads mods to organized folder structure
    - Supports Modrinth and CurseForge mods
    - Handles different mod types (mods, shaderpacks, installers, etc.)
    - Creates detailed download reports
#>
function Download-Mods {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$DownloadFolder = "download",
        [switch]$UseLatestVersion,
        [switch]$UseNextVersion,
        [switch]$ForceDownload,
        [string]$TargetGameVersion = $null
    )
    
    try {
        $mods = Get-ModList -CsvPath $CsvPath
        if (-not $mods) {
            return
        }
        
        # When target version specified, use smart version selection
        if ($TargetGameVersion) {
            Write-Host "🔍 Preparing mods for target version: $TargetGameVersion" -ForegroundColor Cyan
            Write-Host "📊 Processing $($mods.Count) total entries with smart version fallback" -ForegroundColor Gray
            
            # Group mods by Name to find best version for each
            $modGroups = $mods | Group-Object Name
            $smartMods = @()
            
            foreach ($group in $modGroups) {
                # Check if target version exists for this mod
                $targetVersionMod = $group.Group | Where-Object { $_.CurrentGameVersion -eq $TargetGameVersion -or $_.GameVersion -eq $TargetGameVersion } | Select-Object -First 1
                
                if ($targetVersionMod) {
                    # Use the target version
                    $smartMods += $targetVersionMod
                } else {
                    # Use the latest available version (highest version number)
                    $latestMod = $group.Group | Where-Object { ($_.CurrentGameVersion -and $_.CurrentGameVersion -ne "") -or ($_.GameVersion -and $_.GameVersion -ne "") } | Sort-Object { 
                        $version = if ($_.CurrentGameVersion -and $_.CurrentGameVersion -ne "") { $_.CurrentGameVersion } else { $_.GameVersion }
                        [Version]($version -replace '[^\d.]', '') 
                    } -Descending | Select-Object -First 1
                    if ($latestMod) {
                        Write-Host "  ⚠️  $($latestMod.Name): No $TargetGameVersion version, using $($latestMod.GameVersion)" -ForegroundColor Yellow
                        $smartMods += $latestMod
                    }
                }
            }
            
            $mods = $smartMods
            Write-Host "📊 Smart selection: $($mods.Count) mods prepared for $TargetGameVersion" -ForegroundColor Green
        }
        
        # Determine target game version
        $versionAnalysis = $null
        
        if ($TargetGameVersion) {
            # Use specified target version (don't override!)
            $targetGameVersion = $TargetGameVersion
            Write-Host "Targeting specified game version: $targetGameVersion" -ForegroundColor Green
            Write-Host ""
        } elseif ($UseLatestVersion) {
            # Use majority version for latest downloads
            $versionResult = Get-MajorityGameVersion -CsvPath $CsvPath
            $targetGameVersion = $versionResult.MajorityVersion
            $versionAnalysis = $versionResult.Analysis
            Write-Host "Targeting majority game version: $targetGameVersion" -ForegroundColor Green
            Write-Host ""
        } elseif ($UseNextVersion) {
            # Use next version for next version downloads
            $nextVersionResult = Calculate-NextGameVersion -CsvPath $CsvPath
            $targetGameVersion = $nextVersionResult.NextVersion
            $versionAnalysis = $nextVersionResult.Analysis
            Write-Host "Targeting next game version: $targetGameVersion" -ForegroundColor Cyan
            Write-Host ""
        } else {
            # Default version only if nothing else specified
            $targetGameVersion = $DefaultGameVersion
            Write-Host "Targeting default game version: $targetGameVersion" -ForegroundColor Green
            Write-Host ""
        }
        
        # Create mods folder if it doesn't exist
        if (-not (Test-Path $DownloadFolder)) {
            New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
            Write-Host "Created mods folder: $DownloadFolder" -ForegroundColor Green
        }
        
        # Only clear version folders if ForceDownload is specified
        if ($ForceDownload) {
            # Determine which version folders need to be cleared
            $versionsToClear = @()
            if ($TargetGameVersion) {
                # For target version, only clear the specified version folder
                $versionsToClear = @($targetGameVersion)
                Write-Host "Will clear version folder: $targetGameVersion" -ForegroundColor Yellow
            } elseif ($UseLatestVersion) {
                # For latest versions, only clear the majority version folder
                $versionsToClear = @($targetGameVersion)
                Write-Host "Will clear version folder: $targetGameVersion" -ForegroundColor Yellow
            } elseif ($UseNextVersion) {
                # For next versions, only clear the next version folder
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
        } else {
            Write-Host "📦 Ensuring mods are available (using cache when possible)..." -ForegroundColor Cyan
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
            $gameVersion = if (-not [string]::IsNullOrEmpty($mod.CurrentGameVersion)) { $mod.CurrentGameVersion } elseif (-not [string]::IsNullOrEmpty($mod.GameVersion)) { $mod.GameVersion } else { $DefaultGameVersion }
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
            } elseif ($jarFilename -and -not $UseLatestVersion -and -not $UseNextVersion) {
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
            $gameVersionFolder = if ($UseLatestVersion -or $UseNextVersion -or $TargetGameVersion) { Join-Path $DownloadFolder $targetGameVersion } else { Join-Path $DownloadFolder $gameVersion }
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
                $gameVersion = if (-not [string]::IsNullOrEmpty($mod.CurrentGameVersion)) { $mod.CurrentGameVersion } elseif (-not [string]::IsNullOrEmpty($mod.GameVersion)) { $mod.GameVersion } else { $DefaultGameVersion }
                
                # Get JAR filename from CSV
                $jarFilename = if (-not [string]::IsNullOrEmpty($mod.Jar)) { $mod.Jar } else { "" }
                
                # Determine which URL to use for download
                $downloadUrl = $null
                $downloadVersion = $null
                $result = $null
                
                # For system entries (installer, launcher, server), handle differently based on UseLatestVersion
                if ($mod.Type -in @("installer", "launcher", "server")) {
                    if ($UseLatestVersion -or $UseNextVersion) {
                        # When using latest/next version, find system entry that matches target game version
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
                            # For server/launcher entries with no URL, delegate to dedicated server download function
                            if ($mod.Type -in @("launcher", "server")) {
                                Write-Host "⏭️  $($mod.Name): Delegating to server download function for URL resolution..." -ForegroundColor Yellow
                                continue  # Skip normal download process - server download will handle this
                            } else {
                                Write-Host "❌ $($mod.Name): No direct URL available for system entry" -ForegroundColor Red
                                $errorCount++
                                continue
                            }
                        }
                    }
                } elseif ($UseLatestVersion -and $mod.LatestVersionUrl) {
                    $downloadUrl = $mod.LatestVersionUrl
                    $downloadVersion = $mod.LatestVersion
                    # For CurseForge mods, we still need to get the filename from API
                    if ($modHost -eq "curseforge") {
                        $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.CurrentVersion -Loader $loader -ResponseFolder $ApiResponseFolder -Jar $jarFilename -ModUrl $mod.URL -Quiet
                    }
                } elseif ($UseNextVersion -and $mod.NextVersionUrl) {
                    $downloadUrl = $mod.NextVersionUrl
                    $downloadVersion = $mod.NextVersion
                    # For CurseForge mods, we still need to get the filename from API
                    if ($modHost -eq "curseforge") {
                        $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.NextVersion -Loader $loader -ResponseFolder $ApiResponseFolder -Jar $jarFilename -ModUrl $mod.URL -Quiet
                    }
                } elseif ($mod.CurrentVersionUrl) {
                    $downloadUrl = $mod.CurrentVersionUrl
                    $downloadVersion = $mod.CurrentVersion
                    # For CurseForge mods, we still need to get the filename from API
                    if ($modHost -eq "curseforge") {
                        $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.CurrentVersion -Loader $loader -ResponseFolder $ApiResponseFolder -Jar $jarFilename -ModUrl $mod.URL
                    }
                } else {
                    # Need to fetch the URL from API
                    Write-Host "Fetching download URL for $($mod.Name)..." -ForegroundColor Cyan
                    
                    if ($modHost -eq "curseforge") {
                        $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.CurrentVersion -Loader $loader -ResponseFolder $ApiResponseFolder -Jar $jarFilename -ModUrl $mod.URL
                    } else {
                        $result = Validate-ModVersion -ModId $mod.ID -Version $mod.Version -Loader $loader -GameVersion $gameVersion -ResponseFolder $ApiResponseFolder -Jar $jarFilename
                    }
                    
                    if ($result.Exists) {
                        if ($UseLatestVersion) {
                            $downloadUrl = $result.LatestVersionUrl
                            $downloadVersion = $result.LatestVersion
                        } elseif ($UseNextVersion) {
                            # For UseNextVersion, we need to check if NextVersionUrl exists in the mod data
                            # If not, fall back to the API result's latest version URL
                            $downloadUrl = if ($mod.NextVersionUrl) { $mod.NextVersionUrl } else { $result.LatestVersionUrl }
                            $downloadVersion = if ($mod.NextVersion) { $mod.NextVersion } else { $result.LatestVersion }
                        } else {
                            $downloadUrl = $result.VersionUrl
                            $downloadVersion = $mod.CurrentVersion
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
                $gameVersionFolder = if ($UseLatestVersion -or $UseNextVersion -or $TargetGameVersion) { 
                    # For latest/next versions or when target version specified, use target version
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
                } elseif ($jarFilename -and -not $UseLatestVersion -and -not $UseNextVersion) {
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
                    
                    # Check cache first - organize by provider
                    $cacheFolder = ".cache"
                    $providerCacheFolder = Join-Path $cacheFolder $modHost
                    if (-not (Test-Path $providerCacheFolder)) {
                        New-Item -ItemType Directory -Path $providerCacheFolder -Force | Out-Null
                    }
                    
                    # Create cache path using URL hash for uniqueness
                    $urlHash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($downloadUrl))
                    $hashString = [System.BitConverter]::ToString($urlHash).Replace("-", "").Substring(0, 16)
                    $cachePath = Join-Path $providerCacheFolder "$hashString-$filename"
                    
                    # Check if file exists in cache
                    if ((Test-Path $cachePath) -and -not $ForceDownload) {
                        Write-Host "  📦 Found in cache, copying..." -ForegroundColor Green
                        Copy-Item -Path $cachePath -Destination $downloadPath -Force
                    } else {
                        # Decode URL if it contains encoded characters
                        $decodedUrl = [System.Web.HttpUtility]::UrlDecode($downloadUrl)
                        
                        # Download to cache first
                        Write-Host "  💾 Downloading to cache..." -ForegroundColor Gray
                        $webRequest = Invoke-WebRequest -Uri $decodedUrl -OutFile $cachePath -UseBasicParsing
                        
                        # Copy from cache to destination
                        Copy-Item -Path $cachePath -Destination $downloadPath -Force
                    }
                    
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
        
        # Download server files that were skipped due to missing URLs
        Write-Host ""
        Write-Host "Downloading server files from database..." -ForegroundColor Yellow
        $serverDownloadCount = Download-ServerFilesFromDatabase -DownloadFolder $DownloadFolder -ForceDownload:$ForceDownload -CsvPath $CsvPath
        
        # Ensure serverDownloadCount is a number
        if (-not $serverDownloadCount) { $serverDownloadCount = 0 }
        
        # Display summary
        Write-Host ""
        Write-Host "Download Summary:" -ForegroundColor Yellow
        Write-Host "=================" -ForegroundColor Yellow
        $totalDownloaded = [int]$successCount + [int]$serverDownloadCount
        Write-Host "✅ Successfully downloaded: $totalDownloaded" -ForegroundColor Green
        Write-Host "⏭️  Skipped (already exists): $(($downloadResults | Where-Object { $_.Status -eq "Skipped" }).Count)" -ForegroundColor Yellow
        Write-Host "❌ Failed: $errorCount" -ForegroundColor Red
        Write-Host ""
        Write-Host "Download results saved to: $downloadResultsFile" -ForegroundColor Cyan
        
        # Show missing system files if using latest version
        if (($UseLatestVersion -or $UseNextVersion) -and $missingSystemFiles.Count -gt 0) {
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
            Write-DownloadReadme -FolderPath $versionFolder -Analysis $versionAnalysis -DownloadResults $downloadResults -TargetVersion $targetGameVersion -UseLatestVersion:$UseLatestVersion -UseNextVersion:$UseNextVersion
        }
        
        return
    }
    catch {
        Write-Error "Failed to download mods: $($_.Exception.Message)"
        return 0
    }
}

# Function is available for dot-sourcing 