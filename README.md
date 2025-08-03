# Minecraft Mod Manager

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
- **Java 17+** for server testing (22+ for MC 1.21.6+)

## 🛠️ Installation

1. **Clone the repository**:
   ```powershell
   git clone https://github.com/yourusername/minecraft-mods-manager.git
   cd minecraft-mods-manager
   ```

2. **Initialize submodules**:
   ```powershell
   git submodule update --init --recursive
   ```

3. **Optional**: Create a `.env` file for configuration (server URLs already added):
   ```env
   # API Configuration
   MODRINTH_API_BASE_URL=https://api.modrinth.com/v2
   CURSEFORGE_API_BASE_URL=https://api.curseforge.com/v1
   CURSEFORGE_API_KEY=your_api_key_here
   
   # Server URLs
   MINECRAFT_SERVER_URL=https://piston-meta.mojang.com/mc/game/version_manifest_v2.json
   FABRIC_SERVER_URL=https://meta.fabricmc.net/v2/versions
   
   # Default settings
   DEFAULT_LOADER=fabric
   DEFAULT_GAME_VERSION=1.21.6
   DEFAULT_MOD_TYPE=mod
   
   # Server requirements
   JAVA_VERSION_MIN=17
   ```

## 📖 Quick Start

### Basic Usage

#### Check for mod updates (default behavior)

```powershell
.\ModManager.ps1
```

#### Validate all mods and update database

```powershell
.\ModManager.ps1 -ValidateAllModVersions
```

#### Download all mods

```powershell
.\ModManager.ps1 -Download
```

#### Download latest versions instead of current

```powershell
.\ModManager.ps1 -Download -UseLatestVersion
```

#### Quick server validation

```powershell
.\scripts\Validate-ServerMods.ps1 -ShowDetails
```

### Adding Mods

#### Quick add with Modrinth URL (recommended)
```powershell
.\ModManager.ps1 -AddModId "https://modrinth.com/mod/fabric-api"
.\ModManager.ps1 -AddModId "https://modrinth.com/shader/complementary-reimagined"
```

#### Manual add with details

```powershell
.\ModManager.ps1 -AddMod -AddModId "sodium" -AddModName "Sodium" -AddModLoader "fabric"
```

### Server Management

#### Download server files

```powershell
.\ModManager.ps1 -DownloadServer
```
#### Download server files for specific version

```powershell
.\ModManager.ps1 -DownloadServer -GameVersion "1.21.7"
```

#### Add Minecraft server to database (uses MINECRAFT_SERVER_URL from .env)

```powershell
.\ModManager.ps1 -AddMod -AddModId "minecraft-server-1.21.7" -AddModName "Minecraft Server" -AddModType "server" -AddModGameVersion "1.21.7" -Group "required"
```

#### Add Fabric server to database (uses FABRIC_SERVER_URL from .env)

```powershell
.\ModManager.ps1 -AddMod -AddModId "fabric-server-launcher-1.21.7" -AddModName "Fabric Server" -AddModType "launcher" -AddModGameVersion "1.21.7" -AddModLoader "fabric" -Group "required"
```

#### Validate server compatibility

```powershell
.\scripts\Validate-ServerMods.ps1
```

#### Full server validation test

```powershell
.\test\tests\68-TestServerValidation.ps1
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

### Quick Test Commands

```powershell
# Run all tests
.\test\RunAllTests.ps1 -All

# Run critical server compatibility test
.\test\tests\12-TestLatestWithServer.ps1

# Test CurseForge functionality
.\test\tests\67-TestCurseForgeFunctionality.ps1

# Quick server mod validation (fast)
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

## 📋 Complete Parameter Reference

### Core Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Download` | Download all mods | `.\ModManager.ps1 -Download` |
| `-UseLatestVersion` | Use latest versions | `.\ModManager.ps1 -Download -UseLatestVersion` |
| `-ValidateAllModVersions` | Validate all mods | `.\ModManager.ps1 -ValidateAllModVersions` |
| `-DownloadServer` | Download server files | `.\ModManager.ps1 -DownloadServer` |
| `-StartServer` | Start Minecraft server | `.\ModManager.ps1 -StartServer` |

### Mod Management

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-AddModId` | Add mod by ID or URL | `.\ModManager.ps1 -AddModId "fabric-api"` |
| `-AddMod` | Add mod with details | `.\ModManager.ps1 -AddMod -AddModId "sodium"` |
| `-DeleteModID` | Remove mod | `.\ModManager.ps1 -DeleteModID "fabric-api"` |
| `-SearchModName` | Search for mods | `.\ModManager.ps1 -SearchModName "optimization"` |

### Configuration

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-DatabaseFile` | Custom database file | `.\ModManager.ps1 -DatabaseFile "my-mods.csv"` |
| `-DownloadFolder` | Custom download folder | `.\ModManager.ps1 -Download -DownloadFolder "test"` |
| `-UseCachedResponses` | Use cached API responses | `.\ModManager.ps1 -ValidateAllModVersions -UseCachedResponses` |

## 📊 CSV Database Format

The `modlist.csv` file contains these key columns:

| Column | Description |
|--------|-------------|
| `Group` | Mod category (required, optional, admin, block) |
| `Type` | Mod type (mod, datapack, shaderpack, installer, server) |
| `GameVersion` | Target Minecraft version |
| `ID` | Mod ID (Modrinth slug or CurseForge ID) |
| `Loader` | Mod loader (fabric, forge, iris, etc.) |
| `Version` | Expected mod version |
| `Name` | Mod display name |
| `ServerSide` | Server compatibility (required, optional, unsupported) |
| `ClientSide` | Client compatibility (required, optional, unsupported) |

## 🔧 Helper Scripts

Located in the `scripts/` folder for common workflows:

```powershell
# Server mod validation (fast)
.\scripts\Validate-ServerMods.ps1 -ShowDetails

# Test latest mod versions with server
.\scripts\TestLatestMods.ps1

# Download latest versions
.\scripts\DownloadLatestMods.ps1

# Download current versions
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