# System Entries Tests
# Tests system-level functionality: help, validation, database operations

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

Write-Host "Minecraft Mod Manager - System Entries Tests" -ForegroundColor $Colors.Header
Write-Host "=============================================" -ForegroundColor $Colors.Header

# Note: This test file can be run independently as it sets up its own database

Initialize-TestEnvironment

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Test 1: Add system entries (installer, launcher, server) for different versions
Write-TestHeader "Add System Entries"
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.5' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Add Fabric Installer 1.21.5" 1 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.6' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Add Fabric Installer 1.21.6" 1 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Fabric Server Launcher' -AddModType 'launcher' -AddModGameVersion '1.21.5' -AddModUrl 'https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar' -AddModVersion '1.0.3' -AddModJar 'fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar' -DatabaseFile '$TestDbPath'" "Add Fabric Server Launcher 1.21.5" 2 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Fabric Server Launcher' -AddModType 'launcher' -AddModGameVersion '1.21.6' -AddModUrl 'https://meta.fabricmc.net/v2/versions/loader/1.21.6/0.16.14/1.0.3/server/jar' -AddModVersion '1.0.3' -AddModJar 'fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar' -DatabaseFile '$TestDbPath'" "Add Fabric Server Launcher 1.21.6" 3 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Minecraft Server' -AddModType 'server' -AddModGameVersion '1.21.5' -AddModUrl 'https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar' -AddModVersion '1.21.5' -AddModJar 'minecraft_server.1.21.5.jar' -DatabaseFile '$TestDbPath'" "Add Minecraft Server 1.21.5" 4 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Minecraft Server' -AddModType 'server' -AddModGameVersion '1.21.6' -AddModUrl 'https://piston-data.mojang.com/v1/objects/6e64dcabba3c01a7271b4fa6bd898483b794c59b/server.jar' -AddModVersion '1.21.6' -AddModJar 'minecraft_server.1.21.6.jar' -DatabaseFile '$TestDbPath'" "Add Minecraft Server 1.21.6" 5 $null $TestFileName

# Test 2: Test system entry filename handling (verify Jar column is used)
Write-TestHeader "Test System Entry Filename Handling"
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Test Server' -AddModType 'server' -AddModGameVersion '1.21.6' -AddModUrl 'https://example.com/server.jar' -AddModVersion '1.21.6' -AddModJar 'test_server_1.21.6.jar' -DatabaseFile '$TestDbPath'" "Add Test Server with Jar filename" 6 $null $TestFileName

# Test 3: Validate with UseLatestVersion (should detect majority version)
Write-TestHeader "Validate with UseLatestVersion"
Test-Command "& '$ModManagerPath' -ValidateAllModVersions -DatabaseFile '$TestDbPath' -UseLatestVersion -UseCachedResponses" "Validate with UseLatestVersion" 6 $null $TestFileName

# Test 4: Download with UseLatestVersion (should download latest mods and matching system files)
Write-TestHeader "Download with UseLatestVersion"
Test-Command "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -UseLatestVersion -UseCachedResponses" "Download with UseLatestVersion" 6 $null $TestFileName

# Test 5: Download with UseLatestVersion and validation
Write-TestHeader "Download with UseLatestVersion and Validation"
Test-Command "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -UseLatestVersion -ValidateWithDownload -UseCachedResponses" "Download with UseLatestVersion and Validation" 6 $null $TestFileName

# Test 6: Test missing system files scenario (remove some system entries)
Write-TestHeader "Test Missing System Files"
# Remove 1.21.6 system entries to test missing file reporting
$currentMods = Import-Csv $TestDbPath
$filteredMods = $currentMods | Where-Object { 
    -not ($_.Type -in @("installer", "launcher", "server") -and $_.GameVersion -eq "1.21.6") 
}
$filteredMods | Export-Csv $TestDbPath -NoTypeInformation

$missingSystemFilesCmd = "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -UseLatestVersion -UseCachedResponses"
$missingSystemFilesTestName = "Download with Missing System Files"
Test-Command $missingSystemFilesCmd $missingSystemFilesTestName 6 $null $TestFileName

# Test 7: Test UseLatestVersion with all system entries present
Write-TestHeader "Test UseLatestVersion Complete"
# Re-add the missing 1.21.6 system entries
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Fabric Installer' -AddModType 'installer' -AddModGameVersion '1.21.6' -AddModUrl 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.3/fabric-installer-1.0.3.exe' -AddModVersion '1.0.3' -DatabaseFile '$TestDbPath'" "Re-add Fabric Installer 1.21.6" 6 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Fabric Server Launcher' -AddModType 'launcher' -AddModGameVersion '1.21.6' -AddModUrl 'https://meta.fabricmc.net/v2/versions/loader/1.21.6/0.16.14/1.0.3/server/jar' -AddModVersion '1.0.3' -AddModJar 'fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar' -DatabaseFile '$TestDbPath'" "Re-add Fabric Server Launcher 1.21.6" 6 $null $TestFileName
Test-Command "& '$ModManagerPath' -AddMod -AddModName 'Minecraft Server' -AddModType 'server' -AddModGameVersion '1.21.6' -AddModUrl 'https://piston-data.mojang.com/v1/objects/6e64dcabba3c01a7271b4fa6bd898483b794c59b/server.jar' -AddModVersion '1.21.6' -AddModJar 'minecraft_server.1.21.6.jar' -DatabaseFile '$TestDbPath'" "Re-add Minecraft Server 1.21.6" 6 $null $TestFileName

# Test 8: Final UseLatestVersion test with complete system entries
Write-TestHeader "Final UseLatestVersion Test"
$finalUseLatestCmd = "& '$ModManagerPath' -DownloadMods -DatabaseFile '$TestDbPath' -UseLatestVersion -UseCachedResponses"
$finalUseLatestTestName = "Final UseLatestVersion Download"
Test-Command $finalUseLatestCmd $finalUseLatestTestName 6 $null $TestFileName

Write-Host "`nSystem Entries Tests Complete" -ForegroundColor $Colors.Info

# Show test summary
Show-TestSummary 