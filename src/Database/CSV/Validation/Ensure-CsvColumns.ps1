# =============================================================================
# CSV Column Validation Module
# =============================================================================
# This module handles ensuring CSV files have all required columns.
# =============================================================================

<#
.SYNOPSIS
    Ensures CSV has required columns.

.DESCRIPTION
    Checks if a CSV file has all required columns and adds missing ones
    with default values. Creates backup before making changes.

.PARAMETER CsvPath
    The path to the CSV file to validate.

.EXAMPLE
    Ensure-CsvColumns -CsvPath "modlist.csv"

.NOTES
    - Creates backup before making changes
    - Adds missing columns with default values
    - Returns updated mods array or null if failed
#>
function Ensure-CsvColumns {
    param(
        [string]$CsvPath
    )
    try {
        $mods = Import-Csv -Path $CsvPath
        if ($mods -isnot [System.Collections.IEnumerable]) { $mods = @($mods) }
        $headers = $mods[0].PSObject.Properties.Name
        
        $needsUpdate = $false
        
        # Check if GameVersion column exists
        if ($headers -notcontains "GameVersion") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "GameVersion" -Value "1.21.5"
            }
            $needsUpdate = $true
        }
        
        # Check if Type column exists
        if ($headers -notcontains "Type") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "Type" -Value "mod"
            }
            $needsUpdate = $true
        }
        
        # Check if LatestVersion column exists
        if ($headers -notcontains "LatestVersion") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "LatestVersion" -Value ""
            }
            $needsUpdate = $true
        }
        
        # Check if VersionUrl column exists
        if ($headers -notcontains "VersionUrl") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "VersionUrl" -Value ""
            }
            $needsUpdate = $true
        }
        
        # Check if LatestVersionUrl column exists
        if ($headers -notcontains "LatestVersionUrl") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "LatestVersionUrl" -Value ""
            }
            $needsUpdate = $true
        }
        
        # Check if IconUrl column exists
        if ($headers -notcontains "IconUrl") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "IconUrl" -Value ""
            }
            $needsUpdate = $true
        }
        
        # Add new columns for Modrinth project info if missing
        $newColumns = @("ClientSide", "ServerSide", "Title", "ProjectDescription", "IssuesUrl", "SourceUrl", "WikiUrl")
        foreach ($col in $newColumns) {
            if ($headers -notcontains $col) {
                foreach ($mod in $mods) {
                    $mod | Add-Member -MemberType NoteProperty -Name $col -Value ""
                }
                $needsUpdate = $true
            }
        }
        
        # Check if Host column exists
        if ($headers -notcontains "Host") {
            foreach ($mod in $mods) {
                # Default to Modrinth, but set CurseForge for known CurseForge mods
                $modHost = "modrinth"
                if ($mod.ID -eq "357540" -or $mod.ID -eq "invhud_configurable") {
                    $modHost = "curseforge"
                }
                $mod | Add-Member -MemberType NoteProperty -Name "Host" -Value $modHost
            }
            $needsUpdate = $true
        }
        
        # Check if LatestGameVersion column exists
        if ($headers -notcontains "LatestGameVersion") {
            foreach ($mod in $mods) {
                $mod | Add-Member -MemberType NoteProperty -Name "LatestGameVersion" -Value ""
            }
            $needsUpdate = $true
        }
        
        # Check if dependency columns exist
        $dependencyColumns = @("CurrentDependencies", "LatestDependencies", "LatestDependenciesRequired", "LatestDependenciesOptional")
        foreach ($col in $dependencyColumns) {
            if ($headers -notcontains $col) {
                foreach ($mod in $mods) {
                    $mod | Add-Member -MemberType NoteProperty -Name $col -Value ""
                }
                $needsUpdate = $true
            }
        }
        
        if ($needsUpdate) {
            # Create backup before updating
            $backupPath = Get-BackupPath -OriginalPath $CsvPath -BackupType "columns"
            Copy-Item -Path $CsvPath -Destination $backupPath
            Write-Host "Created backup: $backupPath" -ForegroundColor Yellow
            
            # Save updated CSV
            $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        }
        
        return $mods
    }
    catch {
        Write-Error "Failed to ensure CSV columns: $($_.Exception.Message)"
        return $null
    }
}

# Function is available for dot-sourcing 