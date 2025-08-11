# Fabric API Validation Test
# Tests that ModManager validation correctly updates fabric-api next version info

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "84-TestFabricApiNextValidation.ps1"

Write-Host "Minecraft Mod Manager - Fabric API Next Validation Test" -ForegroundColor $Colors.Header
Write-Host "=======================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName -UseMigratedSchema

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDbPath = Join-Path $TestOutputDir "fabric-api-next-test.csv"

# Create necessary directories
New-Item -ItemType Directory -Path $script:TestApiResponseDir -Force | Out-Null

# Copy the main database and filter to just fabric-api
Copy-Item -Path "$PSScriptRoot\..\..\modlist.csv" -Destination $TestDbPath -Force

Write-TestHeader "Before Validation - Check Current fabric-api Data"

# Read the current fabric-api entry
$beforeData = Import-Csv -Path $TestDbPath
$fabricApiBefore = $beforeData | Where-Object { $_.ID -eq "fabric-api" } | Select-Object -First 1

if ($fabricApiBefore) {
    Write-Host "  Current fabric-api data:" -ForegroundColor Cyan
    Write-Host "    CurrentVersion: $($fabricApiBefore.CurrentVersion)" -ForegroundColor Gray
    Write-Host "    CurrentGameVersion: $($fabricApiBefore.CurrentGameVersion)" -ForegroundColor Gray  
    Write-Host "    NextVersion: $($fabricApiBefore.NextVersion)" -ForegroundColor Gray
    Write-Host "    NextVersionUrl: $($fabricApiBefore.NextVersionUrl)" -ForegroundColor Gray
    Write-Host "    NextGameVersion: $($fabricApiBefore.NextGameVersion)" -ForegroundColor Gray
    Write-TestResult "fabric-api found in database" $true $TestFileName
} else {
    Write-TestResult "fabric-api found in database" $false $TestFileName
}

Write-TestHeader "Test Direct API Query for fabric-api 1.21.6"

# Test that fabric-api 1.21.6 version actually exists on Modrinth
Write-Host "  Querying Modrinth API for fabric-api 1.21.6 versions..." -ForegroundColor Cyan
$apiUrl = 'https://api.modrinth.com/v2/project/fabric-api/version?loaders=["fabric"]&game_versions=["1.21.6"]'
$headers = @{
    'Accept' = 'application/json'
    'User-Agent' = 'MinecraftModManager/1.0'
}
try {
    $apiResponse = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
} catch {
    $apiResponse = $null
    Write-Host "  API Error: $_" -ForegroundColor Red
}

if ($apiResponse) {
    if ($apiResponse -and $apiResponse.Count -gt 0) {
        $latestVersion = $apiResponse[0]
        Write-Host "  ✓ Found fabric-api version for 1.21.6: $($latestVersion.version_number)" -ForegroundColor Green
        Write-Host "    Download URL: $($latestVersion.files[0].url)" -ForegroundColor Gray
        Write-TestResult "fabric-api 1.21.6 version exists on Modrinth" $true
    } else {
        Write-Host "  ❌ No fabric-api versions found for 1.21.6" -ForegroundColor Red
        Write-TestResult "fabric-api 1.21.6 version exists on Modrinth" $false
    }
} else {
    Write-Host "  ❌ API query failed" -ForegroundColor Red
    Write-TestResult "fabric-api 1.21.6 version exists on Modrinth" $false
}

Write-TestHeader "Run Validation on fabric-api"

# Run validation on the database
Test-Command "& '$ModManagerPath' -ValidateAllModVersions -DatabaseFile '$TestDbPath' -ApiResponseFolder '$script:TestApiResponseDir'" "Validate All Mod Versions" 0 $null $TestFileName

Write-TestHeader "After Validation - Check Updated fabric-api Data"

# Read the updated fabric-api entry
$afterData = Import-Csv -Path $TestDbPath
$fabricApiAfter = $afterData | Where-Object { $_.ID -eq "fabric-api" } | Select-Object -First 1

if ($fabricApiAfter) {
    Write-Host "  Updated fabric-api data:" -ForegroundColor Cyan
    Write-Host "    CurrentVersion: $($fabricApiAfter.CurrentVersion)" -ForegroundColor Gray
    Write-Host "    CurrentGameVersion: $($fabricApiAfter.CurrentGameVersion)" -ForegroundColor Gray  
    Write-Host "    NextVersion: $($fabricApiAfter.NextVersion)" -ForegroundColor Gray
    Write-Host "    NextVersionUrl: $($fabricApiAfter.NextVersionUrl)" -ForegroundColor Gray
    Write-Host "    NextGameVersion: $($fabricApiAfter.NextGameVersion)" -ForegroundColor Gray
    
    # Expected: NextVersion should be something like "0.128.2+1.21.6"
    # Expected: NextVersionUrl should contain "1.21.6" 
    # Expected: NextGameVersion should be "1.21.6"
    
    $nextVersionCorrect = $fabricApiAfter.NextVersion -like "*1.21.6*" -and $fabricApiAfter.NextVersion -ne $fabricApiBefore.NextVersion
    $nextUrlCorrect = $fabricApiAfter.NextVersionUrl -like "*1.21.6*" -and $fabricApiAfter.NextVersionUrl -ne $fabricApiBefore.NextVersionUrl  
    $nextGameVersionCorrect = $fabricApiAfter.NextGameVersion -eq "1.21.6"
    
    Write-TestResult "NextVersion updated to 1.21.6 version" $nextVersionCorrect $TestFileName
    Write-TestResult "NextVersionUrl updated to 1.21.6 URL" $nextUrlCorrect $TestFileName
    Write-TestResult "NextGameVersion set to 1.21.6" $nextGameVersionCorrect $TestFileName
    
    if ($nextVersionCorrect) {
        Write-Host "  ✓ NextVersion correctly updated from '$($fabricApiBefore.NextVersion)' to '$($fabricApiAfter.NextVersion)'" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NextVersion NOT updated - still: '$($fabricApiAfter.NextVersion)'" -ForegroundColor Red
    }
    
    if ($nextUrlCorrect) {
        Write-Host "  ✓ NextVersionUrl correctly updated" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NextVersionUrl NOT updated - still: '$($fabricApiAfter.NextVersionUrl)'" -ForegroundColor Red  
    }
    
} else {
    Write-TestResult "fabric-api still exists after validation" $false $TestFileName
}

Write-TestHeader "Run Calculate-NextVersionData Directly"

# Import and run the Calculate-NextVersionData function directly
. "$PSScriptRoot\\..\\..\\src\\Data\\Version\\Calculate-NextVersionData.ps1"

Write-Host "  Running Calculate-NextVersionData on database..." -ForegroundColor Cyan
$calculateResult = Calculate-NextVersionData -CsvPath $TestDbPath -ReturnData

if ($calculateResult -and $calculateResult.Count -gt 0) {
    $fabricApiCalculated = $calculateResult | Where-Object { $_.ID -eq "fabric-api" } | Select-Object -First 1
    
    if ($fabricApiCalculated) {
        Write-Host "  Calculate-NextVersionData results for fabric-api:" -ForegroundColor Cyan
        Write-Host "    NextVersion: $($fabricApiCalculated.NextVersion)" -ForegroundColor Gray
        Write-Host "    NextVersionUrl: $($fabricApiCalculated.NextVersionUrl)" -ForegroundColor Gray
        Write-Host "    NextGameVersion: $($fabricApiCalculated.NextGameVersion)" -ForegroundColor Gray
        
        # Check if it properly set NextGameVersion to 1.21.6
        if ($fabricApiCalculated.NextGameVersion -eq "1.21.6") {
            Write-TestResult "Calculate-NextVersionData sets NextGameVersion to 1.21.6" $true
        } else {
            Write-TestResult "Calculate-NextVersionData sets NextGameVersion to 1.21.6" $false
            Write-Host "  ❌ Expected NextGameVersion to be 1.21.6 but got: $($fabricApiCalculated.NextGameVersion)" -ForegroundColor Red
        }
        
        # Check if NextVersion was updated from LatestVersion since fabric-api supports 1.21.6
        if ($fabricApiCalculated.NextVersion -and $fabricApiCalculated.NextVersion -ne $fabricApiBefore.NextVersion) {
            Write-TestResult "Calculate-NextVersionData updates NextVersion" $true
        } else {
            Write-TestResult "Calculate-NextVersionData updates NextVersion" $false
            Write-Host "  ❌ NextVersion was not updated by Calculate-NextVersionData" -ForegroundColor Red
        }
    } else {
        Write-Host "  ❌ fabric-api not found in Calculate-NextVersionData results" -ForegroundColor Red
        Write-TestResult "Calculate-NextVersionData processes fabric-api" $false
    }
} else {
    Write-Host "  ❌ Calculate-NextVersionData returned no results" -ForegroundColor Red
    Write-TestResult "Calculate-NextVersionData executes successfully" $false
}

# Final summary
Write-TestSummary $TestFileName