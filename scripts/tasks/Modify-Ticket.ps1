#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Modify a GitHub ticket content with proper backup and workflow.

.DESCRIPTION
    Reads a GitHub ticket, allows modification of content through a temporary file,
    creates backups, and updates the ticket with the modified content.
    This script provides a safe workflow for modifying ticket content.

.PARAMETER IssueNumber
    The GitHub issue number to modify.

.PARAMETER Editor
    The editor to use for modifying content. Defaults to "notepad" on Windows.

.PARAMETER BackupDir
    The directory to store backup files. Defaults to .tasks/

.PARAMETER OperationDetails
    Description of what this modification operation is doing.

.EXAMPLE
    .\Modify-Ticket.ps1 -IssueNumber 54 -OperationDetails "Adding new acceptance criteria"

.EXAMPLE
    .\Modify-Ticket.ps1 -IssueNumber 21 -Editor "code" -OperationDetails "Updating requirements"
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$IssueNumber,
    
    [Parameter(Mandatory = $false)]
    [string]$Editor = "notepad",
    
    [Parameter(Mandatory = $false)]
    [string]$BackupDir = ".tasks",
    
    [Parameter(Mandatory = $true)]
    [string]$OperationDetails
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to create timestamp
function Get-ISOTimestamp {
    return Get-Date -Format "yyyy-MM-dd_HHmmss"
}

# Function to create backup directory if it doesn't exist
function Initialize-BackupDirectory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-ColorOutput "Created backup directory: $Path" "Green"
    }
}

# Function to create backup file
function New-TicketBackup {
    param(
        [int]$IssueNumber,
        [string]$Operation,
        [string]$Content,
        [string]$BackupDir,
        [string]$OperationDetails
    )
    
    $timestamp = Get-ISOTimestamp
    $backupFileName = "issue-$IssueNumber-$timestamp-$Operation.md"
    $backupPath = Join-Path $BackupDir $backupFileName
    
    $backupContent = @"
---
operation: $Operation
timestamp: $timestamp
issue_number: $IssueNumber
operation_details: "$OperationDetails"
---

$Content
"@
    
    try {
        $backupContent | Out-File -FilePath $backupPath -Encoding UTF8
        Write-ColorOutput "✓ Backup created: $backupPath" "Green"
        return $backupPath
    }
    catch {
        Write-ColorOutput "✗ Failed to create backup: $($_.Exception.Message)" "Red"
        throw
    }
}

# Function to validate gh CLI
function Test-GitHubCLI {
    try {
        $null = gh --version
        return $true
    }
    catch {
        Write-ColorOutput "✗ GitHub CLI (gh) not found. Please install it first." "Red"
        Write-ColorOutput "Install from: https://cli.github.com/" "Yellow"
        return $false
    }
}

# Function to read current ticket content
function Read-GitHubTicket {
    param([int]$IssueNumber)
    
    try {
        Write-ColorOutput "Reading current content of issue #$IssueNumber..." "Cyan"
        
        # Use JSON output to get clean content
        $jsonOutput = gh issue view $IssueNumber --json body,title,number,state,labels 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to read issue #$IssueNumber. Exit code: $LASTEXITCODE"
        }
        
        # Parse JSON and extract body content
        $issueData = $jsonOutput | ConvertFrom-Json
        $bodyContent = $issueData.body
        
        # If body is null or empty, return empty string
        if (-not $bodyContent) {
            $bodyContent = ""
        }
        
        return $bodyContent
    }
    catch {
        Write-ColorOutput "✗ Error reading ticket: $($_.Exception.Message)" "Red"
        throw
    }
}

# Function to create temporary file for editing
function New-TempEditFile {
    param([string]$Content)
    
    $tempFile = [System.IO.Path]::GetTempFileName() + ".md"
    $Content | Out-File -FilePath $tempFile -Encoding UTF8
    return $tempFile
}

# Function to update ticket using Update-Ticket.ps1
function Update-TicketWithFile {
    param(
        [int]$IssueNumber,
        [string]$BodyFile,
        [string]$OperationDetails
    )
    
    $updateScript = Join-Path $PSScriptRoot "Update-Ticket.ps1"
    $result = & $updateScript -IssueNumber $IssueNumber -BodyFile $BodyFile -OperationDetails $OperationDetails
    
    return $result
}

# Main execution
try {
    Write-ColorOutput "=== GitHub Ticket Modifier ===" "Magenta"
    Write-ColorOutput "Modifying ticket #$IssueNumber" "White"
    Write-ColorOutput "Operation: $OperationDetails" "White"
    Write-ColorOutput "Editor: $Editor" "White"
    
    # Validate GitHub CLI
    if (-not (Test-GitHubCLI)) {
        exit 1
    }
    
    # Initialize backup directory
    Initialize-BackupDirectory -Path $BackupDir
    
    # Read current ticket content and create backup
    $currentContent = Read-GitHubTicket -IssueNumber $IssueNumber
    $readBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "read" -Content $currentContent -BackupDir $BackupDir -OperationDetails "Reading current content before modification"
    
    # Create temporary file for editing
    $tempFile = New-TempEditFile -Content $currentContent
    Write-ColorOutput "✓ Created temporary file for editing: $tempFile" "Green"
    
    # Open file in editor
    Write-ColorOutput "`nOpening file in $Editor for editing..." "Cyan"
    Write-ColorOutput "Make your changes and save the file, then close the editor." "Yellow"
    Write-ColorOutput "The ticket will be updated with your changes." "Yellow"
    
    # Start editor
    Start-Process -FilePath $Editor -ArgumentList $tempFile -Wait
    
    # Check if file was modified
    $modifiedContent = Get-Content -Path $tempFile -Raw
    if ($modifiedContent -eq $currentContent) {
        Write-ColorOutput "`n⚠ No changes detected. Ticket was not modified." "Yellow"
        Remove-Item $tempFile -Force
        return @{
            IssueNumber = $IssueNumber
            Success = $true
            Message = "No changes made"
            ReadBackupPath = $readBackupPath
        }
    }
    
    # Update the ticket with modified content
    Write-ColorOutput "`nUpdating ticket with modified content..." "Cyan"
    $updateResult = Update-TicketWithFile -IssueNumber $IssueNumber -BodyFile $tempFile -OperationDetails $OperationDetails
    
    # Clean up temporary file
    Remove-Item $tempFile -Force
    Write-ColorOutput "✓ Cleaned up temporary file" "Green"
    
    Write-ColorOutput "`n=== Summary ===" "Magenta"
    Write-ColorOutput "✓ Ticket #$IssueNumber modified successfully" "Green"
    Write-ColorOutput "✓ Read backup created: $readBackupPath" "Green"
    Write-ColorOutput "✓ Modification completed successfully" "Green"
    
    return @{
        IssueNumber = $IssueNumber
        Success = $true
        ReadBackupPath = $readBackupPath
        UpdateResult = $updateResult
    }
}
catch {
    Write-ColorOutput "`n=== Error Summary ===" "Red"
    Write-ColorOutput "✗ Failed to modify ticket #$IssueNumber" "Red"
    Write-ColorOutput "Error: $($_.Exception.Message)" "Red"
    
    # Clean up temporary file on error
    if ($tempFile -and (Test-Path $tempFile)) {
        Remove-Item $tempFile -Force
        Write-ColorOutput "Cleaned up temporary file on error" "Yellow"
    }
    
    return @{
        IssueNumber = $IssueNumber
        Success = $false
        Error = $_.Exception.Message
    }
} 