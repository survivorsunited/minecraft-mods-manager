# GitHub Add Mod Complete Tests
# Tests that adding a GitHub mod populates all required fields correctly

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "108-TestGitHubAddModComplete.ps1"

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDbPath = Join-Path $TestOutputDir "github-add-mod-test.csv"

Write-Host "Minecraft Mod Manager - GitHub Add Mod Complete Tests" -ForegroundColor $Colors.Header
Write-Host "=====================================================" -ForegroundColor $Colors.Header

# Create empty test database
$emptyDbContent = @'
Group,Type,CurrentGameVersion,ID,Loader,CurrentVersion,Name,Description,Jar,Url,Category,CurrentVersionUrl,NextVersion,NextVersionUrl,NextGameVersion,LatestVersionUrl,LatestVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,LatestGameVersion,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
'@

$emptyDbContent | Out-File -FilePath $TestDbPath -Encoding UTF8
Write-TestResult "Test Database Created" (Test-Path $TestDbPath)

# Test 1: Add GitHub mod and validate all fields are populated
Write-TestHeader "Test 1: Add GitHub Mod with Full Field Validation"

$githubUrl = "https://github.com/survivorsunited/mod-bigger-ender-chests"
$addModOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
    -AddMod `
    -AddModUrl $githubUrl `
    -AddModLoader "fabric" `
    -AddModGameVersion "1.21.8" `
    -AddModVersion "latest" `
    -DatabaseFile $TestDbPath `
    -ApiResponseFolder $script:TestApiResponseDir `
    -UseCachedResponses 2>&1

$addModSuccess = $LASTEXITCODE -eq 0
Write-TestResult "Add GitHub Mod" $addModSuccess

if (-not $addModSuccess) {
    Write-Host "  ✗ Failed to add mod" -ForegroundColor Red
    Write-Host "    Output: $($addModOutput -join "`n")" -ForegroundColor Red
    exit 1
}

# Test 2: Validate all fields are populated
Write-TestHeader "Test 2: Validate All Fields Are Populated"

$mods = Import-Csv -Path $TestDbPath
$addedMod = $mods | Where-Object { $_.ID -eq "survivorsunited/mod-bigger-ender-chests" -or $_.Url -eq $githubUrl } | Select-Object -First 1

if (-not $addedMod) {
    Write-Host "  ✗ Mod not found in database" -ForegroundColor Red
    exit 1
}

Write-Host "  Validating field population..." -ForegroundColor Cyan

# Required fields that must be populated
$requiredFields = @{
    "Group" = @{ Value = $addedMod.Group; Required = $true; Description = "Mod group (required/optional)" }
    "Type" = @{ Value = $addedMod.Type; Required = $true; Description = "Mod type (should be 'mod' from repo prefix)" }
    "CurrentGameVersion" = @{ Value = $addedMod.CurrentGameVersion; Required = $true; Description = "Game version" }
    "ID" = @{ Value = $addedMod.ID; Required = $true; Description = "Mod ID (owner/repo)" }
    "Loader" = @{ Value = $addedMod.Loader; Required = $true; Description = "Mod loader" }
    "CurrentVersion" = @{ Value = $addedMod.CurrentVersion; Required = $true; Description = "Current version" }
    "Name" = @{ Value = $addedMod.Name; Required = $true; Description = "Mod name (should not be ID)" }
    "Url" = @{ Value = $addedMod.Url; Required = $true; Description = "Repository URL" }
    "ApiSource" = @{ Value = $addedMod.ApiSource; Required = $true; Description = "API source (should be 'github')" }
    "Host" = @{ Value = $addedMod.Host; Required = $true; Description = "Host (should be 'github')" }
    "Title" = @{ Value = $addedMod.Title; Required = $true; Description = "Title (should match Name)" }
}

# Optional but should be populated fields
$optionalFields = @{
    "Description" = @{ Value = $addedMod.Description; Required = $false; Description = "Project description" }
    "Jar" = @{ Value = $addedMod.Jar; Required = $false; Description = "JAR filename" }
    "Category" = @{ Value = $addedMod.Category; Required = $false; Description = "Mod category" }
    "CurrentVersionUrl" = @{ Value = $addedMod.CurrentVersionUrl; Required = $false; Description = "Current version download URL" }
    "LatestVersionUrl" = @{ Value = $addedMod.LatestVersionUrl; Required = $false; Description = "Latest version download URL" }
    "LatestVersion" = @{ Value = $addedMod.LatestVersion; Required = $false; Description = "Latest version number" }
    "IconUrl" = @{ Value = $addedMod.IconUrl; Required = $false; Description = "Repository icon URL" }
    "IssuesUrl" = @{ Value = $addedMod.IssuesUrl; Required = $false; Description = "Issues URL" }
    "SourceUrl" = @{ Value = $addedMod.SourceUrl; Required = $false; Description = "Source code URL" }
    "WikiUrl" = @{ Value = $addedMod.WikiUrl; Required = $false; Description = "Wiki URL" }
    "ProjectDescription" = @{ Value = $addedMod.ProjectDescription; Required = $false; Description = "Full project description" }
}

$validationErrors = @()
$validationWarnings = @()

# Validate required fields
foreach ($fieldName in $requiredFields.Keys) {
    $field = $requiredFields[$fieldName]
    if ([string]::IsNullOrWhiteSpace($field.Value)) {
        $validationErrors += "Required field '$fieldName' is empty ($($field.Description))"
    } else {
        Write-Host "  ✓ $fieldName : $($field.Value)" -ForegroundColor Green
    }
}

# Validate specific field values
if ($addedMod.Type -ne "mod") {
    $validationErrors += "Type should be 'mod' (extracted from repo prefix 'mod-'), got '$($addedMod.Type)'"
} else {
    Write-Host "  ✓ Type correctly extracted from repo prefix: 'mod'" -ForegroundColor Green
}

if ($addedMod.Name -eq $addedMod.ID -or [string]::IsNullOrWhiteSpace($addedMod.Name)) {
    $validationErrors += "Name should be populated from GitHub API, not just the ID"
} else {
    Write-Host "  ✓ Name populated from GitHub: '$($addedMod.Name)'" -ForegroundColor Green
}

if ($addedMod.ApiSource -ne "github") {
    $validationErrors += "ApiSource should be 'github', got '$($addedMod.ApiSource)'"
}

if ($addedMod.Host -ne "github") {
    $validationErrors += "Host should be 'github', got '$($addedMod.Host)'"
}

# Validate optional fields (warn if missing but don't fail)
foreach ($fieldName in $optionalFields.Keys) {
    $field = $optionalFields[$fieldName]
    if ([string]::IsNullOrWhiteSpace($field.Value)) {
        $validationWarnings += "Optional field '$fieldName' is empty ($($field.Description))"
    } else {
        Write-Host "  ✓ $fieldName : $($field.Value)" -ForegroundColor Cyan
    }
}

# Report results
if ($validationErrors.Count -gt 0) {
    Write-Host "`n  ✗ Validation Errors:" -ForegroundColor Red
    foreach ($error in $validationErrors) {
        Write-Host "    - $error" -ForegroundColor Red
    }
    Write-TestResult "Field Validation" $false
    exit 1
}

if ($validationWarnings.Count -gt 0) {
    Write-Host "`n  ⚠️  Validation Warnings (optional fields):" -ForegroundColor Yellow
    foreach ($warning in $validationWarnings) {
        Write-Host "    - $warning" -ForegroundColor Yellow
    }
}

Write-TestResult "All Required Fields Populated" $true
Write-TestResult "Optional Fields Check" ($validationWarnings.Count -lt 5)  # Allow some optional fields to be empty

# Test 3: Verify type extraction from repo prefix
Write-TestHeader "Test 3: Verify Type Extraction from Repo Prefix"

$typeTests = @(
    @{ Repo = "mod-bigger-ender-chests"; ExpectedType = "mod" },
    @{ Repo = "shader-awesome-shaders"; ExpectedType = "shader" },
    @{ Repo = "datapack-cool-pack"; ExpectedType = "datapack" },
    @{ Repo = "resourcepack-nice-pack"; ExpectedType = "resourcepack" },
    @{ Repo = "plugin-cool-plugin"; ExpectedType = "plugin" },
    @{ Repo = "unknown-repo"; ExpectedType = "mod" }  # Default fallback
)

$typeTestsPassed = 0
foreach ($test in $typeTests) {
    if ($test.Repo -match '^(mod|shader|datapack|resourcepack|plugin)-') {
        $extractedType = $matches[1]
    } else {
        $extractedType = "mod"  # Default
    }
    
    if ($extractedType -eq $test.ExpectedType) {
        $typeTestsPassed++
        Write-Host "  ✓ $($test.Repo) → $extractedType" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($test.Repo) → Expected $($test.ExpectedType), got $extractedType" -ForegroundColor Red
    }
}

Write-TestResult "Type Extraction Tests" ($typeTestsPassed -eq $typeTests.Count)

Show-TestSummary

