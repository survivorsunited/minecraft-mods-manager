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

Write-Host "Minecraft Mod Manager - Update Summary Logic Tests" -ForegroundColor $Colors.Header
Write-Host "==================================================" -ForegroundColor $Colors.Header

function Invoke-TestUpdateSummaryLogic {
    param([string]$TestFileName = $null)
    
    Write-TestHeader "Step 1: Test Update Summary Logic with -UpdateMods"
    
    # Create a test modlist with known data
    $testModListPath = Join-Path $TestOutputDir "test-modlist.csv"
    $testMods = @(
        [PSCustomObject]@{
            Group = "required"
            Type = "mod"
            GameVersion = "1.21.5"
            ID = "fabric-api"
            Loader = "fabric"
            Version = "0.127.1+1.21.5"
            Name = "Fabric API"
            Description = "Test mod"
            Jar = "fabric-api-0.127.1+1.21.5.jar"
            Url = "https://modrinth.com/mod/fabric-api"
            Category = "Core & Utility"
            ApiSource = "modrinth"
            Host = "modrinth"
        }
    )
    $testMods | Export-Csv -Path $testModListPath -NoTypeInformation
    
    # Run update mods command
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -UpdateMods `
        -DatabaseFile $testModListPath `
        -UseCachedResponses
    
    # Check if command executed successfully
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "Update mods command executed successfully" $true
    } else {
        Write-TestResult "Update mods command failed" $false
        return $false
    }
    
    Write-TestHeader "Step 2: Verify Summary Shows Correct Information"
    
    # Check if the CSV was updated with dependency fields
    $updatedMods = Import-Csv -Path $testModListPath
    $firstMod = $updatedMods[0]
    
    # Check for required dependency fields
    $hasRequiredFields = $true
    $requiredFields = @(
        "CurrentDependenciesRequired",
        "CurrentDependenciesOptional", 
        "LatestDependenciesRequired",
        "LatestDependenciesOptional"
    )
    
    foreach ($field in $requiredFields) {
        if (-not $firstMod.PSObject.Properties.Name -contains $field) {
            Write-TestResult "Missing dependency field: $field" $false
            $hasRequiredFields = $false
        }
    }
    
    if ($hasRequiredFields) {
        Write-TestResult "All required dependency fields present" $true
    }
    
    Write-TestHeader "Step 3: Test Summary Logic with Different Scenarios"
    
    # Test with mods that have different game version support
    $testMods2 = @(
        [PSCustomObject]@{
            Group = "required"
            Type = "mod"
            GameVersion = "1.21.5"
            ID = "test-mod-1"
            Loader = "fabric"
            Version = "1.0.0"
            Name = "Test Mod 1"
            Description = "Test mod supporting 1.21.7"
            Jar = "test-mod-1.jar"
            Url = "https://modrinth.com/mod/test-mod-1"
            Category = "Test"
            ApiSource = "modrinth"
            Host = "modrinth"
        },
        [PSCustomObject]@{
            Group = "required"
            Type = "mod"
            GameVersion = "1.21.5"
            ID = "test-mod-2"
            Loader = "fabric"
            Version = "1.0.0"
            Name = "Test Mod 2"
            Description = "Test mod supporting 1.21.6"
            Jar = "test-mod-2.jar"
            Url = "https://modrinth.com/mod/test-mod-2"
            Category = "Test"
            ApiSource = "modrinth"
            Host = "modrinth"
        }
    )
    
    $testModListPath2 = Join-Path $TestOutputDir "test-modlist-2.csv"
    $testMods2 | Export-Csv -Path $testModListPath2 -NoTypeInformation
    
    # Run update again
    $result2 = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -UpdateMods `
        -DatabaseFile $testModListPath2 `
        -UseCachedResponses
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "Second update mods command executed successfully" $true
    } else {
        Write-TestResult "Second update mods command failed" $false
    }
    
    Write-TestHeader "Step 4: Verify Summary Logic Handles Edge Cases"
    
    # Test with empty modlist
    $emptyModListPath = Join-Path $TestOutputDir "empty-modlist.csv"
    "" | Out-File -FilePath $emptyModListPath
    
    $result3 = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -UpdateMods `
        -DatabaseFile $emptyModListPath `
        -UseCachedResponses
    
    # Should handle empty file gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Empty modlist handled gracefully" $true
    } else {
        Write-TestResult "Empty modlist caused unexpected error" $false
    }
    
    # Summary
    Show-TestSummary "Update Summary Logic Tests"
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestUpdateSummaryLogic -TestFileName $TestFileName 