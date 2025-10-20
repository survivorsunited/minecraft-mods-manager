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
    
    # Create isolated test data with NextVersion populated
    $testData = @'
Group,Type,GameVersion,ID,Loader,Version,Name,Jar,Url,NextGameVersion,NextVersion,NextVersionUrl
required,mod,1.21.5,fabric-api,fabric,0.113.0+1.21.5,Fabric API,fabric-api-0.113.0+1.21.5.jar,https://modrinth.com/mod/fabric-api,1.21.6,0.114.0+1.21.6,https://cdn.modrinth.com/data/P7dR8mSH/versions/1.21.6.jar
required,mod,1.21.5,lithium,fabric,mc1.21.5-0.14.5,Lithium,lithium-fabric-0.14.5+mc1.21.5.jar,https://modrinth.com/mod/lithium,1.21.6,mc1.21.6-0.14.6,https://cdn.modrinth.com/data/gvQqBUqZ/versions/1.21.6.jar
required,mod,1.21.5,sodium,fabric,mc1.21.5-0.6.3,Sodium,sodium-fabric-0.6.3+mc1.21.5.jar,https://modrinth.com/mod/sodium,1.21.6,mc1.21.6-0.6.4,https://cdn.modrinth.com/data/AANobbMI/versions/1.21.6.jar
required,mod,1.21.5,iris,fabric,mc1.21.5-1.8.3,Iris,iris-fabric-1.8.3+mc1.21.5.jar,https://modrinth.com/mod/iris,1.21.6,mc1.21.6-1.8.4,https://cdn.modrinth.com/data/YL57xq9U/versions/1.21.6.jar
required,mod,1.21.5,modmenu,fabric,11.0.1,Mod Menu,modmenu-11.0.1.jar,https://modrinth.com/mod/modmenu,1.21.6,11.0.2,https://cdn.modrinth.com/data/mOgUt4GM/versions/1.21.6.jar
'@
    
    $testData | Out-File -FilePath $TestModListPath -Encoding UTF8
    $testMods = Import-Csv -Path $TestModListPath
    
    Write-TestResult "Database Setup" $true "Created isolated test database with $($testMods.Count) mods with NextVersion data"
    $script:TestResults.Passed++
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

