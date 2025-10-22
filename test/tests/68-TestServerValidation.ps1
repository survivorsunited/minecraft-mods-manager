# Server Validation Tests
# Tests server download, mod validation, and server startup with current mods

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "68-TestServerValidation.ps1"

# Initialize test environment
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"

Write-Host "Minecraft Mod Manager - Server Validation Tests" -ForegroundColor $Colors.Header
Write-Host "===============================================" -ForegroundColor $Colors.Header

function Invoke-TestServerValidation {
    param([string]$TestFileName = $null)
    
    # Set up test directories
    $TestServerDir = Join-Path $TestDownloadDir "1.21.6"
    $TestDbPath = Join-Path $TestOutputDir "server-validation.csv"

Write-TestHeader "Test Environment Setup"

# Create isolated test database with server-side mods AND server/launcher entries
# Empty URLs will trigger auto-resolution
$serverModlistContent = @'
Group,Type,GameVersion,ID,Loader,Version,Name,Description,Jar,Url,Category,VersionUrl,LatestVersionUrl,LatestVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,LatestGameVersion,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
system,server,1.21.6,minecraft-server,vanilla,1.21.6,Minecraft Server 1.21.6,Official Minecraft server,minecraft_server.1.21.6.jar,,Infrastructure,,,,mojang,mojang,,,required,required,Minecraft Server,Official server software,,,,,,,,,,,
system,launcher,1.21.6,fabric-launcher,fabric,0.17.3,Fabric Server Launcher 1.21.6,Fabric server launcher,fabric-server-mc.1.21.6-loader.0.17.3-launcher.1.1.0.jar,,Infrastructure,,,,fabric,fabric,,,required,required,Fabric Launcher,Fabric server launcher,,,,,,,,,,,
required,mod,1.21.6,fabric-api,fabric,0.114.0+1.21.6,Fabric API,Essential hooks for modding with Fabric,fabric-api-0.114.0+1.21.6.jar,https://modrinth.com/mod/fabric-api,Core Library,https://cdn.modrinth.com/data/P7dR8mSH/versions/fabric-api-0.114.0+1.21.6.jar,,,modrinth,modrinth,,,required,required,Fabric API,Essential hooks for modding with Fabric,,,,,,,,,,,
required,mod,1.21.6,lithium,fabric,mc1.21.6-0.14.6,Lithium,Server optimization mod,lithium-fabric-0.14.6+mc1.21.6.jar,https://modrinth.com/mod/lithium,Performance,https://cdn.modrinth.com/data/gvQqBUqZ/versions/mc1.21.6-0.14.6.jar,,,modrinth,modrinth,,,optional,required,Lithium,Server optimization mod,,,,,,,,,,,
required,mod,1.21.6,ledger,fabric,1.3.5,Ledger,Server logging mod,ledger-1.3.5.jar,https://modrinth.com/mod/ledger,Utility,https://cdn.modrinth.com/data/LVN9ygNV/versions/1.3.5.jar,,,modrinth,modrinth,,,optional,required,Ledger,Server logging mod,,,,,,,,,,,
'@

$serverModlistContent | Out-File -FilePath $TestDbPath -Encoding UTF8

Write-Host ""
Write-Host "  🔍 DEBUG: Database Creation" -ForegroundColor Cyan
Write-Host "    Database path: $TestDbPath" -ForegroundColor Gray
Write-Host "    Database exists: $(Test-Path $TestDbPath)" -ForegroundColor Gray

if (Test-Path $TestDbPath) {
    $dbContent = Get-Content $TestDbPath
    Write-Host "    Database lines: $($dbContent.Count)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    📊 DATABASE CONTENTS:" -ForegroundColor Cyan
    $dbContent | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    Write-Host ""
    
    # Parse and validate CSV structure
    try {
        $csvData = Import-Csv -Path $TestDbPath
        Write-Host "    CSV rows parsed: $($csvData.Count)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "    📊 PARSED DATA ANALYSIS:" -ForegroundColor Cyan
        foreach ($row in $csvData) {
            Write-Host "      - $($row.Name)" -ForegroundColor Gray
            Write-Host "        Type: $($row.Type)" -ForegroundColor DarkGray
            Write-Host "        ID: $($row.ID)" -ForegroundColor DarkGray
            Write-Host "        Version: [$($row.Version)]" -ForegroundColor $(if ($row.Version) { "Green" } else { "Red" })
            Write-Host "        GameVersion: [$($row.GameVersion)]" -ForegroundColor $(if ($row.GameVersion) { "Green" } else { "Red" })
            Write-Host "        Url: [$($row.Url)]" -ForegroundColor $(if ($row.Url) { "DarkGray" } else { "Yellow" })
        }
    } catch {
        Write-Host "    ❌ CSV PARSE ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

Write-TestResult "Test Database Created" (Test-Path $TestDbPath)
Write-Host "  Using isolated test database (5 entries: 3 mods + server + launcher)" -ForegroundColor Gray

# Test 1: Validate All Mods
Write-TestHeader "Test 1: Validate All Current Mods"

Write-Host "  Validating all mods in database..." -ForegroundColor Gray
$validationOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -DatabaseFile $TestDbPath -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Parse validation results
$validationCompleted = ($validationOutput -match "Update Summary").Count -gt 0
$validationErrors = ($validationOutput | Select-String "Errors: (\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -as [int]
$validationWarnings = ($validationOutput | Select-String "Warnings: (\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -as [int]

Write-TestResult "Validation Completed" $validationCompleted

if ($validationCompleted) {
    Write-Host "  Validation Results:" -ForegroundColor Gray
    Write-Host "    Errors: $validationErrors" -ForegroundColor $(if ($validationErrors -gt 0) { "Red" } else { "Green" })
    Write-Host "    Warnings: $validationWarnings" -ForegroundColor $(if ($validationWarnings -gt 0) { "Yellow" } else { "Green" })
    
    # Check if there are any critical errors
    $hasCriticalErrors = $validationErrors -gt 0
    Write-TestResult "No Critical Validation Errors" (-not $hasCriticalErrors)
    
    if ($hasCriticalErrors) {
        Write-Host "  ⚠️ Critical errors found - server may not start properly" -ForegroundColor Red
        # Show error details
        $errorLines = $validationOutput | Select-String "ERROR|FAIL" | Select-Object -First 5
        foreach ($errorLine in $errorLines) {
            Write-Host "    $($errorLine.Line)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ❌ Validation failed to complete" -ForegroundColor Red
}

# Test 2: Download Server Files
Write-TestHeader "Test 2: Download Server Files"

Write-Host "  Downloading server files to: $TestDownloadDir" -ForegroundColor Gray
$serverDownloadOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadServer -DownloadFolder $TestDownloadDir -DatabaseFile $TestDbPath -TargetVersion "1.21.6" 2>&1

# Check server download results
$serverDownloadAttempted = ($serverDownloadOutput -match "Starting server files download process").Count -gt 0
$minecraftServerExists = Test-Path (Join-Path $TestServerDir "minecraft_server.1.21.6.jar")
$fabricServerExists = Test-Path (Join-Path $TestServerDir "fabric-server*.jar")

Write-TestResult "Server Download Started" $serverDownloadAttempted
Write-TestResult "Minecraft Server Downloaded" $minecraftServerExists
Write-TestResult "Fabric Server Downloaded" $fabricServerExists

if ($minecraftServerExists -and $fabricServerExists) {
    Write-Host "  ✓ Server files ready for mod testing" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Server files incomplete - mod testing may fail" -ForegroundColor Yellow
}

# Test 3: Download Mods to Server
Write-TestHeader "Test 3: Download Mods for Server"

Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  DETAILED LOGGING: Mod Download Process" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

# Check API key status (informational only - not used by Modrinth API)
Write-Host "  🔑 API KEY STATUS:" -ForegroundColor Yellow
if ($env:MODRINTH_API_KEY) {
    Write-Host "    ✅ MODRINTH_API_KEY: PRESENT (length: $($env:MODRINTH_API_KEY.Length))" -ForegroundColor Green
} else {
    Write-Host "    ⚠️  MODRINTH_API_KEY: MISSING (not required - Modrinth API works without auth)" -ForegroundColor Yellow
}

if ($env:CURSEFORGE_API_KEY) {
    Write-Host "    ✅ CURSEFORGE_API_KEY: PRESENT (length: $($env:CURSEFORGE_API_KEY.Length))" -ForegroundColor Green
} else {
    Write-Host "    ❌ CURSEFORGE_API_KEY: MISSING (cannot download CurseForge mods)" -ForegroundColor Red
}
Write-Host ""

$modDownloadDir = Join-Path $TestServerDir "mods"
Write-Host "  📁 Target Directory: $modDownloadDir" -ForegroundColor Gray
Write-Host "  📊 Database: $TestDbPath" -ForegroundColor Gray
Write-Host "  🗂️  API Response Cache: $script:TestApiResponseDir" -ForegroundColor Gray
Write-Host ""

Write-Host "  🚀 EXECUTING DOWNLOAD COMMAND..." -ForegroundColor Yellow
Write-Host "  📝 Passing BASE download folder (not mods subfolder): $TestDownloadDir" -ForegroundColor Gray
Write-Host "  📝 Targeting version 1.21.6 explicitly" -ForegroundColor Gray
$modDownloadOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadMods -DatabaseFile $TestDbPath -DownloadFolder $TestDownloadDir -TargetVersion "1.21.6" -ApiResponseFolder $script:TestApiResponseDir 2>&1

Write-Host ""
Write-Host "  📊 DOWNLOAD RESULTS ANALYSIS:" -ForegroundColor Yellow

# Check mod download results
$modDownloadAttempted = ($modDownloadOutput -match "Starting mod download process").Count -gt 0
$modsDownloaded = 0
if (Test-Path $modDownloadDir) {
    $modsDownloaded = (Get-ChildItem -Path $modDownloadDir -Filter "*.jar" -ErrorAction SilentlyContinue).Count
}

Write-Host "    Download process started: $modDownloadAttempted" -ForegroundColor Gray
Write-Host "    JARs found in mods folder: $modsDownloaded" -ForegroundColor Gray

# Show detailed download output
Write-Host ""
Write-Host "  📝 DOWNLOAD COMMAND OUTPUT (last 20 lines):" -ForegroundColor Yellow
$modDownloadOutput | Select-Object -Last 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
Write-Host ""

Write-TestResult "Mod Download Started" $modDownloadAttempted
Write-TestResult "Mods Downloaded Successfully" ($modsDownloaded -gt 0)

if ($modsDownloaded -gt 0) {
    Write-Host "  Downloaded $modsDownloaded mod JAR files" -ForegroundColor Green
    
    # List downloaded mods
    if (Test-Path $modDownloadDir) {
        $modFiles = Get-ChildItem -Path $modDownloadDir -Filter "*.jar" | Select-Object -First 10
        Write-Host "  Mod files:" -ForegroundColor Gray
        foreach ($modFile in $modFiles) {
            Write-Host "    - $($modFile.Name)" -ForegroundColor Gray
        }
        if ($modsDownloaded -gt 10) {
            Write-Host "    ... and $($modsDownloaded - 10) more" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  ❌ No mods downloaded - check validation errors" -ForegroundColor Red
}

# Test 4: Add Server Start Script
Write-TestHeader "Test 4: Add Server Start Script"

$startScriptOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddServerStartScript -DownloadFolder $TestDownloadDir -TargetVersion "1.21.6" 2>&1
$startScriptExists = Test-Path (Join-Path $TestServerDir "start-server.ps1")

Write-TestResult "Start Script Created" $startScriptExists

if ($startScriptExists) {
    Write-Host "  ✓ Server start script ready" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Start script missing - manual server start required" -ForegroundColor Yellow
}

# Test 5: Server Configuration Validation
Write-TestHeader "Test 5: Server Configuration Validation"

# Check for required files
$eulaPath = Join-Path $TestServerDir "eula.txt"
$serverPropertiesPath = Join-Path $TestServerDir "server.properties"
$worldDirPath = Join-Path $TestServerDir "world"

# Create EULA file for testing (required for server to start)
if (-not (Test-Path $eulaPath)) {
    "eula=true" | Out-File -FilePath $eulaPath -Encoding UTF8
}

$eulaExists = Test-Path $eulaPath
$serverPropertiesExists = Test-Path $serverPropertiesPath
$hasWorldDir = Test-Path $worldDirPath

Write-TestResult "EULA File Present" $eulaExists
Write-TestResult "Server Properties Exist" $serverPropertiesExists

# Check mod compatibility
$fabricApiDownloaded = (Get-ChildItem -Path $modDownloadDir -Filter "*fabric-api*" -ErrorAction SilentlyContinue).Count -gt 0
Write-TestResult "Fabric API Present" $fabricApiDownloaded

# Test 6: Quick Server Start Test (Non-Interactive)
Write-TestHeader "Test 6: Quick Server Start Test"

if ($startScriptExists -and $eulaExists -and $modsDownloaded -gt 0) {
    Write-Host "  Testing server startup (quick test - 30 seconds max)..." -ForegroundColor Gray
    
    try {
        # Change to server directory
        Push-Location $TestServerDir
        
        # Start server with timeout for testing
        $serverProcess = Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile", "-File", "start-server.ps1" -PassThru -WindowStyle Hidden
        
        # Wait up to 30 seconds for server to start
        $timeout = 30
        $started = $false
        
        for ($i = 0; $i -lt $timeout; $i++) {
            Start-Sleep -Seconds 1
            
            # Check for server startup indicators
            if (Test-Path "logs\latest.log") {
                $logContent = Get-Content "logs\latest.log" -ErrorAction SilentlyContinue
                if ($logContent -match "Done \(" -or $logContent -match "Fabric API") {
                    $started = $true
                    break
                }
            }
            
            # Check if process is still running
            if ($serverProcess.HasExited) {
                break
            }
        }
        
        # Stop the server process
        if (-not $serverProcess.HasExited) {
            $serverProcess.Kill()
            $serverProcess.WaitForExit(5000)
        }
        
        Write-TestResult "Server Started Successfully" $started
        
        if ($started) {
            Write-Host "  ✓ Server started with mods loaded" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ Server start timeout or failed - check logs" -ForegroundColor Yellow
        }
        
    } catch {
        Write-TestResult "Server Start Test" $false
        Write-Host "  ❌ Server start test failed: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Pop-Location
    }
} else {
    Write-TestResult "Server Start Test" $false
    Write-Host "  ⚠️ Skipping server start test - missing dependencies" -ForegroundColor Yellow
}

# Test 7: Server Health Check
Write-TestHeader "Test 7: Server Health Check"

$healthCheckResults = @()

# Check disk space
$serverDirSize = 0
if (Test-Path $TestServerDir) {
    $serverDirSize = (Get-ChildItem -Path $TestServerDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
}

$healthCheckResults += "Server directory size: $([math]::Round($serverDirSize, 2)) MB"

# Check mod conflicts (basic check)
$conflictingMods = @()
if (Test-Path $modDownloadDir) {
    $modFiles = Get-ChildItem -Path $modDownloadDir -Filter "*.jar"
    
    # Check for common conflicts
    $fabricApiCount = ($modFiles | Where-Object { $_.Name -match "fabric-api" }).Count
    $sodiumCount = ($modFiles | Where-Object { $_.Name -match "sodium" }).Count
    $lithiumCount = ($modFiles | Where-Object { $_.Name -match "lithium" }).Count
    
    if ($fabricApiCount -gt 1) { $conflictingMods += "Multiple Fabric API versions" }
    if ($sodiumCount -gt 1) { $conflictingMods += "Multiple Sodium versions" }
    if ($lithiumCount -gt 1) { $conflictingMods += "Multiple Lithium versions" }
}

$hasConflicts = $conflictingMods.Count -gt 0
Write-TestResult "No Mod Conflicts Detected" (-not $hasConflicts)

if ($hasConflicts) {
    Write-Host "  ⚠️ Potential conflicts detected:" -ForegroundColor Yellow
    foreach ($conflict in $conflictingMods) {
        Write-Host "    - $conflict" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✓ No obvious mod conflicts found" -ForegroundColor Green
}

# Check Java requirements
$javaVersion = $null
try {
    $javaOutput = java -version 2>&1
    if ($javaOutput -match "version `"(\d+)") {
        $javaVersion = [int]$Matches[1]
    }
} catch {
    # Java not found
}

$javaCompatible = $javaVersion -ge 17
Write-TestResult "Java 17+ Available" $javaCompatible

if ($javaCompatible) {
    Write-Host "  ✓ Java $javaVersion detected (compatible)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Java 17+ required for Minecraft 1.21.6" -ForegroundColor Yellow
}

# Display comprehensive results
Write-Host "`nServer Validation Summary:" -ForegroundColor $Colors.Info
Write-Host "=============================" -ForegroundColor $Colors.Info

Write-Host "Environment:" -ForegroundColor Gray
Write-Host "  Server Directory: $TestServerDir" -ForegroundColor Gray
Write-Host "  Mods Directory: $modDownloadDir" -ForegroundColor Gray
Write-Host "  Database: $TestDbPath" -ForegroundColor Gray

Write-Host "`nServer Status:" -ForegroundColor Gray
foreach ($result in $healthCheckResults) {
    Write-Host "  $result" -ForegroundColor Gray
}

Write-Host "`nMod Status:" -ForegroundColor Gray
Write-Host "  Total mods: $modsDownloaded" -ForegroundColor Gray
Write-Host "  Validation errors: $validationErrors" -ForegroundColor Gray
Write-Host "  Validation warnings: $validationWarnings" -ForegroundColor Gray

if ($validationErrors -eq 0 -and $modsDownloaded -gt 0 -and $minecraftServerExists -and $fabricServerExists) {
    Write-Host "`n🎉 Server is ready for deployment!" -ForegroundColor Green
} elseif ($validationErrors -gt 0) {
    Write-Host "`n⚠️ Server has validation issues - review errors before deployment" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ Server setup incomplete - missing required components" -ForegroundColor Red
}

    Show-TestSummary "Server Validation Tests"
    
    Write-Host "`nServer Validation Tests Complete" -ForegroundColor $Colors.Info
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestServerValidation -TestFileName $TestFileName