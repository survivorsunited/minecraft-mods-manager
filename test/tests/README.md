# ModManager CLI Test Suite

This directory contains the comprehensive test suite for the ModManager PowerShell script. The tests are organized into 12 logical test files covering all functionality with isolated testing environments and compatibility error detection.

## Test Structure

### Test Framework (`../TestFramework.ps1`)
Shared framework containing common functions and configuration used across all test files:
- Test result tracking and reporting
- Database state validation
- Command execution and validation
- Environment setup and cleanup
- Color-coded output formatting
- Individual test output folders
- Isolated download directories
- Compatibility error detection

### Individual Test Files

#### 01-BasicFunctionality.ps1
Tests core ModManager functionality:
- Help command display
- Adding mods by URL and ID
- Adding shaderpacks and CurseForge mods
- Adding mods to specific groups
- Mod validation and listing
- Mod deletion
- Auto-download functionality
- Custom database file usage

#### 02-DownloadFunctionality.ps1
Tests download-related functionality:
- Basic mod downloads
- Downloads with validation
- Server file downloads
- Duplicate download prevention
- Legacy download behavior
- Isolated download directories

#### 03-SystemEntries.ps1
Tests system entry management:
- Adding installers, launchers, and server files
- Multiple game version support
- UseLatestVersion functionality
- Missing system file detection
- System entry filename handling

#### 04-FilenameHandling.ps1
Tests filename-related functionality:
- Shaderpack filename cleaning
- System entry filename handling
- Downloaded file name verification
- External modification detection
- File extension handling (.exe vs .jar)

#### 05-ValidationTests.ps1
Tests validation and file existence:
- System entry download validation
- Mod file existence verification
- File structure validation
- Download path verification
- API response validation

#### 06-ModpackTests.ps1
Tests modpack functionality:
- Modpack download and extraction
- Modpack file handling
- Modpack validation
- Modpack integration

#### 07-StartServerTests.ps1
Tests server startup functionality:
- Server startup process
- Server configuration validation
- Server log monitoring
- Error detection and reporting
- Server file management

#### 08-StartServerUnitTests.ps1
Tests server unit functionality:
- Detailed server startup unit tests
- Server edge cases
- Server error handling
- Server configuration validation

#### 09-TestCurrent.ps1
Tests current mod version workflows:
- Current mod version downloads
- Current version validation
- Current version server testing
- Current version compatibility

#### 10-TestLatest.ps1
Tests latest mod version workflows:
- Latest mod version downloads
- Latest version validation
- Latest version updates
- Latest version compatibility

#### 11-ParameterValidation.ps1
Tests parameter validation:
- Invalid parameter detection
- Parameter error handling
- Help system validation
- Parameter combinations

#### 12-TestLatestWithServer.ps1
**CRITICAL**: Tests latest mods with server compatibility:
- Complete workflow validation
- Latest mod downloads
- Server file downloads
- Server startup with latest mods
- **Compatibility error detection and reporting**
- **Mod conflict identification**
- **Server log analysis**

## Running Tests

### Main Test Runner (`../RunAllTests.ps1`)

The main test runner provides flexible options for executing tests:

```powershell
# From the test folder
cd test
.\RunAllTests.ps1 -All

# Run specific test files
.\RunAllTests.ps1 -TestFiles '12-TestLatestWithServer.ps1'
.\RunAllTests.ps1 -TestFiles '01-BasicFunctionality.ps1','02-DownloadFunctionality.ps1'

# Run with cleanup after completion
.\RunAllTests.ps1 -All -Cleanup

# Show help
.\RunAllTests.ps1 -Help
```

### Running Individual Test Files

You can also run individual test files directly from the tests folder:

```powershell
# From the tests folder
cd test/tests

# Run basic functionality tests
.\01-BasicFunctionality.ps1

# Run download tests
.\02-DownloadFunctionality.ps1

# Run critical compatibility test
.\12-TestLatestWithServer.ps1
```

## Test Output Organization

Each test file creates its own output folder in `../test-output/`:
- `../test-output/01-BasicFunctionality/` - Outputs for basic functionality tests
- `../test-output/02-DownloadFunctionality/` - Outputs for download tests
- `../test-output/03-SystemEntries/` - Outputs for system entries tests
- `../test-output/04-FilenameHandling/` - Outputs for filename handling tests
- `../test-output/05-ValidationTests/` - Outputs for validation tests
- `../test-output/06-ModpackTests/` - Outputs for modpack tests
- `../test-output/07-StartServerTests/` - Outputs for server tests
- `../test-output/08-StartServerUnitTests/` - Outputs for server unit tests
- `../test-output/09-TestCurrent/` - Outputs for current version tests
- `../test-output/10-TestLatest/` - Outputs for latest version tests
- `../test-output/11-ParameterValidation/` - Outputs for parameter validation tests
- `../test-output/12-TestLatestWithServer/` - Outputs for compatibility tests

Each output folder contains:
- Downloaded mods and files in isolated `download/` subfolder
- Test logs and reports
- Server logs (for server tests)
- Database files
- Any other test artifacts

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
../test-output/12-TestLatestWithServer/
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

## Test Dependencies

- **API Response Files**: Tests use cached API responses from `../apiresponse/` to avoid network calls
- **Database Files**: Each test file uses the main `modlist.csv` database
- **Download Directory**: Tests create files in their individual output folders with isolated `download/` subfolders
- **Test Isolation**: Each test runs in complete isolation to prevent interference

## Test Results

Tests provide detailed output with:
- Color-coded pass/fail indicators
- Test counts and summaries
- Detailed error messages
- File existence verification
- Database state validation
- Compatibility error reporting
- Server log analysis

## Adding New Tests

To add new tests:

1. **Create a new test file** following the naming convention: `XX-Description.ps1`
2. **Import the test framework** at the top: `. "..\TestFramework.ps1"`
3. **Use the provided functions**:
   - `Write-TestHeader` for test section headers
   - `Test-Command` for command execution and validation
   - `Test-DatabaseState` for database validation
   - `Write-TestResult` for custom test results
   - `Initialize-TestEnvironment` for isolated test setup
4. **Update the main runner** to include your new test file (automatic with dynamic discovery)

## Test Best Practices

1. **Independent Tests**: Each test file should be able to run independently
2. **Clean State**: Use `Initialize-TestEnvironment -TestFileName $TestFileName` to ensure a clean starting state
3. **Validation**: Always validate expected outcomes (file counts, database state, etc.)
4. **Error Handling**: Use try-catch blocks for robust error handling
5. **Documentation**: Include clear comments explaining what each test validates
6. **Output Isolation**: Each test file gets its own output folder to prevent conflicts
7. **Download Isolation**: Use isolated download directories to prevent interference with main download folder
8. **Compatibility Testing**: Include compatibility error detection for server tests

## Troubleshooting

### Common Issues

1. **Path Issues**: Ensure you're running tests from the correct directory
2. **API Cache**: Verify API response files exist in `../apiresponse/`
3. **Permissions**: Ensure PowerShell has write permissions for creating test files
4. **Network**: Some tests may require internet access for live API calls
5. **Test Isolation**: Ensure tests don't interfere with each other or the main download folder

### Compatibility Issues

If the 12-TestLatestWithServer test fails:

1. **Check server logs**: Review `../test-output/12-TestLatestWithServer/download/1.21.6/logs/console-*.log`
2. **Review compatibility analysis**: Check `Mod_Compatibility_Analysis.log`
3. **Fix identified issues**: Address missing dependencies or version mismatches
4. **Update modlist.csv**: Remove incompatible mods or update versions

### Debug Mode

To run tests with more verbose output, you can modify the `Test-Command` function in `../TestFramework.ps1` to include additional logging.

### Test Result Capture Issues

If tests show "No test results captured":

1. **Check script-level variables**: Ensure `$script:TestResults` is properly initialized
2. **Verify test function execution**: Ensure test functions are called when files are run
3. **Review test patterns**: Check that test patterns match what the runner expects 