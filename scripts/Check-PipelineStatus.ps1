# Check-PipelineStatus.ps1
# Checks the latest Test Suite pipeline run and shows failures

param(
    [int]$Limit = 1,
    [switch]$ShowFailures,
    [switch]$ShowLogs
)

Write-Host "=== Pipeline Status Check ===" -ForegroundColor Cyan
Write-Host ""

# Get latest run
$runs = gh run list --workflow "Test Suite" --limit $Limit --json databaseId,status,conclusion,createdAt,name,headBranch --jq '.[] | "\(.databaseId)|\(.status)|\(.conclusion // "in_progress")|\(.createdAt)|\(.name)|\(.headBranch)"' | ConvertFrom-String -Delimiter '\|' -PropertyNames RunId,Status,Conclusion,CreatedAt,Name,Branch

if (-not $runs) {
    Write-Host "No pipeline runs found" -ForegroundColor Yellow
    exit 1
}

foreach ($run in $runs) {
    Write-Host "Run ID: $($run.RunId)" -ForegroundColor Cyan
    Write-Host "Status: $($run.Status)" -ForegroundColor $(if ($run.Status -eq 'completed') { 'Green' } else { 'Yellow' })
    Write-Host "Conclusion: $($run.Conclusion)" -ForegroundColor $(if ($run.Conclusion -eq 'success') { 'Green' } elseif ($run.Conclusion -eq 'failure') { 'Red' } else { 'Yellow' })
    Write-Host "Created: $($run.CreatedAt)" -ForegroundColor Gray
    Write-Host "Workflow: $($run.Name)" -ForegroundColor Gray
    Write-Host "Branch: $($run.Branch)" -ForegroundColor Gray
    Write-Host ""
    
    if ($ShowFailures -and $run.Conclusion -eq 'failure') {
        Write-Host "=== Failures ===" -ForegroundColor Red
        gh run view $run.RunId --log-failed | Select-String -Pattern "FAIL|failed|error|Error" -Context 1,1 | Select-Object -First 50
        Write-Host ""
    }
    
    if ($ShowLogs) {
        Write-Host "=== Test Summary ===" -ForegroundColor Cyan
        gh run view $run.RunId --log | Select-String -Pattern "Total.*Passed|Total.*Failed|Summary|102-TestInstallerPlacement|105-TestReleasePackaging|106-TestReleasePackageContents" | Select-Object -Last 30
        Write-Host ""
    }
}

Write-Host "=== Quick Status ===" -ForegroundColor Cyan
$latest = $runs[0]
if ($latest.Conclusion -eq 'success') {
    Write-Host "✓ Latest pipeline: SUCCESS" -ForegroundColor Green
    exit 0
} elseif ($latest.Conclusion -eq 'failure') {
    Write-Host "✗ Latest pipeline: FAILURE" -ForegroundColor Red
    Write-Host "Run: gh run view $($latest.RunId) --log" -ForegroundColor Gray
    exit 1
} else {
    Write-Host "⏳ Latest pipeline: $($latest.Status)" -ForegroundColor Yellow
    exit 0
}

