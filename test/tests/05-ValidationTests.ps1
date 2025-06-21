# Validation Tests
# Tests validation of system entry downloads and file existence verification

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = $MyInvocation.MyCommand.Name
Write-Host "Minecraft Mod Manager - Validation Tests" -ForegroundColor $Colors.Header
Write-Host "=======================================" -ForegroundColor $Colors.Header

# Note: This test file can be run independently as it sets up its own database

Initialize-TestEnvironment -TestFileName $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestDownloadDir = Join-Path $TestOutputDir "download/1.21.5"

# Test 1: Validate each type download ensures file exists
Write-TestHeader "Validate System Entry and Mod Downloads"

# Add system entries and a regular mod
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.5' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Add Fabric Installer" 1 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Fabric Server Launcher' -AddModType 'launcher' -AddModGameVersion '1.21.5' -AddModUrl 'https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar' -AddModVersion '1.0.3' -AddModJar 'fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar' -DatabaseFile '$TestDbPath'" "Add Fabric Server Launcher" 2 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Minecraft Server' -AddModType 'server' -AddModGameVersion '1.21.5' -AddModUrl 'https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar' -AddModVersion '1.21.5' -AddModJar 'minecraft_server.1.21.5.jar' -DatabaseFile '$TestDbPath'" "Add Minecraft Server" 3 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModUrl 'https://modrinth.com/mod/litematica' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Litematica Mod" 4 $null $TestFileName

# Download all
Test-Command "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -DownloadFolder '$TestDownloadDir' -UseCachedResponses" "Download All Types" 4 $null $TestFileName

# Validate files exist
$expectedFiles = @(
    "$TestDownloadDir/installer/fabric-installer-1.0.3.exe",
    "$TestDownloadDir/minecraft_server.1.21.5.jar"
)

$missing = $false
foreach ($file in $expectedFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "✗ FAIL: Missing expected file: $file" -ForegroundColor Red
        $missing = $true
    } else {
        Write-Host "✓ PASS: Found $file" -ForegroundColor Green
    }
}

# Check for at least one mod jar in mods folder
$modFiles = Get-ChildItem "$TestDownloadDir/mods" -File -Filter *.jar -ErrorAction SilentlyContinue
if ($modFiles.Count -ge 1) {
    Write-Host "✓ PASS: Found mod jar in mods folder" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: No mod jar found in mods folder" -ForegroundColor Red
    $missing = $true
}

if ($missing) { 
    Write-Host "Validation tests failed!" -ForegroundColor Red
    exit 1 
} else {
    Write-Host "✓ PASS: All validation tests passed" -ForegroundColor Green
}

Write-Host "`nValidation Tests Complete" -ForegroundColor $Colors.Info 