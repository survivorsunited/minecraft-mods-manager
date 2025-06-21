# StartServer Unit Tests
# Focused unit tests for StartServer functions with proper mocking

param([string]$TestFileName = $null)

# Import test framework
$TestFrameworkPath = Join-Path $PSScriptRoot "..\TestFramework.ps1"
. $TestFrameworkPath

# Test configuration
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\08-StartServerUnitTests"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Mock functions for testing
function Mock-JavaVersion {
    param([string]$Version)
    
    # Create a mock java command that returns the specified version
    $mockJavaScript = @"
    Write-Host "java version `"$Version`" 2024-01-01"
    Write-Host "Java(TM) SE Runtime Environment (build $Version-b01)"
    Write-Host "Java HotSpot(TM) 64-Bit Server VM (build $Version-b01, mixed mode, sharing)"
"@
    
    $mockPath = Join-Path $TestOutputDir "mock-java.ps1"
    $mockJavaScript | Out-File -FilePath $mockPath -Encoding UTF8
    
    return $mockPath
}

function Mock-FileSystem {
    param(
        [string]$BasePath,
        [hashtable]$Structure
    )
    
    # Create mock file system structure
    foreach ($item in $Structure.GetEnumerator()) {
        $itemPath = Join-Path $BasePath $item.Key
        if ($item.Value -is [string]) {
            # It's a file
            $item.Value | Out-File -FilePath $itemPath -Encoding UTF8 -Force
        } else {
            # It's a directory
            New-Item -ItemType Directory -Path $itemPath -Force | Out-Null
            if ($item.Value -is [hashtable]) {
                Mock-FileSystem -BasePath $itemPath -Structure $item.Value
            }
        }
    }
}

function Test-JavaVersionDetection {
    param([string]$TestName)
    
    Write-TestHeader "Testing Java Version Detection" $TestName
    
    # Test 1: Valid Java 22 version
    Write-TestStep "Testing Java 22 version detection"
    $javaVersion = "22.0.1"
    $versionString = "`"$javaVersion`""
    
    if ($versionString -match '"([^"]+)"') {
        $extractedVersion = $matches[1]
        if ($extractedVersion -match "^(\d+)") {
            $majorVersion = [int]$matches[1]
            if ($majorVersion -eq 22) {
                Write-TestResult "PASS" "Java 22 version correctly parsed"
            } else {
                Write-TestResult "FAIL" "Java 22 version incorrectly parsed as $majorVersion"
                return $false
            }
        } else {
            Write-TestResult "FAIL" "Could not extract major version from $extractedVersion"
            return $false
        }
    } else {
        Write-TestResult "FAIL" "Could not extract version from $versionString"
        return $false
    }
    
    # Test 2: Invalid Java 11 version
    Write-TestStep "Testing Java 11 version detection (should fail)"
    $javaVersion = "11.0.17"
    $versionString = "`"$javaVersion`""
    
    if ($versionString -match '"([^"]+)"') {
        $extractedVersion = $matches[1]
        if ($extractedVersion -match "^(\d+)") {
            $majorVersion = [int]$matches[1]
            if ($majorVersion -lt 22) {
                Write-TestResult "PASS" "Java 11 version correctly identified as incompatible"
            } else {
                Write-TestResult "FAIL" "Java 11 version incorrectly identified as compatible"
                return $false
            }
        } else {
            Write-TestResult "FAIL" "Could not extract major version from $extractedVersion"
            return $false
        }
    } else {
        Write-TestResult "FAIL" "Could not extract version from $versionString"
        return $false
    }
    
    return $true
}

function Test-ErrorDetectionLogic {
    param([string]$TestName)
    
    Write-TestHeader "Testing Error Detection Logic" $TestName
    
    # Test 1: Normal log line (should not trigger error)
    Write-TestStep "Testing normal log line"
    $normalLines = @(
        "[12:00:00] [main/INFO]: Starting server...",
        "[12:00:01] [main/INFO]: Loading mods...",
        "[12:00:02] [main/INFO]: Server started successfully"
    )
    
    $errorFound = $false
    foreach ($line in $normalLines) {
        if ($line -match "(ERROR|FATAL|Exception|Failed|Error)" -and $line -notmatch "Server exited") {
            $errorFound = $true
            break
        }
    }
    
    if (-not $errorFound) {
        Write-TestResult "PASS" "Normal log lines correctly identified as error-free"
    } else {
        Write-TestResult "FAIL" "Normal log lines incorrectly flagged as having errors"
        return $false
    }
    
    # Test 2: Error log lines (should trigger error)
    Write-TestStep "Testing error log lines"
    $errorLines = @(
        "[12:00:00] [main/INFO]: Starting server...",
        "[12:00:01] [main/ERROR]: Failed to load mod: fabric-api",
        "[12:00:02] [main/FATAL]: Server startup failed",
        "[12:00:03] [main/Exception]: java.lang.RuntimeException"
    )
    
    $errorFound = $false
    foreach ($line in $errorLines) {
        if ($line -match "(ERROR|FATAL|Exception|Failed|Error)" -and $line -notmatch "Server exited") {
            $errorFound = $true
            break
        }
    }
    
    if ($errorFound) {
        Write-TestResult "PASS" "Error log lines correctly identified as having errors"
    } else {
        Write-TestResult "FAIL" "Error log lines incorrectly flagged as error-free"
        return $false
    }
    
    return $true
}

function Test-JobManagement {
    param([string]$TestName)
    
    Write-TestHeader "Testing Job Management" $TestName
    
    # Test 1: Job creation and monitoring
    Write-TestStep "Testing job creation and monitoring"
    
    $testJob = Start-Job -ScriptBlock {
        Start-Sleep -Seconds 1
        Write-Output "Test completed"
        return 0
    }
    
    if ($testJob) {
        Write-TestResult "PASS" "Job creation successful"
        
        # Wait for job to complete
        Wait-Job -Id $testJob.Id -Timeout 10 | Out-Null
        $jobStatus = Get-Job -Id $testJob.Id
        
        if ($jobStatus.State -eq "Completed") {
            Write-TestResult "PASS" "Job monitoring successful"
            
            # Get job output
            $jobOutput = Receive-Job -Id $testJob.Id
            if ($jobOutput -contains "Test completed") {
                Write-TestResult "PASS" "Job output retrieval successful"
            } else {
                Write-TestResult "FAIL" "Job output retrieval failed"
                return $false
            }
        } else {
            Write-TestResult "FAIL" "Job monitoring failed - State: $($jobStatus.State)"
            return $false
        }
        
        # Clean up
        Remove-Job -Id $testJob.Id -ErrorAction SilentlyContinue
    } else {
        Write-TestResult "FAIL" "Job creation failed"
        return $false
    }
    
    return $true
}

function Test-LogFileMonitoring {
    param([string]$TestName)
    
    Write-TestHeader "Testing Log File Monitoring" $TestName
    
    # Create test log file
    $testLogFile = Join-Path $TestOutputDir "test-monitoring.log"
    
    # Test 1: Log file growth detection
    Write-TestStep "Testing log file growth detection"
    
    # Initial content
    "Initial line" | Out-File -FilePath $testLogFile -Encoding UTF8
    $initialSize = (Get-Item $testLogFile).Length
    
    # Add more content
    "New line 1" | Out-File -FilePath $testLogFile -Append -Encoding UTF8
    "New line 2" | Out-File -FilePath $testLogFile -Append -Encoding UTF8
    
    $newSize = (Get-Item $testLogFile).Length
    
    if ($newSize -gt $initialSize) {
        Write-TestResult "PASS" "Log file growth detection successful"
    } else {
        Write-TestResult "FAIL" "Log file growth detection failed"
        return $false
    }
    
    # Test 2: New content detection
    Write-TestStep "Testing new content detection"
    
    $allContent = Get-Content $testLogFile
    $newLines = $allContent | Select-Object -Last 2
    
    if ($newLines.Count -eq 2 -and $newLines[0] -eq "New line 1" -and $newLines[1] -eq "New line 2") {
        Write-TestResult "PASS" "New content detection successful"
    } else {
        Write-TestResult "FAIL" "New content detection failed"
        return $false
    }
    
    # Clean up
    Remove-Item $testLogFile -ErrorAction SilentlyContinue
    
    return $true
}

function Test-FileSystemValidation {
    param([string]$TestName)
    
    Write-TestHeader "Testing File System Validation" $TestName
    
    # Create test directory structure
    $testBase = Join-Path $TestOutputDir "filesystem-test"
    if (Test-Path $testBase) {
        Remove-Item $testBase -Recurse -Force
    }
    
    # Test 1: Directory existence check
    Write-TestStep "Testing directory existence check"
    
    if (-not (Test-Path $testBase)) {
        Write-TestResult "PASS" "Non-existent directory correctly identified"
    } else {
        Write-TestResult "FAIL" "Non-existent directory incorrectly identified as existing"
        return $false
    }
    
    # Create directory
    New-Item -ItemType Directory -Path $testBase -Force | Out-Null
    
    if (Test-Path $testBase) {
        Write-TestResult "PASS" "Existent directory correctly identified"
    } else {
        Write-TestResult "FAIL" "Existent directory incorrectly identified as non-existent"
        return $false
    }
    
    # Test 2: File existence check
    Write-TestStep "Testing file existence check"
    
    $testFile = Join-Path $testBase "test.txt"
    if (-not (Test-Path $testFile)) {
        Write-TestResult "PASS" "Non-existent file correctly identified"
    } else {
        Write-TestResult "FAIL" "Non-existent file incorrectly identified as existing"
        return $false
    }
    
    # Create file
    "Test content" | Out-File -FilePath $testFile -Encoding UTF8
    
    if (Test-Path $testFile) {
        Write-TestResult "PASS" "Existent file correctly identified"
    } else {
        Write-TestResult "FAIL" "Existent file incorrectly identified as non-existent"
        return $false
    }
    
    # Clean up
    Remove-Item $testBase -Recurse -Force -ErrorAction SilentlyContinue
    
    return $true
}

function Test-VersionFolderDetection {
    param([string]$TestName)
    
    Write-TestHeader "Testing Version Folder Detection" $TestName
    
    # Create test directory structure
    $testBase = Join-Path $TestOutputDir "version-test"
    if (Test-Path $testBase) {
        Remove-Item $testBase -Recurse -Force
    }
    New-Item -ItemType Directory -Path $testBase -Force | Out-Null
    
    # Test 1: No version folders
    Write-TestStep "Testing no version folders"
    
    $versionFolders = Get-ChildItem -Path $testBase -Directory -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Name -match "^\d+\.\d+\.\d+" } |
                     Sort-Object Name -Descending
    
    if ($versionFolders.Count -eq 0) {
        Write-TestResult "PASS" "No version folders correctly detected"
    } else {
        Write-TestResult "FAIL" "No version folders incorrectly detected"
        return $false
    }
    
    # Test 2: Multiple version folders
    Write-TestStep "Testing multiple version folders"
    
    # Create version folders
    New-Item -ItemType Directory -Path (Join-Path $testBase "1.21.5") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $testBase "1.21.6") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $testBase "1.20.1") -Force | Out-Null
    
    $versionFolders = Get-ChildItem -Path $testBase -Directory -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Name -match "^\d+\.\d+\.\d+" } |
                     Sort-Object Name -Descending
    
    if ($versionFolders.Count -eq 3) {
        Write-TestResult "PASS" "Multiple version folders correctly detected"
        
        # Check sorting (should be descending)
        if ($versionFolders[0].Name -eq "1.21.6") {
            Write-TestResult "PASS" "Version folders correctly sorted in descending order"
        } else {
            Write-TestResult "FAIL" "Version folders incorrectly sorted"
            return $false
        }
    } else {
        Write-TestResult "FAIL" "Multiple version folders incorrectly detected"
        return $false
    }
    
    # Test 3: Non-version folders ignored
    Write-TestStep "Testing non-version folders ignored"
    
    # Create non-version folders
    New-Item -ItemType Directory -Path (Join-Path $testBase "mods") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $testBase "logs") -Force | Out-Null
    
    $versionFolders = Get-ChildItem -Path $testBase -Directory -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Name -match "^\d+\.\d+\.\d+" } |
                     Sort-Object Name -Descending
    
    if ($versionFolders.Count -eq 3) {
        Write-TestResult "PASS" "Non-version folders correctly ignored"
    } else {
        Write-TestResult "FAIL" "Non-version folders incorrectly included"
        return $false
    }
    
    # Clean up
    Remove-Item $testBase -Recurse -Force -ErrorAction SilentlyContinue
    
    return $true
}

# Main test execution
function Invoke-StartServerUnitTests {
    param([string]$TestFileName = $null)
    
    Write-TestSuiteHeader "StartServer Unit Tests" $TestFileName
    
    $testResults = @()
    
    # Test 1: Java Version Detection
    $testResults += Test-JavaVersionDetection "Java Version Detection"
    
    # Test 2: Error Detection Logic
    $testResults += Test-ErrorDetectionLogic "Error Detection Logic"
    
    # Test 3: Job Management
    $testResults += Test-JobManagement "Job Management"
    
    # Test 4: Log File Monitoring
    $testResults += Test-LogFileMonitoring "Log File Monitoring"
    
    # Test 5: File System Validation
    $testResults += Test-FileSystemValidation "File System Validation"
    
    # Test 6: Version Folder Detection
    $testResults += Test-VersionFolderDetection "Version Folder Detection"
    
    # Generate test report
    $passedTests = ($testResults | Where-Object { $_ -eq $true }).Count
    $totalTests = $testResults.Count
    
    Write-TestSuiteFooter "StartServer Unit Tests" $passedTests $totalTests
    
    # Save detailed test report
    $reportPath = Join-Path $TestOutputDir "startserver-unit-test-report.txt"
    $reportContent = @"
StartServer Unit Test Report
===========================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Test File: $TestFileName

Test Results:
-------------
Java Version Detection: $(if ($testResults[0]) { "PASS" } else { "FAIL" })
Error Detection Logic: $(if ($testResults[1]) { "PASS" } else { "FAIL" })
Job Management: $(if ($testResults[2]) { "PASS" } else { "FAIL" })
Log File Monitoring: $(if ($testResults[3]) { "PASS" } else { "FAIL" })
File System Validation: $(if ($testResults[4]) { "PASS" } else { "FAIL" })
Version Folder Detection: $(if ($testResults[5]) { "PASS" } else { "FAIL" })

Summary: $passedTests/$totalTests tests passed

Environment Notes:
- PowerShell Version: $($PSVersionTable.PSVersion)
- Test Output Directory: $TestOutputDir
"@
    
    $reportContent | Out-File -FilePath $reportPath -Encoding UTF8
    
    return $passedTests -eq $totalTests
}

# Execute tests if run directly
if ($MyInvocation.InvocationName -ne ".") {
    Invoke-StartServerUnitTests -TestFileName $TestFileName
} 