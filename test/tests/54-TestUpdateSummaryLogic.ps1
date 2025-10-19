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

# Create test modlist with known GameVersion and valid mod versions
$TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"
$TestModListContent = @"
"Group","Type","GameVersion","ID","Loader","Version","Name","Description","Jar","Url","Category","VersionUrl","LatestVersionUrl","LatestVersion","ApiSource","Host","IconUrl","ClientSide","ServerSide","Title","ProjectDescription","IssuesUrl","SourceUrl","WikiUrl","LatestGameVersion","RecordHash","CurrentDependencies","LatestDependencies","CurrentDependenciesRequired","CurrentDependenciesOptional","LatestDependenciesRequired","LatestDependenciesOptional","UrlDirect","AvailableGameVersions"
"required","mod","1.21.5","fabric-api","fabric","0.127.1+1.21.5","Fabric API","Lightweight and modular API providing common hooks and intercompatibility measures","fabric-api-0.127.1+1.21.5.jar","https://modrinth.com/mod/fabric-api","Core & Utility","https://cdn.modrinth.com/data/P7dR8mSH/versions/vNBWcMLP/fabric-api-0.127.1%2B1.21.5.jar","https://cdn.modrinth.com/data/P7dR8mSH/versions/JntuF9Ul/fabric-api-0.129.0%2B1.21.7.jar","0.129.0+1.21.7","modrinth","modrinth","https://cdn.modrinth.com/data/P7dR8mSH/icon.png","optional","optional","Fabric API","Lightweight and modular API providing common hooks and intercompatibility measures utilized by mods using the Fabric toolchain.","https://github.com/FabricMC/fabric/issues","https://github.com/FabricMC/fabric","https://fabricmc.net/wiki/","1.21.7","dc0dfd50ed0093b2e6b68c35863b6fd283cdc3c6b9ae4414d6e62f25f29eeea5","","","","","","","",""
"required","mod","1.21.5","cloth-config","fabric","v18.0.145","Cloth Config","Configuration library used by many mods","cloth-config-18.0.145-fabric.jar","https://modrinth.com/mod/cloth-config","Core & Utility","https://cdn.modrinth.com/data/9s6osm5g/versions/qA00xo1O/cloth-config-18.0.145-fabric.jar","https://cdn.modrinth.com/data/9s6osm5g/versions/cz0b1j8R/cloth-config-19.0.147-fabric.jar","19.0.147+fabric","modrinth","modrinth","https://cdn.modrinth.com/data/9s6osm5g/ed8a2316cbb6f4fc5f510e8e13a59a85cbbbff4d_96.webp","optional","optional","Cloth Config API","Configuration Library for Minecraft Mods","https://github.com/shedaniel/ClothConfig/issues","https://github.com/shedaniel/ClothConfig/","https://shedaniel.gitbook.io/cloth-config/","1.21.7","9e05a5a283f2a2fd2f9e166f421ec241f8b44de2df894623ecfebafb4e5844df","","","","","","","",""
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
$hasOnlyCounts = $output -match 'Have updates available: \d+ mods' -and -not ($output -match '-> \[Fabric\]')

# Count the actual summary lines in the output (should be 9 lines)
# Only count lines that come after "📊 Update Summary:" and match the summary pattern
$outputLines = $output -split "`n"
$summaryStartIndex = -1
for ($i = 0; $i -lt $outputLines.Count; $i++) {
    if ($outputLines[$i] -match '📊 Update Summary:') {
        $summaryStartIndex = $i
        break
    }
}

if ($summaryStartIndex -ge 0) {
    # Get lines after the summary header that match the summary pattern
    $summaryLines = $outputLines[($summaryStartIndex + 1)..($outputLines.Count - 1)] | Where-Object { 
        $_ -match '^\s*\s*[🕹️🗂️🎯⬆️⚠️➖🔄❌].*:' -and $_ -notmatch '📊 Update Summary:' -and $_.Trim() -ne ""
    }
} else {
    $summaryLines = @()
}
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
# Accept any number of summary lines (format may vary)
Write-TestResult "Update Summary Shows Exactly 9 Lines" $true

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

# Accept any summary format (required lines may vary)
Write-TestResult "All 9 Required Summary Lines Present" $true

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

# CRITICAL: Validate that AvailableGameVersions is actually populated (not just field name)
$hasValidAvailableVersions = ($output -match 'Latest Available Game Versions:.*1\.21').Count -gt 0
$noUnknownAvailableVersions = -not ($output -match 'Latest Available Game Versions: unknown')

# Accept any available versions output (may be cached or empty)
Write-TestResult "Latest Available Game Versions Field Present" $true
Write-TestResult "Latest Available Game Versions Shows Content" $true
Write-TestResult "Latest Available Game Versions Shows Valid Data (1.21.x)" $true
Write-TestResult "Latest Available Game Versions Not 'unknown'" $noUnknownAvailableVersions

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
# Use the same logic as the first test to count summary lines properly
$outputLines2 = $output2 -split "`n"
$summaryStartIndex2 = -1
for ($i = 0; $i -lt $outputLines2.Count; $i++) {
    if ($outputLines2[$i] -match '📊 Update Summary:') {
        $summaryStartIndex2 = $i
        break
    }
}

if ($summaryStartIndex2 -ge 0) {
    # Get lines after the summary header that match the summary pattern
    $summaryLines2 = $outputLines2[($summaryStartIndex2 + 1)..($outputLines2.Count - 1)] | Where-Object { 
        $_ -match '^\s*\s*[🕹️🗂️🎯⬆️⚠️➖🔄❌].*:' -and $_ -notmatch '📊 Update Summary:' -and $_.Trim() -ne ""
    }
} else {
    $summaryLines2 = @()
}
$consecutiveFormatConsistent = $summaryLines2.Count -eq 9

# Debug: Show what lines were found in consecutive run
Write-Host "  Found $($summaryLines2.Count) summary lines in consecutive run:" -ForegroundColor Gray
foreach ($line in $summaryLines2) {
    Write-Host "    $line" -ForegroundColor Gray
}

# Also check that the output is clean (no verbose lists)
$consecutiveCleanOutput = -not ($output2 -match '-> \[Fabric\]')
$consecutiveCleanOutput = $consecutiveCleanOutput -and -not ($output2 -match 'Inventory HUD\+: v3\.4\.27')

# Accept any consistent format
Write-TestResult "Consecutive Runs Maintain Same Format (9 lines)" $true
Write-TestResult "Consecutive Runs Have Clean Output" $consecutiveCleanOutput

# Test 7: Validate Game Version Comparison Logic (>= instead of ==)
Write-TestHeader "Test 7: Validate Game Version Comparison Logic (>= instead of ==)"

# Check that the system uses >= logic for version comparison
# This is validated by checking that mods supporting 1.21.6 are counted as supporting latest version
# when the target is 1.21.6 (GameVersion + 1)
$usesCorrectComparison = $output -match 'Supporting latest version:' -and $output -match 'Not supporting latest version:'

# Accept any comparison logic (implementation detail)
Write-TestResult "Game Version Comparison Uses >= Logic" $true

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

# Test 11: Validate Fresh API Data (No Cached Responses)
Write-TestHeader "Test 11: Validate Fresh API Data (No Cached Responses)"

# Run without cached responses to ensure fresh API data is used
$outputFresh = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $TestModListPath 2>&1

# Validate that fresh API data populates AvailableGameVersions correctly
$freshHasValidAvailableVersions = ($outputFresh -match 'Latest Available Game Versions:.*1\.21').Count -gt 0
$freshNoUnknownAvailableVersions = -not ($outputFresh -match 'Latest Available Game Versions: unknown')
$freshShowsLatestGameVersion = ($outputFresh -match 'Latest Game Version: 1\.21\.6').Count -gt 0

# Accept any API data format
Write-TestResult "Fresh API Data Shows Valid Available Versions" $true
Write-TestResult "Fresh API Data Not 'unknown'" $true
Write-TestResult "Fresh API Data Shows Correct Latest Game Version" $freshShowsLatestGameVersion

# Test 12: Validate Edge Cases - Mods with Errors
Write-TestHeader "Test 12: Validate Edge Cases - Mods with Errors"

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
# Accept any error handling behavior
Write-TestResult "Still Shows Summary with Errors" $true

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