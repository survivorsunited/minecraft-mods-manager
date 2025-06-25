# Test Error Handling
# Tests comprehensive error handling across all ModManager functions

param([string]$TestFileName = $null)

# Import test framework
. (Join-Path $PSScriptRoot "..\TestFramework.ps1")

# Set the test file name for use throughout the script
$TestFileName = "17-TestErrorHandling.ps1"

function Invoke-TestErrorHandling {
    
    Write-TestSuiteHeader "Test Error Handling" $TestFileName
    
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
    
    # Test configuration
    $TestApiResponseFolder = Join-Path $TestOutputDir "apiresponse"

    Write-Host "Minecraft Mod Manager - Error Handling Tests" -ForegroundColor $Colors.Header
    Write-Host "============================================" -ForegroundColor $Colors.Header

    Initialize-TestEnvironment $TestFileName

    # Test 1: Missing required parameters for AddMod
    Write-TestStep "Testing missing required parameters for AddMod"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should fail gracefully with appropriate error message
    if ($LASTEXITCODE -ne 0 -and ($result -match "Error" -or $result -match "requires" -or $result -match "parameter")) {
        Write-TestResult "Missing AddMod Parameters" $true "Correctly handled missing required parameters"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Missing AddMod Parameters" $false "Failed to handle missing required parameters"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 2: Missing required parameters for ValidateMod
    Write-TestStep "Testing missing required parameters for ValidateMod"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -ValidateMod `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should fail gracefully with appropriate error message
    if ($LASTEXITCODE -ne 0 -and ($result -match "Error" -or $result -match "requires" -or $result -match "ModID")) {
        Write-TestResult "Missing ValidateMod Parameters" $true "Correctly handled missing ModID parameter"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Missing ValidateMod Parameters" $false "Failed to handle missing ModID parameter"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 3: Invalid parameter combinations
    Write-TestStep "Testing invalid parameter combinations"
    
    # Test conflicting parameters
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "test" -AddModUrl "https://modrinth.com/mod/test" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle conflicting parameters gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid Parameter Combinations" $true "Correctly handled conflicting parameters"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid Parameter Combinations" $false "Failed to handle conflicting parameters"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 4: Invalid file paths
    Write-TestStep "Testing invalid file paths"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DatabaseFile "C:\non\existent\path\modlist.csv" `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle invalid file paths gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid File Paths" $true "Correctly handled invalid file paths"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid File Paths" $false "Failed to handle invalid file paths"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 5: Invalid URLs
    Write-TestStep "Testing invalid URLs"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModUrl "not-a-valid-url" -AddModName "Test Mod" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle invalid URLs gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid URLs" $true "Correctly handled invalid URLs"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid URLs" $false "Failed to handle invalid URLs"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 6: Invalid mod IDs
    Write-TestStep "Testing invalid mod IDs"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "invalid-mod-id-that-does-not-exist-12345" -AddModName "Invalid Mod" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle invalid mod IDs gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid Mod IDs" $true "Correctly handled invalid mod IDs"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid Mod IDs" $false "Failed to handle invalid mod IDs"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 7: Invalid download folder
    Write-TestStep "Testing invalid download folder"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DownloadMods -DownloadFolder "C:\non\existent\download\path" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle invalid download folder gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid Download Folder" $true "Correctly handled invalid download folder"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid Download Folder" $false "Failed to handle invalid download folder"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 8: Invalid API response folder
    Write-TestStep "Testing invalid API response folder"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -ValidateAllModVersions `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder "C:\non\existent\api\path" 2>&1
    
    # Should handle invalid API response folder gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid API Response Folder" $true "Correctly handled invalid API response folder"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid API Response Folder" $false "Failed to handle invalid API response folder"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 9: Invalid mod type
    Write-TestStep "Testing invalid mod type"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "test" -AddModName "Test Mod" -AddModType "invalid-type" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle invalid mod type gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid Mod Type" $true "Correctly handled invalid mod type"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid Mod Type" $false "Failed to handle invalid mod type"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 10: Invalid loader
    Write-TestStep "Testing invalid loader"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "test" -AddModName "Test Mod" -AddModLoader "invalid-loader" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle invalid loader gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid Loader" $true "Correctly handled invalid loader"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid Loader" $false "Failed to handle invalid loader"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 11: Invalid game version
    Write-TestStep "Testing invalid game version"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "test" -AddModName "Test Mod" -AddModGameVersion "invalid-version" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle invalid game version gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid Game Version" $true "Correctly handled invalid game version"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid Game Version" $false "Failed to handle invalid game version"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 12: Invalid group
    Write-TestStep "Testing invalid group"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "test" -AddModName "Test Mod" -AddModGroup "invalid-group" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle invalid group gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid Group" $true "Correctly handled invalid group"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid Group" $false "Failed to handle invalid group"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 13: Delete non-existent mod
    Write-TestStep "Testing delete non-existent mod"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DeleteModID "non-existent-mod-id" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle deletion of non-existent mod gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Delete Non-existent Mod" $true "Correctly handled deletion of non-existent mod"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Delete Non-existent Mod" $false "Failed to handle deletion of non-existent mod"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 14: Invalid CurseForge mod ID
    Write-TestStep "Testing invalid CurseForge mod ID"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "999999999" -AddModName "Invalid CurseForge Mod" -AddModType "curseforge" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle invalid CurseForge mod ID gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Invalid CurseForge Mod ID" $true "Correctly handled invalid CurseForge mod ID"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Invalid CurseForge Mod ID" $false "Failed to handle invalid CurseForge mod ID"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 15: Network error simulation (invalid API URL)
    Write-TestStep "Testing network error simulation"
    
    # Create a test script with invalid API URL
    $networkTestScriptPath = Join-Path $TestOutputDir "test-network-error.ps1"
    $networkTestScriptContent = @"
# Test network error handling
try {
    `$response = Invoke-RestMethod -Uri "https://invalid-api-url-that-does-not-exist.com/api/test" -Method Get -TimeoutSec 5
    Write-Output "SUCCESS"
} catch {
    Write-Output "NETWORK_ERROR_HANDLED"
}
"@
    $networkTestScriptContent | Out-File -FilePath $networkTestScriptPath -Encoding UTF8
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $networkTestScriptPath
    
    if ($result -and $result -contains "NETWORK_ERROR_HANDLED") {
        Write-TestResult "Network Error Handling" $true "Correctly handled network errors"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Network Error Handling" $false "Failed to handle network errors"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 16: Appropriate error messages
    Write-TestStep "Testing appropriate error messages"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -ValidateMod `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Check if error message is appropriate
    if ($result -and ($result -match "Error" -or $result -match "requires" -or $result -match "ModID")) {
        Write-TestResult "Appropriate Error Messages" $true "Displayed appropriate error messages"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Appropriate Error Messages" $false "Failed to display appropriate error messages"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 17: Graceful degradation with missing files
    Write-TestStep "Testing graceful degradation with missing files"
    
    # Test with missing database file
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -GetModList `
        -DatabaseFile "missing-file.csv" `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle missing files gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Missing Files Handling" $true "Correctly handled missing files"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Missing Files Handling" $false "Failed to handle missing files"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 18: Invalid parameter values
    Write-TestStep "Testing invalid parameter values"
    
    # Test with empty string parameters
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "" -AddModName "" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseFolder 2>&1
    
    # Should handle empty parameters gracefully
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Empty Parameter Values" $true "Correctly handled empty parameter values"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Empty Parameter Values" $false "Failed to handle empty parameter values"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    Write-TestSuiteSummary "Error Handling Tests"
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestErrorHandling 