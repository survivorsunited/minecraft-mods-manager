#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Get or update GitHub tickets with proper backup and error handling.

.DESCRIPTION
    A wrapper script that provides a clean interface for reading and updating
    GitHub tickets. Uses the underlying Read-Ticket.ps1 and Update-Ticket.ps1
    scripts to ensure proper backup creation and error handling.

.PARAMETER IssueNumber
    The GitHub issue number to work with.

.PARAMETER Action
    The action to perform: "read" or "update" (default: "read").

.PARAMETER Title
    The new title for the issue (for update action).

.PARAMETER Body
    The new body content for the issue (for update action).

.PARAMETER BodyFile
    Path to a file containing the new body content (for update action).

.PARAMETER Labels
    Comma-separated list of labels to add (for update action).

.PARAMETER State
    The state to set (open/closed) (for update action).

.PARAMETER BackupDir
    The directory to store backup files. Defaults to .tasks/

.PARAMETER OperationDetails
    Description of what this operation is doing (for update action).

.EXAMPLE
    .\Get-Ticket.ps1 -IssueNumber 54
    # Reads ticket #54

.EXAMPLE
    .\Get-Ticket.ps1 -IssueNumber 54 -Action "update" -Body "Updated content" -OperationDetails "Adding new requirements"
    # Updates ticket #54 with new body content

.EXAMPLE
    .\Get-Ticket.ps1 -IssueNumber 21 -Action "update" -State "closed" -OperationDetails "Closing completed issue"
    # Closes ticket #21
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$IssueNumber,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("read", "update")]
    [string]$Action = "read",
    
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
    
    [Parameter(Mandatory = $false)]
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

# Function to get script directory
function Get-ScriptDirectory {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        return Split-Path -Parent $scriptPath
    } else {
        # Fallback to current directory if script path is not available
        return Get-Location
    }
}

# Function to validate required parameters for update action
function Test-UpdateParameters {
    if ($Action -eq "update") {
        $hasUpdates = $false
        
        if ($Title) { $hasUpdates = $true }
        if ($Body) { $hasUpdates = $true }
        if ($BodyFile) { $hasUpdates = $true }
        if ($Labels) { $hasUpdates = $true }
        if ($State) { $hasUpdates = $true }
        
        if (-not $hasUpdates) {
            Write-ColorOutput "⚠ Warning: Update action specified but no update parameters provided." "Yellow"
            Write-ColorOutput "   This will only read the ticket and create a backup." "Yellow"
        }
        
        if (-not $OperationDetails) {
            Write-ColorOutput "⚠ Warning: Update action specified but no OperationDetails provided." "Yellow"
            Write-ColorOutput "   Using default operation details." "Yellow"
            $script:OperationDetails = "Updating ticket content"
        }
    }
}

# Main execution
try {
    Write-ColorOutput "=== GitHub Ticket Manager ===" "Magenta"
    Write-ColorOutput "Action: $Action" "White"
    Write-ColorOutput "Issue: #$IssueNumber" "White"
    
    # Validate parameters
    Test-UpdateParameters
    
    # Get script directory - use the scripts folder
    $scriptDir = Join-Path (Get-Location) "scripts"
    
    if ($Action -eq "read") {
        # Read ticket
        Write-ColorOutput "`nReading ticket #$IssueNumber..." "Cyan"
        
        $readScript = Join-Path $scriptDir "Read-Ticket.ps1"
        if (-not (Test-Path $readScript)) {
            throw "Read-Ticket.ps1 not found at: $readScript"
        }
        
        $resultRaw = & pwsh -NoProfile -ExecutionPolicy Bypass -File $readScript -IssueNumber $IssueNumber -BackupDir $BackupDir
        $result = $resultRaw | Select-Object -Last 1
        
        if ($result.Success) {
            Write-ColorOutput "`n✓ Ticket read operation completed successfully" "Green"
            Write-ColorOutput ("Backup file: " + $result.BackupPath) "Green"
            Write-ColorOutput "`n=== Ticket Content ===" "Magenta"
            $result.Content | Out-String | Write-Host
            return $result
        } else {
            Write-ColorOutput "`n=== Error Summary ===" "Red"
            Write-ColorOutput "✗ Failed to read ticket #$IssueNumber" "Red"
            Write-ColorOutput ("Error: " + $result.Error) "Red"
            return $result
        }
    }
    elseif ($Action -eq "update") {
        # Update ticket
        Write-ColorOutput "`nUpdating ticket #$IssueNumber..." "Cyan"
        
        $updateScript = Join-Path $scriptDir "Update-Ticket.ps1"
        if (-not (Test-Path $updateScript)) {
            throw "Update-Ticket.ps1 not found at: $updateScript"
        }
        
        # Build parameters for update script
        $updateParams = @{
            IssueNumber = $IssueNumber
            BackupDir = $BackupDir
            OperationDetails = $OperationDetails
        }
        
        if ($Title) { $updateParams.Title = $Title }
        if ($Body) { $updateParams.Body = $Body }
        if ($BodyFile) { $updateParams.BodyFile = $BodyFile }
        if ($Labels) { $updateParams.Labels = $Labels }
        if ($State) { $updateParams.State = $State }
        
        $resultRaw = & pwsh -NoProfile -ExecutionPolicy Bypass -File $updateScript @updateParams
        $result = $resultRaw | Where-Object { $_.PSObject.Properties.Name -contains 'Success' } | Select-Object -Last 1
        
        if ($result.Success) {
            Write-ColorOutput "`n✓ Ticket update operation completed successfully" "Green"
            Write-ColorOutput ("Read backup: " + $result.ReadBackupPath) "Green"
            Write-ColorOutput ("Update backup: " + $result.UpdateBackupPath) "Green"
            Write-ColorOutput "`n=== Updated Ticket Content ===" "Magenta"
            $result.UpdatedContent | Out-String | Write-Host
            return $result
        } else {
            Write-ColorOutput "`n=== Error Summary ===" "Red"
            Write-ColorOutput "✗ Failed to update ticket #$IssueNumber" "Red"
            Write-ColorOutput ("Error: " + $result.Error) "Red"
            return $result
        }
    }
}
catch {
    Write-ColorOutput "`n=== Error Summary ===" "Red"
    Write-ColorOutput "✗ Failed to $Action ticket #$IssueNumber" "Red"
    Write-ColorOutput ("Error: " + $_.Exception.Message) "Red"
    
    return @{
        IssueNumber = $IssueNumber
        Action = $Action
        Success = $false
        Error = $_.Exception.Message
    }
} 