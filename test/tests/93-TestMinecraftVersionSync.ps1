# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "93-TestMinecraftVersionSync.ps1"

# Initialize test environment (creates isolated directory and starts logging)
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"

Write-Host "Minecraft Mod Manager - Version Sync Tests" -ForegroundColor $Colors.Header
Write-Host "===========================================" -ForegroundColor $Colors.Header
Write-Host ""

function Invoke-VersionSyncTests {
    param([string]$TestFileName = $null)
    
    Write-TestSuiteHeader "Minecraft & Fabric Version Sync Tests" $TestFileName
    
    # Test 1: Create minimal test database
    Write-TestHeader "Creating minimal test database"
    $minimalCsv = @"
"Group","Type","CurrentGameVersion","ID","Loader","CurrentVersion","Name","Description","Category","Jar","NextVersion","NextVersionUrl","NextGameVersion","LatestVersion","LatestVersionUrl","LatestGameVersion","Url","CurrentVersionUrl","UrlDirect","CurrentDependencies","CurrentDependenciesRequired","CurrentDependenciesOptional","LatestDependencies","LatestDependenciesRequired","LatestDependenciesOptional","Host","ApiSource","ClientSide","ServerSide","Title","ProjectDescription","IconUrl","IssuesUrl","SourceUrl","WikiUrl","AvailableGameVersions","RecordHash"
"required","mod","1.21.5","fabric-api","fabric","0.127.1+1.21.5","Fabric API","Essential hooks for modding with Fabric","library","","","","","","","","https://modrinth.com/mod/fabric-api","","","","","","","","","modrinth","modrinth","required","required","Fabric API","Essential hooks for modding with Fabric","","","","","",""
"@
    $minimalCsv | Out-File -FilePath $TestModListPath -Encoding UTF8
    
    if (Test-Path $TestModListPath) {
        Write-TestResult "Minimal test database created" $true
    } else {
        Write-TestResult "Minimal test database created" $false
        return $false
    }
    
    # Test 2: Test MC Versions API integration
    Write-TestHeader "Testing MC Versions API integration"
    $mcVersionsResult = & pwsh -NoProfile -ExecutionPolicy Bypass -Command {
        param($ScriptRoot)
        . "$ScriptRoot\..\..\src\Import-Modules.ps1"
        $versions = Get-MinecraftVersions -MinVersion "1.21.5" -Channel "stable"
        if ($versions -and $versions.Count -gt 0) {
            Write-Output "SUCCESS: Found $($versions.Count) versions"
            $versions | Select-Object -First 5 | ForEach-Object { Write-Output "  $_" }
            exit 0
        } else {
            Write-Output "FAILED: No versions found"
            exit 1
        }
    } -Args $PSScriptRoot 2>&1
    
    Write-Host $mcVersionsResult -ForegroundColor Gray
    Write-TestResult "MC Versions API returns stable versions >= 1.21.5" ($LASTEXITCODE -eq 0)
    
    # Test 3: Test Fabric Meta API integration
    Write-TestHeader "Testing Fabric Meta API integration"
    $fabricVersionsResult = & pwsh -NoProfile -ExecutionPolicy Bypass -Command {
        param($ScriptRoot)
        . "$ScriptRoot\..\..\src\Import-Modules.ps1"
        $fabricLoader = Get-FabricVersions -GameVersion "1.21.5" -StableOnly
        if ($fabricLoader -and $fabricLoader.loader.version) {
            Write-Output "SUCCESS: Found Fabric loader $($fabricLoader.loader.version)"
            exit 0
        } else {
            Write-Output "FAILED: No Fabric loader found"
            exit 1
        }
    } -Args $PSScriptRoot 2>&1
    
    Write-Host $fabricVersionsResult -ForegroundColor Gray
    Write-TestResult "Fabric Meta API returns loader for 1.21.5" ($LASTEXITCODE -eq 0)
    
    # Test 4: Test Sync with DryRun (no database changes)
    Write-TestHeader "Testing version sync with DryRun"
    $dryRunResult = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -SyncMinecraftVersions `
        -MinecraftMinVersion "1.21.5" `
        -DatabaseFile $TestModListPath `
        -DryRun 2>&1
    
    $dryRunSuccess = $dryRunResult -match "DRY RUN" -or $dryRunResult -match "All versions already in database"
    Write-Host ($dryRunResult | Out-String) -ForegroundColor Gray
    Write-TestResult "Sync with DryRun executes without errors" $dryRunSuccess
    
    # Test 5: Count entries before sync
    Write-TestHeader "Counting database entries before sync"
    $beforeCount = (Import-Csv $TestModListPath).Count
    Write-Host "  Before sync: $beforeCount entries" -ForegroundColor Cyan
    Write-TestResult "Database loaded successfully" ($beforeCount -gt 0)
    
    # Test 6: Test actual sync (add new versions)
    Write-TestHeader "Testing actual version sync to add all versions >= 1.21.5"
    $syncResult = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -SyncMinecraftVersions `
        -MinecraftMinVersion "1.21.5" `
        -DatabaseFile $TestModListPath 2>&1
    
    Write-Host ($syncResult | Out-String) -ForegroundColor Gray
    
    # Test 7: Count entries after sync
    Write-TestHeader "Counting database entries after sync"
    $afterCount = (Import-Csv $TestModListPath).Count
    Write-Host "  After sync: $afterCount entries" -ForegroundColor Cyan
    $entriesAdded = $afterCount -gt $beforeCount
    Write-TestResult "New entries added to database" $entriesAdded
    
    # Test 8: Verify ALL available server entries were added (1.21.5, 1.21.6, 1.21.7, 1.21.8)
    Write-TestHeader "Verifying ALL server entries for versions >= 1.21.5"
    $entries = Import-Csv $TestModListPath
    $serverEntries = $entries | Where-Object { $_.Type -eq "server" }
    $expectedVersions = @("1.21.5", "1.21.6", "1.21.7", "1.21.8")
    $hasAllServers = $true
    
    foreach ($version in $expectedVersions) {
        $hasVersion = $serverEntries | Where-Object { $_.CurrentGameVersion -eq $version }
        if ($hasVersion) {
            Write-Host "  ✓ Found server for $version" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Missing server for $version" -ForegroundColor Red
            $hasAllServers = $false
        }
    }
    Write-TestResult "All server versions (1.21.5-1.21.8) exist in database" $hasAllServers
    
    # Test 9: Verify ALL launcher entries were added
    Write-TestHeader "Verifying ALL Fabric launcher entries for versions >= 1.21.5"
    $launcherEntries = $entries | Where-Object { $_.Type -eq "launcher" }
    $hasAllLaunchers = $true
    
    foreach ($version in $expectedVersions) {
        $hasLauncher = $launcherEntries | Where-Object { $_.CurrentGameVersion -eq $version }
        if ($hasLauncher) {
            $loaderVer = ($hasLauncher | Select-Object -First 1).CurrentVersion
            Write-Host "  ✓ Found launcher for $version (loader: $loaderVer)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Missing launcher for $version" -ForegroundColor Red
            $hasAllLaunchers = $false
        }
    }
    Write-TestResult "All launcher versions (1.21.5-1.21.8) exist in database" $hasAllLaunchers
    
    # Test 10: Verify no duplicates on second sync
    Write-TestHeader "Testing duplicate prevention"
    $resyncResult = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -SyncMinecraftVersions `
        -MinecraftMinVersion "1.21.5" `
        -DatabaseFile $TestModListPath 2>&1
    
    $afterResyncCount = (Import-Csv $TestModListPath).Count
    $noDuplicates = $afterResyncCount -eq $afterCount
    
    Write-Host "  After re-sync: $afterResyncCount entries" -ForegroundColor Cyan
    Write-Host ($resyncResult | Select-String -Pattern "(already in database|no sync needed)" | Out-String) -ForegroundColor Gray
    Write-TestResult "No duplicates created on re-sync" $noDuplicates
    
    # Test 11: Verify Fabric loader versions are real (not "latest")
    Write-TestHeader "Verifying Fabric loader versions are specific"
    $realLoaderVersions = $launcherEntries | Where-Object { 
        $_.CurrentVersion -ne "latest" -and $_.CurrentVersion -match '^\d+\.\d+\.\d+$' 
    }
    $hasRealVersions = $realLoaderVersions.Count -eq $launcherEntries.Count
    
    if ($hasRealVersions) {
        Write-Host "  All Fabric loader versions are specific:" -ForegroundColor Green
        $launcherEntries | ForEach-Object {
            Write-Host "    • $($_.CurrentGameVersion): loader $($_.CurrentVersion)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Some launchers have 'latest' instead of specific versions" -ForegroundColor Red
    }
    Write-TestResult "All Fabric loader versions are specific (not 'latest')" $hasRealVersions
    
    # Test 12: Verify main database has all versions
    Write-TestHeader "Verifying MAIN database has all versions"
    $mainDbPath = Join-Path $PSScriptRoot "..\..\modlist.csv"
    $mainEntries = Import-Csv $mainDbPath
    $mainServers = $mainEntries | Where-Object { $_.Type -eq "server" }
    $mainLaunchers = $mainEntries | Where-Object { $_.Type -eq "launcher" }
    
    $mainHasAll = $true
    foreach ($version in $expectedVersions) {
        $hasServer = $mainServers | Where-Object { $_.CurrentGameVersion -eq $version }
        $hasLauncher = $mainLaunchers | Where-Object { $_.CurrentGameVersion -eq $version }
        
        if ($hasServer -and $hasLauncher) {
            Write-Host "  ✓ Main DB has server & launcher for $version" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Main DB missing entries for $version" -ForegroundColor Yellow
            $mainHasAll = $false
        }
    }
    Write-TestResult "Main database has all versions (1.21.5-1.21.8)" $mainHasAll
    
    # Show final summary
    Write-Host ""
    Show-TestSummary
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-VersionSyncTests -TestFileName $TestFileName

