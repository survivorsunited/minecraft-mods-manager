# ModManager CLI Test Suite

This directory contains the organized test suite for the ModManager PowerShell script. The tests are split into logical groups for better organization and maintainability.

## Test Structure

### Test Framework (`../TestFramework.ps1`)
Shared framework containing common functions and configuration used across all test files:
- Test result tracking and reporting
- Database state validation
- Command execution and validation
- Environment setup and cleanup
- Color-coded output formatting
- Individual test output folders

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

## Running Tests

### Main Test Runner (`../RunAllTests.ps1`)

The main test runner provides flexible options for executing tests:

```powershell
# From the test folder
cd test
.\RunAllTests.ps1 -All

# Run specific test files
.\RunAllTests.ps1 -TestFiles '01-BasicFunctionality.ps1'
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

# Run system entries tests
.\03-SystemEntries.ps1
```

## Test Output Organization

Each test file creates its own output folder in the test directory:
- `output-01-BasicFunctionality/` - Outputs for basic functionality tests
- `output-02-DownloadFunctionality/` - Outputs for download tests
- `output-03-SystemEntries/` - Outputs for system entries tests
- `output-04-FilenameHandling/` - Outputs for filename handling tests
- `output-05-ValidationTests/` - Outputs for validation tests

Each output folder contains:
- Downloaded mods and files
- Database files
- Log files
- Any other test artifacts

## Test Dependencies

- **API Response Files**: Tests use cached API responses from `../apiresponse/` to avoid network calls
- **Database Files**: Each test file creates its own test database (`run-test-cli.csv`)
- **Download Directory**: Tests create files in their individual output folders

## Test Results

Tests provide detailed output with:
- Color-coded pass/fail indicators
- Test counts and summaries
- Detailed error messages
- File existence verification
- Database state validation

## Adding New Tests

To add new tests:

1. **Create a new test file** following the naming convention: `XX-Description.ps1`
2. **Import the test framework** at the top: `. "..\TestFramework.ps1"`
3. **Use the provided functions**:
   - `Write-TestHeader` for test section headers
   - `Test-Command` for command execution and validation
   - `Test-DatabaseState` for database validation
   - `Write-TestResult` for custom test results
4. **Update the main runner** to include your new test file (automatic with dynamic discovery)

## Test Best Practices

1. **Independent Tests**: Each test file should be able to run independently
2. **Clean State**: Use `Initialize-TestEnvironment -TestFileName $TestFileName` to ensure a clean starting state
3. **Validation**: Always validate expected outcomes (file counts, database state, etc.)
4. **Error Handling**: Use try-catch blocks for robust error handling
5. **Documentation**: Include clear comments explaining what each test validates
6. **Output Isolation**: Each test file gets its own output folder to prevent conflicts

## Troubleshooting

### Common Issues

1. **Path Issues**: Ensure you're running tests from the correct directory
2. **API Cache**: Verify API response files exist in `../apiresponse/`
3. **Permissions**: Ensure PowerShell has write permissions for creating test files
4. **Network**: Some tests may require internet access for live API calls

### Debug Mode

To run tests with more verbose output, you can modify the `Test-Command` function in `../TestFramework.ps1` to include additional logging. 