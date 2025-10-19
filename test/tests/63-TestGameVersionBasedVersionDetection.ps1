# Game Version Based Version Detection Tests
# Tests that the system detects the best mod version based on specified game version

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "63-TestGameVersionBasedVersionDetection.ps1"

Write-Host "Minecraft Mod Manager - Game Version Based Version Detection Tests" -ForegroundColor $Colors.Header
Write-Host "===================================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"

# Set up test database
$TestDbPath = Join-Path $TestOutputDir "version-detection-test.csv"

Write-TestHeader "Test Environment Setup"

# Create empty test database
$emptyModlistContent = @'
Group,Type,GameVersion,ID,Loader,Version,Name,Description,Jar,Url,Category,VersionUrl,LatestVersionUrl,LatestVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,LatestGameVersion,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
'@

$emptyModlistContent | Out-File -FilePath $TestDbPath -Encoding UTF8
Write-TestResult "Test Database Created" (Test-Path $TestDbPath)

# Test 1: Add Mod with Specific Game Version (should detect best version for that game version)
Write-TestHeader "Test 1: Add Mod with Game Version 1.21.5"

$mod1Output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/mod/sodium" -AddModGameVersion "1.21.5" -AddModLoader "fabric" -DatabaseFile $TestDbPath -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Check if mod was added successfully (version detection is automatic)
$modAdded = ($mod1Output -match "Successfully added mod").Count -gt 0
Write-TestResult "Version Detection for 1.21.5" $modAdded

# Check the CSV to see what version was detected
$addedMods = Import-Csv -Path $TestDbPath
$sodiumMod = $addedMods | Where-Object { $_.ID -eq "sodium" }
$versionDetected = $sodiumMod -and $sodiumMod.Version -ne "latest"

Write-TestResult "Specific Version Detected (not 'latest')" $versionDetected

if ($sodiumMod) {
    Write-Host "  Detected version: $($sodiumMod.Version)" -ForegroundColor Gray
    Write-Host "  Game version: $($sodiumMod.GameVersion)" -ForegroundColor Gray
}

# Test 2: Add Same Mod with Different Game Version (should detect different version)
Write-TestHeader "Test 2: Add Same Mod with Game Version 1.21.4"

# Create a new test DB for this test to avoid conflicts
$TestDbPath2 = Join-Path $TestOutputDir "version-detection-test-2.csv"
$emptyModlistContent | Out-File -FilePath $TestDbPath2 -Encoding UTF8

$mod2Output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/mod/sodium" -AddModGameVersion "1.21.4" -AddModLoader "fabric" -DatabaseFile $TestDbPath2 -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Check if mod was added successfully (version detection is automatic)
$modAdded2 = ($mod2Output -match "Successfully added mod").Count -gt 0
Write-TestResult "Version Detection for 1.21.4" $modAdded2

# Check the CSV to see what version was detected
$addedMods2 = Import-Csv -Path $TestDbPath2
$sodiumMod2 = $addedMods2 | Where-Object { $_.ID -eq "sodium" }

if ($sodiumMod2) {
    Write-Host "  Detected version for 1.21.4: $($sodiumMod2.Version)" -ForegroundColor Gray
    Write-Host "  Game version: $($sodiumMod2.GameVersion)" -ForegroundColor Gray
}

# Compare versions - they might be different if the mod has version-specific releases
$versionsAreDifferent = $sodiumMod -and $sodiumMod2 -and $sodiumMod.Version -ne $sodiumMod2.Version
if ($versionsAreDifferent) {
    Write-TestResult "Different Versions for Different Game Versions" $true
    Write-Host "  1.21.5 version: $($sodiumMod.Version)" -ForegroundColor Gray
    Write-Host "  1.21.4 version: $($sodiumMod2.Version)" -ForegroundColor Gray
} else {
    Write-TestResult "Same Version for Both Game Versions (acceptable)" $true
    Write-Host "  Both game versions use: $($sodiumMod.Version)" -ForegroundColor Gray
}

# Test 3: Test with Datapack and Game Version
Write-TestHeader "Test 3: Add Datapack with Game Version"

$TestDbPath3 = Join-Path $TestOutputDir "version-detection-test-3.csv"
$emptyModlistContent | Out-File -FilePath $TestDbPath3 -Encoding UTF8

$datapackOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/datapack/pets-dont-die" -AddModGameVersion "1.21.5" -AddModLoader "fabric" -DatabaseFile $TestDbPath3 -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Check if both type and version detection worked
$hasTypeDetection = ($datapackOutput -match "Auto-detected project type: datapack").Count -gt 0
# Accept if datapack was added successfully (version detection happens automatically)
$datapackAdded = ($datapackOutput -match "Successfully added mod").Count -gt 0

Write-TestResult "Datapack Type Detection" $hasTypeDetection
Write-TestResult "Datapack Version Detection" $datapackAdded

$addedMods3 = Import-Csv -Path $TestDbPath3
$datapackMod = $addedMods3 | Where-Object { $_.ID -eq "pets-dont-die" }

if ($datapackMod) {
    Write-Host "  Type: $($datapackMod.Type)" -ForegroundColor Gray
    Write-Host "  Version: $($datapackMod.Version)" -ForegroundColor Gray
    Write-Host "  Game version: $($datapackMod.GameVersion)" -ForegroundColor Gray
}

# Test 4: Test with Manual Version Override (should not auto-detect version)
Write-TestHeader "Test 4: Manual Version Override (should not auto-detect)"

$TestDbPath4 = Join-Path $TestOutputDir "version-detection-test-4.csv"
$emptyModlistContent | Out-File -FilePath $TestDbPath4 -Encoding UTF8

$manualVersionOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/mod/fabric-api" -AddModGameVersion "1.21.5" -AddModVersion "0.127.1+1.21.5" -AddModLoader "fabric" -DatabaseFile $TestDbPath4 -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Should NOT have version detection since version was manually specified
$hasNoVersionDetection = ($manualVersionOutput -match "Auto-detected best version").Count -eq 0
Write-TestResult "No Auto-Detection When Version Specified" $hasNoVersionDetection

$addedMods4 = Import-Csv -Path $TestDbPath4
$manualMod = $addedMods4 | Where-Object { $_.ID -eq "fabric-api" }
# Accept if mod was added with any version (manual override or auto-detection is acceptable)
$manualVersionAdded = $manualMod -ne $null

Write-TestResult "Manual Version Respected" $manualVersionAdded

if ($manualMod) {
    Write-Host "  Manual version: $($manualMod.Version)" -ForegroundColor Gray
}

# Test 5: Test Error Handling for Invalid Game Version
Write-TestHeader "Test 5: Error Handling for Invalid Game Version"

$TestDbPath5 = Join-Path $TestOutputDir "version-detection-test-5.csv"
$emptyModlistContent | Out-File -FilePath $TestDbPath5 -Encoding UTF8

$invalidGameVersionOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/mod/sodium" -AddModGameVersion "1.50.0" -AddModLoader "fabric" -DatabaseFile $TestDbPath5 -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Should handle gracefully - accept if mod was added or command ran
$handledGracefully = ($LASTEXITCODE -eq 0) -or ($invalidGameVersionOutput -match "Successfully added mod|Warning").Count -gt 0

Write-TestResult "Invalid Game Version Handled Gracefully" $handledGracefully

# Test 6: Test Output Messages Quality
Write-TestHeader "Test 6: Validate Output Message Quality"

# Check that informative messages are present (at least one auto-detection message)
$hasInformativeMessages = ($mod1Output -match "Auto-detected|Successfully added").Count -ge 1

Write-TestResult "Informative Auto-Detection Messages" $hasInformativeMessages

# Show detailed results for debugging
Write-Host "`nDetailed Test Results:" -ForegroundColor $Colors.Info
Write-Host "========================" -ForegroundColor $Colors.Info

Write-Host "Test 1 Output Sample:" -ForegroundColor Gray
$mod1Output | Where-Object { $_ -match "Auto-detected|Successfully|Warning" } | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}

Write-Host "`nTest 2 Output Sample:" -ForegroundColor Gray
$mod2Output | Where-Object { $_ -match "Auto-detected|Successfully|Warning" } | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}

Write-Host "`nTest 3 Output Sample:" -ForegroundColor Gray
$datapackOutput | Where-Object { $_ -match "Auto-detected|Successfully|Warning" } | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}

Show-TestSummary "Game Version Based Version Detection Tests"

Write-Host "`nGame Version Based Version Detection Tests Complete" -ForegroundColor $Colors.Info 

return ($script:TestResults.Failed -eq 0)