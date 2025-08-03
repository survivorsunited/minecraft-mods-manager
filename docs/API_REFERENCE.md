# API Reference and Testing Guide

This document lists all API calls made by the Minecraft Mod Manager with corresponding CURL commands for testing and debugging.

## Table of Contents

- [Environment Variables](#environment-variables)
- [Modrinth API](#modrinth-api)
- [CurseForge API](#curseforge-api)
- [Fabric Meta API](#fabric-meta-api)
- [Mojang API](#mojang-api)
- [Error Handling](#error-handling)
- [Testing Scripts](#testing-scripts)

---

## Environment Variables

Before testing, ensure these environment variables are set:

```bash
export MODRINTH_API_BASE_URL="https://api.modrinth.com/v2"
export CURSEFORGE_API_BASE_URL="https://api.curseforge.com/v1" 
export CURSEFORGE_API_KEY="your_curseforge_api_key_here"
```

---

## Modrinth API

### Base URL
```
https://api.modrinth.com/v2
```

### 1. Get Project Information

**Endpoint:** `/project/{project_id}`  
**PowerShell Function:** `Get-ModrinthProjectInfo`  
**File:** `src/Provider/Modrinth/Get-ModrinthProjectInfo.ps1`

**CURL:**
```bash
# Get Fabric API project info
curl -X GET \
  -H "Accept: application/json" \
  -H "User-Agent: MinecraftModManager/1.0" \
  "https://api.modrinth.com/v2/project/fabric-api"

# Get Sodium project info
curl -X GET \
  -H "Accept: application/json" \
  -H "User-Agent: MinecraftModManager/1.0" \
  "https://api.modrinth.com/v2/project/sodium"
```

**PowerShell:**
```powershell
# Get Fabric API project info
curl -H "Accept: application/json" -H "User-Agent: MinecraftModManager/1.0" "https://api.modrinth.com/v2/project/fabric-api"

# Get Sodium project info
curl -H "Accept: application/json" -H "User-Agent: MinecraftModManager/1.0" "https://api.modrinth.com/v2/project/sodium"
```

### 2. Get Project Versions

**Endpoint:** `/project/{project_id}/version`  
**PowerShell Function:** `Validate-ModrinthModVersion`  
**File:** `src/Provider/Modrinth/Validate-ModrinthModVersion.ps1`

**CURL:**
```bash
# Get all versions for Fabric API
curl -X GET \
  -H "Accept: application/json" \
  -H "User-Agent: MinecraftModManager/1.0" \
  "https://api.modrinth.com/v2/project/fabric-api/version"

# Get versions with filters (example)
curl -X GET \
  -H "Accept: application/json" \
  -H "User-Agent: MinecraftModManager/1.0" \
  "https://api.modrinth.com/v2/project/fabric-api/version?loaders=[\"fabric\"]&game_versions=[\"1.21.6\"]"
```

**PowerShell:**
```powershell
# Get all versions for Fabric API
curl -H "Accept: application/json" -H "User-Agent: MinecraftModManager/1.0" "https://api.modrinth.com/v2/project/fabric-api/version"

# Get versions with filters (example)
curl -H "Accept: application/json" -H "User-Agent: MinecraftModManager/1.0" 'https://api.modrinth.com/v2/project/fabric-api/version?loaders=["fabric"]&game_versions=["1.21.6"]'
```

### 3. Search Projects

**Endpoint:** `/search`  
**PowerShell Function:** `Search-ModrinthProjects`  
**File:** `src/Provider/Modrinth/Search-ModrinthProjects.ps1`

**CURL:**
```bash
# Search for mods by name
curl -X GET \
  -H "Accept: application/json" \
  -H "User-Agent: MinecraftModManager/1.0" \
  "https://api.modrinth.com/v2/search?query=sodium"

# Search with filters
curl -X GET \
  -H "Accept: application/json" \
  -H "User-Agent: MinecraftModManager/1.0" \
  "https://api.modrinth.com/v2/search?query=optimization&categories=[\"performance\"]&loaders=[\"fabric\"]&versions=[\"1.21.6\"]&limit=10"

# Advanced search with facets
curl -X GET \
  -H "Accept: application/json" \
  -H "User-Agent: MinecraftModManager/1.0" \
  "https://api.modrinth.com/v2/search?facets=[[\"categories:optimization\"],[\"versions:1.21.6\"],[\"project_type:mod\"]]"
```

**PowerShell:**
```powershell
# Search for mods by name
curl -H "Accept: application/json" -H "User-Agent: MinecraftModManager/1.0" "https://api.modrinth.com/v2/search?query=sodium"

# Search with filters
curl -H "Accept: application/json" -H "User-Agent: MinecraftModManager/1.0" 'https://api.modrinth.com/v2/search?query=optimization&categories=["performance"]&loaders=["fabric"]&versions=["1.21.6"]&limit=10'

# Advanced search with facets
curl -H "Accept: application/json" -H "User-Agent: MinecraftModManager/1.0" 'https://api.modrinth.com/v2/search?facets=[["categories:optimization"],["versions:1.21.6"],["project_type:mod"]]'
```

---

## CurseForge API

### Base URL
```
https://api.curseforge.com/v1
```

### Authentication
All CurseForge API calls require an API key in the `x-api-key` header.

### 1. Get Project Information

**Endpoint:** `/mods/{project_id}`  
**PowerShell Function:** `Get-CurseForgeProjectInfo`  
**File:** `src/Provider/CurseForge/Get-CurseForgeProjectInfo.ps1`

**CURL:**
```bash
# Get project info for Inventory HUD+ (ID: 357540)
curl -X GET \
  -H "Accept: application/json" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/mods/357540"

# Get project info for Just Enough Items (ID: 238222)
curl -X GET \
  -H "Accept: application/json" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/mods/238222"
```

**PowerShell:**
```powershell
# Get project info for Inventory HUD+ (ID: 357540)
curl -H "Accept: application/json" -H "x-api-key: $env:CURSEFORGE_API_KEY" "https://api.curseforge.com/v1/mods/357540"

# Get project info for Just Enough Items (ID: 238222)
curl -H "Accept: application/json" -H "x-api-key: $env:CURSEFORGE_API_KEY" "https://api.curseforge.com/v1/mods/238222"
```

### 2. Get Project Files/Versions

**Endpoint:** `/mods/{project_id}/files`  
**PowerShell Function:** `Validate-CurseForgeModVersion`  
**File:** `src/Provider/CurseForge/Validate-CurseForgeModVersion.ps1`

**CURL:**
```bash
# Get all files for a project
curl -X GET \
  -H "Accept: application/json" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/mods/357540/files"

# Get files with pagination
curl -X GET \
  -H "Accept: application/json" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/mods/357540/files?index=0&pageSize=50"
```

**PowerShell:**
```powershell
# Get all files for a project
curl -H "Accept: application/json" -H "x-api-key: $env:CURSEFORGE_API_KEY" "https://api.curseforge.com/v1/mods/357540/files"

# Get files with pagination
curl -H "Accept: application/json" -H "x-api-key: $env:CURSEFORGE_API_KEY" "https://api.curseforge.com/v1/mods/357540/files?index=0&pageSize=50"
```

### 3. Get Specific File Information

**Endpoint:** `/mods/{project_id}/files/{file_id}`  
**PowerShell Function:** `Get-CurseForgeFileInfo`  
**File:** `src/Provider/CurseForge/Get-CurseForgeFileInfo.ps1`

**CURL:**
```bash
# Get specific file info
curl -X GET \
  -H "Accept: application/json" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/mods/357540/files/5891692"
```

**PowerShell:**
```powershell
# Get specific file info
curl -H "Accept: application/json" -H "x-api-key: $env:CURSEFORGE_API_KEY" "https://api.curseforge.com/v1/mods/357540/files/5891692"
```

### 4. Test API Key Validity

**CURL:**
```bash
# Test API key with games endpoint (should return 200)
curl -X GET \
  -H "Accept: application/json" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/games/432"
```

**PowerShell:**
```powershell
# Test API key with games endpoint (should return 200)
curl -H "Accept: application/json" -H "x-api-key: $env:CURSEFORGE_API_KEY" "https://api.curseforge.com/v1/games/432"
```

---

## Fabric Meta API

### Base URL
```
https://meta.fabricmc.net
```

### 1. Get Loader Versions

**Endpoint:** `/v2/versions/loader/{game_version}`  
**PowerShell Function:** `Get-FabricLoaderInfo`  
**File:** `src/Provider/Fabric/Get-FabricLoaderInfo.ps1`

**CURL:**
```bash
# Get Fabric loader versions for Minecraft 1.21.6
curl -X GET \
  -H "Accept: application/json" \
  "https://meta.fabricmc.net/v2/versions/loader/1.21.6"

# Get Fabric loader versions for Minecraft 1.21.5
curl -X GET \
  -H "Accept: application/json" \
  "https://meta.fabricmc.net/v2/versions/loader/1.21.5"
```

**PowerShell:**
```powershell
# Get Fabric loader versions for Minecraft 1.21.6
curl -H "Accept: application/json" "https://meta.fabricmc.net/v2/versions/loader/1.21.6"

# Get Fabric loader versions for Minecraft 1.21.5
curl -H "Accept: application/json" "https://meta.fabricmc.net/v2/versions/loader/1.21.5"
```

### 2. Get Server JAR Download

**Endpoint:** `/v2/versions/loader/{game_version}/{loader_version}/{installer_version}/server/jar`  
**Used in:** `Download-ServerFiles`  
**File:** `src/Download/Server/Download-ServerFiles.ps1`

**CURL:**
```bash
# Download Fabric server JAR for 1.21.6
curl -L -o "fabric-server-1.21.6.jar" \
  "https://meta.fabricmc.net/v2/versions/loader/1.21.6/0.16.14/1.0.3/server/jar"

# Download Fabric server JAR for 1.21.5
curl -L -o "fabric-server-1.21.5.jar" \
  "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar"
```

**PowerShell:**
```powershell
# Download Fabric server JAR for 1.21.6
curl -L -o "fabric-server-1.21.6.jar" "https://meta.fabricmc.net/v2/versions/loader/1.21.6/0.16.14/1.0.3/server/jar"

# Download Fabric server JAR for 1.21.5
curl -L -o "fabric-server-1.21.5.jar" "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar"
```

---

## Mojang API

### 1. Version Manifest

**Endpoint:** `https://launchermeta.mojang.com/mc/game/version_manifest.json`  
**PowerShell Function:** `Get-MojangServerInfo`  
**File:** `src/Provider/Mojang/Get-MojangServerInfo.ps1`

**CURL:**
```bash
# Get Minecraft version manifest
curl -X GET \
  -H "Accept: application/json" \
  "https://launchermeta.mojang.com/mc/game/version_manifest.json"
```

**PowerShell:**
```powershell
# Get Minecraft version manifest
curl -H "Accept: application/json" "https://launchermeta.mojang.com/mc/game/version_manifest.json"
```

### 2. Specific Version Info

**CURL:**
```bash
# Get version-specific download URLs (example for 1.21.6)
curl -X GET \
  -H "Accept: application/json" \
  "https://piston-meta.mojang.com/v1/packages/177e49d3233cb6eac42f0495c0a48e719870c2ae/1.21.6.json"
```

**PowerShell:**
```powershell
# Get version-specific download URLs (example for 1.21.6)
curl -H "Accept: application/json" "https://piston-meta.mojang.com/v1/packages/177e49d3233cb6eac42f0495c0a48e719870c2ae/1.21.6.json"
```

### 3. Server JAR Downloads

**CURL:**
```bash
# Download Minecraft server 1.21.6
curl -L -o "minecraft_server.1.21.6.jar" \
  "https://piston-data.mojang.com/v1/objects/6e64dcabba3c01a7271b4fa6bd898483b794c59b/server.jar"

# Download Minecraft server 1.21.5  
curl -L -o "minecraft_server.1.21.5.jar" \
  "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar"
```

**PowerShell:**
```powershell
# Download Minecraft server 1.21.6
curl -L -o "minecraft_server.1.21.6.jar" "https://piston-data.mojang.com/v1/objects/6e64dcabba3c01a7271b4fa6bd898483b794c59b/server.jar"

# Download Minecraft server 1.21.5
curl -L -o "minecraft_server.1.21.5.jar" "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar"
```

---

## Error Handling

### Common HTTP Status Codes

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 200 | Success | Request completed successfully |
| 400 | Bad Request | Invalid parameters or malformed request |
| 401 | Unauthorized | Missing or invalid API key |
| 403 | Forbidden | API key invalid, expired, or insufficient permissions |
| 404 | Not Found | Project/file/endpoint doesn't exist |
| 429 | Rate Limited | Too many requests, wait and retry |
| 500 | Server Error | API server issue, retry later |

### Testing Error Responses

```bash
# Test invalid project ID (should return 404)
curl -X GET \
  -H "Accept: application/json" \
  "https://api.modrinth.com/v2/project/invalid-project-id"

# Test invalid CurseForge API key (should return 403)
curl -X GET \
  -H "Accept: application/json" \
  -H "x-api-key: invalid-key" \
  "https://api.curseforge.com/v1/mods/357540"
```

---

## Testing Scripts

### Test All APIs Script

```bash
#!/bin/bash
# test_apis.sh

echo "Testing Modrinth API..."
curl -s -w "Status: %{http_code}\n" \
  -H "Accept: application/json" \
  "https://api.modrinth.com/v2/project/fabric-api" | head -5

echo -e "\nTesting CurseForge API..."
curl -s -w "Status: %{http_code}\n" \
  -H "Accept: application/json" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/games/432" | head -5

echo -e "\nTesting Fabric Meta API..."
curl -s -w "Status: %{http_code}\n" \
  -H "Accept: application/json" \
  "https://meta.fabricmc.net/v2/versions/loader/1.21.6" | head -5

echo -e "\nTesting Mojang API..."
curl -s -w "Status: %{http_code}\n" \
  -H "Accept: application/json" \
  "https://launchermeta.mojang.com/mc/game/version_manifest.json" | head -5
```

### PowerShell Test Script

```powershell
# Test-APIs.ps1

# Test Modrinth API
Write-Host "Testing Modrinth API..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/fabric-api" -Method Get
    Write-Host "✓ Modrinth API: SUCCESS" -ForegroundColor Green
    Write-Host "  Project: $($response.title)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Modrinth API: FAILED" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test CurseForge API
Write-Host "`nTesting CurseForge API..." -ForegroundColor Yellow
try {
    $headers = @{ "x-api-key" = $env:CURSEFORGE_API_KEY }
    $response = Invoke-RestMethod -Uri "https://api.curseforge.com/v1/games/432" -Method Get -Headers $headers
    Write-Host "✓ CurseForge API: SUCCESS" -ForegroundColor Green
} catch {
    Write-Host "✗ CurseForge API: FAILED" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Fabric Meta API
Write-Host "`nTesting Fabric Meta API..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "https://meta.fabricmc.net/v2/versions/loader/1.21.6" -Method Get
    Write-Host "✓ Fabric Meta API: SUCCESS" -ForegroundColor Green
    Write-Host "  Found $($response.Count) loader versions" -ForegroundColor Gray
} catch {
    Write-Host "✗ Fabric Meta API: FAILED" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}
```

### Debugging Failed Requests

```bash
# Verbose curl with headers for debugging
curl -v -X GET \
  -H "Accept: application/json" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/mods/357540" 2>&1 | head -50

# Check response headers only
curl -I -X GET \
  -H "Accept: application/json" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/mods/357540"

# Test with different User-Agent
curl -X GET \
  -H "Accept: application/json" \
  -H "User-Agent: MinecraftModManager/1.0 (Testing)" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/mods/357540"
```

---

## Troubleshooting

### CurseForge 403 Forbidden

The most common issue is CurseForge returning 403 Forbidden for all requests:

1. **Check API Key**: Ensure `CURSEFORGE_API_KEY` is set correctly
2. **Test Basic Endpoint**: Try the games endpoint first
3. **Request New Key**: If all requests fail, the API key may be expired

```bash
# Test if your API key works at all
curl -w "HTTP Status: %{http_code}\n" \
  -H "x-api-key: $CURSEFORGE_API_KEY" \
  "https://api.curseforge.com/v1/games/432"
```

### Rate Limiting

If you get 429 responses, add delays between requests:

```bash
# Add delay between requests
sleep 1
curl -X GET "https://api.modrinth.com/v2/project/fabric-api"
sleep 1  
curl -X GET "https://api.modrinth.com/v2/project/sodium"
```

### Network Issues

For network debugging:

```bash
# Test connectivity to API endpoints
ping api.modrinth.com
ping api.curseforge.com
ping meta.fabricmc.net

# Test DNS resolution
nslookup api.curseforge.com
```

---

## Summary

This document covers all API endpoints used by the Minecraft Mod Manager. Use these CURL commands to:

1. **Debug API issues** - Test endpoints directly
2. **Validate API keys** - Ensure authentication works
3. **Understand data structure** - See what responses look like
4. **Troubleshoot problems** - Isolate whether issues are in the PowerShell code or API itself

For the current CurseForge 403 issue, start with the API key validation commands above.