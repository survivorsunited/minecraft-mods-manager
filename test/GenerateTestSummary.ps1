# Generate Test Summary Report for CI/CD Pipeline
param(
    [string]$OS = "unknown",
    [string]$OutputFile = "test-summary.md"
)

# Generate a comprehensive test summary
Write-Host "Generating test summary report..."

$testOutputDir = "test-output"

# Create summary header
$header = @"
# Test Suite Summary - $OS

**Run Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
**Operating System:** $OS
**PowerShell Version:** $($PSVersionTable.PSVersion)

## Test Results Overview

"@
$header | Out-File -FilePath $OutputFile -Encoding UTF8

# Find and process test log files
$logFiles = Get-ChildItem -Path $testOutputDir -Filter "test-run-*.log" -Recurse
if ($logFiles) {
    Write-Host "Found $($logFiles.Count) test log files"
    
    foreach ($logFile in $logFiles) {
        $logContent = Get-Content $logFile.FullName -Tail 50
        $testName = $logFile.Directory.Name
        
        $logSection = @"

### $testName
**Log File:** $($logFile.Name)

\`\`\`
$($logContent -join "`n")
\`\`\`

"@
        $logSection | Out-File -FilePath $OutputFile -Append -Encoding UTF8
    }
}

# Add test output directory structure
$structureSection = @"

## Test Output Structure

\`\`\`
$((Get-ChildItem -Path $testOutputDir -Recurse | Select-Object FullName, Length | Format-Table -AutoSize | Out-String))
\`\`\`

"@
$structureSection | Out-File -FilePath $OutputFile -Append -Encoding UTF8

Write-Host "Test summary report generated: $OutputFile" 