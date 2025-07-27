#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Read a GitHub ticket and create a backup with proper error handling.

.DESCRIPTION
    Reads a GitHub ticket using gh CLI, creates a backup file in .tasks/ folder,
    and handles errors gracefully. This script ensures all ticket read operations
    are properly backed up as required by the project rules.

.PARAMETER IssueNumber
    The GitHub issue number to read.

.PARAMETER BackupDir
    The directory to store backup files. Defaults to .tasks/

.EXAMPLE
    .\Read-Ticket.ps1 -IssueNumber 54

.EXAMPLE
    .\Read-Ticket.ps1 -IssueNumber 21 -BackupDir "backups"
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$IssueNumber,
    
    [Parameter(Mandatory = $false)]
    [string]$BackupDir = ".tasks"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to create timestamp
function Get-ISOTimestamp {
    return Get-Date -Format "yyyy-MM-dd_HHmmss"
}

# Function to create backup directory if it doesn't exist
function Initialize-BackupDirectory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
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
        return $backupPath
    }
    catch {
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
        return $false
    }
}

# Function to read ticket content
function Read-GitHubTicket {
    param([int]$IssueNumber)
    
    try {
        # Get the full issue content in JSON format, then extract the body
        $jsonOutput = gh issue view $IssueNumber --json title,body,number,state,labels 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to read issue #$IssueNumber. Exit code: $LASTEXITCODE"
        }
        
        # Parse JSON and extract the body content
        $issueData = $jsonOutput | ConvertFrom-Json
        return $issueData.body
    }
    catch {
        throw
    }
}

# Main execution
try {
    # Validate GitHub CLI
    if (-not (Test-GitHubCLI)) {
        return @{ Success = $false; IssueNumber = $IssueNumber; Content = $null; BackupPath = $null; Error = 'GitHub CLI not found'; }
    }
    
    # Initialize backup directory
    Initialize-BackupDirectory -Path $BackupDir
    
    # Read ticket content
    $ticketContent = Read-GitHubTicket -IssueNumber $IssueNumber
    
    # Create read backup
    $readBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "read" -Content $ticketContent -BackupDir $BackupDir -OperationDetails "Reading ticket content for review"
    
    # Create update backup (same content, ready for modification)
    $updateBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "update" -Content $ticketContent -BackupDir $BackupDir -OperationDetails "Ready for modification"
    
    # Return the content for potential further processing
    return @{
        IssueNumber = $IssueNumber
        Content = $ticketContent
        ReadBackupPath = $readBackupPath
        UpdateBackupPath = $updateBackupPath
        Success = $true
        Error = $null
    }
}
catch {
    return @{
        IssueNumber = $IssueNumber
        Content = $null
        BackupPath = $null
        Success = $false
        Error = $_.Exception.Message
    }
} 