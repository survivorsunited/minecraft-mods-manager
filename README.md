# Minecraft Mod Manager

[![Daily Mod Update and Release Pipeline](https://github.com/survivorsunited/minecraft-mods-manager/actions/workflows/daily-mod-update.yml/badge.svg)](https://github.com/survivorsunited/minecraft-mods-manager/actions/workflows/daily-mod-update.yml)

A powerful PowerShell script for managing Minecraft mods across multiple platforms (Modrinth and CurseForge) with automatic version validation, download management, and server compatibility testing.

## 🚀 Features

### Core Functionality
- **Multi-Platform Support**: Works with both Modrinth and CurseForge APIs
- **Automatic Version Validation**: Checks if mod versions exist and finds latest versions
- **Smart Download Management**: Downloads mods organized by game version
- **Comprehensive Reporting**: Generates detailed README files with analysis and mod lists
- **Easy Mod Addition**: Add new mods with minimal information and auto-resolve details
- **Server Compatibility**: Validate and test mods for server deployment

### Advanced Features
- **Icon URL Extraction**: Automatically fetches mod icons and metadata
- **Project Information**: Retrieves detailed mod information (description, links, etc.)
- **Latest Game Version Detection**: Uses the highest supported game version from API responses
- **CurseForge Direct API Downloads**: Uses direct API endpoints for reliable downloads
- **Shaderpack Support**: Download shaderpacks with iris loader support
- **Server Downloads**: Download Minecraft server JARs and Fabric launchers
- **Installer Support**: Download installers to dedicated folders

## 📋 Requirements

- **PowerShell 5.1+** (Windows, Linux, macOS)
- **Internet Connection** for API access
- **Optional**: CurseForge API key for enhanced access
- **Java 17+** for server testing (21+ for MC 1.21.8+)

## 🛠️ Installation

### Clone the repository
```powershell
git clone https://github.com/yourusername/minecraft-mods-manager.git
```

### Navigate to directory
```powershell
cd minecraft-mods-manager
```

### Initialize submodules
```powershell
git submodule update --init --recursive
```

### Create configuration file (optional)
Create a `.env` file for API keys and settings:
```env
# API Configuration
MODRINTH_API_BASE_URL=https://api.modrinth.com/v2
APIRESPONSE_MODRINTH_SUBFOLDER

CURSEFORGE_API_BASE_URL=https://api.curseforge.com/v1
CURSEFORGE_API_KEY=your_api_key_here
APIRESPONSE_CURSEFORGE_SUBFOLDER=curseforge

# Server URLs
MINECRAFT_SERVER_URL=https://piston-meta.mojang.com/mc/game/version_manifest_v2.json
FABRIC_SERVER_URL=https://meta.fabricmc.net/v2/versions

# Default settings
DEFAULT_LOADER=fabric
DEFAULT_GAME_VERSION=1.21.8
DEFAULT_MOD_TYPE=mod

# Server requirements
JAVA_VERSION_MIN=21

```

## 📖 Quick Start

### Check for mod updates
Runs validation and shows update summary for all mods
```powershell
.\ModManager.ps1
```

### Validate all mods and update database
Checks all mod versions against APIs and updates database with latest information
```powershell
.\ModManager.ps1 -ValidateAllModVersions
```

### Download all current mod versions
Downloads all mods using versions specified in database
```powershell
.\ModManager.ps1 -Download
```

### Download all latest mod versions
Downloads the latest available versions instead of database versions
```powershell
.\ModManager.ps1 -Download -UseLatestVersion
```

## 🔄 Progressive Version Testing Workflow

The mod manager supports a three-tier Current → Next → Latest progression for safe compatibility testing:

### Current Version Testing (Default)
Uses stable versions from database - safest for production
```powershell
# Download current stable versions
.\ModManager.ps1 -Download

# Start server with current versions
.\ModManager.ps1 -StartServer
```

### Next Version Testing (Incremental)
Tests the next logical version for progressive compatibility validation
```powershell
# Download next incremental versions (e.g., 1.21.6 if current is 1.21.5)
.\ModManager.ps1 -Download -UseNextVersion

# Start server with next versions
.\ModManager.ps1 -StartServer -UseNextVersion
```

### Latest Version Testing (Bleeding Edge)
Tests with the newest available versions - highest risk but latest features
```powershell
# Update database with latest version information
.\ModManager.ps1 -UpdateMods

# Download latest versions
.\ModManager.ps1 -Download -UseLatestVersion

# Start server with latest versions
.\ModManager.ps1 -StartServer -UseLatestVersion
```

### Complete Progressive Testing Sequence
For comprehensive testing, run all three phases:
```powershell
# Phase 1: Test current stable versions
.\ModManager.ps1 -Download
.\ModManager.ps1 -StartServer

# Phase 2: Test next incremental versions
.\ModManager.ps1 -Download -UseNextVersion -DownloadFolder "test-next"
.\ModManager.ps1 -StartServer -UseNextVersion -DownloadFolder "test-next"

# Phase 3: Test latest bleeding edge versions
.\ModManager.ps1 -UpdateMods
.\ModManager.ps1 -Download -UseLatestVersion -DownloadFolder "test-latest"
.\ModManager.ps1 -StartServer -UseLatestVersion -DownloadFolder "test-latest"
```

### Quick server validation check
Fast validation to check server compatibility without downloading
```powershell
.\scripts\Validate-ServerMods.ps1 -ShowDetails
```

## 🔧 Adding Items to Database

### Add mod by Modrinth URL (recommended)
Automatically detects mod type, version, and metadata from URL
```powershell
.\ModManager.ps1 -AddModId "https://modrinth.com/mod/fabric-api"
```

### Add shaderpack by Modrinth URL
Automatically configures for iris loader
```powershell
.\ModManager.ps1 -AddModId "https://modrinth.com/shader/complementary-reimagined"
```

### Add datapack by Modrinth URL
Automatically detects datapack type and loader-agnostic settings
```powershell
.\ModManager.ps1 -AddModId "https://modrinth.com/datapack/vanilla-tweaks"
```

### Add mod manually with required parameters
Specify mod details manually when URL detection isn't available
```powershell
.\ModManager.ps1 -AddMod -AddModId "sodium" -AddModName "Sodium" -AddModLoader "fabric" -AddModGameVersion "1.21.6"
```

### Add mod with full parameters
Complete specification including compatibility and grouping
```powershell
.\ModManager.ps1 -AddMod -AddModId "lithium" -AddModName "Lithium" -AddModLoader "fabric" -AddModGameVersion "1.21.6" -AddModGroup "required" -AddModType "mod" -AddModDescription "Server optimization mod"
```

### Add optional mod
Marks mod as optional (not required for server operation)
```powershell
.\ModManager.ps1 -AddMod -AddModId "journeymap" -AddModName "JourneyMap" -AddModLoader "fabric" -AddModGameVersion "1.21.6" -AddModGroup "optional"
```

### Add server-side only mod
Specifies mod works only on server (not client)
```powershell
.\ModManager.ps1 -AddMod -AddModId "anti-xray" -AddModName "Anti X-Ray" -AddModLoader "fabric" -AddModGameVersion "1.21.6" -AddModGroup "required" -AddModType "mod" -ServerSide "required" -ClientSide "unsupported"
```

### Add client-side only mod
Specifies mod works only on client (not server)
```powershell
.\ModManager.ps1 -AddMod -AddModId "sodium" -AddModName "Sodium" -AddModLoader "fabric" -AddModGameVersion "1.21.6" -AddModGroup "required" -AddModType "mod" -ServerSide "unsupported" -ClientSide "required"
```

## 🏗️ Server Management

### ✨ Automatic URL Resolution
The system now automatically resolves server download URLs for all Minecraft versions. When adding server entries with empty URLs, the download process will:
- **Minecraft Server**: Fetches the official server JAR URL from Mojang's version manifest
- **Fabric Launcher**: Builds the download URL using the latest loader and installer versions from Fabric Meta API

### Download server files for all versions in database
Downloads Minecraft server JARs and Fabric launchers for all versions found in database
```powershell
.\ModManager.ps1 -DownloadMods
```
*Note: Server files are now downloaded automatically with mods*

### Download server files for specific version
Downloads all files including server files for the specified Minecraft version
```powershell
.\ModManager.ps1 -DownloadMods -GameVersion "1.21.7"
```

### Add Minecraft server to database (auto-resolves URL)
Adds Minecraft server JAR download to database - URL will be auto-resolved during download
```powershell
.\ModManager.ps1 -AddMod -AddModId "minecraft-server-1.21.7" -AddModName "Minecraft Server" -AddModType "server" -AddModGameVersion "1.21.7" -AddModGroup "required"
```

### Add Fabric server launcher to database (auto-resolves URL)
Adds Fabric server launcher to database - URL will be auto-resolved during download
```powershell
.\ModManager.ps1 -AddMod -AddModId "fabric-server-launcher-1.21.7" -AddModName "Fabric Server" -AddModType "launcher" -AddModGameVersion "1.21.7" -AddModLoader "fabric" -AddModGroup "required"
```

### Add Fabric installer to database
Adds Fabric installer for client installation to database
```powershell
.\ModManager.ps1 -AddMod -AddModId "fabric-installer-1.21.7" -AddModName "Fabric Installer" -AddModType "installer" -AddModGameVersion "1.21.7" -AddModLoader "fabric" -AddModGroup "optional"
```

### Start Minecraft server (CI/CD Pipeline Ready) 🚀
Starts the Minecraft server for validation testing - perfect for CI/CD pipelines
```powershell
.\ModManager.ps1 -StartServer
```

**Server Startup Features:**
- **Automatic Download**: Downloads server files if not present
- **Two-Stage Initialization**: Handles first-run setup automatically
- **EULA Acceptance**: Automatically accepts EULA for testing
- **Offline Mode**: Sets server to offline mode for CI/CD environments
- **Full Validation**: Waits for server to fully load, validates success, then stops
- **Exit Codes**: Returns 0 for success, 1 for failure (pipeline-ready)

### Clear server files for fresh start
Removes server configuration and world files while keeping JARs
```powershell
.\ModManager.ps1 -ClearServer
```

### Configure server memory settings
Customize memory allocation for better server performance
```bash
# Set in .env file or as environment variables
MINECRAFT_MIN_MEMORY=2G
MINECRAFT_MAX_MEMORY=8G
```

### Pipeline Integration Example
Perfect for automated testing in CI/CD pipelines:
```bash
# Download all files (auto-resolves server URLs)
./ModManager.ps1 -DownloadMods

# Validate server startup (returns proper exit codes)
./ModManager.ps1 -StartServer
if [ $? -eq 0 ]; then
    echo "Server validation passed!"
else
    echo "Server validation failed!"
    exit 1
fi
```

### Validate server compatibility
Checks which mods are compatible with server deployment
```powershell
.\scripts\Validate-ServerMods.ps1
```

### Test all server versions
Comprehensive test for all Minecraft versions (1.21.5, 1.21.6, 1.21.7, 1.21.8)
```powershell
.\test\test-all-versions.ps1
```

## 🔍 Mod Management

### Search for mods by name
Interactive search with selection menu
```powershell
.\ModManager.ps1 -SearchModName "optimization"
```

### Remove mod from database
Deletes mod entry from database by ID
```powershell
.\ModManager.ps1 -DeleteModID "fabric-api"
```

### Use custom database file
Specify alternative database file for operations
```powershell
.\ModManager.ps1 -DatabaseFile "my-mods.csv"
```

### Use custom download folder
Specify alternative download location
```powershell
.\ModManager.ps1 -Download -DownloadFolder "test"
```

### Use cached API responses
Speed up validation by using previously cached API responses
```powershell
.\ModManager.ps1 -ValidateAllModVersions -UseCachedResponses
```

## 📋 Complete Parameter Reference

### Core Action Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-Download` | Switch | Download all mods from database | `.\ModManager.ps1 -Download` |
| `-UseLatestVersion` | Switch | Use latest versions instead of database versions | `.\ModManager.ps1 -Download -UseLatestVersion` |
| `-ValidateAllModVersions` | Switch | Validate all mods and update database | `.\ModManager.ps1 -ValidateAllModVersions` |
| `-RolloverMods` | Switch | Rollover mods to next/specified version | `.\ModManager.ps1 -RolloverMods -DryRun` |
| `-RolloverToVersion` | String | Target version for rollover | `.\ModManager.ps1 -RolloverMods -RolloverToVersion "1.21.9"` |
| `-DryRun` | Switch | Preview changes without modifying database | `.\ModManager.ps1 -RolloverMods -DryRun` |
| `-DownloadServer` | Switch | Download server files from database | `.\ModManager.ps1 -DownloadServer` |
| `-StartServer` | Switch | Start Minecraft server with downloaded files | `.\ModManager.ps1 -StartServer` |
| `-ClearServer` | Switch | Clear server files for fresh restart | `.\ModManager.ps1 -ClearServer` |
| `-AddMod` | Switch | Add new mod to database | `.\ModManager.ps1 -AddMod -AddModId "sodium"` |
| `-SearchModName` | String | Search for mods interactively | `.\ModManager.ps1 -SearchModName "optimization"` |
| `-DeleteModID` | String | Remove mod from database by ID | `.\ModManager.ps1 -DeleteModID "fabric-api"` |

### Mod Addition Parameters

| Parameter | Type | Default | Description | Values |
|-----------|------|---------|-------------|---------|
| `-AddModId` | String | - | **Required**: Mod ID or slug | `"fabric-api"`, `"sodium"` |
| `-AddModUrl` | String | - | Alternative to ID: Full mod URL | `"https://modrinth.com/mod/fabric-api"` |
| `-AddModName` | String | - | **Required**: Display name for mod | `"Fabric API"`, `"Sodium"` |
| `-AddModGameVersion` | String | "1.21.5" | Target Minecraft version | `"1.21.6"`, `"1.21.7"` |
| `-AddModLoader` | String | "fabric" | Mod loader system | `fabric`, `forge`, `iris`, `vanilla` |
| `-AddModGroup` | String | "required" | Mod importance category | `required`, `optional`, `admin`, `block` |
| `-AddModType` | String | "mod" | Item type | `mod`, `datapack`, `shaderpack`, `installer`, `server`, `launcher` |
| `-AddModVersion` | String | "latest" | Specific mod version | `"latest"`, `"1.0.0"`, `"v2.1.3"` |
| `-AddModDescription` | String | "" | Mod description text | `"Performance optimization mod"` |
| `-AddModCategory` | String | "" | Mod category | `"Optimization"`, `"Utility"` |
| `-AddModJar` | String | "" | Specific JAR filename | `"sodium-fabric-1.0.jar"` |
| `-AddModUrlDirect` | String | "" | Direct download URL | `"https://cdn.modrinth.com/..."` |

### Server/Client Compatibility Parameters

| Parameter | Type | Default | Description | Values |
|-----------|------|---------|-------------|---------|
| `-ServerSide` | String | "optional" | Server compatibility | `required`, `optional`, `unsupported` |
| `-ClientSide` | String | "optional" | Client compatibility | `required`, `optional`, `unsupported` |

### Configuration Parameters

| Parameter | Type | Default | Description | Example |
|-----------|------|---------|-------------|---------|
| `-DatabaseFile` | String | "modlist.csv" | Custom database file path | `.\ModManager.ps1 -DatabaseFile "my-mods.csv"` |
| `-DownloadFolder` | String | "download" | Custom download directory | `.\ModManager.ps1 -Download -DownloadFolder "test"` |
| `-ApiResponseFolder` | String | "apiresponse" | API response cache folder | `.\ModManager.ps1 -ApiResponseFolder "cache"` |
| `-UseCachedResponses` | Switch | false | Use cached API responses | `.\ModManager.ps1 -ValidateAllModVersions -UseCachedResponses` |
| `-ForceDownload` | Switch | false | Force re-download existing files | `.\ModManager.ps1 -Download -ForceDownload` |

### Environment Variables

Configure server behavior through environment variables in your `.env` file:

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `MINECRAFT_MIN_MEMORY` | "1G" | Minimum memory allocation for server | `MINECRAFT_MIN_MEMORY=2G` |
| `MINECRAFT_MAX_MEMORY` | "4G" | Maximum memory allocation for server | `MINECRAFT_MAX_MEMORY=8G` |
| `JAVA_VERSION_MIN` | "21" | Minimum required Java version | `JAVA_VERSION_MIN=21` |
| `CURSEFORGE_API_KEY` | - | CurseForge API key for enhanced access | `CURSEFORGE_API_KEY=your_key_here` |
| `DEFAULT_LOADER` | "fabric" | Default mod loader | `DEFAULT_LOADER=forge` |
| `DEFAULT_GAME_VERSION` | "1.21.8" | Default Minecraft version | `DEFAULT_GAME_VERSION=1.21.8` |

### Advanced Server Management Parameters

| Parameter | Type | Default | Description | Example |
|-----------|------|---------|-------------|---------|
| `-MonitorServerPerformance` | Switch | false | Monitor server performance | `.\ModManager.ps1 -MonitorServerPerformance` |
| `-PerformanceSampleInterval` | Int | 5 | Performance sampling interval (seconds) | `.\ModManager.ps1 -MonitorServerPerformance -PerformanceSampleInterval 10` |
| `-PerformanceSampleCount` | Int | 12 | Number of performance samples | `.\ModManager.ps1 -MonitorServerPerformance -PerformanceSampleCount 20` |
| `-CreateServerBackup` | Switch | false | Create server backup | `.\ModManager.ps1 -CreateServerBackup` |
| `-BackupPath` | String | "backups" | Backup directory path | `.\ModManager.ps1 -CreateServerBackup -BackupPath "my-backups"` |
| `-BackupName` | String | auto | Custom backup name | `.\ModManager.ps1 -CreateServerBackup -BackupName "pre-update"` |
| `-RestoreServerBackup` | String | - | Restore from backup name | `.\ModManager.ps1 -RestoreServerBackup "pre-update"` |
| `-RunServerHealthCheck` | Switch | false | Run server health diagnostics | `.\ModManager.ps1 -RunServerHealthCheck` |
| `-HealthCheckTimeout` | Int | 30 | Health check timeout (seconds) | `.\ModManager.ps1 -RunServerHealthCheck -HealthCheckTimeout 60` |

### CurseForge Modpack Parameters

| Parameter | Type | Default | Description | Example |
|-----------|------|---------|-------------|---------|
| `-DownloadCurseForgeModpack` | Switch | false | Download CurseForge modpack | `.\ModManager.ps1 -DownloadCurseForgeModpack` |
| `-CurseForgeModpackId` | String | - | CurseForge modpack project ID | `.\ModManager.ps1 -DownloadCurseForgeModpack -CurseForgeModpackId "123456"` |
| `-CurseForgeFileId` | String | - | Specific modpack file ID | `.\ModManager.ps1 -DownloadCurseForgeModpack -CurseForgeFileId "789012"` |
| `-CurseForgeModpackName` | String | - | Custom modpack name | `.\ModManager.ps1 -DownloadCurseForgeModpack -CurseForgeModpackName "MyPack"` |

### Cross-Platform Modpack Parameters

| Parameter | Type | Default | Description | Example |
|-----------|------|---------|-------------|---------|
| `-ImportModpack` | String | - | Import modpack file path | `.\ModManager.ps1 -ImportModpack "pack.mrpack"` |
| `-ModpackType` | String | "auto" | Modpack format type | `.\ModManager.ps1 -ImportModpack "pack.zip" -ModpackType "curseforge"` |
| `-ExportModpack` | String | - | Export modpack file path | `.\ModManager.ps1 -ExportModpack "my-pack.mrpack"` |
| `-ExportType` | String | "modrinth" | Export format type | `.\ModManager.ps1 -ExportModpack "pack.zip" -ExportType "curseforge"` |
| `-ExportName` | String | "Exported Modpack" | Modpack display name | `.\ModManager.ps1 -ExportModpack "pack.mrpack" -ExportName "My Custom Pack"` |
| `-ExportAuthor` | String | "ModManager" | Modpack author name | `.\ModManager.ps1 -ExportModpack "pack.mrpack" -ExportAuthor "PlayerName"` |

### Database Entry Requirements

When adding items manually, these parameters are required or have important defaults:

#### Required Parameters
- **AddModId** or **AddModUrl**: Unique identifier or source URL
- **AddModName**: Display name for the item  
- **AddModGameVersion**: Target Minecraft version (default: "1.21.5")

#### Group Types
- `required` - Essential for modpack operation
- `optional` - Nice to have but not required
- `admin` - Administrative/utility mods
- `block` - Disabled/blocked items

#### Type Options
- `mod` - Standard Minecraft mod
- `datapack` - Data pack file
- `shaderpack` - Shader pack for graphics
- `installer` - Installation tool
- `server` - Server JAR file
- `launcher` - Server launcher tool

#### Loader Options
- `fabric` - Fabric mod loader
- `forge` - Forge mod loader  
- `iris` - Iris shader loader
- `vanilla` - No mod loader required

#### Compatibility Values
- `required` - Must be present
- `optional` - Can be present
- `unsupported` - Cannot be present

### Complete Example with All Parameters
```powershell
.\ModManager.ps1 -AddMod -AddModId "example-mod" -AddModName "Example Mod" -AddModGameVersion "1.21.6" -AddModLoader "fabric" -AddModGroup "required" -AddModType "mod" -AddModVersion "latest" -AddModDescription "Example description" -AddModCategory "Utility" -ServerSide "required" -ClientSide "required"
```

## 📊 Update Summary

The default `.\ModManager.ps1` command shows a comprehensive update summary:

```
📊 Update Summary:
=================
   🕹️  Latest Game Version: 1.21.6
   🎯 Supporting latest version: 45 mods
   ⬆️  Have updates available: 15 mods
   ⚠️  Not supporting latest version: 5 mods
   ❌ Errors: 0 mods
```

**Key Features:**
- **Latest Game Version**: Calculated from your modlist
- **Update Detection**: Identifies mods with available updates
- **Compatibility Check**: Shows which mods support newer game versions
- **Error Tracking**: Reports validation issues

## 📁 File Structure

```
minecraft-mods-manager/
├── ModManager.ps1              # Main script
├── modlist.csv                 # Mod database
├── .env                        # Configuration (optional)
├── src/                        # Modular source code
├── scripts/                    # Helper scripts
├── download/                   # Downloaded mods (auto-created)
│   └── 1.21.6/
│       ├── mods/              # Downloaded mod JARs
│       ├── shaderpacks/       # Shaderpack files
│       └── server files       # Minecraft + Fabric server
├── apiresponse/               # API response cache
│   ├── modrinth/             # Modrinth API responses
│   └── curseforge/           # CurseForge API responses
├── test/                      # Testing framework
├── docs/                      # Documentation
└── tools/                     # Additional tools
```

## 🧪 Testing

### Run all tests
Executes complete test suite for all functionality
```powershell
.\test\RunAllTests.ps1 -All
```

### Run critical server compatibility test
Tests server mod compatibility and deployment
```powershell
.\test\tests\12-TestLatestWithServer.ps1
```

### Test CurseForge functionality
Validates CurseForge API integration and authentication
```powershell
.\test\tests\67-TestCurseForgeFunctionality.ps1
```

### Quick server mod validation (fast)
Fast server compatibility check without downloads
```powershell
.\scripts\Validate-ServerMods.ps1 -ShowDetails
```

### Server Validation Results

The server validation script provides instant feedback:

```
📊 Validation Results:
=====================
  Server-compatible mods: 1
  Client-only mods: 0
  Unknown compatibility: 67
  Total issues found: 138

🔍 Server may work but needs verification
   67 mods have unknown server compatibility
   Server readiness: 1.5%
```

**For detailed testing documentation, see [test/README.md](test/README.md)**

## 📋 CSV Database Format

The `modlist.csv` file contains these key columns:

| Column | Description | Values |
|--------|-------------|---------|
| `Group` | Mod category | required, optional, admin, block |
| `Type` | Mod type | mod, datapack, shaderpack, installer, server, launcher |
| `GameVersion` | Target Minecraft version | 1.21.6, 1.21.7, etc. |
| `ID` | Mod ID | Modrinth slug or CurseForge ID |
| `Loader` | Mod loader | fabric, forge, iris, vanilla |
| `Version` | Expected mod version | latest, specific version |
| `Name` | Mod display name | Human-readable name |
| `ServerSide` | Server compatibility | required, optional, unsupported |
| `ClientSide` | Client compatibility | required, optional, unsupported |

## 🔧 Helper Scripts

### Server mod validation (fast)
Quick server compatibility check

```powershell
.\scripts\Validate-ServerMods.ps1 -ShowDetails
```

### Build release from cached downloads

Package an already-downloaded version (no network) into a timestamped release folder with verification.
 
```powershell
.# Strict (default): fail on any difference vs CSV
./scripts/Build-ReleaseFromCache.ps1 -Version 1.21.8

.# Warn only: report diffs but continue building artifacts
./scripts/Build-ReleaseFromCache.ps1 -Version 1.21.8 -VerificationMode warn

.# Relaxed version: ignore version-only differences for mods (treat older/newer JAR names as matched by base)
./scripts/Build-ReleaseFromCache.ps1 -Version 1.21.8 -VerificationMode relaxed-version
```

Artifacts are written under `releases/<version>/<timestamp>/`. When verification finds differences, details are saved to:

- `verification-missing.txt` – expected but not found
- `verification-extra.txt` – present but not expected

### Reconcile CSV vs cache (report)

Generate a report comparing what the CSV expects vs what’s in `download/<version>`.

```powershell
./scripts/Reconcile-ExpectedVsCache.ps1 -Version 1.21.8                      # exact comparison
./scripts/Reconcile-ExpectedVsCache.ps1 -Version 1.21.8 -Mode relaxed-version # pair version-only differences for mods
```

Outputs are written to `releases/<version>/reconcile-<timestamp>/`:

- `reconciliation-report.txt` – human-readable summary
- `expected.txt` / `actual.txt` – raw lists
- `missing.txt` / `extra.txt` – diffs for automation


### Test latest mod versions with server

Validates latest versions for server compatibility

```powershell
.\scripts\TestLatestMods.ps1
```

### Download latest versions

Downloads newest available versions of all mods

```powershell
.\scripts\DownloadLatestMods.ps1
```

### Download current versions

Downloads currently specified versions from database

```powershell
.\scripts\DownloadCurrentMods.ps1
```

## 🔍 API Documentation

Complete API reference with CURL and PowerShell examples:
**[docs/API_REFERENCE.md](docs/API_REFERENCE.md)**

Includes all endpoints for:

- Modrinth API
- CurseForge API  
- Fabric Meta API
- Mojang API

## 🛡️ Error Handling

- **Graceful API Failures**: Continues processing if individual mods fail
- **Automatic Retries**: Handles temporary network issues
- **Detailed Error Reporting**: Shows specific failure reasons
- **Backup Protection**: Creates backups before making changes

## 🔄 Workflow

### Typical Usage

1. **Prepare `modlist.csv`** with your installed mods
2. **Run validation**: `.\ModManager.ps1` (check for updates)
3. **Review Update Summary**
4. **Download updates**: `.\ModManager.ps1 -Download -UseLatestVersion`
5. **Validate server compatibility**: `.\scripts\Validate-ServerMods.ps1`
6. **Apply updates** to your Minecraft installation

### Server Deployment

1. **Validate mods**: `.\scripts\Validate-ServerMods.ps1 -ShowDetails`
2. **Download server files**: `.\ModManager.ps1 -DownloadServer`
3. **Download mods**: `.\ModManager.ps1 -DownloadMods`
4. **Test server startup**: `.\test\tests\68-TestServerValidation.ps1`
5. **Deploy to production**

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `.\test\RunAllTests.ps1 -All`
5. Submit a pull request

### Testing Requirements

- All tests must pass on Windows, Linux, and macOS
- New features require corresponding tests
- Use test isolation to prevent interference
- See [test/README.md](test/README.md) for detailed testing guidelines

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📚 Documentation

- **[Test Documentation](test/README.md)** - Comprehensive testing guide
- **[API Reference](docs/API_REFERENCE.md)** - Complete API documentation
- **[Use Cases](docs/)** - Specific workflow examples
- **[Scripts Reference](scripts/)** - Helper script documentation
