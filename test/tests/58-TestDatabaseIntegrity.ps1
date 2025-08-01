#!/usr/bin/env pwsh

<#
.SYNOPSIS
Test database integrity after ModManager operations to ensure no data loss

.DESCRIPTION
This test ensures that ModManager operations (UpdateMods, Download, etc.) 
do not corrupt or remove data from the database. It validates that all
columns and rows are preserved after operations.
#>

# Set up test environment
$ErrorActionPreference = "Stop"
$testDir = Split-Path -Parent $PSScriptRoot
$rootDir = Split-Path -Parent $testDir
$originalDir = Get-Location

try {
    Set-Location $testDir
    
    # Import test framework
    . "$testDir\TestFramework.ps1"
    
    # Import modules
    . "$rootDir\src\Import-Modules.ps1"
    
    Write-Host "=== Test 58: Database Integrity Test ===" -ForegroundColor Cyan
    
    # Create test database copy
    $originalDb = "$rootDir\modlist.csv"
    $testDb = "$testDir\test-modlist-integrity.csv"
    $backupDb = "$testDir\test-modlist-integrity-backup.csv"
    
    if (-not (Test-Path $originalDb)) {
        throw "Original database not found: $originalDb"
    }
    
    # Copy original database
    Copy-Item $originalDb $testDb -Force
    Copy-Item $originalDb $backupDb -Force
    
    Write-Host "Created test database copies" -ForegroundColor Yellow
    
    # Read original data
    $originalData = Import-Csv $testDb
    $originalRowCount = $originalData.Count
    $originalColumns = ($originalData | Get-Member -MemberType NoteProperty).Name
    
    Write-Host "Original database: $originalRowCount rows, $($originalColumns.Count) columns" -ForegroundColor Gray
    
    # Test 1: UpdateMods operation
    Write-Host "Testing UpdateMods operation..." -ForegroundColor Yellow
    
    try {
        # Run UpdateMods with test database (use absolute path)
        & "$rootDir\ModManager.ps1" -UpdateMods -ModListFile $testDb -ApiResponseFolder "$testDir\api-responses"
        
        # Check data integrity after UpdateMods
        if (-not (Test-Path $testDb)) {
            throw "Database file was deleted by UpdateMods operation!"
        }
        
        $afterUpdateData = Import-Csv $testDb
        $afterUpdateRowCount = $afterUpdateData.Count
        $afterUpdateColumns = ($afterUpdateData | Get-Member -MemberType NoteProperty).Name
        
        Write-Host "After UpdateMods: $afterUpdateRowCount rows, $($afterUpdateColumns.Count) columns" -ForegroundColor Gray
        
        # Validate row count
        if ($afterUpdateRowCount -ne $originalRowCount) {
            throw "Row count changed! Original: $originalRowCount, After: $afterUpdateRowCount"
        }
        
        # Validate column count
        if ($afterUpdateColumns.Count -ne $originalColumns.Count) {
            throw "Column count changed! Original: $($originalColumns.Count), After: $($afterUpdateColumns.Count)"
        }
        
        # Validate all columns exist
        foreach ($col in $originalColumns) {
            if ($col -notin $afterUpdateColumns) {
                throw "Column '$col' was removed!"
            }
        }
        
        # Validate critical data is preserved (ID, Name, Group, Type should never change)
        for ($i = 0; $i -lt $originalData.Count; $i++) {
            $orig = $originalData[$i]
            $after = $afterUpdateData[$i]
            
            if ($orig.ID -ne $after.ID) {
                throw "Row ${i}: ID changed from '$($orig.ID)' to '$($after.ID)'"
            }
            if ($orig.Name -ne $after.Name) {
                throw "Row ${i}: Name changed from '$($orig.Name)' to '$($after.Name)'"
            }
            if ($orig.Group -ne $after.Group) {
                throw "Row ${i}: Group changed from '$($orig.Group)' to '$($after.Group)'"
            }
            if ($orig.Type -ne $after.Type) {
                throw "Row ${i}: Type changed from '$($orig.Type)' to '$($after.Type)'"
            }
        }
        
        Write-Host "✅ UpdateMods operation preserved data integrity" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ UpdateMods operation failed integrity check: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    
    # Test 2: Download operation with UseLatestVersion
    Write-Host "Testing Download with UseLatestVersion..." -ForegroundColor Yellow
    
    # Restore from backup
    Copy-Item $backupDb $testDb -Force
    
    try {
        # Run Download with UseLatestVersion (use absolute path)
        & "$rootDir\ModManager.ps1" -Download -UseLatestVersion -ModListFile $testDb -DownloadFolder "$testDir\downloads" -ApiResponseFolder "$testDir\api-responses"
        
        # Check data integrity after Download
        if (-not (Test-Path $testDb)) {
            throw "Database file was deleted by Download operation!"
        }
        
        $afterDownloadData = Import-Csv $testDb
        $afterDownloadRowCount = $afterDownloadData.Count
        $afterDownloadColumns = ($afterDownloadData | Get-Member -MemberType NoteProperty).Name
        
        Write-Host "After Download: $afterDownloadRowCount rows, $($afterDownloadColumns.Count) columns" -ForegroundColor Gray
        
        # Validate row count
        if ($afterDownloadRowCount -ne $originalRowCount) {
            throw "Row count changed! Original: $originalRowCount, After: $afterDownloadRowCount"
        }
        
        # Validate column count
        if ($afterDownloadColumns.Count -ne $originalColumns.Count) {
            throw "Column count changed! Original: $($originalColumns.Count), After: $($afterDownloadColumns.Count)"
        }
        
        Write-Host "✅ Download operation preserved data integrity" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Download operation failed integrity check: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    
    # Test 3: Check for empty fields that shouldn't be empty
    Write-Host "Checking for unexpected empty fields..." -ForegroundColor Yellow
    
    $criticalFields = @('ID', 'Name', 'Group', 'Type', 'GameVersion', 'Loader', 'ApiSource', 'Host')
    $emptyFieldIssues = @()
    
    for ($i = 0; $i -lt $afterDownloadData.Count; $i++) {
        $row = $afterDownloadData[$i]
        foreach ($field in $criticalFields) {
            if ([string]::IsNullOrWhiteSpace($row.$field)) {
                $emptyFieldIssues += "Row $($i+1): Critical field '$field' is empty"
            }
        }
    }
    
    if ($emptyFieldIssues.Count -gt 0) {
        Write-Host "❌ Found empty critical fields:" -ForegroundColor Red
        foreach ($issue in $emptyFieldIssues) {
            Write-Host "  $issue" -ForegroundColor Red
        }
        throw "Critical fields are empty - data corruption detected"
    }
    
    Write-Host "✅ No critical fields are empty" -ForegroundColor Green
    
    # Clean up test files
    Remove-Item $testDb -Force -ErrorAction SilentlyContinue
    Remove-Item $backupDb -Force -ErrorAction SilentlyContinue
    Remove-Item "$testDir\downloads" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$testDir\api-responses" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "=== Test 58: Database Integrity - PASSED ===" -ForegroundColor Green
    
} catch {
    Write-Host "=== Test 58: Database Integrity - FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    # Clean up test files on failure
    Remove-Item $testDb -Force -ErrorAction SilentlyContinue
    Remove-Item $backupDb -Force -ErrorAction SilentlyContinue
    Remove-Item "$testDir\downloads" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$testDir\api-responses" -Recurse -Force -ErrorAction SilentlyContinue
    
    exit 1
} finally {
    Set-Location $originalDir
}