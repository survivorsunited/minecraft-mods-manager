# Test 69: Server URL Configuration Test
# Tests environment variable configuration for server URLs and add-server commands

param(
    [string]$TestOutputDir = "test/test-output/69-TestServerURLConfiguration",
    [string]$DatabaseFile = "test-server-urls.csv"
)

# Create test output directory
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Start transcript
$logFile = Join-Path $TestOutputDir "69-TestServerURLConfiguration.log"
Start-Transcript -Path $logFile

Write-Host "Test 69: Server URL Configuration Test" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

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

# Test 1: Environment Variable Detection
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 1: Environment Variable Detection" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

$minecraftServerUrl = $env:MINECRAFT_SERVER_URL
$fabricServerUrl = $env:FABRIC_SERVER_URL

if ($minecraftServerUrl) {
    Write-Host "✓ PASS: MINECRAFT_SERVER_URL detected" -ForegroundColor Green
    Write-Host "  URL: $minecraftServerUrl" -ForegroundColor Gray
} else {
    Write-Host "✗ FAIL: MINECRAFT_SERVER_URL not found in environment" -ForegroundColor Red
}

if ($fabricServerUrl) {
    Write-Host "✓ PASS: FABRIC_SERVER_URL detected" -ForegroundColor Green
    Write-Host "  URL: $fabricServerUrl" -ForegroundColor Gray
} else {
    Write-Host "✗ FAIL: FABRIC_SERVER_URL not found in environment" -ForegroundColor Red
}

Write-Host ""

# Test 2: Create Test Database
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 2: Create Test Database" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

try {
    # Create minimal CSV with headers
    $csvHeaders = '"Group","Type","GameVersion","ID","Loader","Version","Name","Description","Jar","Url","Category","VersionUrl","LatestVersionUrl","LatestVersion","ApiSource","Host","IconUrl","ClientSide","ServerSide","Title","ProjectDescription","IssuesUrl","SourceUrl","WikiUrl","LatestGameVersion","RecordHash","UrlDirect","AvailableGameVersions","CurrentDependencies","LatestDependencies","CurrentDependenciesRequired","CurrentDependenciesOptional","LatestDependenciesRequired","LatestDependenciesOptional"'
    Set-Content -Path $testDbPath -Value $csvHeaders -Encoding UTF8
    
    Write-Host "✓ PASS: Test database created" -ForegroundColor Green
    Write-Host "  Path: $testDbPath" -ForegroundColor Gray
} catch {
    Write-Host "✗ FAIL: Could not create test database: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 3: Add Minecraft Server to Database
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 3: Add Minecraft Server to Database" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

try {
    $originalDir = Get-Location
    Set-Location $PSScriptRoot\..\..
    
    # Test adding minecraft server
    $result = & .\ModManager.ps1 -AddMod -AddModId "minecraft-server" -AddModName "Minecraft Server" -AddModType "server" -AddModGameVersion "1.21.7" -DatabaseFile $testDbPath
    
    Set-Location $originalDir
    
    # Check if entry was added
    $csvContent = Import-Csv $testDbPath
    $minecraftEntry = $csvContent | Where-Object { $_.ID -eq "minecraft-server" }
    
    if ($minecraftEntry) {
        Write-Host "✓ PASS: Minecraft server added to database" -ForegroundColor Green
        Write-Host "  Name: $($minecraftEntry.Name)" -ForegroundColor Gray
        Write-Host "  Type: $($minecraftEntry.Type)" -ForegroundColor Gray
        Write-Host "  GameVersion: $($minecraftEntry.GameVersion)" -ForegroundColor Gray
        Write-Host "  URL: $($minecraftEntry.Url)" -ForegroundColor Gray
    } else {
        Write-Host "✗ FAIL: Minecraft server not found in database" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ FAIL: Error adding Minecraft server: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Add Fabric Server to Database
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 4: Add Fabric Server to Database" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

try {
    $originalDir = Get-Location
    Set-Location $PSScriptRoot\..\..
    
    # Test adding fabric server
    $result = & .\ModManager.ps1 -AddMod -AddModId "fabric-server" -AddModName "Fabric Server" -AddModType "server" -AddModGameVersion "1.21.7" -AddModLoader "fabric" -DatabaseFile $testDbPath
    
    Set-Location $originalDir
    
    # Check if entry was added
    $csvContent = Import-Csv $testDbPath
    $fabricEntry = $csvContent | Where-Object { $_.ID -eq "fabric-server" }
    
    if ($fabricEntry) {
        Write-Host "✓ PASS: Fabric server added to database" -ForegroundColor Green
        Write-Host "  Name: $($fabricEntry.Name)" -ForegroundColor Gray
        Write-Host "  Type: $($fabricEntry.Type)" -ForegroundColor Gray
        Write-Host "  GameVersion: $($fabricEntry.GameVersion)" -ForegroundColor Gray
        Write-Host "  Loader: $($fabricEntry.Loader)" -ForegroundColor Gray
        Write-Host "  URL: $($fabricEntry.Url)" -ForegroundColor Gray
    } else {
        Write-Host "✗ FAIL: Fabric server not found in database" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ FAIL: Error adding Fabric server: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 5: Verify URL Assignment
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 5: Verify URL Assignment" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

$csvContent = Import-Csv $testDbPath
$minecraftEntry = $csvContent | Where-Object { $_.ID -eq "minecraft-server" }
$fabricEntry = $csvContent | Where-Object { $_.ID -eq "fabric-server" }

$urlsCorrect = $true

if ($minecraftEntry -and $minecraftEntry.Url -eq $minecraftServerUrl) {
    Write-Host "✓ PASS: Minecraft server URL correctly assigned from environment" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Minecraft server URL mismatch" -ForegroundColor Red
    Write-Host "  Expected: $minecraftServerUrl" -ForegroundColor Gray
    Write-Host "  Got: $($minecraftEntry.Url)" -ForegroundColor Gray
    $urlsCorrect = $false
}

if ($fabricEntry -and $fabricEntry.Url -eq $fabricServerUrl) {
    Write-Host "✓ PASS: Fabric server URL correctly assigned from environment" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Fabric server URL mismatch" -ForegroundColor Red
    Write-Host "  Expected: $fabricServerUrl" -ForegroundColor Gray
    Write-Host "  Got: $($fabricEntry.Url)" -ForegroundColor Gray
    $urlsCorrect = $false
}

Write-Host ""

# Test Summary
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan

$totalTests = 5
$passedTests = 0

if ($minecraftServerUrl) { $passedTests++ }
if ($fabricServerUrl) { $passedTests++ }
if ($minecraftEntry) { $passedTests++ }
if ($fabricEntry) { $passedTests++ }
if ($urlsCorrect) { $passedTests++ }

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor Red

if ($passedTests -eq $totalTests) {
    Write-Host ""
    Write-Host "🎉 ALL TESTS PASSED! 🎉" -ForegroundColor Green
    Write-Host ""
    Write-Host "Server URL Configuration Tests Complete" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ SOME TESTS FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Server URL Configuration Tests Complete with failures" -ForegroundColor Red
}

Stop-Transcript
return ($passedTests -eq $totalTests)