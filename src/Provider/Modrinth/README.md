# Modrinth Provider

The Modrinth provider integrates with the Modrinth API (https://api.modrinth.com/v2) to fetch project information and validate mod versions.

## Overview

Modrinth is a modern mod hosting platform that provides:
- Comprehensive project metadata
- Version information with game version compatibility
- Dependency resolution
- Fast API responses with good rate limits

## Functions

### Get-ModrinthProjectInfo
Retrieves detailed project information from Modrinth.

**Parameters:**
- `ProjectId` (string): Modrinth project ID or slug (e.g., "fabric-api")
- `UseCachedResponses` (bool): Use cached responses if available

**Returns:**
- Project information object with metadata, versions, and dependencies

**Example:**
```powershell
$projectInfo = Get-ModrinthProjectInfo -ProjectId "fabric-api"
Write-Host "Project Title: $($projectInfo.title)"
Write-Host "Description: $($projectInfo.description)"
Write-Host "Total Downloads: $($projectInfo.downloads)"
```

### Validate-ModrinthModVersion
Validates if a specific mod version exists and is compatible.

**Parameters:**
- `ModID` (string): Modrinth project ID or slug
- `Version` (string): Version string to validate
- `Loader` (string): Mod loader (fabric, forge, etc.)
- `GameVersion` (string): Minecraft version (optional)
- `ResponseFolder` (string): Folder for caching responses

**Returns:**
- Validation result object with success status and version information

**Example:**
```powershell
$result = Validate-ModrinthModVersion -ModID "fabric-api" -Version "0.127.1+1.21.5" -Loader "fabric"
if ($result.Success) {
    Write-Host "✓ Version is valid"
    Write-Host "Download URL: $($result.VersionUrl)"
}
```

## API Integration

### Base URL
```
https://api.modrinth.com/v2
```

### Key Endpoints
- **Project Info**: `/project/{id}`
- **Project Versions**: `/project/{id}/version`
- **Version Details**: `/version/{id}`

### Rate Limits
- 300 requests per minute per IP
- Burst allowance for short-term spikes
- No API key required for basic usage

## Response Format

### Project Information
```json
{
  "id": "P7dR8mSH",
  "slug": "fabric-api",
  "project_type": "mod",
  "team": "team-id",
  "title": "Fabric API",
  "description": "Lightweight and modular API...",
  "body": "Full project description...",
  "published": "2019-05-28T18:46:00.213194Z",
  "updated": "2025-01-15T10:30:00.123456Z",
  "approved": "2019-05-28T18:46:00.213194Z",
  "status": "approved",
  "downloads": 50000000,
  "followers": 15000,
  "categories": ["library", "fabric"],
  "additional_categories": [],
  "game_versions": ["1.21.5", "1.21.6", "1.21.7"],
  "loaders": ["fabric"],
  "versions": ["version-id-1", "version-id-2"],
  "icon_url": "https://cdn.modrinth.com/data/P7dR8mSH/icon.png",
  "issues_url": "https://github.com/FabricMC/fabric/issues",
  "source_url": "https://github.com/FabricMC/fabric",
  "wiki_url": "https://fabricmc.net/wiki/",
  "discord_url": null,
  "donation_urls": []
}
```

### Version Information
```json
{
  "id": "version-id-1",
  "project_id": "P7dR8mSH",
  "author_id": "author-id",
  "featured": true,
  "name": "Fabric API 0.127.1+1.21.5",
  "version_number": "0.127.1+1.21.5",
  "changelog": "Version changelog...",
  "changelog_url": null,
  "date_published": "2025-01-15T10:30:00.123456Z",
  "downloads": 1000000,
  "version_type": "release",
  "status": "listed",
  "requested_status": null,
  "files": [
    {
      "hashes": {
        "sha512": "hash-value",
        "sha1": "hash-value"
      },
      "url": "https://cdn.modrinth.com/data/P7dR8mSH/versions/version-id-1/fabric-api-0.127.1+1.21.5.jar",
      "filename": "fabric-api-0.127.1+1.21.5.jar",
      "primary": true,
      "size": 2500000,
      "file_type": null
    }
  ],
  "dependencies": [
    {
      "version_id": null,
      "project_id": "dependency-project-id",
      "file_name": null,
      "dependency_type": "required"
    }
  ],
  "game_versions": ["1.21.5"],
  "loaders": ["fabric"]
}
```

## Error Handling

### Common Error Responses

#### 404 Not Found
```json
{
  "error": "not_found",
  "description": "The specified project was not found"
}
```

#### 429 Rate Limited
```json
{
  "error": "ratelimited",
  "description": "You are being rate limited"
}
```

### Error Handling in Code
```powershell
try {
    $projectInfo = Get-ModrinthProjectInfo -ProjectId "invalid-project"
} catch {
    if ($_.Exception.Message -match "404") {
        Write-Warning "Project not found"
    } elseif ($_.Exception.Message -match "429") {
        Write-Warning "Rate limited - waiting before retry"
        Start-Sleep -Seconds 60
    } else {
        Write-Error "Unexpected error: $($_.Exception.Message)"
    }
}
```

## Caching Strategy

### Cache Structure
```
apiresponse/modrinth/
├── fabric-api-project.json          # Project information
├── fabric-api-versions.json         # Version list
└── version-{id}-details.json        # Individual version details
```

### Cache Duration
- **Project Info**: 1 hour
- **Version Lists**: 30 minutes
- **Version Details**: 24 hours

### Cache Usage
```powershell
# Use cached responses
$projectInfo = Get-ModrinthProjectInfo -ProjectId "fabric-api" -UseCachedResponses $true

# Force fresh API call
$projectInfo = Get-ModrinthProjectInfo -ProjectId "fabric-api" -UseCachedResponses $false
```

## Version Matching

### Version Format
Modrinth versions follow semantic versioning with game version suffixes:
- `0.127.1+1.21.5` - Mod version 0.127.1 for Minecraft 1.21.5
- `1.0.0-alpha.1+1.21.6` - Alpha version for Minecraft 1.21.6
- `2.5.3+fabric-1.21.5` - Explicit loader specification

### Matching Logic
1. **Exact Match**: Direct version string comparison
2. **Partial Match**: Match major.minor versions
3. **Latest Match**: Use latest version for game version
4. **Fallback**: Use latest available version

### Example Matching
```powershell
# These all match the same version
$version1 = Validate-ModrinthModVersion -ModID "fabric-api" -Version "0.127.1+1.21.5"
$version2 = Validate-ModrinthModVersion -ModID "fabric-api" -Version "0.127.1" -GameVersion "1.21.5"
$version3 = Validate-ModrinthModVersion -ModID "fabric-api" -Version "latest" -GameVersion "1.21.5"
```

## Dependencies

### Dependency Types
- **required**: Must be present for mod to function
- **optional**: Enhances functionality but not required
- **incompatible**: Cannot be used together
- **embedded**: Included within the mod file

### Dependency Resolution
```powershell
$projectInfo = Get-ModrinthProjectInfo -ProjectId "fabric-api"
foreach ($version in $projectInfo.versions) {
    $versionDetails = Get-ModrinthVersionInfo -VersionId $version
    foreach ($dependency in $versionDetails.dependencies) {
        if ($dependency.dependency_type -eq "required") {
            Write-Host "Required dependency: $($dependency.project_id)"
        }
    }
}
```

## Best Practices

### Performance Optimization
1. **Use Caching**: Enable cached responses for repeated requests
2. **Batch Requests**: Group multiple API calls when possible
3. **Rate Limiting**: Respect API limits to avoid throttling

### Error Resilience
1. **Retry Logic**: Implement exponential backoff for transient failures
2. **Fallback Options**: Have alternative data sources when available
3. **Graceful Degradation**: Continue operation with reduced functionality

### Version Management
1. **Validate Compatibility**: Check game version and loader compatibility
2. **Track Dependencies**: Maintain dependency graphs for complex setups
3. **Update Notifications**: Monitor for new versions and security updates

## Testing

### Unit Tests
Test individual functions with known data:
```powershell
# Test valid project
$result = Get-ModrinthProjectInfo -ProjectId "fabric-api"
Assert-NotNull $result
Assert-Equal "Fabric API" $result.title

# Test invalid project
$result = Get-ModrinthProjectInfo -ProjectId "invalid-project-12345"
Assert-Null $result
```

### Integration Tests
Test complete workflows:
```powershell
# Test version validation workflow
$validation = Validate-ModrinthModVersion -ModID "fabric-api" -Version "0.127.1+1.21.5" -Loader "fabric"
Assert-True $validation.Success
Assert-NotNull $validation.VersionUrl
```

## Troubleshooting

### Common Issues

1. **Version Not Found**:
   - Verify exact version string format
   - Check if version exists for specified game version
   - Try using version ID instead of version number

2. **Rate Limiting**:
   - Enable response caching
   - Add delays between requests
   - Consider API key for higher limits (if available)

3. **Network Timeouts**:
   - Increase timeout values
   - Check internet connectivity
   - Verify API endpoint availability

### Debug Information
Enable verbose logging to see detailed API interactions:
```powershell
$VerbosePreference = "Continue"
$result = Validate-ModrinthModVersion -ModID "fabric-api" -Version "0.127.1+1.21.5" -Loader "fabric" -Verbose
```

This will show:
- API URLs being called
- Response cache hits/misses
- Version matching logic
- Error details and stack traces