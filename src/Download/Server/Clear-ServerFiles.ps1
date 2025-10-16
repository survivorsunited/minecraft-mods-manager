# =============================================================================
# Server Cleanup Module
# =============================================================================
# This module handles clearing server files and re-downloading mods and server files.
# =============================================================================

<#
.SYNOPSIS
    Clears server files for a specific Minecraft version and re-downloads everything.

.DESCRIPTION
    Orchestrates the complete server cleanup workflow:
    1. Determines target version
    2. Removes server-specific files (worlds, configs, logs, etc.)
    3. Removes server JARs and Fabric launcher files
    4. Re-downloads mods for the version
    5. Re-downloads server files

.PARAMETER CsvPath
    Path to the mod database CSV file.

.PARAMETER DownloadFolder
    Path to the download folder.

.PARAMETER ApiResponseFolder
    Path to the API response cache folder.

.PARAMETER TargetVersion
    Specific version to clear.

.PARAMETER GameVersion
    Game version to use (alternative to TargetVersion).

.PARAMETER UseLatestVersion
    Clear the latest game version.

.PARAMETER UseNextVersion
    Clear the next game version.

.EXAMPLE
    Clear-ServerFiles -CsvPath "modlist.csv" -DownloadFolder "download" -GameVersion "1.21.5"

.NOTES
    - Returns $true on success, $false on failure
    - Removes world data, configs, and server files
    - Re-downloads mods and server files after clearing
#>
function Clear-ServerFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder,
        
        [Parameter(Mandatory=$true)]
        [string]$ApiResponseFolder,
        
        [Parameter(Mandatory=$false)]
        [string]$TargetVersion,
        
        [Parameter(Mandatory=$false)]
        [string]$GameVersion,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseLatestVersion,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseNextVersion
    )
    
    Write-Host "Clearing server files..." -ForegroundColor Yellow
    
    # Determine which version to clear
    $versionToClear = $null
    
    if ($TargetVersion) {
        $versionToClear = $TargetVersion
    } elseif ($GameVersion) {
        $versionToClear = $GameVersion
    } elseif ($UseLatestVersion) {
        $versionToClear = Get-LatestVersion -CsvPath $CsvPath
    } elseif ($UseNextVersion) {
        $versionToClear = Get-NextVersion -CsvPath $CsvPath
    } else {
        $versionToClear = Get-CurrentVersion -CsvPath $CsvPath
    }
    
    if (-not $versionToClear) {
        Write-Host "❌ Failed to determine version to clear" -ForegroundColor Red
        return $false
    }
    
    # Only clear the target version folder
    $targetFolder = Join-Path $DownloadFolder $versionToClear
    
    if (-not (Test-Path $targetFolder)) {
        Write-Host "⚠️  No server folder found for $versionToClear." -ForegroundColor Yellow
        Write-Host "💡 Will download fresh server files and mods..." -ForegroundColor Cyan
    } else {
        $versionFolders = @(Get-Item $targetFolder)
        
        foreach ($folder in $versionFolders) {
            $folderPath = $folder.FullName
            Write-Host "🗑️  Clearing server files in: $($folder.Name)" -ForegroundColor Cyan
            
            # Remove server-specific files and folders (including mods to ensure clean slate)
            $itemsToRemove = @(
                "world", "world_nether", "world_the_end",
                "logs", "crash-reports", "config",
                "eula.txt", "server.properties", "ops.json", "whitelist.json",
                "banned-ips.json", "banned-players.json", "usercache.json",
                "versions", "libraries", ".fabric",
                "mods"  # Clear mods folder for fresh download
            )
            
            foreach ($item in $itemsToRemove) {
                $itemPath = Join-Path $folderPath $item
                if (Test-Path $itemPath) {
                    Remove-Item $itemPath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "   ✓ Removed: $item" -ForegroundColor Gray
                }
            }
            
            # Remove server JAR files (use wildcards)
            Get-ChildItem -Path $folderPath -Filter "minecraft_server.*.jar" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "   ✓ Removed: $($_.Name)" -ForegroundColor Gray
            }
            
            # Remove Fabric launcher files (use wildcards)
            Get-ChildItem -Path $folderPath -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "   ✓ Removed: $($_.Name)" -ForegroundColor Gray
            }
            
            # Remove log files (use wildcards)
            Get-ChildItem -Path $folderPath -Filter "*.log" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
            Get-ChildItem -Path $folderPath -Filter "*.log.gz" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
            Get-ChildItem -Path $folderPath -Filter "*.tmp" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "✅ Server files cleared successfully!" -ForegroundColor Green
    }
    
    # After clearing, download mods and server files
    Write-Host ""
    Write-Host "📦 Downloading fresh mods and server files..." -ForegroundColor Cyan
    
    # Use the version we already determined above
    $currentGameVersion = $versionToClear
    
    if ($TargetVersion -or $GameVersion) {
        Write-Host "📋 Target game version: $currentGameVersion (user specified)" -ForegroundColor Cyan
    } elseif ($UseLatestVersion) {
        Write-Host "📋 Target game version: $currentGameVersion (LATEST)" -ForegroundColor Cyan
    } elseif ($UseNextVersion) {
        Write-Host "📋 Target game version: $currentGameVersion (NEXT)" -ForegroundColor Cyan
    } else {
        Write-Host "📋 Target game version: $currentGameVersion (CURRENT, default)" -ForegroundColor Cyan
    }
    
    # Download mods using target version (skip server files - handled separately)
    Write-Host "Downloading mods for $currentGameVersion..." -ForegroundColor Yellow
    Download-Mods -CsvPath $CsvPath -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder -SkipServerFiles -TargetGameVersion $currentGameVersion
    
    # Download server files ONLY for target game version
    Write-Host ""
    Write-Host "Downloading server files for $currentGameVersion only..." -ForegroundColor Yellow
    Download-ServerFiles -DownloadFolder $DownloadFolder -ForceDownload:$false -GameVersion $currentGameVersion
    
    Write-Host ""
    Write-Host "✅ Server cleared and mods downloaded successfully!" -ForegroundColor Green
    Write-Host "💡 Run -StartServer to start the server" -ForegroundColor Cyan
    
    return $true
}

