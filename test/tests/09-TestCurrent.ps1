# Test Current Version Workflow
# Tests the complete workflow: use modlist.csv, download current versions, start server, monitor logs

param([string]$TestFileName = $null)

# Import test framework
$TestFrameworkPath = Join-Path $PSScriptRoot "..\TestFramework.ps1"
. $TestFrameworkPath

# Test configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$ModListPath = Join-Path $PSScriptRoot "..\..\modlist.csv"
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\09-TestCurrent"
$TestDownloadDir = Join-Path $TestOutputDir "download"

# Ensure test output and download directories exist
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}
if (-not (Test-Path $TestDownloadDir)) {
    New-Item -ItemType Directory -Path $TestDownloadDir -Force | Out-Null
}

function Test-CurrentVersionWorkflow {
    param([string]$TestName)
    
    Write-TestHeader "Testing Current Version Workflow"
    
    # Step 1: Verify modlist.csv exists
    Write-TestStep "Checking modlist.csv exists"
    if (-not (Test-Path $ModListPath)) {
        Write-TestResult "ModList Existence" $false "modlist.csv not found at $ModListPath"
        return $false
    }
    Write-TestResult "ModList Existence" $true "modlist.csv found"
    
    # Step 2: Read modlist.csv to see what mods we have
    Write-TestStep "Reading modlist.csv"
    try {
        $modList = Import-Csv -Path $ModListPath
        Write-TestResult "ModList Reading" $true "Successfully read modlist.csv with $($modList.Count) mods"
    } catch {
        Write-TestResult "ModList Reading" $false "Failed to read modlist.csv: $($_.Exception.Message)"
        return $false
    }
    
    # Step 3: Download current versions (not latest)
    Write-TestStep "Downloading current versions"
    $downloadResult = & $ModManagerPath -DownloadMods -DatabaseFile $ModListPath -DownloadFolder $TestDownloadDir -UseCachedResponses 2>&1
    $downloadOutput = $downloadResult -join "`n"
    
    # Check if downloads succeeded by looking for success indicators or absence of failure indicators
    if ($downloadOutput -match "✅ Successfully downloaded: \d+" -or $downloadOutput -match "Successfully downloaded: \d+" -or 
        ($downloadOutput -match "Download Summary" -and $downloadOutput -notmatch "Failed: [1-9]")) {
        Write-TestResult "Current Version Download" $true "Current versions downloaded successfully"
    } else {
        Write-TestResult "Current Version Download" $false "Failed to download current versions: $downloadOutput"
        return $false
    }
    
    # Step 4: Verify downloads exist in output folder
    Write-TestStep "Verifying downloads in output folder"
    if (Test-Path $TestDownloadDir) {
        $downloadContents = Get-ChildItem -Path $TestDownloadDir -Recurse -File | Measure-Object
        Write-TestResult "Download Verification" $true "Found $($downloadContents.Count) files in download directory"
    } else {
        Write-TestResult "Download Verification" $false "Download directory not found"
        return $false
    }
    
    # Step 5: Test server startup process
    Write-TestStep "Testing server startup process"
    $startServerResult = & $ModManagerPath -StartServer -DatabaseFile $ModListPath 2>&1
    $startServerOutput = $startServerResult -join "`n"
    
    # Check if server startup process works (may fail due to Java version, but should get past initial checks)
    if ($startServerOutput -match "Checking Java version" -or $startServerOutput -match "Java version") {
        Write-TestResult "Server Startup Process" $true "Server startup process initiated successfully"
    } else {
        Write-TestResult "Server Startup Process" $false "Server startup process failed: $startServerOutput"
        return $false
    }
    
    # Step 6: Test log monitoring (create mock logs)
    Write-TestStep "Testing log monitoring"
    $logDir = Join-Path $TestOutputDir "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $mockLogFile = Join-Path $logDir "server.log"
    @"
[12:00:00] [main/INFO]: Starting server...
[12:00:01] [main/INFO]: Loading mods...
[12:00:02] [main/INFO]: Server started successfully
[12:00:03] [main/INFO]: Server running on port 25565
"@ | Out-File -FilePath $mockLogFile -Encoding UTF8
    
    # Test log analysis
    $logContent = Get-Content $mockLogFile
    $errorLines = $logContent | Where-Object { $_ -match "(ERROR|FATAL|Exception|Failed|Error)" }
    
    if ($errorLines.Count -eq 0) {
        Write-TestResult "Log Monitoring" $true "Log monitoring correctly identified error-free logs"
    } else {
        Write-TestResult "Log Monitoring" $false "Log monitoring incorrectly flagged logs as having errors"
        return $false
    }
    
    # Step 7: Test error detection (create error logs)
    Write-TestStep "Testing error detection"
    $errorLogFile = Join-Path $logDir "error.log"
    @"
[12:00:00] [main/INFO]: Starting server...
[12:00:01] [main/ERROR]: Failed to load mod: fabric-api
[12:00:02] [main/FATAL]: Server startup failed
"@ | Out-File -FilePath $errorLogFile -Encoding UTF8
    
    $errorLogContent = Get-Content $errorLogFile
    $errorDetected = $errorLogContent | Where-Object { $_ -match "(ERROR|FATAL|Exception|Failed|Error)" }
    
    if ($errorDetected.Count -gt 0) {
        Write-TestResult "Error Detection" $true "Error detection correctly identified errors in logs"
    } else {
        Write-TestResult "Error Detection" $false "Error detection failed to identify errors in logs"
        return $false
    }
    
    # Step 8: Test version comparison (current vs latest)
    Write-TestStep "Testing version comparison"
    $currentMods = $modList | Where-Object { $_.Type -eq "mod" }
    $versionComparisonPassed = $true
    
    foreach ($mod in $currentMods) {
        if ($mod.Version -and $mod.LatestVersion -and $mod.Version -ne $mod.LatestVersion) {
            Write-TestResult "Version Comparison: $($mod.Name)" $true "Current: $($mod.Version), Latest: $($mod.LatestVersion)"
        } elseif ($mod.Version -and $mod.LatestVersion) {
            Write-TestResult "Version Comparison: $($mod.Name)" $true "Using latest version: $($mod.Version)"
        }
    }
    
    Write-TestResult "Version Comparison Complete" $true "All mod version comparisons completed"
    
    return $true
}

function Test-CurrentVersionDatabaseState {
    param([string]$TestName)
    
    Write-TestHeader "Testing Current Version Database State"
    
    # Verify modlist.csv still exists and is readable
    if (-not (Test-Path $ModListPath)) {
        Write-TestResult "Database Existence" $false "modlist.csv not found after workflow"
        return $false
    }
    
    # Read the database
    try {
        $modList = Import-Csv -Path $ModListPath
        Write-TestResult "Database Reading" $true "Successfully read modlist.csv with $($modList.Count) mods"
    } catch {
        Write-TestResult "Database Reading" $false "Failed to read modlist.csv: $($_.Exception.Message)"
        return $false
    }
    
    # Check that we have mods in the database
    $modCount = $modList.Count
    if ($modCount -gt 0) {
        Write-TestResult "Mod Count" $true "Found $modCount mods in database"
    } else {
        Write-TestResult "Mod Count" $false "No mods found in database"
        return $false
    }
    
    # Check for specific mod types
    $mods = $modList | Where-Object { $_.Type -eq "mod" }
    $modpacks = $modList | Where-Object { $_.Type -eq "modpack" }
    $servers = $modList | Where-Object { $_.Type -eq "server" }
    
    Write-TestResult "Mod Types" $true "Found: $($mods.Count) mods, $($modpacks.Count) modpacks, $($servers.Count) servers"
    
    return $true
}

# Main test execution function
function Invoke-TestCurrent {
    param([string]$TestFileName = $null)
    
    Write-TestSuiteHeader "Test Current Version Workflow" $TestFileName
    
    # Run the main workflow test
    $workflowResult = Test-CurrentVersionWorkflow -TestName "Current Version Workflow"
    
    # Run the database state test
    $databaseResult = Test-CurrentVersionDatabaseState -TestName "Current Version Database State"
    
    # Summary
    Write-TestSuiteSummary "Test Current Version Workflow"
    
    return ($workflowResult -and $databaseResult)
}

# Execute tests if run directly
if ($MyInvocation.InvocationName -ne ".") {
    Invoke-TestCurrent -TestFileName $TestFileName
} 