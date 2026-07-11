# =============================================================================
# GitHub Mod Version Validation Module
# =============================================================================
# Validates GitHub-hosted Minecraft mod releases and extracts metadata from
# release JAR filenames such as:
#   custom-portals-4.0.31-1.21.8.jar
#   biggerenderchests-1.1.0-1.21.11.jar
# =============================================================================

try {
    if (-not (Get-Command Invoke-RestMethodWithRetry -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\..\..\Net\Invoke-RestMethodWithRetry.ps1"
    }
    if (-not (Get-Command Get-GitHubProjectInfo -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\Get-GitHubProjectInfo.ps1"
    }
    if (-not (Get-Command Get-GitHubReleases -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\Get-GitHubProjectInfo.ps1"
    }
} catch { }

function ConvertTo-GitHubSafeDateTime {
    param([object]$Value)

    if ($null -eq $Value) { return [DateTime]::MinValue }
    if ($Value -is [DateTime]) { return $Value }

    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return [DateTime]::MinValue }

    $formats = @(
        "yyyy-MM-ddTHH:mm:ssZ",
        "yyyy-MM-ddTHH:mm:ss.fffZ",
        "yyyy-MM-ddTHH:mm:ssK",
        "yyyy-MM-ddTHH:mm:ss.fffK",
        "MM/dd/yyyy HH:mm:ss",
        "M/d/yyyy HH:mm:ss",
        "dd/MM/yyyy HH:mm:ss",
        "d/M/yyyy HH:mm:ss"
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    $parsed = [DateTime]::MinValue

    if ([DateTime]::TryParseExact($text, $formats, $culture, $styles, [ref]$parsed)) { return $parsed }
    if ([DateTime]::TryParse($text, $culture, $styles, [ref]$parsed)) { return $parsed }

    return [DateTime]::MinValue
}

function ConvertTo-GitHubDisplayName {
    param([string]$RawName)

    if ([string]::IsNullOrWhiteSpace($RawName)) { return "" }

    $knownNames = @{
        "customportals" = "Custom Portals"
        "custom-portals" = "Custom Portals"
        "biggerenderchests" = "Bigger Ender Chests"
        "bigger-ender-chests" = "Bigger Ender Chests"
    }

    $name = $RawName.Trim() -replace "^mod[-_]", ""
    $compact = ($name -replace "[-_\s]", "").ToLowerInvariant()
    $hyphenated = ($name -replace "[_\s]", "-").ToLowerInvariant()

    if ($knownNames.ContainsKey($compact)) { return $knownNames[$compact] }
    if ($knownNames.ContainsKey($hyphenated)) { return $knownNames[$hyphenated] }

    $name = $name -creplace "([a-z])([A-Z])", '$1 $2'
    $name = $name -replace "[-_]", " "
    $name = $name -replace "\s+", " "
    $name = $name.Trim()

    if ([string]::IsNullOrWhiteSpace($name)) { return "" }

    return (Get-Culture).TextInfo.ToTitleCase($name.ToLowerInvariant())
}

function Get-GitHubRepoPartsFromValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $text = $Value.Trim()

    if ($text -match "^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/#?]+)") {
        return [pscustomobject]@{ Owner = $matches.owner; Repo = ($matches.repo -replace "\.git$", ""); Url = "https://github.com/$($matches.owner)/$(($matches.repo -replace '\.git$', ''))" }
    }

    if ($text -match "^(?<owner>[^/\s]+)/(?<repo>[^/\s]+)$") {
        return [pscustomobject]@{ Owner = $matches.owner; Repo = ($matches.repo -replace "\.git$", ""); Url = "https://github.com/$($matches.owner)/$(($matches.repo -replace '\.git$', ''))" }
    }

    return $null
}

function Get-GitHubJarMetadataFromFileName {
    param([string]$FileName)

    if ([string]::IsNullOrWhiteSpace($FileName)) { return $null }
    $name = [System.IO.Path]::GetFileName($FileName)
    if ($name -notmatch "(?i)\.jar$") { return $null }

    if ($name -match "^(?<id>.+?)-(?<modVersion>\d+(?:\.\d+){1,3}(?:[-+][A-Za-z0-9_.-]+)?)-(?<mcVersion>1\.\d+(?:\.\d+)?)\.jar$") {
        return [pscustomobject]@{
            Id = $matches.id
            Name = ConvertTo-GitHubDisplayName $matches.id
            Version = $matches.modVersion
            GameVersion = $matches.mcVersion
            FileName = $name
        }
    }

    return $null
}

function Test-GitHubPlayableJarAsset {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    if ($Name -notmatch "(?i)\.jar$") { return $false }
    if ($Name -match "(?i)(sources|source|javadoc|dev|api|test|tests)") { return $false }

    return $true
}

function New-GitHubValidationResponse {
    param(
        [bool]$Success,
        [string]$Error = "",
        [object]$Selected = $null,
        [object]$LatestGameAsset = $null,
        [object]$RepoInfo = $null,
        [string]$RepositoryUrl = "",
        [string]$Loader = "fabric"
    )

    if (-not $Success) {
        return @{ Success = $false; Exists = $false; Error = $Error }
    }

    if (-not $LatestGameAsset) { $LatestGameAsset = $Selected }

    $title = if ($Selected.Name) { $Selected.Name } elseif ($RepoInfo -and $RepoInfo.name) { ConvertTo-GitHubDisplayName $RepoInfo.name } else { $Selected.Id }
    $sourceUrl = if ($RepositoryUrl) { $RepositoryUrl } elseif ($RepoInfo -and $RepoInfo.html_url) { $RepoInfo.html_url } else { "" }
    $description = if ($RepoInfo -and $RepoInfo.description) { $RepoInfo.description } else { "" }
    $iconUrl = ""

    if ($RepoInfo -and $RepoInfo.owner -and $RepoInfo.owner.PSObject.Properties['avatar_url']) {
        $iconUrl = $RepoInfo.owner.avatar_url
    }

    return @{
        Success = $true
        Exists = $true
        Version = $Selected.Version
        LatestVersion = $Selected.Version
        VersionUrl = $Selected.DownloadUrl
        LatestVersionUrl = $LatestGameAsset.DownloadUrl
        DownloadUrl = $Selected.DownloadUrl
        Dependencies = ""
        FileSize = $Selected.Size
        Jar = $Selected.FileName
        LatestGameVersion = $LatestGameAsset.GameVersion
        CurrentGameVersion = $Selected.GameVersion
        ModId = $Selected.Id
        ID = $Selected.Id
        Title = $title
        Name = $title
        ProjectDescription = $description
        IconUrl = $iconUrl
        IssuesUrl = if ($sourceUrl) { "$sourceUrl/issues" } else { "" }
        SourceUrl = $sourceUrl
        WikiUrl = if ($RepoInfo -and $RepoInfo.has_wiki -and $sourceUrl) { "$sourceUrl/wiki" } else { "" }
        ClientSide = $null
        ServerSide = $null
        Loader = $Loader
    }
}

function Validate-GitHubModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModID,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [Parameter(Mandatory=$true)]
        [string]$Loader,
        [string]$GameVersion = "",
        [bool]$UseCachedResponses = $false,
        [string]$CsvPath = $null,
        [switch]$Quiet = $false
    )

    try {
        $effectiveGameVersion = if (-not [string]::IsNullOrWhiteSpace($GameVersion)) { $GameVersion } else { "1.21.8" }
        $repoParts = Get-GitHubRepoPartsFromValue -Value $ModID

        if (-not $repoParts) {
            return New-GitHubValidationResponse -Success $false -Error "Invalid GitHub repository identifier: $ModID"
        }

        if (-not $Quiet) {
            Write-Host "Validating GitHub mod $($repoParts.Owner)/$($repoParts.Repo) [Version: $Version] for $Loader/$effectiveGameVersion..." -ForegroundColor Cyan
        }

        # Direct release JAR URL: use metadata from the filename, not system-*.
        if ($ModID -match "github\.com/.+?/releases/download/.+?/(?<file>[^/?#]+\.jar)") {
            $meta = Get-GitHubJarMetadataFromFileName -FileName $matches.file
            if ($meta) {
                $selected = [pscustomobject]@{
                    Id = $meta.Id
                    Name = $meta.Name
                    Version = $meta.Version
                    GameVersion = $meta.GameVersion
                    FileName = $meta.FileName
                    DownloadUrl = $ModID
                    Size = 0
                    PublishedAt = [DateTime]::UtcNow
                }
                return New-GitHubValidationResponse -Success $true -Selected $selected -RepositoryUrl $repoParts.Url -Loader $Loader
            }
        }

        if (-not $Quiet) { Write-Host "DEBUG: Getting repository info for $($repoParts.Url)" -ForegroundColor Yellow }
        $repoInfo = Get-GitHubProjectInfo -RepositoryUrl $repoParts.Url -UseCachedResponses $UseCachedResponses -Quiet:$Quiet
        if (-not $repoInfo) { return New-GitHubValidationResponse -Success $false -Error "Failed to get repository info" }

        if (-not $Quiet) { Write-Host "DEBUG: Getting releases for $($repoParts.Url)" -ForegroundColor Yellow }
        $releases = @(Get-GitHubReleases -RepositoryUrl $repoParts.Url -UseCachedResponses $UseCachedResponses -Quiet:$Quiet)
        if ($releases.Count -eq 0) { return New-GitHubValidationResponse -Success $false -Error "No releases found in repository" }

        if (-not $Quiet) { Write-Host "DEBUG: Found $($releases.Count) releases" -ForegroundColor Yellow }

        $allAssets = @()
        foreach ($release in $releases) {
            $publishedAt = ConvertTo-GitHubSafeDateTime $release.published_at
            foreach ($asset in @($release.assets)) {
                if (-not (Test-GitHubPlayableJarAsset -Name ([string]$asset.name))) { continue }
                $meta = Get-GitHubJarMetadataFromFileName -FileName ([string]$asset.name)
                if (-not $meta) { continue }

                $allAssets += [pscustomobject]@{
                    Id = $meta.Id
                    Name = $meta.Name
                    Version = $meta.Version
                    GameVersion = $meta.GameVersion
                    FileName = $meta.FileName
                    DownloadUrl = $asset.browser_download_url
                    Size = $asset.size
                    PublishedAt = $publishedAt
                    ReleaseTag = $release.tag_name
                }
            }
        }

        if ($allAssets.Count -eq 0) {
            return New-GitHubValidationResponse -Success $false -Error "No JAR assets with parseable metadata found"
        }

        $candidates = @($allAssets)
        if ($effectiveGameVersion -and $effectiveGameVersion -notin @("latest", "current", "*")) {
            $candidates = @($candidates | Where-Object { $_.GameVersion -eq $effectiveGameVersion })
        }

        if ($Version -and $Version -notin @("latest", "current", "*")) {
            $versionCandidates = @($candidates | Where-Object { $_.Version -eq $Version })
            if ($versionCandidates.Count -gt 0) { $candidates = $versionCandidates }
        }

        if ($candidates.Count -eq 0) {
            $availableAssets = ($allAssets | Select-Object -First 20 | ForEach-Object { $_.FileName }) -join ', '
            if (-not $Quiet) {
                Write-Host "DEBUG: No JAR file found for game version $effectiveGameVersion" -ForegroundColor Red
                Write-Host "Available assets: $availableAssets" -ForegroundColor Yellow
            }
            return New-GitHubValidationResponse -Success $false -Error "No JAR file found for game version $effectiveGameVersion"
        }

        $selected = @($candidates | Sort-Object PublishedAt -Descending | Select-Object -First 1)[0]
        $latestGameAsset = @($allAssets | Sort-Object { try { [System.Version]$_.GameVersion } catch { [System.Version]"0.0.0" } } -Descending | Select-Object -First 1)[0]

        if (-not $Quiet) {
            Write-Host "✅ Found JAR: $($selected.FileName) in release $($selected.ReleaseTag)" -ForegroundColor Green
            Write-Host "DEBUG: Extracted version $($selected.Version) and game version $($selected.GameVersion) from JAR filename" -ForegroundColor Gray
        }

        return New-GitHubValidationResponse -Success $true -Selected $selected -LatestGameAsset $latestGameAsset -RepoInfo $repoInfo -RepositoryUrl $repoParts.Url -Loader $Loader
    }
    catch {
        Write-Host "Validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return New-GitHubValidationResponse -Success $false -Error $_.Exception.Message
    }
}

# Function is available for dot-sourcing
