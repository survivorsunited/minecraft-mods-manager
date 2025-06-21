# Standardized Test Logging Pattern

All tests should use the standardized logging pattern from `TestFramework.ps1` to ensure console output is captured and saved.

## Pattern for Test Files

### 1. Import TestFramework and Initialize Environment

```powershell
# Import test framework
$TestFrameworkPath = Join-Path $PSScriptRoot "..\TestFramework.ps1"
. $TestFrameworkPath

# Test configuration
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\{TestName}"
$TestDownloadDir = Join-Path $TestOutputDir "download"

# Initialize test environment with logging (auto-detects test name)
Initialize-TestEnvironment
```

### 2. Test Functions

Use the existing test functions from TestFramework.ps1. Individual test logs are automatically saved to:
- `test-output/{TestName}/{TestName}.log` - Main console log
- `test-output/{TestName}/{Individual_Test_Name}.log` - Individual test logs

### 3. Cleanup at End

```powershell
# Cleanup test environment (stops logging)
Cleanup-TestEnvironment
```

## Log File Locations

- **Main Console Log**: `test-output/{TestName}.log`
- **Individual Test Logs**: `test-output/{TestName}/{Individual_Test_Name}.log`
- **Test Reports**: `test-output/{TestName}/{TestName}-test-report.txt`

## Automatic Test Name Detection

The `Initialize-TestEnvironment` function automatically detects the test name from the calling script filename. No need to manually specify the test name!

## Example Implementation

See `test/tests/12-TestLatestWithServer.ps1` for a complete example of the standardized logging pattern.

## Benefits

1. **No Lost Output**: All console output is captured and saved
2. **Consistent Structure**: All tests follow the same logging pattern
3. **Easy Debugging**: Logs are organized and easy to find
4. **CI/CD Friendly**: Logs are saved in predictable locations for pipeline analysis
5. **Automatic**: Test names are auto-detected, no manual configuration needed 