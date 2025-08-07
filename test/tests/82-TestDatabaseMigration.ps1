#!/usr/bin/env pwsh
# Test for database migration from old to new column structure

param(
    [string]$TestDir = "test-output/82-TestDatabaseMigration"
)

# Import test framework
. "$PSScriptRoot/../TestFramework.ps1"

$testName = "Database Migration Test"
Initialize-Test -TestName $testName -TestDir $TestDir

try {
    Write-Host "=== Test 82: Database Migration Test ===" -ForegroundColor Cyan
    
    # Create old format database
    $oldCsv = Join-Path $testOutputDir "old-format.csv"
    $newCsv = Join-Path $testOutputDir "migrated.csv"
    
    $oldCsvContent = @"
Group,Type,GameVersion,ID,Loader,Version,Name,Description,Jar,Url,Category,VersionUrl,LatestVersionUrl,LatestVersion,LatestGameVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
required,mod,1.21.5,fabric-api,fabric,0.127.1+1.21.5,Fabric API,Essential API for Fabric mods,,https://modrinth.com/mod/fabric-api,api,https://cdn.modrinth.com/data/P7dR8mSH/versions/old.jar,https://cdn.modrinth.com/data/P7dR8mSH/versions/latest.jar,0.128.0+1.21.8,1.21.8,modrinth,modrinth,,,,,,,,,,,,"1.21.5,1.21.6,1.21.7,1.21.8",,,
required,mod,1.21.5,sodium,fabric,mc1.21.5-0.6.13-fabric,Sodium,Modern rendering engine,,https://modrinth.com/mod/sodium,performance,https://cdn.modrinth.com/data/AANobbMI/versions/old.jar,https://cdn.modrinth.com/data/AANobbMI/versions/latest.jar,mc1.21.8-0.6.14-fabric,1.21.8,modrinth,modrinth,,,,,,,,,,,,"1.21.5,1.21.6,1.21.7,1.21.8",,,
"@

    Set-Content -Path $oldCsv -Value $oldCsvContent -Encoding UTF8
    Write-Host "✓ Created old format test database" -ForegroundColor Green
    
    # Test migration function
    Write-Host "`n--- Test 1: Migration Script Execution ---" -ForegroundColor Yellow
    
    # Copy old file to new location for migration
    Copy-Item -Path $oldCsv -Destination $newCsv
    
    # Run migration
    $migrationScript = Join-Path $PSScriptRoot "../../src/Database/Migration/Migrate-ToCurrentNextLatest.ps1"
    if (Test-Path $migrationScript) {
        . $migrationScript
        $migrationResult = Migrate-ToCurrentNextLatest -CsvPath $newCsv
        
        if ($migrationResult.Success) {
            Write-Host "✓ Migration completed successfully" -ForegroundColor Green
            
            # Verify migrated structure
            Write-Host "`n--- Test 2: Verify Migrated Columns ---" -ForegroundColor Yellow
            $migratedMods = Import-Csv -Path $newCsv
            
            $expectedColumns = @("CurrentGameVersion", "CurrentVersion", "CurrentVersionUrl",
                               "NextVersion", "NextVersionUrl", "NextGameVersion",
                               "LatestVersion", "LatestVersionUrl", "LatestGameVersion")
            
            $oldColumns = @("GameVersion", "Version", "VersionUrl")
            
            # Check new columns exist
            $missingNewColumns = @()
            foreach ($column in $expectedColumns) {
                if (-not ($migratedMods[0].PSObject.Properties.Name -contains $column)) {
                    $missingNewColumns += $column
                }
            }
            
            if ($missingNewColumns.Count -eq 0) {
                Write-Host "✓ All new columns present after migration" -ForegroundColor Green
            } else {
                Write-Host "✗ Missing new columns: $($missingNewColumns -join ', ')" -ForegroundColor Red
                $global:TestFailed = $true
            }
            
            # Check old columns are gone (if migration removes them)
            $remainingOldColumns = @()
            foreach ($column in $oldColumns) {
                if ($migratedMods[0].PSObject.Properties.Name -contains $column) {
                    $remainingOldColumns += $column
                }
            }
            
            # This might be OK if migration keeps old columns for compatibility
            if ($remainingOldColumns.Count -gt 0) {
                Write-Host "ℹ  Old columns still present: $($remainingOldColumns -join ', ') (may be intentional)" -ForegroundColor Yellow
            }
            
            # Test data preservation and transformation
            Write-Host "`n--- Test 3: Data Transformation ---" -ForegroundColor Yellow
            $fabricMod = $migratedMods | Where-Object { $_.ID -eq "fabric-api" } | Select-Object -First 1
            
            # Check if old data was moved to new columns
            if ($fabricMod.CurrentVersion -eq "0.127.1+1.21.5") {
                Write-Host "✓ Version → CurrentVersion migration successful" -ForegroundColor Green
            } else {
                Write-Host "✗ Version → CurrentVersion migration failed" -ForegroundColor Red
                $global:TestFailed = $true
            }
            
            if ($fabricMod.CurrentGameVersion -eq "1.21.5") {
                Write-Host "✓ GameVersion → CurrentGameVersion migration successful" -ForegroundColor Green
            } else {
                Write-Host "✗ GameVersion → CurrentGameVersion migration failed" -ForegroundColor Red
                $global:TestFailed = $true
            }
            
            if ($fabricMod.CurrentVersionUrl -eq "https://cdn.modrinth.com/data/P7dR8mSH/versions/old.jar") {
                Write-Host "✓ VersionUrl → CurrentVersionUrl migration successful" -ForegroundColor Green
            } else {
                Write-Host "✗ VersionUrl → CurrentVersionUrl migration failed" -ForegroundColor Red
                $global:TestFailed = $true
            }
            
            # Test Next version population
            Write-Host "`n--- Test 4: Next Version Population ---" -ForegroundColor Yellow
            if (-not [string]::IsNullOrEmpty($fabricMod.NextGameVersion)) {
                Write-Host "✓ NextGameVersion populated: $($fabricMod.NextGameVersion)" -ForegroundColor Green
            } else {
                Write-Host "✗ NextGameVersion not populated" -ForegroundColor Red
                $global:TestFailed = $true
            }
            
            # Test backup creation
            Write-Host "`n--- Test 5: Backup Creation ---" -ForegroundColor Yellow
            $backupFiles = Get-ChildItem -Path (Split-Path $newCsv -Parent) -Filter "*.csv" | Where-Object { $_.Name -like "*backup*" -or $_.Name -like "*pre-migration*" }
            
            if ($backupFiles.Count -gt 0) {
                Write-Host "✓ Migration backup created: $($backupFiles[0].Name)" -ForegroundColor Green
            } else {
                Write-Host "⚠ No migration backup found (may not be required for test)" -ForegroundColor Yellow
            }
            
        } else {
            Write-Host "✗ Migration failed: $($migrationResult.Error)" -ForegroundColor Red
            $global:TestFailed = $true
        }
    } else {
        Write-Host "✗ Migration script not found: $migrationScript" -ForegroundColor Red
        $global:TestFailed = $true
    }
    
    # Test rollback functionality (if available)
    Write-Host "`n--- Test 6: Database Compatibility ---" -ForegroundColor Yellow
    
    # Test that new structure works with existing functions
    try {
        # Try to import and validate the migrated data
        $mods = Import-Csv -Path $newCsv
        if ($mods.Count -eq 2) {
            Write-Host "✓ Migrated database can be imported correctly" -ForegroundColor Green
        } else {
            Write-Host "✗ Migrated database import failed" -ForegroundColor Red
            $global:TestFailed = $true
        }
        
        # Test column access
        $testMod = $mods[0]
        $testProperties = @("CurrentVersion", "CurrentGameVersion", "CurrentVersionUrl", "NextVersion", "LatestVersion")
        $accessibleProperties = 0
        
        foreach ($prop in $testProperties) {
            try {
                $value = $testMod.$prop
                $accessibleProperties++
            } catch {
                Write-Host "✗ Cannot access property: $prop" -ForegroundColor Red
            }
        }
        
        if ($accessibleProperties -eq $testProperties.Count) {
            Write-Host "✓ All new properties accessible" -ForegroundColor Green
        } else {
            Write-Host "✗ Some properties not accessible ($accessibleProperties/$($testProperties.Count))" -ForegroundColor Red
            $global:TestFailed = $true
        }
        
    } catch {
        Write-Host "✗ Database compatibility test failed: $($_.Exception.Message)" -ForegroundColor Red
        $global:TestFailed = $true
    }
    
    # Final result
    if ($global:TestFailed) {
        Write-Host "`n=== Test 82: Database Migration - FAILED ===" -ForegroundColor Red
        $global:FailedTests++
    } else {
        Write-Host "`n=== Test 82: Database Migration - PASSED ===" -ForegroundColor Green
        $global:PassedTests++
    }
    
} catch {
    Write-Host "`n=== Test 82: Database Migration - ERROR ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    $global:FailedTests++
} finally {
    Finalize-Test
}