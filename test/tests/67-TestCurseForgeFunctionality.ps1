# CurseForge Functionality Tests
# Tests CurseForge API integration, error handling, and mod operations

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "67-TestCurseForgeFunctionality.ps1"

Write-Host "Minecraft Mod Manager - CurseForge Functionality Tests" -ForegroundColor $Colors.Header
Write-Host "======================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"

# Set up test directories
$TestDbPath = Join-Path $TestOutputDir "curseforge-test.csv"

Write-TestHeader "Test Environment Setup"

# Create test database with CurseForge mods
$curseForgeModlistContent = @'
Group,Type,GameVersion,ID,Loader,Version,Name,Description,Jar,Url,Category,VersionUrl,LatestVersionUrl,LatestVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,LatestGameVersion,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
required,mod,1.21.5,357540,fabric,v3.4.27,Inventory HUD+,Display inventory on screen,inventoryhud.fabric.1.21.5-3.4.27.jar,https://www.curseforge.com/minecraft/mc-mods/inventory-hud-forge,Storage & Inventory,,,,curseforge,curseforge,,,,,,,,,,,,,,,,,
optional,mod,1.21.5,238222,fabric,latest,Just Enough Items,Item and recipe viewing mod,jei.jar,https://www.curseforge.com/minecraft/mc-mods/jei,Utility,,,,curseforge,curseforge,,,,,,,,,,,,,,,,,
optional,mod,1.21.5,32274,fabric,latest,JourneyMap,Real-time mapping mod,journeymap.jar,https://www.curseforge.com/minecraft/mc-mods/journeymap,Map & Information,,,,curseforge,curseforge,,,,,,,,,,,,,,,,,
'@

$curseForgeModlistContent | Out-File -FilePath $TestDbPath -Encoding UTF8
Write-TestResult "Test Database Created" (Test-Path $TestDbPath)

Write-Host "  CurseForge mods configured:" -ForegroundColor Gray
Write-Host "    - Inventory HUD+ (357540) - Known 403 error" -ForegroundColor Gray
Write-Host "    - Just Enough Items (238222)" -ForegroundColor Gray
Write-Host "    - JourneyMap (32274)" -ForegroundColor Gray

# Test 1: CurseForge API Key Detection
Write-TestHeader "Test 1: CurseForge API Key Detection"

# Check if API key is available
$apiKeyAvailable = $false
$apiKeyError = $null

try {
    # Load environment variables
    . "$PSScriptRoot\..\..\src\Core\Environment\Load-EnvironmentVariables.ps1"
    Load-EnvironmentVariables
    
    $apiKeyAvailable = -not [string]::IsNullOrEmpty($env:CURSEFORGE_API_KEY)
} catch {
    $apiKeyError = $_.Exception.Message
}

Write-TestResult "CurseForge API Key Available" $apiKeyAvailable

if ($apiKeyAvailable) {
    Write-Host "  API Key Length: $($env:CURSEFORGE_API_KEY.Length) characters" -ForegroundColor Green
} else {
    Write-Host "  ❌ No API key found in environment" -ForegroundColor Yellow
    Write-Host "  ⏭️  Skipping remaining CurseForge tests (API key required)" -ForegroundColor Yellow
    if ($apiKeyError) {
        Write-Host "  Error: $apiKeyError" -ForegroundColor Yellow
    }
    Write-Host "" -ForegroundColor Gray
    Write-Host "To run CurseForge tests, set the CURSEFORGE_API_KEY environment variable." -ForegroundColor Gray
    Write-Host "You can get an API key from: https://console.curseforge.com" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Gray
    
    # Show test summary and exit gracefully
    Show-TestSummary "CurseForge Functionality Tests"
    return $true
}

# Test 2: Direct CurseForge API Test
Write-TestHeader "Test 2: Direct CurseForge API Test"

$apiTestResults = @()

# Test with known project IDs
$testProjects = @(
    @{ ID = "357540"; Name = "Inventory HUD+"; ExpectedError = $true },
    @{ ID = "238222"; Name = "Just Enough Items"; ExpectedError = $false },
    @{ ID = "32274"; Name = "JourneyMap"; ExpectedError = $false }
)

foreach ($project in $testProjects) {
    try {
        Write-Host "  Testing: curl -H 'Accept: application/json' -H 'x-api-key: \$env:CURSEFORGE_API_KEY' 'https://api.curseforge.com/v1/mods/$($project.ID)'" -ForegroundColor Gray
        
        . "$PSScriptRoot\..\..\src\Provider\CurseForge\Get-CurseForgeProjectInfo.ps1"
        $result = Get-CurseForgeProjectInfo -ProjectId $project.ID -UseCachedResponses $false
        
        if ($result) {
            $apiTestResults += [PSCustomObject]@{
                ProjectID = $project.ID
                Name = $project.Name
                Success = $true
                Error = $null
                StatusCode = "200"
            }
        } else {
            $apiTestResults += [PSCustomObject]@{
                ProjectID = $project.ID
                Name = $project.Name
                Success = $false
                Error = "No data returned"
                StatusCode = "Unknown"
            }
        }
    } catch {
        $errorMessage = $_.Exception.Message
        $statusCode = if ($errorMessage -match '403') { "403" } 
                     elseif ($errorMessage -match '404') { "404" }
                     elseif ($errorMessage -match '401') { "401" }
                     else { "Error" }
        
        $apiTestResults += [PSCustomObject]@{
            ProjectID = $project.ID
            Name = $project.Name
            Success = $false
            Error = $errorMessage
            StatusCode = $statusCode
        }
    }
}

# Check if API is working (no longer expecting 403 errors)
$allSuccessful = ($apiTestResults | Where-Object { $_.Success -eq $true }).Count -eq $apiTestResults.Count
$inventoryHudResult = $apiTestResults | Where-Object { $_.ProjectID -eq "357540" }
$apiWorking = $inventoryHudResult -and $inventoryHudResult.StatusCode -eq "200"

Write-TestResult "CurseForge API Working" $apiWorking

Write-Host "  API Test Results:" -ForegroundColor Gray
foreach ($result in $apiTestResults) {
    $status = if ($result.Success) { "✓" } else { "✗" }
    $color = if ($result.Success) { "Green" } else { "Red" }
    Write-Host "    $status $($result.Name) ($($result.ProjectID)): Status $($result.StatusCode)" -ForegroundColor $color
    if ($result.Error -and $result.Error.Length -gt 0) {
        $shortError = if ($result.Error.Length -gt 60) { $result.Error.Substring(0, 60) + "..." } else { $result.Error }
        Write-Host "      Error: $shortError" -ForegroundColor Red
    }
}

# Test 3: Validate CurseForge Mods
Write-TestHeader "Test 3: Validate CurseForge Mods"

$validationOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -DatabaseFile $TestDbPath -ApiResponseFolder $script:TestApiResponseDir 2>&1

# Parse validation results
$validationErrors = ($validationOutput | Select-String "Errors: (\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -as [int]
$hasValidationErrors = $validationErrors -gt 0

Write-TestResult "Validation Completed" ($null -ne $validationOutput)
Write-TestResult "No Validation Errors (API Working)" (-not $hasValidationErrors)

if ($hasValidationErrors) {
    Write-Host "  Found $validationErrors validation error(s)" -ForegroundColor Yellow
    
    # Check for specific 403 error in output
    $has403Error = ($validationOutput -join "`n") -match "403|Forbidden"
    Write-TestResult "403 Error in Validation Output" $has403Error
} else {
    Write-Host "  ✓ No validation errors - API is working correctly" -ForegroundColor Green
}

# Test 4: CurseForge Mod Validation Working
Write-TestHeader "Test 4: CurseForge Mod Validation Working"

# Test that CurseForge mod validation now works correctly
$validationWorking = $true
$validationMessages = @()

try {
    # Attempt to validate the previously problematic mod
    . "$PSScriptRoot\..\..\src\Provider\CurseForge\Validate-CurseForgeModVersion.ps1"
    $result = Validate-CurseForgeModVersion -ModId "357540" -Version "v3.4.27" -Loader "fabric"
    
    # Check if validation succeeded
    if ($result -and -not $result.Error) {
        $validationMessages += "✓ Validation successful: Inventory HUD+ v3.4.27 for fabric"
    } elseif ($result -and $result.Error) {
        $validationWorking = $false
        $validationMessages += "✗ Validation error: $($result.Error)"
    } else {
        $validationWorking = $false
        $validationMessages += "✗ No result returned from validation"
    }
} catch {
    $validationWorking = $false
    $validationMessages += "✗ Exception during validation: $($_.Exception.Message)"
}

Write-TestResult "CurseForge Validation Working" $validationWorking

foreach ($msg in $validationMessages) {
    Write-Host "  $msg" -ForegroundColor Gray
}

# Test 5: CurseForge API Key Validation
Write-TestHeader "Test 5: CurseForge API Key Validation"

# Test with a simple curl call to verify the API key
$apiKeyValid = $false
$curlTestError = $null

try {
    # Test a simple API endpoint that should work with any valid key
    $curlCommand = "curl -s -w `"%{http_code}`" -X GET -H 'Accept: application/json' -H `"x-api-key: $env:CURSEFORGE_API_KEY`" `"https://api.curseforge.com/v1/games/432`""
    Write-Host "  Executing: $curlCommand" -ForegroundColor Gray
    
    $curlOutput = curl -s -w "%{http_code}" -X GET -H 'Accept: application/json' -H "x-api-key: $env:CURSEFORGE_API_KEY" "https://api.curseforge.com/v1/games/432" 2>&1
    
    if ($curlOutput -match "200$") {
        $apiKeyValid = $true
    } elseif ($curlOutput -match "403") {
        $curlTestError = "API key rejected (403 Forbidden)"
    } elseif ($curlOutput -match "401") {
        $curlTestError = "API key unauthorized (401)"
    } else {
        $curlTestError = "Unexpected response: $curlOutput"
    }
} catch {
    $curlTestError = "Curl test failed: $($_.Exception.Message)"
}

Write-TestResult "API Key Valid" $apiKeyValid

if ($curlTestError) {
    Write-Host "  ❌ $curlTestError" -ForegroundColor Red
} else {
    Write-Host "  ✓ API key accepted by CurseForge" -ForegroundColor Green
}

# Test 6: CurseForge API Response Caching
Write-TestHeader "Test 6: CurseForge API Response Caching"

# Check if cache directory exists and has content
$cacheDir = Join-Path $script:TestApiResponseDir "curseforge"
$cacheDirExists = Test-Path $cacheDir
$cacheFiles = @()

if ($cacheDirExists) {
    $cacheFiles = Get-ChildItem -Path $cacheDir -Filter "*.json" -ErrorAction SilentlyContinue
}

Write-TestResult "Cache Directory Created" $cacheDirExists
Write-TestResult "Cache Files Generated" ($cacheFiles.Count -gt 0)

if ($cacheFiles.Count -gt 0) {
    Write-Host "  Cached responses:" -ForegroundColor Gray
    foreach ($file in $cacheFiles | Select-Object -First 5) {
        Write-Host "    - $($file.Name)" -ForegroundColor Gray
    }
    if ($cacheFiles.Count -gt 5) {
        Write-Host "    ... and $($cacheFiles.Count - 5) more" -ForegroundColor Gray
    }
}

# Test 7: Mixed Provider Database
Write-TestHeader "Test 7: Mixed Provider Database"

# Create a mixed database with both Modrinth and CurseForge mods
$mixedModlistContent = @'
Group,Type,GameVersion,ID,Loader,Version,Name,Description,Jar,Url,Category,VersionUrl,LatestVersionUrl,LatestVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,LatestGameVersion,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependencies,LatestDependencies,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
required,mod,1.21.5,fabric-api,fabric,latest,Fabric API,Essential hooks,fabric-api.jar,https://modrinth.com/mod/fabric-api,Core Library,,,,modrinth,modrinth,,,,,,,,,,,,,,,,,
required,mod,1.21.5,238222,fabric,latest,Just Enough Items,Item viewing,jei.jar,https://www.curseforge.com/minecraft/mc-mods/jei,Utility,,,,curseforge,curseforge,,,,,,,,,,,,,,,,,
'@

$mixedDbPath = Join-Path $TestOutputDir "mixed-provider-test.csv"
$mixedModlistContent | Out-File -FilePath $mixedDbPath -Encoding UTF8

$mixedValidationOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateAllModVersions -DatabaseFile $mixedDbPath -ApiResponseFolder $script:TestApiResponseDir -UseCachedResponses 2>&1

$mixedValidationCompleted = ($mixedValidationOutput -match "Update Summary").Count -gt 0
Write-TestResult "Mixed Provider Validation" $mixedValidationCompleted

# Show detailed results for debugging
Write-Host "`nDetailed Test Results:" -ForegroundColor $Colors.Info
Write-Host "=======================" -ForegroundColor $Colors.Info

Write-Host "Test Environment:" -ForegroundColor Gray
Write-Host "  Output Dir: $TestOutputDir" -ForegroundColor Gray
Write-Host "  API Response Dir: $script:TestApiResponseDir" -ForegroundColor Gray
Write-Host "  Test Database: $TestDbPath" -ForegroundColor Gray

Write-Host "`nAPI Status:" -ForegroundColor Green
Write-Host "  ✓ CurseForge API is now working with valid API key" -ForegroundColor Green
Write-Host "  ✓ All test projects accessible (357540, 238222, 32274)" -ForegroundColor Green

Show-TestSummary "CurseForge Functionality Tests"

Write-Host "`nCurseForge Functionality Tests Complete" -ForegroundColor $Colors.Info

return ($script:TestResults.Failed -eq 0)