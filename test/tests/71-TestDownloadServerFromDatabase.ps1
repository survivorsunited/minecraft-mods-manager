# Test 71: Download Server From Database Test
# Tests that DownloadServer downloads ALL server and launcher entries from database

param(
    [string]$TestOutputDir = "test/test-output/71-TestDownloadServerFromDatabase",
    [string]$DatabaseFile = "test-server-download.csv"
)

# Create test output directory
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Start transcript
$logFile = Join-Path $TestOutputDir "71-TestDownloadServerFromDatabase.log"
Start-Transcript -Path $logFile

Write-Host "Test 71: Download Server From Database Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Test database path
$testDbPath = Join-Path $TestOutputDir $DatabaseFile

# Import main functions
try {
    . "$PSScriptRoot\..\..\ModManager.ps1" -SkipExecution
    Write-Host "✓ PASS: ModManager functions imported" -ForegroundColor Green
} catch {
    Write-Host "✗ FAIL: Could not import ModManager functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 1: Create Test Database with Server Entries
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 1: Create Test Database with Server Entries" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

try {
    # Copy real modlist.csv server entries to test database
    $realDb = Import-Csv -Path "modlist.csv"
    $serverEntries = $realDb | Where-Object { $_.Type -eq "server" -or $_.Type -eq "launcher" }
    
    Write-Host "  Found $($serverEntries.Count) server/launcher entries in main database" -ForegroundColor Gray
    
    # Export to test database
    $serverEntries | Export-Csv -Path $testDbPath -NoTypeInformation
    
    Write-Host "✓ PASS: Test database created with server entries" -ForegroundColor Green
    
    # Display server entries
    Write-Host ""
    Write-Host "Server/Launcher entries in test database:" -ForegroundColor Cyan
    foreach ($entry in $serverEntries) {
        Write-Host "  - $($entry.Name) ($($entry.ID)) - Version: $($entry.GameVersion) - Type: $($entry.Type)" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ FAIL: Could not create test database: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Run Download-ServerFiles
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 2: Run Download-ServerFiles Function" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

try {
    # Create test download folder
    $testDownloadFolder = Join-Path $TestOutputDir "download"
    
    # Run the download function
    $downloadCount = Download-ServerFiles -DownloadFolder $testDownloadFolder -ForceDownload
    
    Write-Host ""
    Write-Host "  Downloaded: $downloadCount files" -ForegroundColor Gray
} catch {
    Write-Host "✗ FAIL: Error running Download-ServerFiles: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Check Downloaded Files vs Database
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 3: Verify All Database Entries Were Downloaded" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

$testDownloadFolder = Join-Path $TestOutputDir "download"
$missingDownloads = @()
$foundDownloads = @()

foreach ($entry in $serverEntries) {
    $expectedVersionFolder = Join-Path $testDownloadFolder $entry.GameVersion
    $foundFile = $false
    
    # Check if version folder exists
    if (Test-Path $expectedVersionFolder) {
        # Look for any server/launcher files in the folder
        $files = Get-ChildItem -Path $expectedVersionFolder -Filter "*.jar" -ErrorAction SilentlyContinue
        if ($files.Count -gt 0) {
            $foundFile = $true
            $foundDownloads += $entry
        }
    }
    
    if (-not $foundFile) {
        $missingDownloads += $entry
    }
}

Write-Host "  Database entries: $($serverEntries.Count)" -ForegroundColor Gray
Write-Host "  Downloaded files found: $($foundDownloads.Count)" -ForegroundColor Gray
Write-Host "  Missing downloads: $($missingDownloads.Count)" -ForegroundColor Gray

if ($missingDownloads.Count -gt 0) {
    Write-Host ""
    Write-Host "✗ FAIL: Not all database entries were downloaded" -ForegroundColor Red
    Write-Host "  Missing:" -ForegroundColor Red
    foreach ($missing in $missingDownloads) {
        Write-Host "    - $($missing.Name) ($($missing.GameVersion))" -ForegroundColor Red
    }
} else {
    Write-Host "✓ PASS: All database entries were downloaded" -ForegroundColor Green
}

Write-Host ""

# Test 4: Check Hardcoded vs Dynamic
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 4: Check If Function Uses Database or Hardcoded Values" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

# Check Download-ServerFiles source
$functionSource = Get-Content "$PSScriptRoot\..\..\src\Download\Server\Download-ServerFiles.ps1" -Raw

if ($functionSource -match 'serverFiles = @\(' -and $functionSource -match 'Version = "1.21.5"') {
    Write-Host "✗ FAIL: Download-ServerFiles uses hardcoded values instead of database" -ForegroundColor Red
    Write-Host "  The function should read server entries from the database" -ForegroundColor Yellow
} else {
    Write-Host "✓ PASS: Download-ServerFiles appears to use dynamic values" -ForegroundColor Green
}

Write-Host ""

# Test Summary
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan

$totalTests = 4
$passedTests = 0

# Count passed tests
if ($serverEntries.Count -gt 0) { $passedTests++ }
if ($downloadCount -gt 0) { $passedTests++ }
if ($missingDownloads.Count -eq 0) { $passedTests++ }
if ($functionSource -notmatch 'serverFiles = @\(') { $passedTests++ }

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor Red

Write-Host ""
Write-Host "Key Findings:" -ForegroundColor Yellow
Write-Host "=============" -ForegroundColor Yellow
Write-Host "  Database has $($serverEntries.Count) server/launcher entries" -ForegroundColor Gray
Write-Host "  Function downloaded $downloadCount files" -ForegroundColor Gray
Write-Host "  Missing $($missingDownloads.Count) downloads from database" -ForegroundColor Gray

if ($totalTests -eq $passedTests) {
    Write-Host ""
    Write-Host "🎉 ALL TESTS PASSED! 🎉" -ForegroundColor Green
    Write-Host ""
    Write-Host "Download Server From Database Tests Complete" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ SOME TESTS FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "The Download-ServerFiles function needs to be updated to read from database" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Download Server From Database Tests Complete with failures" -ForegroundColor Red
}

Stop-Transcript
return ($passedTests -eq $totalTests)