# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Import version functions
. "$PSScriptRoot\..\..\src\Data\Version\Get-CurrentVersion.ps1"
. "$PSScriptRoot\..\..\src\Data\Version\Get-NextVersion.ps1"
. "$PSScriptRoot\..\..\src\Data\Version\Get-LatestVersion.ps1"

# Set the test file name for use throughout the script
$TestFileName = "94-TestVersionFunctions.ps1"

# Initialize test environment
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestDbPath = Join-Path $TestOutputDir "test-modlist.csv"

Write-Host "Version Functions Tests" -ForegroundColor $Colors.Header
Write-Host "======================" -ForegroundColor $Colors.Header

# Create test database with known versions
$testData = @"
"Group","Type","CurrentGameVersion","ID","Loader","CurrentVersion","Name","Description","Category","Jar","NextVersion","NextVersionUrl","NextGameVersion","LatestVersion","LatestVersionUrl","LatestGameVersion","Url","CurrentVersionUrl","UrlDirect","CurrentDependencies","CurrentDependenciesRequired","CurrentDependenciesOptional","LatestDependencies","LatestDependenciesRequired","LatestDependenciesOptional","Host","ApiSource","ClientSide","ServerSide","Title","ProjectDescription","IconUrl","IssuesUrl","SourceUrl","WikiUrl","AvailableGameVersions","RecordHash"
"required","mod","1.21.5","fabric-api","fabric","0.128.2+1.21.5","Fabric API","Test mod 1","Core","fabric-api.jar","0.128.2+1.21.6","url1","1.21.6","0.135.2+1.21.9","url2","1.21.9","https://modrinth.com/mod/fabric-api","url3","","","","","","","","modrinth","modrinth","","","Fabric API","","","","","","",""
"required","mod","1.21.5","cloth-config","fabric","18.0.145","Cloth Config","Test mod 2","Core","cloth-config.jar","19.0.147","url4","1.21.6","20.0.148","url5","1.21.9","https://modrinth.com/mod/cloth-config","url6","","","","","","","","modrinth","modrinth","","","Cloth Config","","","","","","",""
"required","mod","1.21.5","balm","fabric","21.5.25","Balm","Test mod 3","Core","balm.jar","21.6.1","url7","1.21.6","21.10.2","url8","1.21.10","https://modrinth.com/mod/balm","url9","","","","","","","","modrinth","modrinth","","","Balm","","","","","","",""
"required","server","1.21.5","minecraft-server","vanilla","1.21.5","Minecraft Server","Server","","server.jar","","","","","","","https://mojang.com","","","","","","","","","mojang","mojang","","","Server","","","","","","",""
"required","launcher","1.21.5","fabric-launcher","fabric","0.17.3","Fabric Launcher","Launcher","","launcher.jar","","","","","","","https://fabric.net","","","","","","","","","fabric","fabric","","","Launcher","","","","","","",""
"@

$testData | Out-File -FilePath $TestDbPath -Encoding UTF8

# Test 1: Get-CurrentVersion
Write-TestHeader "Test 1: Get-CurrentVersion"

$currentVersion = Get-CurrentVersion -CsvPath $TestDbPath
Write-Host "  Returned: $currentVersion" -ForegroundColor Gray
Write-TestResult "Get-CurrentVersion returns 1.21.5" ($currentVersion -eq "1.21.5")

# Test 2: Get-NextVersion
Write-TestHeader "Test 2: Get-NextVersion"

$nextVersion = Get-NextVersion -CsvPath $TestDbPath
Write-Host "  Returned: $nextVersion" -ForegroundColor Gray
Write-TestResult "Get-NextVersion returns 1.21.6" ($nextVersion -eq "1.21.6")

# Test 3: Get-LatestVersion
Write-TestHeader "Test 3: Get-LatestVersion"

$latestVersion = Get-LatestVersion -CsvPath $TestDbPath
Write-Host "  Returned: $latestVersion" -ForegroundColor Gray
Write-TestResult "Get-LatestVersion returns majority (1.21.9)" ($latestVersion -eq "1.21.9")

# Test 4: Functions return null for empty database
Write-TestHeader "Test 4: Null Return for Empty Database"

$emptyData = @"
"Group","Type","CurrentGameVersion","ID","Loader","CurrentVersion","Name","Description","Category","Jar","NextVersion","NextVersionUrl","NextGameVersion","LatestVersion","LatestVersionUrl","LatestGameVersion","Url","CurrentVersionUrl","UrlDirect","CurrentDependencies","CurrentDependenciesRequired","CurrentDependenciesOptional","LatestDependencies","LatestDependenciesRequired","LatestDependenciesOptional","Host","ApiSource","ClientSide","ServerSide","Title","ProjectDescription","IconUrl","IssuesUrl","SourceUrl","WikiUrl","AvailableGameVersions","RecordHash"
"@

$emptyDbPath = Join-Path $TestOutputDir "empty-modlist.csv"
$emptyData | Out-File -FilePath $emptyDbPath -Encoding UTF8

$emptyCurrentVersion = Get-CurrentVersion -CsvPath $emptyDbPath
Write-TestResult "Get-CurrentVersion returns null for empty DB" ($null -eq $emptyCurrentVersion)

$emptyNextVersion = Get-NextVersion -CsvPath $emptyDbPath
Write-TestResult "Get-NextVersion returns null for empty DB" ($null -eq $emptyNextVersion)

$emptyLatestVersion = Get-LatestVersion -CsvPath $emptyDbPath
Write-TestResult "Get-LatestVersion returns null for empty DB" ($null -eq $emptyLatestVersion)

# Test 5: Functions exclude infrastructure (server, launcher)
Write-TestHeader "Test 5: Infrastructure Exclusion"

$infraData = @"
"Group","Type","CurrentGameVersion","ID","Loader","CurrentVersion","Name","Description","Category","Jar","NextVersion","NextVersionUrl","NextGameVersion","LatestVersion","LatestVersionUrl","LatestGameVersion","Url","CurrentVersionUrl","UrlDirect","CurrentDependencies","CurrentDependenciesRequired","CurrentDependenciesOptional","LatestDependencies","LatestDependenciesRequired","LatestDependenciesOptional","Host","ApiSource","ClientSide","ServerSide","Title","ProjectDescription","IconUrl","IssuesUrl","SourceUrl","WikiUrl","AvailableGameVersions","RecordHash"
"required","server","1.21.9","minecraft-server","vanilla","1.21.9","Server","","","server.jar","","","1.21.10","","","1.21.10","","","","","","","","","","mojang","mojang","","","Server","","","","","","",""
"required","launcher","1.21.8","fabric-launcher","fabric","0.17.3","Launcher","","","launcher.jar","","","1.21.9","","","1.21.9","","","","","","","","","","fabric","fabric","","","Launcher","","","","","","",""
"required","mod","1.21.5","test-mod","fabric","1.0","Test Mod","","","test.jar","2.0","url","1.21.6","3.0","url","1.21.7","","","","","","","","","","modrinth","modrinth","","","Test","","","","","","",""
"@

$infraDbPath = Join-Path $TestOutputDir "infra-modlist.csv"
$infraData | Out-File -FilePath $infraDbPath -Encoding UTF8

$infraCurrentVersion = Get-CurrentVersion -CsvPath $infraDbPath
Write-Host "  Current from DB with server=1.21.9, mod=1.21.5: $infraCurrentVersion" -ForegroundColor Gray
Write-TestResult "Get-CurrentVersion excludes server entries" ($infraCurrentVersion -eq "1.21.5")

$infraNextVersion = Get-NextVersion -CsvPath $infraDbPath
Write-Host "  Next from DB with launcher=1.21.9, mod=1.21.6: $infraNextVersion" -ForegroundColor Gray
Write-TestResult "Get-NextVersion excludes launcher entries" ($infraNextVersion -eq "1.21.6")

$infraLatestVersion = Get-LatestVersion -CsvPath $infraDbPath
Write-Host "  Latest from DB with server=1.21.10, mod=1.21.7: $infraLatestVersion" -ForegroundColor Gray
Write-TestResult "Get-LatestVersion excludes infrastructure" ($infraLatestVersion -eq "1.21.7")

# Show test summary
Show-TestSummary "Version Functions Tests"

Write-Host "`nVersion Functions Tests Complete" -ForegroundColor $Colors.Info

return ($script:TestResults.Failed -eq 0)

