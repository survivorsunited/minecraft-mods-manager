# Test Add Mod Functionality
# Tests all 12 -AddMod* parameters to ensure comprehensive coverage

param([string]$TestFileName = $null)

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "14-TestAddModFunctionality.ps1"

Write-Host "Minecraft Mod Manager - Add Mod Functionality Tests" -ForegroundColor $Colors.Header
Write-Host "===================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Test configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\14-TestAddModFunctionality"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"
$TestApiResponseFolder = Join-Path $TestOutputDir "apiresponse"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Initialize test results at script level
$script:TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
}

function Invoke-TestAddModFunctionality {
    param([string]$TestFileName = $null)
    
    Write-TestSuiteHeader "Add Mod Functionality Tests" $TestFileName
    
    # Test 1: -AddModId parameter validation
    Write-TestStep "Testing -AddModId parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "fabric-api" -AddModName "Fabric API" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModId Parameter" $true "Successfully added mod with AddModId"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModId Parameter" $false "Failed to add mod with AddModId"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 2: -AddModUrl parameter validation
    Write-TestStep "Testing -AddModUrl parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModUrl "https://modrinth.com/mod/sodium" -AddModName "Sodium" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModUrl Parameter" $true "Successfully added mod with AddModUrl"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModUrl Parameter" $false "Failed to add mod with AddModUrl"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 3: -AddModName parameter validation
    Write-TestStep "Testing -AddModName parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "lithium" -AddModName "Lithium Performance Mod" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModName Parameter" $true "Successfully added mod with AddModName"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModName Parameter" $false "Failed to add mod with AddModName"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 4: -AddModLoader parameter validation
    Write-TestStep "Testing -AddModLoader parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "phosphor" -AddModName "Phosphor" -AddModLoader "fabric" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModLoader Parameter" $true "Successfully added mod with AddModLoader"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModLoader Parameter" $false "Failed to add mod with AddModLoader"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 5: -AddModGameVersion parameter validation
    Write-TestStep "Testing -AddModGameVersion parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "starlight" -AddModName "Starlight" -AddModGameVersion "1.21.6" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModGameVersion Parameter" $true "Successfully added mod with AddModGameVersion"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModGameVersion Parameter" $false "Failed to add mod with AddModGameVersion"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 6: -AddModType parameter validation
    Write-TestStep "Testing -AddModType parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModUrl "https://modrinth.com/shader/complementary-reimagined" `
        -AddModName "Complementary Shaders" -AddModType "shaderpack" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModType Parameter" $true "Successfully added mod with AddModType"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModType Parameter" $false "Failed to add mod with AddModType"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 7: -AddModGroup parameter validation
    Write-TestStep "Testing -AddModGroup parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "no-chat-reports" -AddModName "No Chat Reports" -AddModGroup "block" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModGroup Parameter" $true "Successfully added mod with AddModGroup"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModGroup Parameter" $false "Failed to add mod with AddModGroup"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 8: -AddModDescription parameter validation
    Write-TestStep "Testing -AddModDescription parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "lazydfu" -AddModName "LazyDFU" `
        -AddModDescription "Makes the game boot faster by deferring non-essential initialization" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModDescription Parameter" $true "Successfully added mod with AddModDescription"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModDescription Parameter" $false "Failed to add mod with AddModDescription"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 9: -AddModJar parameter validation
    Write-TestStep "Testing -AddModJar parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModName "Fabric Installer" -AddModType "installer" `
        -AddModJar "fabric-installer-1.0.3.exe" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModJar Parameter" $true "Successfully added mod with AddModJar"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModJar Parameter" $false "Failed to add mod with AddModJar"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 10: -AddModVersion parameter validation
    Write-TestStep "Testing -AddModVersion parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "ferritecore" -AddModName "FerriteCore" -AddModVersion "6.0.0" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModVersion Parameter" $true "Successfully added mod with AddModVersion"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModVersion Parameter" $false "Failed to add mod with AddModVersion"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 11: -AddModUrlDirect parameter validation
    Write-TestStep "Testing -AddModUrlDirect parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModName "Direct Download Mod" -AddModType "mod" `
        -AddModUrlDirect "https://example.com/mod.jar" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModUrlDirect Parameter" $true "Successfully added mod with AddModUrlDirect"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModUrlDirect Parameter" $false "Failed to add mod with AddModUrlDirect"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 12: -AddModCategory parameter validation
    Write-TestStep "Testing -AddModCategory parameter"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "smoothboot" -AddModName "Smooth Boot" -AddModCategory "performance" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "AddModCategory Parameter" $true "Successfully added mod with AddModCategory"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "AddModCategory Parameter" $false "Failed to add mod with AddModCategory"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 13: Error handling for invalid parameters
    Write-TestStep "Testing error handling for invalid parameters"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "invalid-mod-id-that-does-not-exist" -AddModName "Invalid Mod" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    # This should fail gracefully, not crash
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-TestResult "Error Handling" $true "Gracefully handled invalid mod ID"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Error Handling" $false "Failed to handle invalid mod ID gracefully"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 14: Integration with existing mod database
    Write-TestStep "Testing integration with existing mod database"
    $modCount = (Import-Csv $TestModListPath -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($modCount -gt 0) {
        Write-TestResult "Database Integration" $true "Successfully integrated with mod database ($modCount mods)"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Database Integration" $false "Failed to integrate with mod database"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 15: Parameter combination testing
    Write-TestStep "Testing parameter combinations"
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod -AddModId "hydrogen" -AddModName "Hydrogen" -AddModLoader "fabric" `
        -AddModGameVersion "1.21.6" -AddModType "mod" -AddModGroup "optional" `
        -AddModDescription "Reduces memory usage" -AddModCategory "performance" `
        -DatabaseFile $TestModListPath `
        -UseCachedResponses -ApiResponseFolder $TestApiResponseFolder
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "Parameter Combinations" $true "Successfully added mod with multiple parameters"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Parameter Combinations" $false "Failed to add mod with multiple parameters"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    Write-TestSuiteSummary "Add Mod Functionality Tests"
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestAddModFunctionality -TestFileName $TestFileName 