# Filename Handling Tests
# Tests filename cleaning, system entry filename handling, and external modification detection

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = $MyInvocation.MyCommand.Name
Write-Host "Minecraft Mod Manager - Filename Handling Tests" -ForegroundColor $Colors.Header
Write-Host "===============================================" -ForegroundColor $Colors.Header

# Note: This test file can be run independently as it sets up its own database

Initialize-TestEnvironment -TestFileName $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestDownloadDir = Join-Path $TestOutputDir "download"

# Test 1: Test shaderpack filename cleaning (add a shaderpack with URL-encoded filename)
Write-TestHeader "Test Shaderpack Filename Cleaning"
Test-Command "& '$ModManagerPath' -AddMod -AddModUrl 'https://modrinth.com/shader/astralex' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add AstraLex Shaderpack" 1 $null $TestFileName

# Test 2: Test system entry filename handling (verify Jar column is used)
Write-TestHeader "Test System Entry Filename Handling"
# Add a system entry with a specific Jar filename
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Test Server' -AddModType 'server' -AddModGameVersion '1.21.6' -AddModUrl 'https://example.com/server.jar' -AddModVersion '1.21.6' -AddModJar 'test_server_1.21.6.jar' -DatabaseFile '$TestDbPath'" "Add Test Server with Jar filename" 2 $null $TestFileName

# Test 3: Verify downloaded files have correct names
Write-TestHeader "Verify Downloaded File Names"
$verifyFilesCmd = 'Get-ChildItem "' + $TestDownloadDir + '" -Recurse -File | Where-Object { $_.Name -match "fabric-installer|fabric-server|minecraft_server|astralex|bsl|complementary" } | Select-Object Name, FullName'
$verifyFilesTestName = "Verify Downloaded File Names"
Test-Command $verifyFilesCmd $verifyFilesTestName 0 $null $TestFileName

# Test 4: Simulate external update to Fabric API version
Write-TestHeader "Detect External Fabric Version Update"
# Add Fabric API first
Test-Command "& '$ModManagerPath' -AddMod -AddModUrl 'https://modrinth.com/mod/fabric-api' -DatabaseFile '$TestDbPath' -UseCachedResponses" "Add Fabric API" 3 $null $TestFileName

# Manually update the Fabric API version in the CSV (simulate external edit)
$csv = Import-Csv $TestDbPath
foreach ($row in $csv) {
    if ($row.ID -eq "fabric-api") {
        $row.Version = "0.127.1+1.21.5"
    }
}
$csv | Export-Csv $TestDbPath -NoTypeInformation

# Run GetModList to trigger hash check and warning
Test-Command "& '$ModManagerPath' -GetModList -DatabaseFile '$TestDbPath'" "Detect Fabric API Version Hash Mismatch" 3 $null $TestFileName

# Test 5: Fabric Installer should be downloaded as .exe, not .jar
Write-TestHeader "Fabric Installer Downloaded as EXE"
# Add Fabric Installer system entry with .exe URL
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.5' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Add Fabric Installer EXE" 4 $null $TestFileName

# Download mods
Test-Command "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -DownloadFolder '$TestDownloadDir'" "Download Mods with Installer" 4 $null $TestFileName

# Check that Fabric Installer was downloaded as .exe
$installerFile = Get-ChildItem $TestDownloadDir -Recurse -File | Where-Object { $_.Name -like 'fabric-installer*.exe' }
if ($installerFile) {
    Write-Host "✓ PASS: Fabric Installer downloaded as EXE: $($installerFile.FullName)" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Fabric Installer not downloaded as EXE" -ForegroundColor Red
}

Write-Host "`nFilename Handling Tests Complete" -ForegroundColor $Colors.Info 