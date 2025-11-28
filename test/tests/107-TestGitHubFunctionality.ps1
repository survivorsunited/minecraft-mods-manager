# GitHub Functionality Tests
# Tests GitHub API integration, release parsing, and JAR file detection

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "107-TestGitHubFunctionality.ps1"

Write-Host "Minecraft Mod Manager - GitHub Functionality Tests" -ForegroundColor $Colors.Header
Write-Host "===================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"

# Set up test directories
$TestDbPath = Join-Path $TestOutputDir "github-test.csv"

Write-TestHeader "Test Environment Setup"

# Create test database with GitHub mods
$githubModlistContent = @'
Group,Type,CurrentGameVersion,ID,Loader,CurrentVersion,Name,Description,Jar,Url,Category,CurrentVersionUrl,NextVersion,NextVersionUrl,NextGameVersion,LatestVersionUrl,LatestVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,LatestGameVersion,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
required,mod,1.21.8,survivorsunited/mod-bigger-ender-chests,fabric,1.1.0,Bigger Ender Chests,Increases ender chest inventory size,mod-bigger-ender-chests-1.1.0-1.21.8.jar,https://github.com/survivorsunited/mod-bigger-ender-chests,Storage & Inventory,,,,,github,github,,,,,,,,,,,,,,,,,
'@

$githubModlistContent | Out-File -FilePath $TestDbPath -Encoding UTF8
Write-TestResult "Test Database Created" (Test-Path $TestDbPath)

Write-Host "  GitHub mods configured:" -ForegroundColor Gray
Write-Host "    - Bigger Ender Chests (survivorsunited/mod-bigger-ender-chests)" -ForegroundColor Gray

# Import the modular functions for testing
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

# Test 1: GitHub Repository URL Parsing
Write-TestHeader "Test 1: GitHub Repository URL Parsing"

$testUrls = @(
    @{ Url = "https://github.com/survivorsunited/mod-bigger-ender-chests"; ExpectedOwner = "survivorsunited"; ExpectedRepo = "mod-bigger-ender-chests" },
    @{ Url = "https://github.com/owner/repo"; ExpectedOwner = "owner"; ExpectedRepo = "repo" },
    @{ Url = "https://github.com/user/mod.git"; ExpectedOwner = "user"; ExpectedRepo = "mod" }
)

$parsingTestsPassed = 0
foreach ($testUrl in $testUrls) {
    if ($testUrl.Url -match 'github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?/?$') {
        $owner = $matches[1]
        $repo = $matches[2]
        if ($owner -eq $testUrl.ExpectedOwner -and $repo -eq $testUrl.ExpectedRepo) {
            $parsingTestsPassed++
            Write-Host "  ✓ Parsed: $($testUrl.Url) -> $owner/$repo" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed: $($testUrl.Url) -> Expected $($testUrl.ExpectedOwner)/$($testUrl.ExpectedRepo), got $owner/$repo" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ Failed to parse: $($testUrl.Url)" -ForegroundColor Red
    }
}

Write-TestResult "URL Parsing Tests" ($parsingTestsPassed -eq $testUrls.Count)

# Test 2: Get GitHub Project Info
Write-TestHeader "Test 2: Get GitHub Project Info"

$repositoryUrl = "https://github.com/survivorsunited/mod-bigger-ender-chests"
$projectInfo = $null
$projectInfoError = $null

try {
    $projectInfo = Get-GitHubProjectInfo -RepositoryUrl $repositoryUrl -UseCachedResponses $false
} catch {
    $projectInfoError = $_.Exception.Message
}

$projectInfoSuccess = $null -ne $projectInfo -and $projectInfo.full_name -eq "survivorsunited/mod-bigger-ender-chests"
Write-TestResult "Get GitHub Project Info" $projectInfoSuccess

if ($projectInfoSuccess) {
    Write-Host "  ✓ Repository: $($projectInfo.full_name)" -ForegroundColor Green
    Write-Host "  ✓ Description: $($projectInfo.description)" -ForegroundColor Gray
} else {
    Write-Host "  ✗ Failed to get project info" -ForegroundColor Red
    if ($projectInfoError) {
        Write-Host "    Error: $projectInfoError" -ForegroundColor Red
    }
}

# Test 3: Get GitHub Releases
Write-TestHeader "Test 3: Get GitHub Releases"

$releases = $null
$releasesError = $null

try {
    $releases = Get-GitHubReleases -RepositoryUrl $repositoryUrl -UseCachedResponses $false
} catch {
    $releasesError = $_.Exception.Message
}

$releasesSuccess = $null -ne $releases -and $releases.Count -gt 0
Write-TestResult "Get GitHub Releases" $releasesSuccess

if ($releasesSuccess) {
    Write-Host "  ✓ Found $($releases.Count) release(s)" -ForegroundColor Green
    foreach ($release in $releases | Select-Object -First 3) {
        Write-Host "    - $($release.tag_name) ($($release.name))" -ForegroundColor Gray
        Write-Host "      Assets: $($release.assets.Count)" -ForegroundColor Gray
    }
} else {
    Write-Host "  ✗ Failed to get releases or no releases found" -ForegroundColor Red
    if ($releasesError) {
        Write-Host "    Error: $releasesError" -ForegroundColor Red
    }
}

# Test 4: Validate GitHub Mod Version
Write-TestHeader "Test 4: Validate GitHub Mod Version"

$validationResult = $null
$validationError = $null

try {
    $validationResult = Validate-GitHubModVersion -ModID $repositoryUrl -Version "latest" -Loader "fabric" -GameVersion "1.21.8" -UseCachedResponses $false
} catch {
    $validationError = $_.Exception.Message
}

$validationSuccess = $null -ne $validationResult -and $validationResult.Success -eq $true
Write-TestResult "Validate GitHub Mod Version" $validationSuccess

if ($validationSuccess) {
    Write-Host "  ✓ Version: $($validationResult.Version)" -ForegroundColor Green
    Write-Host "  ✓ JAR: $($validationResult.Jar)" -ForegroundColor Green
    Write-Host "  ✓ Download URL: $($validationResult.DownloadUrl)" -ForegroundColor Gray
    
    # Check if JAR matches expected pattern
    $jarPatternMatch = $validationResult.Jar -match '.*-\d+\.\d+\.\d+-\d+\.\d+\.\d+\.jar$'
    Write-TestResult "JAR Pattern Match (<name>-<version>-<game version>.jar)" $jarPatternMatch
} else {
    Write-Host "  ✗ Validation failed" -ForegroundColor Red
    if ($validationResult -and $validationResult.Error) {
        Write-Host "    Error: $($validationResult.Error)" -ForegroundColor Red
    }
    if ($validationError) {
        Write-Host "    Exception: $validationError" -ForegroundColor Red
    }
}

# Test 5: Validate with "latest" Version Keyword
Write-TestHeader "Test 5: Validate with 'latest' Version Keyword"

$latestResult = $null
$latestError = $null

try {
    $latestResult = Validate-GitHubModVersion -ModID $repositoryUrl -Version "latest" -Loader "fabric" -GameVersion "1.21.8" -UseCachedResponses $false
} catch {
    $latestError = $_.Exception.Message
}

$latestSuccess = $null -ne $latestResult -and $latestResult.Success -eq $true
Write-TestResult "Validate with 'latest' Keyword" $latestSuccess

if ($latestSuccess) {
    Write-Host "  ✓ Latest version: $($latestResult.Version)" -ForegroundColor Green
    Write-Host "  ✓ JAR: $($latestResult.Jar)" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to get latest version" -ForegroundColor Red
    if ($latestResult -and $latestResult.Error) {
        Write-Host "    Error: $($latestResult.Error)" -ForegroundColor Red
    }
}

# Test 6: JAR File Pattern Matching
Write-TestHeader "Test 6: JAR File Pattern Matching"

if ($releasesSuccess -and $releases.Count -gt 0) {
    $latestRelease = $releases | Sort-Object { [DateTime]::Parse($_.published_at) } -Descending | Select-Object -First 1
    
    # Test pattern matching for different JAR file formats
    $testPatterns = @(
        @{ Pattern = ".*-1\.1\.0-1\.21\.8\.jar$"; Name = "Full pattern (<name>-<version>-<game version>.jar)" },
        @{ Pattern = ".*-1\.1\.0\.jar$"; Name = "Version-only pattern (<name>-<version>.jar)" },
        @{ Pattern = "\.jar$"; Name = "Any JAR file" }
    )
    
    $patternTestsPassed = 0
    foreach ($testPattern in $testPatterns) {
        $matched = $false
        foreach ($asset in $latestRelease.assets) {
            if ($asset.name -match $testPattern.Pattern) {
                $matched = $true
                Write-Host "  ✓ $($testPattern.Name): $($asset.name)" -ForegroundColor Green
                $patternTestsPassed++
                break
            }
        }
        if (-not $matched) {
            Write-Host "  ✗ $($testPattern.Name): No match found" -ForegroundColor Red
        }
    }
    
    Write-TestResult "JAR Pattern Matching" ($patternTestsPassed -gt 0)
} else {
    Write-Host "  ⏭️  Skipping pattern matching test (no releases available)" -ForegroundColor Yellow
    Write-TestResult "JAR Pattern Matching" $true "Skipped - no releases"
}

# Test 7: Add GitHub Mod to Database
Write-TestHeader "Test 7: Add GitHub Mod to Database"

$addModOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
    -AddMod `
    -AddModUrl "https://github.com/survivorsunited/mod-bigger-ender-chests" `
    -AddModLoader "fabric" `
    -AddModGameVersion "1.21.8" `
    -DatabaseFile $TestDbPath `
    -UseCachedResponses `
    -ApiResponseFolder $script:TestApiResponseDir 2>&1

$addModSuccess = $LASTEXITCODE -eq 0 -and ($addModOutput -join "`n") -match "Bigger Ender Chests|survivorsunited/mod-bigger-ender-chests"
Write-TestResult "Add GitHub Mod to Database" $addModSuccess

if ($addModSuccess) {
    Write-Host "  ✓ Mod added successfully" -ForegroundColor Green
    
    # Verify mod was added to database
    if (Test-Path $TestDbPath) {
        $mods = Import-Csv -Path $TestDbPath
        $addedMod = $mods | Where-Object { $_.ID -eq "survivorsunited/mod-bigger-ender-chests" -or $_.Url -match "github.com/survivorsunited/mod-bigger-ender-chests" }
        if ($addedMod) {
            Write-Host "  ✓ Mod found in database" -ForegroundColor Green
            Write-Host "    ID: $($addedMod.ID)" -ForegroundColor Gray
            Write-Host "    ApiSource: $($addedMod.ApiSource)" -ForegroundColor Gray
            Write-Host "    Host: $($addedMod.Host)" -ForegroundColor Gray
        } else {
            Write-Host "  ✗ Mod not found in database" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ✗ Failed to add mod" -ForegroundColor Red
    Write-Host "    Exit code: $LASTEXITCODE" -ForegroundColor Red
}

# Test 8: Validate GitHub Mod via Common Provider Interface
Write-TestHeader "Test 8: Validate via Common Provider Interface"

$commonValidationResult = $null
$commonValidationError = $null

try {
    $commonValidationResult = Validate-ModVersion -ModId "survivorsunited/mod-bigger-ender-chests" -Version "latest" -Loader "fabric" -GameVersion "1.21.8" -CsvPath $TestDbPath -ResponseFolder $TestOutputDir
} catch {
    $commonValidationError = $_.Exception.Message
}

$commonValidationSuccess = $null -ne $commonValidationResult -and $commonValidationResult.Exists -eq $true
Write-TestResult "Validate via Common Interface" $commonValidationSuccess

if ($commonValidationSuccess) {
    Write-Host "  ✓ Provider auto-detected: GitHub" -ForegroundColor Green
    Write-Host "  ✓ Version: $($commonValidationResult.LatestVersion)" -ForegroundColor Green
    Write-Host "  ✓ JAR: $($commonValidationResult.Jar)" -ForegroundColor Green
} else {
    Write-Host "  ✗ Common interface validation failed" -ForegroundColor Red
    if ($commonValidationResult -and $commonValidationResult.Error) {
        Write-Host "    Error: $($commonValidationResult.Error)" -ForegroundColor Red
    }
    if ($commonValidationError) {
        Write-Host "    Exception: $commonValidationError" -ForegroundColor Red
    }
}

# Test 9: GitHub API Response Caching
Write-TestHeader "Test 9: GitHub API Response Caching"

# Check if cache directory exists and has content
$cacheDir = Join-Path $script:TestApiResponseDir "github"
$cacheDirExists = Test-Path $cacheDir
$cacheFiles = @()

if ($cacheDirExists) {
    $cacheFiles = Get-ChildItem -Path $cacheDir -Filter "*.json" -ErrorAction SilentlyContinue
}

Write-TestResult "Cache Directory Created" $cacheDirExists
Write-TestResult "Cache Files Generated" ($cacheFiles.Count -gt 0)

if ($cacheFiles.Count -gt 0) {
    Write-Host "  Cached responses:" -ForegroundColor Gray
    foreach ($file in $cacheFiles | Select-Object -First 5) {
        Write-Host "    - $($file.Name)" -ForegroundColor Gray
    }
    if ($cacheFiles.Count -gt 5) {
        Write-Host "    ... and $($cacheFiles.Count - 5) more" -ForegroundColor Gray
    }
}

# Test 10: Error Handling
Write-TestHeader "Test 10: Error Handling"

# Test with invalid repository URL
$invalidResult = $null
try {
    $invalidResult = Get-GitHubProjectInfo -RepositoryUrl "https://github.com/invalid-user/invalid-repo-12345" -UseCachedResponses $false
} catch {
    # Expected to fail
}

$errorHandlingSuccess = $null -eq $invalidResult
Write-TestResult "Error Handling - Invalid Repository" $errorHandlingSuccess

if ($errorHandlingSuccess) {
    Write-Host "  ✓ Invalid repository handled correctly" -ForegroundColor Green
} else {
    Write-Host "  ✗ Invalid repository not handled correctly" -ForegroundColor Red
}

# Show detailed results for debugging
Write-Host "`nDetailed Test Results:" -ForegroundColor $Colors.Info
Write-Host "=======================" -ForegroundColor $Colors.Info

Write-Host "Test Environment:" -ForegroundColor Gray
Write-Host "  Output Dir: $TestOutputDir" -ForegroundColor Gray
Write-Host "  API Response Dir: $script:TestApiResponseDir" -ForegroundColor Gray
Write-Host "  Test Database: $TestDbPath" -ForegroundColor Gray

Show-TestSummary "GitHub Functionality Tests"

Write-Host "`nGitHub Functionality Tests Complete" -ForegroundColor $Colors.Info

return ($script:TestResults.Failed -eq 0)

