#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Update a GitHub ticket with proper backup creation and content preservation.

.DESCRIPTION
    Updates a GitHub ticket using gh CLI, creates backups before and after updates,
    preserves existing content, and handles errors gracefully. This script ensures
    all ticket update operations are properly backed up as required by the project rules.

.PARAMETER IssueNumber
    The GitHub issue number to update.

.PARAMETER Title
    The new title for the issue (optional).

.PARAMETER Body
    The new body content for the issue (optional).

.PARAMETER BodyFile
    Path to a file containing the new body content (optional).

.PARAMETER Labels
    Comma-separated list of labels to add (optional).

.PARAMETER State
    The state to set (open/closed) (optional).

.PARAMETER BackupDir
    The directory to store backup files. Defaults to .tasks/

.PARAMETER OperationDetails
    Description of what this update operation is doing.

.EXAMPLE
    .\Update-Ticket.ps1 -IssueNumber 54 -Body "Updated content" -OperationDetails "Adding new requirements"

.EXAMPLE
    .\Update-Ticket.ps1 -IssueNumber 21 -BodyFile "update-content.md" -Labels "bug,high-priority"

.EXAMPLE
    .\Update-Ticket.ps1 -IssueNumber 33 -State "closed" -OperationDetails "Closing completed issue"
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$IssueNumber,
    
    [Parameter(Mandatory = $false)]
    [string]$Title,
    
    [Parameter(Mandatory = $false)]
    [string]$Body,
    
    [Parameter(Mandatory = $false)]
    [string]$BodyFile,
    
    [Parameter(Mandatory = $false)]
    [string]$Labels,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("open", "closed")]
    [string]$State,
    
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

# Function to strip metadata from content
function Remove-MetadataFromContent {
    param([string]$Content)
    
    if (-not $Content) {
        return ""
    }
    
    # Split content into lines
    $lines = $Content -split "`n"
    
    # Find where metadata ends (after the second --- line)
    $contentStartIndex = -1
    $metadataCount = 0
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq "---") {
            $metadataCount++
            if ($metadataCount -eq 2) {
                $contentStartIndex = $i + 1
                break
            }
        }
    }
    
    # If we found metadata, return only the content part
    if ($contentStartIndex -ge 0) {
        return ($lines[$contentStartIndex..($lines.Count-1)] -join "`n").Trim()
    }
    
    # If no metadata found, return original content
    return $Content
}

# Function to build gh edit command
function Build-GitHubEditCommand {
    param(
        [int]$IssueNumber,
        [string]$Title,
        [string]$Body,
        [string]$BodyFile,
        [string]$Labels,
        [string]$State
    )
    
    $command = "gh issue edit $IssueNumber"
    $params = @()
    
    if ($Title) {
        $params += "--title `"$Title`""
    }
    
    if ($Body) {
        # Strip any metadata from body content before writing to GitHub
        $cleanBody = Remove-MetadataFromContent -Content $Body
        
        # Create temporary file for body content
        $tempFile = [System.IO.Path]::GetTempFileName()
        $cleanBody | Out-File -FilePath $tempFile -Encoding UTF8
        $params += "--body-file `"$tempFile`""
        $script:tempFiles += $tempFile
    }
    elseif ($BodyFile) {
        if (-not (Test-Path $BodyFile)) {
            throw "Body file not found: $BodyFile"
        }
        
        # Read file content and strip metadata
        $fileContent = Get-Content -Path $BodyFile -Raw
        $cleanContent = Remove-MetadataFromContent -Content $fileContent
        
        # Create temporary file with clean content
        $tempFile = [System.IO.Path]::GetTempFileName()
        $cleanContent | Out-File -FilePath $tempFile -Encoding UTF8
        $params += "--body-file `"$tempFile`""
        $script:tempFiles += $tempFile
    }
    
    if ($Labels) {
        $params += "--label `"$Labels`""
    }
    
    if ($State) {
        $params += "--state `"$State`""
    }
    
    if ($params.Count -gt 0) {
        $command += " " + ($params -join " ")
    }
    
    return $command
}

# Function to update ticket
function Update-GitHubTicket {
    param(
        [string]$Command
    )
    
    try {
        Write-ColorOutput "Executing: $Command" "Cyan"
        $output = Invoke-Expression $Command 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update issue. Exit code: $LASTEXITCODE. Output: $output"
        }
        
        return $output
    }
    catch {
        Write-ColorOutput "✗ Error updating ticket: $($_.Exception.Message)" "Red"
        throw
    }
}

# Function to cleanup temporary files
function Remove-TempFiles {
    if ($script:tempFiles) {
        foreach ($file in $script:tempFiles) {
            if (Test-Path $file) {
                Remove-Item $file -Force
                Write-ColorOutput "Cleaned up temporary file: $file" "Yellow"
            }
        }
    }
}

# Initialize temp files array
$script:tempFiles = @()

# Main execution
try {
    Write-ColorOutput "=== GitHub Ticket Updater ===" "Magenta"
    Write-ColorOutput "Updating ticket #$IssueNumber" "White"
    Write-ColorOutput "Operation: $OperationDetails" "White"
    
    # Validate GitHub CLI
    if (-not (Test-GitHubCLI)) {
        exit 1
    }
    
    # Initialize backup directory
    Initialize-BackupDirectory -Path $BackupDir
    
    # Read current ticket content and create backup
    $currentContent = Read-GitHubTicket -IssueNumber $IssueNumber
    $readBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "read" -Content $currentContent -BackupDir $BackupDir -OperationDetails "Reading current content before update"
    
    # Build update command
    $updateCommand = Build-GitHubEditCommand -IssueNumber $IssueNumber -Title $Title -Body $Body -BodyFile $BodyFile -Labels $Labels -State $State
    
    # Check if we have any updates to make
    if ($updateCommand -eq "gh issue edit $IssueNumber") {
        Write-ColorOutput "⚠ No update parameters provided. Nothing to update." "Yellow"
        return @{
            IssueNumber = $IssueNumber
            Success = $true
            Message = "No updates needed"
            ReadBackupPath = $readBackupPath
        }
    }
    
    # Update the ticket
    $updateOutput = Update-GitHubTicket -Command $updateCommand
    
    # Read updated content and create backup
    $updatedContent = Read-GitHubTicket -IssueNumber $IssueNumber
    $updateBackupPath = New-TicketBackup -IssueNumber $IssueNumber -Operation "update" -Content $updatedContent -BackupDir $BackupDir -OperationDetails $OperationDetails
    
    # Display updated content
    Write-ColorOutput "`n=== Updated Ticket Content ===" "Magenta"
    Write-Host $updatedContent
    
    Write-ColorOutput "`n=== Summary ===" "Magenta"
    Write-ColorOutput "✓ Ticket #$IssueNumber updated successfully" "Green"
    Write-ColorOutput "✓ Read backup created: $readBackupPath" "Green"
    Write-ColorOutput "✓ Update backup created: $updateBackupPath" "Green"
    Write-ColorOutput "✓ Operation completed successfully" "Green"
    
    # Cleanup temporary files
    Remove-TempFiles
    
    # Return the results for potential further processing
    return @{
        IssueNumber = $IssueNumber
        Success = $true
        ReadBackupPath = $readBackupPath
        UpdateBackupPath = $updateBackupPath
        UpdatedContent = $updatedContent
        Command = $updateCommand
    }
}
catch {
    Write-ColorOutput "`n=== Error Summary ===" "Red"
    Write-ColorOutput "✗ Failed to update ticket #$IssueNumber" "Red"
    Write-ColorOutput "Error: $($_.Exception.Message)" "Red"
    
    # Cleanup temporary files on error
    Remove-TempFiles
    
    return @{
        IssueNumber = $IssueNumber
        Success = $false
        Error = $_.Exception.Message
    }
}
finally {
    # Ensure cleanup happens even if there's an error
    Remove-TempFiles
} 