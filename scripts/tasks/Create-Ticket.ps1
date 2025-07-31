#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create a new GitHub ticket with proper backup and error handling.

.DESCRIPTION
    Creates a new GitHub ticket using gh CLI, creates a backup file in .tasks/ folder,
    and handles errors gracefully. This script ensures all ticket creation operations
    are properly backed up and follow the project rules.

.PARAMETER Title
    The title of the GitHub issue to create.

.PARAMETER Body
    The body content of the GitHub issue.

.PARAMETER BodyFile
    Path to a file containing the body content of the GitHub issue.

.PARAMETER Labels
    Comma-separated list of labels to apply to the issue.

.PARAMETER BackupDir
    The directory to store backup files. Defaults to .tasks/

.PARAMETER OperationDetails
    Description of the creation operation for backup metadata.

.EXAMPLE
    .\Create-Ticket.ps1 -Title "Fix logging issues" -Body "Analysis shows multiple issues..." -Labels "bug,high-priority" -OperationDetails "Creating ticket for analysis findings"

.EXAMPLE
    .\Create-Ticket.ps1 -Title "Feature request" -BodyFile "feature-description.md" -Labels "enhancement" -OperationDetails "Creating feature request"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Title,
    
    [Parameter(Mandatory = $false)]
    [string]$Body = "",
    
    [Parameter(Mandatory = $false)]
    [string]$BodyFile = "",
    
    [Parameter(Mandatory = $false)]
    [string]$Labels = "",
    
    [Parameter(Mandatory = $false)]
    [string]$BackupDir = ".tasks",
    
    [Parameter(Mandatory = $true)]
    [string]$OperationDetails
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

# Function to validate GitHub CLI availability
function Test-GitHubCLI {
    try {
        $ghVersion = gh --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub CLI returned non-zero exit code"
        }
        return $true
    } catch {
        return $false
    }
}

# Function to create backup file for new ticket
function New-TicketCreationBackup {
    param(
        [string]$BackupPath,
        [string]$Title,
        [string]$Body,
        [string]$Labels,
        [string]$Timestamp,
        [string]$OperationDetails
    )
    
    $backupContent = @"
---
operation: create
timestamp: $Timestamp
issue_title: $Title
labels: $Labels
operation_details: $OperationDetails
---

# $Title

$Body
"@
    
    $backupContent | Out-File -FilePath $BackupPath -Encoding UTF8
}

# Function to create backup file after creation
function New-TicketPostCreationBackup {
    param(
        [string]$BackupPath,
        [int]$IssueNumber,
        [string]$Title,
        [string]$Body,
        [string]$Labels,
        [string]$Timestamp,
        [string]$OperationDetails
    )
    
    $backupContent = @"
---
operation: created
timestamp: $Timestamp
issue_number: $IssueNumber
issue_title: $Title
labels: $Labels
operation_details: $OperationDetails
---

# $Title

$Body
"@
    
    $backupContent | Out-File -FilePath $BackupPath -Encoding UTF8
}

# Main execution
try {
    Write-Host "Creating GitHub ticket: $Title" -ForegroundColor Cyan
    
    # Validate GitHub CLI
    if (-not (Test-GitHubCLI)) {
        throw "GitHub CLI (gh) not found or not working. Please install GitHub CLI from https://cli.github.com/ and run 'gh auth login'"
    }
    
    # Initialize backup directory
    Initialize-BackupDirectory -Path $BackupDir
    
    # Get timestamp for backup files
    $timestamp = Get-ISOTimestamp
    
    # Determine body content
    $bodyContent = $Body
    if ($BodyFile -and (Test-Path $BodyFile)) {
        $bodyContent = Get-Content $BodyFile -Raw
    }
    
    # Create pre-creation backup
    $preCreationBackupPath = Join-Path $BackupDir "issue-create-$timestamp-pre.md"
    New-TicketCreationBackup -BackupPath $preCreationBackupPath -Title $Title -Body $bodyContent -Labels $Labels -Timestamp $timestamp -OperationDetails $OperationDetails
    
    # Build GitHub CLI command
    $ghArgs = @("issue", "create", "--title", $Title)
    
    if ($bodyContent) {
        $ghArgs += @("--body", $bodyContent)
    }
    
    if ($Labels) {
        $ghArgs += @("--label", $Labels)
    }
    
    # Execute GitHub CLI command
    Write-Host "Executing: gh $($ghArgs -join ' ')" -ForegroundColor Gray
    $result = & gh @ghArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI failed with exit code $LASTEXITCODE. Output: $result"
    }
    
    # Extract issue number from result
    $issueNumber = $null
    if ($result -match "https://github\.com/.+/issues/(\d+)") {
        $issueNumber = [int]$matches[1]
    } else {
        throw "Could not extract issue number from GitHub CLI output: $result"
    }
    
    # Create post-creation backup
    $postCreationBackupPath = Join-Path $BackupDir "issue-$issueNumber-$timestamp-created.md"
    New-TicketPostCreationBackup -BackupPath $postCreationBackupPath -IssueNumber $issueNumber -Title $Title -Body $bodyContent -Labels $Labels -Timestamp $timestamp -OperationDetails $OperationDetails
    
    # Return result object
    $resultObject = [PSCustomObject]@{
        Success = $true
        IssueNumber = $issueNumber
        Title = $Title
        Body = $bodyContent
        Labels = $Labels
        Url = $result
        PreCreationBackupPath = $preCreationBackupPath
        PostCreationBackupPath = $postCreationBackupPath
        Timestamp = $timestamp
        OperationDetails = $OperationDetails
        Error = $null
    }
    
    Write-Host "✅ Successfully created issue #$issueNumber" -ForegroundColor Green
    Write-Host "📝 Pre-creation backup: $preCreationBackupPath" -ForegroundColor Gray
    Write-Host "📝 Post-creation backup: $postCreationBackupPath" -ForegroundColor Gray
    Write-Host "🔗 Issue URL: $result" -ForegroundColor Blue
    
    return $resultObject
    
} catch {
    $errorMessage = $_.Exception.Message
    Write-Host "❌ Failed to create GitHub ticket: $errorMessage" -ForegroundColor Red
    
    # Return error result object
    $errorResult = [PSCustomObject]@{
        Success = $false
        IssueNumber = $null
        Title = $Title
        Body = $bodyContent
        Labels = $Labels
        Url = $null
        PreCreationBackupPath = $preCreationBackupPath
        PostCreationBackupPath = $null
        Timestamp = $timestamp
        OperationDetails = $OperationDetails
        Error = $errorMessage
    }
    
    return $errorResult
}