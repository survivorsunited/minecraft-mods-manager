# Modlist CSV Column Documentation

This document provides detailed information about each column in the `modlist.csv` file used by the Minecraft Mod Manager.

## Overview

The `modlist.csv` file is the central database for managing Minecraft mods. It contains metadata, download URLs, version information, and dependency data for each mod.

## Column Reference

### Core Identification Columns

#### Group
- **Type**: String
- **Required**: Yes
- **Values**: `required`, `optional`, `admin`, `block`
- **Description**: Categorizes the mod based on its importance or function
- **Updated By**: User input, Add-ModToDatabase.ps1
- **Default**: `required`

#### Type
- **Type**: String
- **Required**: Yes
- **Values**: `mod`, `datapack`, `shaderpack`, `installer`, `server`, `launcher`
- **Description**: Specifies the type of content
- **Updated By**: User input, Add-ModToDatabase.ps1
- **Default**: `mod`

#### GameVersion
- **Type**: String (Semantic Version)
- **Required**: Yes
- **Example**: `1.21.5`
- **Description**: Target Minecraft version for the mod
- **Updated By**: User input, Add-ModToDatabase.ps1
- **Default**: `1.21.5`

#### ID
- **Type**: String
- **Required**: Yes
- **Examples**: `fabric-api`, `238222` (CurseForge ID)
- **Description**: Unique identifier for the mod (Modrinth slug or CurseForge ID)
- **Updated By**: User input, extracted from URL in Add-ModToDatabase.ps1

#### Loader
- **Type**: String
- **Required**: Yes
- **Values**: `fabric`, `forge`, `iris`, `quilt`, etc.
- **Description**: The mod loader required
- **Updated By**: User input, Add-ModToDatabase.ps1
- **Default**: `fabric`

### Version Information Columns

#### Version
- **Type**: String
- **Required**: Yes
- **Example**: `0.127.1+1.21.5`
- **Description**: Expected/current version of the mod
- **Updated By**: User input, Validate-AllModVersions.ps1 (when found by JAR)

#### LatestVersion
- **Type**: String
- **Required**: No
- **Example**: `0.129.0+1.21.7`
- **Description**: Latest available version from API
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### LatestGameVersion
- **Type**: String
- **Required**: No
- **Example**: `1.21.7`
- **Description**: Highest Minecraft version supported by the mod
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### AvailableGameVersions
- **Type**: String (Comma-separated list)
- **Required**: No
- **Example**: `1.21.5,1.21.6,1.21.7`
- **Description**: All Minecraft versions supported by the mod (extracted from project API data)
- **Updated By**: Validate-ModVersion in Common.ps1
- **Used By**: Calculate-LatestGameVersionFromAvailableVersions.ps1, Show-VersionSummary.ps1
- **Note**: Populated from project.game_versions API field for comprehensive version support data

### Mod Metadata Columns

#### Name
- **Type**: String
- **Required**: Yes
- **Example**: `Fabric API`
- **Description**: Human-readable display name
- **Updated By**: User input, Add-ModToDatabase.ps1

#### Description
- **Type**: String
- **Required**: No
- **Description**: Brief description of the mod
- **Updated By**: User input, Add-ModToDatabase.ps1

#### Title
- **Type**: String
- **Required**: No
- **Description**: Official project title from API
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### ProjectDescription
- **Type**: String
- **Required**: No
- **Description**: Detailed project description from API
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### Category
- **Type**: String
- **Required**: No
- **Examples**: `Core & Utility`, `Interface`, `Shaders`
- **Description**: Mod category classification
- **Updated By**: User input, Add-ModToDatabase.ps1

### File and URL Columns

#### Jar
- **Type**: String
- **Required**: For server/launcher/installer types
- **Example**: `fabric-api-0.127.1+1.21.5.jar`
- **Description**: JAR/EXE filename for download
- **Updated By**: User input, Add-ModToDatabase.ps1

#### Url
- **Type**: String (URL)
- **Required**: No
- **Example**: `https://modrinth.com/mod/fabric-api`
- **Description**: Mod page URL
- **Updated By**: User input, Add-ModToDatabase.ps1

#### UrlDirect
- **Type**: String (URL)
- **Required**: For server/launcher/installer types
- **Description**: Direct download URL (bypasses API)
- **Updated By**: User input (required for system entries)
- **Test Usage**: Used in 03-SystemEntries.ps1 for server/launcher/installer downloads

#### VersionUrl
- **Type**: String (URL)
- **Required**: No
- **Description**: Download URL for current version
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### LatestVersionUrl
- **Type**: String (URL)
- **Required**: No
- **Description**: Download URL for latest version
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### IconUrl
- **Type**: String (URL)
- **Required**: No
- **Description**: URL to mod icon/thumbnail
- **Updated By**: Update-ModListWithLatestVersions.ps1

### API Source Columns

#### ApiSource
- **Type**: String
- **Required**: Yes
- **Values**: `modrinth`, `curseforge`
- **Description**: Which API provides the mod
- **Updated By**: Add-ModToDatabase.ps1
- **Default**: `modrinth`

#### Host
- **Type**: String
- **Required**: Yes
- **Values**: `modrinth`, `curseforge`
- **Description**: Hosting platform (usually same as ApiSource)
- **Updated By**: Add-ModToDatabase.ps1
- **Default**: `modrinth`

### Compatibility Columns

#### ClientSide
- **Type**: String
- **Required**: No
- **Values**: `required`, `optional`, `unsupported`
- **Description**: Client-side compatibility
- **Updated By**: Update-ModListWithLatestVersions.ps1
- **Default**: `optional`

#### ServerSide
- **Type**: String
- **Required**: No
- **Values**: `required`, `optional`, `unsupported`
- **Description**: Server-side compatibility
- **Updated By**: Update-ModListWithLatestVersions.ps1
- **Default**: `optional`

### External Link Columns

#### IssuesUrl
- **Type**: String (URL)
- **Required**: No
- **Description**: Bug tracker/issues URL
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### SourceUrl
- **Type**: String (URL)
- **Required**: No
- **Description**: Source code repository URL
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### WikiUrl
- **Type**: String (URL)
- **Required**: No
- **Description**: Documentation/wiki URL
- **Updated By**: Update-ModListWithLatestVersions.ps1

### Dependency Columns

#### CurrentDependencies
- **Type**: String (JSON)
- **Required**: No
- **Description**: Dependencies for current version (legacy format)
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### LatestDependencies
- **Type**: String (JSON)
- **Required**: No
- **Description**: Dependencies for latest version (legacy format)
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### CurrentDependenciesRequired
- **Type**: String (Comma-separated mod IDs)
- **Required**: No
- **Example**: `P7dR8mSH,5WeWGLoJ`
- **Description**: Required dependencies for current version
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### CurrentDependenciesOptional
- **Type**: String (Comma-separated mod IDs)
- **Required**: No
- **Example**: `9s6osm5g,mOgUt4GM`
- **Description**: Optional dependencies for current version
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### LatestDependenciesRequired
- **Type**: String (Comma-separated mod IDs)
- **Required**: No
- **Description**: Required dependencies for latest version
- **Updated By**: Update-ModListWithLatestVersions.ps1

#### LatestDependenciesOptional
- **Type**: String (Comma-separated mod IDs)
- **Required**: No
- **Description**: Optional dependencies for latest version
- **Updated By**: Update-ModListWithLatestVersions.ps1

### Validation Columns

#### RecordHash
- **Type**: String (SHA256 Hash)
- **Required**: No
- **Description**: Hash of the record for change detection
- **Updated By**: Calculate-RecordHash.ps1
- **Note**: Used to detect when mod metadata has changed

## Column Usage by Type

### Standard Mods (`type=mod`)
- Uses all columns normally
- Downloads to `mods/` subfolder

### Shaderpacks (`type=shaderpack`)
- Loader is typically `iris`
- Downloads to `shaderpacks/` subfolder
- ClientSide is usually `required`
- ServerSide is usually `unsupported`

### Server/Launcher/Installer Types
- **Required**: `Jar` and `UrlDirect` columns must be populated
- Version/dependency columns are typically empty
- Downloads directly to version folder (not in subfolder)

### System Entries
System entries (server, launcher, installer) are handled specially:
- They bypass normal API validation
- Require direct download URLs
- Are cleaned by Clean-SystemEntries.ps1 to ensure empty strings instead of nulls
- Tested extensively in 03-SystemEntries.ps1
- Must have both `Jar` and `UrlDirect` columns populated
- Version is typically the game version for servers or installer version

## Column Update Flow

1. **User adds mod**: Add-ModToDatabase.ps1 creates initial record
2. **Validation runs**: Validate-AllModVersions.ps1 fetches API data
3. **Database update**: Update-ModListWithLatestVersions.ps1 populates:
   - Version URLs
   - Latest version info
   - Project metadata
   - Dependency information
   - Available game versions
4. **Download process**: Uses appropriate URL columns based on flags

## Best Practices

1. **Never manually edit** system-populated columns (URLs, dependencies, etc.)
2. **Use Add-ModToDatabase** for adding new mods
3. **Run validation** to populate/update metadata
4. **Backup before bulk updates** - automatic backups are created
5. **Test dependency updates** - Use test 53-TestDependencyFieldSplit.ps1 to verify dependency columns
6. **Verify system entries** - Use test 03-SystemEntries.ps1 for server/launcher/installer testing

## Testing Information

### Key Test Files
- **03-SystemEntries.ps1**: Tests system entries (server/launcher/installer) handling
- **14-TestAddModFunctionality.ps1**: Tests all AddMod parameters and column population
- **18-TestDependencyDetection.ps1**: Tests dependency column extraction and population
- **53-TestDependencyFieldSplit.ps1**: Tests dependency field splitting into Required/Optional
- **54-TestUpdateSummaryLogic.ps1**: Tests AvailableGameVersions and version calculation logic

### Column Validation in Tests
Tests verify that:
- All columns are properly initialized with empty strings (not null)
- System entries have required Jar and UrlDirect fields
- Dependency columns are properly split and populated
- AvailableGameVersions contains valid version data
- RecordHash is calculated correctly for change detection

## Related Documentation

- [README.md](../README.md) - Main documentation
- [USECASE_LATEST_MODS_TESTING.md](USECASE_LATEST_MODS_TESTING.md) - Testing workflow
- Source files in `src/Database/` for implementation details
- Test files in `test/tests/` for usage examples