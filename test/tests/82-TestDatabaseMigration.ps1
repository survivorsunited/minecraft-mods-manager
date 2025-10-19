# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "82-TestDatabaseMigration.ps1"

# Initialize test environment
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"

Write-Host "Minecraft Mod Manager - Database Migration Tests" -ForegroundColor $Colors.Header
Write-Host "================================================" -ForegroundColor $Colors.Header

function Invoke-TestDatabaseMigration {
    param([string]$TestFileName = $null)
    
    # Test 1: Create Old Format Database
    Write-TestHeader "Test 1: Create Old Format Database"
    
    $oldCsv = Join-Path $TestOutputDir "old-format.csv"
    $newCsv = Join-Path $TestOutputDir "migrated.csv"
    
    $oldCsvContent = @"
Group,Type,GameVersion,ID,Loader,Version,Name,Description,Jar,Url,Category,VersionUrl,LatestVersionUrl,LatestVersion,LatestGameVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
required,mod,1.21.5,fabric-api,fabric,0.127.1+1.21.5,Fabric API,Essential API for Fabric mods,,https://modrinth.com/mod/fabric-api,api,https://cdn.modrinth.com/data/P7dR8mSH/versions/old.jar,https://cdn.modrinth.com/data/P7dR8mSH/versions/latest.jar,0.128.0+1.21.8,1.21.8,modrinth,modrinth,,,,,,,,,,,,"1.21.5,1.21.6,1.21.7,1.21.8",,,
required,mod,1.21.5,sodium,fabric,mc1.21.5-0.6.13-fabric,Sodium,Modern rendering engine,,https://modrinth.com/mod/sodium,performance,https://cdn.modrinth.com/data/AANobbMI/versions/old.jar,https://cdn.modrinth.com/data/AANobbMI/versions/latest.jar,mc1.21.8-0.6.14-fabric,1.21.8,modrinth,modrinth,,,,,,,,,,,,"1.21.5,1.21.6,1.21.7,1.21.8",,,
"@
    
    Set-Content -Path $oldCsv -Value $oldCsvContent -Encoding UTF8
    $oldCsvCreated = Test-Path $oldCsv
    Write-TestResult "Old format database created" $oldCsvCreated
    
    # Test 2: Check Migration Script Exists
    Write-TestHeader "Test 2: Migration Script Existence"
    
    $migrationScript = Join-Path $PSScriptRoot "..\..\src\Database\Migration\Migrate-ToCurrentNextLatest.ps1"
    $migrationScriptExists = Test-Path $migrationScript
    Write-TestResult "Migration script exists" $migrationScriptExists
    
    if (-not $migrationScriptExists) {
        Write-Host "  Migration script not found at: $migrationScript" -ForegroundColor Red
        Show-TestSummary "Database Migration Tests"
        return ($script:TestResults.Failed -eq 0)
    }
    
    # Test 3: Execute Migration
    Write-TestHeader "Test 3: Execute Migration"
    
    # Copy old file to new location for migration
    Copy-Item -Path $oldCsv -Destination $newCsv
    
    $migrationSucceeded = $false
    try {
        . $migrationScript
        $migrationResult = Migrate-ToCurrentNextLatest -CsvPath $newCsv
        $migrationSucceeded = $migrationResult.Success -eq $true
    } catch {
        Write-Host "  Migration error: $($_.Exception.Message)" -ForegroundColor Red
        $migrationSucceeded = $false
    }
    
    Write-TestResult "Migration executed successfully" $migrationSucceeded
    
    if (-not $migrationSucceeded) {
        Show-TestSummary "Database Migration Tests"
        return ($script:TestResults.Failed -eq 0)
    }
    
    # Test 4: Verify New Columns Exist
    Write-TestHeader "Test 4: Verify New Columns Exist"
    
    $migratedMods = Import-Csv -Path $newCsv
    $expectedColumns = @("CurrentGameVersion", "CurrentVersion", "CurrentVersionUrl",
                        "NextVersion", "NextVersionUrl", "NextGameVersion",
                        "LatestVersion", "LatestVersionUrl", "LatestGameVersion")
    
    $missingNewColumns = @()
    foreach ($column in $expectedColumns) {
        if (-not ($migratedMods[0].PSObject.Properties.Name -contains $column)) {
            $missingNewColumns += $column
        }
    }
    
    $allNewColumnsPresent = $missingNewColumns.Count -eq 0
    Write-TestResult "All new columns present" $allNewColumnsPresent
    
    if (-not $allNewColumnsPresent) {
        Write-Host "  Missing columns: $($missingNewColumns -join ', ')" -ForegroundColor Red
    }
    
    # Test 5: Verify Data Transformation - CurrentVersion
    Write-TestHeader "Test 5: Data Transformation - CurrentVersion"
    
    $fabricMod = $migratedMods | Where-Object { $_.ID -eq "fabric-api" } | Select-Object -First 1
    $currentVersionCorrect = $fabricMod.CurrentVersion -eq "0.127.1+1.21.5"
    Write-TestResult "Version → CurrentVersion migration" $currentVersionCorrect
    
    if (-not $currentVersionCorrect) {
        Write-Host "  Expected: 0.127.1+1.21.5, Got: $($fabricMod.CurrentVersion)" -ForegroundColor Red
    }
    
    # Test 6: Verify Data Transformation - CurrentGameVersion
    Write-TestHeader "Test 6: Data Transformation - CurrentGameVersion"
    
    $currentGameVersionCorrect = $fabricMod.CurrentGameVersion -eq "1.21.5"
    Write-TestResult "GameVersion → CurrentGameVersion migration" $currentGameVersionCorrect
    
    if (-not $currentGameVersionCorrect) {
        Write-Host "  Expected: 1.21.5, Got: $($fabricMod.CurrentGameVersion)" -ForegroundColor Red
    }
    
    # Test 7: Verify Data Transformation - CurrentVersionUrl
    Write-TestHeader "Test 7: Data Transformation - CurrentVersionUrl"
    
    $currentVersionUrlCorrect = $fabricMod.CurrentVersionUrl -eq "https://cdn.modrinth.com/data/P7dR8mSH/versions/old.jar"
    Write-TestResult "VersionUrl → CurrentVersionUrl migration" $currentVersionUrlCorrect
    
    if (-not $currentVersionUrlCorrect) {
        Write-Host "  Expected: https://cdn.modrinth.com/data/P7dR8mSH/versions/old.jar" -ForegroundColor Red
        Write-Host "  Got: $($fabricMod.CurrentVersionUrl)" -ForegroundColor Red
    }
    
    # Test 8: Verify NextGameVersion Population
    Write-TestHeader "Test 8: NextGameVersion Population"
    
    $nextGameVersionPopulated = -not [string]::IsNullOrEmpty($fabricMod.NextGameVersion)
    Write-TestResult "NextGameVersion populated" $nextGameVersionPopulated
    
    if ($nextGameVersionPopulated) {
        Write-Host "  NextGameVersion: $($fabricMod.NextGameVersion)" -ForegroundColor Gray
    }
    
    # Test 9: Database Import Compatibility
    Write-TestHeader "Test 9: Database Import Compatibility"
    
    $canImport = $false
    try {
        $mods = Import-Csv -Path $newCsv
        $canImport = $mods.Count -eq 2
    } catch {
        Write-Host "  Import error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-TestResult "Migrated database can be imported" $canImport
    
    # Test 10: Property Access Test
    Write-TestHeader "Test 10: Property Access Test"
    
    $testMod = $migratedMods[0]
    $testProperties = @("CurrentVersion", "CurrentGameVersion", "CurrentVersionUrl", "NextVersion", "LatestVersion")
    $accessibleProperties = 0
    
    foreach ($prop in $testProperties) {
        try {
            $value = $testMod.$prop
            $accessibleProperties++
        } catch {
            Write-Host "  Cannot access property: $prop" -ForegroundColor Red
        }
    }
    
    $allPropertiesAccessible = $accessibleProperties -eq $testProperties.Count
    Write-TestResult "All new properties accessible" $allPropertiesAccessible
    
    if (-not $allPropertiesAccessible) {
        Write-Host "  Accessible: $accessibleProperties/$($testProperties.Count)" -ForegroundColor Red
    }
    
    # Summary
    Show-TestSummary "Database Migration Tests"
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestDatabaseMigration -TestFileName $TestFileName
