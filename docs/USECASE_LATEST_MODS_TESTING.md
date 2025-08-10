# Use Case: Progressive Mod Version Testing (Current → Next → Latest)

This guide explains how to test mod versions progressively using the Current → Next → Latest workflow in ModManager.ps1.

## Overview

The mod manager supports three-tier version testing for safer compatibility testing:

- **Current**: Stable/default versions (e.g., 1.21.5) - production ready
- **Next**: Next logical version (e.g., 1.21.6) - incremental testing  
- **Latest**: Bleeding edge versions (e.g., 1.21.8) - newest available

This progressive approach is essential for:
- **Safe Compatibility Testing**: Incremental updates instead of jumping to bleeding edge
- **Modpack Development**: Testing mod compatibility step by step
- **Server Administration**: Validating updates before production deployment
- **Quality Assurance**: Identifying issues early in the upgrade process

## Prerequisites

- PowerShell 7.0+ installed
- ModManager.ps1 script available
- modlist.csv database file
- Internet connection for API access

## Progressive Testing Workflows

### Workflow 1: Next Version Testing (Recommended)

Test the next incremental version for safer compatibility validation:

#### Step 1: Download Next Version Mods

```powershell
.\ModManager.ps1 -Download -UseNextVersion -DatabaseFile "modlist.csv" -DownloadFolder "download"
```

**What this does:**
- Downloads the next logical version of each mod (e.g., 1.21.6 if current is 1.21.5)
- Uses incremental version progression for safer testing
- Organizes files by the target game version

#### Step 2: Start Server with Next Versions

```powershell
.\ModManager.ps1 -StartServer -UseNextVersion -DownloadFolder "download"
```

**Expected outcomes:**
- Higher compatibility success rate than jumping to latest
- Easier to identify specific compatibility issues
- Safer progression path for production updates

### Workflow 2: Current Version Testing (Default)

Test with current stable versions (no flags needed):

```powershell
# Download current versions (default behavior)
.\ModManager.ps1 -Download -DatabaseFile "modlist.csv" -DownloadFolder "download"

# Start server with current versions
.\ModManager.ps1 -StartServer -DownloadFolder "download"
```

### Workflow 3: Latest Version Testing (Bleeding Edge)

## Step-by-Step Process (Latest Version Testing)

### Step 1: Update Mod Database to Latest Versions

First, fetch the latest version information for all mods from Modrinth and CurseForge:

```powershell
.\ModManager.ps1 -UpdateMods -DatabaseFile "modlist.csv" -UseCachedResponses
```

**What this does:**
- Calls Modrinth and CurseForge APIs to get latest version information
- Updates the `LatestVersion` and `LatestVersionUrl` columns in modlist.csv
- Shows a summary of available updates

**Expected output:**
```
✅ Database updated: 60 mods now have latest version information
🔄 53 mods have newer versions available!
```

### Step 2: Download Latest Mods

Download all mods using their latest versions:

```powershell
.\ModManager.ps1 -Download -UseLatestVersion -DatabaseFile "modlist.csv" -DownloadFolder "download" -UseCachedResponses
```

**What this does:**
- Downloads the newest version of each mod from the APIs
- Creates organized folder structure by Minecraft version
- Shows download progress and file sizes

**Expected output:**
```
⬇️  Fabric API: Downloading 0.128.1+1.21.7...
✅ Fabric API: Downloaded successfully (2.14 MB)
...
Download Summary:
✅ Successfully downloaded: 66
⏭️  Skipped (already exists): 0
❌ Failed: 0
```

### Step 3: Download Latest Server Files

Download the latest Minecraft server JAR files:

```powershell
.\ModManager.ps1 -DownloadServer -DownloadFolder "download" -UseCachedResponses
```

**What this does:**
- Downloads the latest Minecraft server JAR from Mojang
- Downloads Fabric server launcher files
- Creates server startup scripts

**Expected output:**
```
⬇️  Minecraft Server: Downloading 1.21.6...
✅ Minecraft Server: Downloaded successfully (54.89 MB)
⬇️  Fabric Server Launcher: Downloading 1.0.3...
✅ Fabric Server Launcher: Downloaded successfully (0.17 MB)
```

### Step 4: Start Server to Test Compatibility

Attempt to start the server with all latest mods:

```powershell
.\ModManager.ps1 -StartServer -DownloadFolder "download"
```

**What this does:**
- Attempts to start the Minecraft server with all latest mods
- Validates mod compatibility and dependencies
- Reports any compatibility issues

**Expected outcomes:**
- **Success**: Server starts successfully (exit code 0)
- **Compatibility Issues**: Server reports mod conflicts (exit code 1)
- **Dependency Problems**: Missing or incompatible mods identified

## Command Reference by Testing Type

### Current Version Commands (Default)
```powershell
# Download current stable versions
.\ModManager.ps1 -Download -DatabaseFile "modlist.csv" -DownloadFolder "download"

# Start server with current versions
.\ModManager.ps1 -StartServer -DownloadFolder "download"
```

### Next Version Commands (Incremental Testing)
```powershell
# Download next incremental versions
.\ModManager.ps1 -Download -UseNextVersion -DatabaseFile "modlist.csv" -DownloadFolder "download"

# Start server with next versions
.\ModManager.ps1 -StartServer -UseNextVersion -DownloadFolder "download"
```

### Latest Version Commands (Bleeding Edge)
```powershell
# Update database to latest versions first
.\ModManager.ps1 -UpdateMods -DatabaseFile "modlist.csv"

# Download latest versions
.\ModManager.ps1 -Download -UseLatestVersion -DatabaseFile "modlist.csv" -DownloadFolder "download"

# Start server with latest versions
.\ModManager.ps1 -StartServer -UseLatestVersion -DownloadFolder "download"
```

## Complete Command Sequence

### Option 1: Automated Helper Script (Recommended)

Use the focused helper script for the easiest experience:

```powershell
# Run the complete workflow automatically
.\scripts\TestLatestMods.ps1

# With custom download folder
.\scripts\TestLatestMods.ps1 -DownloadFolder "test-latest"
```

**Helper Script Parameters:**
- `-DownloadFolder`: Custom download folder (default: "download")
- `-DatabaseFile`: Custom database file (default: "modlist.csv")

### Option 2: Download Latest Mods Only

If you only want to download the latest mods without server testing:

```powershell
# Download latest mods only
.\scripts\DownloadLatestMods.ps1

# With custom download folder
.\scripts\DownloadLatestMods.ps1 -DownloadFolder "latest-mods"
```

### Option 3: Manual Commands

You can also run the entire process manually:

```powershell
# Update mod database to latest versions
.\ModManager.ps1 -UpdateMods -DatabaseFile "modlist.csv" -UseCachedResponses

# Download latest mods and server files
.\ModManager.ps1 -Download -UseLatestVersion -DatabaseFile "modlist.csv" -DownloadFolder "download" -UseCachedResponses
.\ModManager.ps1 -DownloadServer -DownloadFolder "download" -UseCachedResponses

# Start server to test compatibility
.\ModManager.ps1 -StartServer -DownloadFolder "download"
```

## Understanding the Results

### Successful Test
If the server starts successfully:
- All mods are compatible with each other
- Dependencies are satisfied
- Latest versions work together

### Compatibility Issues
If the server fails to start, check for:
- **Missing Dependencies**: `requires.*fabric-api.*which is missing`
- **Version Conflicts**: `requires.*minecraft.*but only the wrong version is present`
- **Mod Conflicts**: `Remove mod '([^']+)'` or `Replace mod '([^']+)'`

### Common Issues and Solutions

#### Issue: Missing Dependencies
**Symptoms:** Server logs show "requires [mod] which is missing"
**Solution:** 
- Check if the required mod is in your modlist.csv
- Verify the mod is downloaded to the server folder
- Ensure dependency versions are compatible

#### Issue: Version Mismatches
**Symptoms:** Server logs show version conflicts
**Solution:**
- Update the conflicting mod to a compatible version
- Check Minecraft version compatibility
- Consider downgrading problematic mods

#### Issue: Mod Conflicts
**Symptoms:** Server suggests removing or replacing mods
**Solution:**
- Review the conflicting mods
- Choose which mod to keep based on functionality
- Check if there are alternative mods available

## File Structure After Testing

After running the complete process, you'll have:

```
download/
├── 1.21.5/                    # Minecraft version folder
│   ├── mods/                  # Downloaded mods
│   │   ├── fabric-api-0.128.1+1.21.7.jar
│   │   ├── cloth-config-19.0.147+fabric.jar
│   │   └── ...
│   ├── minecraft_server.1.21.5.jar
│   └── start-server.ps1
├── 1.21.6/                    # Latest version folder
│   ├── mods/
│   ├── minecraft_server.1.21.6.jar
│   └── start-server.ps1
└── apiresponse/               # Cached API responses
    └── mod-download-results.csv
```

## Performance Tips

### Use Cached Responses
Always include `-UseCachedResponses` for faster testing:
- Avoids API rate limits
- Reduces network requests
- Speeds up repeated testing

### Test in Isolation
Use separate download folders for different tests:
```powershell
.\ModManager.ps1 -Download -UseLatestVersion -DatabaseFile "modlist.csv" -DownloadFolder "test-latest" -UseCachedResponses
```

### Monitor Server Logs
Check server logs for detailed error information:
- Look for specific mod conflicts
- Identify missing dependencies
- Understand compatibility issues

## Integration with Testing Framework

This use case is automated in the testing framework:
- **Test File**: `test/tests/12-TestLatestWithServer.ps1`
- **Purpose**: Validates latest mod compatibility
- **Expected**: May show compatibility issues (exit code 1)
- **Success Rate**: Typically 75% (6/8 tests pass)

## Troubleshooting

### Server Won't Start
1. Check server logs for specific error messages
2. Verify all required mods are downloaded
3. Ensure Fabric API and loader are present
4. Check for Java version compatibility

### Download Failures
1. Check internet connection
2. Verify API endpoints are accessible
3. Try without `-UseCachedResponses` to refresh data
4. Check if mod URLs are still valid

### Performance Issues
1. Use `-UseCachedResponses` for faster testing
2. Test with smaller mod subsets first
3. Monitor disk space for large downloads
4. Consider testing during off-peak hours

## Related Documentation

- [Main README.md](README.md) - Overview of ModManager.ps1
- [TASK_LIST.md](TASK_LIST.md) - Project development status
- [test/tests/12-TestLatestWithServer.ps1](test/tests/12-TestLatestWithServer.ps1) - Automated test implementation

## Support

For issues with this use case:
1. Check the troubleshooting section above
2. Review server logs for specific error messages
3. Verify mod compatibility with Minecraft version
4. Consider testing with a subset of mods first 