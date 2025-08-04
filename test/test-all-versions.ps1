#!/usr/bin/env pwsh
# =============================================================================
# Comprehensive Version Testing Script
# =============================================================================
# Tests all Minecraft versions to ensure URL resolution and server startup work
# =============================================================================

param(
    [switch]$Quick,  # Skip time-consuming tests
    [string[]]$Versions = @("1.21.5", "1.21.6", "1.21.7", "1.21.8"),
    [switch]$Verbose
)

# Test results tracking
$testResults = @()
$totalTests = 0
$passedTests = 0
$failedTests = 0

function Write-TestHeader($message) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host $message -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Write-TestResult($testName, $result, $details = $null) {
    $global:totalTests++
    
    if ($result -eq "PASS") {
        Write-Host "✅ $testName" -ForegroundColor Green
        $global:passedTests++
        $status = "PASS"
    } elseif ($result -eq "FAIL") {
        Write-Host "❌ $testName" -ForegroundColor Red
        if ($details) {
            Write-Host "   Details: $details" -ForegroundColor Yellow
        }
        $global:failedTests++
        $status = "FAIL"
    } else {
        Write-Host "⚠️  $testName" -ForegroundColor Yellow
        if ($details) {
            Write-Host "   Details: $details" -ForegroundColor Gray
        }
        $status = "SKIP"
    }
    
    $global:testResults += [PSCustomObject]@{
        Test = $testName
        Status = $status
        Details = $details
        Timestamp = Get-Date
    }
}

function Test-URLResolution($version) {
    Write-TestHeader "Testing URL Resolution for Version $version"
    
    # Test 1: Database entries exist
    try {
        $mods = Import-Csv -Path "modlist.csv"
        $serverEntry = $mods | Where-Object { $_.GameVersion -eq $version -and $_.Type -eq "server" -and $_.ID -match "minecraft-server" }
        $launcherEntry = $mods | Where-Object { $_.GameVersion -eq $version -and $_.Type -eq "launcher" -and $_.ID -match "fabric-server-launcher" }
        
        if ($serverEntry) {
            Write-TestResult "Database has Minecraft Server entry for $version" "PASS"
        } else {
            Write-TestResult "Database has Minecraft Server entry for $version" "FAIL" "No server entry found"
            return $false
        }
        
        if ($launcherEntry) {
            Write-TestResult "Database has Fabric Launcher entry for $version" "PASS"
        } else {
            Write-TestResult "Database has Fabric Launcher entry for $version" "FAIL" "No launcher entry found"
            return $false
        }
    } catch {
        Write-TestResult "Database accessibility" "FAIL" $_.Exception.Message
        return $false
    }
    
    # Test 2: URL resolution (if URLs are empty)
    if ([string]::IsNullOrEmpty($serverEntry.Url)) {
        Write-TestResult "Minecraft Server URL needs resolution for $version" "PASS" "Empty URL will trigger auto-resolution"
    } else {
        Write-TestResult "Minecraft Server URL already populated for $version" "PASS" "URL: $($serverEntry.Url)"
    }
    
    if ([string]::IsNullOrEmpty($launcherEntry.Url) -or $launcherEntry.Url -eq "https://meta.fabricmc.net/v2/versions") {
        Write-TestResult "Fabric Launcher URL needs resolution for $version" "PASS" "Empty/base URL will trigger auto-resolution"
    } else {
        Write-TestResult "Fabric Launcher URL already populated for $version" "PASS" "URL: $($launcherEntry.Url)"
    }
    
    return $true
}

function Test-Download($version) {
    Write-TestHeader "Testing Download for Version $version"
    
    # Test 3: Download process
    try {
        Write-Host "Running download for version $version..." -ForegroundColor Gray
        $downloadOutput = & pwsh -Command "./ModManager.ps1 -DownloadMods -GameVersion '$version'" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Download process completed for $version" "PASS"
        } else {
            Write-TestResult "Download process completed for $version" "FAIL" "Exit code: $LASTEXITCODE"
            return $false
        }
    } catch {
        Write-TestResult "Download process for $version" "FAIL" $_.Exception.Message
        return $false
    }
    
    # Test 4: Downloaded files exist
    $versionFolder = "download/$version"
    if (-not (Test-Path $versionFolder)) {
        Write-TestResult "Version folder exists for $version" "FAIL" "Folder not found: $versionFolder"
        return $false
    } else {
        Write-TestResult "Version folder exists for $version" "PASS"
    }
    
    # Check for Minecraft server JAR
    $serverJar = Get-ChildItem -Path $versionFolder -Filter "minecraft_server.$version.jar" -ErrorAction SilentlyContinue
    if ($serverJar) {
        $serverSize = [math]::Round($serverJar.Length / 1MB, 2)
        Write-TestResult "Minecraft Server JAR downloaded for $version" "PASS" "Size: ${serverSize} MB"
    } else {
        Write-TestResult "Minecraft Server JAR downloaded for $version" "FAIL" "JAR file not found"
        return $false
    }
    
    # Check for Fabric launcher JAR
    $fabricJars = Get-ChildItem -Path $versionFolder -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue
    if ($fabricJars.Count -gt 0) {
        $fabricSize = [math]::Round($fabricJars[0].Length / 1MB, 2)
        Write-TestResult "Fabric Server JAR downloaded for $version" "PASS" "Size: ${fabricSize} MB"
    } else {
        Write-TestResult "Fabric Server JAR downloaded for $version" "FAIL" "JAR file not found"
        return $false
    }
    
    return $true
}

function Test-ServerStartup($version) {
    Write-TestHeader "Testing Server Startup for Version $version"
    
    if ($Quick) {
        Write-TestResult "Server startup test for $version" "SKIP" "Skipped due to -Quick flag"
        return $true
    }
    
    # Clear server files first
    try {
        Write-Host "Clearing server files for clean test..." -ForegroundColor Gray
        $clearOutput = & pwsh -Command "./ModManager.ps1 -ClearServer" 2>&1
        Write-TestResult "Server files cleared for $version" "PASS"
    } catch {
        Write-TestResult "Server files cleared for $version" "FAIL" $_.Exception.Message
        return $false
    }
    
    # Test 5: Server startup and validation
    try {
        Write-Host "Starting server for validation (this may take 1-2 minutes)..." -ForegroundColor Gray
        $serverOutput = & pwsh -Command "./ModManager.ps1 -StartServer" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Server startup and validation for $version" "PASS" "Server loaded and stopped successfully"
            
            # Check for expected log messages
            $logFile = "download/$version/logs/latest.log"
            if (Test-Path $logFile) {
                $logContent = Get-Content $logFile -Raw
                
                if ($logContent -match "Done \(\d+\.\d+s\)! For help, type") {
                    Write-TestResult "Server 'Done' message found for $version" "PASS" "Server fully loaded"
                } else {
                    Write-TestResult "Server 'Done' message found for $version" "FAIL" "Done message not found in logs"
                }
                
                if ($logContent -match "SERVER IS RUNNING IN OFFLINE/INSECURE MODE") {
                    Write-TestResult "Server offline mode confirmed for $version" "PASS" "Running in test mode"
                } else {
                    Write-TestResult "Server offline mode confirmed for $version" "FAIL" "Offline mode warning not found"
                }
            } else {
                Write-TestResult "Server log file created for $version" "FAIL" "Log file not found"
            }
        } else {
            Write-TestResult "Server startup and validation for $version" "FAIL" "Exit code: $LASTEXITCODE"
            return $false
        }
    } catch {
        Write-TestResult "Server startup for $version" "FAIL" $_.Exception.Message
        return $false
    }
    
    return $true
}

function Show-TestSummary {
    Write-TestHeader "Test Summary"
    
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "✅ Passed: $passedTests" -ForegroundColor Green
    Write-Host "❌ Failed: $failedTests" -ForegroundColor Red
    Write-Host "⚠️  Skipped: $($totalTests - $passedTests - $failedTests)" -ForegroundColor Yellow
    
    $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
    
    if ($failedTests -gt 0) {
        Write-Host ""
        Write-Host "Failed Tests:" -ForegroundColor Red
        foreach ($result in $testResults | Where-Object { $_.Status -eq "FAIL" }) {
            Write-Host "  ❌ $($result.Test): $($result.Details)" -ForegroundColor Red
        }
    }
    
    # Save detailed results
    $resultsFile = "test-results-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').csv"
    $testResults | Export-Csv -Path $resultsFile -NoTypeInformation
    Write-Host ""
    Write-Host "Detailed results saved to: $resultsFile" -ForegroundColor Cyan
    
    return $failedTests -eq 0
}

# Main test execution
try {
    Write-TestHeader "Comprehensive Minecraft Version Testing"
    Write-Host "Testing versions: $($Versions -join ', ')" -ForegroundColor Cyan
    Write-Host "Quick mode: $Quick" -ForegroundColor Gray
    
    foreach ($version in $Versions) {
        Write-Host ""
        Write-Host "🎯 Testing Version $version" -ForegroundColor Magenta
        Write-Host ("-" * 40) -ForegroundColor Gray
        
        # Run tests for this version
        $urlTest = Test-URLResolution $version
        $downloadTest = if ($urlTest) { Test-Download $version } else { $false }
        $startupTest = if ($downloadTest) { Test-ServerStartup $version } else { $false }
        
        # Version summary
        if ($urlTest -and $downloadTest -and ($startupTest -or $Quick)) {
            Write-Host "🎉 Version ${version}: ALL TESTS PASSED" -ForegroundColor Green
        } else {
            Write-Host "💥 Version ${version}: SOME TESTS FAILED" -ForegroundColor Red
        }
    }
    
    # Final summary
    $success = Show-TestSummary
    
    if ($success) {
        Write-Host ""
        Write-Host "🎉 ALL TESTS COMPLETED SUCCESSFULLY!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host ""
        Write-Host "❌ SOME TESTS FAILED - CHECK RESULTS ABOVE" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "❌ Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}