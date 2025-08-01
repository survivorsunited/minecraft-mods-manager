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
    [switch]$UpdateMods,
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
    [string]$ModListFile,
    [string]$DatabaseFile,
    [string]$DownloadFolder,
    [string]$ApiResponseFolder,
    [switch]$UseCachedResponses,
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
    [int]$DiagnosticsLogLines
)

# Import all modular functions
. "$PSScriptRoot\src\Import-Modules.ps1"

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

# Handle UpdateMods parameter
if ($UpdateMods) {
    Write-Host "Starting mod update process..." -ForegroundColor Yellow
    Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UpdateModList | Out-Null
    Exit-ModManager 0
}

# Handle Download parameter
if ($Download) {
    Write-Host "Starting mod download process..." -ForegroundColor Yellow
    if ($UseLatestVersion) {
        Write-Host "Using latest versions for download..." -ForegroundColor Cyan
        Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UpdateModList | Out-Null
        Download-Mods -CsvPath $effectiveModListPath -UseLatestVersion -ForceDownload:$ForceDownload
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
        Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UpdateModList | Out-Null
        Download-Mods -CsvPath $effectiveModListPath -UseLatestVersion -ForceDownload:$ForceDownload
    } else {
        Write-Host "Using current versions for download..." -ForegroundColor Cyan
        Download-Mods -CsvPath $effectiveModListPath -ForceDownload:$ForceDownload
    }
    Exit-ModManager 0
}

# Handle DownloadServer parameter
if ($DownloadServer) {
    Write-Host "Starting server files download process..." -ForegroundColor Yellow
    Download-ServerFiles -DownloadFolder $DownloadFolder -ForceDownload:$ForceDownload
    Exit-ModManager 0
}

# Handle StartServer parameter
if ($StartServer) {
    Write-Host "Starting Minecraft server..." -ForegroundColor Yellow
    Start-MinecraftServer -DownloadFolder $DownloadFolder
    Exit-ModManager 0
}

# Handle AddServerStartScript parameter
if ($AddServerStartScript) {
    Write-Host "Adding server start script..." -ForegroundColor Yellow
    Add-ServerStartScript -DownloadFolder $DownloadFolder
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
    Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UseCachedResponses:$UseCachedResponses | Out-Null
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
Validate-AllModVersions -CsvPath $effectiveModListPath -ResponseFolder $ApiResponseFolder -UpdateModList | Out-Null

# Exit cleanly with transcript stop
Exit-ModManager 0
