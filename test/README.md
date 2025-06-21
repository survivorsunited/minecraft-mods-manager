# Minecraft Mod Manager Test Suite

This test suite validates all functionality of the Minecraft Mod Manager PowerShell script with comprehensive testing, mod compatibility validation, and detailed error reporting.

## Test Coverage

The test suite covers all major functionality with 12 comprehensive test files:

### ✅ **Core Functionality Tests**
- **01-BasicFunctionality.ps1** - Core validation and API response generation
- **02-DownloadFunctionality.ps1** - Mod download and file organization
- **03-SystemEntries.ps1** - System mod validation and management
- **04-FilenameHandling.ps1** - File naming and organization patterns
- **05-ValidationTests.ps1** - Mod validation workflows and error handling
- **06-ModpackTests.ps1** - Modpack functionality and processing

### ✅ **Server and Compatibility Tests**
- **07-StartServerTests.ps1** - Server startup and management
- **08-StartServerUnitTests.ps1** - Server unit tests and edge cases
- **09-TestCurrent.ps1** - Current mod version workflows
- **10-TestLatest.ps1** - Latest mod version workflows
- **11-ParameterValidation.ps1** - Parameter validation and error handling
- **12-TestLatestWithServer.ps1** - **CRITICAL**: Latest mods with server compatibility testing

### ✅ **Test Features**
- **Isolated Test Environment**: Each test runs in isolated directories
- **API Response Caching**: Faster testing with cached API responses
- **Comprehensive Reporting**: Detailed pass/fail reporting with explanations
- **Modular Testing**: Can run individual test files or full suite
- **Compatibility Error Detection**: Automated detection of mod conflicts
- **Server Log Analysis**: Detailed analysis of server startup issues

## Usage

### Quick Test Commands

```powershell
# Run all tests
.\test\RunAllTests.ps1 -All

# Run specific test
.\test\RunAllTests.ps1 -TestFiles "12-TestLatestWithServer.ps1"

# Run multiple specific tests
.\test\RunAllTests.ps1 -TestFiles "01-BasicFunctionality.ps1","02-DownloadFunctionality.ps1"

# Run with cleanup
.\test\RunAllTests.ps1 -All -Cleanup

# Show help
.\test\RunAllTests.ps1 -Help
```

### Test Output

The test suite provides detailed output showing:

```
2025-06-22 01:48:11 - 🚀 Running test file: 12-TestLatestWithServer.ps1
2025-06-22 01:48:11 - ────────────────────────────────────────────────────────────
2025-06-22 01:48:22 - ✅ Completed: 12-TestLatestWithServer.ps1
2025-06-22 01:48:22 -    Passed: 6, Failed: 2, Total: 8

2025-06-22 01:48:22 - === Final Test Summary ===
2025-06-22 01:48:22 - Total Tests: 123
2025-06-22 01:48:22 - Passed: 121
2025-06-22 01:48:22 - Failed: 2
2025-06-22 01:48:22 - Success Rate: 98.4%
```

## Test Structure

```
test/
├── RunAllTests.ps1            # Main test runner
├── TestFramework.ps1          # Shared test utilities
├── README.md                  # This file
├── tests/                     # Individual test files
│   ├── 01-BasicFunctionality.ps1
│   ├── 02-DownloadFunctionality.ps1
│   ├── 03-SystemEntries.ps1
│   ├── 04-FilenameHandling.ps1
│   ├── 05-ValidationTests.ps1
│   ├── 06-ModpackTests.ps1
│   ├── 07-StartServerTests.ps1
│   ├── 08-StartServerUnitTests.ps1
│   ├── 09-TestCurrent.ps1
│   ├── 10-TestLatest.ps1
│   ├── 11-ParameterValidation.ps1
│   └── 12-TestLatestWithServer.ps1
├── test-output/               # Test execution outputs
│   ├── 01-BasicFunctionality/
│   ├── 02-DownloadFunctionality/
│   ├── 03-SystemEntries/
│   ├── 04-FilenameHandling/
│   ├── 05-ValidationTests/
│   ├── 06-ModpackTests/
│   ├── 07-StartServerTests/
│   ├── 08-StartServerUnitTests/
│   ├── 09-TestCurrent/
│   ├── 10-TestLatest/
│   ├── 11-ParameterValidation/
│   └── 12-TestLatestWithServer/
└── apiresponse/               # Cached API responses for testing
```

## Critical Test: Mod Compatibility Validation

### 12-TestLatestWithServer.ps1

This is the **most critical test** for validating mod compatibility:

**What it does:**
1. Validates all mods in the database
2. Updates mods to latest versions
3. Downloads latest mods and server files
4. Attempts server startup
5. Analyzes server logs for compatibility issues
6. Reports specific errors that need fixing

**Expected Results with Compatibility Issues:**
- Total Tests: 8
- Passed: 6 (validation, downloads, server files, start script, isolation check)
- Failed: 2 (server startup, compatibility analysis)
- Success Rate: 75%

**Common Compatibility Issues Detected:**
- Missing Fabric API dependencies
- Minecraft version mismatches (mods built for 1.21.5 running on 1.21.6)
- Specific mods that need removal or replacement

### Test Output Structure

```
test/test-output/12-TestLatestWithServer/
├── download/                    # Downloaded mods and server files
│   └── 1.21.6/
│       ├── mods/               # Latest mods
│       ├── minecraft_server.1.21.6.jar
│       ├── fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar
│       ├── start-server.ps1
│       └── logs/               # Server startup logs
│           └── console-*.log   # Server console output
├── latest-with-server-test-report.txt  # Test results report
├── Mod_Compatibility_Analysis.log      # Compatibility analysis
├── Server_Startup_with_Latest_Mods.log # Server startup test
├── Download_Everything.log             # Download test
├── Update_Mods_to_Latest.log           # Update test
└── Validate_All_Mods.log               # Validation test
```

## What Each Test Validates

### Basic Functionality (01-BasicFunctionality.ps1)
- ✅ ModManager script executes without errors
- ✅ API response files are generated
- ✅ Validation completes successfully
- ✅ Help system displays correctly

### Download Functionality (02-DownloadFunctionality.ps1)
- ✅ Download command executes successfully
- ✅ Download folder structure is created
- ✅ Mod JAR files are downloaded
- ✅ Files are organized by game version

### System Entries (03-SystemEntries.ps1)
- ✅ System mod validation and management
- ✅ Required vs optional mod handling
- ✅ Mod group organization

### Filename Handling (04-FilenameHandling.ps1)
- ✅ File naming patterns and organization
- ✅ Special character handling
- ✅ Path validation

### Validation Tests (05-ValidationTests.ps1)
- ✅ Mod validation workflows
- ✅ Error handling and reporting
- ✅ API response processing

### Modpack Tests (06-ModpackTests.ps1)
- ✅ Modpack functionality and processing
- ✅ Modpack file handling
- ✅ Modpack validation

### Server Tests (07-StartServerTests.ps1, 08-StartServerUnitTests.ps1)
- ✅ Server startup and management
- ✅ Server configuration validation
- ✅ Server log monitoring
- ✅ Error detection and reporting

### Current/Latest Tests (09-TestCurrent.ps1, 10-TestLatest.ps1)
- ✅ Current mod version workflows
- ✅ Latest mod version workflows
- ✅ Version comparison and updates

### Parameter Validation (11-ParameterValidation.ps1)
- ✅ Parameter validation and error handling
- ✅ Invalid parameter detection
- ✅ Help system validation

### Latest with Server (12-TestLatestWithServer.ps1)
- ✅ Complete workflow validation
- ✅ Mod compatibility testing
- ✅ Server startup with latest mods
- ✅ Compatibility error detection and reporting

## Troubleshooting

### Test Failures

If tests fail, check:

1. **Network Connectivity**: Tests require internet access for API calls
2. **PowerShell Execution Policy**: Ensure scripts can run
3. **File Permissions**: Ensure write access to test folders
4. **ModManager Script**: Ensure main script is in correct location

### Compatibility Issues

If the 12-TestLatestWithServer test fails:

1. **Check server logs**: Review `test/test-output/12-TestLatestWithServer/download/1.21.6/logs/console-*.log`
2. **Review compatibility analysis**: Check `Mod_Compatibility_Analysis.log`
3. **Fix identified issues**: Address missing dependencies or version mismatches
4. **Update modlist.csv**: Remove incompatible mods or update versions

### Individual Test Debugging

To debug specific tests:

```powershell
# Run with verbose output
.\test\RunAllTests.ps1 -TestFiles "12-TestLatestWithServer.ps1"

# Check test output manually
Get-Content .\test\test-output\12-TestLatestWithServer\latest-with-server-test-report.txt
Get-Content .\test\test-output\12-TestLatestWithServer\Mod_Compatibility_Analysis.log
```

### Test Result Capture Issues

If tests show "No test results captured":

1. **Check script-level variables**: Ensure `$script:TestResults` is properly initialized
2. **Verify test function execution**: Ensure test functions are called when files are run
3. **Review test patterns**: Check that test patterns match what the runner expects

## CI/CD Integration

The test suite integrates with GitHub Actions for automated testing:

- **Cross-platform testing**: Windows, Linux, macOS
- **Automated artifact collection**: Test logs and reports
- **Comprehensive reporting**: Detailed test summaries
- **Release integration**: Automatic release creation on successful tests 