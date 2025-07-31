# CurseForge Provider

The CurseForge provider integrates with the CurseForge API (https://www.curseforge.com/api/v1) to fetch project information and validate mod versions for CurseForge-hosted mods.

## Overview

CurseForge is one of the largest mod hosting platforms, providing:
- Extensive mod library with detailed metadata
- File-based version management system
- Advanced search and filtering capabilities
- Direct download URLs with CDN support

## Functions

### Get-CurseForgeProjectInfo
Retrieves detailed project information from CurseForge.

**Parameters:**
- `ProjectId` (string): CurseForge project ID (numeric, e.g., "238222")
- `UseCachedResponses` (bool): Use cached responses if available

**Returns:**
- Project information object with metadata, files, and categories

**Example:**
```powershell
$projectInfo = Get-CurseForgeProjectInfo -ProjectId "238222"
Write-Host "Project Name: $($projectInfo.name)"
Write-Host "Downloads: $($projectInfo.downloadCount)"
Write-Host "Game Versions: $($projectInfo.latestFilesIndexes.gameVersion -join ', ')"
```

### Get-CurseForgeFileInfo
Retrieves information about a specific file from CurseForge.

**Parameters:**
- `ProjectId` (string): CurseForge project ID
- `FileId` (string): CurseForge file ID
- `UseCachedResponses` (bool): Use cached responses if available

**Returns:**
- File information object with download URL, dependencies, and compatibility

**Example:**
```powershell
$fileInfo = Get-CurseForgeFileInfo -ProjectId "238222" -FileId "123456"
Write-Host "File Name: $($fileInfo.fileName)"
Write-Host "Download URL: $($fileInfo.downloadUrl)"
Write-Host "Game Versions: $($fileInfo.gameVersions -join ', ')"
```

### Validate-CurseForgeModVersion
Validates if a specific mod version exists and is compatible.

**Parameters:**
- `ModID` (string): CurseForge project ID
- `FileID` (string): CurseForge file ID to validate
- `GameVersion` (string): Minecraft version (optional)
- `Loader` (string): Mod loader (fabric, forge, etc.)
- `ResponseFolder` (string): Folder for caching responses

**Returns:**
- Validation result object with success status and file information

**Example:**
```powershell
$result = Validate-CurseForgeModVersion -ModID "238222" -FileID "123456" -Loader "fabric"
if ($result.Success) {
    Write-Host "✓ File is valid"
    Write-Host "Download URL: $($result.DownloadUrl)"
}
```

## API Integration

### Base URL
```
https://www.curseforge.com/api/v1
```

### Authentication
CurseForge API requires an API key for most operations:
```powershell
$env:CURSEFORGE_API_KEY = "your-api-key-here"
```

Get your API key from: https://console.curseforge.com/

### Key Endpoints
- **Mod Info**: `/mods/{modId}`
- **Mod Files**: `/mods/{modId}/files`
- **File Info**: `/mods/{modId}/files/{fileId}`
- **File Download**: `/mods/{modId}/files/{fileId}/download`

### Rate Limits
- **Without API Key**: 50 requests per hour
- **With API Key**: 1000 requests per hour
- **Burst**: Short-term bursts allowed

## Response Format

### Project Information
```json
{
  "data": {
    "id": 238222,
    "gameId": 432,
    "name": "Inventory HUD+",
    "slug": "inventory-hud-forge",
    "links": {
      "websiteUrl": "https://www.curseforge.com/minecraft/mc-mods/inventory-hud-forge",
      "wikiUrl": null,
      "issuesUrl": "https://github.com/example/inventory-hud/issues",
      "sourceUrl": "https://github.com/example/inventory-hud"
    },
    "summary": "Enhanced inventory display with customizable HUD",
    "status": 4,
    "downloadCount": 1500000,
    "isFeatured": false,
    "primaryCategoryId": 420,
    "categories": [
      {
        "id": 420,
        "gameId": 432,
        "name": "Client-side",
        "slug": "client-side"
      }
    ],
    "classId": 6,
    "authors": [
      {
        "id": 12345,
        "name": "ModAuthor",
        "url": "https://www.curseforge.com/members/modauthor"
      }
    ],
    "logo": {
      "id": 67890,
      "modId": 238222,
      "title": "inventory-hud-logo.png",
      "description": "",
      "thumbnailUrl": "https://media.forgecdn.net/avatars/thumbnails/123/456/256/256/6361234567890.png",
      "url": "https://media.forgecdn.net/avatars/123/456/6361234567890.png"
    },
    "screenshots": [],
    "mainFileId": 3456789,
    "latestFiles": [
      {
        "id": 3456789,
        "gameId": 432,
        "modId": 238222,
        "isAvailable": true,
        "displayName": "InventoryHUD-1.21.5-3.4.7.jar",
        "fileName": "InventoryHUD-1.21.5-3.4.7.jar",
        "releaseType": 1,
        "fileStatus": 4,
        "hashes": [
          {
            "value": "sha1-hash-value",
            "algo": 1
          }
        ],
        "fileDate": "2025-01-15T10:30:00.123Z",
        "fileLength": 150000,
        "downloadCount": 50000,
        "downloadUrl": "https://www.curseforge.com/api/v1/mods/238222/files/3456789/download",
        "gameVersions": ["1.21.5"],
        "sortableGameVersions": [
          {
            "gameVersionName": "1.21.5",
            "gameVersionPadded": "0000000001.0000000021.0000000005",
            "gameVersion": "1.21.5",
            "gameVersionReleaseDate": "2024-12-03T00:00:00Z",
            "gameVersionTypeId": 73250
          }
        ],
        "dependencies": [
          {
            "modId": 306612,
            "relationType": 3
          }
        ],
        "exposeAsAlternative": null,
        "parentProjectFileId": null,
        "alternateFileId": 0,
        "isServerPack": false,
        "serverPackFileId": null,
        "hasInstallScript": false,
        "gameVersionDateReleased": "2024-12-03T00:00:00Z",
        "gameVersionMappingId": 7498058,
        "gameVersionId": 10841,
        "gameVersionFlavor": null
      }
    ],
    "latestFilesIndexes": [
      {
        "gameVersion": "1.21.5",
        "fileId": 3456789,
        "filename": "InventoryHUD-1.21.5-3.4.7.jar",
        "releaseType": 1,
        "gameVersionTypeId": 73250,
        "modLoader": 4
      }
    ],
    "dateCreated": "2016-05-15T10:30:00.123Z",
    "dateModified": "2025-01-15T10:30:00.123Z",
    "dateReleased": "2025-01-15T10:30:00.123Z",
    "allowModDistribution": true,
    "gamePopularityRank": 150,
    "isAvailable": true,
    "thumbsUpCount": 500
  }
}
```

### File Information
```json
{
  "data": {
    "id": 3456789,
    "gameId": 432,
    "modId": 238222,
    "isAvailable": true,
    "displayName": "InventoryHUD-1.21.5-3.4.7.jar",
    "fileName": "InventoryHUD-1.21.5-3.4.7.jar",
    "releaseType": 1,
    "fileStatus": 4,
    "hashes": [
      {
        "value": "sha1-hash-value",
        "algo": 1
      }
    ],
    "fileDate": "2025-01-15T10:30:00.123Z",
    "fileLength": 150000,
    "downloadCount": 50000,
    "downloadUrl": "https://www.curseforge.com/api/v1/mods/238222/files/3456789/download",
    "gameVersions": ["1.21.5"],
    "sortableGameVersions": [
      {
        "gameVersionName": "1.21.5",
        "gameVersionPadded": "0000000001.0000000021.0000000005",
        "gameVersion": "1.21.5",
        "gameVersionReleaseDate": "2024-12-03T00:00:00Z",
        "gameVersionTypeId": 73250
      }
    ],
    "dependencies": [
      {
        "modId": 306612,
        "relationType": 3
      }
    ],
    "modules": [
      {
        "name": "META-INF",
        "fingerprint": 2085616893
      },
      {
        "name": "inventory-hud.jar",
        "fingerprint": 1234567890
      }
    ]
  }
}
```

## Error Handling

### Common Error Responses

#### 401 Unauthorized
```json
{
  "error": "Unauthorized",
  "errorMessage": "API key is required"
}
```

#### 403 Forbidden
```json
{
  "error": "Forbidden",
  "errorMessage": "Invalid API key or insufficient permissions"
}
```

#### 404 Not Found
```json
{
  "error": "Not Found",
  "errorMessage": "The specified mod or file was not found"
}
```

#### 429 Rate Limited
```json
{
  "error": "Too Many Requests",
  "errorMessage": "Rate limit exceeded"
}
```

### Error Handling in Code
```powershell
try {
    $projectInfo = Get-CurseForgeProjectInfo -ProjectId "999999"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    switch ($statusCode) {
        401 { Write-Warning "API key required - set CURSEFORGE_API_KEY environment variable" }
        403 { Write-Warning "Invalid API key or insufficient permissions" }
        404 { Write-Warning "Project not found" }
        429 { 
            Write-Warning "Rate limited - waiting before retry"
            Start-Sleep -Seconds 3600  # Wait 1 hour
        }
        default { Write-Error "Unexpected error: $($_.Exception.Message)" }
    }
}
```

## Caching Strategy

### Cache Structure
```
apiresponse/curseforge/
├── 238222-curseforge-project.json   # Project information
├── 238222-curseforge-files.json     # File list
└── 238222-3456789-file.json         # Individual file details
```

### Cache Duration
- **Project Info**: 2 hours
- **File Lists**: 1 hour  
- **File Details**: 24 hours

### Cache Usage
```powershell
# Use cached responses
$projectInfo = Get-CurseForgeProjectInfo -ProjectId "238222" -UseCachedResponses $true

# Force fresh API call
$projectInfo = Get-CurseForgeProjectInfo -ProjectId "238222" -UseCachedResponses $false
```

## File Management

### File Types
CurseForge uses release types to categorize files:
- **1**: Release (stable)
- **2**: Beta (testing)
- **3**: Alpha (experimental)

### File Status
Files have status codes indicating availability:
- **1**: Processing
- **2**: Changes Required
- **3**: Under Review
- **4**: Approved (available)
- **5**: Rejected
- **6**: Malware Detected
- **7**: Deleted
- **8**: Archived
- **9**: Testing
- **10**: Released
- **11**: Ready for Review
- **12**: Deprecated
- **13**: Baking
- **14**: Awaiting Publishing
- **15**: Failed Publishing

### Dependency Types
Dependencies have relationship types:
- **1**: Embedded Library
- **2**: Optional Dependency  
- **3**: Required Dependency
- **4**: Tool
- **5**: Incompatible
- **6**: Include

### Example File Management
```powershell
$projectInfo = Get-CurseForgeProjectInfo -ProjectId "238222"
foreach ($file in $projectInfo.data.latestFiles) {
    $releaseType = switch ($file.releaseType) {
        1 { "Release" }
        2 { "Beta" }
        3 { "Alpha" }
        default { "Unknown" }
    }
    
    if ($file.fileStatus -eq 4) {  # Approved
        Write-Host "✓ $($file.displayName) ($releaseType)"
        
        # Check dependencies
        foreach ($dep in $file.dependencies) {
            $relationType = switch ($dep.relationType) {
                1 { "Embedded" }
                2 { "Optional" }
                3 { "Required" }
                4 { "Tool" }
                5 { "Incompatible" }
                6 { "Include" }
                default { "Unknown" }
            }
            Write-Host "  Dependency: $($dep.modId) ($relationType)"
        }
    }
}
```

## Version Matching

### File Identification
CurseForge uses numeric file IDs rather than semantic versioning:
- Each file has a unique numeric ID
- Files are associated with game versions
- Mod loaders are specified per file

### Matching Logic
1. **Direct File ID**: Use specific file ID if known
2. **Latest for Game Version**: Find latest file for specific Minecraft version
3. **Release Type Priority**: Prefer Release > Beta > Alpha
4. **Loader Compatibility**: Match specified mod loader

### Example Matching
```powershell
# Find latest release file for Minecraft 1.21.5
$projectInfo = Get-CurseForgeProjectInfo -ProjectId "238222"
$latestFile = $projectInfo.data.latestFiles | 
    Where-Object { $_.gameVersions -contains "1.21.5" -and $_.releaseType -eq 1 } |
    Sort-Object fileDate -Descending |
    Select-Object -First 1

if ($latestFile) {
    Write-Host "Latest file: $($latestFile.displayName)"
    Write-Host "File ID: $($latestFile.id)"
    Write-Host "Download: $($latestFile.downloadUrl)"
}
```

## Best Practices

### API Key Management
1. **Secure Storage**: Store API key in environment variables, not code
2. **Key Rotation**: Regularly rotate API keys for security
3. **Access Control**: Use separate keys for different applications

### Performance Optimization
1. **Caching**: Aggressive caching due to strict rate limits
2. **Batch Operations**: Group related API calls when possible
3. **Conditional Requests**: Use ETags and Last-Modified headers

### Error Resilience
1. **Rate Limit Handling**: Implement proper backoff strategies
2. **Fallback Data**: Use cached data when API is unavailable  
3. **Retry Logic**: Retry transient failures with exponential backoff

## Testing

### Unit Tests
Test individual functions with known project IDs:
```powershell
# Test valid project
$result = Get-CurseForgeProjectInfo -ProjectId "238222"
Assert-NotNull $result
Assert-Equal "Inventory HUD+" $result.data.name

# Test invalid project
$result = Get-CurseForgeProjectInfo -ProjectId "999999999"
Assert-Null $result
```

### Integration Tests
Test complete workflows:
```powershell
# Test file validation workflow
$validation = Validate-CurseForgeModVersion -ModID "238222" -FileID "3456789" -Loader "fabric"
Assert-True $validation.Success
Assert-NotNull $validation.DownloadUrl
```

## Troubleshooting

### Common Issues

1. **403 Forbidden**:
   - Verify API key is set: `$env:CURSEFORGE_API_KEY`
   - Check API key permissions on CurseForge console
   - Ensure key hasn't expired

2. **Rate Limiting**:
   - Enable aggressive caching
   - Implement request queuing
   - Consider multiple API keys for higher throughput

3. **File Not Available**:
   - Check file status (must be 4 for approved)
   - Verify game version compatibility
   - Check if file was deleted or archived

4. **Download Issues**:
   - Use direct download URLs from API response
   - Handle redirect responses properly
   - Check file hash after download

### Debug Information
Enable verbose logging for detailed API interactions:
```powershell
$VerbosePreference = "Continue"
$result = Validate-CurseForgeModVersion -ModID "238222" -FileID "3456789" -Loader "fabric" -Verbose
```

This will show:
- API endpoints being called
- HTTP headers and authentication
- Response status codes and content
- Cache hit/miss information
- File validation steps