# GitHub Provider

The GitHub provider enables adding and managing Minecraft mods directly from GitHub repositories. It automatically detects JAR files in GitHub releases and extracts version information.

## Features

- **Repository Detection**: Automatically detects GitHub repository URLs
- **Release Parsing**: Fetches releases from GitHub API
- **JAR File Detection**: Finds JAR files matching pattern `*-<version>.jar` in release assets
- **Version Extraction**: Extracts version information from release tags and JAR filenames
- **API Caching**: Caches API responses for faster subsequent operations

## Usage

### Adding a Mod from GitHub

```powershell
# Add mod using GitHub repository URL
Add-ModToDatabase -AddModUrl "https://github.com/survivorsunited/mod-bigger-ender-chests" -AddModLoader "fabric" -AddModGameVersion "1.21.8"
```

### Validating a GitHub Mod

```powershell
# Validate mod version
Validate-ModVersion -ModId "https://github.com/survivorsunited/mod-bigger-ender-chests" -Version "1.1.0" -Loader "fabric" -GameVersion "1.21.8"
```

## API Endpoints

- **Repository Info**: `https://api.github.com/repos/{owner}/{repo}`
- **Releases**: `https://api.github.com/repos/{owner}/{repo}/releases`

## JAR File Pattern

The provider looks for JAR files matching the pattern:
- `*-<version>-<game version>.jar` (e.g., `mod-bigger-ender-chests-1.1.0-1.21.8.jar`)

The matching logic follows this priority:
1. Full pattern match: `*-<version>-<game version>.jar` (preferred)
2. Version-only pattern: `*-<version>.jar` (fallback)
3. Any `.jar` file in release assets (last resort)

This ensures the correct JAR file is selected based on both mod version and Minecraft game version.

## Version Keywords

Supported version keywords:
- `latest` - Gets the most recent release
- `current` - Uses version from database or falls back to latest
- Specific version (e.g., `1.1.0`) - Matches release tag

## Caching

API responses are cached in:
- `.cache/apiresponse/github/{owner}-{repo}.json` - Repository info
- `.cache/apiresponse/github/{owner}-{repo}-releases.json` - Releases list

Cache expires after 5 minutes by default.

## Error Handling

The provider handles:
- Invalid repository URLs
- Missing releases
- Missing JAR files in releases
- API rate limiting (via retry mechanism)
- Network failures

## Examples

### Example Repository Structure

```
https://github.com/survivorsunited/mod-bigger-ender-chests
├── Releases
│   ├── v1.1.0
│   │   └── mod-bigger-ender-chests-1.1.0-1.21.8.jar
│   ├── v1.0.0
│   │   └── mod-bigger-ender-chests-1.0.0-1.21.7.jar
```

### Database Entry

When added to the database, a GitHub mod will have:
- **ID**: `owner/repo` (e.g., `survivorsunited/mod-bigger-ender-chests`)
- **ApiSource**: `github`
- **Host**: `github`
- **Url**: Full GitHub repository URL

## Limitations

- Does not provide dependency information (GitHub releases don't include dependency metadata)
- Requires releases to be published (not draft releases)
- JAR files must be attached as release assets (not in source code)

## Related Functions

- `Get-GitHubProjectInfo` - Fetches repository information
- `Get-GitHubReleases` - Fetches all releases from a repository
- `Validate-GitHubModVersion` - Validates a specific mod version

