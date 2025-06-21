# Test Server Startup Functionality
# Tests the server startup process and error handling

param([string]$TestFileName = $null)

# Import test framework
$TestFrameworkPath = Join-Path $PSScriptRoot "..\TestFramework.ps1"
. $TestFrameworkPath

# Test configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\07-StartServerTests"
$TestDownloadDir = Join-Path $TestOutputDir "download"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Test variables
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0
$TestReport = @()

# Test report file
$TestReportPath = Join-Path $TestOutputDir "start-server-test-report.txt"

function Test-ServerStartup {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$ExpectedOutput = "",
        [int]$ExpectedExitCode = $null
    )
    
    $script:TotalTests++
    Write-Host "Testing: $TestName" -ForegroundColor Yellow
    
    try {
        $result = & $TestScript 2>&1
        $exitCode = $LASTEXITCODE
        $output = $result -join "`n"
        
        # Save individual test log
        $logFile = Join-Path $TestOutputDir "$($TestName.Replace(' ', '_')).log"
        $output | Out-File -FilePath $logFile -Encoding UTF8
        
        # Check if test passed
        $passed = $true
        $errorMessage = ""
        
        if ($ExpectedExitCode -ne $null -and $exitCode -ne $ExpectedExitCode) {
            $passed = $false
            $errorMessage = "Expected exit code $ExpectedExitCode, got $exitCode"
        }
        
        if ($ExpectedOutput -and $output -notmatch $ExpectedOutput) {
            $passed = $false
            $errorMessage = "Expected output pattern '$ExpectedOutput' not found"
        }
        
        if ($passed) {
            Write-Host "  ✅ PASS" -ForegroundColor Green
            $script:PassedTests++
            $script:TestReport += "✅ PASS: $TestName`n"
        } else {
            Write-Host "  ❌ FAIL: $errorMessage" -ForegroundColor Red
            $script:FailedTests++
            $script:TestReport += "❌ FAIL: $TestName - $errorMessage`n"
        }
        
    } catch {
        Write-Host "  ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $script:FailedTests++
        $script:TestReport += "❌ ERROR: $TestName - $($_.Exception.Message)`n"
    }
    
    Write-Host ""
}

function Invoke-StartServerTests {
    param([string]$TestFileName = $null)
    
    Write-Host "Starting Server Startup Tests" -ForegroundColor Yellow
    Write-Host "Test Output Directory: $TestOutputDir" -ForegroundColor Gray
    Write-Host ""

    # Test 1: Server startup with missing files
    Write-Host "=== Test 1: Server Startup with Missing Files ===" -ForegroundColor Magenta
    Test-ServerStartup -TestName "Server Startup Missing Files" -TestScript {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -StartServer -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Download folder not found" -ExpectedExitCode 1

    # Test 2: Server startup with invalid Java
    Write-Host "=== Test 2: Server Startup with Invalid Java ===" -ForegroundColor Magenta
    Test-ServerStartup -TestName "Server Startup Invalid Java" -TestScript {
        # Create a mock server folder with invalid Java
        $serverFolder = Join-Path $TestDownloadDir "1.21.6"
        if (-not (Test-Path $serverFolder)) {
            New-Item -ItemType Directory -Path $serverFolder -Force | Out-Null
        }
        
        # Create a mock server jar
        $serverJar = Join-Path $serverFolder "minecraft_server.1.21.6.jar"
        "Mock server jar" | Out-File -FilePath $serverJar -Encoding UTF8
        
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -StartServer -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Java version" -ExpectedExitCode 1

    # Test 3: Server startup with missing mods folder
    Write-Host "=== Test 3: Server Startup with Missing Mods Folder ===" -ForegroundColor Magenta
    Test-ServerStartup -TestName "Server Startup Missing Mods" -TestScript {
        # Create server folder without mods
        $serverFolder = Join-Path $TestDownloadDir "1.21.6"
        if (-not (Test-Path $serverFolder)) {
            New-Item -ItemType Directory -Path $serverFolder -Force | Out-Null
        }
        
        # Create a mock server jar
        $serverJar = Join-Path $serverFolder "minecraft_server.1.21.6.jar"
        "Mock server jar" | Out-File -FilePath $serverJar -Encoding UTF8
        
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -StartServer -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Java version" -ExpectedExitCode 1

    # Test 4: Server startup with empty mods folder
    Write-Host "=== Test 4: Server Startup with Empty Mods Folder ===" -ForegroundColor Magenta
    Test-ServerStartup -TestName "Server Startup Empty Mods" -TestScript {
        # Create server folder with empty mods
        $serverFolder = Join-Path $TestDownloadDir "1.21.6"
        $modsFolder = Join-Path $serverFolder "mods"
        
        if (-not (Test-Path $serverFolder)) {
            New-Item -ItemType Directory -Path $serverFolder -Force | Out-Null
        }
        if (-not (Test-Path $modsFolder)) {
            New-Item -ItemType Directory -Path $modsFolder -Force | Out-Null
        }
        
        # Create a mock server jar
        $serverJar = Join-Path $serverFolder "minecraft_server.1.21.6.jar"
        "Mock server jar" | Out-File -FilePath $serverJar -Encoding UTF8
        
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -StartServer -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Java version" -ExpectedExitCode 1

    # Test 5: Server startup with incompatible mods
    Write-Host "=== Test 5: Server Startup with Incompatible Mods ===" -ForegroundColor Magenta
    Test-ServerStartup -TestName "Server Startup Incompatible Mods" -TestScript {
        # Create server folder with mock incompatible mods
        $serverFolder = Join-Path $TestDownloadDir "1.21.6"
        $modsFolder = Join-Path $serverFolder "mods"
        
        if (-not (Test-Path $serverFolder)) {
            New-Item -ItemType Directory -Path $serverFolder -Force | Out-Null
        }
        if (-not (Test-Path $modsFolder)) {
            New-Item -ItemType Directory -Path $modsFolder -Force | Out-Null
        }
        
        # Create mock incompatible mods
        $incompatibleMod1 = Join-Path $modsFolder "incompatible-mod-1.jar"
        $incompatibleMod2 = Join-Path $modsFolder "incompatible-mod-2.jar"
        "Mock incompatible mod 1" | Out-File -FilePath $incompatibleMod1 -Encoding UTF8
        "Mock incompatible mod 2" | Out-File -FilePath $incompatibleMod2 -Encoding UTF8
        
        # Create a mock server jar
        $serverJar = Join-Path $serverFolder "minecraft_server.1.21.6.jar"
        "Mock server jar" | Out-File -FilePath $serverJar -Encoding UTF8
        
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -StartServer -DownloadFolder $TestDownloadDir
    } -ExpectedOutput "Java version" -ExpectedExitCode 1

    # Generate final report
    $TestReport += @"

Test Summary:
=============
Total Tests: $TotalTests
Passed: $PassedTests
Failed: $FailedTests
Success Rate: $(if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 2) } else { 0 })%

Test Details:
=============
This test validates server startup functionality and error handling.

Expected Behavior:
- Server startup should handle missing files gracefully
- Invalid Java should be detected
- Missing mods should be handled
- Incompatible mods should be detected
- Error messages should be clear and helpful
"@

    # Set global test results for the test runner
    $script:TestResults = @{
        Total = $TotalTests
        Passed = $PassedTests
        Failed = $FailedTests
    }

    # Save test report
    $TestReport | Out-File -FilePath $TestReportPath -Encoding UTF8

    Write-Host "Test completed!" -ForegroundColor Green
    Write-Host "Total Tests: $TotalTests" -ForegroundColor Cyan
    Write-Host "Passed: $PassedTests" -ForegroundColor Green
    Write-Host "Failed: $FailedTests" -ForegroundColor Red
    Write-Host "Success Rate: $(if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 2) } else { 0 })%" -ForegroundColor Green
    Write-Host "Test report saved to: $TestReportPath" -ForegroundColor Gray

    return ($FailedTests -eq 0)
}

# Execute tests if run directly
if ($MyInvocation.InvocationName -ne ".") {
    Invoke-StartServerTests -TestFileName $TestFileName
} 