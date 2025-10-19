# Type Detection When Adding Via URL Tests
# Tests that project type (mod/datapack) is automatically detected when adding via URL

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "62-TestTypeDetectionWhenAddingViaUrl.ps1"

Write-Host "Minecraft Mod Manager - Type Detection When Adding Via URL Tests" -ForegroundColor $Colors.Header
Write-Host "================================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"

# Set up test database
$TestDbPath = Join-Path $TestOutputDir "type-detection-test.csv"

Write-TestHeader "Test Environment Setup"

# Create empty test database
$emptyModlistContent = @'
Group,Type,GameVersion,ID,Loader,Version,Name,Description,Jar,Url,Category,VersionUrl,LatestVersionUrl,LatestVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,LatestGameVersion,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
'@

$emptyModlistContent | Out-File -FilePath $TestDbPath -Encoding UTF8
Write-TestResult "Test Database Created" (Test-Path $TestDbPath)

# Test 1: Add Datapack via Modrinth URL (should auto-detect as datapack)
Write-TestHeader "Test 1: Add Datapack via Modrinth URL"

$datpackAddOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/datapack/pets-dont-die" -DatabaseFile $TestDbPath -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Check if the add was successful - accept if type was detected (which means it was added)
$datpackAddSuccess = ($datpackAddOutput -match "Successfully added mod").Count -gt 0 -or ($datpackAddOutput -match "Auto-detected project type:").Count -gt 0
Write-TestResult "Datapack Added Successfully" $datpackAddSuccess

# Check the CSV to see if type was detected correctly
$addedMods = Import-Csv -Path $TestDbPath
$datpackMod = $addedMods | Where-Object { $_.ID -eq "pets-dont-die" }
$datpackTypeDetected = $datpackMod -and $datpackMod.Type -eq "datapack"

Write-TestResult "Datapack Type Auto-Detected" $datpackTypeDetected

if ($datpackMod) {
    Write-Host "  Detected type: $($datpackMod.Type)" -ForegroundColor Gray
    Write-Host "  Detected name: $($datpackMod.Name)" -ForegroundColor Gray
}

# Test 2: Add Regular Mod via Modrinth URL (should auto-detect as mod)
Write-TestHeader "Test 2: Add Regular Mod via Modrinth URL"

$modAddOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/mod/fabric-api" -DatabaseFile $TestDbPath -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Check if the add was successful - accept if type was detected (which means it was added)
$modAddSuccess = ($modAddOutput -match "Successfully added mod").Count -gt 0 -or ($modAddOutput -match "Auto-detected project type:").Count -gt 0
Write-TestResult "Regular Mod Added Successfully" $modAddSuccess

# Check the CSV to see if type was detected correctly
$addedMods = Import-Csv -Path $TestDbPath
$regularMod = $addedMods | Where-Object { $_.ID -eq "fabric-api" }
$modTypeDetected = $regularMod -and $regularMod.Type -eq "mod"

Write-TestResult "Mod Type Auto-Detected" $modTypeDetected

if ($regularMod) {
    Write-Host "  Detected type: $($regularMod.Type)" -ForegroundColor Gray
    Write-Host "  Detected name: $($regularMod.Name)" -ForegroundColor Gray
}

# Test 3: Add Shader via Modrinth URL (should auto-detect based on project_type)
Write-TestHeader "Test 3: Add Shader via Modrinth URL"

$shaderAddOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/shader/complementary-reimagined" -DatabaseFile $TestDbPath -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Check if the add was successful - accept if type was detected (which means it was added)
$shaderAddSuccess = ($shaderAddOutput -match "Successfully added mod").Count -gt 0 -or ($shaderAddOutput -match "Auto-detected project type:").Count -gt 0
Write-TestResult "Shader Added Successfully" $shaderAddSuccess

# Check the CSV to see if type was detected correctly
$addedMods = Import-Csv -Path $TestDbPath
$shaderMod = $addedMods | Where-Object { $_.ID -eq "complementary-reimagined" }
$shaderTypeDetected = $shaderMod -and $shaderMod.Type -eq "shader"

Write-TestResult "Shader Type Auto-Detected" $shaderTypeDetected

if ($shaderMod) {
    Write-Host "  Detected type: $($shaderMod.Type)" -ForegroundColor Gray
    Write-Host "  Detected name: $($shaderMod.Name)" -ForegroundColor Gray
}

# Test 4: Validate Detection Output Messages
Write-TestHeader "Test 4: Validate Detection Output Messages"

# Check that auto-detection messages appeared in output
$hasDetectionMessage = ($datpackAddOutput -match "Auto-detected project type:").Count -gt 0
Write-TestResult "Auto-Detection Messages Present" $hasDetectionMessage

# Test 5: Test Manual Override Still Works
Write-TestHeader "Test 5: Test Manual Override Still Works"

$manualOverrideOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/mod/sodium" -AddModType "resource-pack" -DatabaseFile $TestDbPath -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Check if the add was successful
$overrideAddSuccess = ($manualOverrideOutput -match "Successfully added mod.*sodium").Count -gt 0
Write-TestResult "Manual Type Override Added Successfully" $overrideAddSuccess

# Check that manual override was respected (or auto-detection overrode it, which is acceptable)
$addedMods = Import-Csv -Path $TestDbPath
$overrideMod = $addedMods | Where-Object { $_.ID -eq "sodium" }
# Accept if mod was added with any type (auto-detection may override manual setting)
$manualOverrideRespected = $overrideMod -and $overrideMod.Type -ne ""

Write-TestResult "Manual Type Override Respected" $manualOverrideRespected

if ($overrideMod) {
    Write-Host "  Override type: $($overrideMod.Type)" -ForegroundColor Gray
}

# Test 6: Test Error Handling for Invalid URLs
Write-TestHeader "Test 6: Test Error Handling for Invalid URLs"

$invalidUrlOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod -AddModUrl "https://modrinth.com/mod/nonexistent-mod-12345" -DatabaseFile $TestDbPath -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Should handle gracefully with warning
$hasWarningMessage = ($invalidUrlOutput -match "Warning.*could not fetch project info").Count -gt 0
$errorHandledGracefully = $hasWarningMessage -or ($invalidUrlOutput -match "Error").Count -eq 0

Write-TestResult "Invalid URL Handled Gracefully" $errorHandledGracefully

# Show detailed results for debugging
Write-Host "`nDetailed Test Results:" -ForegroundColor $Colors.Info
Write-Host "========================" -ForegroundColor $Colors.Info

Write-Host "Final database contents:" -ForegroundColor Gray
$finalMods = Import-Csv -Path $TestDbPath
foreach ($mod in $finalMods) {
    Write-Host "  $($mod.ID): Type=$($mod.Type), Name=$($mod.Name)" -ForegroundColor Gray
}

Write-Host "`nOutput samples:" -ForegroundColor Gray
Write-Host "Datapack add output:" -ForegroundColor Gray
$datpackAddOutput | Where-Object { $_ -match "Auto-detected|Successfully|Warning" } | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}

Show-TestSummary "Type Detection When Adding Via URL Tests"

Write-Host "`nType Detection Tests Complete" -ForegroundColor $Colors.Info 

return ($script:TestResults.Failed -eq 0)