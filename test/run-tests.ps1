# Test Suite for Minecraft Mod Manager
# This script tests all functionality mentioned in the README

param(
    [switch]$GenerateBaseline,
    [switch]$Verbose,
    [string]$TestName = "all"
)

# Test configuration
$TestFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $TestFolder
$ModManagerScript = Join-Path $ProjectRoot "ModManager.ps1"
$TempFolder = Join-Path $TestFolder "temp"
$BaselineFolder = Join-Path $TestFolder "baseline"
$ResultsFolder = Join-Path $TestFolder "results"

# Test databases
$TestModList = Join-Path $TempFolder "test-modlist.csv"
$BaselineModList = Join-Path $BaselineFolder "expected-modlist.csv"
$ResultsModList = Join-Path $ResultsFolder "actual-modlist.csv"

# Colors for output
$Green = "Green"
$Red = "Red"
$Yellow = "Yellow"
$Cyan = "Cyan"
$White = "White"

# Test counters
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

function Write-TestHeader {
    param([string]$TestName)
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor $Cyan
    Write-Host "TEST: $TestName" -ForegroundColor $Cyan
    Write-Host "=" * 80 -ForegroundColor $Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    $Global:TotalTests++
    if ($Passed) {
        $Global:PassedTests++
        Write-Host "✓ PASS: $TestName" -ForegroundColor $Green
        if ($Message) { Write-Host "  $Message" -ForegroundColor $White }
    } else {
        $Global:FailedTests++
        Write-Host "✗ FAIL: $TestName" -ForegroundColor $Red
        if ($Message) { Write-Host "  $Message" -ForegroundColor $Red }
    }
}

function Initialize-TestEnvironment {
    Write-Host "Initializing test environment..." -ForegroundColor $Yellow
    
    # Create directories
    @($TempFolder, $BaselineFolder, $ResultsFolder) | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item $_ -Recurse -Force
        }
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
    
    # Create minimal test modlist using ModManager add commands
    if (Test-Path $TestModList) { Remove-Item $TestModList -Force }

    # Add Fabric API
    & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -AddMod -AddModId "fabric-api" -AddModName "Fabric API" -AddModType "mod" -AddModLoader "fabric" -AddModGameVersion "1.21.5" -AddModDescription "Core API for the Fabric toolchain"
    # Add Sodium
    & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -AddMod -AddModId "sodium" -AddModName "Sodium" -AddModType "mod" -AddModLoader "fabric" -AddModGameVersion "1.21.5" -AddModDescription "Modern rendering engine and client-side optimization mod"
    # Add Complementary Reimagined (shaderpack)
    & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -AddMod -AddModId "complementary-reimagined" -AddModName "Complementary Reimagined" -AddModType "shaderpack" -AddModLoader "iris" -AddModGameVersion "1.21.5" -AddModDescription "Beautiful shaderpack"

    Write-Host "Test environment initialized." -ForegroundColor $Green
}

function Test-BasicValidation {
    Write-TestHeader "Basic Mod Validation"
    
    try {
        # Test validation of all mods
        $output = & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -ValidateAllModVersions 2>&1
        
        # Check if validation completed without errors
        $validationPassed = $LASTEXITCODE -eq 0 -and $output -notmatch "error|Error|ERROR"
        Write-TestResult "Validation Execution" $validationPassed "Validation completed successfully"
        
        # Check if API response files were created
        $apiFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "apiresponse") -Filter "*.json" -ErrorAction SilentlyContinue
        $apiFilesPassed = $apiFiles.Count -gt 0
        Write-TestResult "API Response Files Created" $apiFilesPassed "Found $($apiFiles.Count) API response files"
        
        return $validationPassed -and $apiFilesPassed
    }
    catch {
        Write-TestResult "Basic Validation" $false "Exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-ModAddition {
    Write-TestHeader "Mod Addition Functionality"
    
    try {
        # Test adding a mod by URL
        $output = & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -AddModUrl "https://modrinth.com/mod/balm" 2>&1
        
        # Check if mod was added successfully
        $addPassed = $LASTEXITCODE -eq 0
        Write-TestResult "Add Mod by URL" $addPassed "Added Balm mod by URL"
        
        # Test adding a mod by ID
        $output = & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -AddMod -AddModId "ferrite-core" -AddModName "FerriteCore" 2>&1
        
        $addByIdPassed = $LASTEXITCODE -eq 0
        Write-TestResult "Add Mod by ID" $addByIdPassed "Added FerriteCore by ID"
        
        # Test adding a shaderpack
        $output = & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -AddModUrl "https://modrinth.com/shader/bsl-shaders" 2>&1
        
        $addShaderPassed = $LASTEXITCODE -eq 0
        Write-TestResult "Add Shaderpack" $addShaderPassed "Added BSL Shaders"
        
        # Check if mods were actually added to CSV
        $mods = Import-Csv -Path $TestModList
        $balmMod = $mods | Where-Object { $_.ID -eq "balm" }
        $ferriteMod = $mods | Where-Object { $_.ID -eq "ferrite-core" }
        $bslMod = $mods | Where-Object { $_.ID -eq "bsl-shaders" }
        
        $balmAdded = $balmMod -ne $null
        $ferriteAdded = $ferriteMod -ne $null
        $bslAdded = $bslMod -ne $null
        
        Write-TestResult "Balm Mod in CSV" $balmAdded "Balm mod found in CSV"
        Write-TestResult "FerriteCore in CSV" $ferriteAdded "FerriteCore found in CSV"
        Write-TestResult "BSL Shaders in CSV" $bslAdded "BSL Shaders found in CSV"
        
        return $addPassed -and $addByIdPassed -and $addShaderPassed -and $balmAdded -and $ferriteAdded -and $bslAdded
    }
    catch {
        Write-TestResult "Mod Addition" $false "Exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-ModDownload {
    Write-TestHeader "Mod Download Functionality"
    
    try {
        # Test downloading mods
        $output = & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -Download 2>&1
        
        $downloadPassed = $LASTEXITCODE -eq 0
        Write-TestResult "Download Execution" $downloadPassed "Download completed successfully"
        
        # Check if download folder was created
        $downloadFolder = Join-Path $ProjectRoot "download"
        $downloadFolderExists = Test-Path $downloadFolder
        Write-TestResult "Download Folder Created" $downloadFolderExists "Download folder exists"
        
        # Check if mods were downloaded
        $downloadedFiles = Get-ChildItem -Path $downloadFolder -Recurse -Filter "*.jar" -ErrorAction SilentlyContinue
        $filesDownloaded = $downloadedFiles.Count -gt 0
        Write-TestResult "Mod Files Downloaded" $filesDownloaded "Found $($downloadedFiles.Count) downloaded JAR files"
        
        return $downloadPassed -and $downloadFolderExists -and $filesDownloaded
    }
    catch {
        Write-TestResult "Mod Download" $false "Exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-ServerDownload {
    Write-TestHeader "Server Download Functionality"
    
    try {
        # Test downloading server files
        $output = & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -DownloadServer 2>&1
        
        $serverDownloadPassed = $LASTEXITCODE -eq 0
        Write-TestResult "Server Download Execution" $serverDownloadPassed "Server download completed successfully"
        
        # Check if server files were downloaded
        $downloadFolder = Join-Path $ProjectRoot "download"
        $serverFiles = Get-ChildItem -Path $downloadFolder -Recurse -Filter "minecraft_server.*.jar" -ErrorAction SilentlyContinue
        $fabricFiles = Get-ChildItem -Path $downloadFolder -Recurse -Filter "fabric-server-*.jar" -ErrorAction SilentlyContinue
        
        $serverFilesExist = $serverFiles.Count -gt 0
        $fabricFilesExist = $fabricFiles.Count -gt 0
        
        Write-TestResult "Minecraft Server Files" $serverFilesExist "Found $($serverFiles.Count) server JAR files"
        Write-TestResult "Fabric Server Files" $fabricFilesExist "Found $($fabricFiles.Count) Fabric server files"
        
        return $serverDownloadPassed -and $serverFilesExist -and $fabricFilesExist
    }
    catch {
        Write-TestResult "Server Download" $false "Exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-ModListOperations {
    Write-TestHeader "Mod List Operations"
    
    try {
        # Test getting mod list
        $output = & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $TestModList -GetModList 2>&1
        
        $getModListPassed = $LASTEXITCODE -eq 0
        Write-TestResult "Get Mod List" $getModListPassed "Get mod list completed successfully"
        
        # Test custom ModListFile parameter
        $customModList = Join-Path $TempFolder "custom-test.csv"
        Copy-Item $TestModList $customModList
        
        $output = & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ModListFile $customModList -GetModList 2>&1
        
        $customFilePassed = $LASTEXITCODE -eq 0
        Write-TestResult "Custom ModListFile Parameter" $customFilePassed "Custom file parameter works correctly"
        
        return $getModListPassed -and $customFilePassed
    }
    catch {
        Write-TestResult "Mod List Operations" $false "Exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-HelpAndDocumentation {
    Write-TestHeader "Help and Documentation"
    
    try {
        # Test help display
        $output = & powershell -ExecutionPolicy Bypass -File $ModManagerScript -ShowHelp 2>&1
        
        $helpPassed = $LASTEXITCODE -eq 0
        Write-TestResult "Help Display" $helpPassed "Help information displayed successfully"
        
        # Check if help contains expected sections
        $helpContent = $output -join "`n"
        $hasUsageExamples = $helpContent -match "USAGE EXAMPLES"
        $hasFunctions = $helpContent -match "FUNCTIONS"
        $hasCsvColumns = $helpContent -match "CSV COLUMNS"
        
        Write-TestResult "Help Contains Usage Examples" $hasUsageExamples "Usage examples section found"
        Write-TestResult "Help Contains Functions" $hasFunctions "Functions section found"
        Write-TestResult "Help Contains CSV Columns" $hasCsvColumns "CSV columns section found"
        
        return $helpPassed -and $hasUsageExamples -and $hasFunctions -and $hasCsvColumns
    }
    catch {
        Write-TestResult "Help and Documentation" $false "Exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-CsvStructure {
    Write-TestHeader "CSV Structure Validation"
    
    try {
        # Read the test modlist
        $mods = Import-Csv -Path $TestModList
        
        # Check if CSV has expected columns
        $expectedColumns = @(
            "Group", "Type", "GameVersion", "ID", "Loader", "Version", "Name", "Description",
            "Jar", "Url", "Category", "VersionUrl", "LatestVersionUrl", "LatestVersion",
            "ApiSource", "Host", "IconUrl", "ClientSide", "ServerSide", "Title",
            "ProjectDescription", "IssuesUrl", "SourceUrl", "WikiUrl", "LatestGameVersion"
        )
        
        $csvColumns = $mods[0].PSObject.Properties.Name
        $allColumnsPresent = $true
        $missingColumns = @()
        
        foreach ($column in $expectedColumns) {
            if ($column -notin $csvColumns) {
                $allColumnsPresent = $false
                $missingColumns += $column
            }
        }
        
        Write-TestResult "All Expected Columns Present" $allColumnsPresent "Missing columns: $($missingColumns -join ', ')"
        
        # Check if CSV has data
        $hasData = $mods.Count -gt 0
        Write-TestResult "CSV Contains Data" $hasData "CSV contains $($mods.Count) mods"
        
        return $allColumnsPresent -and $hasData
    }
    catch {
        Write-TestResult "CSV Structure" $false "Exception: $($_.Exception.Message)"
        return $false
    }
}

function Save-TestResults {
    Write-Host "`nSaving test results..." -ForegroundColor $Yellow
    
    # Copy the final test modlist to results
    if (Test-Path $TestModList) {
        Copy-Item $TestModList $ResultsModList -Force
        Write-Host "Test results saved to: $ResultsModList" -ForegroundColor $Green
    }
}

function Generate-Baseline {
    Write-Host "`nGenerating baseline..." -ForegroundColor $Yellow
    
    # Run all tests to generate baseline
    Initialize-TestEnvironment
    Test-BasicValidation | Out-Null
    Test-ModAddition | Out-Null
    Test-ModDownload | Out-Null
    Test-ServerDownload | Out-Null
    Test-ModListOperations | Out-Null
    Test-HelpAndDocumentation | Out-Null
    Test-CsvStructure | Out-Null
    
    # Copy final modlist as baseline
    if (Test-Path $TestModList) {
        Copy-Item $TestModList $BaselineModList -Force
        Write-Host "Baseline generated: $BaselineModList" -ForegroundColor $Green
    }
}

function Compare-Results {
    Write-TestHeader "Results Comparison"
    
    if (-not (Test-Path $BaselineModList)) {
        Write-TestResult "Baseline Exists" $false "Baseline file not found. Run with -GenerateBaseline first."
        return $false
    }
    
    if (-not (Test-Path $ResultsModList)) {
        Write-TestResult "Results Exist" $false "Results file not found."
        return $false
    }
    
    try {
        # Compare CSV files
        $baseline = Import-Csv -Path $BaselineModList
        $results = Import-Csv -Path $ResultsModList
        
        # Compare mod counts
        $baselineCount = $baseline.Count
        $resultsCount = $results.Count
        $countMatch = $baselineCount -eq $resultsCount
        Write-TestResult "Mod Count Match" $countMatch "Baseline: $baselineCount, Results: $resultsCount"
        
        # Compare specific mods
        $expectedMods = @("fabric-api", "sodium", "complementary-reimagined", "balm", "ferrite-core", "bsl-shaders")
        $allModsPresent = $true
        
        foreach ($modId in $expectedMods) {
            $modInResults = $results | Where-Object { $_.ID -eq $modId }
            $modPresent = $modInResults -ne $null
            Write-TestResult "Mod '$modId' Present" $modPresent "Mod $modId found in results"
            if (-not $modPresent) { $allModsPresent = $false }
        }
        
        return $countMatch -and $allModsPresent
    }
    catch {
        Write-TestResult "Results Comparison" $false "Exception: $($_.Exception.Message)"
        return $false
    }
}

function Show-TestSummary {
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor $Cyan
    Write-Host "TEST SUMMARY" -ForegroundColor $Cyan
    Write-Host "=" * 80 -ForegroundColor $Cyan
    Write-Host "Total Tests: $TotalTests" -ForegroundColor $White
    Write-Host "Passed: $PassedTests" -ForegroundColor $Green
    Write-Host "Failed: $FailedTests" -ForegroundColor $Red
    
    if ($FailedTests -eq 0) {
        Write-Host "`n🎉 ALL TESTS PASSED! 🎉" -ForegroundColor $Green
    } else {
        Write-Host "`n❌ SOME TESTS FAILED! ❌" -ForegroundColor $Red
    }
}

# Main test execution
Write-Host "Minecraft Mod Manager Test Suite" -ForegroundColor $Cyan
Write-Host "=================================" -ForegroundColor $Cyan

if ($GenerateBaseline) {
    Generate-Baseline
    exit 0
}

# Run specific test or all tests
switch ($TestName.ToLower()) {
    "basic" { 
        Initialize-TestEnvironment
        Test-BasicValidation
    }
    "addition" { 
        Initialize-TestEnvironment
        Test-ModAddition
    }
    "download" { 
        Initialize-TestEnvironment
        Test-ModDownload
    }
    "server" { 
        Initialize-TestEnvironment
        Test-ServerDownload
    }
    "operations" { 
        Initialize-TestEnvironment
        Test-ModListOperations
    }
    "help" { 
        Test-HelpAndDocumentation
    }
    "csv" { 
        Initialize-TestEnvironment
        Test-CsvStructure
    }
    "compare" {
        Compare-Results
    }
    default {
        # Run all tests
        Initialize-TestEnvironment
        Test-BasicValidation
        Test-ModAddition
        Test-ModDownload
        Test-ServerDownload
        Test-ModListOperations
        Test-HelpAndDocumentation
        Test-CsvStructure
        Save-TestResults
        Compare-Results
    }
}

Show-TestSummary

# Exit with appropriate code
if ($FailedTests -eq 0) {
    exit 0
} else {
    exit 1
} 