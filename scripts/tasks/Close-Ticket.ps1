# =============================================================================
# GitHub Ticket Closer - Close GitHub Tickets with Backup Creation
# =============================================================================
# 
# This script closes GitHub tickets with proper backup creation and error handling.
# It follows the mandatory workflow defined in .cursor/rules/gov-06-issues.mdc
# 
# USAGE:
#   .\Close-Ticket.ps1 -IssueNumber 59 -OperationDetails "Closing completed ticket"
# 
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [int]$IssueNumber,
    
    [Parameter(Mandatory=$true)]
    [string]$OperationDetails,
    
    [string]$BackupDir = ".tasks"
)

# =============================================================================
# Helper Functions
# =============================================================================

function Get-ISOTimestamp {
    return (Get-Date).ToString("yyyy-MM-dd_HHmmss")
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-GitHubCLI {
    try {
        $null = Get-Command "gh" -ErrorAction Stop
        $result = & gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub CLI not authenticated. Run 'gh auth login' first."
        }
        return $true
    }
    catch {
        throw "GitHub CLI (gh) not found or not authenticated. Please install GitHub CLI and run 'gh auth login'."
    }
}

function Initialize-BackupDirectory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-ColorOutput "Created backup directory: $Path" "Green"
    }
}

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
status: CLOSED
---

$Content
"@
    
    try {
        $backupContent | Out-File -FilePath $backupPath -Encoding UTF8
        Write-ColorOutput "✓ Backup created: $backupPath" "Green"
        return $backupPath
    }
    catch {
        throw "Failed to create backup file: $($_.Exception.Message)"
    }
}

function Get-TicketContent {
    param([int]$IssueNumber)
    
    try {
        $content = & gh issue view $IssueNumber --json title,body,state | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to read issue #$IssueNumber"
        }
        
        $fullContent = "# $($content.title)`n`n$($content.body)"
        return @{
            Title = $content.title
            Body = $content.body
            State = $content.state
            FullContent = $fullContent
        }
    }
    catch {
        throw "Failed to read issue #$IssueNumber`: $($_.Exception.Message)"
    }
}

function Close-GitHubIssue {
    param([int]$IssueNumber)
    
    try {
        $result = & gh issue close $IssueNumber 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to close issue #$IssueNumber. Error: $result"
        }
        return $true
    }
    catch {
        throw "Failed to close issue #$IssueNumber`: $($_.Exception.Message)"
    }
}

# =============================================================================
# Main Script Logic
# =============================================================================

Write-ColorOutput "=== GitHub Ticket Closer ===" "Cyan"
Write-ColorOutput "Closing ticket #$IssueNumber" "Yellow"
Write-ColorOutput "Operation: $OperationDetails" "Yellow"

try {
    # Validate GitHub CLI
    Test-GitHubCLI
    
    # Initialize backup directory
    Initialize-BackupDirectory $BackupDir
    
    # Read current ticket content for backup
    Write-ColorOutput "Reading current content of issue #$IssueNumber..." "Yellow"
    $ticketContent = Get-TicketContent -IssueNumber $IssueNumber
    
    # Check if already closed
    if ($ticketContent.State -eq "CLOSED") {
        Write-ColorOutput "✓ Issue #$IssueNumber is already closed" "Green"
        
        # Create backup anyway for record keeping
        $readBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "close-already-closed" -Content $ticketContent.FullContent -BackupDir $BackupDir -OperationDetails $OperationDetails
        
        $result = [PSCustomObject]@{
            Success = $true
            IssueNumber = $IssueNumber
            State = "ALREADY_CLOSED"
            BackupPath = $readBackupPath
            OperationDetails = $OperationDetails
        }
        
        Write-ColorOutput "`n=== Summary ===" "Cyan"
        Write-ColorOutput "✓ Issue #$IssueNumber was already closed" "Green"
        Write-ColorOutput "✓ Backup created: $readBackupPath" "Green"
        
        return $result
    }
    
    # Create backup before closing
    $readBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "close-read" -Content $ticketContent.FullContent -BackupDir $BackupDir -OperationDetails $OperationDetails
    
    # Close the issue
    Write-ColorOutput "Closing issue #$IssueNumber..." "Yellow"
    Close-GitHubIssue -IssueNumber $IssueNumber
    
    # Read updated content for verification backup
    $updatedContent = Get-TicketContent -IssueNumber $IssueNumber
    $closeBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "close-closed" -Content $updatedContent.FullContent -BackupDir $BackupDir -OperationDetails $OperationDetails
    
    # Return success result
    $result = [PSCustomObject]@{
        Success = $true
        IssueNumber = $IssueNumber
        State = $updatedContent.State
        ReadBackupPath = $readBackupPath
        CloseBackupPath = $closeBackupPath
        OperationDetails = $OperationDetails
    }
    
    Write-ColorOutput "`n=== Summary ===" "Cyan"
    Write-ColorOutput "✓ Issue #$IssueNumber closed successfully" "Green"
    Write-ColorOutput "✓ Read backup created: $readBackupPath" "Green"
    Write-ColorOutput "✓ Close backup created: $closeBackupPath" "Green"
    Write-ColorOutput "✓ Operation completed successfully" "Green"
    
    return $result
}
catch {
    # Handle errors with proper output
    $errorResult = [PSCustomObject]@{
        Success = $false
        IssueNumber = $IssueNumber
        Error = $_.Exception.Message
        OperationDetails = $OperationDetails
    }
    
    Write-ColorOutput "`n=== Error Summary ===" "Red"
    Write-ColorOutput "✗ Failed to close ticket #$IssueNumber" "Red"
    Write-ColorOutput "Error: $($_.Exception.Message)" "Red"
    
    return $errorResult
}