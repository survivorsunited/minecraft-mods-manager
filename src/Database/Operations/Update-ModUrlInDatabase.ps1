# =============================================================================
# Update Mod URL in Database Function
# =============================================================================
# This function updates a mod's URL in the database after dynamic resolution
# =============================================================================

<#
.SYNOPSIS
    Updates a mod's URL in the database.

.DESCRIPTION
    Updates the URL field for a specific mod entry in the CSV database
    after dynamic URL resolution.

.PARAMETER ModId
    The ID of the mod to update.

.PARAMETER NewUrl
    The new URL to set for the mod.

.PARAMETER CsvPath
    Path to the CSV database file.

.EXAMPLE
    Update-ModUrlInDatabase -ModId "minecraft-server-1.21.7" -NewUrl "https://..." -CsvPath "modlist.csv"

.NOTES
    - Reads the CSV file
    - Updates the matching mod entry
    - Saves the updated data back to CSV
    - Creates backup before modifying
#>
function Update-ModUrlInDatabase {
    param(
        [Parameter(Mandatory)]
        [string]$ModId,
        
        [Parameter(Mandatory)]
        [string]$NewUrl,
        
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        Write-Host "    🔍 Updating URL for mod ID: $ModId" -ForegroundColor Gray
        
        # Check if file exists
        if (-not (Test-Path $CsvPath)) {
            throw "CSV file not found: $CsvPath"
        }
        
        # Create backup first
        $backupPath = "$CsvPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -Path $CsvPath -Destination $backupPath -Force
        Write-Host "    💾 Created backup: $backupPath" -ForegroundColor Gray
        
        # Read CSV data
        $mods = Import-Csv -Path $CsvPath
        $updated = $false
        
        # Find and update the matching mod
        foreach ($mod in $mods) {
            if ($mod.ID -eq $ModId) {
                $oldUrl = $mod.Url
                $mod.Url = $NewUrl
                $updated = $true
                Write-Host "    ✏️  Updated URL:" -ForegroundColor Gray
                Write-Host "      Old: $oldUrl" -ForegroundColor DarkGray
                Write-Host "      New: $NewUrl" -ForegroundColor Gray
                break
            }
        }
        
        if (-not $updated) {
            Write-Host "    ⚠️  Mod ID '$ModId' not found in database" -ForegroundColor Yellow
            return $false
        }
        
        # Save updated data back to CSV
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        Write-Host "    ✅ Database updated successfully" -ForegroundColor Green
        
        # Clean up old backups (keep only last 5)
        $backupFiles = Get-ChildItem -Path "$(Split-Path $CsvPath)" -Filter "$(Split-Path $CsvPath -Leaf).backup.*" |
                       Sort-Object LastWriteTime -Descending
        
        if ($backupFiles.Count -gt 5) {
            $filesToRemove = $backupFiles | Select-Object -Skip 5
            foreach ($file in $filesToRemove) {
                Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        
        return $true
        
    } catch {
        Write-Host "    ❌ Failed to update database: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function is available for dot-sourcing