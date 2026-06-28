# =============================================================================
# GitHub Direct URL Validation Wrapper
# =============================================================================
# GitHub release tags do not always match mod versions exactly. Some rows already
# contain the verified asset URL in CurrentVersionUrl, NextVersionUrl, or
# LatestVersionUrl. Prefer those direct URLs when they match the requested game
# version before scanning releases by tag.
# =============================================================================

if (-not $script:ValidateGitHubModVersionOriginalCommand) {
    $script:ValidateGitHubModVersionOriginalCommand = ${function:Validate-GitHubModVersion}
}

function Get-GitHubDirectAssetFileName {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return "" }
    try {
        $decoded = [System.Web.HttpUtility]::UrlDecode($Url)
        $withoutQuery = ($decoded -split '\?')[0]
        return [System.IO.Path]::GetFileName($withoutQuery)
    } catch { return "" }
}

function Test-GitHubDirectAssetUrlForGameVersion {
    param(
        [string]$Url,
        [string]$GameVersion
    )
    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    if ($Url -notmatch 'github\.com/.+/releases/download/.+\.jar') { return $false }
    if ([string]::IsNullOrWhiteSpace($GameVersion)) { return $true }
    $fileName = Get-GitHubDirectAssetFileName -Url $Url
    return ($fileName -match [regex]::Escape($GameVersion))
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

    $effectiveGameVersion = if (-not [string]::IsNullOrWhiteSpace($GameVersion)) { $GameVersion } else { "" }
    $repositoryUrl = $ModID
    if ($ModID -notmatch '^https?://') {
        if ($ModID -match '^([^/]+)/([^/]+)$') { $repositoryUrl = "https://github.com/$ModID" }
    }

    if ($CsvPath -and (Test-Path $CsvPath)) {
        try {
            $mods = Import-Csv -Path $CsvPath
            $row = $mods | Where-Object {
                $_.ID -eq $ModID -or
                $_.ID -eq ($repositoryUrl -replace '^https://github\.com/', '') -or
                $_.Url -eq $repositoryUrl -or
                $_.SourceUrl -eq $repositoryUrl
            } | Select-Object -First 1

            if ($row) {
                $candidates = @(
                    [PSCustomObject]@{ Source = 'CurrentVersionUrl'; GameVersion = $row.CurrentGameVersion; Version = $row.CurrentVersion; Url = $row.CurrentVersionUrl },
                    [PSCustomObject]@{ Source = 'LatestVersionUrl'; GameVersion = $row.LatestGameVersion; Version = $row.LatestVersion; Url = $row.LatestVersionUrl },
                    [PSCustomObject]@{ Source = 'NextVersionUrl'; GameVersion = $row.NextGameVersion; Version = $row.NextVersion; Url = $row.NextVersionUrl }
                )

                $candidate = $candidates | Where-Object {
                    ($_.GameVersion -eq $effectiveGameVersion -or [string]::IsNullOrWhiteSpace($effectiveGameVersion)) -and
                    (Test-GitHubDirectAssetUrlForGameVersion -Url $_.Url -GameVersion $effectiveGameVersion)
                } | Select-Object -First 1

                if ($candidate) {
                    $jar = Get-GitHubDirectAssetFileName -Url $candidate.Url
                    if (-not $Quiet) {
                        Write-Host "✅ GitHub direct URL matched $($row.Name) via $($candidate.Source): $jar" -ForegroundColor Green
                    }

                    $resolvedVersion = if (-not [string]::IsNullOrWhiteSpace($candidate.Version)) { $candidate.Version } else { $Version }
                    return @{
                        Success = $true
                        Exists = $true
                        Version = $resolvedVersion
                        LatestVersion = $resolvedVersion
                        VersionUrl = $candidate.Url
                        LatestVersionUrl = $candidate.Url
                        DownloadUrl = $candidate.Url
                        Dependencies = ""
                        FileSize = 0
                        Jar = $jar
                        LatestGameVersion = $effectiveGameVersion
                        Title = if ($row.Title) { $row.Title } else { $row.Name }
                        ProjectDescription = $row.ProjectDescription
                        IconUrl = $row.IconUrl
                        IssuesUrl = if ($row.IssuesUrl) { $row.IssuesUrl } else { "$repositoryUrl/issues" }
                        SourceUrl = if ($row.SourceUrl) { $row.SourceUrl } else { $repositoryUrl }
                        WikiUrl = $row.WikiUrl
                        ClientSide = $row.ClientSide
                        ServerSide = $row.ServerSide
                    }
                }
            }
        } catch {
            if (-not $Quiet) {
                Write-Host "⚠️  GitHub direct URL lookup failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    & $script:ValidateGitHubModVersionOriginalCommand -ModID $ModID -Version $Version -Loader $Loader -GameVersion $GameVersion -UseCachedResponses:$UseCachedResponses -CsvPath $CsvPath -Quiet:$Quiet
}

# Function intentionally overrides Validate-GitHubModVersion after the original module is imported.
