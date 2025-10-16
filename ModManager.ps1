# Minecraft Mod Manager PowerShell Script
# Uses modlist.csv as data source and Modrinth API for version checking

# Command line parameters
param(
    [switch]$Download,
    [switch]$UseLatestVersion,
    [switch]$UseNextVersion,
    [switch]$UseCurrentVersion,
    [switch]$ForceDownload,
    [switch]$Help,
    [switch]$ValidateModVersion,
    [switch]$ValidateMod,
    [string]$ModID,
    [switch]$ValidateAllModVersions,
    [switch]$UpdateMods,
    [switch]$DownloadMods,
    [switch]$GetModList,
    [switch]$ShowHelp,
    [switch]$AddMod,
    [string]$AddModId,
    [string]$AddModUrl,
    [string]$AddModName,
    [string]$SearchModName,
    [string]$AddModLoader,
    [string]$AddModGameVersion,
    [string]$AddModType,
    [string]$AddModGroup = "required",
    [string]$AddModDescription,
    [string]$AddModJar,
    [string]$AddModVersion,
    [string]$AddModUrlDirect,
    [string]$AddModCategory,
    [switch]$DownloadServer,
    [switch]$StartServer,
    [switch]$NoAutoRestart,
    [string]$GameVersion,
    [string]$TargetVersion,
    [switch]$ClearServer,
    [switch]$AddServerStartScript,
    [string]$DeleteModID,
    [string]$DeleteModType,
    [string]$ModListFile,
    [string]$DatabaseFile,
    [string]$DownloadFolder,
    [string]$ApiResponseFolder,
    [switch]$UseCachedResponses,
    [switch]$ClearCache,
    [switch]$Online,
    [switch]$ValidateWithDownload,
    [switch]$DownloadCurseForgeModpack,
    [string]$CurseForgeModpackId,
    [string]$CurseForgeFileId,
    [string]$CurseForgeModpackName,
    [string]$CurseForgeGameVersion,
    [switch]$ValidateCurseForgeModpack,
    # Cross-Platform Modpack Integration
    [string]$ImportModpack,
    [string]$ModpackType,
    [string]$ExportModpack,
    [string]$ExportType,
    [string]$ExportName,
    [string]$ExportAuthor,
    [string]$ValidateModpack,
    [string]$ValidateType,
    [bool]$ResolveConflicts,
    # Advanced Server Management
    [switch]$MonitorServerPerformance,
    [int]$PerformanceSampleInterval,
    [int]$PerformanceSampleCount,
    [switch]$CreateServerBackup,
    [string]$BackupPath,
    [string]$BackupName,
    [string]$RestoreServerBackup,
    [switch]$ForceRestore,
    [switch]$ListServerPlugins,
    [string]$InstallPlugin,
    [string]$PluginUrl,
    [string]$RemovePlugin,
    [switch]$ForceRemovePlugin,
    [string]$CreateConfigTemplate,
    [string]$TemplateName,
    [string]$TemplatesPath,
    [string]$ApplyConfigTemplate,
    [switch]$ForceApplyTemplate,
    [switch]$RunServerHealthCheck,
    [int]$HealthCheckTimeout,
    [switch]$RunServerDiagnostics,
    [int]$DiagnosticsLogLines,
    # Minecraft Version Sync
    [switch]$SyncMinecraftVersions,
    [string]$MinecraftVersionChannel = "stable",
    [string]$MinecraftMinVersion = "1.21.5",
    # JDK Version Sync
    [switch]$SyncJDKVersions,
    [string[]]$JDKVersions = @("17", "21", "22"),
    [string[]]$JDKPlatforms = @("windows", "linux", "mac"),
    # JDK Download
    [switch]$DownloadJDK,
    [string]$JDKVersion = "21",
    [string]$JDKPlatform = "",
    [switch]$DryRun
)

# Save parameter values that might be overridden by environment variables
$OriginalApiResponseFolder = $ApiResponseFolder

# Import all modular functions
. "$PSScriptRoot\src\Import-Modules.ps1"

# Load environment variables from .env file
Load-EnvironmentVariables

# Restore parameter values if they were provided
if ($OriginalApiResponseFolder) {
    $script:ApiResponseFolder = $OriginalApiResponseFolder
    $ApiResponseFolder = $OriginalApiResponseFolder
}

# Set up logging
$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$logFile = Join-Path $logDir "modmanager-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
Start-Transcript -Path $logFile -Append -Force

# Helper function to exit cleanly with transcript stop
function Exit-ModManager {
    param([int]$ExitCode = 0)
    Stop-Transcript
    exit $ExitCode
}

# Output script header
Write-Host "Minecraft Mod Manager PowerShell Script" -ForegroundColor Magenta
Write-Host "Log file: $logFile" -ForegroundColor DarkGray

# Set default values for parameters
if (-not $ModListFile) { $ModListFile = "modlist.csv" }
if (-not $DatabaseFile) { $DatabaseFile = $null }
if (-not $DownloadFolder) { $DownloadFolder = "download" }
if (-not $ApiResponseFolder) { $ApiResponseFolder = "apiresponse" }
if (-not $ModpackType) { $ModpackType = "auto" }
if (-not $ExportType) { $ExportType = "modrinth" }
if (-not $ExportName) { $ExportName = "Exported Modpack" }
if (-not $ExportAuthor) { $ExportAuthor = "ModManager" }
if (-not $ValidateType) { $ValidateType = "auto" }
if (-not $ResolveConflicts) { $ResolveConflicts = $true }
if (-not $PerformanceSampleInterval) { $PerformanceSampleInterval = 5 }
if (-not $PerformanceSampleCount) { $PerformanceSampleCount = 12 }
if (-not $BackupPath) { $BackupPath = "backups" }
if (-not $TemplateName) { $TemplateName = "default" }
if (-not $TemplatesPath) { $TemplatesPath = "templates" }
if (-not $HealthCheckTimeout) { $HealthCheckTimeout = 30 }
if (-not $DiagnosticsLogLines) { $DiagnosticsLogLines = 100 }

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

# Main script execution logic
# Handle command-line parameters and execute appropriate functions

# Get effective modlist path
$effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $ModListPath

# Handle ClearCache parameter
if ($ClearCache) {
    Write-Host "Clearing cache..." -ForegroundColor Yellow
    $cacheFolder = ".cache"
    
    if (Test-Path $cacheFolder) {
        $cacheFolders = Get-ChildItem -Path $cacheFolder -Directory
        $cacheFiles = Get-ChildItem -Path $cacheFolder -File
        
        foreach ($folder in $cacheFolders) {
            Write-Host "  🗑️  Removing: $($folder.Name)" -ForegroundColor Gray
            Remove-Item -Path $folder.FullName -Recurse -Force
        }
        
        foreach ($file in $cacheFiles) {
            Write-Host "  🗑️  Removing: $($file.Name)" -ForegroundColor Gray
            Remove-Item -Path $file.FullName -Force
        }
        
        Write-Host "✅ Cache cleared successfully!" -ForegroundColor Green
    } else {
        Write-Host "  ℹ️  Cache folder does not exist" -ForegroundColor Yellow
    }
    
    Exit-ModManager 0
}

# Handle UpdateMods parameter
if ($UpdateMods) {
    Write-Host "Starting mod update process..." -ForegroundColor Yellow
    # Use cache by default unless -Online is specified
    $useCache = -not $Online
    if ($UseCachedResponses) { $useCache = $true }  # Explicit -UseCachedResponses overrides
    Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UpdateModList -UseCachedResponses:$useCache | Out-Null
    Exit-ModManager 0
}

# Handle Download parameter
if ($Download) {
    Write-Host "Starting mod download process..." -ForegroundColor Yellow
    if ($TargetVersion) {
        Write-Host "Targeting specific game version: $TargetVersion..." -ForegroundColor Cyan
        Download-Mods -CsvPath $effectiveModListPath -TargetGameVersion $TargetVersion -ForceDownload:$ForceDownload -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder
    } elseif ($UseLatestVersion) {
        Write-Host "Using latest versions for download..." -ForegroundColor Cyan
        Download-Mods -CsvPath $effectiveModListPath -UseLatestVersion -ForceDownload:$ForceDownload -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder
    } elseif ($UseNextVersion) {
        Write-Host "Using next versions for download..." -ForegroundColor Cyan
        Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UpdateModList | Out-Null
        Download-Mods -CsvPath $effectiveModListPath -UseNextVersion -ForceDownload:$ForceDownload -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder
    } else {
        Write-Host "Using current versions for download..." -ForegroundColor Cyan
        Download-Mods -CsvPath $effectiveModListPath -ForceDownload:$ForceDownload
    }
    Exit-ModManager 0
}

# Handle DownloadMods parameter
if ($DownloadMods) {
    Write-Host "Starting mod download process..." -ForegroundColor Yellow
    if ($UseLatestVersion) {
        Write-Host "Using latest versions for download..." -ForegroundColor Cyan
        if ($TargetVersion) {
            Download-Mods -CsvPath $effectiveModListPath -UseLatestVersion -TargetGameVersion $TargetVersion -ForceDownload:$ForceDownload -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder
        } else {
            Download-Mods -CsvPath $effectiveModListPath -UseLatestVersion -ForceDownload:$ForceDownload -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder
        }
    } elseif ($UseNextVersion) {
        Write-Host "Using next versions for download..." -ForegroundColor Cyan
        Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UpdateModList | Out-Null
        Download-Mods -CsvPath $effectiveModListPath -UseNextVersion -ForceDownload:$ForceDownload -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder
    } else {
        Write-Host "Using current versions for download..." -ForegroundColor Cyan
        Download-Mods -CsvPath $effectiveModListPath -ForceDownload:$ForceDownload
    }
    Exit-ModManager 0
}

# Handle DownloadServer parameter
if ($DownloadServer) {
    Write-Host "Starting server files download process..." -ForegroundColor Yellow
    
    # Determine which version to download (same logic as mod downloads)
    $serverVersion = $null
    
    if ($TargetVersion) {
        # Explicit version specified
        $serverVersion = $TargetVersion
        Write-Host "📋 Downloading server files for version: $serverVersion (user specified)" -ForegroundColor Cyan
    } elseif ($GameVersion) {
        # GameVersion parameter
        $serverVersion = $GameVersion
        Write-Host "📋 Downloading server files for version: $serverVersion (user specified)" -ForegroundColor Cyan
    } elseif ($UseLatestVersion) {
        # Latest version from database
        $nextVersionResult = Calculate-NextGameVersion -CsvPath $effectiveModListPath
        $serverVersion = $nextVersionResult.LatestVersion
        Write-Host "📋 Downloading server files for LATEST version: $serverVersion" -ForegroundColor Cyan
    } elseif ($UseNextVersion) {
        # Next version (current + 1)
        $nextVersionResult = Calculate-NextGameVersion -CsvPath $effectiveModListPath
        $serverVersion = $nextVersionResult.NextVersion
        Write-Host "📋 Downloading server files for NEXT version: $serverVersion" -ForegroundColor Cyan
    } else {
        # Default: Current version (majority in database)
        $nextVersionResult = Calculate-NextGameVersion -CsvPath $effectiveModListPath
        $serverVersion = $nextVersionResult.MajorityVersion
        Write-Host "📋 Downloading server files for CURRENT version: $serverVersion (default)" -ForegroundColor Cyan
    }
    
    Download-ServerFiles -DownloadFolder $DownloadFolder -ForceDownload:$ForceDownload -GameVersion $serverVersion
    Exit-ModManager 0
}

# Handle ClearServer parameter
if ($ClearServer) {
    Write-Host "Clearing server files..." -ForegroundColor Yellow
    
    # Determine which version to clear
    $versionToClear = $null
    
    if ($TargetVersion) {
        $versionToClear = $TargetVersion
    } elseif ($GameVersion) {
        $versionToClear = $GameVersion
    } elseif ($UseLatestVersion) {
        $versionToClear = Get-LatestVersion -CsvPath $effectiveModListPath
    } elseif ($UseNextVersion) {
        $versionToClear = Get-NextVersion -CsvPath $effectiveModListPath
    } else {
        $versionToClear = Get-CurrentVersion -CsvPath $effectiveModListPath
    }
    
    if (-not $versionToClear) {
        Write-Host "❌ Failed to determine version to clear" -ForegroundColor Red
        Exit-ModManager 1
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
    Download-Mods -CsvPath $effectiveModListPath -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder -SkipServerFiles -TargetGameVersion $currentGameVersion
    
    # Download server files ONLY for target game version
    Write-Host ""
    Write-Host "Downloading server files for $currentGameVersion only..." -ForegroundColor Yellow
    Download-ServerFiles -DownloadFolder $DownloadFolder -ForceDownload:$false -GameVersion $currentGameVersion
    
    Write-Host ""
    Write-Host "✅ Server cleared and mods downloaded successfully!" -ForegroundColor Green
    Write-Host "💡 Run -StartServer to start the server" -ForegroundColor Cyan
    Exit-ModManager 0
}

# Handle StartServer parameter
if ($StartServer) {
    Write-Host "Starting Minecraft server..." -ForegroundColor Yellow
    
    # Determine target version (use parameter if provided, otherwise use current version as default)
    Write-Host "🔍 Determining target game version..." -ForegroundColor Cyan
    
    if ($TargetVersion) {
        $targetVersion = $TargetVersion
        Write-Host "🎯 Target version: $targetVersion (user specified via TargetVersion)" -ForegroundColor Green
    } elseif ($GameVersion) {
        $targetVersion = $GameVersion
        Write-Host "🎯 Target version: $targetVersion (user specified via GameVersion)" -ForegroundColor Green
    } elseif ($UseLatestVersion) {
        # Use latest version to test compatibility with newest Minecraft
        $targetVersion = Get-LatestVersion -CsvPath $effectiveModListPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine latest game version" -ForegroundColor Red
            Exit-ModManager 1
        }
        Write-Host "🎯 Target version: $targetVersion (LATEST version)" -ForegroundColor Green
    } elseif ($UseNextVersion) {
        # Use next version to test if newer versions will work
        $targetVersion = Get-NextVersion -CsvPath $effectiveModListPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine next game version" -ForegroundColor Red
            Exit-ModManager 1
        }
        Write-Host "🎯 Target version: $targetVersion (NEXT version)" -ForegroundColor Green
    } elseif ($UseCurrentVersion) {
        # Use current version (majority version from modlist)
        $targetVersion = Get-CurrentVersion -CsvPath $effectiveModListPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine current game version" -ForegroundColor Red
            Exit-ModManager 1
        }
        Write-Host "🎯 Target version: $targetVersion (CURRENT version)" -ForegroundColor Green
    } else {
        # Default: Use current version (majority version from modlist)
        $targetVersion = Get-CurrentVersion -CsvPath $effectiveModListPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine current game version" -ForegroundColor Red
            Exit-ModManager 1
        }
        Write-Host "🎯 Target version: $targetVersion (CURRENT version - default)" -ForegroundColor Green
        Write-Host "   💡 Use -UseNextVersion to test with next Minecraft version" -ForegroundColor Gray
    }
    
    # Check if target version folder exists and has files
    $targetFolder = Join-Path $DownloadFolder $targetVersion
    $needsDownload = $false
    
    if (-not (Test-Path $targetFolder)) {
        $needsDownload = $true
        Write-Host "⚠️  Target version folder $targetVersion not found. Need to download mods and server files." -ForegroundColor Yellow
    } else {
        # Check if the target version folder has server files
        $fabricJars = Get-ChildItem -Path $targetFolder -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue
        if ($fabricJars.Count -eq 0) {
            $needsDownload = $true
            Write-Host "⚠️  No Fabric server JAR found in $targetVersion. Need to download server files." -ForegroundColor Yellow
        }
        
        # Check if mods folder exists and has mods for proper testing
        $modsFolder = Join-Path $targetFolder "mods"
        if (-not (Test-Path $modsFolder) -or (Get-ChildItem -Path $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue).Count -eq 0) {
            $needsDownload = $true
            Write-Host "⚠️  No mods found in $targetVersion/mods. Need to download mods for proper server testing." -ForegroundColor Yellow
        }
    }
    
    # Always ensure mods and server files are available (download to cache if not cached, then copy)
    Write-Host "📦 Ensuring mods and server files are available for $targetVersion..." -ForegroundColor Cyan
    Download-Mods -CsvPath $effectiveModListPath -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder -TargetGameVersion $targetVersion
    Write-Host "" -ForegroundColor White
    
    # Now start the server
    $serverParams = @{
        DownloadFolder = $DownloadFolder
        TargetVersion = $targetVersion
        CsvPath = $effectiveModListPath
    }
    if ($NoAutoRestart) {
        $serverParams.Add("NoAutoRestart", $true)
    }
    $serverResult = Start-MinecraftServer @serverParams
    if ($serverResult) {
        Write-Host "🎉 SERVER VALIDATION SUCCESSFUL!" -ForegroundColor Green
        Exit-ModManager 0
    } else {
        Write-Host "💥 SERVER VALIDATION FAILED!" -ForegroundColor Red
        Exit-ModManager 1
    }
}

# Handle AddServerStartScript parameter
if ($AddServerStartScript) {
    Write-Host "Adding server start script..." -ForegroundColor Yellow
    Add-ServerStartScript -DownloadFolder $DownloadFolder
    Exit-ModManager 0
}

# Handle SearchModName parameter
if ($SearchModName) {
    Write-Host "Searching for mods..." -ForegroundColor Yellow
    $searchResult = Search-ModrinthProjects -Query $SearchModName -Interactive
    
    if ($searchResult) {
        # User selected a project, now add it to database
        $projectUrl = "https://modrinth.com/$($searchResult.project_type)/$($searchResult.slug)"
        Write-Host "Adding selected mod to database..." -ForegroundColor Green
        Add-ModToDatabase -AddModUrl $projectUrl -AddModName $searchResult.title -AddModLoader $AddModLoader -AddModGameVersion $AddModGameVersion -AddModType $AddModType -AddModGroup $AddModGroup -AddModDescription $searchResult.description -AddModJar $AddModJar -AddModUrlDirect $AddModUrlDirect -AddModCategory $AddModCategory -ForceDownload:$ForceDownload -CsvPath $effectiveModListPath
    } else {
        Write-Host "No mod selected or search cancelled" -ForegroundColor Yellow
    }
    Exit-ModManager 0
}

# Handle AddMod parameters
if ($AddMod -or $AddModId -or $AddModUrl) {
    Write-Host "Adding new mod..." -ForegroundColor Yellow
    Add-ModToDatabase -AddModId $AddModId -AddModUrl $AddModUrl -AddModName $AddModName -AddModLoader $AddModLoader -AddModGameVersion $AddModGameVersion -AddModType $AddModType -AddModGroup $AddModGroup -AddModDescription $AddModDescription -AddModJar $AddModJar -AddModUrlDirect $AddModUrlDirect -AddModCategory $AddModCategory -ForceDownload:$ForceDownload -CsvPath $effectiveModListPath
    Exit-ModManager 0
}

# Handle ValidateAllModVersions parameter
if ($ValidateAllModVersions) {
    Write-Host "Starting mod validation process..." -ForegroundColor Yellow
    # Use cache by default unless -Online is specified
    $useCache = -not $Online
    if ($UseCachedResponses) { $useCache = $true }  # Explicit -UseCachedResponses overrides
    Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UseCachedResponses:$useCache | Out-Null
    Exit-ModManager 0
}

# Handle ValidateModVersion parameters
if ($ValidateModVersion -and $ModID -and $AddModVersion) {
    Write-Host "Validating specific mod version..." -ForegroundColor Yellow
    Validate-ModVersion -ModId $ModID -Version $AddModVersion -Loader $AddModLoader -ResponseFolder $ApiResponseFolder
    Exit-ModManager 0
}

# Handle GetModList parameter
if ($GetModList) {
    Write-Host "Loading mod list..." -ForegroundColor Yellow
    Get-ModList -CsvPath $effectiveModListPath
    Exit-ModManager 0
}

# Handle DeleteModID parameter
if ($DeleteModID) {
    Write-Host "Deleting mod..." -ForegroundColor Yellow
    Delete-ModFromDatabase -DeleteModID $DeleteModID -DeleteModType $DeleteModType -CsvPath $effectiveModListPath
    Exit-ModManager 0
}

# Handle SyncMinecraftVersions parameter
if ($SyncMinecraftVersions) {
    Write-Host "Syncing Minecraft versions from mc-versions-api.net..." -ForegroundColor Yellow
    Sync-MinecraftVersions -CsvPath $effectiveModListPath -Channel $MinecraftVersionChannel -MinVersion $MinecraftMinVersion -DryRun:$DryRun
    Exit-ModManager 0
}

# Handle SyncJDKVersions parameter
if ($SyncJDKVersions) {
    Write-Host "Syncing JDK versions from Adoptium API..." -ForegroundColor Yellow
    Sync-JDKVersions -CsvPath $effectiveModListPath -Versions $JDKVersions -Platforms $JDKPlatforms -DryRun:$DryRun
    Exit-ModManager 0
}

# Handle DownloadJDK parameter
if ($DownloadJDK) {
    Write-Host "Downloading JDK..." -ForegroundColor Yellow
    $jdkDownloadResult = Download-JDK -CsvPath $effectiveModListPath -DownloadFolder $DownloadFolder -Version $JDKVersion -Platform $JDKPlatform -ForceDownload:$ForceDownload
    if ($jdkDownloadResult) {
        Exit-ModManager 0
    } else {
        Exit-ModManager 1
    }
}

# Handle ShowHelp parameter
if ($ShowHelp) {
    Show-Help
    Exit-ModManager 0
}

# Default behavior when no parameters are provided
Write-Host "Minecraft Mod Manager" -ForegroundColor Magenta
Write-Host "====================" -ForegroundColor Magenta
Write-Host ""
Write-Host "No parameters provided. Running default validation and update..." -ForegroundColor Yellow
Write-Host ""

# Run the default behavior: validate and update mods
# Default: Use cache (only fetch data for missing entries)
# Use -Online to force fresh API calls for all mods
$useCache = -not $Online
if ($UseCachedResponses) { $useCache = $true }  # Explicit -UseCachedResponses overrides
Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UpdateModList -UseCachedResponses:$useCache | Out-Null

# Exit cleanly with transcript stop
Exit-ModManager 0
