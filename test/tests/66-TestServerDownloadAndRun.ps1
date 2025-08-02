# Server Download and Run Tests
# Tests that server download, mod installation, and server startup work correctly

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "66-TestServerDownloadAndRun.ps1"

Write-Host "Minecraft Mod Manager - Server Download and Run Tests" -ForegroundColor $Colors.Header
Write-Host "====================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"

# Set up test directories
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestDbPath = Join-Path $TestOutputDir "server-test.csv"

Write-TestHeader "Test Environment Setup"

# Create test database with server-side mods
$serverModlistContent = @'
Group,Type,GameVersion,ID,Loader,Version,Name,Description,Jar,Url,Category,VersionUrl,LatestVersionUrl,LatestVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,LatestGameVersion,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
required,mod,1.21.6,fabric-api,fabric,latest,Fabric API,Essential hooks for modding with Fabric,fabric-api.jar,https://modrinth.com/mod/fabric-api,Core Library,,,,modrinth,modrinth,,,required,required,Fabric API,Essential hooks for modding with Fabric,,,,,,,,,,,
required,mod,1.21.6,lithium,fabric,latest,Lithium,Server optimization mod,lithium.jar,https://modrinth.com/mod/lithium,Performance,,,,modrinth,modrinth,,,optional,required,Lithium,Server optimization mod,,,,,,,,,,,
required,mod,1.21.6,ledger,fabric,latest,Ledger,Server logging mod,ledger.jar,https://modrinth.com/mod/ledger,Utility,,,,modrinth,modrinth,,,optional,required,Ledger,Server logging mod,,,,,,,,,,,
'@

$serverModlistContent | Out-File -FilePath $TestDbPath -Encoding UTF8
Write-TestResult "Test Database Created" (Test-Path $TestDbPath)

Write-Host "  Server-side mods configured:" -ForegroundColor Gray
Write-Host "    - Fabric API (required)" -ForegroundColor Gray
Write-Host "    - Lithium (performance)" -ForegroundColor Gray
Write-Host "    - Ledger (logging)" -ForegroundColor Gray

# Test 1: Download Server Files
Write-TestHeader "Test 1: Download Server Files"

$serverDownloadOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadServer -DownloadFolder $TestDownloadDir 2>&1

# Check if server download was attempted
$serverDownloadAttempted = ($serverDownloadOutput -match "Starting server files download process").Count -gt 0
Write-TestResult "Server Download Process Started" $serverDownloadAttempted

# Check if server jar file was downloaded (or attempted)
$expectedServerPath = Join-Path $TestDownloadDir "1.21.6"
$serverFilesPresent = Test-Path $expectedServerPath

Write-TestResult "Server Directory Created" $serverFilesPresent

if ($serverFilesPresent) {
    $serverJarFiles = Get-ChildItem -Path $expectedServerPath -Name "*.jar" | Where-Object { $_ -like "*server*" }
    $serverJarDownloaded = $serverJarFiles.Count -gt 0
    Write-TestResult "Server JAR Downloaded" $serverJarDownloaded
    
    if ($serverJarDownloaded) {
        Write-Host "  Downloaded server JAR: $($serverJarFiles[0])" -ForegroundColor Green
    }
}

# Test 2: Download Mods for Server
Write-TestHeader "Test 2: Download Server Mods"

$modsDownloadOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -DownloadMods -DatabaseFile $TestDbPath -DownloadFolder $TestDownloadDir -UseCachedResponses -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Check if mod download was attempted
$modsDownloadAttempted = ($modsDownloadOutput -match "Starting mod download process").Count -gt 0
Write-TestResult "Mods Download Process Started" $modsDownloadAttempted

# Check if mods directory was created
$expectedModsPath = Join-Path $expectedServerPath "mods"
$modsDirectoryCreated = Test-Path $expectedModsPath

Write-TestResult "Mods Directory Created" $modsDirectoryCreated

if ($modsDirectoryCreated) {
    $modJarFiles = Get-ChildItem -Path $expectedModsPath -Name "*.jar" -ErrorAction SilentlyContinue
    $modJarsDownloaded = $modJarFiles.Count -gt 0
    Write-TestResult "Mod JARs Downloaded" $modJarsDownloaded
    
    if ($modJarsDownloaded) {
        Write-Host "  Downloaded $($modJarFiles.Count) mod JAR(s):" -ForegroundColor Green
        $modJarFiles | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
    }
}

# Test 3: Add Server Start Script
Write-TestHeader "Test 3: Add Server Start Script"

$startScriptOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -AddServerStartScript -DownloadFolder $TestDownloadDir 2>&1

# Check if start script creation was attempted
$startScriptAttempted = ($startScriptOutput -match "Adding server start script").Count -gt 0
Write-TestResult "Start Script Creation Attempted" $startScriptAttempted

# Check if start script files were created
$startScriptFiles = @()
if (Test-Path $expectedServerPath) {
    $startScriptFiles = @()
    $startScriptFiles += Get-ChildItem -Path $expectedServerPath -Filter "start-server.*" -ErrorAction SilentlyContinue
    $startScriptFiles += Get-ChildItem -Path $expectedServerPath -Filter "run.*" -ErrorAction SilentlyContinue
    $startScriptFiles += Get-ChildItem -Path $expectedServerPath -Filter "start.*" -ErrorAction SilentlyContinue
}

$startScriptCreated = $startScriptFiles.Count -gt 0
Write-TestResult "Start Script Created" $startScriptCreated

if ($startScriptCreated) {
    Write-Host "  Created start script(s):" -ForegroundColor Green
    $startScriptFiles | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
}

# Test 4: Validate Server Configuration
Write-TestHeader "Test 4: Validate Server Configuration"

$serverConfigValid = $true
$configIssues = @()

# Check for essential files
$essentialFiles = @(
    @{ Path = $expectedServerPath; Name = "Server directory" },
    @{ Path = $expectedModsPath; Name = "Mods directory" }
)

foreach ($file in $essentialFiles) {
    if (-not (Test-Path $file.Path)) {
        $serverConfigValid = $false
        $configIssues += "Missing: $($file.Name)"
    }
}

# Check for server properties or other config files
if (Test-Path $expectedServerPath) {
    $configFiles = @()
    $configFiles += Get-ChildItem -Path $expectedServerPath -Filter "server.properties" -ErrorAction SilentlyContinue
    $configFiles += Get-ChildItem -Path $expectedServerPath -Filter "eula.txt" -ErrorAction SilentlyContinue
    $configFiles += Get-ChildItem -Path $expectedServerPath -Filter "*.yml" -ErrorAction SilentlyContinue
    $configFiles += Get-ChildItem -Path $expectedServerPath -Filter "*.yaml" -ErrorAction SilentlyContinue
    $hasConfigFiles = $configFiles.Count -gt 0
    
    if ($hasConfigFiles) {
        Write-Host "  Found configuration files:" -ForegroundColor Green
        $configFiles | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
    }
}

Write-TestResult "Server Configuration Valid" $serverConfigValid

if ($configIssues.Count -gt 0) {
    Write-Host "  Configuration issues:" -ForegroundColor Red
    $configIssues | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}

# Test 5: Dry Run Server Start (Don't actually start the server)
Write-TestHeader "Test 5: Server Start Preparation Check"

# We won't actually start the server, but we'll check if the start command would work
$serverStartPreparationValid = $true

# Check if we have a server JAR
if (Test-Path $expectedServerPath) {
    $serverJars = Get-ChildItem -Path $expectedServerPath -Name "*.jar" | Where-Object { $_ -like "*server*" -or $_ -like "*minecraft*" }
    $hasServerJar = $serverJars.Count -gt 0
    
    if (-not $hasServerJar) {
        $serverStartPreparationValid = $false
        Write-Host "  ❌ No server JAR found" -ForegroundColor Red
    } else {
        Write-Host "  ✓ Server JAR available: $($serverJars[0])" -ForegroundColor Green
    }
    
    # Check if we have mods
    if (Test-Path $expectedModsPath) {
        $modCount = (Get-ChildItem -Path $expectedModsPath -Name "*.jar" -ErrorAction SilentlyContinue).Count
        Write-Host "  ✓ Mods directory has $modCount JAR file(s)" -ForegroundColor Green
    }
    
    # Check for Fabric loader (required for Fabric mods)
    $fabricFiles = Get-ChildItem -Path $expectedServerPath -Name "*fabric*" -ErrorAction SilentlyContinue
    if ($fabricFiles.Count -gt 0) {
        Write-Host "  ✓ Fabric loader files detected" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  No Fabric loader detected (may need to be installed separately)" -ForegroundColor Yellow
    }
}

Write-TestResult "Server Start Preparation Valid" $serverStartPreparationValid

# Test 6: File Permissions and Structure
Write-TestHeader "Test 6: File Permissions and Structure"

$permissionsValid = $true

if (Test-Path $expectedServerPath) {
    # Check if we can write to the server directory (needed for logs, world files, etc.)
    try {
        $testFile = Join-Path $expectedServerPath "test-write-permission.tmp"
        "test" | Out-File -FilePath $testFile -Encoding UTF8
        Remove-Item -Path $testFile -Force
        Write-Host "  ✓ Server directory is writable" -ForegroundColor Green
    } catch {
        $permissionsValid = $false
        Write-Host "  ❌ Server directory is not writable" -ForegroundColor Red
    }
    
    # Check directory structure
    $expectedDirs = @("mods")
    foreach ($dir in $expectedDirs) {
        $dirPath = Join-Path $expectedServerPath $dir
        if (Test-Path $dirPath) {
            Write-Host "  ✓ Directory exists: $dir" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Directory missing: $dir" -ForegroundColor Yellow
        }
    }
}

Write-TestResult "File Permissions Valid" $permissionsValid

# Show detailed results for debugging
Write-Host "`nDetailed Test Results:" -ForegroundColor $Colors.Info
Write-Host "========================" -ForegroundColor $Colors.Info

Write-Host "Test Directories:" -ForegroundColor Gray
Write-Host "  Download Dir: $TestDownloadDir" -ForegroundColor Gray
Write-Host "  Server Dir: $expectedServerPath" -ForegroundColor Gray
Write-Host "  Mods Dir: $expectedModsPath" -ForegroundColor Gray

if (Test-Path $TestDownloadDir) {
    Write-Host "`nDownload Directory Contents:" -ForegroundColor Gray
    Get-ChildItem -Path $TestDownloadDir -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Replace($TestDownloadDir, "").TrimStart("\", "/")
        Write-Host "  $relativePath" -ForegroundColor Gray
    }
}

Write-Host "`nServer Download Output Sample:" -ForegroundColor Gray
$serverDownloadOutput | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}

Write-Host "`nMods Download Output Sample:" -ForegroundColor Gray
$modsDownloadOutput | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}

Show-TestSummary "Server Download and Run Tests"

Write-Host "`nServer Download and Run Tests Complete" -ForegroundColor $Colors.Info
Write-Host "Note: Actual server startup was skipped to avoid hanging the test." -ForegroundColor Yellow

return ($script:TestResults.Failed -eq 0)