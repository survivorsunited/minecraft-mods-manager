# Daily Mod Update Script
# This script runs ModManager to update modlist.csv with latest versions
# Can be run manually or scheduled with Windows Task Scheduler

param(
    [switch]$CommitChanges = $true,
    [switch]$PushChanges = $true,
    [string]$CommitMessage = "",
    [switch]$Verbose = $false
)

# Set up logging
$logFile = Join-Path $PSScriptRoot "..\logs\daily-update-$(Get-Date -Format 'yyyy-MM-dd').log"
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

function Test-GitStatus {
    try {
        $status = git status --porcelain 2>$null
        return $status
    }
    catch {
        Write-Log "Error checking git status: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Commit-Changes {
    param([string]$Message)
    try {
        Write-Log "Configuring git user..." "INFO"
        git config --local user.email "daily-update@survivorsunited.org"
        git config --local user.name "Daily Update Script"
        
        Write-Log "Adding modlist.csv to git..." "INFO"
        git add modlist.csv
        
        Write-Log "Committing changes with message: $Message" "INFO"
        $commitResult = git commit -m $Message 2>&1
        Write-Log "Commit result: $commitResult" "INFO"
        
        return $true
    }
    catch {
        Write-Log "Error committing changes: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Push-Changes {
    try {
        Write-Log "Pushing changes to remote repository..." "INFO"
        $pushResult = git push 2>&1
        Write-Log "Push result: $pushResult" "INFO"
        Write-Log "Changes pushed successfully" "INFO"
        return $true
    }
    catch {
        Write-Log "Error pushing changes: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main execution
Write-Log "🔄 Starting daily mod update pipeline..." "INFO"
Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')" "INFO"
Write-Log "Working directory: $(Get-Location)" "INFO"
Write-Log "Commit changes: $CommitChanges" "INFO"
Write-Log "Push changes: $PushChanges" "INFO"

try {
    # Check if we're in a git repository
    if (-not (Test-Path ".git")) {
        Write-Log "❌ Not in a git repository. Cannot commit changes." "ERROR"
        exit 1
    }
    
    # Check if ModManager.ps1 exists
    $modManagerPath = Join-Path $PSScriptRoot "..\ModManager.ps1"
    if (-not (Test-Path $modManagerPath)) {
        Write-Log "❌ ModManager.ps1 not found at: $modManagerPath" "ERROR"
        exit 1
    }
    
    # Check if modlist.csv exists
    $modListPath = Join-Path $PSScriptRoot "..\modlist.csv"
    if (-not (Test-Path $modListPath)) {
        Write-Log "❌ modlist.csv not found at: $modListPath" "ERROR"
        exit 1
    }
    
    # Get initial git status
    Write-Log "📋 Checking initial git status..." "INFO"
    $initialStatus = Test-GitStatus
    if ($Verbose) {
        Write-Log "Initial git status: $initialStatus" "DEBUG"
    }
    
    # Run ModManager to update all mods
    Write-Log "📋 Running ModManager to update modlist.csv..." "INFO"
    Write-Log "Command: pwsh -NoProfile -ExecutionPolicy Bypass -File '$modManagerPath' -ValidateAllModVersions -UpdateMods" "INFO"
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $modManagerPath -ValidateAllModVersions -UpdateMods 2>&1
    
    Write-Log "ModManager output:" "INFO"
    Write-Log $result "INFO"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "✅ ModManager completed successfully" "INFO"
        
        # Check if modlist.csv was modified
        Write-Log "📋 Checking git status for modlist.csv changes..." "INFO"
        $finalStatus = Test-GitStatus
        $modlistChanges = $finalStatus | Where-Object { $_ -match "modlist\.csv" }
        Write-Log "Git status for modlist.csv: $modlistChanges" "INFO"
        
        if ($modlistChanges) {
            Write-Log "📝 Changes detected in modlist.csv" "INFO"
            
            if ($Verbose) {
                # Show what changed
                Write-Log "📊 Changes summary:" "DEBUG"
                $diff = git diff --stat modlist.csv
                Write-Log $diff "DEBUG"
                
                # Show detailed changes
                Write-Log "📋 Detailed changes:" "DEBUG"
                $detailedDiff = git diff modlist.csv
                Write-Log $detailedDiff "DEBUG"
            }
            
            if ($CommitChanges) {
                # Generate commit message
                if ([string]::IsNullOrEmpty($CommitMessage)) {
                    $CommitMessage = "🤖 Daily mod update - $(Get-Date -Format 'yyyy-MM-dd')"
                }
                
                Write-Log "Commit message: $CommitMessage" "INFO"
                
                # Commit changes
                if (Commit-Changes -Message $CommitMessage) {
                    Write-Log "✅ Changes committed successfully" "INFO"
                    
                    # Push changes if requested
                    if ($PushChanges) {
                        if (Push-Changes) {
                            Write-Log "✅ Changes pushed to repository" "INFO"
                        } else {
                            Write-Log "❌ Failed to push changes" "ERROR"
                            exit 1
                        }
                    } else {
                        Write-Log "ℹ️  Skipping push (PushChanges = false)" "INFO"
                    }
                } else {
                    Write-Log "❌ Failed to commit changes" "ERROR"
                    exit 1
                }
            } else {
                Write-Log "ℹ️  Skipping commit (CommitChanges = false)" "INFO"
            }
        } else {
            Write-Log "ℹ️  No changes detected in modlist.csv" "INFO"
            Write-Log "📊 All mods are already up to date" "INFO"
        }
    } else {
        Write-Log "❌ ModManager failed with exit code: $LASTEXITCODE" "ERROR"
        Write-Log "Error output: $result" "ERROR"
        exit 1
    }
}
catch {
    Write-Log "❌ Error during daily mod update: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}

Write-Log "🏁 Daily mod update pipeline completed" "INFO"
Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')" "INFO"
Write-Log "Log file: $logFile" "INFO" 