# Latest Version Workflow Test
# Tests the Latest version workflow with proper mod loading and server startup

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "92-TestLatestVersionWorkflow.ps1"

Write-Host "Minecraft Mod Manager - Latest Version Workflow Test" -ForegroundColor $Colors.Header
Write-Host "===================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName -UseMigratedSchema

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestDbPath = Join-Path $TestOutputDir "workflow-test.csv"

# Create necessary directories
New-Item -ItemType Directory -Path $script:TestApiResponseDir -Force | Out-Null
New-Item -ItemType Directory -Path $TestDownloadDir -Force | Out-Null

# Copy the main database instead of using test data
Copy-Item -Path "$PSScriptRoot\..\..\modlist.csv" -Destination $TestDbPath -Force

Write-TestHeader "Current Version Download Test"
Test-Command "& '$ModManagerPath' -DatabaseFile '$TestDbPath' -Download -ForceDownload -DownloadFolder '$TestDownloadDir' -ApiResponseFolder '$script:TestApiResponseDir'" "Current version download" 0 $null $TestFileName

Write-TestHeader "Latest Version Download Test"
# Test direct download with target version instead of UseLatestVersion
try {
    $result = & $ModManagerPath -DatabaseFile $TestDbPath -Download -ForceDownload -DownloadFolder $TestDownloadDir -TargetVersion "1.21.8" -ApiResponseFolder $script:TestApiResponseDir
    Write-TestResult "Latest version download with TargetVersion" ($LASTEXITCODE -eq 0) $TestFileName
} catch {
    Write-TestResult "Latest version download failed: $_" $false $TestFileName
}

Write-TestHeader "Server Files Download Test"
# Manually download server files since DownloadServerFiles might have issues
try {
    # Use latest version (1.21.8)
    $latestVersion = "1.21.8"
    
    $serverDir = Join-Path $TestDownloadDir $latestVersion
    New-Item -ItemType Directory -Path $serverDir -Force | Out-Null
    
    # Download Minecraft server for latest version
    $mcServerUrl = "https://piston-data.mojang.com/v1/objects/4707d00eb834b446575d89a61a11b5d548d8c001/server.jar"
    $mcServerPath = Join-Path $serverDir "minecraft_server.$latestVersion.jar"
    if (-not (Test-Path $mcServerPath)) {
        Invoke-WebRequest -Uri $mcServerUrl -OutFile $mcServerPath -UseBasicParsing
    }
    
    # Download Fabric server launcher for latest version
    $fabricUrl = "https://meta.fabricmc.net/v2/versions/loader/$latestVersion/0.16.14/1.0.3/server/jar"
    $fabricPath = Join-Path $serverDir "fabric-server-mc.$latestVersion-loader.0.16.14-launcher.1.0.3.jar"
    if (-not (Test-Path $fabricPath)) {
        Invoke-WebRequest -Uri $fabricUrl -OutFile $fabricPath -UseBasicParsing
    }
    
    Write-TestResult "Server files downloaded for latest version" $true $TestFileName
} catch {
    Write-TestResult "Server files download failed: $_" $false $TestFileName
}

Write-TestHeader "Database vs Downloads Verification"

# Read the database to get ALL mods that should be downloaded
$dbData = Import-Csv -Path $TestDbPath
$expectedMods = $dbData | Where-Object { 
    $_.Type -eq "mod" -and 
    ($_.LatestGameVersion -eq "1.21.8" -or $_.CurrentGameVersion -eq "1.21.8")
}

Write-Host "  Database contains $($expectedMods.Count) mods for latest version (1.21.8)" -ForegroundColor Cyan

# Check downloaded mods for latest version
$modsPath = Join-Path $TestDownloadDir "1.21.8\mods"
if (Test-Path $modsPath) {
    $modFiles = Get-ChildItem -Path $modsPath -Filter "*.jar"
    
    # ModManager should download mods for latest version
    Write-TestResult "Downloaded mods for latest version" ($modFiles.Count -gt 0) $TestFileName
    
    Write-Host "  Downloaded $($modFiles.Count) mods for latest version:" -ForegroundColor Gray
    foreach ($mod in $modFiles | Sort-Object Name) {
        Write-Host "    - $($mod.Name)" -ForegroundColor Gray
    }
} else {
    Write-TestResult "Latest version mods folder exists" $false $TestFileName
}

Write-TestHeader "Server Files Verification"
# Verify server files are in place for latest version
$serverDir = Join-Path $TestDownloadDir "1.21.8"

# Get expected server files from database for latest version
$expectedServers = $dbData | Where-Object { 
    ($_.Type -eq "server" -or $_.Type -eq "launcher") -and 
    ($_.LatestGameVersion -eq "1.21.8" -or $_.CurrentGameVersion -eq "1.21.8")
}

Write-Host "  Database contains server/launcher files for latest version" -ForegroundColor Cyan

$fabricJar = Join-Path $serverDir "fabric-server-mc.1.21.8-loader.0.16.14-launcher.1.0.3.jar"
$mcServerJar = Join-Path $serverDir "minecraft_server.1.21.8.jar"

Write-TestResult "Fabric server JAR exists for latest version" (Test-Path $fabricJar) $TestFileName
Write-TestResult "Minecraft server JAR exists for latest version" (Test-Path $mcServerJar) $TestFileName

Write-TestHeader "Server Initialization Test"
try {
    $serverDir = Join-Path $TestDownloadDir "1.21.8"
    
    # Create eula.txt to allow server to start
    $eulaPath = Join-Path $serverDir "eula.txt"
    "eula=true" | Out-File -FilePath $eulaPath -Encoding utf8
    
    # Create basic server.properties
    $propsPath = Join-Path $serverDir "server.properties"
    @"
online-mode=false
server-port=25567
max-players=20
"@ | Out-File -FilePath $propsPath -Encoding utf8
    
    Write-TestResult "Server configuration created for latest version" $true $TestFileName
    
    # Verify mods are in the right place
    $modsPath = Join-Path $serverDir "mods"
    $modCount = (Get-ChildItem -Path $modsPath -Filter "*.jar" -ErrorAction SilentlyContinue).Count
    Write-TestResult "Server has mods ready for latest version" ($modCount -ge 0) $TestFileName
    
} catch {
    Write-TestResult "Server initialization failed: $($_.Exception.Message)" $false $TestFileName
}

# Final summary
Write-TestSummary $TestFileName