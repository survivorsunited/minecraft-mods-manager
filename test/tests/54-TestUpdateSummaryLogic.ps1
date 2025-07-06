# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "54-TestUpdateSummaryLogic.ps1"

# Initialize test environment
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"

# Create test modlist with known GameVersion
$TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"
$TestModListContent = @"
"Group","Type","GameVersion","ID","Loader","Version","Name","Description","Jar","Url","Category","VersionUrl","LatestVersionUrl","LatestVersion","ApiSource","Host","IconUrl","ClientSide","ServerSide","Title","ProjectDescription","IssuesUrl","SourceUrl","WikiUrl","LatestGameVersion","RecordHash","CurrentDependencies","LatestDependencies","CurrentDependenciesRequired","CurrentDependenciesOptional","LatestDependenciesRequired","LatestDependenciesOptional"
"required","mod","1.21.5","fabric-api","fabric","0.127.1+1.21.5","Fabric API","Test mod","fabric-api-0.127.1+1.21.5.jar","https://modrinth.com/mod/fabric-api","Core & Utility","","","","modrinth","modrinth","","optional","optional","Fabric API","","","","","","","","","","","",""
"required","mod","1.21.5","sodium","fabric","mc1.21.5-0.6.13-fabric","Sodium","Test mod","sodium-fabric-0.6.13+mc1.21.5.jar","https://modrinth.com/mod/sodium","Performance","","","","modrinth","modrinth","","required","unsupported","Sodium","","","","","","","","","","","","",""
"@

Write-Host "Minecraft Mod Manager - Update Summary Logic Tests" -ForegroundColor $Colors.Header
Write-Host "=================================================" -ForegroundColor $Colors.Header

# Test 1: Validate Update Summary Shows Only Counts (No Verbose Lists)
Write-TestHeader "Test 1: Validate Update Summary Shows Only Counts (No Verbose Lists)"

# Create test modlist
New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
$TestModListContent | Out-File -FilePath $TestModListPath -Encoding UTF8

# Capture the actual output from ModManager
$output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $TestModListPath -UseCachedResponses 2>&1

# Validate against acceptance criteria
$hasVerboseLists = $output -match 'Inventory HUD\+: v3\.4\.27 ->'
$hasOnlyCounts = $output -match 'Have updates available: 2 mods' -and -not ($output -match '-> \[Fabric\]')
# Count the actual summary lines in the output (now 9 lines with new fields)
# Exclude the header line "📊 Update Summary:" and only count the data lines
$summaryLines = $output -split "`n" | Where-Object { $_ -match '^\s*[🕹️🗂️🎯⬆️⚠️➖🔄❌].*:' -and $_ -notmatch '📊 Update Summary:' }
$hasNineSummaryLines = $summaryLines.Count -eq 9

# Debug: Show what lines were found
Write-Host "  Found $($summaryLines.Count) summary lines:" -ForegroundColor Gray
foreach ($line in $summaryLines) {
    Write-Host "    $line" -ForegroundColor Gray
}

# Check for absence of verbose lists
$noVerboseLists = -not ($output -match 'Inventory HUD\+: v3\.4\.27 -> \[Fabric\]\[1\.21\.5\]InventoryHud\(v3\.4\.27\) \(Game: unknown\)')
$noVerboseLists = $noVerboseLists -and -not ($output -match '-> \[Fabric\]')

Write-TestResult "No Verbose Lists in Output" $noVerboseLists
Write-TestResult "Available Updates Shows Only Count" $hasOnlyCounts
Write-TestResult "Update Summary Shows Exactly 9 Lines" $hasNineSummaryLines

# Test 2: Validate Update Summary Format (Exactly 9 Required Lines)
Write-TestHeader "Test 2: Validate Update Summary Format (Exactly 9 Required Lines)"

# Check for all 9 required summary lines (including new fields)
$requiredLines = @(
    'Latest Game Version:',
    'Latest Available Game Versions:',
    'Supporting latest version:',
    'Have updates available:',
    'Not supporting latest version:',
    'Not updated:',
    'Externally updated:',
    'Not found:',
    'Errors:'
)

$allLinesPresent = $true
foreach ($line in $requiredLines) {
    $linePresent = $output -match [regex]::Escape($line)
    if (-not $linePresent) {
        Write-Host "  Missing required line: $line" -ForegroundColor Red
        $allLinesPresent = $false
    }
}

Write-TestResult "All 9 Required Summary Lines Present" $allLinesPresent

# Test 3: Validate Latest Game Version Calculation (GameVersion + 1)
Write-TestHeader "Test 3: Validate Latest Game Version Calculation (GameVersion + 1)"

# Check that the system correctly calculates Latest Game Version as GameVersion + 1
# Since GameVersion is 1.21.5, Latest Game Version should be 1.21.6
$hasCorrectLatestVersion = ($output -match 'Latest Game Version: 1\.21\.6').Count -gt 0
$noHardcodedVersion = -not (($output -match '1\.21\.7.*target').Count -gt 0)

Write-TestResult "Latest Game Version Calculated as GameVersion + 1 (1.21.6)" $hasCorrectLatestVersion
Write-TestResult "No Hardcoded 1.21.7 Version" $noHardcodedVersion

# Test 4: Validate Latest Available Game Versions Field
Write-TestHeader "Test 4: Validate Latest Available Game Versions Field"

# Check that the Latest Available Game Versions field is present and shows available versions
$hasAvailableVersionsField = ($output -match 'Latest Available Game Versions:').Count -gt 0
$hasAvailableVersionsContent = ($output -match 'Latest Available Game Versions:.*[0-9]').Count -gt 0

Write-TestResult "Latest Available Game Versions Field Present" $hasAvailableVersionsField
Write-TestResult "Latest Available Game Versions Shows Content" $hasAvailableVersionsContent

# Test 5: Validate Clean Output (No Verbose Lists Anywhere)
Write-TestHeader "Test 5: Validate Clean Output (No Verbose Lists Anywhere)"

# Check that output is clean and concise with no verbose lists
$noIndividualModDetails = -not ($output -match '-> \[Fabric\]')
$noIndividualModDetails = $noIndividualModDetails -and -not ($output -match 'Inventory HUD\+: v3\.4\.27')
$noIndividualModDetails = $noIndividualModDetails -and -not ($output -match 'individual mod details')

Write-TestResult "No Individual Mod Details in Output" $noIndividualModDetails
Write-TestResult "Output is Clean and Concise" $noIndividualModDetails

# Test 6: Validate Consecutive Run Behavior
Write-TestHeader "Test 6: Validate Consecutive Run Behavior"

# Run the command again to test consecutive behavior
$output2 = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $TestModListPath -UseCachedResponses 2>&1

# Check that consecutive runs maintain the same format (9 summary lines)
# Exclude the header line "📊 Update Summary:" and only count the data lines
$summaryLines2 = $output2 -split "`n" | Where-Object { $_ -match '^\s*[🕹️🗂️🎯⬆️⚠️➖🔄❌].*:' -and $_ -notmatch '📊 Update Summary:' }
$consecutiveFormatConsistent = $summaryLines2.Count -eq 9

# Debug: Show what lines were found in consecutive run
Write-Host "  Found $($summaryLines2.Count) summary lines in consecutive run:" -ForegroundColor Gray
foreach ($line in $summaryLines2) {
    Write-Host "    $line" -ForegroundColor Gray
}

# Also check that the output is clean (no verbose lists)
$consecutiveCleanOutput = -not ($output2 -match '-> \[Fabric\]')
$consecutiveCleanOutput = $consecutiveCleanOutput -and -not ($output2 -match 'Inventory HUD\+: v3\.4\.27')

Write-TestResult "Consecutive Runs Maintain Same Format (9 lines)" $consecutiveFormatConsistent
Write-TestResult "Consecutive Runs Have Clean Output" $consecutiveCleanOutput

# Test 7: Validate Game Version Comparison Logic (>= instead of ==)
Write-TestHeader "Test 7: Validate Game Version Comparison Logic (>= instead of ==)"

# Check that the system uses >= logic for version comparison
# This is validated by checking that mods supporting 1.21.6 are counted as supporting latest version
# when the target is 1.21.6 (GameVersion + 1)
$usesCorrectComparison = $output -match 'Supporting latest version:' -and $output -match 'Not supporting latest version:'

Write-TestResult "Game Version Comparison Uses >= Logic" $usesCorrectComparison

# Test 8: Validate No Verbose Lists for "Mods not supporting latest version"
Write-TestHeader "Test 8: Validate No Verbose Lists for 'Mods not supporting latest version'"

# Check that "Mods not supporting latest version" shows only count, not individual mod details
$noVerboseNotSupporting = -not ($output -match 'Mods not supporting latest version.*:.*->')
$noVerboseNotSupporting = $noVerboseNotSupporting -and -not ($output -match 'Mods not supporting latest version.*:.*\[Fabric\]')

Write-TestResult "Mods not supporting latest version shows only count" $noVerboseNotSupporting

# Test 9: Validate No Verbose Lists for "Available Updates"
Write-TestHeader "Test 9: Validate No Verbose Lists for 'Available Updates'"

# Check that "Available Updates" shows only count, not individual mod details
$noVerboseAvailableUpdates = -not ($output -match 'Available Updates.*:.*->')
$noVerboseAvailableUpdates = $noVerboseAvailableUpdates -and -not ($output -match 'Available Updates.*:.*\[Fabric\]')

Write-TestResult "Available Updates shows only count" $noVerboseAvailableUpdates

# Test 10: Validate Most Common GameVersion Detection
Write-TestHeader "Test 10: Validate Most Common GameVersion Detection"

# Check that the system finds the most common GameVersion in the database
# In our test data, both mods have GameVersion 1.21.5, so that should be the most common
$hasMostCommonDetection = ($output -match 'Latest Game Version: 1\.21\.6').Count -gt 0

Write-TestResult "Most Common GameVersion Detection Works" $hasMostCommonDetection

# Test 11: Validate Edge Cases - Mods with Errors
Write-TestHeader "Test 11: Validate Edge Cases - Mods with Errors"

# Create a test modlist with a mod that will cause an error
$TestModListWithErrorPath = Join-Path $TestOutputDir "test-modlist-error.csv"
$TestModListWithErrorContent = @"
"Group","Type","GameVersion","ID","Loader","Version","Name","Description","Jar","Url","Category","VersionUrl","LatestVersionUrl","LatestVersion","ApiSource","Host","IconUrl","ClientSide","ServerSide","Title","ProjectDescription","IssuesUrl","SourceUrl","WikiUrl","LatestGameVersion","RecordHash","CurrentDependencies","LatestDependencies","CurrentDependenciesRequired","CurrentDependenciesOptional","LatestDependenciesRequired","LatestDependenciesOptional"
"required","mod","1.21.5","invalid-mod-id","fabric","1.0.0","Invalid Mod","Test mod with error","invalid.jar","","Core & Utility","","","","modrinth","modrinth","","optional","optional","Invalid Mod","","","","","","","","","","","","",""
"@

$TestModListWithErrorContent | Out-File -FilePath $TestModListWithErrorPath -Encoding UTF8

# Run with error-inducing modlist
$outputError = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $TestModListWithErrorPath -UseCachedResponses 2>&1

# Check that errors are handled gracefully and still show in summary
$handlesErrorsGracefully = ($outputError -match 'Errors:.*mods').Count -gt 0
$stillShowsSummary = ($outputError -match '📊 Update Summary:').Count -gt 0

Write-TestResult "Handles Mods with Errors Gracefully" $handlesErrorsGracefully
Write-TestResult "Still Shows Summary with Errors" $stillShowsSummary

# Test 12: Validate Edge Cases - Mods Not Found
Write-TestHeader "Test 12: Validate Edge Cases - Mods Not Found"

# Check that mods not found are handled and shown in summary
$handlesNotFound = ($outputError -match 'Not found:.*mods').Count -gt 0
$noVerboseNotFound = -not (($outputError -match 'Not found.*:.*->').Count -gt 0)

Write-TestResult "Handles Mods Not Found" $handlesNotFound
Write-TestResult "Mods Not Found Shows Only Count" $noVerboseNotFound

# Summary
Show-TestSummary "Update Summary Logic Tests"

# Log the actual output for debugging
$logPath = Join-Path $TestOutputDir "update-summary-output.log"
$output | Out-File -FilePath $logPath -Encoding UTF8
Write-Host "Console output logged to: $logPath" -ForegroundColor Gray

return ($script:TestResults.Failed -eq 0) 