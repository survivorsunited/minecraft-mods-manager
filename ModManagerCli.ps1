# ModManagerCli.ps1 - CLI entry point for Minecraft Mods Manager

# Dot-source the main script to load all functions
. "$PSScriptRoot/ModManager.ps1"

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
    [string]$DatabaseFile,
    [string]$ApiResponseFolder,
    [switch]$UseCachedResponses,
    [switch]$ValidateWithDownload,
    [switch]$DownloadCurseForgeModpack,
    [string]$CurseForgeModpackId,
    [string]$CurseForgeFileId,
    [string]$CurseForgeModpackName,
    [string]$CurseForgeGameVersion,
    [switch]$ValidateCurseForgeModpack,
    [string]$ImportModpack,
    [string]$ModpackType,
    [string]$ExportModpack,
    [string]$ExportType,
    [string]$ExportName,
    [string]$ExportAuthor,
    [string]$ValidateModpack,
    [string]$ValidateType,
    [bool]$ResolveConflicts,
    [switch]$Gui,
    [string]$ModListFile,
    [string]$DownloadFolder
)

# Set defaults if not provided
if (-not $ModListFile) { $ModListFile = "modlist.csv" }
if (-not $DownloadFolder) { $DownloadFolder = "download" }
if (-not $ModpackType) { $ModpackType = "auto" }
if (-not $ExportType) { $ExportType = "modrinth" }
if (-not $ExportName) { $ExportName = "Exported Modpack" }
if (-not $ExportAuthor) { $ExportAuthor = "ModManager" }
if (-not $ValidateType) { $ValidateType = "auto" }
if ($ResolveConflicts -eq $null) { $ResolveConflicts = $true }
if (-not $ApiResponseFolder) { $ApiResponseFolder = "apiresponse" }

# Call the CLI logic function from ModManager.ps1
Invoke-ModManagerCli @PSBoundParameters 