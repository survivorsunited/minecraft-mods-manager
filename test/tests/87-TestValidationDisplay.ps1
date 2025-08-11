# Test Validation Display Messages
# Tests that validation shows Current/Next/Latest for all mods

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "87-TestValidationDisplay.ps1"

Write-Host "Minecraft Mod Manager - Validation Display Test" -ForegroundColor $Colors.Header
Write-Host "================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName -UseMigratedSchema

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDbPath = Join-Path $TestOutputDir "validation-display-test.csv"

# Create necessary directories
New-Item -ItemType Directory -Path $script:TestApiResponseDir -Force | Out-Null

# Copy the main database (which now has all Current/Next/Latest fields populated)
Copy-Item -Path "$PSScriptRoot\..\..\modlist.csv" -Destination $TestDbPath -Force

Write-TestHeader "Test Validation Display Messages"

Write-Host "  Running validation to see Current/Next/Latest display..." -ForegroundColor Cyan
Write-Host "  Expected format: Validating mod [Current: x | Next: y | Latest: z] for loader..." -ForegroundColor Gray
Write-Host ""

# Run validation and capture first few lines of output
& $ModManagerPath -ValidateAllModVersions -DatabaseFile $TestDbPath -ApiResponseFolder $script:TestApiResponseDir | Select-Object -First 10

Write-Host ""
Write-TestResult "Validation display test completed" $true

# Final summary
Write-TestSummary $TestFileName