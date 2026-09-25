# GitHub Direct Release URL Tests
# Ensures parseable GitHub release asset URLs are stored as owner/repo rows, not system-* rows.

. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = "108-TestGitHubDirectReleaseUrl.ps1"

Write-Host "Minecraft Mod Manager - GitHub Direct Release URL Tests" -ForegroundColor $Colors.Header
Write-Host "=======================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestDbPath = Join-Path $TestOutputDir "github-direct-release-url-test.csv"
$TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"

$assetUrl = "https://github.com/survivorsunited/mod-bigger-ender-chests/releases/download/v2026.2.25/biggerenderchests-1.1.0-1.21.11.jar"
$canonicalRepoUrl = "https://github.com/survivorsunited/mod-bigger-ender-chests"
$canonicalId = "survivorsunited/mod-bigger-ender-chests"

Write-TestHeader "Test Environment Setup"

$header = 'Group,Type,CurrentGameVersion,ID,Loader,CurrentVersion,Name,Description,Category,Jar,NextVersion,NextVersionUrl,NextGameVersion,LatestVersion,LatestVersionUrl,LatestGameVersion,Url,CurrentVersionUrl,UrlDirect,CurrentDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependencies,LatestDependenciesRequired,LatestDependenciesOptional,Host,ApiSource,ClientSide,ServerSide,Title,ProjectDescription,IconUrl,IssuesUrl,SourceUrl,WikiUrl,AvailableGameVersions,RecordHash'
$header | Out-File -FilePath $TestDbPath -Encoding UTF8

Write-TestResult "Empty test database created" (Test-Path $TestDbPath)

Write-TestHeader "Test 1: Add direct GitHub release asset URL"

$addOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
    -AddMod `
    -AddModUrl $assetUrl `
    -AddModLoader "fabric" `
    -AddModGameVersion "1.21.11" `
    -DatabaseFile $TestDbPath `
    -ApiResponseFolder $TestApiResponseDir 2>&1

$addExitCode = $LASTEXITCODE
$addSucceeded = $addExitCode -eq 0
Write-TestResult "AddMod command exits successfully" $addSucceeded

if (-not $addSucceeded) {
    Write-Host "  AddMod output:" -ForegroundColor Red
    $addOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}

$rows = @()
if (Test-Path $TestDbPath) { $rows = @(Import-Csv -Path $TestDbPath) }
$row = $rows | Select-Object -First 1

Write-TestResult "Exactly one row was written" ($rows.Count -eq 1)
Write-TestResult "ID resolves to owner/repo" ($row -and $row.ID -eq $canonicalId)
Write-TestResult "ID is not generated system ID" ($row -and $row.ID -notmatch '^system-')
Write-TestResult "Url is canonical repository URL" ($row -and $row.Url -eq $canonicalRepoUrl)
Write-TestResult "CurrentVersionUrl preserves exact asset URL" ($row -and $row.CurrentVersionUrl -eq $assetUrl)
Write-TestResult "Jar is parsed from asset filename" ($row -and $row.Jar -eq "biggerenderchests-1.1.0-1.21.11.jar")
Write-TestResult "CurrentVersion parsed from filename" ($row -and $row.CurrentVersion -eq "1.1.0")
Write-TestResult "CurrentGameVersion parsed from filename" ($row -and $row.CurrentGameVersion -eq "1.21.11")
Write-TestResult "Host is GitHub" ($row -and $row.Host -eq "github")
Write-TestResult "ApiSource is GitHub" ($row -and $row.ApiSource -eq "github")
Write-TestResult "SourceUrl is canonical repository URL" ($row -and $row.SourceUrl -eq $canonicalRepoUrl)

if ($row) {
    Write-Host "  Row summary:" -ForegroundColor Gray
    Write-Host "    ID: $($row.ID)" -ForegroundColor Gray
    Write-Host "    Url: $($row.Url)" -ForegroundColor Gray
    Write-Host "    CurrentVersionUrl: $($row.CurrentVersionUrl)" -ForegroundColor Gray
    Write-Host "    Jar: $($row.Jar)" -ForegroundColor Gray
}

Show-TestSummary "GitHub Direct Release URL Tests"

Write-Host "`nGitHub Direct Release URL Tests Complete" -ForegroundColor $Colors.Info

return ($script:TestResults.Failed -eq 0)
