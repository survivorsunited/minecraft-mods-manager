# Test script to verify backup functionality
Write-Host "Testing backup functionality..." -ForegroundColor Yellow

# Test the Get-BackupPath function
$testPath = "modlist.csv"
$backupPath = Get-BackupPath -OriginalPath $testPath -BackupType "test"

Write-Host "Original path: $testPath" -ForegroundColor White
Write-Host "Backup path: $backupPath" -ForegroundColor White

# Check if backups folder exists
if (Test-Path "backups") {
    Write-Host "✅ Backups folder exists" -ForegroundColor Green
    Get-ChildItem "backups" | ForEach-Object {
        Write-Host "  Found: $($_.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ Backups folder does not exist" -ForegroundColor Red
}

# Test creating a backup
Write-Host "`nCreating test backup..." -ForegroundColor Yellow
Copy-Item "modlist.csv" -Destination $backupPath -ErrorAction SilentlyContinue

if (Test-Path $backupPath) {
    Write-Host "✅ Test backup created successfully: $backupPath" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create test backup" -ForegroundColor Red
}

Write-Host "`nBackup test completed!" -ForegroundColor Yellow 