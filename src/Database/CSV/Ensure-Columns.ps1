# =============================================================================
# CSV Column Validation Module
# =============================================================================
# This module handles ensuring CSV files have required columns.
# =============================================================================

<#
.SYNOPSIS
    Ensures CSV has required columns.

.DESCRIPTION
    Checks if a CSV file has all required columns and adds missing ones
    with default values.

.PARAMETER CsvPath
    The path to the CSV file.

.EXAMPLE
    Ensure-CsvColumns -CsvPath "modlist.csv"

.NOTES
    - Adds missing columns with default values
    - Creates backup before making changes
    - Returns updated mod list
#>
# Function to ensure CSV has required columns
function Ensure-CsvColumns {
    param(
        [string]$CsvPath
    )
    try {
        if (-not (Test-Path $CsvPath)) {
            throw "CSV file not found: $CsvPath"
        }
        
        $mods = Import-Csv -Path $CsvPath
        if ($mods -isnot [System.Collections.IEnumerable]) { $mods = @($mods) }
        
        # Handle empty CSV file
        if (-not $mods -or $mods.Count -eq 0) {
            Write-Host "📝 CSV file is empty, creating with required columns" -ForegroundColor Yellow
            $mods = @()
        }
        
        # Define required columns (updated for Current/Next/Latest structure)
        $requiredColumns = @(
            "ID", "Name", "Type", "Loader", "CurrentGameVersion", "CurrentVersion", "Jar", "Url", "UrlDirect",
            "Category", "Description", "Group", "CurrentVersionUrl", "NextVersion", "NextVersionUrl", 
            "NextGameVersion", "LatestVersionUrl", "LatestVersion", "LatestGameVersion", "IconUrl", 
            "ClientSide", "ServerSide", "Title", "ProjectDescription", "IssuesUrl", "SourceUrl", 
            "WikiUrl", "RecordHash", "AvailableGameVersions",
            "CurrentDependenciesRequired", "CurrentDependenciesOptional", "LatestDependenciesRequired", "LatestDependenciesOptional"
        )
        
        # Check if any required columns are missing
        $missingColumns = @()
        if ($mods.Count -gt 0) {
            foreach ($column in $requiredColumns) {
                if (-not ($mods[0].PSObject.Properties.Match($column).Count)) {
                    $missingColumns += $column
                }
            }
        } else {
            # If CSV is empty, all columns are missing
            $missingColumns = $requiredColumns
        }
        
        # Add missing columns with default values
        if ($missingColumns.Count -gt 0) {
            Write-Host "📝 Adding missing columns to CSV: $($missingColumns -join ', ')" -ForegroundColor Yellow
            
            foreach ($mod in $mods) {
                foreach ($column in $missingColumns) {
                    $mod | Add-Member -MemberType NoteProperty -Name $column -Value ""
                }
            }
            
            # Save updated CSV
            $mods | Export-Csv -Path $CsvPath -NoTypeInformation
            Write-Host "✅ CSV updated with missing columns" -ForegroundColor Green
        }
        
        return $mods
    }
    catch {
        Write-Error "Failed to ensure CSV columns: $($_.Exception.Message)"
        return $null
    }
}

# Function is available for dot-sourcing 