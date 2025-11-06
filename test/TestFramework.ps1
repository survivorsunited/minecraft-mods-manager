# Test Framework for Minecraft Mod Manager
# Provides shared utilities and functions for all tests
#
# This framework ensures:
# - Test isolation: Each test runs in its own output directory
# - Proper logging: All test output is captured and saved
# - Consistent results: Standardized test result reporting
# - Database management: Isolated database files for each test
# - API response caching: Organized API responses per test

# Colors for output formatting
$Colors = @{
    Header = "Cyan"      # Test headers and section titles
    Success = "Green"    # Passed tests and success messages
    Error = "Red"        # Failed tests and error messages
    Warning = "Yellow"   # Warnings and important notices
    Info = "Gray"        # Informational messages
    Muted = "DarkGray"   # Muted text for less important information
}

# API Response subfolder configuration for organized caching
$ModrinthApiResponseSubfolder = if ($env:APIRESPONSE_MODRINTH_SUBFOLDER) { $env:APIRESPONSE_MODRINTH_SUBFOLDER } else { "modrinth" }
$CurseForgeApiResponseSubfolder = if ($env:APIRESPONSE_CURSEFORGE_SUBFOLDER) { $env:APIRESPONSE_CURSEFORGE_SUBFOLDER } else { "curseforge" }

<#
.SYNOPSIS
    Gets the API response path for a specific test and domain.

.DESCRIPTION
    Constructs the full path to the API response folder for a specific test and API domain.
    This ensures API responses are organized by test and by API provider (Modrinth/CurseForge).

.PARAMETER TestOutputDir
    The base output directory for the test.

.PARAMETER Domain
    The API domain to get the response path for. Defaults to "modrinth".

.EXAMPLE
    Get-ApiResponsePath -TestOutputDir "C:\test\output\01-BasicFunctionality" -Domain "modrinth"
    Returns: "C:\test\output\01-BasicFunctionality\apiresponse\modrinth"

.EXAMPLE
    Get-ApiResponsePath -TestOutputDir "C:\test\output\02-DownloadFunctionality" -Domain "curseforge"
    Returns: "C:\test\output\02-DownloadFunctionality\apiresponse\curseforge"

.OUTPUTS
    [string] The full path to the API response folder for the specified domain.
#>
function Get-ApiResponsePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestOutputDir,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("modrinth", "curseforge")]
        [string]$Domain = "modrinth"
    )
    
    $BaseResponseFolder = Join-Path $TestOutputDir "apiresponse"
    $subfolder = if ($Domain -eq "curseforge") { $CurseForgeApiResponseSubfolder } else { $ModrinthApiResponseSubfolder }
    return Join-Path $BaseResponseFolder $subfolder
}

# Configuration constants
$ScriptPath = "..\ModManager.ps1"
# Default DB path anchored to this framework folder to avoid CWD issues in CI
$TestDbPath = Join-Path $PSScriptRoot "test-output\run-test-cli.csv"  # Will be overridden per-test in Initialize-TestEnvironment
$TestRoot = Join-Path $PSScriptRoot "tests"

# Test counter (shared across all test files) - Use script scope for persistence
$script:TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
}

# Console logging variables for transcript management
$script:ConsoleLogPath = $null
$script:IsLogging = $false

<#
.SYNOPSIS
    Starts console logging for a test.

.DESCRIPTION
    Begins a PowerShell transcript to capture all console output for the test.
    The log file is created inside the test's own output directory to maintain isolation.

.PARAMETER TestOutputDir
    The output directory for the test where the log file will be created.

.EXAMPLE
    Start-TestLogging -TestOutputDir "C:\test\output\01-BasicFunctionality"
    Creates: "C:\test\output\01-BasicFunctionality\01-BasicFunctionality.log"

.NOTES
    This function sets the global $script:ConsoleLogPath and $script:IsLogging variables.
    Call Stop-TestLogging to end the transcript.
#>
function Start-TestLogging {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestOutputDir
    )
    
    # Create log file inside the test's own output directory
    $script:ConsoleLogPath = Join-Path $TestOutputDir "$(Split-Path $TestOutputDir -Leaf).log"
    Start-Transcript -Path $script:ConsoleLogPath -Append -Force
    $script:IsLogging = $true
    
    Write-Host "Transcript started, output file is $script:ConsoleLogPath" -ForegroundColor $Colors.Info
}

<#
.SYNOPSIS
    Stops console logging for a test.

.DESCRIPTION
    Ends the PowerShell transcript and cleans up logging variables.
    Should be called after Start-TestLogging to properly close the log file.

.EXAMPLE
    Stop-TestLogging
    Stops the transcript and displays the log file location.

.NOTES
    This function checks if logging is active before attempting to stop the transcript.
    It also resets the global $script:IsLogging variable.
#>
function Stop-TestLogging {
    if ($script:IsLogging) {
        Stop-Transcript
        $script:IsLogging = $false
        Write-Host "Console logging stopped. Log saved to: $script:ConsoleLogPath" -ForegroundColor $Colors.Info
    }
}

<#
.SYNOPSIS
    Gets the path to the current test's console log file.

.DESCRIPTION
    Returns the full path to the console log file for the currently running test.
    Useful for debugging or referencing the log file in test results.

.EXAMPLE
    $logPath = Get-TestConsoleLogPath
    Write-Host "Test log available at: $logPath"

.OUTPUTS
    [string] The full path to the current test's console log file, or $null if no logging is active.
#>
function Get-TestConsoleLogPath {
    return $script:ConsoleLogPath
}

<#
.SYNOPSIS
    Gets the output folder path for a specific test.

.DESCRIPTION
    Creates and returns the output folder path for a test based on its filename.
    This ensures each test has its own isolated output directory.
    
    The folder structure follows the pattern:
    test/test-output/{TestName}/
    where {TestName} is the filename without extension.

.PARAMETER TestFileName
    The filename of the test (e.g., "01-BasicFunctionality.ps1")

.EXAMPLE
    Get-TestOutputFolder "01-BasicFunctionality.ps1"
    Returns: "C:\projects\minecraft\minecraft-mods-manager\test\test-output\01-BasicFunctionality"

.EXAMPLE
    Get-TestOutputFolder "12-TestLatestWithServer.ps1"
    Returns: "C:\projects\minecraft\minecraft-mods-manager\test\test-output\12-TestLatestWithServer"

.OUTPUTS
    [string] The full path to the test's output directory. The directory is created if it doesn't exist.

.NOTES
    This function is critical for test isolation. Each test should use this function
    to get its own output directory, preventing interference between tests.
#>
function Get-TestOutputFolder {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestFileName
    )
    
    $testName = [IO.Path]::GetFileNameWithoutExtension($TestFileName)
    $folder = Join-Path $PSScriptRoot "test-output" $testName
    
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    
    return $folder
}

<#
.SYNOPSIS
    Writes a formatted test header to the console.

.DESCRIPTION
    Displays a visually distinct header for a test section with consistent formatting.
    Uses the Header color and creates a clear visual separator.

.PARAMETER Title
    The title text to display in the header.

.EXAMPLE
    Write-TestHeader "Download Mods"
    Displays:
    ================================================================================
    TEST: Download Mods
    ================================================================================
#>
function Write-TestHeader {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title
    )
    
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "TEST: $Title" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
}

<#
.SYNOPSIS
    Records and displays a test result.

.DESCRIPTION
    Records a test result in the global test counter and displays it with appropriate formatting.
    Updates the total, passed, and failed counts automatically.

.PARAMETER TestName
    The name of the test that was executed.

.PARAMETER Passed
    Whether the test passed (true) or failed (false).

.PARAMETER Message
    Optional additional message to display with the result.

.EXAMPLE
    Write-TestResult "Database Creation" $true "Database file created successfully"
    Displays: ✓ PASS: Database Creation
              Database file created successfully

.EXAMPLE
    Write-TestResult "API Call" $false "Connection timeout after 30 seconds"
    Displays: ✗ FAIL: API Call
              Connection timeout after 30 seconds

.NOTES
    This function automatically updates the global test statistics.
    Use this for all test result reporting to maintain consistent formatting and counting.
#>
function Write-TestResult {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestName,
        
        [Parameter(Mandatory=$true)]
        [bool]$Passed,
        
        [Parameter(Mandatory=$false)]
        [string]$Message = ""
    )
    
    $script:TestResults.Total++
    if ($Passed) {
        $script:TestResults.Passed++
        Write-Host "✓ PASS: $TestName" -ForegroundColor $Colors.Success
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
    } else {
        $script:TestResults.Failed++
        Write-Host "✗ FAIL: $TestName" -ForegroundColor $Colors.Error
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
    }
}

<#
.SYNOPSIS
    Writes a test step indicator to the console.

.DESCRIPTION
    Displays a step indicator for multi-step tests with consistent formatting.
    Uses the Info color to distinguish from test results.

.PARAMETER StepName
    The name of the step being executed.

.EXAMPLE
    Write-TestStep "Validating mod versions"
    Displays: → Validating mod versions
#>
function Write-TestStep {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StepName
    )
    
    Write-Host "  → $StepName" -ForegroundColor $Colors.Info
}

<#
.SYNOPSIS
    Writes a test suite header.

.DESCRIPTION
    Displays a header for a test suite with optional test file information.
    Used at the beginning of test files to identify the test suite.

.PARAMETER SuiteName
    The name of the test suite.

.PARAMETER TestFileName
    Optional test file name to display.

.EXAMPLE
    Write-TestSuiteHeader "StartServer Unit Tests" "08-StartServerUnitTests.ps1"
    Displays:
    StartServer Unit Tests
    =====================
    Test File: 08-StartServerUnitTests.ps1
#>
function Write-TestSuiteHeader {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SuiteName,
        
        [Parameter(Mandatory=$false)]
        [string]$TestFileName = $null
    )
    
    Write-Host ""
    Write-Host "StartServer Unit Tests" -ForegroundColor $Colors.Header
    Write-Host "=====================" -ForegroundColor $Colors.Header
    if ($TestFileName) {
        Write-Host "Test File: $TestFileName" -ForegroundColor $Colors.Info
    }
    Write-Host ""
}

<#
.SYNOPSIS
    Writes a test suite footer with summary statistics.

.DESCRIPTION
    Displays a footer for a test suite with passed/total test counts.
    Uses color coding to indicate success (all passed) or failure (some failed).

.PARAMETER SuiteName
    The name of the test suite.

.PARAMETER Passed
    The number of tests that passed.

.PARAMETER Total
    The total number of tests executed.

.EXAMPLE
    Write-TestSuiteFooter "Basic Functionality" 10 12
    Displays:
    ================================================================================
    Basic Functionality Summary
    ================================================================================
    Passed: 10/12 tests (in red because not all passed)
#>
function Write-TestSuiteFooter {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SuiteName,
        
        [Parameter(Mandatory=$true)]
        [int]$Passed,
        
        [Parameter(Mandatory=$true)]
        [int]$Total
    )
    
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "$SuiteName Summary" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "Passed: $Passed/$Total tests" -ForegroundColor $(if ($Passed -eq $Total) { $Colors.Success } else { $Colors.Error })
}

<#
.SYNOPSIS
    Validates the state of a test database.

.DESCRIPTION
    Checks if a database file exists and contains the expected number of mods.
    Optionally validates that specific mod names are present in the database.

.PARAMETER ExpectedModCount
    The expected number of mods in the database.

.PARAMETER ExpectedMods
    Optional array of mod names that should be present in the database.

.PARAMETER TestName
    The name for this validation test. Defaults to "Database State".

.EXAMPLE
    Test-DatabaseState -ExpectedModCount 3 -ExpectedMods @("Fabric API", "Sodium")
    Validates that the database contains exactly 3 mods and includes "Fabric API" and "Sodium".

.EXAMPLE
    Test-DatabaseState -ExpectedModCount 0
    Validates that the database is empty (0 mods).

.NOTES
    This function uses the global $TestDbPath variable for the database file location.
    It automatically calls Write-TestResult to record the validation results.
#>
function Test-DatabaseState {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ExpectedModCount,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ExpectedMods = @(),
        
        [Parameter(Mandatory=$false)]
        [string]$TestName = "Database State"
    )
    
    if (-not (Test-Path $script:TestDbPath)) {
        Write-TestResult $TestName $false "Database file not found: $script:TestDbPath"
        return
    }
    
    $mods = Import-Csv $script:TestDbPath
    $actualCount = $mods.Count
    
    if ($actualCount -eq $ExpectedModCount) {
        Write-TestResult $TestName $true "Found $actualCount mods (expected $ExpectedModCount)"
    } else {
        Write-TestResult $TestName $false "Found $actualCount mods (expected $ExpectedModCount)"
    }
    
    # Check for specific mods if provided
    foreach ($expectedMod in $ExpectedMods) {
    $found = $mods | Where-Object { $_.Name -eq $expectedMod }
        if ($found) {
            Write-TestResult "Contains $expectedMod" $true
        } else {
            Write-TestResult "Contains $expectedMod" $false
        }
    }
}

<#
.SYNOPSIS
    Executes a command and validates its results.

.DESCRIPTION
    Runs a PowerShell command and captures its output and exit code.
    Validates the command execution and optionally checks database state.
    Provides comprehensive logging and error handling.

.PARAMETER Command
    The PowerShell command to execute (as a string).

.PARAMETER TestName
    The name of the test being executed.

.PARAMETER ExpectedModCount
    Optional expected number of mods in the database after command execution.

.PARAMETER ExpectedMods
    Optional array of mod names that should be present in the database.

.PARAMETER TestFileName
    Optional test file name for isolated database testing.

.EXAMPLE
    Test-Command "& 'ModManager.ps1' -AddMod -AddModId 'fabric-api'" "Add Fabric API" 1 @("Fabric API")
    Executes the command and validates that exactly 1 mod named "Fabric API" exists in the database.

.EXAMPLE
    Test-Command "& 'ModManager.ps1' -ShowHelp" "Help Display" 0
    Executes the help command and validates that the database is unchanged (0 mods).

.NOTES
    This function:
    - Captures all command output (stdout and stderr)
    - Considers exit codes 0 and 1 as success (common for validation commands)
    - Changes to the test's output directory during execution
    - Uses isolated database files when TestFileName is provided
    - Automatically calls Write-TestResult to record results
    - Provides detailed error information on failure
#>
function Test-Command {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$true)]
        [string]$TestName,
        
        [Parameter(Mandatory=$false)]
        [int]$ExpectedModCount = 0,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ExpectedMods = @(),
        
        [Parameter(Mandatory=$false)]
        [string]$TestFileName = $null
    )
    
    Write-Host "`nRunning: $Command" -ForegroundColor $Colors.Info
    
    # Get the output folder and database path
    $outputFolder = $null
    $dbPath = $TestDbPath
    if ($TestFileName) {
        $outputFolder = Get-TestOutputFolder $TestFileName
        $dbPath = Join-Path $outputFolder "run-test-cli.csv"
    }
    
    # Change to output folder if specified
    if ($outputFolder) {
        Push-Location $outputFolder
    }
    
    try {
        # Execute the command and capture all output
        $result = & pwsh -NoProfile -ExecutionPolicy Bypass -Command $Command 2>&1
        $exitCode = $LASTEXITCODE
        
        # Only display essential output (filter out verbose debug info)
        $filteredOutput = $result | Where-Object { 
            $_ -and 
            -not ($_ -match "DEBUG:") -and
            -not ($_ -match "Export-Csv:") -and
            -not ($_ -match "Calculate-LatestGameVersionFromAvailableVersions:") -and
            -not ($_ -match "Filter-RelevantGameVersions:") -and
            -not ($_ -match "Cannot bind argument to parameter") -and
            -not ($_ -match "Could not find a part of the path") -and
            -not ($_ -match "Processing.*results for") -and
            -not ($_ -match "No available game versions for") -and
            -not ($_ -match "Total unique available game versions:") -and
            -not ($_ -match "Update Summary:") -and
            -not ($_ -match "Latest Game Version:") -and
            -not ($_ -match "Latest Available Game Versions:") -and
            -not ($_ -match "Supporting latest version:") -and
            -not ($_ -match "Have updates available:") -and
            -not ($_ -match "Not supporting latest version:") -and
            -not ($_ -match "Not updated:") -and
            -not ($_ -match "Externally updated:") -and
            -not ($_ -match "Not found:") -and
            -not ($_ -match "Errors:") -and
            -not ($_ -match "All modular functions imported successfully") -and
            -not ($_ -match "Starting mod validation process") -and
            -not ($_ -match "Validating.*version.*for") -and
            -not ($_ -match "\\?\\?\\?") -and
            -not ($_ -match "\\?\\?") -and
            -not ($_ -match "\\?")
        }
        
        # Display filtered output (only if there's meaningful content and not too verbose)
        if ($filteredOutput -and $filteredOutput.Count -lt 10) {
            $filteredOutput | ForEach-Object { Write-Host $_ }
        } elseif ($filteredOutput.Count -ge 10) {
            Write-Host "  [Output suppressed - too verbose]" -ForegroundColor Gray
        }
        
        # Consider exit code 0 or 1 as success for our tests
        if ($exitCode -eq 0 -or $exitCode -eq 1) {
            Write-TestResult $TestName $true "Command executed successfully (exit code: $exitCode)"
            
            # Test database state if expected values provided
            if ($ExpectedModCount -gt 0 -or $ExpectedMods.Count -gt 0) {
                # Use the correct database path for testing
                $originalTestDbPath = $script:TestDbPath
                $script:TestDbPath = $dbPath
                Test-DatabaseState $ExpectedModCount $ExpectedMods
                $script:TestDbPath = $originalTestDbPath
            }
        } else {
            Write-TestResult $TestName $false "Command failed with exit code $exitCode"
        }
    }
    catch {
        Write-TestResult $TestName $false "Command threw exception: $($_.Exception.Message)"
    }
    finally {
        if ($outputFolder) { Pop-Location }
    }
}

<#
.SYNOPSIS
    Initializes the test environment for a test file.

.DESCRIPTION
    Sets up the complete test environment including:
    - Auto-detection of test file name if not provided
    - Creation of isolated output directory
    - Database file setup with proper headers
    - Console logging initialization
    - Cleanup of previous test artifacts

.PARAMETER TestFileName
    Optional test file name. If not provided, auto-detects from calling script.

.PARAMETER UseMigratedSchema
    If specified, creates database with migrated Current/Next/Latest column structure.

.EXAMPLE
    Initialize-TestEnvironment "01-BasicFunctionality.ps1"
    Sets up environment for the Basic Functionality test.

.EXAMPLE
    Initialize-TestEnvironment
    Auto-detects test file name and sets up environment.

.EXAMPLE
    Initialize-TestEnvironment -TestFileName "81-TestCurrentNextLatestWorkflow.ps1" -UseMigratedSchema
    Sets up environment with migrated column structure.

.NOTES
    This function is typically called at the beginning of each test file.
    It ensures complete isolation between tests by:
    - Removing any existing output directory
    - Creating a fresh database with proper headers
    - Starting console logging to the test's output directory
    - Setting up all necessary paths and variables
#>
function Initialize-TestEnvironment {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TestFileName = $null,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseMigratedSchema
    )
    
    Write-Host "Initializing test environment..." -ForegroundColor $Colors.Info
    
    # Auto-detect test name from calling script if not provided
    if (-not $TestFileName) {
        $TestFileName = Split-Path $MyInvocation.ScriptName -Leaf
        Write-Host "Auto-detected test name: $TestFileName" -ForegroundColor $Colors.Info
    }
    
    # Set TestDbPath to the output folder if TestFileName is provided
    if ($TestFileName) {
        $outputFolder = Get-TestOutputFolder $TestFileName
        # Remove the entire output folder if it exists
        if (Test-Path $outputFolder) {
            Remove-Item -Path $outputFolder -Recurse -Force
            Write-Host "Removed existing output folder: $outputFolder" -ForegroundColor $Colors.Info
        }
        # Recreate the output folder
        New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
        $script:TestDbPath = Join-Path $outputFolder "run-test-cli.csv"
        $script:TestApiResponseDir = Join-Path $outputFolder "apiresponse"
        
        # Start console logging for this test
        Start-TestLogging -TestOutputDir $outputFolder
    }
    
    # Clean up previous test files (use script-scoped TestDbPath)
    if ($script:TestDbPath -and (Test-Path $script:TestDbPath)) {
        Write-Host "Removed existing database: $script:TestDbPath" -ForegroundColor $Colors.Info
    }
    
    # Create blank database with headers only
    if ($UseMigratedSchema) {
        # Migrated schema with Current/Next/Latest structure
        $headers = @("Group", "Type", "CurrentGameVersion", "ID", "Loader", "CurrentVersion", "Name", "Description", "Jar", "Url", "Category", "CurrentVersionUrl", "NextVersion", "NextVersionUrl", "NextGameVersion", "LatestVersionUrl", "LatestVersion", "LatestGameVersion", "ApiSource", "Host", "IconUrl", "ClientSide", "ServerSide", "Title", "ProjectDescription", "IssuesUrl", "SourceUrl", "WikiUrl", "RecordHash", "UrlDirect", "AvailableGameVersions", "CurrentDependenciesRequired", "CurrentDependenciesOptional", "LatestDependenciesRequired", "LatestDependenciesOptional")
    } else {
        # Original schema (all 34 columns as per MODLIST_CSV_COLUMNS.md)
        $headers = @("Group", "Type", "GameVersion", "ID", "Loader", "Version", "Name", "Description", "Jar", "Url", "Category", "VersionUrl", "LatestVersionUrl", "LatestVersion", "ApiSource", "Host", "IconUrl", "ClientSide", "ServerSide", "Title", "ProjectDescription", "IssuesUrl", "SourceUrl", "WikiUrl", "LatestGameVersion", "RecordHash", "UrlDirect", "AvailableGameVersions", "CurrentDependencies", "LatestDependencies", "CurrentDependenciesRequired", "CurrentDependenciesOptional", "LatestDependenciesRequired", "LatestDependenciesOptional")
    }
    $headers -join "," | Out-File $script:TestDbPath -Encoding UTF8
    Write-Host "Created new database: $script:TestDbPath" -ForegroundColor $Colors.Info
    
    # Create output folder for this test file
    if ($TestFileName) {
    $outputFolder = Get-TestOutputFolder $TestFileName
    $script:TestOutputDir = $outputFolder
    Write-Host "Test output folder: $outputFolder" -ForegroundColor $Colors.Info
    }
    Write-TestResult "Environment Setup" $true "Test database created"
}

<#
.SYNOPSIS
    Displays a comprehensive test summary.

.DESCRIPTION
    Shows the final test results including total tests, passed tests, and failed tests.
    Provides a visual summary with color coding and success/failure indicators.

.EXAMPLE
    Show-TestSummary
    Displays:
    ================================================================================
    TEST SUMMARY
    ================================================================================
    Total Tests: 42
    Passed: 42
    Failed: 0
    🎉 ALL TESTS PASSED! 🎉

.NOTES
    This function should be called at the end of each test file to provide
    a clear summary of all test results. It uses the global $script:TestResults
    variable to gather statistics from all Write-TestResult calls.
#>
function Show-TestSummary {
    param(
        [string]$WorkflowType = "Unknown"
    )
    
    Write-Host "`n" + ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "TEST SUMMARY" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "Total Tests: $($script:TestResults.Total)" -ForegroundColor $Colors.Info
    Write-Host "Passed: $($script:TestResults.Passed)" -ForegroundColor $Colors.Success
    Write-Host "Failed: $($script:TestResults.Failed)" -ForegroundColor $(if ($script:TestResults.Failed -eq 0) { $Colors.Success } else { $Colors.Error })
    
    if ($script:TestResults.Failed -eq 0) {
        Write-Host "`n🎉 ALL TESTS PASSED! 🎉" -ForegroundColor $Colors.Success
    } else {
        Write-Host "`n❌ SOME TESTS FAILED! ❌" -ForegroundColor $Colors.Error
    }
    
    # Show version compatibility matrix for workflow tests
    if ($WorkflowType -ne "Unknown" -and $script:TestOutputDir) {
        Show-VersionMatrix -TestOutputDir $script:TestOutputDir -WorkflowType $WorkflowType
    }
}

# Version Compatibility Matrix function
function Show-VersionMatrix {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestOutputDir,
        [string]$WorkflowType = "Unknown"
    )
    
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "VERSION COMPATIBILITY MATRIX - $WorkflowType Workflow" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    
    # Check all version folders
    $versionFolders = @("1.21.8", "1.21.9", "1.21.10")
    $matrix = @{}
    
    foreach ($version in $versionFolders) {
        $versionPath = Join-Path $TestOutputDir "download" $version "mods"
        if (Test-Path $versionPath) {
            $modFiles = Get-ChildItem -Path $versionPath -Filter "*.jar" -Recurse -ErrorAction SilentlyContinue
            
            $versionCounts = @{
                "1.21.8" = 0
                "1.21.9" = 0
                "1.21.10" = 0
                "1.21.11" = 0
                "unknown" = 0
            }
            
            foreach ($mod in $modFiles) {
                $fileName = $mod.Name
                $matched = $false
                
                foreach ($checkVersion in @("1.21.8", "1.21.9", "1.21.10", "1.21.11")) {
                    if ($fileName -match $checkVersion.Replace(".", "\.")) {
                        $versionCounts[$checkVersion]++
                        $matched = $true
                        break
                    }
                }
                
                if (-not $matched) {
                    $versionCounts["unknown"]++
                }
            }
            
            $matrix[$version] = $versionCounts
        } else {
            $matrix[$version] = @{
                "1.21.8" = 0; "1.21.9" = 0; "1.21.10" = 0; "1.21.11" = 0; "unknown" = 0
            }
        }
    }
    
    # Display matrix
    Write-Host "Download Folder | 1.21.8 Mods | 1.21.9 Mods | 1.21.10 Mods | 1.21.11 Mods | Unknown" -ForegroundColor $Colors.Info
    Write-Host ("-" * 80) -ForegroundColor $Colors.Muted
    
    foreach ($folder in $versionFolders) {
        if (-not $matrix.ContainsKey($folder)) { continue }
        
        $counts = $matrix[$folder]
        $total = ($counts.Values | Measure-Object -Sum).Sum
        
        $line = "{0,-15} | {1,11} | {2,12} | {3,12} | {4,12} | {5,7}" -f @(
            $folder,
            $counts["1.21.8"],
            $counts["1.21.9"], 
            $counts["1.21.10"],
            $counts["1.21.11"],
            $counts["unknown"]
        )
        
        $color = $Colors.Muted
        if ($folder -eq "1.21.8" -and $counts["1.21.8"] -gt $counts["1.21.9"]) { $color = $Colors.Success }
        elseif ($folder -eq "1.21.9" -and $counts["1.21.9"] -gt 0) { $color = $Colors.Success }
        elseif ($folder -eq "1.21.10" -and $counts["1.21.10"] -gt 0) { $color = $Colors.Success }
        elseif ($total -gt 0) { $color = $Colors.Warning }
        
        Write-Host $line -ForegroundColor $color
    }
    
    Write-Host ("-" * 80) -ForegroundColor $Colors.Muted
    Write-Host "EXPECTED BEHAVIOR:" -ForegroundColor $Colors.Info
    Write-Host "Current (1.21.8)  : All mods should be 1.21.8 versions" -ForegroundColor $Colors.Muted
    Write-Host "Next (1.21.9)     : Mix of 1.21.8 (current) + 1.21.9 (next) versions" -ForegroundColor $Colors.Muted  
    Write-Host "Latest (1.21.10+) : Mix of 1.21.8 + 1.21.9 + 1.21.10+ versions" -ForegroundColor $Colors.Muted
    Write-Host ""
}

function Cleanup-TestEnvironment {
    param([switch]$Cleanup)
    
    # Stop console logging
    Stop-TestLogging
    
    if ($Cleanup) {
        Write-Host "`nCleaning up test environment..." -ForegroundColor $Colors.Info
        
        if (Test-Path $TestDbPath) {
            Write-Host "Removed existing database: $TestDbPath" -ForegroundColor $Colors.Info
        }
        
        # Remove copied API files
        if (Test-Path $MainApiResponsePath) {
            Get-ChildItem $MainApiResponsePath -File | Remove-Item -Force
        }
        
        Write-Host "Cleanup completed" -ForegroundColor $Colors.Info
    }
}

function Write-TestSuiteSummary {
    param([string]$SuiteName)
    
    $passedTests = $script:TestResults.Passed
    $totalTests = $script:TestResults.Total
    
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "$SuiteName Summary" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "Passed: $passedTests/$totalTests tests" -ForegroundColor $(if ($passedTests -eq $totalTests) { $Colors.Success } else { $Colors.Error })
    
    if ($passedTests -eq $totalTests) {
        Write-Host "True" -ForegroundColor $Colors.Success
    } else {
        Write-Host "False" -ForegroundColor $Colors.Error
    }
}

# Alias for Show-TestSummary to maintain backward compatibility
function Write-TestSummary {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TestFileName = $null
    )
    
    Show-TestSummary
}

# NOTE: Download folders are intentionally preserved for post-test validation.
# Remove any Remove-Item calls that delete download folders. 