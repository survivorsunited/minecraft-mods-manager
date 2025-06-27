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

# Test 1: Server Performance Monitoring Function
Write-TestHeader "Server Performance Monitoring Function"
$result1 = Test-Command "Get-ServerPerformance function should be available" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "function Get-ServerPerformance"
}
Write-TestResult "Server performance monitoring function" $result1

# Test 2: Server Backup Function
Write-TestHeader "Server Backup Function"
$result2 = Test-Command "New-ServerBackup function should be available" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "function New-ServerBackup"
}
Write-TestResult "Server backup function" $result2

# Test 3: Server Backup Restoration Function
Write-TestHeader "Server Backup Restoration Function"
$result3 = Test-Command "Restore-ServerBackup function should be available" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "function Restore-ServerBackup"
}
Write-TestResult "Server backup restoration function" $result3

# Test 4: Server Plugin Management Functions
Write-TestHeader "Server Plugin Management Functions"
$result4 = Test-Command "Server plugin management functions should be available" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingFunctions.Count -eq 0
}
Write-TestResult "Server plugin management functions" $result4

# Test 5: Server Config Template Functions
Write-TestHeader "Server Config Template Functions"
$result5 = Test-Command "Server config template functions should be available" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingFunctions.Count -eq 0
}
Write-TestResult "Server config template functions" $result5

# Test 6: Server Health Check Function
Write-TestHeader "Server Health Check Function"
$result6 = Test-Command "Test-ServerHealth function should be available" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "function Test-ServerHealth"
}
Write-TestResult "Server health check function" $result6

# Test 7: Server Diagnostics Function
Write-TestHeader "Server Diagnostics Function"
$result7 = Test-Command "Get-ServerDiagnostics function should be available" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "function Get-ServerDiagnostics"
}
Write-TestResult "Server diagnostics function" $result7

# Test 8: Advanced Server Management Parameters
Write-TestHeader "Advanced Server Management Parameters"
$result8 = Test-Command "Advanced server management parameters should be in param block" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingParameters.Count -eq 0
}
Write-TestResult "Advanced server management parameters" $result8

# Test 9: CLI Integration for Performance Monitoring
Write-TestHeader "CLI Integration for Performance Monitoring"
$result9 = Test-Command "CLI should handle MonitorServerPerformance parameter" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "if \(`$MonitorServerPerformance\)" -and $scriptContent -match "Get-ServerPerformance"
}
Write-TestResult "CLI integration for performance monitoring" $result9

# Test 10: CLI Integration for Server Backup
Write-TestHeader "CLI Integration for Server Backup"
$result10 = Test-Command "CLI should handle CreateServerBackup parameter" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "if \(`$CreateServerBackup\)" -and $scriptContent -match "New-ServerBackup"
}
Write-TestResult "CLI integration for server backup" $result10

# Test 11: CLI Integration for Backup Restoration
Write-TestHeader "CLI Integration for Backup Restoration"
$result11 = Test-Command "CLI should handle RestoreServerBackup parameter" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "if \(`$RestoreServerBackup\)" -and $scriptContent -match "Restore-ServerBackup"
}
Write-TestResult "CLI integration for backup restoration" $result11

# Test 12: CLI Integration for Plugin Management
Write-TestHeader "CLI Integration for Plugin Management"
$result12 = Test-Command "CLI should handle plugin management parameters" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingCLI.Count -eq 0
}
Write-TestResult "CLI integration for plugin management" $result12

# Test 13: CLI Integration for Config Templates
Write-TestHeader "CLI Integration for Config Templates"
$result13 = Test-Command "CLI should handle config template parameters" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingCLI.Count -eq 0
}
Write-TestResult "CLI integration for config templates" $result13

# Test 14: CLI Integration for Health Check
Write-TestHeader "CLI Integration for Health Check"
$result14 = Test-Command "CLI should handle RunServerHealthCheck parameter" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "if \(`$RunServerHealthCheck\)" -and $scriptContent -match "Test-ServerHealth"
}
Write-TestResult "CLI integration for health check" $result14

# Test 15: CLI Integration for Diagnostics
Write-TestHeader "CLI Integration for Diagnostics"
$result15 = Test-Command "CLI should handle RunServerDiagnostics parameter" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    return $scriptContent -match "if \(`$RunServerDiagnostics\)" -and $scriptContent -match "Get-ServerDiagnostics"
}
Write-TestResult "CLI integration for diagnostics" $result15

# Test 16: Performance Monitoring Parameters
Write-TestHeader "Performance Monitoring Parameters"
$result16 = Test-Command "Performance monitoring should have configurable parameters" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingParams.Count -eq 0
}
Write-TestResult "Performance monitoring parameters" $result16

# Test 17: Backup Management Parameters
Write-TestHeader "Backup Management Parameters"
$result17 = Test-Command "Backup management should have configurable parameters" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingParams.Count -eq 0
}
Write-TestResult "Backup management parameters" $result17

# Test 18: Plugin Management Parameters
Write-TestHeader "Plugin Management Parameters"
$result18 = Test-Command "Plugin management should have configurable parameters" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingParams.Count -eq 0
}
Write-TestResult "Plugin management parameters" $result18

# Test 19: Config Template Parameters
Write-TestHeader "Config Template Parameters"
$result19 = Test-Command "Config template management should have configurable parameters" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingParams.Count -eq 0
}
Write-TestResult "Config template parameters" $result19

# Test 20: Health and Diagnostics Parameters
Write-TestHeader "Health and Diagnostics Parameters"
$result20 = Test-Command "Health and diagnostics should have configurable parameters" {
    $scriptContent = Get-Content $ModManagerPath -Raw
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
    
    return $missingParams.Count -eq 0
}
Write-TestResult "Health and diagnostics parameters" $result20

# Test 21: Function Parameter Validation
Write-TestHeader "Function Parameter Validation"
$result21 = Test-Command "Advanced server functions should have proper parameter validation" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    
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
    
    return $missingPatterns.Count -eq 0
}
Write-TestResult "Function parameter validation" $result21

# Test 22: Error Handling Implementation
Write-TestHeader "Error Handling Implementation"
$result22 = Test-Command "Advanced server functions should have comprehensive error handling" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    
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
    
    return $missingPatterns.Count -eq 0
}
Write-TestResult "Error handling implementation" $result22

# Test 23: Success Reporting Implementation
Write-TestHeader "Success Reporting Implementation"
$result23 = Test-Command "Advanced server functions should report success properly" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    
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
    
    return $missingPatterns.Count -eq 0
}
Write-TestResult "Success reporting implementation" $result23

# Test 24: CLI Parameter Recognition
Write-TestHeader "CLI Parameter Recognition"
$result24 = Test-Command "CLI should recognize advanced server management parameters" {
    $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -RunServerHealthCheck -DownloadFolder $TestDownloadDir 2>&1
    return $output -match "Server Health Check" -or $output -match "No server JAR found"
}
Write-TestResult "CLI parameter recognition" $result24

# Test 25: Function Integration Test
Write-TestHeader "Function Integration Test"
$result25 = Test-Command "Advanced server functions should integrate with existing server functions" {
    $scriptContent = Get-Content $ModManagerPath -Raw
    
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
    
    return $missingPatterns.Count -eq 0
}
Write-TestResult "Function integration test" $result25

# Summary
Show-TestSummary "Advanced Server Management Tests"

# Log file verification
$expectedLogPath = Join-Path $TestOutputDir "$([IO.Path]::GetFileNameWithoutExtension($TestFileName)).log"
if (Test-Path $expectedLogPath) {
    Write-Host "✓ Console log created: $expectedLogPath" -ForegroundColor Green
} else {
    Write-Host "✗ Console log missing: $expectedLogPath" -ForegroundColor Red
}

return ($script:TestResults.Failed -eq 0) 