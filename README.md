# Minecraft Mod Manager

A powerful PowerShell script for managing Minecraft mods across multiple platforms (Modrinth and CurseForge) with automatic version validation, download management, comprehensive testing, and compatibility error reporting.

## 🚀 Features

### Core Functionality
- **Multi-Platform Support**: Works with both Modrinth and CurseForge APIs
- **Automatic Version Validation**: Checks if mod versions exist and finds latest versions
- **Smart Download Management**: Downloads mods organized by game version
- **Majority Version Targeting**: Automatically determines the most compatible game version
- **Comprehensive Reporting**: Generates detailed README files with analysis and mod lists
- **Easy Mod Addition**: Add new mods with minimal information and auto-resolve details
- **Organized API Responses**: API responses are organized by domain in subfolders for better management

### Advanced Features
- **Icon URL Extraction**: Automatically fetches mod icons and metadata
- **Project Information**: Retrieves detailed mod information (description, links, etc.)
- **Latest Game Version Detection**: Uses the highest supported game version from API responses
- **JAR Filename Matching**: Fallback matching when version strings don't match exactly
- **CurseForge Direct API Downloads**: Uses direct API endpoints for reliable downloads
- **Git Integration**: Includes minecraft-mod-hash tool as a submodule for mod validation
- **Shaderpack Support**: Download shaderpacks with iris loader support
- **Server Downloads**: Download Minecraft server JARs and Fabric launchers
- **Installer Support**: Download installers (including predefined Fabric installer) to dedicated folders

### Testing & Quality Assurance
- **Comprehensive Test Suite**: Full test coverage with 12+ test files
- **Mod Compatibility Testing**: Automated detection of mod compatibility issues
- **Server Startup Validation**: Tests server startup with downloaded mods
- **Isolated Test Environment**: Each test runs in isolated directories
- **API Response Caching**: Faster testing with cached API responses
- **CI/CD Pipeline**: Automated testing across Windows/Linux/macOS
- **Compatibility Error Reporting**: Detailed reporting of mod conflicts and issues

## 📋 Requirements

- **PowerShell 5.1+** (Windows 10/11)
- **Internet Connection** for API access
- **Optional**: CurseForge API key for enhanced access

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

3. **Optional**: Create a `.env` file for API keys and configuration:
   ```env
   # API Configuration
   MODRINTH_API_BASE_URL=https://api.modrinth.com/v2
   CURSEFORGE_API_BASE_URL=https://www.curseforge.com/api/v1
   CURSEFORGE_API_KEY=your_api_key_here
   
   # API Response Subfolder Configuration
   APIRESPONSE_MODRINTH_SUBFOLDER=modrinth
   APIRESPONSE_CURSEFORGE_SUBFOLDER=curseforge
   
   # Default settings
   DEFAULT_LOADER=fabric
   DEFAULT_GAME_VERSION=1.21.5
   DEFAULT_MOD_TYPE=mod
   ```

## 🧪 Testing

### Quick Test Commands

```powershell
# Run all tests
.\test\RunAllTests.ps1 -All

# Run specific test
.\test\RunAllTests.ps1 -TestFiles "12-TestLatestWithServer.ps1"

# Run multiple specific tests
.\test\RunAllTests.ps1 -TestFiles "01-BasicFunctionality.ps1","02-DownloadFunctionality.ps1"

# Test API response organization
.\test\RunAllTests.ps1 -TestFiles "13-TestApiResponseOrganization.ps1"
```

### Test Coverage

The project includes comprehensive testing with the following test files:

- **01-BasicFunctionality.ps1** - Core functionality validation
- **02-DownloadFunctionality.ps1** - Download system testing
- **03-SystemEntries.ps1** - System mod validation
- **04-FilenameHandling.ps1** - File naming and organization
- **05-ValidationTests.ps1** - Mod validation workflows
- **06-ModpackTests.ps1** - Modpack functionality
- **07-StartServerTests.ps1** - Server startup testing
- **08-StartServerUnitTests.ps1** - Server unit tests
- **09-TestCurrent.ps1** - Current mod version workflows
- **10-TestLatest.ps1** - Latest mod version workflows
- **11-ParameterValidation.ps1** - Parameter validation
- **12-TestLatestWithServer.ps1** - **CRITICAL**: Latest mods with server compatibility testing
- **13-TestApiResponseOrganization.ps1** - API response organization and environment variable testing

### Mod Compatibility Testing

The **12-TestLatestWithServer.ps1** test is critical for validating mod compatibility:

- Downloads latest mods and server files
- Attempts server startup
- Detects compatibility issues (missing dependencies, version mismatches)
- Reports specific errors that need fixing

**Expected Test Results with Compatibility Issues:**
- Total Tests: 8
- Passed: 6 (validation, downloads, server files, start script, isolation check)
- Failed: 2 (server startup, compatibility analysis)
- Success Rate: 75%

**Common Compatibility Issues Detected:**
- Missing Fabric API dependencies
- Minecraft version mismatches (mods built for 1.21.5 running on 1.21.6)
- Specific mods that need removal or replacement

### Test Output Structure

```
test/test-output/{TestName}/
├── download/                    # Downloaded mods and server files
├── {TestName}.log              # Individual test logs
├── {TestName}-test-report.txt  # Test results report
└── Server_*.log                # Server startup logs
```

## 📁 File Structure

```
minecraft-mods-manager/
├── ModManager.ps1              # Main script
├── modlist.csv                 # Mod list (input)
├── README.md                   # This file
├── .gitignore                  # Git ignore rules
├── .gitmodules                 # Git submodules
├── .env                        # Environment configuration (optional)
├── apiresponse/                # API response cache (organized by domain)
│   ├── modrinth/              # Modrinth API responses
│   │   ├── fabric-api-project.json
│   │   ├── fabric-api-versions.json
│   │   ├── sodium-project.json
│   │   └── sodium-versions.json
│   ├── curseforge/            # CurseForge API responses
│   │   ├── 357540-curseforge-versions.json
│   │   └── other-mod-curseforge-versions.json
│   ├── version-validation-results.csv
│   └── mod-download-results.csv
├── download/                   # Downloaded content (created automatically)
│   ├── 1.21.5/
│   │   ├── mods/              # Mods for this version
│   │   │   ├── block/         # Block group mods
│   │   │   └── *.jar          # Other mods
│   │   ├── shaderpacks/       # Shaderpacks
│   │   ├── installer/         # Installers
│   │   ├── minecraft_server.1.21.5.jar
│   │   └── fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar
│   └── 1.21.6/
│       ├── mods/              # Mods for this version
│       │   ├── block/         # Block group mods
│       │   └── *.jar          # Other mods
│       ├── shaderpacks/       # Shaderpacks
│       ├── installer/         # Installers
│       ├── minecraft_server.1.21.6.jar
│       └── fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar
├── test/                       # Test framework
│   ├── RunAllTests.ps1        # Main test runner
│   ├── TestFramework.ps1      # Shared test utilities
│   ├── tests/                 # Individual test files
│   ├── test-output/           # Test execution outputs
│   └── apiresponse/           # Cached API responses for testing (same structure)
├── tools/
│   └── minecraft-mod-hash/     # Mod validation tool (submodule)
└── backups/                    # Automatic backups
```

## 📖 Usage

### Use Cases

- **[Testing Latest Mod Versions](USECASE_LATEST_MODS_TESTING.md)** - Complete guide for testing latest mod versions with the latest Minecraft server
  - **Helper Script**: `.\scripts\TestLatestMods.ps1` - Automated workflow for testing latest mods
- **Modpack Development** - Validate mod compatibility before release
- **Server Administration** - Test updates before applying to production
- **Quality Assurance** - Automated compatibility testing

### Helper Scripts

For common workflows, use the focused helper scripts in the `scripts/` folder:

```powershell
# Test latest mod versions with latest server (complete workflow)
.\scripts\TestLatestMods.ps1

# Download latest versions of all mods
.\scripts\DownloadLatestMods.ps1

# Download current versions of all mods
.\scripts\DownloadCurrentMods.ps1

# With custom options
.\scripts\TestLatestMods.ps1 -DownloadFolder "test-latest"
.\scripts\DownloadLatestMods.ps1 -DownloadFolder "latest-mods"
```

### Basic Commands

```powershell
# Run validation and update modlist
.\ModManager.ps1

# Download all mods to download/ folder
.\ModManager.ps1 -Download

# Download latest versions instead of current versions
.\ModManager.ps1 -Download -UseLatestVersion

# Force download (overwrite existing files)
.\ModManager.ps1 -Download -ForceDownload

# Quick add mods using Modrinth URLs
.\ModManager.ps1 -AddModID "https://modrinth.com/mod/fabric-api"
.\ModManager.ps1 -AddModID "https://modrinth.com/shader/complementary-reimagined"

# Show help
.\ModManager.ps1 -Help
```

## 📋 Complete Parameter Reference

### Core Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-Download` | Switch | Download all mods to download/ folder | `.\ModManager.ps1 -Download` |
| `-UseLatestVersion` | Switch | Use latest versions instead of current versions | `.\ModManager.ps1 -Download -UseLatestVersion` |
| `-ForceDownload` | Switch | Force download (overwrite existing files) | `.\ModManager.ps1 -Download -ForceDownload` |
| `-Help` | Switch | Show help information | `.\ModManager.ps1 -Help` |
| `-ShowHelp` | Switch | Show detailed help information | `.\ModManager.ps1 -ShowHelp` |

### Validation Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-ValidateMod` | Switch | Validate a specific mod and update latest version | `.\ModManager.ps1 -ValidateMod -ModID "fabric-api"` |
| `-ModID` | String | Mod ID to validate (required with -ValidateMod) | `.\ModManager.ps1 -ValidateMod -ModID "sodium"` |
| `-ValidateModVersion` | Switch | Validate mod version (placeholder - use -ValidateMod instead) | `.\ModManager.ps1 -ValidateModVersion` |
| `-ValidateAllModVersions` | Switch | Validate all mods and update CSV | `.\ModManager.ps1 -ValidateAllModVersions` |
| `-ValidateWithDownload` | Switch | Validate before downloading | `.\ModManager.ps1 -DownloadMods -ValidateWithDownload` |

### Download Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-DownloadMods` | Switch | Download mods with custom settings | `.\ModManager.ps1 -DownloadMods` |
| `-DownloadServer` | Switch | Download Minecraft server JARs and Fabric launchers | `.\ModManager.ps1 -DownloadServer` |
| `-StartServer` | Switch | Start Minecraft server after download | `.\ModManager.ps1 -StartServer` |

### Mod Management Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-AddMod` | Switch | Add a new mod to the database | `.\ModManager.ps1 -AddMod -AddModID "fabric-api"` |
| `-AddModId` | String | Mod ID (Modrinth slug or CurseForge ID) | `.\ModManager.ps1 -AddMod -AddModId "sodium"` |
| `-AddModUrl` | String | Modrinth URL for quick add | `.\ModManager.ps1 -AddModId "https://modrinth.com/mod/fabric-api"` |
| `-AddModName` | String | Mod display name | `.\ModManager.ps1 -AddMod -AddModName "Fabric API"` |
| `-AddModLoader` | String | Mod loader (fabric, forge, iris, etc.) | `.\ModManager.ps1 -AddMod -AddModLoader "fabric"` |
| `-AddModGameVersion` | String | Target Minecraft version | `.\ModManager.ps1 -AddMod -AddModGameVersion "1.21.6"` |
| `-AddModType` | String | Mod type (mod, shaderpack, datapack, etc.) | `.\ModManager.ps1 -AddMod -AddModType "shaderpack"` |
| `-AddModGroup` | String | Mod group (required, optional, admin, block) | `.\ModManager.ps1 -AddMod -AddModGroup "optional"` |
| `-AddModDescription` | String | Mod description | `.\ModManager.ps1 -AddMod -AddModDescription "Required API"` |
| `-AddModJar` | String | JAR/EXE filename (required for server/launcher/installer) | `.\ModManager.ps1 -AddMod -AddModJar "fabric-api.jar"` |
| `-AddModUrlDirect` | String | Direct download URL (required for server/launcher/installer) | `.\ModManager.ps1 -AddMod -AddModUrlDirect "https://..."` |
| `-AddModCategory` | String | Mod category | `.\ModManager.ps1 -AddMod -AddModCategory "Core"` |
| `-DeleteModID` | String | Mod ID to delete | `.\ModManager.ps1 -DeleteModID "fabric-api"` |
| `-DeleteModType` | String | Mod type for deletion (optional) | `.\ModManager.ps1 -DeleteModID "fabric-api" -DeleteModType "mod"` |

### Information Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-GetModList` | Switch | Display mod list information | `.\ModManager.ps1 -GetModList` |

### Configuration Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-ModListFile` | String | Custom mod list file path | `.\ModManager.ps1 -ModListFile "custom-mods.csv"` |
| `-DatabaseFile` | String | Custom database file path | `.\ModManager.ps1 -DatabaseFile "my-mods.csv"` |
| `-UseCachedResponses` | Switch | Use cached API responses (faster testing) | `.\ModManager.ps1 -ValidateAllModVersions -UseCachedResponses` |

### Parameter Combinations

#### Quick Mod Addition
```powershell
# Add Modrinth mod with URL (auto-resolves everything)
.\ModManager.ps1 -AddModId "https://modrinth.com/mod/fabric-api"

# Add Modrinth shaderpack with URL
.\ModManager.ps1 -AddModId "https://modrinth.com/shader/complementary-reimagined"
```

#### Manual Mod Addition
```powershell
# Add mod with minimal info (auto-resolves latest version)
.\ModManager.ps1 -AddMod -AddModId "fabric-api" -AddModName "Fabric API"

# Add mod with specific settings
.\ModManager.ps1 -AddMod -AddModId "sodium" -AddModName "Sodium" -AddModLoader "fabric" -AddModGameVersion "1.21.6" -AddModGroup "optional"
```

#### Validation Workflows
```powershell
# Validate specific mod and update latest version
.\ModManager.ps1 -ValidateMod -ModID "fabric-api"

# Validate all mods and update CSV
.\ModManager.ps1 -ValidateAllModVersions

# Validate with cached responses (faster)
.\ModManager.ps1 -ValidateAllModVersions -UseCachedResponses
```

#### Download Workflows
```powershell
# Download current versions
.\ModManager.ps1 -Download

# Download latest versions
.\ModManager.ps1 -Download -UseLatestVersion

# Force download (overwrite existing)
.\ModManager.ps1 -Download -ForceDownload

# Download with validation first
.\ModManager.ps1 -DownloadMods -ValidateWithDownload
```

#### Server Management
```powershell
# Download server files
.\ModManager.ps1 -DownloadServer

# Start server after download
.\ModManager.ps1 -StartServer
```

#### Mod Management
```powershell
# Delete specific mod
.\ModManager.ps1 -DeleteModID "fabric-api"

# Delete mod with type specification
.\ModManager.ps1 -DeleteModID "fabric-api" -DeleteModType "mod"

# Show mod list
.\ModManager.ps1 -GetModList
```

### Default Behavior

When no parameters are provided, the script runs the default workflow:
```powershell
.\ModManager.ps1
# Equivalent to: .\ModManager.ps1 -ValidateAllModVersions
```

This validates all mods and updates the CSV with latest version information.

### Error Handling

- **Missing Required Parameters**: Script shows error message and usage example
- **Invalid Mod IDs**: Script reports "mod not found" and continues
- **API Failures**: Script continues processing other mods
- **File Not Found**: Script creates missing directories automatically

### Performance Tips

- **Use `-UseCachedResponses`** for faster testing and development
- **Combine validation and download** with `-ValidateWithDownload`
- **Use latest versions** with `-UseLatestVersion` for maximum compatibility
- **Force download** with `-ForceDownload` to overwrite existing files

## 🧪 Testing

### Test Isolation
All tests use isolated download folders to prevent interference with the main `download/` directory. Test outputs are contained within `test/test-output/` with each test having its own isolated download directory.

**Test Isolation Guarantees:**
- ✅ **No writes to main download folder**: Tests never write to `download/` or `test/download/`
- ✅ **Isolated test environments**: Each test creates its own temporary download folders
- ✅ **Automatic cleanup**: Test artifacts are cleaned up after completion
- ✅ **Parameter-based downloads**: All download operations respect the `-DownloadFolder` parameter

### Running Tests
```powershell
# Run all tests
.\test\RunAllTests.ps1

# Run specific test
.\test\tests\02-DownloadFunctionality.ps1

# Run E2E test with server startup
.\test\tests\12-TestLatestWithServer.ps1
```

### Test Coverage
- **Basic Functionality**: Core script operations and parameter handling
- **Download Functionality**: Mod and server file downloads with isolation
- **System Entries**: Installer, launcher, and server file management
- **Filename Handling**: Complex filename resolution and validation
- **Validation Tests**: API validation and version checking
- **Modpack Tests**: Modpack download and extraction workflows
- **Server Tests**: Server startup and log monitoring
- **Latest Version Tests**: E2E workflows with latest version downloads
- **Current Version Tests**: E2E workflows with current version downloads
- **Parameter Validation**: Comprehensive parameter validation and error handling
- **Latest with Server**: Complete E2E test including server startup and mod compatibility detection

## ➕ Adding New Mods

The script supports adding mods with minimal information and automatically resolves all details from the APIs.

### Quick Add with Modrinth URLs (Recommended)

The simplest way to add mods is to just provide the Modrinth URL:

```powershell
# Add any Modrinth mod, shaderpack, datapack, etc. with just the URL
.\ModManager.ps1 -AddModId "https://modrinth.com/mod/fabric-api"
.\ModManager.ps1 -AddModId "https://modrinth.com/shader/complementary-reimagined"
.\ModManager.ps1 -AddModId "https://modrinth.com/datapack/example-datapack"
```

**Features:**
- **Auto-detects type** (mod, shaderpack, datapack, resourcepack, plugin)
- **Auto-detects mod ID** from the URL
- **Fetches all metadata** (name, version, icon, description, etc.)
- **Defaults to "optional" group** (can be overridden with `-AddModGroup`)
- **Auto-uses "iris" loader** for shaderpacks
- **Error handling** for unsupported Modrinth types

### Adding Modrinth Mods (Traditional Method)

```powershell
# Add a Modrinth mod with minimal info (auto-resolves latest version)
.\ModManager.ps1 -AddMod -AddModId "fabric-api" -AddModName "Fabric API"

# Add with specific loader and game version
.\ModManager.ps1 -AddMod -AddModId "sodium" -AddModName "Sodium" -AddModLoader "fabric" -AddModGameVersion "1.21.6"

# Add to a specific group (required, optional, admin, block)
.\ModManager.ps1 -AddMod -AddModId "no-chat-reports" -AddModName "No Chat Reports" -AddModGroup "block"
```

### Adding CurseForge Mods

```powershell
# Add a CurseForge mod (requires CurseForge ID)
.\ModManager.ps1 -AddMod -AddModId "238222" -AddModName "Inventory HUD+" -AddModType "curseforge"

# Add with specific loader and game version
.\ModManager.ps1 -AddMod -AddModId "238222" -AddModName "Inventory HUD+" -AddModLoader "fabric" -AddModGameVersion "1.21.6" -AddModType "curseforge"
```

### Adding Shaderpacks

```powershell
# Add a shaderpack (uses "iris" loader automatically)
.\ModManager.ps1 -AddMod -AddModId "complementary-reimagined" -AddModName "Complementary Reimagined" -AddModType "shaderpack"
```

### Adding Installers

```powershell
# Add the Fabric installer (predefined URL)
.\ModManager.ps1 -AddMod -AddModId "fabric-installer-1.0.3" -AddModName "Fabric Installer" -AddModType "installer" -AddModGameVersion "1.21.5"

# Add a custom installer with direct URL
.\ModManager.ps1 -AddMod -AddModId "https://example.com/installer.exe" -AddModName "Custom Installer" -AddModType "installer" -AddModGameVersion "1.21.5"
```

**Note**: Installers are downloaded to the `installer/` subfolder within each game version folder.

### Auto-Resolution Features

When adding mods with minimal information, the script automatically:

1. **Fetches latest version** from the appropriate API
2. **Downloads all metadata** (description, icon, links, etc.)
3. **Determines compatibility** (client/server side support)
4. **Extracts download URLs** for both current and latest versions
5. **Adds complete record** to modlist.csv with all information

### Adding Server, Launcher, and Installer Mods

For `server`, `launcher`, and `installer` types, you **must** provide both the direct download URL and the filename to save as. These are stored in the `Url` and `Jar` columns in the CSV.

**Example: Add a Minecraft Server JAR**
```powershell
.\ModManager.ps1 -AddMod -AddModId "minecraft-server-1.21.5" -AddModName "Minecraft Server" -AddModType "server" -AddModGameVersion "1.21.5" -AddModUrlDirect "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar" -AddModJar "minecraft_server.1.21.5.jar"
```

**Example: Add a Fabric Server Launcher**
```powershell
.\ModManager.ps1 -AddMod -AddModId "fabric-server-launcher-1.21.5" -AddModName "Fabric Server Launcher" -AddModType "launcher" -AddModGameVersion "1.21.5" -AddModUrlDirect "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar" -AddModJar "fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar"
```

**Example: Add a Fabric Installer**
```powershell
.\ModManager.ps1 -AddMod -AddModId "fabric-installer-1.0.3" -AddModName "Fabric Installer" -AddModType "installer" -AddModGameVersion "1.21.5" -AddModUrlDirect "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe" -AddModJar "fabric-installer-1.0.3.exe"
```

**Note:**
- The script will error if you do not provide both `-AddModUrlDirect` and `-AddModJar` for these types.
- These values are stored in the CSV and used for all future downloads.

## 📊 CSV Format

The `modlist.csv` file should contain these columns (in order):

| Column              | Description                                                      |
|---------------------|------------------------------------------------------------------|
| Group               | Mod category (required, optional, admin, block)                  |
| Type                | Mod type (mod, datapack, shaderpack, installer, server, launcher) |
| GameVersion         | Target Minecraft version                                         |
| ID                  | Mod ID (Modrinth slug or CurseForge ID)                         |
| Loader              | Mod loader (fabric, forge, iris, etc.)                          |
| Version             | Expected mod version                                             |
| Name                | Mod display name                                                 |
| Description         | Mod description                                                  |
| Jar                 | JAR/EXE filename (for server, launcher, installer: required)                        |
| Url                 | Mod URL (for server, launcher, installer: direct download URL, required)            |
| Category            | Mod category                                                     |
| Version Url         | Download URL for current version                                 |
| Latest Version Url  | Download URL for latest version                                  |
| Latest Version      | Latest version string                                            |
| LatestVersion       | (Alias for Latest Version)                                       |
| VersionUrl          | (Alias for Version Url)                                          |
| LatestVersionUrl    | (Alias for Latest Version Url)                                   |
| ApiSource           | API source (modrinth, curseforge)                                |
| Host                | API host (modrinth, curseforge)                                  |
| IconUrl             | Mod icon URL                                                     |
| ClientSide          | Client-side support info                                         |
| ServerSide          | Server-side support info                                         |
| Title               | Project title                                                    |
| ProjectDescription  | Project description (from API)                                   |
| IssuesUrl           | Issues/bug tracker URL                                           |
| SourceUrl           | Source code URL                                                  |
| WikiUrl             | Wiki/documentation URL                                           |
| LatestGameVersion   | Highest supported game version (from API)                        |

### Example CSV Entries

#### Modrinth Mod
```csv
"required","mod","1.21.5","fabric-api","fabric","v0.126.0+1.21.5","Fabric API","Required by most Fabric mods","fabric-api-0.126.0%2B1.21.5.jar","https://modrinth.com/mod/fabric-api","Core & Utility","https://cdn.modrinth.com/data/P7dR8mSH/versions/B41MB8lb/fabric-api-0.126.0%2B1.21.5.jar","https://cdn.modrinth.com/data/P7dR8mSH/versions/N3z6cNQv/fabric-api-0.127.1%2B1.21.6.jar","0.127.1+1.21.6","0.127.1+1.21.6","https://cdn.modrinth.com/data/P7dR8mSH/versions/B41MB8lb/fabric-api-0.126.0%2B1.21.5.jar","https://cdn.modrinth.com/data/P7dR8mSH/versions/N3z6cNQv/fabric-api-0.127.1%2B1.21.6.jar","modrinth","modrinth","https://cdn.modrinth.com/data/P7dR8mSH/icon.png","optional","optional","Fabric API","Lightweight and modular API providing common hooks and intercompatibility measures utilized by mods using the Fabric toolchain.","https://github.com/FabricMC/fabric/issues","https://github.com/FabricMC/fabric","https://fabricmc.net/wiki/","1.21.6"
```

#### CurseForge Mod
```csv
"required","mod","1.21.5","238222","fabric","3.4.6","Inventory HUD+","Enhanced inventory display","inventory-hud-3.4.6.jar","https://www.curseforge.com/minecraft/mc-mods/inventory-hud","Interface","https://www.curseforge.com/api/v1/mods/238222/files/1234567/download","https://www.curseforge.com/api/v1/mods/238222/files/1234568/download","3.4.7","3.4.7","https://www.curseforge.com/api/v1/mods/238222/files/1234567/download","https://www.curseforge.com/api/v1/mods/238222/files/1234568/download","curseforge","curseforge","https://media.forgecdn.net/avatars/thumbnails/123/456/256/256/6361234567890.png","required","optional","Inventory HUD+","Enhanced inventory display with customizable HUD","https://github.com/example/inventory-hud/issues","https://github.com/example/inventory-hud","","1.21.6"
```

#### Shaderpack
```csv
"optional","shaderpack","1.21.6","complementary-reimagined","iris","","Complementary Reimagined","Beautiful shaderpack","complementary-reimagined.zip","https://modrinth.com/shader/complementary-reimagined","Shaders","","","","","","","modrinth","modrinth","https://cdn.modrinth.com/data/123456/icon.png","required","unsupported","Complementary Reimagined","A beautiful shaderpack","","","","1.21.6"
```

## 🔧 Configuration

### Environment Variables

The script supports several environment variables for configuration. Create a `.env` file in the project root:

#### API Response Organization
- **`APIRESPONSE_MODRINTH_SUBFOLDER`**: Subfolder name for Modrinth API responses (default: `modrinth`)
- **`APIRESPONSE_CURSEFORGE_SUBFOLDER`**: Subfolder name for CurseForge API responses (default: `curseforge`)

#### API Configuration
- **`MODRINTH_API_BASE_URL`**: Modrinth API base URL (default: `https://api.modrinth.com/v2`)
- **`CURSEFORGE_API_BASE_URL`**: CurseForge API base URL (default: `https://www.curseforge.com/api/v1`)
- **`CURSEFORGE_API_KEY`**: CurseForge API key for enhanced rate limits (optional)

#### Default Settings
- **`DEFAULT_LOADER`**: Default mod loader (default: `fabric`)
- **`DEFAULT_GAME_VERSION`**: Default game version (default: `1.21.5`)
- **`DEFAULT_MOD_TYPE`**: Default mod type (default: `mod`)

### API Response Organization

API responses are automatically organized into subfolders by domain:

- **Modrinth responses**: Stored in `apiresponse/modrinth/`
  - Project info: `{modid}-project.json`
  - Version info: `{modid}-versions.json`
- **CurseForge responses**: Stored in `apiresponse/curseforge/`
  - Version info: `{modid}-curseforge-versions.json`

This organization:
- **Improves performance**: Faster file lookups in smaller directories
- **Enhances maintainability**: Clear separation between API sources
- **Reduces conflicts**: No filename collisions between different APIs
- **Enables customization**: Subfolder names can be configured via environment variables

## 📈 Features in Detail

### Majority Version Targeting

When using `-UseLatestVersion`, the script:

1. **Analyzes all mods** to find the most common `LatestGameVersion`
2. **Targets the majority version** for maximum compatibility
3. **Downloads all mods** to a single version folder (e.g., `download/1.21.6/mods/`)
4. **Generates comprehensive README** with version distribution analysis

### CurseForge Integration

- **Direct API Downloads**: Uses `https://www.curseforge.com/api/v1/mods/{modId}/files/{fileId}/download`
- **Automatic URL Construction**: Builds download URLs when direct URLs are missing
- **File ID Extraction**: Extracts file IDs from API responses for reliable downloads
- **ID Requirements**: CurseForge mods require numeric IDs (found in mod URLs)

### Shaderpack Support

- **Iris Loader**: Automatically uses "iris" loader for shaderpacks
- **Separate Folder**: Downloads to `download/[version]/shaderpacks/` folder
- **Modrinth Shaders**: Supports Modrinth shader downloads

### Server and Launcher Downloads

- **Minecraft Server JARs**: Downloads official server JARs for specific versions
- **Fabric Launchers**: Downloads Fabric server launchers with proper naming
- **Version-Specific**: Each download is tied to a specific game version

### Comprehensive README Generation

Each download creates a detailed README with:

- **Game Version Analysis**: Total mods, majority version, target version
- **Version Distribution**: Breakdown of all supported versions with mod lists
- **Download Results**: Success/failure counts and error details
- **Mod List**: Complete list of downloaded mods with versions and sizes
- **Download Settings**: Flags and configuration used

## 🔍 Output Files

### Generated Files

- **`apiresponse/version-validation-results.csv`**: Validation results
- **`apiresponse/mod-download-results.csv`**: Download results

### Backup Files

- **`modlist-backup.csv`**: Backup before CSV updates
- **`modlist-columns-backup.csv`**: Backup when adding new columns

## 🛡️ Error Handling

- **Graceful API Failures**: Continues processing if individual mods fail
- **Automatic Retries**: Handles temporary network issues
- **Detailed Error Reporting**: Shows specific failure reasons
- **Backup Protection**: Creates backups before making changes

## 🔄 Workflow

### Typical Usage Workflow

1. **Prepare modlist.csv** with your mods
2. **Run validation**: `.\ModManager.ps1`
3. **Review results** in the console output
4. **Download mods**: `.\ModManager.ps1 -Download -UseLatestVersion`
5. **Check generated README** in the mods folder
6. **Use downloaded mods** in your Minecraft installation

### Continuous Integration

- **Regular validation**: Check for updates weekly
- **Version tracking**: Monitor for new mod versions
- **Compatibility testing**: Ensure mods work with target versions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Testing

#### Local Testing

Run the complete test suite locally:

```powershell
cd test
.\RunAllTests.ps1 -All
```

Run individual test files:

```powershell
.\RunAllTests.ps1 -TestFiles '01-BasicFunctionality.ps1'
```

#### Continuous Integration

This project includes GitHub Actions workflows that automatically run the test suite on:

- **Windows** (Windows Server 2022)
- **Linux** (Ubuntu 22.04) 
- **macOS** (macOS 13)

The CI pipeline:
- Runs on every push to `main` and `develop` branches
- Runs on all pull requests
- Can be manually triggered via GitHub Actions UI
- Uploads test logs and output as artifacts
- Supports cross-platform testing

#### CI Features

- **Multi-platform testing**: Ensures compatibility across Windows, Linux, and macOS
- **Automatic PowerShell installation**: Sets up PowerShell 7 on Linux and macOS
- **Test artifacts**: Preserves test logs and output for debugging
- **Fail-fast protection**: Prevents broken code from being merged
- **Manual triggering**: Allows running tests on demand

#### Viewing Results

1. Go to the **Actions** tab on GitHub
2. Click on the latest workflow run
3. View test results for each platform
4. Download test artifacts if needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
