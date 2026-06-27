<#
.SYNOPSIS
    Lists or deletes GitHub releases that look like test releases.

.DESCRIPTION
    Safe by default: without -Delete, this script only prints the releases it would remove.
    With -Delete, it deletes matching releases using the GitHub CLI.

    By default, matching releases also have their Git tags deleted via gh release delete --cleanup-tag.
    Use -KeepTags to keep the Git tags.

.REQUIREMENTS
    - GitHub CLI installed: https://cli.github.com/
    - Authenticated GitHub CLI session: gh auth login
    - Permission to delete releases/tags in the repository

.EXAMPLES
    # Dry run
    .\tools\Remove-TestReleases.ps1

    # Delete matching test releases and cleanup tags
    .\tools\Remove-TestReleases.ps1 -Delete

    # Delete matching releases but keep Git tags
    .\tools\Remove-TestReleases.ps1 -Delete -KeepTags

    # Use a custom match pattern
    .\tools\Remove-TestReleases.ps1 -Pattern '(?i)test|draft|trial' -Delete
#>

param(
    [string]$Repo = "survivorsunited/minecraft-mods-manager",

    # Conservative default: matches release names/tags containing test as a separate token.
    # Examples matched: test, test-release, release-test, v1.0-test, TEST 1.21.11
    [string]$Pattern = '(?i)(^|[-_ .])test([-_ .]|$)',

    [switch]$Delete,
    [switch]$KeepTags,
    [int]$Limit = 1000
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install GitHub CLI first: https://cli.github.com/"
    }
}

function Get-ReleaseValue {
    param(
        [object]$Release,
        [string]$Property
    )

    if ($Release.PSObject.Properties.Name -contains $Property) {
        return [string]$Release.$Property
    }
    return ""
}

if ([string]::IsNullOrWhiteSpace($Pattern)) {
    throw "Pattern cannot be empty. Refusing to match every release."
}

Require-Command -Name "gh"

try {
    gh auth status --hostname github.com 2>$null | Out-Null
} catch {
    throw "GitHub CLI is not authenticated. Run: gh auth login"
}

Write-Host "Repository: $Repo" -ForegroundColor Cyan
Write-Host "Match pattern: $Pattern" -ForegroundColor Cyan
Write-Host "Mode: $(if ($Delete) { 'DELETE' } else { 'DRY RUN' })" -ForegroundColor Cyan
Write-Host ""

# Keep this field list compatible with current gh release list output.
# Do not request url/html_url here; many gh versions do not expose those fields for release list.
$fields = "tagName,name,isDraft,isPrerelease,publishedAt,createdAt"
$ghOutput = & gh release list --repo $Repo --limit $Limit --json $fields 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Failed to list releases from $Repo. gh output:`n$($ghOutput -join "`n")"
}

$json = ($ghOutput -join "`n").Trim()
if ([string]::IsNullOrWhiteSpace($json)) {
    Write-Host "No releases found." -ForegroundColor Yellow
    exit 0
}

$releases = @($json | ConvertFrom-Json)

if ($releases.Count -eq 0) {
    Write-Host "No releases found." -ForegroundColor Yellow
    exit 0
}

$matches = @(
    $releases | Where-Object {
        $tag = Get-ReleaseValue -Release $_ -Property "tagName"
        $name = Get-ReleaseValue -Release $_ -Property "name"
        ($tag -match $Pattern) -or ($name -match $Pattern)
    }
)

if ($matches.Count -eq 0) {
    Write-Host "No test releases matched the pattern." -ForegroundColor Green
    exit 0
}

Write-Host "Matched $($matches.Count) test release(s):" -ForegroundColor Yellow
$matches |
    Select-Object tagName, name, isDraft, isPrerelease, publishedAt |
    Format-Table -AutoSize

if (-not $Delete) {
    Write-Host ""
    Write-Host "Dry run only. Nothing was deleted." -ForegroundColor Green
    Write-Host "To delete these releases, run:" -ForegroundColor Cyan
    Write-Host "  .\tools\Remove-TestReleases.ps1 -Delete" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To keep Git tags while deleting releases, run:" -ForegroundColor Cyan
    Write-Host "  .\tools\Remove-TestReleases.ps1 -Delete -KeepTags" -ForegroundColor Cyan
    exit 0
}

Write-Host ""
Write-Host "Deleting matched releases..." -ForegroundColor Red

foreach ($release in $matches) {
    $tag = Get-ReleaseValue -Release $release -Property "tagName"
    $name = Get-ReleaseValue -Release $release -Property "name"

    if ([string]::IsNullOrWhiteSpace($tag)) {
        Write-Host "Skipping release with no tag: $name" -ForegroundColor Yellow
        continue
    }

    $args = @("release", "delete", $tag, "--repo", $Repo, "--yes")
    if (-not $KeepTags) { $args += "--cleanup-tag" }

    Write-Host "Deleting release: $tag :: $name" -ForegroundColor Yellow
    & gh @args

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to delete release/tag: $tag"
    }
}

Write-Host ""
Write-Host "Done. Deleted $($matches.Count) matching test release(s)." -ForegroundColor Green
if (-not $KeepTags) {
    Write-Host "Matching release tags were also deleted via --cleanup-tag." -ForegroundColor Green
}
