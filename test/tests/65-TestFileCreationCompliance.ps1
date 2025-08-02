# Test File Creation Compliance Tests
# Ensures that all test operations create files in test directories, not root

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "65-TestFileCreationCompliance.ps1"

Write-Host "Minecraft Mod Manager - Test File Creation Compliance Tests" -ForegroundColor $Colors.Header
Write-Host "===========================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"

# Set up test database path in test directory
$TestDbPath = Join-Path $TestOutputDir "file-creation-test.csv"

Write-TestHeader "Test Environment Setup"

# Create empty test database
$emptyModlistContent = @'
Group,Type,GameVersion,ID,Loader,Version,Name,Description,Jar,Url,Category,VersionUrl,LatestVersionUrl,LatestVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,LatestGameVersion,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
'@

$emptyModlistContent | Out-File -FilePath $TestDbPath -Encoding UTF8
Write-TestResult "Test Database Created in Test Directory" (Test-Path $TestDbPath)

# Test 1: Verify AddMod with explicit DatabaseFile creates files in correct location
Write-TestHeader "Test 1: AddMod File Creation Location"

# Record current root directory files before test
$rootFilesBefore = Get-ChildItem -Path "." -Name "*.csv" | Sort-Object

# Add a mod using explicit DatabaseFile parameter
$addModOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/mod/sodium" -DatabaseFile $TestDbPath -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Record root directory files after test
$rootFilesAfter = Get-ChildItem -Path "." -Name "*.csv" | Sort-Object

# Check if any new CSV files were created in root
$newRootFiles = Compare-Object $rootFilesBefore $rootFilesAfter | Where-Object { $_.SideIndicator -eq "=>" }
$noNewRootFiles = ($newRootFiles -eq $null)

Write-TestResult "No New Files Created in Root" $noNewRootFiles

if (-not $noNewRootFiles) {
    Write-Host "  ❌ New files found in root:" -ForegroundColor Red
    $newRootFiles | ForEach-Object { Write-Host "    - $($_.InputObject)" -ForegroundColor Red }
}

# Check that the test database was updated
$testDbUpdated = (Test-Path $TestDbPath) -and (Get-Content $TestDbPath | Measure-Object -Line).Lines -gt 1
Write-TestResult "Test Database Updated Correctly" $testDbUpdated

# Test 2: Verify SearchModName doesn't create root files
Write-TestHeader "Test 2: SearchModName File Creation Location"

# This test would be interactive, so we'll test the non-interactive search function directly
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

$rootFilesBefore2 = Get-ChildItem -Path "." -Name "*.csv" | Sort-Object

try {
    # Test the search function directly (non-interactive)
    $searchResult = Search-ModrinthProjects -Query "sodium" -ProjectType "mod" -Limit 1 -Quiet
    $searchWorked = $searchResult -and $searchResult.Count -gt 0
} catch {
    $searchWorked = $false
}

$rootFilesAfter2 = Get-ChildItem -Path "." -Name "*.csv" | Sort-Object
$newRootFiles2 = Compare-Object $rootFilesBefore2 $rootFilesAfter2 | Where-Object { $_.SideIndicator -eq "=>" }
$noNewRootFiles2 = ($newRootFiles2 -eq $null)

Write-TestResult "Search Function No Root Files" $noNewRootFiles2
Write-TestResult "Search Function Works" $searchWorked

# Test 3: Verify validation doesn't create unwanted files
Write-TestHeader "Test 3: Validation File Creation Location"

$rootFilesBefore3 = Get-ChildItem -Path "." -Name "*.csv" | Sort-Object

# Run validation with explicit database file
$validationOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -DatabaseFile $TestDbPath -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

$rootFilesAfter3 = Get-ChildItem -Path "." -Name "*.csv" | Sort-Object
$newRootFiles3 = Compare-Object $rootFilesBefore3 $rootFilesAfter3 | Where-Object { $_.SideIndicator -eq "=>" }
$noNewRootFiles3 = ($newRootFiles3 -eq $null)

Write-TestResult "Validation No Root Files" $noNewRootFiles3

# Test 4: Check for common problematic file patterns
Write-TestHeader "Test 4: Check for Problematic File Patterns"

# Check for files that might be test artifacts
$problemFiles = Get-ChildItem -Path "." -Name "*test*" -File | Where-Object { 
    $_ -like "test-*.csv" -or 
    $_ -like "*-test.csv" -or 
    $_ -like "temp*.csv" 
}

$noProblemFiles = ($problemFiles.Count -eq 0)
Write-TestResult "No Problematic Test Files in Root" $noProblemFiles

if (-not $noProblemFiles) {
    Write-Host "  ❌ Problematic files found in root:" -ForegroundColor Red
    $problemFiles | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}

# Test 5: Verify test output files are in correct locations
Write-TestHeader "Test 5: Test Output File Locations"

# Check that test files are being created in test directories
$testOutputExists = Test-Path $TestOutputDir
$testDbInCorrectLocation = Test-Path $TestDbPath
$responsesCacheInCorrectLocation = Test-Path $script:TestApiResponseDir

Write-TestResult "Test Output Directory Exists" $testOutputExists
Write-TestResult "Test Database in Correct Location" $testDbInCorrectLocation
Write-TestResult "API Responses Cache in Correct Location" $responsesCacheInCorrectLocation

if ($testDbInCorrectLocation) {
    Write-Host "  ✓ Test database: $TestDbPath" -ForegroundColor Green
}
if ($responsesCacheInCorrectLocation) {
    Write-Host "  ✓ API cache: $script:TestApiResponseDir" -ForegroundColor Green
}

# Test 6: Clean up verification
Write-TestHeader "Test 6: Clean Up Verification"

# List all CSV files in root for manual verification
$allRootCsvFiles = Get-ChildItem -Path "." -Name "*.csv" | Sort-Object

Write-Host "  Current CSV files in root directory:" -ForegroundColor Gray
foreach ($file in $allRootCsvFiles) {
    if ($file -like "*test*") {
        Write-Host "    ❌ $file (should not be here)" -ForegroundColor Red
    } else {
        Write-Host "    ✓ $file (legitimate)" -ForegroundColor Gray
    }
}

$onlyLegitimateFiles = ($allRootCsvFiles | Where-Object { $_ -like "*test*" }).Count -eq 0
Write-TestResult "Only Legitimate Files in Root" $onlyLegitimateFiles

# Show detailed results for debugging
Write-Host "`nDetailed Test Results:" -ForegroundColor $Colors.Info
Write-Host "========================" -ForegroundColor $Colors.Info

Write-Host "Test Output Directory: $TestOutputDir" -ForegroundColor Gray
Write-Host "Test Database Path: $TestDbPath" -ForegroundColor Gray
Write-Host "API Response Cache: $script:TestApiResponseDir" -ForegroundColor Gray

Write-Host "`nRoot directory CSV files:" -ForegroundColor Gray
$allRootCsvFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

Show-TestSummary "Test File Creation Compliance Tests"

Write-Host "`nTest File Creation Compliance Tests Complete" -ForegroundColor $Colors.Info 

return ($script:TestResults.Failed -eq 0)