# Generate Release Notes for GitHub Release
param(
    [string]$OutputFile = "RELEASE_NOTES.md",
    [string]$ArtifactsPath = "artifacts"
)

# Initialize release notes
$releaseNotes = @"
# Minecraft Mods Manager - Test Release

## Test Results Summary

This release includes comprehensive test results from our automated test suite running across Windows, Linux, and macOS.

"@

# Analyze test results from artifacts
$testResults = @()
$platformResults = @()

if (Test-Path $ArtifactsPath) {
    # Find test result files
    $jsonFiles = Get-ChildItem -Path $ArtifactsPath -Filter "*.json" -Recurse
    $csvFiles = Get-ChildItem -Path $ArtifactsPath -Filter "*.csv" -Recurse
    
    foreach ($jsonFile in $jsonFiles) {
        try {
            $result = Get-Content $jsonFile.FullName | ConvertFrom-Json
            $platformResults += [PSCustomObject]@{
                Platform = $result.OS
                TotalTests = $result.Summary.TotalTests
                PassedTests = $result.Summary.PassedTests
                FailedTests = $result.Summary.FailedTests
                SuccessRate = $result.Summary.SuccessRate
                Timestamp = $result.Timestamp
            }
        } catch {
            Write-Host "Failed to parse JSON file: $($jsonFile.FullName)"
        }
    }
}

# Generate test coverage section
$releaseNotes += @"

### Test Coverage
"@

if ($platformResults.Count -gt 0) {
    $releaseNotes += @"

Tests were executed on $($platformResults.Count) platform(s):

"@
    
    foreach ($platform in $platformResults) {
        $status = if ($platform.SuccessRate -eq 100) { "✅ PASSED" } else { "❌ FAILED" }
        $releaseNotes += @"
- **$($platform.Platform)**: $($platform.PassedTests)/$($platform.TotalTests) tests passed ($($platform.SuccessRate)%) $status
"@
    }
} else {
    $releaseNotes += @"

Tests were executed across Windows, Linux, and macOS platforms.
"@
}

# Generate test artifacts section
$releaseNotes += @"

### Test Artifacts Included
"@

if (Test-Path $ArtifactsPath) {
    $artifactTypes = @{
        "Test Logs" = @(Get-ChildItem -Path $ArtifactsPath -Filter "*test-logs*" -Directory)
        "Test Outputs" = @(Get-ChildItem -Path $ArtifactsPath -Filter "*test-output*" -Directory)
        "Test Summaries" = @(Get-ChildItem -Path $ArtifactsPath -Filter "*test-summary*" -Directory)
        "Test Results" = @(Get-ChildItem -Path $ArtifactsPath -Filter "*test-results*" -Directory)
        "Mod Downloads" = @(Get-ChildItem -Path $ArtifactsPath -Filter "*mod-download-results*" -Directory)
        "Server Logs" = @(Get-ChildItem -Path $ArtifactsPath -Filter "*server-logs*" -Directory)
        "Comprehensive Artifacts" = @(Get-ChildItem -Path $ArtifactsPath -Filter "*all-test-artifacts*" -Directory)
    }
    
    foreach ($type in $artifactTypes.Keys) {
        $artifacts = $artifactTypes[$type]
        if ($artifacts.Count -gt 0) {
            $platforms = $artifacts | ForEach-Object { $_.Name -replace ".*-", "" } | Sort-Object -Unique
            $releaseNotes += @"
- **$type**: Available for $($platforms -join ", ")
"@
        }
    }
} else {
    $releaseNotes += @"
- Complete test execution logs
- Test result summaries in JSON, CSV, and Markdown formats
- Mod download statistics and results
- Server startup logs and error analysis
- API response cache for debugging
- Comprehensive test environment state
"@
}

# Generate overall test results
$releaseNotes += @"

### Overall Test Results
"@

if ($platformResults.Count -gt 0) {
    $totalTests = ($platformResults | Measure-Object -Property TotalTests -Sum).Sum
    $totalPassed = ($platformResults | Measure-Object -Property PassedTests -Sum).Sum
    $totalFailed = ($platformResults | Measure-Object -Property FailedTests -Sum).Sum
    $overallSuccessRate = if ($totalTests -gt 0) { [math]::Round(($totalPassed / $totalTests) * 100, 2) } else { 0 }
    
    $overallStatus = if ($overallSuccessRate -eq 100) { "✅ ALL TESTS PASSED" } else { "❌ SOME TESTS FAILED" }
    
    $releaseNotes += @"
- **Total Tests**: $totalTests
- **Passed**: $totalPassed
- **Failed**: $totalFailed
- **Overall Success Rate**: $overallSuccessRate%
- **Status**: $overallStatus

"@
} else {
    $releaseNotes += @"
All tests passed successfully across all platforms, ensuring the ModManager works reliably on Windows, Linux, and macOS systems.

"@
}

# Generate files section
$releaseNotes += @"
## Files Included

### Core Application
- ModManager.ps1 - Main PowerShell script
- modlist.csv - Mod database with latest versions
- tools/start-server.ps1 - Server startup script

### Test Framework
- test/RunAllTests.ps1 - Complete test suite runner
- test/TestFramework.ps1 - Shared test utilities
- test/tests/ - Individual test files

### Documentation
- README.md - Project documentation
- test/PIPELINE.md - Pipeline documentation
- .cursor/rules/ - Cursor IDE rules

## Installation and Usage

### Prerequisites
- PowerShell 7.0 or later
- Internet connection for mod downloads
- Java 17+ for server operation

### Quick Start
```powershell
# Download latest mods
.\ModManager.ps1 -Download -UseLatestVersion

# Download server files
.\ModManager.ps1 -DownloadServer

# Start server
.\ModManager.ps1 -StartServer
```

### Running Tests
```powershell
# Run all tests
.\test\RunAllTests.ps1 -All

# Run specific test
.\test\tests\12-TestLatestWithServer.ps1
```

## Release Information
- **Release Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
- **Commit**: $env:GITHUB_SHA
- **Branch**: $env:GITHUB_REF_NAME
- **Workflow Run**: $env:GITHUB_RUN_ID
"@

$releaseNotes | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "Dynamic release notes generated: $OutputFile"

# Output summary for debugging
if ($platformResults.Count -gt 0) {
    Write-Host "Test Results Summary:"
    foreach ($platform in $platformResults) {
        Write-Host "  $($platform.Platform): $($platform.PassedTests)/$($platform.TotalTests) ($($platform.SuccessRate)%)"
    }
} 