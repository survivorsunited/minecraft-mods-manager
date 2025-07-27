#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Get the next GitHub ticket to work on with automatic prioritization.

.DESCRIPTION
    Queries GitHub issues to find the next ticket to work on based on priority,
    phase, and current development status. Automatically filters and prioritizes
    issues for efficient workflow management.

.PARAMETER ReadTicket
    Automatically read the next ticket after finding it.

.PARAMETER Priority
    Filter by priority label (high-priority, medium-priority, low-priority).

.PARAMETER Phase
    Filter by development phase (Phase 1, Phase 2, Phase 3, Phase 4).

.PARAMETER Limit
    Number of tickets to return (default: 1).

.PARAMETER BackupDir
    Backup directory for ticket operations (default: .tasks/).

.EXAMPLE
    .\Get-Next-Ticket.ps1
    # Gets the next highest priority ticket

.EXAMPLE
    .\Get-Next-Ticket.ps1 -ReadTicket
    # Gets and reads the next ticket

.EXAMPLE
    .\Get-Next-Ticket.ps1 -Priority "high-priority" -Phase "Phase 2"
    # Gets next high-priority ticket from Phase 2

.EXAMPLE
    .\Get-Next-Ticket.ps1 -Limit 5
    # Gets next 5 tickets to work on
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$ReadTicket,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("high-priority", "medium-priority", "low-priority")]
    [string]$Priority,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Phase 1", "Phase 2", "Phase 3", "Phase 4")]
    [string]$Phase,
    
    [Parameter(Mandatory = $false)]
    [int]$Limit = 1,
    
    [Parameter(Mandatory = $false)]
    [string]$BackupDir = ".tasks"
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

# Function to build GitHub CLI query
function Build-GitHubQuery {
    $query = @("issue", "list", "--state", "open", "--json", "number,title,labels,assignees,createdAt,updatedAt")
    
    if ($Priority) {
        $query += @("--label", $Priority)
    }
    
    if ($Phase) {
        $query += @("--milestone", $Phase)
    }
    
    $query += @("--limit", $Limit.ToString())
    
    return $query
}

# Function to prioritize issues
function Sort-IssuesByPriority {
    param([array]$Issues)
    
    # Define priority order
    $priorityOrder = @{
        "high-priority" = 1
        "medium-priority" = 2
        "low-priority" = 3
    }
    
    # Sort issues by priority, then by creation date
    $sortedIssues = $Issues | Sort-Object {
        $highestPriority = 999
        foreach ($label in $_.labels) {
            if ($priorityOrder.ContainsKey($label.name)) {
                $highestPriority = [Math]::Min($highestPriority, $priorityOrder[$label.name])
            }
        }
        return $highestPriority
    }, "createdAt"
    
    return $sortedIssues
}

# Function to display issue information
function Show-IssueInfo {
    param([object]$Issue)
    
    Write-ColorOutput "`n=== Next Ticket to Work On ===" "Magenta"
    Write-ColorOutput "Issue #$($Issue.number): $($Issue.title)" "White"
    
    # Show labels
    if ($Issue.labels.Count -gt 0) {
        $labelNames = $Issue.labels | ForEach-Object { $_.name }
        Write-ColorOutput "Labels: $($labelNames -join ', ')" "Cyan"
    }
    
    # Show assignees
    if ($Issue.assignees.Count -gt 0) {
        $assigneeNames = $Issue.assignees | ForEach-Object { $_.login }
        Write-ColorOutput "Assigned to: $($assigneeNames -join ', ')" "Yellow"
    }
    
    # Show dates
    $createdDate = [DateTime]::Parse($Issue.createdAt).ToString("yyyy-MM-dd")
    $updatedDate = [DateTime]::Parse($Issue.updatedAt).ToString("yyyy-MM-dd")
    Write-ColorOutput "Created: $createdDate | Updated: $updatedDate" "Gray"
    
    Write-ColorOutput "=================================" "Magenta"
}

# Function to read ticket using Read-Ticket.ps1
function Read-NextTicket {
    param([int]$IssueNumber)
    
    try {
        Write-ColorOutput "`nReading ticket #$IssueNumber..." "Cyan"
        
        $readScript = Join-Path $PSScriptRoot "Read-Ticket.ps1"
        if (-not (Test-Path $readScript)) {
            throw "Read-Ticket.ps1 not found at: $readScript"
        }
        
        $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $readScript -IssueNumber $IssueNumber -BackupDir $BackupDir
        
        if ($result.Success) {
            Write-ColorOutput "✓ Ticket read successfully" "Green"
            Write-ColorOutput "Backup created: $($result.ReadBackupPath)" "Green"
            
            Write-ColorOutput "`n=== Ticket Content ===" "Magenta"
            $result.Content | Out-String | Write-Host
            return $result
        } else {
            Write-ColorOutput "✗ Failed to read ticket: $($result.Error)" "Red"
            return $result
        }
    }
    catch {
        Write-ColorOutput "✗ Error reading ticket: $($_.Exception.Message)" "Red"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Main execution
try {
    Write-ColorOutput "=== GitHub Next Ticket Finder ===" "Magenta"
    
    # Validate GitHub CLI
    if (-not (Test-GitHubCLI)) {
        exit 1
    }
    
    # Build query
    $query = Build-GitHubQuery
    Write-ColorOutput "Querying GitHub issues..." "Cyan"
    Write-ColorOutput "Command: gh $($query -join ' ')" "Gray"
    
    # Execute query
    $jsonOutput = gh $query 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to query GitHub issues. Exit code: $LASTEXITCODE"
    }
    
    # Parse JSON
    $issues = $jsonOutput | ConvertFrom-Json
    
    if ($issues.Count -eq 0) {
        Write-ColorOutput "`nNo open issues found matching criteria." "Yellow"
        Write-ColorOutput "Try adjusting priority or phase filters." "Yellow"
        return @{ Success = $false; Issues = @(); Message = "No issues found" }
    }
    
    # Sort by priority
    $sortedIssues = Sort-IssuesByPriority -Issues $issues
    
    # Display results
    if ($Limit -eq 1) {
        $nextIssue = $sortedIssues[0]
        Show-IssueInfo -Issue $nextIssue
        
        $result = @{
            Success = $true
            Issue = $nextIssue
            IssueNumber = $nextIssue.number
            Title = $nextIssue.title
            Labels = $nextIssue.labels
            Message = "Found next ticket: #$($nextIssue.number)"
        }
        
        # Read ticket if requested
        if ($ReadTicket) {
            $readResult = Read-NextTicket -IssueNumber $nextIssue.number
            $result.ReadResult = $readResult
        }
        
        return $result
    } else {
        Write-ColorOutput "`n=== Next $($sortedIssues.Count) Tickets ===" "Magenta"
        
        for ($i = 0; $i -lt $sortedIssues.Count; $i++) {
            $issue = $sortedIssues[$i]
            Write-ColorOutput "`n$($i + 1). Issue #$($issue.number): $($issue.title)" "White"
            
            if ($issue.labels.Count -gt 0) {
                $labelNames = $issue.labels | ForEach-Object { $_.name }
                Write-ColorOutput "   Labels: $($labelNames -join ', ')" "Cyan"
            }
        }
        
        return @{
            Success = $true
            Issues = $sortedIssues
            Count = $sortedIssues.Count
            Message = "Found $($sortedIssues.Count) tickets"
        }
    }
}
catch {
    Write-ColorOutput "`n=== Error Summary ===" "Red"
    Write-ColorOutput "✗ Failed to get next ticket" "Red"
    Write-ColorOutput ("Error: " + $_.Exception.Message) "Red"
    
    return @{
        Success = $false
        Error = $_.Exception.Message
        Message = "Failed to get next ticket"
    }
} 