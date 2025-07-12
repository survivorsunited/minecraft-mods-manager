# =============================================================================
# Backup Path Generation Module
# =============================================================================
# This module handles generating backup file paths.
# =============================================================================

<#
.SYNOPSIS
    Gets backup path in backups folder.

.DESCRIPTION
    Generates a unique backup path for a file in the backups folder
    with timestamp and backup type.

.PARAMETER OriginalPath
    The original file path.

.PARAMETER BackupType
    The type of backup (default: "backup").

.EXAMPLE
    Get-BackupPath -OriginalPath "modlist.csv" -BackupType "update"

.NOTES
    - Creates backups folder if it doesn't exist
    - Generates timestamped backup filename
    - Returns full path in backups folder
#>
function Get-BackupPath {
    param(
        [string]$OriginalPath,
        [string]$BackupType = "backup"
    )
    
    # Create backups folder if it doesn't exist
    if (-not (Test-Path $BackupFolder)) {
        New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null
        Write-Host "Created backups folder: $BackupFolder" -ForegroundColor Green
    }
    
    # Get original filename without path
    $originalFileName = [System.IO.Path]::GetFileName($OriginalPath)
    $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($originalFileName)
    $extension = [System.IO.Path]::GetExtension($originalFileName)
    
    # Create timestamp for unique backup names
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    
    # Create backup filename
    $backupFileName = "${fileNameWithoutExt}-${BackupType}-${timestamp}${extension}"
    
    # Return full path in backups folder
    return Join-Path $BackupFolder $backupFileName
}

# Function is available for dot-sourcing 