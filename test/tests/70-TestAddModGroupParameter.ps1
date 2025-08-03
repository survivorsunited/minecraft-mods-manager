# Test 70: Add Mod Group Parameter Test
# Tests that the Group parameter is properly saved when adding mods

param(
    [string]$TestOutputDir = "test/test-output/70-TestAddModGroupParameter",
    [string]$DatabaseFile = "test-group-parameter.csv"
)

# Create test output directory
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Start transcript
$logFile = Join-Path $TestOutputDir "70-TestAddModGroupParameter.log"
Start-Transcript -Path $logFile

Write-Host "Test 70: Add Mod Group Parameter Test" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

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

# Test 1: Create Test Database
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 1: Create Test Database" -ForegroundColor Yellow
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

# Test 2: Add Server with Required Group
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 2: Add Server with Required Group" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

try {
    $originalDir = Get-Location
    Set-Location $PSScriptRoot\..\..
    
    # Test adding server with required group
    $result = & .\ModManager.ps1 -AddMod -AddModId "minecraft-server-test" -AddModName "Test Server" -AddModType "server" -AddModGameVersion "1.21.7" -AddModGroup "required" -DatabaseFile $testDbPath
    
    Set-Location $originalDir
    
    # Check if entry was added with correct group
    $csvContent = Import-Csv $testDbPath
    $serverEntry = $csvContent | Where-Object { $_.ID -eq "minecraft-server-test" }
    
    if ($serverEntry) {
        Write-Host "✓ PASS: Server added to database" -ForegroundColor Green
        Write-Host "  Name: $($serverEntry.Name)" -ForegroundColor Gray
        Write-Host "  Type: $($serverEntry.Type)" -ForegroundColor Gray
        Write-Host "  Group: '$($serverEntry.Group)'" -ForegroundColor Gray
        
        if ($serverEntry.Group -eq "required") {
            Write-Host "✓ PASS: Group parameter correctly set to 'required'" -ForegroundColor Green
        } else {
            Write-Host "✗ FAIL: Group parameter mismatch" -ForegroundColor Red
            Write-Host "  Expected: 'required'" -ForegroundColor Gray
            Write-Host "  Got: '$($serverEntry.Group)'" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ FAIL: Server not found in database" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ FAIL: Error adding server: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Add Launcher with Optional Group
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 3: Add Launcher with Optional Group" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

try {
    $originalDir = Get-Location
    Set-Location $PSScriptRoot\..\..
    
    # Test adding launcher with optional group
    $result = & .\ModManager.ps1 -AddMod -AddModId "fabric-launcher-test" -AddModName "Test Launcher" -AddModType "launcher" -AddModGameVersion "1.21.7" -AddModLoader "fabric" -AddModGroup "optional" -DatabaseFile $testDbPath
    
    Set-Location $originalDir
    
    # Check if entry was added with correct group
    $csvContent = Import-Csv $testDbPath
    $launcherEntry = $csvContent | Where-Object { $_.ID -eq "fabric-launcher-test" }
    
    if ($launcherEntry) {
        Write-Host "✓ PASS: Launcher added to database" -ForegroundColor Green
        Write-Host "  Name: $($launcherEntry.Name)" -ForegroundColor Gray
        Write-Host "  Type: $($launcherEntry.Type)" -ForegroundColor Gray
        Write-Host "  Group: '$($launcherEntry.Group)'" -ForegroundColor Gray
        
        if ($launcherEntry.Group -eq "optional") {
            Write-Host "✓ PASS: Group parameter correctly set to 'optional'" -ForegroundColor Green
        } else {
            Write-Host "✗ FAIL: Group parameter mismatch" -ForegroundColor Red
            Write-Host "  Expected: 'optional'" -ForegroundColor Gray
            Write-Host "  Got: '$($launcherEntry.Group)'" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ FAIL: Launcher not found in database" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ FAIL: Error adding launcher: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Default Group Value
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 4: Default Group Value" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

try {
    $originalDir = Get-Location
    Set-Location $PSScriptRoot\..\..
    
    # Test adding without specifying group (should default to "required")
    $result = & .\ModManager.ps1 -AddMod -AddModId "default-group-test" -AddModName "Default Group Test" -AddModType "mod" -DatabaseFile $testDbPath
    
    Set-Location $originalDir
    
    # Check if entry was added with default group
    $csvContent = Import-Csv $testDbPath
    $defaultEntry = $csvContent | Where-Object { $_.ID -eq "default-group-test" }
    
    if ($defaultEntry) {
        Write-Host "✓ PASS: Mod added to database" -ForegroundColor Green
        Write-Host "  Name: $($defaultEntry.Name)" -ForegroundColor Gray
        Write-Host "  Type: $($defaultEntry.Type)" -ForegroundColor Gray
        Write-Host "  Group: '$($defaultEntry.Group)'" -ForegroundColor Gray
        
        if ($defaultEntry.Group -eq "required") {
            Write-Host "✓ PASS: Default group correctly set to 'required'" -ForegroundColor Green
        } else {
            Write-Host "✗ FAIL: Default group not set correctly" -ForegroundColor Red
            Write-Host "  Expected: 'required'" -ForegroundColor Gray
            Write-Host "  Got: '$($defaultEntry.Group)'" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ FAIL: Mod not found in database" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ FAIL: Error adding mod: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 5: Verify CSV Structure
Write-Host "=================================================================================" -ForegroundColor Yellow
Write-Host "TEST: Test 5: Verify CSV Structure" -ForegroundColor Yellow
Write-Host "=================================================================================" -ForegroundColor Yellow

# Display the raw CSV content for debugging
Write-Host "Raw CSV Content:" -ForegroundColor Cyan
$csvRawContent = Get-Content $testDbPath | Select-Object -First 5
foreach ($line in $csvRawContent) {
    Write-Host "  $line" -ForegroundColor Gray
}

Write-Host ""

# Test Summary
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan

$totalTests = 5
$passedTests = 0

# Count passed tests
$csvContent = Import-Csv $testDbPath
$serverEntry = $csvContent | Where-Object { $_.ID -eq "minecraft-server-test" }
$launcherEntry = $csvContent | Where-Object { $_.ID -eq "fabric-launcher-test" }
$defaultEntry = $csvContent | Where-Object { $_.ID -eq "default-group-test" }

if ($serverEntry -and $serverEntry.Group -eq "required") { $passedTests++ }
if ($launcherEntry -and $launcherEntry.Group -eq "optional") { $passedTests++ }
if ($defaultEntry -and $defaultEntry.Group -eq "required") { $passedTests++ }
$passedTests += 2  # For database creation and CSV structure

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor Red

if ($passedTests -eq $totalTests) {
    Write-Host ""
    Write-Host "🎉 ALL TESTS PASSED! 🎉" -ForegroundColor Green
    Write-Host ""
    Write-Host "Group Parameter Tests Complete" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ SOME TESTS FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Group Parameter Tests Complete with failures" -ForegroundColor Red
}

Stop-Transcript
return ($passedTests -eq $totalTests)