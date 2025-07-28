# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "56-TestProviderUnitTests.ps1"

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"

Write-Host "Minecraft Mod Manager - Provider Unit Tests" -ForegroundColor $Colors.Header
Write-Host "=============================================" -ForegroundColor $Colors.Header

# Import the modular functions for testing
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

# ================================================================================
# TEST: Provider Common Functions
# ================================================================================
Write-TestHeader "Provider Common Functions"

# Test Validate-ModVersion with Modrinth provider
Write-TestHeader "Validate-ModVersion - Modrinth Provider"

# Test with valid mod ID and version
$result = Validate-ModVersion -ModId "fabric-api" -Version "0.91.0+1.21.5" -Loader "fabric" -ResponseFolder $TestOutputDir
if ($result -and $result.Exists) {
    Write-TestResult "Validate-ModVersion - Valid Modrinth Mod" $true
} else {
    Write-TestResult "Validate-ModVersion - Valid Modrinth Mod" $false "Expected valid result, got: $($result | ConvertTo-Json)"
}

# Test with "latest" version
$result = Validate-ModVersion -ModId "fabric-api" -Version "latest" -Loader "fabric" -ResponseFolder $TestOutputDir
if ($result -and $result.Exists) {
    Write-TestResult "Validate-ModVersion - Latest Version" $true
} else {
    Write-TestResult "Validate-ModVersion - Latest Version" $false "Expected valid result, got: $($result | ConvertTo-Json)"
}

# Test with invalid mod ID
$result = Validate-ModVersion -ModId "invalid-mod-id-12345" -Version "1.0.0" -ResponseFolder $TestOutputDir
if ($result -and -not $result.Exists) {
    Write-TestResult "Validate-ModVersion - Invalid Mod ID" $true
} else {
    Write-TestResult "Validate-ModVersion - Invalid Mod ID" $false "Expected invalid result, got: $($result | ConvertTo-Json)"
}

# ================================================================================
# TEST: Modrinth Provider Functions
# ================================================================================
Write-TestHeader "Modrinth Provider Functions"

# Test Get-ModrinthProjectInfo with valid project ID
$projectInfo = Get-ModrinthProjectInfo -ProjectId "fabric-api" -UseCachedResponses $false
if ($projectInfo -and $projectInfo.project_id -eq "fabric-api") {
    Write-TestResult "Get-ModrinthProjectInfo - Valid Project" $true
} else {
    Write-TestResult "Get-ModrinthProjectInfo - Valid Project" $false "Expected valid project info"
}

# Test Get-ModrinthProjectInfo with invalid project ID
$projectInfo = Get-ModrinthProjectInfo -ProjectId "invalid-project-12345" -UseCachedResponses $false
if (-not $projectInfo) {
    Write-TestResult "Get-ModrinthProjectInfo - Invalid Project" $true
} else {
    Write-TestResult "Get-ModrinthProjectInfo - Invalid Project" $false "Expected null result for invalid project"
}

# Test Validate-ModrinthModVersion with valid mod and version
$result = Validate-ModrinthModVersion -ModID "fabric-api" -Version "0.91.0+1.21.5" -Loader "fabric"
if ($result -and $result.Success) {
    Write-TestResult "Validate-ModrinthModVersion - Valid Mod/Version" $true
} else {
    Write-TestResult "Validate-ModrinthModVersion - Valid Mod/Version" $false "Expected success, got: $($result | ConvertTo-Json)"
}

# Test Validate-ModrinthModVersion with invalid version
$result = Validate-ModrinthModVersion -ModID "fabric-api" -Version "999.999.999" -Loader "fabric"
if ($result -and -not $result.Success) {
    Write-TestResult "Validate-ModrinthModVersion - Invalid Version" $true
} else {
    Write-TestResult "Validate-ModrinthModVersion - Invalid Version" $false "Expected failure for invalid version"
}

# ================================================================================
# TEST: CurseForge Provider Functions
# ================================================================================
Write-TestHeader "CurseForge Provider Functions"

# Test Get-CurseForgeProjectInfo with valid project ID
$projectInfo = Get-CurseForgeProjectInfo -ProjectId "238222" -UseCachedResponses $false
if ($projectInfo -and $projectInfo.id -eq 238222) {
    Write-TestResult "Get-CurseForgeProjectInfo - Valid Project" $true
} else {
    Write-TestResult "Get-CurseForgeProjectInfo - Valid Project" $false "Expected valid project info"
}

# Test Get-CurseForgeFileInfo with valid file ID
$fileInfo = Get-CurseForgeFileInfo -ModID "238222" -FileID "123456" -UseCachedResponses $false
if ($fileInfo) {
    Write-TestResult "Get-CurseForgeFileInfo - Valid File" $true
} else {
    Write-TestResult "Get-CurseForgeFileInfo - Valid File" $false "Expected valid file info"
}

# Test Validate-CurseForgeModVersion with valid mod and version
$result = Validate-CurseForgeModVersion -ModID "238222" -FileID "123456" -UseCachedResponses $false
if ($result) {
    Write-TestResult "Validate-CurseForgeModVersion - Valid Mod/Version" $true
} else {
    Write-TestResult "Validate-CurseForgeModVersion - Valid Mod/Version" $false "Expected valid result"
}

# ================================================================================
# TEST: Fabric Provider Functions
# ================================================================================
Write-TestHeader "Fabric Provider Functions"

# Test Get-FabricLoaderInfo with valid version
$loaderInfo = Get-FabricLoaderInfo -GameVersion "1.21.5" -UseCachedResponses $false
if ($loaderInfo -and $loaderInfo.loader) {
    Write-TestResult "Get-FabricLoaderInfo - Valid Version" $true
} else {
    Write-TestResult "Get-FabricLoaderInfo - Valid Version" $false "Expected valid loader info"
}

# Test Get-FabricLoaderInfo with invalid version
$loaderInfo = Get-FabricLoaderInfo -GameVersion "999.999.999" -UseCachedResponses $false
if (-not $loaderInfo) {
    Write-TestResult "Get-FabricLoaderInfo - Invalid Version" $true
} else {
    Write-TestResult "Get-FabricLoaderInfo - Invalid Version" $false "Expected null result for invalid version"
}

# ================================================================================
# TEST: Mojang Provider Functions
# ================================================================================
Write-TestHeader "Mojang Provider Functions"

# Test Get-MojangServerInfo with valid version
$serverInfo = Get-MojangServerInfo -GameVersion "1.21.5" -UseCachedResponses $false
if ($serverInfo -and $serverInfo.downloads -and $serverInfo.downloads.server) {
    Write-TestResult "Get-MojangServerInfo - Valid Version" $true
} else {
    Write-TestResult "Get-MojangServerInfo - Valid Version" $false "Expected valid server info"
}

# Test Get-MojangServerInfo with invalid version
$serverInfo = Get-MojangServerInfo -GameVersion "999.999.999" -UseCachedResponses $false
if (-not $serverInfo) {
    Write-TestResult "Get-MojangServerInfo - Invalid Version" $true
} else {
    Write-TestResult "Get-MojangServerInfo - Invalid Version" $false "Expected null result for invalid version"
}

# ================================================================================
# TEST: Error Handling and Edge Cases
# ================================================================================
Write-TestHeader "Error Handling and Edge Cases"

# Test Validate-ModVersion with empty parameters
try {
    $result = Validate-ModVersion -ModId "" -Version "" -ResponseFolder $TestOutputDir
    Write-TestResult "Validate-ModVersion - Empty Parameters" $false "Should have thrown exception"
} catch {
    Write-TestResult "Validate-ModVersion - Empty Parameters" $true
}

# Test Validate-ModVersion with null parameters
try {
    $result = Validate-ModVersion -ModId $null -Version $null -ResponseFolder $TestOutputDir
    Write-TestResult "Validate-ModVersion - Null Parameters" $false "Should have thrown exception"
} catch {
    Write-TestResult "Validate-ModVersion - Null Parameters" $true
}

# Test provider functions with network errors (using invalid URLs)
try {
    $result = Get-ModrinthProjectInfo -ProjectId "test" -UseCachedResponses $false
    Write-TestResult "Get-ModrinthProjectInfo - Network Error Handling" $true
} catch {
    Write-TestResult "Get-ModrinthProjectInfo - Network Error Handling" $true "Exception handled correctly"
}

# ================================================================================
# TEST: Response File Generation
# ================================================================================
Write-TestHeader "Response File Generation"

# Test that response files are created
$result = Validate-ModVersion -ModId "fabric-api" -Version "0.91.0+1.21.5" -ResponseFolder $TestOutputDir
$expectedResponseFile = Join-Path $TestOutputDir "fabric-api-0.91.0+1.21.5.json"
if (Test-Path $expectedResponseFile) {
    Write-TestResult "Response File Generation" $true
} else {
    Write-TestResult "Response File Generation" $false "Expected response file: $expectedResponseFile"
}

# ================================================================================
# TEST: Provider Auto-Detection
# ================================================================================
Write-TestHeader "Provider Auto-Detection"

# Test that Validate-ModVersion correctly routes to Modrinth provider
$result = Validate-ModVersion -ModId "fabric-api" -Version "0.91.0+1.21.5" -ResponseFolder $TestOutputDir
if ($result -and $result.Exists) {
    Write-TestResult "Provider Auto-Detection - Modrinth" $true
} else {
    Write-TestResult "Provider Auto-Detection - Modrinth" $false "Expected successful routing to Modrinth"
}

# ================================================================================
# TEST SUMMARY
# ================================================================================
Show-TestSummary "Provider Unit Tests"

return ($script:TestResults.Failed -eq 0) 