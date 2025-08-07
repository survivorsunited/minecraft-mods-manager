# =============================================================================
# Reorder CSV Columns Function
# =============================================================================
# This function reorders CSV columns in a logical, readable order
# =============================================================================

<#
.SYNOPSIS
    Reorders CSV columns in a logical order for better readability.

.DESCRIPTION
    Reorganizes CSV columns to put the most important identifying columns first,
    followed by version information, then URLs, and finally metadata.

.PARAMETER CsvPath
    Path to the CSV file to reorder.

.PARAMETER BackupOriginal
    Whether to create a backup of the original file.

.EXAMPLE
    Reorder-CsvColumns -CsvPath "modlist.csv"
#>
function Reorder-CsvColumns {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        
        [bool]$BackupOriginal = $true
    )
    
    Write-Host "🔄 Reordering CSV columns for better readability..." -ForegroundColor Cyan
    
    # Check if file exists
    if (-not (Test-Path $CsvPath)) {
        Write-Host "❌ CSV file not found: $CsvPath" -ForegroundColor Red
        return $false
    }
    
    # Create backup if requested
    if ($BackupOriginal) {
        $backupPath = "$CsvPath.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
        Copy-Item -Path $CsvPath -Destination $backupPath -Force
        Write-Host "💾 Created backup: $backupPath" -ForegroundColor Green
    }
    
    # Read CSV data
    $data = Import-Csv -Path $CsvPath
    if ($data.Count -eq 0) {
        Write-Host "⚠️  CSV file is empty" -ForegroundColor Yellow
        return $false
    }
    
    # Get all current columns
    $allColumns = $data[0].PSObject.Properties.Name
    Write-Host "📊 Found $($allColumns.Count) columns" -ForegroundColor Gray
    
    # Define logical column order
    # Primary identification columns first
    $orderedColumns = @(
        "Group",
        "Type", 
        "CurrentGameVersion",  # Using Current* for migrated databases
        "ID",
        "Loader",
        "CurrentVersion",      # Using Current* for migrated databases
        "Name"
    )
    
    # Then other version-related columns
    $orderedColumns += @(
        "Description",
        "Category",
        "Jar",
        "NextVersion",
        "NextVersionUrl", 
        "NextGameVersion",
        "LatestVersion",
        "LatestVersionUrl",
        "LatestGameVersion"
    )
    
    # URL columns
    $orderedColumns += @(
        "Url",
        "CurrentVersionUrl",   # Using Current* for migrated databases
        "UrlDirect"
    )
    
    # Dependencies
    $orderedColumns += @(
        "CurrentDependencies",
        "CurrentDependenciesRequired",
        "CurrentDependenciesOptional",
        "LatestDependencies", 
        "LatestDependenciesRequired",
        "LatestDependenciesOptional"
    )
    
    # API/Source information
    $orderedColumns += @(
        "Host",
        "ApiSource"
    )
    
    # Metadata
    $orderedColumns += @(
        "ClientSide",
        "ServerSide",
        "Title",
        "ProjectDescription",
        "IconUrl",
        "IssuesUrl", 
        "SourceUrl",
        "WikiUrl",
        "AvailableGameVersions",
        "RecordHash"
    )
    
    # Handle any columns not in our ordered list (including old column names)
    $remainingColumns = $allColumns | Where-Object { $_ -notin $orderedColumns }
    
    # Special handling for non-migrated databases
    if ($remainingColumns -contains "GameVersion") {
        # Non-migrated database - adjust order
        $orderedColumns = $orderedColumns -replace "CurrentGameVersion", "GameVersion"
        $orderedColumns = $orderedColumns -replace "CurrentVersion", "Version" 
        $orderedColumns = $orderedColumns -replace "CurrentVersionUrl", "VersionUrl"
        $orderedColumns = $orderedColumns -replace "CurrentDependencies", "Dependencies"
        $orderedColumns = $orderedColumns -replace "CurrentDependenciesRequired", "DependenciesRequired"
        $orderedColumns = $orderedColumns -replace "CurrentDependenciesOptional", "DependenciesOptional"
    }
    
    # Add remaining columns at the end
    if ($remainingColumns.Count -gt 0) {
        Write-Host "📝 Found additional columns: $($remainingColumns -join ', ')" -ForegroundColor Yellow
        $orderedColumns += $remainingColumns
    }
    
    # Filter to only columns that actually exist
    $finalColumns = $orderedColumns | Where-Object { $_ -in $allColumns }
    
    # Reorder the data
    $reorderedData = @()
    foreach ($row in $data) {
        $newRow = [PSCustomObject]@{}
        foreach ($col in $finalColumns) {
            $newRow | Add-Member -NotePropertyName $col -NotePropertyValue $row.$col
        }
        $reorderedData += $newRow
    }
    
    # Export reordered data
    $reorderedData | Export-Csv -Path $CsvPath -NoTypeInformation
    
    Write-Host "✅ Successfully reordered $($finalColumns.Count) columns" -ForegroundColor Green
    Write-Host "📋 New column order (first 10):" -ForegroundColor Cyan
    $finalColumns | Select-Object -First 10 | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
    if ($finalColumns.Count -gt 10) {
        Write-Host "   ... and $($finalColumns.Count - 10) more columns" -ForegroundColor DarkGray
    }
    
    return $true
}

# Function is available for dot-sourcing