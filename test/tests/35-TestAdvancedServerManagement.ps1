# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "35-TestAdvancedServerManagement.ps1"

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"

Write-Host "Minecraft Mod Manager - Advanced Server Management Tests" -ForegroundColor $Colors.Header
Write-Host "=======================================================" -ForegroundColor $Colors.Header

function Invoke-TestAdvancedServerManagement {
    param([string]$TestFileName = $null)
    
    # Test 1: Server Performance Monitoring Function
    Write-TestHeader "Server Performance Monitoring Function"
    $scriptContent = Get-Content $ModManagerPath -Raw
    $result1 = $scriptContent -match "function Get-ServerPerformance"
    Write-TestResult "Server performance monitoring function" $result1 "Function availability check"

# Test 2: Server Backup Function
Write-TestHeader "Server Backup Function"
$result2 = $scriptContent -match "function New-ServerBackup"
Write-TestResult "Server backup function" $result2 "Function availability check"

# Test 3: Server Backup Restoration Function
Write-TestHeader "Server Backup Restoration Function"
$result3 = $scriptContent -match "function Restore-ServerBackup"
Write-TestResult "Server backup restoration function" $result3 "Function availability check"

# Test 4: Server Plugin Management Functions
Write-TestHeader "Server Plugin Management Functions"
$pluginFunctions = @(
    "function Get-ServerPlugins",
    "function Install-ServerPlugin",
    "function Remove-ServerPlugin"
)

$missingFunctions = @()
foreach ($function in $pluginFunctions) {
    if ($scriptContent -notmatch [regex]::Escape($function)) {
        $missingFunctions += $function
    }
}

$result4 = $missingFunctions.Count -eq 0
Write-TestResult "Server plugin management functions" $result4 "Function availability check"

# Test 5: Server Config Template Functions
Write-TestHeader "Server Config Template Functions"
$templateFunctions = @(
    "function New-ServerConfigTemplate",
    "function Apply-ServerConfigTemplate"
)

$missingFunctions = @()
foreach ($function in $templateFunctions) {
    if ($scriptContent -notmatch [regex]::Escape($function)) {
        $missingFunctions += $function
    }
}

$result5 = $missingFunctions.Count -eq 0
Write-TestResult "Server config template functions" $result5 "Function availability check"

# Test 6: Server Health Check Function
Write-TestHeader "Server Health Check Function"
$result6 = $scriptContent -match "function Test-ServerHealth"
Write-TestResult "Server health check function" $result6 "Function availability check"

# Test 7: Server Diagnostics Function
Write-TestHeader "Server Diagnostics Function"
$result7 = $scriptContent -match "function Get-ServerDiagnostics"
Write-TestResult "Server diagnostics function" $result7 "Function availability check"

# Test 8: Advanced Server Management Parameters
Write-TestHeader "Advanced Server Management Parameters"
$parameters = @(
    "MonitorServerPerformance",
    "CreateServerBackup",
    "RestoreServerBackup",
    "ListServerPlugins",
    "InstallPlugin",
    "RemovePlugin",
    "CreateConfigTemplate",
    "ApplyConfigTemplate",
    "RunServerHealthCheck",
    "RunServerDiagnostics"
)

$missingParameters = @()
foreach ($param in $parameters) {
    if ($scriptContent -notmatch [regex]::Escape($param)) {
        $missingParameters += $param
    }
}

$result8 = $missingParameters.Count -eq 0
Write-TestResult "Advanced server management parameters" $result8 "Parameter availability check"

# Test 9: CLI Integration for Performance Monitoring
Write-TestHeader "CLI Integration for Performance Monitoring"
$result9 = $scriptContent -match "if \(`$MonitorServerPerformance\)" -and $scriptContent -match "Get-ServerPerformance"
Write-TestResult "CLI integration for performance monitoring" $result9 "CLI parameter integration check"

# Test 10: CLI Integration for Server Backup
Write-TestHeader "CLI Integration for Server Backup"
$result10 = $scriptContent -match "if \(`$CreateServerBackup\)" -and $scriptContent -match "New-ServerBackup"
Write-TestResult "CLI integration for server backup" $result10 "CLI parameter integration check"

# Test 11: CLI Integration for Backup Restoration
Write-TestHeader "CLI Integration for Backup Restoration"
$result11 = $scriptContent -match "if \(`$RestoreServerBackup\)" -and $scriptContent -match "Restore-ServerBackup"
Write-TestResult "CLI integration for backup restoration" $result11 "CLI parameter integration check"

# Test 12: CLI Integration for Plugin Management
Write-TestHeader "CLI Integration for Plugin Management"
$pluginCLI = @(
    "if \(`$ListServerPlugins\)",
    "if \(`$InstallPlugin -and `$PluginUrl\)",
    "if \(`$RemovePlugin\)"
)

$missingCLI = @()
foreach ($cli in $pluginCLI) {
    if ($scriptContent -notmatch $cli) {
        $missingCLI += $cli
    }
}

$result12 = $missingCLI.Count -eq 0
Write-TestResult "CLI integration for plugin management" $result12 "CLI parameter integration check"

# Test 13: CLI Integration for Config Templates
Write-TestHeader "CLI Integration for Config Templates"
$templateCLI = @(
    "if \(`$CreateConfigTemplate\)",
    "if \(`$ApplyConfigTemplate\)"
)

$missingCLI = @()
foreach ($cli in $templateCLI) {
    if ($scriptContent -notmatch $cli) {
        $missingCLI += $cli
    }
}

$result13 = $missingCLI.Count -eq 0
Write-TestResult "CLI integration for config templates" $result13 "CLI parameter integration check"

# Test 14: CLI Integration for Health Check
Write-TestHeader "CLI Integration for Health Check"
$result14 = $scriptContent -match "if \(`$RunServerHealthCheck\)" -and $scriptContent -match "Test-ServerHealth"
Write-TestResult "CLI integration for health check" $result14 "CLI parameter integration check"

# Test 15: CLI Integration for Diagnostics
Write-TestHeader "CLI Integration for Diagnostics"
$result15 = $scriptContent -match "if \(`$RunServerDiagnostics\)" -and $scriptContent -match "Get-ServerDiagnostics"
Write-TestResult "CLI integration for diagnostics" $result15 "CLI parameter integration check"

# Test 16: Performance Monitoring Parameters
Write-TestHeader "Performance Monitoring Parameters"
$perfParams = @(
    "PerformanceSampleInterval",
    "PerformanceSampleCount"
)

$missingParams = @()
foreach ($param in $perfParams) {
    if ($scriptContent -notmatch [regex]::Escape($param)) {
        $missingParams += $param
    }
}

$result16 = $missingParams.Count -eq 0
Write-TestResult "Performance monitoring parameters" $result16 "Parameter availability check"

# Test 17: Backup Management Parameters
Write-TestHeader "Backup Management Parameters"
$backupParams = @(
    "BackupPath",
    "BackupName",
    "ForceRestore"
)

$missingParams = @()
foreach ($param in $backupParams) {
    if ($scriptContent -notmatch [regex]::Escape($param)) {
        $missingParams += $param
    }
}

$result17 = $missingParams.Count -eq 0
Write-TestResult "Backup management parameters" $result17 "Parameter availability check"

# Test 18: Plugin Management Parameters
Write-TestHeader "Plugin Management Parameters"
$pluginParams = @(
    "PluginUrl",
    "ForceRemovePlugin"
)

$missingParams = @()
foreach ($param in $pluginParams) {
    if ($scriptContent -notmatch [regex]::Escape($param)) {
        $missingParams += $param
    }
}

$result18 = $missingParams.Count -eq 0
Write-TestResult "Plugin management parameters" $result18 "Parameter availability check"

# Test 19: Config Template Parameters
Write-TestHeader "Config Template Parameters"
$templateParams = @(
    "TemplateName",
    "TemplatesPath",
    "ForceApplyTemplate"
)

$missingParams = @()
foreach ($param in $templateParams) {
    if ($scriptContent -notmatch [regex]::Escape($param)) {
        $missingParams += $param
    }
}

$result19 = $missingParams.Count -eq 0
Write-TestResult "Config template parameters" $result19 "Parameter availability check"

# Test 20: Health and Diagnostics Parameters
Write-TestHeader "Health and Diagnostics Parameters"
$healthParams = @(
    "HealthCheckTimeout",
    "DiagnosticsLogLines"
)

$missingParams = @()
foreach ($param in $healthParams) {
    if ($scriptContent -notmatch [regex]::Escape($param)) {
        $missingParams += $param
    }
}

$result20 = $missingParams.Count -eq 0
Write-TestResult "Health and diagnostics parameters" $result20 "Parameter availability check"

# Test 21: Function Parameter Validation
Write-TestHeader "Function Parameter Validation"
# Check for parameter validation patterns
$validationPatterns = @(
    "if \(-not \(Test-Path",
    "try \{\s*.*\s*\} catch \{\s*.*\s*\}",
    "Write-Host.*❌.*Error"
)

$missingPatterns = @()
foreach ($pattern in $validationPatterns) {
    if ($scriptContent -notmatch $pattern) {
        $missingPatterns += $pattern
    }
}

$result21 = $missingPatterns.Count -eq 0
Write-TestResult "Function parameter validation" $result21 "Parameter validation pattern check"

# Test 22: Error Handling Implementation
Write-TestHeader "Error Handling Implementation"
# Check for error handling patterns
$errorPatterns = @(
    "catch \{\s*.*Write-Host.*❌.*Error",
    "return `$false",
    "return `$null"
)

$missingPatterns = @()
foreach ($pattern in $errorPatterns) {
    if ($scriptContent -notmatch $pattern) {
        $missingPatterns += $pattern
    }
}

$result22 = $missingPatterns.Count -eq 0
Write-TestResult "Error handling implementation" $result22 "Error handling pattern check"

# Test 23: Success Reporting Implementation
Write-TestHeader "Success Reporting Implementation"
# Check for success reporting patterns
$successPatterns = @(
    "Write-Host.*✅.*successfully",
    "return `$true",
    "exit 0"
)

$missingPatterns = @()
foreach ($pattern in $successPatterns) {
    if ($scriptContent -notmatch $pattern) {
        $missingPatterns += $pattern
    }
}

$result23 = $missingPatterns.Count -eq 0
Write-TestResult "Success reporting implementation" $result23 "Success reporting pattern check"

# Test 24: CLI Parameter Recognition
Write-TestHeader "CLI Parameter Recognition"
$output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -RunServerHealthCheck -DownloadFolder $TestDownloadDir 2>&1
$result24 = $output -match "Server Health Check" -or $output -match "No server JAR found"
Write-TestResult "CLI parameter recognition" $result24 "CLI parameter recognition check"

# Test 25: Function Integration Test
Write-TestHeader "Function Integration Test"
# Check for integration with existing server functions
$integrationPatterns = @(
    "Download-ServerFiles",
    "Start-MinecraftServer",
    "Get-ChildItem.*minecraft_server.*jar"
)

$missingPatterns = @()
foreach ($pattern in $integrationPatterns) {
    if ($scriptContent -notmatch $pattern) {
        $missingPatterns += $pattern
    }
}

$result25 = $missingPatterns.Count -eq 0
Write-TestResult "Function integration test" $result25 "Function integration pattern check"

    # Summary
    Write-TestSuiteSummary "Advanced Server Management Tests"
    
    # Log file verification
    $expectedLogPath = Join-Path $TestOutputDir "$([IO.Path]::GetFileNameWithoutExtension($TestFileName)).log"
    if (Test-Path $expectedLogPath) {
        Write-Host "✓ Console log created: $expectedLogPath" -ForegroundColor Green
    } else {
        Write-Host "✗ Console log missing: $expectedLogPath" -ForegroundColor Red
    }
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestAdvancedServerManagement -TestFileName $TestFileName 