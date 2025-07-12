# =============================================================================
# Help Display Module
# =============================================================================
# This module handles displaying help information for the ModManager.
# =============================================================================

<#
.SYNOPSIS
    Shows help information for the ModManager.

.DESCRIPTION
    Displays comprehensive help information including functions, usage examples,
    output format, CSV columns, and file locations.

.EXAMPLE
    Show-Help

.NOTES
    - Displays all available functions and their parameters
    - Shows usage examples for common operations
    - Explains output format and CSV structure
    - Lists all input/output files and their purposes
#>
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

# Function is available for dot-sourcing 