# =============================================================================
# Help Display Module
# =============================================================================
# This module handles displaying help information for the ModManager.
# =============================================================================

<#
.SYNOPSIS
    Shows help information.

.DESCRIPTION
    Displays comprehensive help information for the ModManager,
    including functions, usage examples, and file descriptions.

.EXAMPLE
    Show-Help

.NOTES
    - Displays all available functions and parameters
    - Shows usage examples and output formats
    - Describes CSV columns and file locations
#>
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
    Write-Host "  CACHING OPTIONS:" -ForegroundColor Cyan
    Write-Host "    Default: Uses cached API responses (only fetches data for missing entries)"
    Write-Host "    -Online: Forces fresh API calls for all mods (ignores cache)"
    Write-Host "    -UseCachedResponses: Explicitly use cached responses (overrides -Online)"
    Write-Host ""
    Write-Host "    Cache behavior:"
    Write-Host "      • Default (no flags): Smart caching - uses existing cache, only fetches missing data"
    Write-Host "      • -Online: Always fetch from API, update all cached responses"
    Write-Host "      • -UseCachedResponses: Use cache exclusively, skip API calls entirely"
    Write-Host ""
    Write-Host "  Download-Mods [-CsvPath <path>] [-UseLatestVersion] [-UseNextVersion] [-ForceDownload]" -ForegroundColor White
    Write-Host "    - Downloads mods to local download folder organized by GameVersion"
    Write-Host "    - Creates subfolders for each GameVersion (e.g., download/1.21.5/mods/)"
    Write-Host "    - Creates block subfolder for mods in 'block' group (e.g., download/1.21.5/mods/block/)"
    Write-Host "    - Creates shaderpacks subfolder for shaderpacks (e.g., download/1.21.5/shaderpacks/)"
    Write-Host "    - Uses CurrentVersionUrl by default, NextVersionUrl with -UseNextVersion, or LatestVersionUrl with -UseLatestVersion"
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
    Write-Host "  Sync-MinecraftVersions [-MinecraftMinVersion <version>] [-MinecraftVersionChannel <channel>] [-DryRun]" -ForegroundColor White
    Write-Host "    - Auto-discovers and adds new Minecraft versions from mc-versions-api.net"
    Write-Host "    - Default MinVersion: 1.21.5 (only adds versions >= this)"
    Write-Host "    - Default Channel: stable (excludes snapshots, pre-releases)"
    Write-Host "    - Adds both server and launcher entries to database"
    Write-Host "    - Use -DryRun to preview changes without modifying database"
    Write-Host ""
    Write-Host "    Example: .\ModManager.ps1 -SyncMinecraftVersions" -ForegroundColor Gray
    Write-Host "    Example: .\ModManager.ps1 -SyncMinecraftVersions -MinecraftMinVersion \"1.21.6\" -DryRun" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Rollover-Mods [-RolloverToVersion <version>] [-DryRun]" -ForegroundColor White
    Write-Host "    - Rolls over mods from Current to Next versions"
    Write-Host "    - Without -RolloverToVersion: Uses NextVersion data from database"
    Write-Host "    - With -RolloverToVersion: Updates all mods to specified game version"
    Write-Host "    - Use -DryRun to preview changes without modifying database"
    Write-Host "    - Creates backup before making changes"
    Write-Host ""
    Write-Host "    Example: .\ModManager.ps1 -RolloverMods -DryRun" -ForegroundColor Gray
    Write-Host "    Example: .\ModManager.ps1 -RolloverMods -RolloverToVersion \"1.21.9\"" -ForegroundColor Gray
    Write-Host ""
}

# Function is available for dot-sourcing 