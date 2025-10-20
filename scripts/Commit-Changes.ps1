param(
    [Parameter(Mandatory=$true)]
    [string]$Message,
    
    [Parameter(Mandatory=$false)]
    [string[]]$Files = @(),
    
    [switch]$Push
)

# Add files
if ($Files.Count -gt 0) {
    Write-Host "Adding files..." -ForegroundColor Cyan
    foreach ($file in $Files) {
        git add $file
        Write-Host "  Added: $file" -ForegroundColor Green
    }
} else {
    Write-Host "Adding all changes..." -ForegroundColor Cyan
    git add -A
}

# Commit
Write-Host "Committing with message: $Message" -ForegroundColor Cyan
git commit -m $Message

if ($LASTEXITCODE -ne 0) {
    Write-Host "Commit failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Commit successful!" -ForegroundColor Green

# Push if requested
if ($Push) {
    Write-Host "Pushing to remote..." -ForegroundColor Cyan
    git push
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Push failed!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Push successful!" -ForegroundColor Green
}

exit 0

