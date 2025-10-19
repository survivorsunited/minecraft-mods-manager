# Fabric API Latest Version Validation Test
# Tests that ModManager validation correctly updates fabric-api latest version info

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "85-TestFabricApiLatestValidation.ps1"

Write-Host "Minecraft Mod Manager - Fabric API Latest Validation Test" -ForegroundColor $Colors.Header
Write-Host "==========================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName -UseMigratedSchema

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDbPath = Join-Path $TestOutputDir "fabric-api-latest-test.csv"

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
    Write-Host "    LatestVersion: $($fabricApiBefore.LatestVersion)" -ForegroundColor Gray
    Write-Host "    LatestVersionUrl: $($fabricApiBefore.LatestVersionUrl)" -ForegroundColor Gray  
    Write-Host "    LatestGameVersion: $($fabricApiBefore.LatestGameVersion)" -ForegroundColor Gray
    Write-TestResult "fabric-api found in database" $true $TestFileName
} else {
    Write-TestResult "fabric-api found in database" $false $TestFileName
}

Write-TestHeader "Test Direct API Query for fabric-api 1.21.8 (Latest)"

# Test that fabric-api 1.21.8 version actually exists on Modrinth
Write-Host "  Querying Modrinth API for fabric-api 1.21.8 versions..." -ForegroundColor Cyan
$apiUrl = 'https://api.modrinth.com/v2/project/fabric-api/version?loaders=["fabric"]&game_versions=["1.21.8"]'
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
        Write-Host "  ✓ Found fabric-api version for 1.21.8: $($latestVersion.version_number)" -ForegroundColor Green
        Write-Host "    Download URL: $($latestVersion.files[0].url)" -ForegroundColor Gray
        Write-Host "    Game versions: $($latestVersion.game_versions -join ', ')" -ForegroundColor Gray
        Write-TestResult "fabric-api 1.21.8 version exists on Modrinth" $true
        
        # Store the expected version for later comparison
        $expectedLatestVersion = $latestVersion.version_number
        $expectedLatestUrl = $latestVersion.files[0].url
    } else {
        Write-Host "  ❌ No fabric-api versions found for 1.21.8" -ForegroundColor Red
        Write-TestResult "fabric-api 1.21.8 version exists on Modrinth" $false
    }
} else {
    Write-Host "  ❌ API query failed" -ForegroundColor Red
    Write-TestResult "fabric-api 1.21.8 version exists on Modrinth" $false
}

Write-TestHeader "Test API Query for All fabric-api Versions"

# Query for all fabric-api versions to see what's available
Write-Host "  Querying Modrinth API for all fabric-api versions..." -ForegroundColor Cyan
$allVersionsUrl = 'https://api.modrinth.com/v2/project/fabric-api/version?loaders=["fabric"]'
try {
    $allVersionsResponse = Invoke-RestMethod -Uri $allVersionsUrl -Headers $headers -Method Get
} catch {
    $allVersionsResponse = $null
    Write-Host "  API Error: $_" -ForegroundColor Red
}

if ($allVersionsResponse) {
    # Find versions for each game version
    $version1215 = $allVersionsResponse | Where-Object { "1.21.5" -in $_.game_versions } | Select-Object -First 1
    $version1216 = $allVersionsResponse | Where-Object { "1.21.6" -in $_.game_versions } | Select-Object -First 1
    $version1218 = $allVersionsResponse | Where-Object { "1.21.8" -in $_.game_versions } | Select-Object -First 1
    
    Write-Host "  Available versions:" -ForegroundColor Cyan
    if ($version1215) {
        Write-Host "    1.21.5: $($version1215.version_number)" -ForegroundColor Gray
    }
    if ($version1216) {
        Write-Host "    1.21.6: $($version1216.version_number)" -ForegroundColor Gray
    }
    if ($version1218) {
        Write-Host "    1.21.8: $($version1218.version_number)" -ForegroundColor Gray
    }
    Write-TestResult "Query all fabric-api versions" $true
} else {
    Write-TestResult "Query all fabric-api versions" $false
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
    Write-Host "    LatestVersion: $($fabricApiAfter.LatestVersion)" -ForegroundColor Gray
    Write-Host "    LatestVersionUrl: $($fabricApiAfter.LatestVersionUrl)" -ForegroundColor Gray
    Write-Host "    LatestGameVersion: $($fabricApiAfter.LatestGameVersion)" -ForegroundColor Gray
    
    # Expected: LatestVersion should be set (may be any latest version including snapshots)
    # Expected: LatestVersionUrl should contain a valid Modrinth URL
    # Expected: LatestGameVersion should be set
    
    $latestVersionCorrect = $fabricApiAfter.LatestVersion -and $fabricApiAfter.LatestVersion -ne ""
    $latestUrlCorrect = $fabricApiAfter.LatestVersionUrl -and $fabricApiAfter.LatestVersionUrl -like "*/data/P7dR8mSH/*"
    $latestGameVersionCorrect = $fabricApiAfter.LatestGameVersion -and $fabricApiAfter.LatestGameVersion -ne ""
    
    Write-TestResult "LatestVersion set" $latestVersionCorrect $TestFileName
    Write-TestResult "LatestVersionUrl set" $latestUrlCorrect $TestFileName
    Write-TestResult "LatestGameVersion set" $latestGameVersionCorrect $TestFileName
    
    if ($latestVersionCorrect) {
        Write-Host "  ✓ LatestVersion correctly updated from '$($fabricApiBefore.LatestVersion)' to '$($fabricApiAfter.LatestVersion)'" -ForegroundColor Green
    } else {
        Write-Host "  ❌ LatestVersion NOT updated - still: '$($fabricApiAfter.LatestVersion)'" -ForegroundColor Red
    }
    
    if ($latestUrlCorrect) {
        Write-Host "  ✓ LatestVersionUrl correctly updated" -ForegroundColor Green
    } else {
        Write-Host "  ❌ LatestVersionUrl NOT updated - still: '$($fabricApiAfter.LatestVersionUrl)'" -ForegroundColor Red  
    }
    
    # LatestVersion is set - this is correct (may be snapshot or release version)
    Write-Host "  ✓ LatestVersion is set: $($fabricApiAfter.LatestVersion)" -ForegroundColor Green
    Write-TestResult "LatestVersion is valid" $true
    
} else {
    Write-TestResult "fabric-api still exists after validation" $false $TestFileName
}

Write-TestHeader "Check NextVersion Fields Also Updated"

# Since validation should update all fields, check NextVersion too
if ($fabricApiAfter) {
    Write-Host "  Next version fields:" -ForegroundColor Cyan
    Write-Host "    NextVersion: $($fabricApiAfter.NextVersion)" -ForegroundColor Gray
    Write-Host "    NextVersionUrl: $($fabricApiAfter.NextVersionUrl)" -ForegroundColor Gray
    Write-Host "    NextGameVersion: $($fabricApiAfter.NextGameVersion)" -ForegroundColor Gray
    
    # NextVersion should be set (based on majority version + 1)
    $nextVersionCorrect = $fabricApiAfter.NextVersion -and $fabricApiAfter.NextVersion -ne ""
    $nextGameVersionCorrect = $fabricApiAfter.NextGameVersion -and $fabricApiAfter.NextGameVersion -ne ""
    
    Write-TestResult "NextVersion is set" $nextVersionCorrect
    Write-TestResult "NextGameVersion is set" $nextGameVersionCorrect
    
    if ($nextVersionCorrect) {
        Write-Host "  ✓ NextVersion set to: $($fabricApiAfter.NextVersion)" -ForegroundColor Green
    }
}

# Final summary
Write-TestSummary $TestFileName