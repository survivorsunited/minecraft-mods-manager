# =============================================================================
# Database Migration: Current/Next/Latest Column Structure
# =============================================================================
# Migrates existing database from Version/LatestVersion to Current/Next/Latest
# =============================================================================

<#
.SYNOPSIS
    Migrates database to Current/Next/Latest column structure.

.DESCRIPTION
    Restructures modlist.csv to implement the Current → Next → Latest 
    progression workflow, replacing the existing Version → LatestVersion jump.
    
    Column Changes:
    - Version → CurrentVersion
    - VersionUrl → CurrentVersionUrl  
    - GameVersion → CurrentGameVersion
    - Add: NextVersion, NextVersionUrl, NextGameVersion
    - Keep: LatestVersion, LatestVersionUrl, LatestGameVersion (unchanged)

.PARAMETER CsvPath
    Path to the database CSV file to migrate.

.PARAMETER BackupPath
    Custom backup path. If not specified, uses backups/ directory.

.PARAMETER DryRun
    If specified, shows what would be changed without making modifications.

.EXAMPLE
    Migrate-ToCurrentNextLatest -CsvPath "modlist.csv" -DryRun
    
.EXAMPLE
    Migrate-ToCurrentNextLatest -CsvPath "modlist.csv"

.NOTES
    - Creates automatic backup before migration
    - Preserves all existing data
    - Adds empty Next* columns (populated later by update functions)
    - Safe to run multiple times (idempotent)
#>
function Migrate-ToCurrentNextLatest {
    param(
        [string]$CsvPath = "modlist.csv",
        [string]$BackupPath,
        [switch]$DryRun
    )
    
    try {
        Write-Host "🔄 Database Migration: Current/Next/Latest Structure" -ForegroundColor Cyan
        Write-Host "======================================================" -ForegroundColor Cyan
        Write-Host "Database: $CsvPath" -ForegroundColor Gray
        Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'MIGRATION MODE' })" -ForegroundColor Gray
        Write-Host ""
        
        # Check if file exists
        if (-not (Test-Path $CsvPath)) {
            throw "Database file not found: $CsvPath"
        }
        
        # Load current data
        Write-Host "📊 Loading database..." -ForegroundColor Yellow
        $data = Import-Csv -Path $CsvPath
        $totalRecords = $data.Count
        Write-Host "   Loaded $totalRecords records" -ForegroundColor Green
        
        # Check current column structure
        $currentColumns = ($data | Get-Member -MemberType NoteProperty).Name
        Write-Host "   Found $($currentColumns.Count) columns" -ForegroundColor Green
        
        # Check if migration is needed
        $hasOldStructure = $currentColumns -contains "Version" -and $currentColumns -contains "GameVersion"
        $hasNewStructure = $currentColumns -contains "CurrentVersion" -and $currentColumns -contains "NextVersion"
        
        if ($hasNewStructure) {
            Write-Host "✅ Database already has Current/Next/Latest structure!" -ForegroundColor Green
            Write-Host "   No migration needed." -ForegroundColor Green
            return $true
        }
        
        if (-not $hasOldStructure) {
            Write-Host "❌ Unexpected database structure!" -ForegroundColor Red
            Write-Host "   Expected columns 'Version' and 'GameVersion' not found." -ForegroundColor Red
            return $false
        }
        
        # Define column mappings
        $columnMappings = @{
            "Version" = "CurrentVersion"
            "VersionUrl" = "CurrentVersionUrl"
            "GameVersion" = "CurrentGameVersion"
        }
        
        $newColumns = @("NextVersion", "NextVersionUrl", "NextGameVersion")
        
        Write-Host "🔍 Migration Plan:" -ForegroundColor Yellow
        Write-Host "   Column Renames:" -ForegroundColor Gray
        foreach ($mapping in $columnMappings.GetEnumerator()) {
            Write-Host "     $($mapping.Key) → $($mapping.Value)" -ForegroundColor Cyan
        }
        Write-Host "   New Columns:" -ForegroundColor Gray
        foreach ($col in $newColumns) {
            Write-Host "     + $col" -ForegroundColor Green
        }
        
        if ($DryRun) {
            Write-Host ""
            Write-Host "🔍 DRY RUN: Migration plan complete. Use without -DryRun to execute." -ForegroundColor Yellow
            return $true
        }
        
        # Create backup
        if (-not $BackupPath) {
            $backupDir = "backups"
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $BackupPath = Join-Path $backupDir "$timestamp-pre-migration-$(Split-Path $CsvPath -Leaf)"
        }
        
        Write-Host ""
        Write-Host "💾 Creating backup..." -ForegroundColor Yellow
        Copy-Item -Path $CsvPath -Destination $BackupPath -Force
        Write-Host "   Backup created: $BackupPath" -ForegroundColor Green
        
        # Perform migration
        Write-Host ""
        Write-Host "🔨 Performing migration..." -ForegroundColor Yellow
        
        # Create new data structure
        $migratedData = @()
        
        foreach ($record in $data) {
            # Create new record with renamed columns
            $newRecord = [PSCustomObject]@{}
            
            # Copy all existing columns, renaming as needed
            foreach ($column in $currentColumns) {
                $newColumnName = if ($columnMappings.ContainsKey($column)) {
                    $columnMappings[$column]
                } else {
                    $column
                }
                
                $newRecord | Add-Member -MemberType NoteProperty -Name $newColumnName -Value $record.$column
            }
            
            # Add new Next* columns (empty for now)
            foreach ($newCol in $newColumns) {
                $newRecord | Add-Member -MemberType NoteProperty -Name $newCol -Value ""
            }
            
            $migratedData += $newRecord
        }
        
        # Verify migration
        $newColumnCount = ($migratedData[0] | Get-Member -MemberType NoteProperty).Name.Count
        $expectedNewColumns = $currentColumns.Count + $newColumns.Count
        
        if ($newColumnCount -ne $expectedNewColumns) {
            throw "Migration verification failed: Expected $expectedNewColumns columns, got $newColumnCount"
        }
        
        # Save migrated data
        Write-Host "   Saving migrated data..." -ForegroundColor Gray
        $migratedData | Export-Csv -Path $CsvPath -NoTypeInformation
        
        # Verify saved data
        $verifyData = Import-Csv -Path $CsvPath
        if ($verifyData.Count -ne $totalRecords) {
            throw "Data verification failed: Expected $totalRecords records, got $($verifyData.Count)"
        }
        
        Write-Host ""
        Write-Host "✅ MIGRATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
        Write-Host "================================================" -ForegroundColor Green
        Write-Host "Records migrated: $totalRecords" -ForegroundColor Green
        Write-Host "Columns before: $($currentColumns.Count)" -ForegroundColor Green
        Write-Host "Columns after: $newColumnCount" -ForegroundColor Green
        Write-Host "Backup location: $BackupPath" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
        Write-Host "1. Run validation to populate Next* columns:" -ForegroundColor Yellow
        Write-Host "   Update-WithLatestVersions.ps1" -ForegroundColor Gray
        Write-Host "2. Test the new workflow flags:" -ForegroundColor Yellow  
        Write-Host "   ModManager.ps1 -UseNextVersion" -ForegroundColor Gray
        Write-Host "3. Update any custom scripts using old column names" -ForegroundColor Yellow
        
        return $true
        
    } catch {
        Write-Host ""
        Write-Host "❌ Migration failed: $($_.Exception.Message)" -ForegroundColor Red
        
        # Attempt rollback if backup exists
        if ((Test-Path $BackupPath) -and -not $DryRun) {
            Write-Host ""
            Write-Host "🔄 Attempting automatic rollback..." -ForegroundColor Yellow
            try {
                Copy-Item -Path $BackupPath -Destination $CsvPath -Force
                Write-Host "✅ Rollback successful. Database restored from backup." -ForegroundColor Green
            } catch {
                Write-Host "❌ Rollback failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "   Please manually restore from: $BackupPath" -ForegroundColor Yellow
            }
        }
        
        return $false
    }
}

# Function is available for dot-sourcing