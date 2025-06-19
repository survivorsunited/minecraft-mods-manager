# Minecraft Mod Manager

A powerful PowerShell script for managing Minecraft mods across multiple platforms (Modrinth and CurseForge) with automatic version validation, download management, and comprehensive reporting.

## 🚀 Features

### Core Functionality
- **Multi-Platform Support**: Works with both Modrinth and CurseForge APIs
- **Automatic Version Validation**: Checks if mod versions exist and finds latest versions
- **Smart Download Management**: Downloads mods organized by game version
- **Majority Version Targeting**: Automatically determines the most compatible game version
- **Comprehensive Reporting**: Generates detailed README files with analysis and mod lists

### Advanced Features
- **Icon URL Extraction**: Automatically fetches mod icons and metadata
- **Project Information**: Retrieves detailed mod information (description, links, etc.)
- **Latest Game Version Detection**: Uses the highest supported game version from API responses
- **JAR Filename Matching**: Fallback matching when version strings don't match exactly
- **CurseForge Direct API Downloads**: Uses direct API endpoints for reliable downloads
- **Git Integration**: Includes minecraft-mod-hash tool as a submodule for mod validation

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
├── mods/                       # Downloaded mods (created automatically)
├── tools/
│   └── minecraft-mod-hash/     # Mod validation tool (submodule)
└── backups/                    # Automatic backups
```

## 📖 Usage

### Basic Commands

```powershell
# Run validation and update modlist
.\ModManager.ps1

# Download all mods to mods/ folder
.\ModManager.ps1 -Download

# Download latest versions instead of current versions
.\ModManager.ps1 -Download -UseLatestVersion

# Force download (overwrite existing files)
.\ModManager.ps1 -Download -ForceDownload

# Show help
.\ModManager.ps1 -Help
```

### Advanced Functions

```powershell
# Validate a specific mod
Validate-ModVersion -ModId "fabric-api" -Version "0.91.0+1.20.1"

# Validate all mods and update CSV
Validate-AllModVersions -UpdateModList

# Download mods with custom settings
Download-Mods -UseLatestVersion -ForceDownload

# Get mod list
Get-ModList

# Show help
Show-Help
```

## 📊 CSV Format

The `modlist.csv` file should contain these columns (in order):

| Column              | Description                                                      |
|---------------------|------------------------------------------------------------------|
| Group               | Mod category (required, optional, admin)                         |
| Type                | Mod type (mod, datapack, etc.)                                   |
| GameVersion         | Target Minecraft version                                         |
| ID                  | Mod ID (Modrinth slug or CurseForge ID)                         |
| Loader              | Mod loader (fabric, forge, etc.)                                 |
| Version             | Expected mod version                                             |
| Name                | Mod display name                                                 |
| Description         | Mod description                                                  |
| Jar                 | JAR filename                                                     |
| Url                 | Mod URL                                                          |
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

### Example CSV Entry

```csv
"required","mod","1.21.5","fabric-api","fabric","v0.126.0+1.21.5","Fabric API","Required by most Fabric mods","fabric-api-0.126.0+1.21.5.jar","https://modrinth.com/mod/fabric-api","Core & Utility","https://cdn.modrinth.com/data/P7dR8mSH/versions/B41MB8lb/fabric-api-0.126.0%2B1.21.5.jar","https://cdn.modrinth.com/data/P7dR8mSH/versions/N3z6cNQv/fabric-api-0.127.1%2B1.21.6.jar","0.127.1+1.21.6","0.127.1+1.21.6","https://cdn.modrinth.com/data/P7dR8mSH/versions/B41MB8lb/fabric-api-0.126.0%2B1.21.5.jar","https://cdn.modrinth.com/data/P7dR8mSH/versions/N3z6cNQv/fabric-api-0.127.1%2B1.21.6.jar","modrinth","modrinth","https://cdn.modrinth.com/data/P7dR8mSH/icon.png","optional","optional","Fabric API","Lightweight and modular API providing common hooks and intercompatibility measures utilized by mods using the Fabric toolchain.","https://github.com/FabricMC/fabric/issues","https://github.com/FabricMC/fabric","https://fabricmc.net/wiki/","1.21.6"
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
- **API Response Folder**: `apiresponse/`
- **Mods Folder**: `mods/`

## 📈 Features in Detail

### Majority Version Targeting

When using `-UseLatestVersion`, the script:

1. **Analyzes all mods** to find the most common `LatestGameVersion`
2. **Targets the majority version** for maximum compatibility
3. **Downloads all mods** to a single version folder (e.g., `mods/1.21.6/`)
4. **Generates comprehensive README** with version distribution analysis

### CurseForge Integration

- **Direct API Downloads**: Uses `https://www.curseforge.com/api/v1/mods/{modId}/files/{fileId}/download`
- **Automatic URL Construction**: Builds download URLs when direct URLs are missing
- **File ID Extraction**: Extracts file IDs from API responses for reliable downloads

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
- **`apiresponse/*.json`**: API response cache
- **`mods/{version}/README.md`**: Comprehensive modpack documentation
- **`modlist-backup.csv`**: Automatic backup before updates

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
