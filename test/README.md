# Minecraft Mod Manager Test Suite

This test suite validates all functionality of the Minecraft Mod Manager PowerShell script using temporary databases and compares results against expected baselines.

## Test Coverage

The test suite covers all major functionality mentioned in the main README:

### ✅ **Core Functionality Tests**
- **Basic Validation**: Tests mod validation and API response generation
- **Mod Addition**: Tests adding mods by URL, ID, and different types (mods, shaderpacks)
- **Mod Download**: Tests downloading mods to organized folders
- **Server Download**: Tests downloading Minecraft server JARs and Fabric launchers
- **Mod List Operations**: Tests mod list display and custom file parameters
- **Help and Documentation**: Tests help system and documentation completeness
- **CSV Structure**: Tests CSV format and required columns

### ✅ **Test Features**
- **Temporary Databases**: Uses isolated test files to avoid affecting production data
- **Baseline Comparison**: Compares test results against expected baseline
- **Comprehensive Reporting**: Detailed pass/fail reporting with explanations
- **Modular Testing**: Can run individual test categories or full suite
- **Clean Environment**: Automatically cleans up test artifacts

## Usage

### First Time Setup (Generate Baseline)

```powershell
# Generate the baseline expected results
.\test\run-tests.ps1 -GenerateBaseline
```

This will:
1. Run all tests with a minimal test modlist
2. Create the expected baseline file in `test/baseline/expected-modlist.csv`
3. This baseline becomes the "gold standard" for future comparisons

### Running Tests

```powershell
# Run all tests
.\test\run-tests.ps1

# Run specific test categories
.\test\run-tests.ps1 -TestName "basic"      # Basic validation only
.\test\run-tests.ps1 -TestName "addition"   # Mod addition only
.\test\run-tests.ps1 -TestName "download"   # Download functionality only
.\test\run-tests.ps1 -TestName "server"     # Server download only
.\test\run-tests.ps1 -TestName "operations" # Mod list operations only
.\test\run-tests.ps1 -TestName "help"       # Help system only
.\test\run-tests.ps1 -TestName "csv"        # CSV structure only
.\test\run-tests.ps1 -TestName "compare"    # Results comparison only

# Verbose output
.\test\run-tests.ps1 -Verbose
```

### Test Output

The test suite provides detailed output showing:

```
================================================================================
TEST: Basic Mod Validation
================================================================================
✓ PASS: Validation Execution
  Validation completed successfully
✓ PASS: API Response Files Created
  Found 3 API response files

================================================================================
TEST: Mod Addition Functionality
================================================================================
✓ PASS: Add Mod by URL
  Added Balm mod by URL
✓ PASS: Add Mod by ID
  Added FerriteCore by ID
✓ PASS: Add Shaderpack
  Added BSL Shaders
✓ PASS: Balm Mod in CSV
  Balm mod found in CSV
✓ PASS: FerriteCore in CSV
  FerriteCore found in CSV
✓ PASS: BSL Shaders in CSV
  BSL Shaders found in CSV

================================================================================
TEST SUMMARY
================================================================================
Total Tests: 25
Passed: 25
Failed: 0

🎉 ALL TESTS PASSED! 🎉
```

## Test Structure

```
test/
├── run-tests.ps1              # Main test script
├── README.md                  # This file
├── temp/                      # Temporary test files (auto-created)
│   └── test-modlist.csv      # Test modlist used during tests
├── baseline/                  # Expected results (auto-created)
│   └── expected-modlist.csv  # Baseline for comparison
└── results/                   # Actual test results (auto-created)
    └── actual-modlist.csv    # Results from current test run
```

## Test Database

The test suite uses a minimal test modlist with 3 initial mods:

1. **Fabric API** (required mod) - Core API for Fabric
2. **Sodium** (optional mod) - Performance optimization
3. **Complementary Reimagined** (optional shaderpack) - Shader pack

During testing, additional mods are added:
- **Balm** (via URL)
- **FerriteCore** (via ID)
- **BSL Shaders** (shaderpack via URL)

## What Each Test Validates

### Basic Validation
- ✅ ModManager script executes without errors
- ✅ API response files are generated
- ✅ Validation completes successfully

### Mod Addition
- ✅ Adding mods by Modrinth URL works
- ✅ Adding mods by ID works
- ✅ Adding shaderpacks works
- ✅ Mods are actually written to CSV file
- ✅ Correct metadata is populated

### Mod Download
- ✅ Download command executes successfully
- ✅ Download folder structure is created
- ✅ Mod JAR files are downloaded
- ✅ Files are organized by game version

### Server Download
- ✅ Server download command executes
- ✅ Minecraft server JARs are downloaded
- ✅ Fabric server launchers are downloaded

### Mod List Operations
- ✅ Get mod list command works
- ✅ Custom ModListFile parameter works
- ✅ Different CSV files can be used

### Help and Documentation
- ✅ Help system displays correctly
- ✅ All required help sections are present
- ✅ Usage examples are included
- ✅ Function documentation is complete

### CSV Structure
- ✅ All expected columns are present
- ✅ CSV contains test data
- ✅ Structure matches expected format

### Results Comparison
- ✅ Test results match baseline
- ✅ Expected mods are present
- ✅ Mod counts are correct

## Troubleshooting

### Test Failures

If tests fail, check:

1. **Network Connectivity**: Tests require internet access for API calls
2. **PowerShell Execution Policy**: Ensure scripts can run
3. **File Permissions**: Ensure write access to test folders
4. **ModManager Script**: Ensure main script is in correct location

### Regenerating Baseline

If you need to update the baseline (e.g., after script changes):

```powershell
.\test\run-tests.ps1 -GenerateBaseline
```

### Individual Test Debugging

To debug specific tests:

```powershell
# Run with verbose output
.\test\run-tests.ps1 -TestName "addition" -Verbose

# Check test files manually
Get-Content .\test\temp\test-modlist.csv
Get-Content .\test\baseline\expected-modlist.csv
```

## Integration with CI/CD

The test suite returns appropriate exit codes:
- **Exit 0**: All tests passed
- **Exit 1**: Some tests failed

This makes it suitable for integration with CI/CD pipelines.

## Adding New Tests

To add new tests:

1. Create a new test function in `run-tests.ps1`
2. Add it to the main test execution section
3. Update this README with test description
4. Regenerate baseline if needed

Example new test function:

```powershell
function Test-NewFeature {
    Write-TestHeader "New Feature Test"
    
    try {
        # Test implementation here
        $testPassed = $true
        Write-TestResult "New Feature" $testPassed "Feature works correctly"
        return $testPassed
    }
    catch {
        Write-TestResult "New Feature" $false "Exception: $($_.Exception.Message)"
        return $false
    }
}
``` 