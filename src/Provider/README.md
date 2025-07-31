# Provider System

The Provider system is a modular architecture for integrating with different API providers for Minecraft mod management. Each provider implements a consistent interface for fetching project information, validating versions, and handling API-specific requirements.

## Architecture

### Common Interface
All providers implement common functions accessed through `Provider/Common.ps1`:
- **Validate-ModVersion**: Universal validation function that auto-detects provider
- **Get-ProviderFromUrl**: Determines provider type from URLs
- **Invoke-ApiWithRateLimit**: Handles rate limiting and caching

### Provider Structure
Each provider follows a consistent folder structure:
```
Provider/{ProviderName}/
├── README.md              # Provider-specific documentation
├── Read.ps1               # Project information retrieval functions
└── Validate.ps1           # Version validation functions
```

## Supported Providers

### Modrinth
- **API**: https://api.modrinth.com/v2
- **Functions**: `Get-ModrinthProjectInfo`, `Validate-ModrinthModVersion`
- **Features**: Project info, version validation, dependency resolution
- **Rate Limits**: Moderate (built-in rate limiting)

### CurseForge
- **API**: https://www.curseforge.com/api/v1
- **Functions**: `Get-CurseForgeProjectInfo`, `Get-CurseForgeFileInfo`, `Validate-CurseForgeModVersion`
- **Features**: File-based versioning, direct download URLs
- **Rate Limits**: Strict (requires API key for higher limits)

### Fabric
- **API**: https://meta.fabricmc.net
- **Functions**: `Get-FabricLoaderInfo`, `Get-FabricServerInfo`
- **Features**: Loader versions, server launcher information
- **Rate Limits**: None (public API)

### Mojang
- **API**: https://piston-data.mojang.com
- **Functions**: `Get-MojangServerInfo`, `Get-MojangVersionInfo`
- **Features**: Official server JARs, version manifests
- **Rate Limits**: Moderate

## Usage Examples

### Basic Validation
```powershell
# Auto-detect provider and validate
$result = Validate-ModVersion -ModId "fabric-api" -Version "0.127.1+1.21.5" -Loader "fabric"

# Check if mod exists and version is valid
if ($result.Exists) {
    Write-Host "✓ Mod version is valid"
    Write-Host "Latest version: $($result.LatestVersion)"
}
```

### Provider-Specific Functions
```powershell
# Get Modrinth project information
$projectInfo = Get-ModrinthProjectInfo -ProjectId "fabric-api"

# Get CurseForge file information
$fileInfo = Get-CurseForgeFileInfo -ProjectId "238222" -FileId "123456"

# Get Fabric loader versions
$loaderInfo = Get-FabricLoaderInfo -GameVersion "1.21.5"
```

### Response Caching
```powershell
# Use cached responses for faster testing
$result = Validate-ModVersion -ModId "fabric-api" -Version "0.127.1+1.21.5" -Loader "fabric" -UseCachedResponses $true
```

## Configuration

### Environment Variables
```powershell
# API base URLs
$env:MODRINTH_API_BASE_URL = "https://api.modrinth.com/v2"
$env:CURSEFORGE_API_BASE_URL = "https://www.curseforge.com/api/v1"

# API keys (optional but recommended)
$env:CURSEFORGE_API_KEY = "your-api-key"

# Response caching
$env:APIRESPONSE_MODRINTH_SUBFOLDER = "modrinth"
$env:APIRESPONSE_CURSEFORGE_SUBFOLDER = "curseforge"
```

### Rate Limiting
The system includes built-in rate limiting to respect API limits:
- **Modrinth**: 300 requests per minute
- **CurseForge**: 1000 requests per hour (with API key)
- **Fabric/Mojang**: No explicit limits

## Adding New Providers

To add a new provider:

1. **Create Provider Folder**:
   ```
   src/Provider/NewProvider/
   ├── README.md
   ├── Read.ps1
   └── Validate.ps1
   ```

2. **Implement Required Functions**:
   - `Get-{Provider}ProjectInfo`: Retrieve project information
   - `Validate-{Provider}ModVersion`: Validate specific versions

3. **Update Common.ps1**:
   - Add provider detection logic to `Get-ProviderFromUrl`
   - Add provider-specific wrapper in `Validate-ModVersion`

4. **Add Tests**:
   - Unit tests in `test/tests/56-TestProviderUnitTests.ps1`
   - Functional tests in `test/tests/57-TestProviderFunctionalTests.ps1`

## Error Handling

The provider system includes comprehensive error handling:

### Network Errors
```powershell
try {
    $result = Get-ModrinthProjectInfo -ProjectId "invalid-project"
} catch {
    Write-Warning "API request failed: $($_.Exception.Message)"
}
```

### Rate Limiting
```powershell
# Automatic retry with backoff
$result = Invoke-ApiWithRateLimit -Url $apiUrl -Method "GET"
```

### Version Not Found
```powershell
$result = Validate-ModVersion -ModId "fabric-api" -Version "999.999.999" -Loader "fabric"
if (-not $result.Exists) {
    Write-Warning "Version not found: $($result.Message)"
}
```

## Testing

### Unit Tests
Run provider unit tests to verify individual functions:
```powershell
.\test\tests\56-TestProviderUnitTests.ps1
```

### Functional Tests
Run end-to-end functional tests:
```powershell
.\test\tests\57-TestProviderFunctionalTests.ps1
```

### Test Coverage
- **Unit Tests**: 20/20 passing (100% success rate)
- **Functional Tests**: 13/22 passing (59% success rate)
- **Integration Tests**: Included in main test suite

## Performance

### Caching Strategy
- **Project Info**: Cached for 1 hour
- **Version Lists**: Cached for 30 minutes
- **File Responses**: Cached for 24 hours

### Performance Metrics
- **Cold Request**: ~500-1000ms per API call
- **Cached Request**: ~1-5ms per response
- **Batch Processing**: Automatic batching for multiple requests

## Troubleshooting

### Common Issues

1. **403 Forbidden (CurseForge)**:
   ```powershell
   $env:CURSEFORGE_API_KEY = "your-api-key"
   ```

2. **Version Not Found**:
   - Check exact version format in API response
   - Verify loader compatibility
   - Check game version support

3. **Rate Limiting**:
   - Enable caching with `-UseCachedResponses $true`
   - Reduce concurrent requests
   - Implement request delays

### Debug Mode
Enable debug output for troubleshooting:
```powershell
$VerbosePreference = "Continue"
$result = Validate-ModVersion -ModId "fabric-api" -Version "0.127.1+1.21.5" -Loader "fabric" -Verbose
```

## API Documentation

Each provider has specific API documentation:
- **Modrinth**: [API Docs](https://docs.modrinth.com/api-spec/)
- **CurseForge**: [API Docs](https://docs.curseforge.com/)
- **Fabric**: [Meta API](https://fabricmc.net/develop/)
- **Mojang**: [Version Manifest](https://minecraft.wiki/w/Version_manifest.json)