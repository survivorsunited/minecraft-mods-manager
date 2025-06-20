# Minecraft Mod Manager

A powerful PowerShell script for managing Minecraft mods across multiple platforms (Modrinth and CurseForge) with automatic version validation, download management, and comprehensive reporting.

## 🚀 Features

### Core Functionality
- **Multi-Platform Support**: Works with both Modrinth and CurseForge APIs
- **Automatic Version Validation**: Checks if mod versions exist and finds latest versions
- **Smart Download Management**: Downloads mods organized by game version
- **Majority Version Targeting**: Automatically determines the most compatible game version
- **Comprehensive Reporting**: Generates detailed README files with analysis and mod lists
- **Easy Mod Addition**: Add new mods with minimal information and auto-resolve details

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

3. **Optional**: Create a `.env` file for API keys:
   ```
   CURSEFORGE_API_KEY=your_api_key_here
   ```

## 📁 File Structure

```
minecraft-mods-manager/
├── ModManager.ps1              # Main script
├── modlist.csv                 # Mod list (input)
├── README.md                   # This file
├── .gitignore                  # Git ignore rules
├── .gitmodules                 # Git submodules
├── apiresponse/                # API response cache
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
├── tools/
│   └── minecraft-mod-hash/     # Mod validation tool (submodule)
└── backups/                    # Automatic backups
```

## 📖 Usage

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

### Adding New Mods

The script supports adding mods with minimal information and automatically resolves all details from the APIs.

#### Quick Add with Modrinth URLs (Recommended)

The simplest way to add mods is to just provide the Modrinth URL:

```powershell
# Add any Modrinth mod, shaderpack, datapack, etc. with just the URL
.\ModManager.ps1 -AddModID "https://modrinth.com/mod/fabric-api"
.\ModManager.ps1 -AddModID "https://modrinth.com/shader/complementary-reimagined"
.\ModManager.ps1 -AddModID "https://modrinth.com/datapack/example-datapack"
```

**Features:**
- **Auto-detects type** (mod, shaderpack, datapack, resourcepack, plugin)
- **Auto-detects mod ID** from the URL
- **Fetches all metadata** (name, version, icon, description, etc.)
- **Defaults to "optional" group** (can be overridden with `-AddModGroup`)
- **Auto-uses "iris" loader** for shaderpacks
- **Error handling** for unsupported Modrinth types

#### Adding Modrinth Mods (Traditional Method)

```powershell
# Add a Modrinth mod with minimal info (auto-resolves latest version)
.\ModManager.ps1 -AddMod -AddModID "fabric-api" -AddModName "Fabric API"

# Add with specific loader and game version
.\ModManager.ps1 -AddMod -AddModID "sodium" -AddModName "Sodium" -AddModLoader "fabric" -AddModGameVersion "1.21.6"

# Add to a specific group (required, optional, admin, block)
.\ModManager.ps1 -AddMod -AddModID "no-chat-reports" -AddModName "No Chat Reports" -AddModGroup "block"
```

#### Adding CurseForge Mods

```powershell
# Add a CurseForge mod (requires CurseForge ID)
.\ModManager.ps1 -AddMod -AddModID "238222" -AddModName "Inventory HUD+" -AddModType "curseforge"

# Add with specific loader and game version
.\ModManager.ps1 -AddMod -AddModID "238222" -AddModName "Inventory HUD+" -AddModLoader "fabric" -AddModGameVersion "1.21.6" -AddModType "curseforge"
```

#### Adding Shaderpacks

```powershell
# Add a shaderpack (uses "iris" loader automatically)
.\ModManager.ps1 -AddMod -AddModID "complementary-reimagined" -AddModName "Complementary Reimagined" -AddModType "shaderpack"
```

#### Adding Installers

```powershell
# Add the Fabric installer (predefined URL)
.\ModManager.ps1 -AddMod -AddModID "fabric-installer-1.0.3" -AddModName "Fabric Installer" -AddModType "installer" -AddModGameVersion "1.21.5"

# Add a custom installer with direct URL
.\ModManager.ps1 -AddMod -AddModID "https://example.com/installer.exe" -AddModName "Custom Installer" -AddModType "installer" -AddModGameVersion "1.21.5"
```

**Note**: Installers are downloaded to the `installer/` subfolder within each game version folder.

#### Auto-Resolution Features

When adding mods with minimal information, the script automatically:

1. **Fetches latest version** from the appropriate API
2. **Downloads all metadata** (description, icon, links, etc.)
3. **Determines compatibility** (client/server side support)
4. **Extracts download URLs** for both current and latest versions
5. **Adds complete record** to modlist.csv with all information

#### Adding Server, Launcher, and Installer Mods

For `server`, `launcher`, and `installer` types, you **must** provide both the direct download URL and the filename to save as. These are stored in the `Url` and `Jar` columns in the CSV.

**Example: Add a Minecraft Server JAR**
```powershell
.\ModManager.ps1 -AddMod -AddModID "minecraft-server-1.21.5" -AddModName "Minecraft Server" -AddModType "server" -AddModGameVersion "1.21.5" -AddModUrl "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar" -AddModJar "minecraft_server.1.21.5.jar"
```

**Example: Add a Fabric Server Launcher**
```powershell
.\ModManager.ps1 -AddMod -AddModID "fabric-server-launcher-1.21.5" -AddModName "Fabric Server Launcher" -AddModType "launcher" -AddModGameVersion "1.21.5" -AddModUrl "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar" -AddModJar "fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar"
```

**Example: Add a Fabric Installer**
```powershell
.\ModManager.ps1 -AddMod -AddModID "fabric-installer-1.0.3" -AddModName "Fabric Installer" -AddModType "installer" -AddModGameVersion "1.21.5" -AddModUrl "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe" -AddModJar "fabric-installer-1.0.3.exe"
```

**Note:**
- The script will error if you do not provide both `-AddModUrl` and `-AddModJar` for these types.
- These values are stored in the CSV and used for all future downloads.

### Advanced Functions

```powershell
# Validate a specific mod
.\ModManager.ps1 -ValidateMod -ModID "fabric-api"

# Validate all mods and update CSV
.\ModManager.ps1 -ValidateAll

# Download mods with custom settings
.\ModManager.ps1 -Download -UseLatestVersion -ForceDownload

# Get mod list
.\ModManager.ps1 -ListMods

# Show help
.\ModManager.ps1 -Help
```

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
"required","mod","1.21.5","fabric-api","fabric","v0.126.0+1.21.5","Fabric API","Required by most Fabric mods","fabric-api-0.126.0+1.21.5.jar","https://modrinth.com/mod/fabric-api","Core & Utility","https://cdn.modrinth.com/data/P7dR8mSH/versions/B41MB8lb/fabric-api-0.126.0%2B1.21.5.jar","https://cdn.modrinth.com/data/P7dR8mSH/versions/N3z6cNQv/fabric-api-0.127.1%2B1.21.6.jar","0.127.1+1.21.6","0.127.1+1.21.6","https://cdn.modrinth.com/data/P7dR8mSH/versions/B41MB8lb/fabric-api-0.126.0%2B1.21.5.jar","https://cdn.modrinth.com/data/P7dR8mSH/versions/N3z6cNQv/fabric-api-0.127.1%2B1.21.6.jar","modrinth","modrinth","https://cdn.modrinth.com/data/P7dR8mSH/icon.png","optional","optional","Fabric API","Lightweight and modular API providing common hooks and intercompatibility measures utilized by mods using the Fabric toolchain.","https://github.com/FabricMC/fabric/issues","https://github.com/FabricMC/fabric","https://fabricmc.net/wiki/","1.21.6"
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

Create a `.env` file in the project root:

```env
# API Configuration
MODRINTH_API_BASE_URL=https://api.modrinth.com/v2
CURSEFORGE_API_BASE_URL=https://www.curseforge.com/api/v1
CURSEFORGE_API_KEY=your_api_key_here

# Default Settings
DEFAULT_LOADER=fabric
DEFAULT_GAME_VERSION=1.21.5
DEFAULT_MOD_TYPE=mod
```

### Default Settings

- **Default Loader**: `fabric`
- **Default Game Version**: `1.21.5`
- **Default Mod Type**: `mod`
- **API Response Folder**: `apiresponse/`
- **Download Folder**: `download/`

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
