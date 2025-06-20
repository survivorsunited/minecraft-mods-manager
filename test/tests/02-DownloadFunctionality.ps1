# Download Functionality Tests
# Tests mod downloading, validation with download, and server file downloads

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = $MyInvocation.MyCommand.Name
Write-Host "Minecraft Mod Manager - Download Functionality Tests" -ForegroundColor $Colors.Header
Write-Host "=====================================================" -ForegroundColor $Colors.Header

# Note: This test file assumes a database with mods already exists
# It should be run after 01-BasicFunctionality.ps1

Initialize-TestEnvironment -TestFileName $TestFileName

# Test 1: Download mods
Write-TestHeader "Download Mods"
Test-Command ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -UseCachedResponses" "Download Mods" 4 $null $TestFileName

# Test 2: Download mods with validation
Write-TestHeader "Download Mods with Validation"
Test-Command ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -ValidateWithDownload -UseCachedResponses" "Download Mods with Validation" 4 $null $TestFileName

# Test 3: Download server files
Write-TestHeader "Download Server Files"
Test-Command ".\$ScriptPath -DownloadServer" "Download Server Files" 0 $null $TestFileName

# Test 4: Test duplicate 'Already exists' message fix
Write-TestHeader "Test Duplicate Already Exists Fix"
# Download the same files twice to verify no duplicate messages
$duplicateTestCmd = ".\$ScriptPath -DownloadMods -DatabaseFile '$TestDbPath' -UseCachedResponses"
Test-Command $duplicateTestCmd "Download to Test Duplicate Prevention" 4 $null $TestFileName

# Test 5: Test legacy Download behavior (validation + download)
Write-TestHeader "Test Legacy Download Behavior"
Test-Command ".\$ScriptPath -Download -DatabaseFile '$TestDbPath' -UseCachedResponses" "Legacy Download (Validation + Download)" 4 $null $TestFileName

Write-Host "`nDownload Functionality Tests Complete" -ForegroundColor $Colors.Info 