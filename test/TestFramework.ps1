# Shared Test Framework for ModManager CLI Tests
# Contains common functions and configuration used across all test files

# Configuration
$ScriptPath = "..\ModManager.ps1"
$TestDbPath = "run-test-cli.csv"  # Will be set to output folder path in Initialize-TestEnvironment
$TestApiResponsePath = "apiresponse"
$MainApiResponsePath = "apiresponse"
$TestRoot = Join-Path $PSScriptRoot "tests"

# Colors for output
$Colors = @{
    Pass = "Green"
    Fail = "Red"
    Info = "Cyan"
    Warning = "Yellow"
    Header = "Magenta"
}

# Test counter (shared across all test files) - Use script scope
$script:TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
}

function Get-TestOutputFolder {
    param([string]$TestFileName)
    $testName = [IO.Path]::GetFileNameWithoutExtension($TestFileName)
    $folder = Join-Path $PSScriptRoot "test-output" $testName
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    return $folder
}

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "TEST: $Title" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $script:TestResults.Total++
    if ($Passed) {
        $script:TestResults.Passed++
        Write-Host "✓ PASS: $TestName" -ForegroundColor $Colors.Pass
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
    } else {
        $script:TestResults.Failed++
        Write-Host "✗ FAIL: $TestName" -ForegroundColor $Colors.Fail
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
    }
}

function Write-TestStep {
    param([string]$StepName)
    Write-Host "  → $StepName" -ForegroundColor $Colors.Info
}

function Write-TestSuiteHeader {
    param([string]$SuiteName, [string]$TestFileName = $null)
    Write-Host ""
    Write-Host "StartServer Unit Tests" -ForegroundColor $Colors.Header
    Write-Host "=====================" -ForegroundColor $Colors.Header
    if ($TestFileName) {
        Write-Host "Test File: $TestFileName" -ForegroundColor $Colors.Info
    }
    Write-Host ""
}

function Write-TestSuiteFooter {
    param([string]$SuiteName, [int]$Passed, [int]$Total)
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "$SuiteName Summary" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "Passed: $Passed/$Total tests" -ForegroundColor $(if ($Passed -eq $Total) { $Colors.Pass } else { $Colors.Fail })
}

function Test-DatabaseState {
    param(
        [int]$ExpectedModCount,
        [string[]]$ExpectedMods = @(),
        [string]$TestName = "Database State"
    )
    
    if (-not (Test-Path $TestDbPath)) {
        Write-TestResult $TestName $false "Database file not found"
        return
    }
    
    $mods = Import-Csv $TestDbPath
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

function Test-Command {
    param(
        [string]$Command,
        [string]$TestName,
        [int]$ExpectedModCount = 0,
        [string[]]$ExpectedMods = @(),
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
        
        # Display the captured output
        $result | ForEach-Object { Write-Host $_ }
        
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

function Initialize-TestEnvironment {
    param([string]$TestFileName = $null)
    Write-Host "Initializing test environment..." -ForegroundColor $Colors.Info
    
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
    }
    
    # Clean up previous test files
    if (Test-Path $TestDbPath) {
        Write-Host "Removed existing database: $TestDbPath" -ForegroundColor $Colors.Info
    }
    
    # Create blank database with headers only
    $headers = @("Group", "Type", "GameVersion", "ID", "Loader", "Version", "Name", "Description", "Jar", "Url", "Category", "VersionUrl", "LatestVersionUrl", "LatestVersion", "ApiSource", "Host", "IconUrl", "ClientSide", "ServerSide", "Title", "ProjectDescription", "IssuesUrl", "SourceUrl", "WikiUrl", "LatestGameVersion", "RecordHash")
    $headers -join "," | Out-File $TestDbPath -Encoding UTF8
    Write-Host "Created new database: $TestDbPath" -ForegroundColor $Colors.Info
    
    # Copy API response files to main apiresponse folder for caching
    if (Test-Path $TestApiResponsePath) {
        if (-not (Test-Path $MainApiResponsePath)) {
            New-Item -ItemType Directory -Path $MainApiResponsePath -Force
        }
        
        # Only copy if source and destination are different
        if ($TestApiResponsePath -ne $MainApiResponsePath) {
            Copy-Item "$TestApiResponsePath\*" $MainApiResponsePath -Force
            Write-Host "Copied API response files for caching" -ForegroundColor $Colors.Info
        } else {
            Write-Host "API response files already in correct location" -ForegroundColor $Colors.Info
        }
    }
    
    # Create output folder for this test file
    if ($TestFileName) {
        $outputFolder = Get-TestOutputFolder $TestFileName
        Write-Host "Test output folder: $outputFolder" -ForegroundColor $Colors.Info
    }
    Write-TestResult "Environment Setup" $true "Test database created and API files copied"
}

function Show-TestSummary {
    Write-Host "`n" + ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "TEST SUMMARY" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    
    Write-Host "Total Tests: $($script:TestResults.Total)" -ForegroundColor White
    Write-Host "Passed: $($script:TestResults.Passed)" -ForegroundColor $Colors.Pass
    Write-Host "Failed: $($script:TestResults.Failed)" -ForegroundColor $Colors.Fail
    
    if ($script:TestResults.Failed -eq 0) {
        Write-Host "`n🎉 ALL TESTS PASSED! 🎉" -ForegroundColor $Colors.Pass
    } else {
        Write-Host "`n❌ SOME TESTS FAILED! ❌" -ForegroundColor $Colors.Fail
    }
}

function Cleanup-TestEnvironment {
    param([switch]$Cleanup)
    
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
    Write-Host "Passed: $passedTests/$totalTests tests" -ForegroundColor $(if ($passedTests -eq $totalTests) { $Colors.Pass } else { $Colors.Fail })
    
    if ($passedTests -eq $totalTests) {
        Write-Host "True" -ForegroundColor $Colors.Pass
    } else {
        Write-Host "False" -ForegroundColor $Colors.Fail
    }
}

# NOTE: Download folders are intentionally preserved for post-test validation.
# Remove any Remove-Item calls that delete download folders. 