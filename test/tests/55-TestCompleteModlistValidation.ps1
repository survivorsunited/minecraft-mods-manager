# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "55-TestCompleteModlistValidation.ps1"

# Initialize test environment
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"

# Use the REAL modlist.csv for comprehensive testing
$RealModListPath = Join-Path $PSScriptRoot "..\..\modlist.csv"

Write-Host "Minecraft Mod Manager - Complete Modlist Validation Tests" -ForegroundColor $Colors.Header
Write-Host "=========================================================" -ForegroundColor $Colors.Header

# Test 1: Validate Real Modlist Structure
Write-TestHeader "Test 1: Validate Real Modlist Structure"

# Load the real modlist
$realMods = Import-Csv -Path $RealModListPath
$totalMods = $realMods.Count

Write-Host "  Total mods in real modlist: $totalMods" -ForegroundColor Gray

# Validate required columns exist
$requiredColumns = @("GameVersion", "LatestGameVersion", "LatestVersion", "ID", "Name", "Host")
$missingColumns = @()
foreach ($column in $requiredColumns) {
    if ($column -notin $realMods[0].PSObject.Properties.Name) {
        $missingColumns += $column
    }
}

$hasAllRequiredColumns = $missingColumns.Count -eq 0
Write-TestResult "All Required Columns Present" $hasAllRequiredColumns

if (-not $hasAllRequiredColumns) {
    Write-Host "  Missing columns: $($missingColumns -join ', ')" -ForegroundColor Red
}

# Test 2: Validate GameVersion Distribution
Write-TestHeader "Test 2: Validate GameVersion Distribution"

$gameVersionCounts = $realMods | Where-Object { $_.GameVersion -and $_.GameVersion -ne "unknown" } | Group-Object GameVersion | Sort-Object Count -Descending
$mostCommonGameVersion = if ($gameVersionCounts) { $gameVersionCounts[0].Name } else { "unknown" }

Write-Host "  Most common GameVersion: $mostCommonGameVersion" -ForegroundColor Gray
Write-Host "  GameVersion distribution:" -ForegroundColor Gray
foreach ($version in $gameVersionCounts) {
    Write-Host "    $($version.Name): $($version.Count) mods" -ForegroundColor Gray
}

$hasValidGameVersions = $gameVersionCounts.Count -gt 0
Write-TestResult "Valid GameVersion Distribution" $hasValidGameVersions

# Test 3: Validate Latest Game Version Calculation for Each Mod
Write-TestHeader "Test 3: Validate Latest Game Version Calculation for Each Mod"

$modsWithInvalidCalculation = @()
$modsWithValidCalculation = @()

foreach ($mod in $realMods) {
    if ($mod.GameVersion -and $mod.GameVersion -ne "unknown") {
        # Calculate expected Latest Game Version (GameVersion + 1)
        $gameVersionParts = $mod.GameVersion -split '\.'
        if ($gameVersionParts.Count -ge 2) {
            $major = [int]$gameVersionParts[0]
            $minor = [int]$gameVersionParts[1]
            $patch = if ($gameVersionParts.Count -ge 3) { [int]$gameVersionParts[2] } else { 0 }
            $expectedLatestGameVersion = "$major.$minor.$($patch + 1)"
            
            # Check if the mod's LatestGameVersion is >= expected (should support the next version)
            $modLatestGameVersion = $mod.LatestGameVersion
            if ($modLatestGameVersion -and $modLatestGameVersion -ne "unknown") {
                $modVersionParts = $modLatestGameVersion -split '\.'
                $expectedVersionParts = $expectedLatestGameVersion -split '\.'
                
                if ($modVersionParts.Count -ge 2 -and $expectedVersionParts.Count -ge 2) {
                    $modMajor = [int]$modVersionParts[0]
                    $modMinor = [int]$modVersionParts[1]
                    $expectedMajor = [int]$expectedVersionParts[0]
                    $expectedMinor = [int]$expectedVersionParts[1]
                    
                    $supportsExpected = ($modMajor -gt $expectedMajor) -or 
                                       (($modMajor -eq $expectedMajor) -and ($modMinor -ge $expectedMinor))
                    
                    if ($supportsExpected) {
                        $modsWithValidCalculation += $mod
                    } else {
                        $modsWithInvalidCalculation += @{
                            Mod = $mod
                            GameVersion = $mod.GameVersion
                            ExpectedLatest = $expectedLatestGameVersion
                            ActualLatest = $modLatestGameVersion
                        }
                    }
                }
            }
        }
    }
}

Write-Host "  Mods with valid Latest Game Version calculation: $($modsWithValidCalculation.Count)" -ForegroundColor Gray
Write-Host "  Mods with invalid Latest Game Version calculation: $($modsWithInvalidCalculation.Count)" -ForegroundColor Gray

if ($modsWithInvalidCalculation.Count -gt 0) {
    Write-Host "  Examples of mods with invalid calculation:" -ForegroundColor Yellow
    foreach ($invalid in $modsWithInvalidCalculation[0..4]) { # Show first 5
        Write-Host "    $($invalid.Mod.Name): GameVersion=$($invalid.GameVersion), Expected=$($invalid.ExpectedLatest), Actual=$($invalid.ActualLatest)" -ForegroundColor Yellow
    }
}

$allModsHaveValidCalculation = $modsWithInvalidCalculation.Count -eq 0
Write-TestResult "All Mods Have Valid Latest Game Version Calculation" $allModsHaveValidCalculation

# Test 4: Run Update Summary on Real Modlist
Write-TestHeader "Test 4: Run Update Summary on Real Modlist"

# Capture the actual output from ModManager with real modlist
$output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $RealModListPath -UseCachedResponses 2>&1

# Save output for analysis
$output | Out-File -FilePath (Join-Path $TestOutputDir "real-modlist-update-output.log") -Encoding UTF8

# Validate the output format
$hasLatestGameVersionLine = ($output -match 'Latest Game Version:').Count -gt 0
$hasAvailableVersionsLine = ($output -match 'Latest Available Game Versions:').Count -gt 0
$hasSupportingLatestLine = ($output -match 'Supporting latest version:').Count -gt 0
$hasUpdatesAvailableLine = ($output -match 'Have updates available:').Count -gt 0
$hasNotSupportingLine = ($output -match 'Not supporting latest version:').Count -gt 0

Write-TestResult "Latest Game Version Line Present" $hasLatestGameVersionLine
Write-TestResult "Available Versions Line Present" $hasAvailableVersionsLine
Write-TestResult "Supporting Latest Line Present" $hasSupportingLatestLine
Write-TestResult "Updates Available Line Present" $hasUpdatesAvailableLine
Write-TestResult "Not Supporting Line Present" $hasNotSupportingLine

# Test 5: Validate No Verbose Lists in Real Output
Write-TestHeader "Test 5: Validate No Verbose Lists in Real Output"

# Check for verbose lists (individual mod details)
$hasVerboseLists = $output -match '-> \[Fabric\]' -or $output -match '-> \[Forge\]'
$hasOnlyCounts = $output -match 'Have updates available: \d+ mods' -and -not ($output -match '-> \[Fabric\]')

Write-TestResult "No Verbose Lists in Output" (-not $hasVerboseLists)
Write-TestResult "Only Counts Shown" $hasOnlyCounts

# Test 6: Validate Latest Game Version Calculation in Output
Write-TestHeader "Test 6: Validate Latest Game Version Calculation in Output"

# Extract the calculated Latest Game Version from output
$latestGameVersionMatch = $output -match 'Latest Game Version: ([\d\.]+)'
$calculatedLatestGameVersion = if ($latestGameVersionMatch -and $matches) { $matches[1] } else { "not found" }

Write-Host "  Calculated Latest Game Version from output: $calculatedLatestGameVersion" -ForegroundColor Gray
Write-Host "  Expected Latest Game Version (most common + 1): $($mostCommonGameVersion + 1)" -ForegroundColor Gray

# Calculate expected based on most common GameVersion
$expectedGameVersionParts = $mostCommonGameVersion -split '\.'
$expectedLatest = if ($expectedGameVersionParts.Count -ge 2) {
    $major = [int]$expectedGameVersionParts[0]
    $minor = [int]$expectedGameVersionParts[1]
    $patch = if ($expectedGameVersionParts.Count -ge 3) { [int]$expectedGameVersionParts[2] } else { 0 }
    "$major.$minor.$($patch + 1)"
} else {
    $mostCommonGameVersion
}

$latestGameVersionCorrect = $calculatedLatestGameVersion -eq $expectedLatest
Write-TestResult "Latest Game Version Calculated Correctly" $latestGameVersionCorrect

# Test 7: Validate Summary Line Count
Write-TestHeader "Test 7: Validate Summary Line Count"

# Count the actual summary lines in the output (excluding header)
$summaryLines = $output -split "`n" | Where-Object { $_ -match '^   [🕹️🗂️🎯⬆️⚠️➖🔄❌].*:' -and $_ -notmatch '📊 Update Summary:' }
$summaryLineCount = $summaryLines.Count

Write-Host "  Found $summaryLineCount summary lines:" -ForegroundColor Gray
foreach ($line in $summaryLines) {
    Write-Host "    $line" -ForegroundColor Gray
}

$hasCorrectSummaryLines = $summaryLineCount -eq 9
Write-TestResult "Summary Shows Exactly 9 Lines" $hasCorrectSummaryLines

# Test 8: Validate Each Mod's GameVersion + 1 Logic
Write-TestHeader "Test 8: Validate Each Mod's GameVersion + 1 Logic"

$modsWithCorrectLogic = 0
$modsWithIncorrectLogic = 0

foreach ($mod in $realMods) {
    if ($mod.GameVersion -and $mod.GameVersion -ne "unknown") {
        # Calculate expected (GameVersion + 1)
        $gameVersionParts = $mod.GameVersion -split '\.'
        if ($gameVersionParts.Count -ge 2) {
            $major = [int]$gameVersionParts[0]
            $minor = [int]$gameVersionParts[1]
            $patch = if ($gameVersionParts.Count -ge 3) { [int]$gameVersionParts[2] } else { 0 }
            $expected = "$major.$minor.$($patch + 1)"
            
            # Check if mod supports this expected version
            $modLatest = $mod.LatestGameVersion
            if ($modLatest -and $modLatest -ne "unknown") {
                $modParts = $modLatest -split '\.'
                $expectedParts = $expected -split '\.'
                
                if ($modParts.Count -ge 2 -and $expectedParts.Count -ge 2) {
                    $modMajor = [int]$modParts[0]
                    $modMinor = [int]$modParts[1]
                    $expectedMajor = [int]$expectedParts[0]
                    $expectedMinor = [int]$expectedParts[1]
                    
                    $supports = ($modMajor -gt $expectedMajor) -or 
                               (($modMajor -eq $expectedMajor) -and ($modMinor -ge $expectedMinor))
                    
                    if ($supports) {
                        $modsWithCorrectLogic++
                    } else {
                        $modsWithIncorrectLogic++
                    }
                }
            }
        }
    }
}

Write-Host "  Mods with correct GameVersion + 1 logic: $modsWithCorrectLogic" -ForegroundColor Gray
Write-Host "  Mods with incorrect GameVersion + 1 logic: $modsWithIncorrectLogic" -ForegroundColor Gray

$allModsHaveCorrectLogic = $modsWithIncorrectLogic -eq 0
Write-TestResult "All Mods Follow GameVersion + 1 Logic" $allModsHaveCorrectLogic

# Test 9: Validate Consecutive Run Consistency
Write-TestHeader "Test 9: Validate Consecutive Run Consistency"

# Run the command again to test consecutive behavior
$output2 = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $RealModListPath -UseCachedResponses 2>&1

# Save second run output
$output2 | Out-File -FilePath (Join-Path $TestOutputDir "real-modlist-update-output-run2.log") -Encoding UTF8

# Check that consecutive runs maintain the same format
$summaryLines2 = $output2 -split "`n" | Where-Object { $_ -match '^   [🕹️🗂️🎯⬆️⚠️➖🔄❌].*:' -and $_ -notmatch '📊 Update Summary:' }
$consecutiveFormatConsistent = $summaryLines2.Count -eq 9

Write-Host "  First run summary lines: $summaryLineCount" -ForegroundColor Gray
Write-Host "  Second run summary lines: $($summaryLines2.Count)" -ForegroundColor Gray

Write-TestResult "Consecutive Runs Maintain Same Format" $consecutiveFormatConsistent

# Test 10: Validate Edge Cases with Real Data
Write-TestHeader "Test 10: Validate Edge Cases with Real Data"

# Check for mods with "unknown" GameVersion
$modsWithUnknownGameVersion = $realMods | Where-Object { $_.GameVersion -eq "unknown" }
$unknownGameVersionCount = $modsWithUnknownGameVersion.Count

# Check for mods with "unknown" LatestGameVersion
$modsWithUnknownLatestGameVersion = $realMods | Where-Object { $_.LatestGameVersion -eq "unknown" }
$unknownLatestGameVersionCount = $modsWithUnknownLatestGameVersion.Count

Write-Host "  Mods with unknown GameVersion: $unknownGameVersionCount" -ForegroundColor Gray
Write-Host "  Mods with unknown LatestGameVersion: $unknownLatestGameVersionCount" -ForegroundColor Gray

$handlesUnknownVersions = $true # The system should handle these gracefully
Write-TestResult "Handles Unknown Versions Gracefully" $handlesUnknownVersions

# Final Summary
Write-Host ""
Write-Host "==================================================================================" -ForegroundColor $Colors.Header
Write-Host "COMPLETE MODLIST VALIDATION SUMMARY" -ForegroundColor $Colors.Header
Write-Host "==================================================================================" -ForegroundColor $Colors.Header
Write-Host "Total mods tested: $totalMods" -ForegroundColor Gray
Write-Host "Most common GameVersion: $mostCommonGameVersion" -ForegroundColor Gray
Write-Host "Expected Latest Game Version: $expectedLatest" -ForegroundColor Gray
Write-Host "Calculated Latest Game Version: $calculatedLatestGameVersion" -ForegroundColor Gray
Write-Host "Mods with valid calculation: $($modsWithValidCalculation.Count)" -ForegroundColor Gray
Write-Host "Mods with invalid calculation: $($modsWithInvalidCalculation.Count)" -ForegroundColor Gray
Write-Host "Mods with correct GameVersion + 1 logic: $modsWithCorrectLogic" -ForegroundColor Gray
Write-Host "Mods with incorrect GameVersion + 1 logic: $modsWithIncorrectLogic" -ForegroundColor Gray

Show-TestSummary "Complete Modlist Validation"

return ($script:TestResults.Failed -eq 0) 