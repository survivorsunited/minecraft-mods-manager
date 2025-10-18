# Test Rollover Mods Functionality
# Tests the -RolloverMods parameter and version rollover functionality

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "71-TestRolloverMods.ps1"

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"

Write-Host "Minecraft Mod Manager - Rollover Mods Tests" -ForegroundColor $Colors.Header
Write-Host "===========================================" -ForegroundColor $Colors.Header

function Invoke-TestRolloverMods {
    
    Write-TestSuiteHeader "Test Rollover Mods Functionality" $TestFileName
    
    # Initialize test results
    $script:TestResults = @{
        Total = 0
        Passed = 0
        Failed = 0
    }
    
    # Test 1: Setup test database with mods that have NextVersion data
    Write-TestStep "Setting up test database with NextVersion data"
    
    # Copy a few mods from main database that have NextVersion populated
    $mainMods = Import-Csv "modlist.csv"
    $testMods = $mainMods | Where-Object { $_.NextVersion -and $_.NextVersion -ne "" } | Select-Object -First 5
    
    if ($testMods.Count -ge 5) {
        $testMods | Export-Csv -Path $TestModListPath -NoTypeInformation
        Write-TestResult "Database Setup" $true "Created test database with $($testMods.Count) mods"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Database Setup" $false "Insufficient mods with NextVersion data"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 2: Dry run rollover to NextVersion
    Write-TestStep "Testing dry run rollover to NextVersion"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -RolloverMods -DryRun `
        -DatabaseFile $TestModListPath
    
    if ($LASTEXITCODE -eq 0) {
        # Verify database was NOT modified
        $modsAfterDryRun = Import-Csv -Path $TestModListPath
        $unchanged = $true
        foreach ($mod in $modsAfterDryRun) {
            $originalMod = $testMods | Where-Object { $_.ID -eq $mod.ID } | Select-Object -First 1
            if ($originalMod -and $mod.CurrentVersion -ne $originalMod.CurrentVersion) {
                $unchanged = $false
                break
            }
        }
        
        if ($unchanged) {
            Write-TestResult "Dry Run" $true "Database unchanged in dry run mode"
            $script:TestResults.Passed++
        } else {
            Write-TestResult "Dry Run" $false "Database was modified in dry run mode"
            $script:TestResults.Failed++
        }
    } else {
        Write-TestResult "Dry Run" $false "Dry run command failed"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 3: Actual rollover to NextVersion
    Write-TestStep "Testing actual rollover to NextVersion"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -RolloverMods `
        -DatabaseFile $TestModListPath
    
    if ($LASTEXITCODE -eq 0) {
        # Verify mods were rolled over
        $modsAfterRollover = Import-Csv -Path $TestModListPath
        $rolledOverCount = 0
        foreach ($mod in $modsAfterRollover) {
            $originalMod = $testMods | Where-Object { $_.ID -eq $mod.ID } | Select-Object -First 1
            if ($originalMod -and $originalMod.NextVersion -and $mod.CurrentVersion -eq $originalMod.NextVersion) {
                $rolledOverCount++
            }
        }
        
        if ($rolledOverCount -eq $testMods.Count) {
            Write-TestResult "Rollover Execution" $true "All $rolledOverCount mods rolled over successfully"
            $script:TestResults.Passed++
        } else {
            Write-TestResult "Rollover Execution" $false "Only $rolledOverCount/$($testMods.Count) mods rolled over"
            $script:TestResults.Failed++
        }
    } else {
        Write-TestResult "Rollover Execution" $false "Rollover command failed"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 4: Rollover to specific version (dry run)
    Write-TestStep "Testing rollover to specific version (1.21.9)"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -RolloverMods -RolloverToVersion "1.21.9" -DryRun `
        -DatabaseFile $TestModListPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "Specific Version Rollover" $true "Rollover to specific version executed"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Specific Version Rollover" $false "Specific version rollover failed"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 5: Verify Next* fields are cleared after rollover
    Write-TestStep "Verifying Next* fields cleared after rollover"
    $modsAfterRollover = Import-Csv -Path $TestModListPath
    $allCleared = $true
    foreach ($mod in $modsAfterRollover) {
        if ($mod.NextVersion -and $mod.NextVersion -ne "") {
            $allCleared = $false
            break
        }
    }
    
    if ($allCleared) {
        Write-TestResult "Next Fields Cleared" $true "All Next* fields cleared after rollover"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Next Fields Cleared" $false "Some Next* fields not cleared"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    Write-TestSuiteSummary "Test Rollover Mods Functionality"
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestRolloverMods

