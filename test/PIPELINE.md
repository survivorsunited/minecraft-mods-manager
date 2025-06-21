# Test Pipeline Documentation

## Overview

The test pipeline runs the complete test suite across multiple operating systems (Windows, Linux, macOS), captures comprehensive test artifacts for analysis and reporting, and creates GitHub releases on successful test completion.

## Pipeline Configuration

The pipeline is configured in `.github/workflows/test.yml` and includes:

### Test Execution
- **Matrix Strategy**: Runs tests on Windows, Linux, and macOS
- **PowerShell Setup**: Installs PowerShell on Linux and macOS
- **Test Suite**: Executes all tests using `RunAllTests.ps1 -All`
- **Release Creation**: Creates GitHub releases on successful main branch tests

### Artifact Collection

The pipeline captures the following artifacts:

#### 1. Test Logs (`test-logs-{os}`)
- All test execution logs
- Individual test log files
- Error logs and debug information

#### 2. Test Output Directories (`test-output-{os}`)
- Complete test output directories
- Download folders with mods and server files
- Test-specific output files

#### 3. Test Summary Reports (`test-summary-{os}`)
- Generated markdown summaries
- Test report files
- High-level test results

#### 4. Test Results Data (`test-results-{os}`)
- JSON format test results
- CSV format test data
- Markdown test reports

#### 5. Mod Download Results (`mod-download-results-{os}`)
- Mod download CSV files
- Updated modlist.csv files
- Download statistics

#### 6. Server Logs (`server-logs-{os}`)
- Server startup logs
- Server error logs
- Minecraft server logs

#### 7. Comprehensive Artifacts (`all-test-artifacts-{os}`)
- Complete test output
- All generated reports
- Full test environment state

## Release Creation

### Automatic Release Generation
On successful test completion on the main branch, the pipeline:

1. **Downloads all artifacts** from all operating systems
2. **Generates dynamic release notes** based on actual test results
3. **Creates a GitHub pre-release** with comprehensive test artifacts
4. **Attaches all test outputs** for download and analysis

### Release Notes Generation
The pipeline uses `GenerateReleaseNotes.ps1` to create dynamic release notes:

- **Test Summary**: Overall test results across all platforms
- **Platform Results**: Individual results for Windows, Linux, macOS
- **Compatibility Analysis**: Mod compatibility issues detected
- **Artifact Summary**: List of all attached test artifacts
- **System Information**: Test environment details

### Release Artifacts
Each release includes:
- **Test Logs**: Complete test execution logs from all platforms
- **Test Outputs**: Full test output directories with mods and server files
- **Test Reports**: Generated summaries and analysis reports
- **Server Logs**: Minecraft server startup and error logs
- **Mod Downloads**: Downloaded mod files and compatibility data

## Generated Scripts

### GenerateTestSummary.ps1
Creates a comprehensive markdown summary of test execution including:
- Test execution logs
- Test output structure
- System information

### GenerateTestResults.ps1
Generates detailed test results in multiple formats:
- **JSON**: Structured test data for programmatic analysis
- **CSV**: Tabular test results for spreadsheet analysis
- **Markdown**: Human-readable test reports

### GenerateReleaseNotes.ps1
Creates dynamic release notes based on actual test results:
- **Test Summary**: Overall success rates and test counts
- **Platform Analysis**: Results breakdown by operating system
- **Compatibility Issues**: Detected mod conflicts and errors
- **Artifact List**: Complete list of attached test artifacts

### CreateCompletionReport.ps1
Creates a simple completion report for pipeline notifications.

## Artifact Retention

All artifacts are retained for **30 days** to allow for:
- Post-test analysis
- Bug investigation
- Performance analysis
- Historical comparison

## Test Artifacts Structure

```
test/
├── test-output/                    # Main test output directory
│   ├── 01-BasicFunctionality/     # Individual test outputs
│   ├── 02-DownloadFunctionality/
│   ├── ...
│   └── 12-TestLatestWithServer/
│       ├── download/              # Downloaded mods and server files
│       │   └── 1.21.6/
│       │       ├── mods/          # Latest mods
│       │       ├── minecraft_server.1.21.6.jar
│       │       ├── fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar
│       │       ├── start-server.ps1
│       │       └── logs/          # Server startup logs
│       │           └── console-*.log
│       ├── *.log                  # Test execution logs
│       └── *-test-report.txt      # Test-specific reports
├── apiresponse/                   # API response cache
│   ├── mod-download-results.csv   # Download statistics
│   └── *.json                     # Cached API responses
└── output-*/                      # Legacy test outputs
```

## Pipeline Artifacts

After pipeline execution, the following artifacts are available:

1. **test-logs-{os}**: Raw test execution logs
2. **test-output-{os}**: Complete test output directories
3. **test-summary-{os}**: Generated summary reports
4. **test-results-{os}**: Structured test results (JSON/CSV)
5. **mod-download-results-{os}**: Mod download data
6. **server-logs-{os}**: Server startup and error logs
7. **all-test-artifacts-{os}**: Complete test environment

## Critical Test Analysis

### 12-TestLatestWithServer.ps1 Results
The pipeline specifically analyzes the critical compatibility test:

**Expected Results with Compatibility Issues:**
- Total Tests: 8
- Passed: 6 (validation, downloads, server files, start script, isolation check)
- Failed: 2 (server startup, compatibility analysis)
- Success Rate: 75%

**Compatibility Issues Detected:**
- Missing Fabric API dependencies
- Minecraft version mismatches
- Specific mods requiring removal or replacement

## Usage

### Running Tests Locally
```powershell
# Run all tests
.\test\RunAllTests.ps1 -All

# Run specific tests
.\test\RunAllTests.ps1 -TestFiles "01-BasicFunctionality.ps1","02-DownloadFunctionality.ps1"

# Run critical compatibility test
.\test\RunAllTests.ps1 -TestFiles "12-TestLatestWithServer.ps1"

# Generate test results
.\test\GenerateTestResults.ps1 -OS "Windows" -OutputDir "test-results"

# Generate release notes
.\test\GenerateReleaseNotes.ps1 -ArtifactsDir "artifacts" -OutputFile "release-notes.md"
```

### Pipeline Triggers
- **Push to main/develop**: Automatic test execution
- **Pull Request**: Automatic test execution
- **Manual**: Workflow dispatch for on-demand testing
- **Main Branch Success**: Automatic release creation

## Analysis

### Test Results Analysis
Use the generated JSON and CSV files for:
- Test success rate analysis
- Performance trending
- Failure pattern identification
- Mod compatibility analysis
- Cross-platform comparison

### Log Analysis
Review test logs for:
- Test execution details
- Error messages and stack traces
- Performance metrics
- System compatibility issues
- Server startup problems

### Artifact Investigation
Download artifacts to investigate:
- Downloaded mod files
- Server configuration
- Test environment state
- API response data
- Compatibility error details

### Release Analysis
Review release artifacts for:
- Cross-platform test consistency
- Mod compatibility trends
- Performance regression detection
- System-specific issues
- Comprehensive test coverage validation 