# Generate Comprehensive Test Results for CI/CD Pipeline
param(
    [string]$OutputDir = "test-results",
    [string]$OS = "unknown"
)

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$testOutputDir = "test-output"
$results = @{
    OS = $OS
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    TestResults = @()
    Summary = @{
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SuccessRate = 0
    }
}

# Process test output directories
$testDirs = Get-ChildItem -Path $testOutputDir -Directory
foreach ($testDir in $testDirs) {
    $testResult = @{
        TestName = $testDir.Name
        LogFiles = @()
        ReportFiles = @()
        DownloadFolders = @()
        Status = "Unknown"
    }
    
    # Find log files
    $logFiles = Get-ChildItem -Path $testDir.FullName -Filter "*.log" -Recurse
    foreach ($logFile in $logFiles) {
        $testResult.LogFiles += @{
            Name = $logFile.Name
            Path = $logFile.FullName
            Size = $logFile.Length
        }
    }
    
    # Find report files
    $reportFiles = Get-ChildItem -Path $testDir.FullName -Filter "*test-report.txt" -Recurse
    foreach ($reportFile in $reportFiles) {
        $testResult.ReportFiles += @{
            Name = $reportFile.Name
            Path = $reportFile.FullName
            Size = $reportFile.Length
        }
    }
    
    # Find download folders
    $downloadFolders = Get-ChildItem -Path $testDir.FullName -Directory | Where-Object { $_.Name -match "download" }
    foreach ($downloadFolder in $downloadFolders) {
        $testResult.DownloadFolders += @{
            Name = $downloadFolder.Name
            Path = $downloadFolder.FullName
            ModCount = (Get-ChildItem -Path $downloadFolder.FullName -Filter "*.jar" -Recurse).Count
        }
    }
    
    # Determine test status from log files
    $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestLog) {
        $logContent = Get-Content $latestLog.FullName -Tail 20
        if ($logContent -match "All.*tests passed") {
            $testResult.Status = "Passed"
            $results.Summary.PassedTests++
        } elseif ($logContent -match "Some.*tests failed") {
            $testResult.Status = "Failed"
            $results.Summary.FailedTests++
        } else {
            $testResult.Status = "Unknown"
        }
    }
    
    $results.Summary.TotalTests++
    $results.TestResults += $testResult
}

# Calculate success rate
if ($results.Summary.TotalTests -gt 0) {
    $results.Summary.SuccessRate = [math]::Round(($results.Summary.PassedTests / $results.Summary.TotalTests) * 100, 2)
}

# Generate JSON report
$jsonFile = Join-Path $OutputDir "test-results-$OS.json"
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8

# Generate CSV report
$csvFile = Join-Path $OutputDir "test-results-$OS.csv"
$csvData = $results.TestResults | ForEach-Object {
    [PSCustomObject]@{
        TestName = $_.TestName
        Status = $_.Status
        LogFileCount = $_.LogFiles.Count
        ReportFileCount = $_.ReportFiles.Count
        DownloadFolderCount = $_.DownloadFolders.Count
        TotalMods = ($_.DownloadFolders | Measure-Object -Property ModCount -Sum).Sum
    }
}
$csvData | Export-Csv -Path $csvFile -NoTypeInformation

# Generate markdown report
$mdFile = Join-Path $OutputDir "test-results-$OS.md"
$mdContent = @"
# Test Results Summary - $OS

**Generated:** $($results.Timestamp)
**PowerShell Version:** $($results.PowerShellVersion)

## Overall Summary

- **Total Tests:** $($results.Summary.TotalTests)
- **Passed:** $($results.Summary.PassedTests)
- **Failed:** $($results.Summary.FailedTests)
- **Success Rate:** $($results.Summary.SuccessRate)%

## Test Details

"@

foreach ($testResult in $results.TestResults) {
    $mdContent += @"

### $($testResult.TestName)
- **Status:** $($testResult.Status)
- **Log Files:** $($testResult.LogFiles.Count)
- **Report Files:** $($testResult.ReportFiles.Count)
- **Download Folders:** $($testResult.DownloadFolders.Count)
- **Total Mods:** $(($testResult.DownloadFolders | Measure-Object -Property ModCount -Sum).Sum)

"@
}

$mdContent | Out-File -FilePath $mdFile -Encoding UTF8

Write-Host "Test results generated:"
Write-Host "  JSON: $jsonFile"
Write-Host "  CSV: $csvFile"
Write-Host "  Markdown: $mdFile"
Write-Host "  Summary: $($results.Summary.PassedTests)/$($results.Summary.TotalTests) tests passed ($($results.Summary.SuccessRate)%)" 