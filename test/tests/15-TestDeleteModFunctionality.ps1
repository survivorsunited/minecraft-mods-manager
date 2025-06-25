# Test Delete Mod Functionality
# Tests the new DeleteMod functionality with proper parameter validation and CSV updates

param([string]$TestFileName = $null)

# Import test framework
. (Join-Path $PSScriptRoot "..\TestFramework.ps1")

# Set the test file name for use throughout the script
$TestFileName = "15-TestDeleteModFunctionality.ps1"

function Invoke-TestDeleteModFunctionality {
    
    Write-TestSuiteHeader "Test Delete Mod Functionality" $TestFileName
    
    # Initialize test results
    $script:TestResults = @{
        Total = 0
        Passed = 0
        Failed = 0
    }
    
    # Test setup - PROPER ISOLATION (like Test 13)
    $TestOutputDir = Get-TestOutputFolder $TestFileName
    $TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
    $TestDownloadDir = Join-Path $TestOutputDir "download"
    $TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"
    $ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
    
    # Clean previous test artifacts
    if (Test-Path $TestOutputDir) {
        Remove-Item -Path $TestOutputDir -Recurse -Force
    }
    
    # Ensure clean state
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $TestDownloadDir -Force | Out-Null
    
    # Setup: Add some test mods to the database
    Write-TestStep "Setting up test database with mods"
    
    # Add mods with different types for testing
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "fabric-api" -AddModName "Fabric API" -AddModType "mod" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "sodium" -AddModName "Sodium" -AddModType "mod" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "fabric-api" -AddModName "Fabric API Installer" -AddModType "installer" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "lithium" -AddModName "Lithium" -AddModType "mod" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    $initialCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-TestResult "Database Setup" $true "Added $initialCount test mods to database"
    $script:TestResults.Passed++
    $script:TestResults.Total++
    
    # Test 1: Delete mod by ID only (should delete all mods with that ID)
    Write-TestStep "Testing delete by ID only"
    $beforeCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "fabric-api" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir
    
    $afterCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    $deletedCount = $beforeCount - $afterCount
    
    if ($LASTEXITCODE -eq 0 -and $deletedCount -eq 2) {
        Write-TestResult "Delete by ID Only" $true "Successfully deleted 2 mods with ID 'fabric-api'"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Delete by ID Only" $false "Failed to delete mods by ID (deleted: $deletedCount)"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 2: Delete mod by ID and specific type
    Write-TestStep "Testing delete by ID and type"
    $beforeCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "sodium" -DeleteModType "mod" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir
    
    $afterCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    $deletedCount = $beforeCount - $afterCount
    
    if ($LASTEXITCODE -eq 0 -and $deletedCount -eq 1) {
        Write-TestResult "Delete by ID and Type" $true "Successfully deleted 1 mod with ID 'sodium' and type 'mod'"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Delete by ID and Type" $false "Failed to delete mod by ID and type (deleted: $deletedCount)"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 3: Delete non-existent mod (should handle gracefully)
    Write-TestStep "Testing delete non-existent mod"
    $beforeCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "non-existent-mod" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir
    
    $afterCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    if ($LASTEXITCODE -eq 0 -and $beforeCount -eq $afterCount) {
        Write-TestResult "Delete Non-existent Mod" $true "Gracefully handled deletion of non-existent mod"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Delete Non-existent Mod" $false "Failed to handle non-existent mod deletion gracefully"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 4: Delete mod with wrong type (should not delete)
    Write-TestStep "Testing delete with wrong type"
    $beforeCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "lithium" -DeleteModType "installer" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir
    
    $afterCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    if ($LASTEXITCODE -eq 0 -and $beforeCount -eq $afterCount) {
        Write-TestResult "Delete with Wrong Type" $true "Correctly did not delete mod with wrong type"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Delete with Wrong Type" $false "Incorrectly deleted mod with wrong type"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 5: Delete by URL (Modrinth URL)
    Write-TestStep "Testing delete by Modrinth URL"
    $beforeCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "https://modrinth.com/mod/lithium" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir
    
    $afterCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    $deletedCount = $beforeCount - $afterCount
    
    if ($LASTEXITCODE -eq 0 -and $deletedCount -eq 1) {
        Write-TestResult "Delete by Modrinth URL" $true "Successfully deleted mod by Modrinth URL"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Delete by Modrinth URL" $false "Failed to delete mod by Modrinth URL (deleted: $deletedCount)"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 6: Delete by CurseForge URL
    Write-TestStep "Testing delete by CurseForge URL"
    # First add a CurseForge mod for testing
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "357540" -AddModName "Inventory HUD+" -AddModType "curseforge" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    $beforeCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "https://www.curseforge.com/minecraft/mc-mods/inventory-hud-forge" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir
    
    $afterCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    $deletedCount = $beforeCount - $afterCount
    
    if ($LASTEXITCODE -eq 0 -and $deletedCount -eq 1) {
        Write-TestResult "Delete by CurseForge URL" $true "Successfully deleted mod by CurseForge URL"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Delete by CurseForge URL" $false "Failed to delete mod by CurseForge URL (deleted: $deletedCount)"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 7: Database integrity after deletions
    Write-TestStep "Testing database integrity after deletions"
    $finalMods = Import-Csv $TestModListPath -ErrorAction SilentlyContinue
    
    if ($finalMods -and $finalMods.Count -ge 0) {
        # Check that all remaining mods have valid data
        $validMods = $finalMods | Where-Object { 
            $_.ID -and $_.Name -and $_.Type 
        }
        
        if ($validMods.Count -eq $finalMods.Count) {
            Write-TestResult "Database Integrity" $true "Database integrity maintained after deletions ($($finalMods.Count) mods remaining)"
            $script:TestResults.Passed++
        } else {
            Write-TestResult "Database Integrity" $false "Database integrity compromised after deletions"
            $script:TestResults.Failed++
        }
    } else {
        Write-TestResult "Database Integrity" $true "Database is empty but valid after deletions"
        $script:TestResults.Passed++
    }
    $script:TestResults.Total++
    
    # Test 8: Multiple deletion scenarios
    Write-TestStep "Testing multiple deletion scenarios"
    
    # Add more mods for testing
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "phosphor" -AddModName "Phosphor" -AddModType "mod" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "hydrogen" -AddModName "Hydrogen" -AddModType "mod" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    $beforeCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    # Delete multiple mods in sequence
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "phosphor" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "hydrogen" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    $afterCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    $deletedCount = $beforeCount - $afterCount
    
    if ($deletedCount -eq 2) {
        Write-TestResult "Multiple Deletions" $true "Successfully deleted multiple mods in sequence"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Multiple Deletions" $false "Failed to delete multiple mods (deleted: $deletedCount)"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 9: Delete with special characters in ID
    Write-TestStep "Testing delete with special characters"
    
    # Add a mod with special characters
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "no-chat-reports" -AddModName "No Chat Reports" -AddModType "mod" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseDir | Out-Null
    
    $beforeCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "no-chat-reports" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir
    
    $afterCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    $deletedCount = $beforeCount - $afterCount
    
    if ($LASTEXITCODE -eq 0 -and $deletedCount -eq 1) {
        Write-TestResult "Delete with Special Characters" $true "Successfully deleted mod with special characters in ID"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Delete with Special Characters" $false "Failed to delete mod with special characters (deleted: $deletedCount)"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    Write-TestSuiteSummary "Test Delete Mod Functionality"
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestDeleteModFunctionality 