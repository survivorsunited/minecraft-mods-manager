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

.PARAMETER ModName
    The name of the mod to update (alternative to ModId).

.PARAMETER GameVersion
    The game version to filter by when using ModName.

.PARAMETER NewUrl
    The new URL to set for the mod.

.PARAMETER UrlType
    Which URL field to update (Url, VersionUrl, LatestVersionUrl).

.PARAMETER CsvPath
    Path to the CSV database file.

.PARAMETER BackupDatabase
    Whether to create a backup before modifying (default: true).

.EXAMPLE
    Update-ModUrlInDatabase -ModId "minecraft-server-1.21.7" -NewUrl "https://..." -CsvPath "modlist.csv"

.EXAMPLE
    Update-ModUrlInDatabase -ModName "Inventory Totem" -GameVersion "1.21.5" -NewUrl "https://..." -UrlType "VersionUrl"

.NOTES
    - Reads the CSV file
    - Updates the matching mod entry
    - Saves the updated data back to CSV
    - Creates backup before modifying
#>
function Update-ModUrlInDatabase {
    param(
        [Parameter(ParameterSetName="ById")]
        [string]$ModId,
        
        [Parameter(ParameterSetName="ByName")]
        [string]$ModName,
        
        [Parameter(ParameterSetName="ByName")]
        [string]$GameVersion,
        
        [Parameter(Mandatory)]
        [string]$NewUrl,
        
        [ValidateSet("Url", "VersionUrl", "CurrentVersionUrl", "NextVersionUrl", "LatestVersionUrl")]
        [string]$UrlType = "Url",
        
        [string]$CsvPath = "modlist.csv",
        
        [bool]$BackupDatabase = $true
    )
    
    try {
        $searchCriteria = if ($ModId) { "mod ID: $ModId" } else { "mod name: $ModName (MC $GameVersion)" }
        Write-Host "    🔍 Updating $UrlType for $searchCriteria" -ForegroundColor Gray
        
        # Check if file exists
        if (-not (Test-Path $CsvPath)) {
            throw "CSV file not found: $CsvPath"
        }
        
        # Create backup first in backups folder (if requested)
        if ($BackupDatabase) {
            $csvDir = Split-Path $CsvPath -Parent
            $csvName = Split-Path $CsvPath -Leaf
            $backupDir = Join-Path $csvDir "backups"
            
            # Create backups directory if it doesn't exist
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            
            $backupPath = Join-Path $backupDir "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$csvName"
            Copy-Item -Path $CsvPath -Destination $backupPath -Force
            Write-Host "    💾 Created backup: $backupPath" -ForegroundColor Gray
        }
        
        # Read CSV data
        $mods = Import-Csv -Path $CsvPath
        $updated = $false
        
        # Find and update the matching mod
        foreach ($mod in $mods) {
            $isMatch = $false
            
            if ($ModId -and $mod.ID -eq $ModId) {
                $isMatch = $true
            } elseif ($ModName -and $mod.Name -eq $ModName) {
                # Handle both migrated and non-migrated column structures
                $modGameVersion = if ($mod.PSObject.Properties.Name -contains "CurrentGameVersion") { 
                    $mod.CurrentGameVersion 
                } else { 
                    $mod.GameVersion 
                }
                if ($modGameVersion -eq $GameVersion) {
                    $isMatch = $true
                }
            }
            
            if ($isMatch) {
                # Get the current URL based on UrlType (handle both old and new column structures)
                $oldUrl = switch ($UrlType) {
                    "Url" { $mod.Url }
                    "VersionUrl" { 
                        if ($mod.PSObject.Properties.Name -contains "CurrentVersionUrl") { 
                            $mod.CurrentVersionUrl 
                        } else { 
                            $mod.VersionUrl 
                        }
                    }
                    "CurrentVersionUrl" { $mod.CurrentVersionUrl }
                    "NextVersionUrl" { $mod.NextVersionUrl }
                    "LatestVersionUrl" { $mod.LatestVersionUrl }
                }
                
                # Update the appropriate URL field (handle both old and new column structures)
                switch ($UrlType) {
                    "Url" { $mod.Url = $NewUrl }
                    "VersionUrl" { 
                        if ($mod.PSObject.Properties.Name -contains "CurrentVersionUrl") { 
                            $mod.CurrentVersionUrl = $NewUrl 
                        } else { 
                            $mod.VersionUrl = $NewUrl 
                        }
                    }
                    "CurrentVersionUrl" { $mod.CurrentVersionUrl = $NewUrl }
                    "NextVersionUrl" { $mod.NextVersionUrl = $NewUrl }
                    "LatestVersionUrl" { $mod.LatestVersionUrl = $NewUrl }
                }
                
                $updated = $true
                Write-Host "    ✏️  Updated ${UrlType}:" -ForegroundColor Gray
                Write-Host "      Old: $oldUrl" -ForegroundColor DarkGray
                Write-Host "      New: $NewUrl" -ForegroundColor Gray
                break
            }
        }
        
        if (-not $updated) {
            $notFoundMsg = if ($ModId) { "Mod ID '$ModId'" } else { "Mod '$ModName' (MC $GameVersion)" }
            Write-Host "    ⚠️  $notFoundMsg not found in database" -ForegroundColor Yellow
            return $false
        }
        
        # Save updated data back to CSV
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        Write-Host "    ✅ Database updated successfully" -ForegroundColor Green
        
        # Clean up old backups (keep only last 5) if we created a backup
        if ($BackupDatabase) {
            $backupFiles = Get-ChildItem -Path $backupDir -Filter "$csvName.*" |
                           Sort-Object LastWriteTime -Descending
            
            if ($backupFiles.Count -gt 5) {
                $filesToRemove = $backupFiles | Select-Object -Skip 5
                foreach ($file in $filesToRemove) {
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        return $true
        
    } catch {
        Write-Host "    ❌ Failed to update database: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function is available for dot-sourcing