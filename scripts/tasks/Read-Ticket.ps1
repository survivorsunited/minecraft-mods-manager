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
        $backupContent | Out-File -FilePath $backupPath #-Encoding UTF8
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
        # Use temporary file to avoid PowerShell pipeline Unicode corruption
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        # Write GitHub CLI output directly to temp file with UTF-8 encoding
        $process = Start-Process -FilePath "gh" -ArgumentList "issue", "view", $IssueNumber, "--json", "title,body,number,state,labels" -RedirectStandardOutput $tempFile -RedirectStandardError "$tempFile.err" -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            Remove-Item "$tempFile.err" -ErrorAction SilentlyContinue
            throw "Failed to read issue #$IssueNumber. Exit code: $($process.ExitCode)"
        }
        
        # Read from temp file and apply Unicode encoding fix
        $rawContent = Get-Content $tempFile -Raw -Encoding UTF8
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        
        # Apply the Unicode encoding fix you showed me - convert from Default to UTF8
        $jsonCorrected = [Text.Encoding]::UTF8.GetString([Text.Encoding]::Default.GetBytes($rawContent))
        
        # Validate JSON output
        if ([string]::IsNullOrWhiteSpace($jsonCorrected)) {
            throw "Empty response from GitHub CLI for issue #$IssueNumber"
        }
        
        # Parse JSON and extract the body content
        $issueData = $jsonCorrected | ConvertFrom-Json -ErrorAction Stop
        if (-not $issueData.body) {
            throw "No body content found in issue #$IssueNumber"
        }
        
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
        Write-Error 'GitHub CLI not found'
        return
    }
    
    # Initialize backup directory
    Initialize-BackupDirectory -Path $BackupDir
    
    # Read ticket content
    $ticketContent = Read-GitHubTicket -IssueNumber $IssueNumber

    $ticketContent | Out-File -FilePath ".tasks\issue-56-2025-07-27_215924-update.txt" -Encoding UTF8
    
    # Create read backup
    $readBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "read" -Content $ticketContent -BackupDir $BackupDir -OperationDetails "Reading ticket content for review"
    
    # Create update backup (same content, ready for modification)
    $updateBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "update" -Content $ticketContent -BackupDir $BackupDir -OperationDetails "Ready for modification"
    
    # Output only the update backup path
    Write-Output $updateBackupPath
}
catch {
    Write-Error $_.Exception.Message
} 