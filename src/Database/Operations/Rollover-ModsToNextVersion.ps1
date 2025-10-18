# =============================================================================
# Rollover Mods to Next Version Module
# =============================================================================
# This module handles rolling over mods from Current to Next versions.
# =============================================================================

<#
.SYNOPSIS
    Rolls over mods to their next version or a specified version.

.DESCRIPTION
    Updates mods in the database by rolling over Current* fields to Next* values,
    or by updating all mods to a specified game version.

.PARAMETER CsvPath
    Path to the modlist CSV file.

.PARAMETER RolloverToVersion
    Optional: Specific game version to rollover to (e.g., "1.21.9").
    If not specified, uses NextVersion data from the database.

.PARAMETER DryRun
    Show what would be changed without actually updating the database.

.EXAMPLE
    Rollover-ModsToNextVersion -CsvPath "modlist.csv"
    Rolls over all mods with NextVersion data to their next version.

.EXAMPLE
    Rollover-ModsToNextVersion -CsvPath "modlist.csv" -RolloverToVersion "1.21.9"
    Updates all mods to version 1.21.9.

.NOTES
    - Creates backup before making changes
    - Validates that Next* data exists before rollover
    - Clears Next* fields after rollover (will be repopulated on next UpdateMods)
#>
function Rollover-ModsToNextVersion {
    param(
        [string]$CsvPath = "modlist.csv",
        [string]$RolloverToVersion = "",
        [switch]$DryRun = $false
    )
    
    try {
        # Load mods
        $mods = Import-Csv -Path $CsvPath
        if (-not $mods) {
            Write-Host "❌ No mods found in database" -ForegroundColor Red
            return $false
        }
        
        Write-Host "🔄 Rollover Mods to Next Version" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        Write-Host ""
        
        if ($RolloverToVersion) {
            Write-Host "🎯 Target Version: $RolloverToVersion (specified)" -ForegroundColor Yellow
            Write-Host "📝 Mode: Update all mods to specified version" -ForegroundColor Gray
        } else {
            Write-Host "📝 Mode: Rollover to NextVersion data" -ForegroundColor Gray
        }
        
        if ($DryRun) {
            Write-Host "🔍 DRY RUN MODE: No changes will be saved" -ForegroundColor Magenta
        }
        Write-Host ""
        
        # Create backup before making changes
        if (-not $DryRun) {
            $backupPath = Get-BackupPath -CsvPath $CsvPath -Prefix "pre-rollover"
            Copy-Item -Path $CsvPath -Destination $backupPath -Force
            Write-Host "💾 Backup created: $backupPath" -ForegroundColor Green
            Write-Host ""
        }
        
        $rolledOverCount = 0
        $skippedCount = 0
        $errorCount = 0
        
        foreach ($mod in $mods) {
            # Skip system entries
            if ($mod.Type -in @("installer", "launcher", "server", "jdk")) {
                continue
            }
            
            if ($RolloverToVersion) {
                # Mode 1: Rollover to specified version
                if ($mod.CurrentGameVersion -ne $RolloverToVersion) {
                    $oldVersion = $mod.CurrentGameVersion
                    
                    if ($DryRun) {
                        Write-Host "  Would update $($mod.Name): $oldVersion → $RolloverToVersion" -ForegroundColor Yellow
                    } else {
                        $mod.CurrentGameVersion = $RolloverToVersion
                        Write-Host "✓ Updated $($mod.Name): $oldVersion → $RolloverToVersion" -ForegroundColor Green
                    }
                    
                    $rolledOverCount++
                }
            } else {
                # Mode 2: Rollover using NextVersion data
                if ($mod.NextVersion -and $mod.NextVersion -ne "") {
                    $oldVersion = $mod.CurrentVersion
                    $oldGameVersion = $mod.CurrentGameVersion
                    
                    if ($DryRun) {
                        Write-Host "  Would rollover $($mod.Name):" -ForegroundColor Yellow
                        Write-Host "    Version: $oldVersion → $($mod.NextVersion)" -ForegroundColor Gray
                        Write-Host "    GameVersion: $oldGameVersion → $($mod.NextGameVersion)" -ForegroundColor Gray
                    } else {
                        # Rollover Current* to Next* values
                        $mod.CurrentVersion = $mod.NextVersion
                        $mod.CurrentVersionUrl = $mod.NextVersionUrl
                        $mod.CurrentGameVersion = $mod.NextGameVersion
                        
                        # Clear Next* fields (will be repopulated on next UpdateMods)
                        $mod.NextVersion = ""
                        $mod.NextVersionUrl = ""
                        $mod.NextGameVersion = ""
                        
                        Write-Host "✓ Rolled over $($mod.Name):" -ForegroundColor Green
                        Write-Host "  Version: $oldVersion → $($mod.CurrentVersion)" -ForegroundColor Cyan
                        Write-Host "  GameVersion: $oldGameVersion → $($mod.CurrentGameVersion)" -ForegroundColor Cyan
                    }
                    
                    $rolledOverCount++
                } else {
                    $skippedCount++
                }
            }
        }
        
        # Save changes
        if (-not $DryRun -and $rolledOverCount -gt 0) {
            $mods | Export-Csv -Path $CsvPath -NoTypeInformation
            Write-Host ""
            Write-Host "💾 Database updated successfully" -ForegroundColor Green
        }
        
        # Summary
        Write-Host ""
        Write-Host "📊 Rollover Summary:" -ForegroundColor Cyan
        Write-Host "  Rolled over: $rolledOverCount mods" -ForegroundColor Green
        Write-Host "  Skipped: $skippedCount mods" -ForegroundColor Yellow
        Write-Host "  Errors: $errorCount mods" -ForegroundColor Red
        
        if ($RolloverToVersion -and -not $DryRun) {
            Write-Host ""
            Write-Host "⚠️  Note: Run -UpdateMods to populate version data for $RolloverToVersion" -ForegroundColor Yellow
        }
        
        return $true
        
    } catch {
        Write-Host "❌ Error during rollover: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function is available for dot-sourcing

