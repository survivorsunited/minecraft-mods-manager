# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "18-TestSwitchParameters.ps1"

# Initialize test environment (mandatory: starts console logging)
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$ModListPath = Join-Path $PSScriptRoot "..\..\modlist.csv"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"

Write-Host "Minecraft Mod Manager - Switch Parameter Tests" -ForegroundColor $Colors.Header
Write-Host "================================================" -ForegroundColor $Colors.Header

function Invoke-TestSwitchParameters {
    param([string]$TestFileName = $null)

    Write-TestSuiteHeader "Switch Parameter Tests" $TestFileName

    $allPassed = $true

    # Test 1: -Help parameter
    Write-TestHeader "Test: -Help Parameter"
    Test-Command -Command "& pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Help" -TestName "-Help Parameter"

    # Test 2: -ShowHelp parameter
    Write-TestHeader "Test: -ShowHelp Parameter"
    Test-Command -Command "& pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ShowHelp" -TestName "-ShowHelp Parameter"

    # Test 3: -ForceDownload parameter (with -Download)
    Write-TestHeader "Test: -ForceDownload Parameter"
    Test-Command -Command "& pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Download -ForceDownload -DatabaseFile $ModListPath -DownloadFolder $TestDownloadDir -UseCachedResponses" -TestName "-ForceDownload Parameter"

    # Test 4: -ValidateWithDownload parameter (with -Download)
    Write-TestHeader "Test: -ValidateWithDownload Parameter"
    Test-Command -Command "& pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -Download -ValidateWithDownload -DatabaseFile $ModListPath -DownloadFolder $TestDownloadDir -UseCachedResponses" -TestName "-ValidateWithDownload Parameter"

    # Test 5: -AddMod parameter (should require additional args, expect error)
    Write-TestHeader "Test: -AddMod Parameter (Missing Args)"
    Test-Command -Command "& pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddMod" -TestName "-AddMod Parameter (Missing Args)"

    # Log file verification (mandatory)
    $expectedLogPath = Join-Path $TestOutputDir ("18-TestSwitchParameters.log")
    if (Test-Path $expectedLogPath) {
        Write-Host "✓ Console log created: $expectedLogPath" -ForegroundColor Green
    } else {
        Write-Host "✗ Console log missing: $expectedLogPath" -ForegroundColor Red
        $allPassed = $false
    }

    Show-TestSummary
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestSwitchParameters -TestFileName $TestFileName 