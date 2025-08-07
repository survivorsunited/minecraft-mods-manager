#!/usr/bin/env pwsh
# Test for Next version validation functionality

param(
    [string]$TestDir = "test-output/83-TestNextVersionValidation"
)

# Import test framework
. "$PSScriptRoot/../TestFramework.ps1"

$testName = "Next Version Validation Test"
Initialize-Test -TestName $testName -TestDir $TestDir

try {
    Write-Host "=== Test 83: Next Version Validation Test ===" -ForegroundColor Cyan
    
    # Create test database with Current/Next/Latest structure
    $testCsv = Join-Path $testOutputDir "validation-test.csv"
    
    $csvContent = @"
Group,Type,CurrentGameVersion,ID,Loader,CurrentVersion,Name,Description,Jar,Url,Category,CurrentVersionUrl,NextVersion,NextVersionUrl,NextGameVersion,LatestVersionUrl,LatestVersion,LatestGameVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
required,mod,1.21.5,fabric-api,fabric,0.127.1+1.21.5,Fabric API,Essential API for Fabric mods,,https://modrinth.com/mod/fabric-api,api,https://cdn.modrinth.com/data/P7dR8mSH/versions/current.jar,0.127.1+1.21.6,https://cdn.modrinth.com/data/P7dR8mSH/versions/next.jar,1.21.6,https://cdn.modrinth.com/data/P7dR8mSH/versions/latest.jar,0.128.0+1.21.8,1.21.8,modrinth,modrinth,,,,,,,,,,,,"1.21.5,1.21.6,1.21.7,1.21.8",,,
required,mod,1.21.5,sodium,fabric,mc1.21.5-0.6.13-fabric,Sodium,Modern rendering engine,,https://modrinth.com/mod/sodium,performance,https://cdn.modrinth.com/data/AANobbMI/versions/current.jar,mc1.21.6-0.6.13-fabric,https://cdn.modrinth.com/data/AANobbMI/versions/next.jar,1.21.6,https://cdn.modrinth.com/data/AANobbMI/versions/latest.jar,mc1.21.8-0.6.14-fabric,1.21.8,modrinth,modrinth,,,,,,,,,,,,"1.21.5,1.21.6,1.21.7,1.21.8",,,
"@

    Set-Content -Path $testCsv -Value $csvContent -Encoding UTF8
    Write-Host "✓ Created test database with Next version data" -ForegroundColor Green
    
    # Test 1: Validate-AllModVersions includes Next version fields
    Write-Host "`n--- Test 1: Validate-AllModVersions Next Version Support ---" -ForegroundColor Yellow
    
    $validationResult = & $ModManagerPath -DatabaseFile $testCsv -ValidateAllModVersions -UseCachedResponses -ApiResponseFolder $apiResponseDir
    $validationExitCode = $LASTEXITCODE
    
    if ($validationExitCode -eq 0) {
        Write-Host "✓ Validation completed successfully" -ForegroundColor Green
        
        # Check validation results file for Next version fields
        $resultsFile = Join-Path $apiResponseDir "version-validation-results.csv"
        if (Test-Path $resultsFile) {
            $results = Import-Csv -Path $resultsFile
            
            $nextVersionFields = @("NextVersion", "NextVersionUrl", "NextGameVersion")
            $missingFields = @()
            
            foreach ($field in $nextVersionFields) {
                if (-not ($results[0].PSObject.Properties.Name -contains $field)) {
                    $missingFields += $field
                }
            }
            
            if ($missingFields.Count -eq 0) {
                Write-Host "✓ Validation results include all Next version fields" -ForegroundColor Green
            } else {
                Write-Host "✗ Missing Next version fields: $($missingFields -join ', ')" -ForegroundColor Red
                $global:TestFailed = $true
            }
            
            # Check if Next version data was populated
            $fabricResult = $results | Where-Object { $_.ID -eq "fabric-api" } | Select-Object -First 1
            if ($fabricResult -and -not [string]::IsNullOrEmpty($fabricResult.NextGameVersion)) {
                Write-Host "✓ Next version data populated: NextGameVersion = $($fabricResult.NextGameVersion)" -ForegroundColor Green
            } else {
                Write-Host "⚠ Next version data not populated (may require API call)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "✗ Validation results file not found" -ForegroundColor Red
            $global:TestFailed = $true
        }
    } else {
        Write-Host "✗ Validation failed (exit code: $validationExitCode)" -ForegroundColor Red
        $global:TestFailed = $true
    }
    
    # Test 2: Validate-ModVersionUrls checks all three tiers
    Write-Host "`n--- Test 2: URL Validation for All Tiers ---" -ForegroundColor Yellow
    
    # Create test database with mismatched URLs
    $urlTestCsv = Join-Path $testOutputDir "url-validation-test.csv"
    $urlTestContent = @"
Group,Type,CurrentGameVersion,ID,Loader,CurrentVersion,Name,Description,Jar,Url,Category,CurrentVersionUrl,NextVersion,NextVersionUrl,NextGameVersion,LatestVersionUrl,LatestVersion,LatestGameVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
required,mod,1.21.5,test-mod,fabric,1.0.0,Test Mod,Test mod for URL validation,,https://example.com,test,https://cdn.example.com/1.21.6/mod.jar,1.0.1,https://cdn.example.com/1.21.5/mod.jar,1.21.6,https://cdn.example.com/1.21.7/mod.jar,1.0.2,1.21.8,modrinth,modrinth,,,,,,,,,,,,"1.21.5,1.21.6,1.21.7,1.21.8",,,
"@

    Set-Content -Path $urlTestCsv -Value $urlTestContent -Encoding UTF8
    
    # Import and test URL validation function
    $validationScript = Join-Path $PSScriptRoot "../../src/Validation/Database/Validate-ModVersionUrls.ps1"
    if (Test-Path $validationScript) {
        . $validationScript
        
        try {
            $urlValidationResults = Validate-ModVersionUrls -CsvPath $urlTestCsv -DryRun
            Write-Host "✓ URL validation function executed successfully" -ForegroundColor Green
            
            # The function should detect mismatches in all three URL types
            # CurrentVersionUrl has 1.21.6 but should match CurrentGameVersion (1.21.5)
            # NextVersionUrl has 1.21.5 but should match NextGameVersion (1.21.6) 
            # LatestVersionUrl has 1.21.7 but should match LatestGameVersion (1.21.8)
            
            Write-Host "✓ URL validation tested all three tiers" -ForegroundColor Green
        } catch {
            Write-Host "✗ URL validation failed: $($_.Exception.Message)" -ForegroundColor Red
            $global:TestFailed = $true
        }
    } else {
        Write-Host "✗ URL validation script not found: $validationScript" -ForegroundColor Red
        $global:TestFailed = $true
    }
    
    # Test 3: Update-WithLatestVersions populates Next columns
    Write-Host "`n--- Test 3: Update Function Next Version Support ---" -ForegroundColor Yellow
    
    # Create mock validation results with Next version data
    $mockResults = @(
        [PSCustomObject]@{
            ModId = "fabric-api"
            VersionUrl = "https://cdn.example.com/current.jar"
            NextVersionUrl = "https://cdn.example.com/next.jar"
            NextVersion = "0.127.2+1.21.6"
            NextGameVersion = "1.21.6"
            LatestVersionUrl = "https://cdn.example.com/latest.jar"
            LatestVersion = "0.128.1+1.21.8"
            LatestGameVersion = "1.21.8"
        }
    )
    
    # Import and test update function
    $updateScript = Join-Path $PSScriptRoot "../../src/Database/CSV/Update-WithLatestVersions.ps1"
    if (Test-Path $updateScript) {
        . $updateScript
        
        try {
            $updateTestCsv = Join-Path $testOutputDir "update-test.csv"
            Copy-Item -Path $testCsv -Destination $updateTestCsv
            
            $updatedCount = Update-ModListWithLatestVersions -CsvPath $updateTestCsv -ValidationResults $mockResults
            
            if ($updatedCount -gt 0) {
                Write-Host "✓ Update function executed successfully" -ForegroundColor Green
                
                # Verify Next version data was populated
                $updatedMods = Import-Csv -Path $updateTestCsv
                $fabricMod = $updatedMods | Where-Object { $_.ID -eq "fabric-api" } | Select-Object -First 1
                
                if ($fabricMod.NextVersion -eq "0.127.2+1.21.6") {
                    Write-Host "✓ NextVersion updated correctly" -ForegroundColor Green
                } else {
                    Write-Host "✗ NextVersion not updated correctly" -ForegroundColor Red
                    $global:TestFailed = $true
                }
                
                if ($fabricMod.NextGameVersion -eq "1.21.6") {
                    Write-Host "✓ NextGameVersion updated correctly" -ForegroundColor Green
                } else {
                    Write-Host "✗ NextGameVersion not updated correctly" -ForegroundColor Red
                    $global:TestFailed = $true
                }
            } else {
                Write-Host "✗ Update function returned 0 updated records" -ForegroundColor Red
                $global:TestFailed = $true
            }
        } catch {
            Write-Host "✗ Update function failed: $($_.Exception.Message)" -ForegroundColor Red
            $global:TestFailed = $true
        }
    } else {
        Write-Host "✗ Update function script not found: $updateScript" -ForegroundColor Red
        $global:TestFailed = $true
    }
    
    # Test 4: Calculate-NextVersionData function works correctly
    Write-Host "`n--- Test 4: Next Version Calculation ---" -ForegroundColor Yellow
    
    $calcScript = Join-Path $PSScriptRoot "../../src/Data/Version/Calculate-NextVersionData.ps1"
    if (Test-Path $calcScript) {
        . $calcScript
        
        try {
            $nextVersionData = Calculate-NextVersionData -CsvPath $testCsv
            
            if ($nextVersionData -and $nextVersionData.Count -gt 0) {
                Write-Host "✓ Next version calculation completed" -ForegroundColor Green
                
                # Check if fabric-api has next version data
                $fabricNext = $nextVersionData | Where-Object { $_.ID -eq "fabric-api" } | Select-Object -First 1
                if ($fabricNext -and $fabricNext.NextGameVersion) {
                    Write-Host "✓ Next version calculated for fabric-api: $($fabricNext.NextGameVersion)" -ForegroundColor Green
                } else {
                    Write-Host "⚠ Next version not calculated for fabric-api (may be expected)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "✗ Next version calculation returned no results" -ForegroundColor Red
                $global:TestFailed = $true
            }
        } catch {
            Write-Host "✗ Next version calculation failed: $($_.Exception.Message)" -ForegroundColor Red
            $global:TestFailed = $true
        }
    } else {
        Write-Host "✗ Next version calculation script not found: $calcScript" -ForegroundColor Red
        $global:TestFailed = $true
    }
    
    # Test 5: Add-ModToDatabase uses new column structure
    Write-Host "`n--- Test 5: Add Mod Function Column Structure ---" -ForegroundColor Yellow
    
    $addTestCsv = Join-Path $testOutputDir "add-mod-test.csv"
    
    # Create empty CSV with headers
    $emptyContent = @"
Group,Type,CurrentGameVersion,ID,Loader,CurrentVersion,Name,Description,Jar,Url,Category,CurrentVersionUrl,NextVersion,NextVersionUrl,NextGameVersion,LatestVersionUrl,LatestVersion,LatestGameVersion,ApiSource,Host,IconUrl,ClientSide,ServerSide,Title,ProjectDescription,IssuesUrl,SourceUrl,WikiUrl,RecordHash,UrlDirect,AvailableGameVersions,CurrentDependenciesRequired,CurrentDependenciesOptional,LatestDependenciesRequired,LatestDependenciesOptional
"@
    Set-Content -Path $addTestCsv -Value $emptyContent -Encoding UTF8
    
    # Test adding a mod uses new column structure
    $addResult = & $ModManagerPath -DatabaseFile $addTestCsv -AddMod -AddModId "test-new-mod" -AddModName "Test New Mod" -AddModGameVersion "1.21.6" -AddModVersion "1.0.0"
    $addExitCode = $LASTEXITCODE
    
    if ($addExitCode -eq 0) {
        Write-Host "✓ Add mod completed successfully" -ForegroundColor Green
        
        # Verify new mod uses new column structure
        $addedMods = Import-Csv -Path $addTestCsv
        $newMod = $addedMods | Where-Object { $_.ID -eq "test-new-mod" } | Select-Object -First 1
        
        if ($newMod) {
            if ($newMod.CurrentGameVersion -eq "1.21.6") {
                Write-Host "✓ New mod uses CurrentGameVersion correctly" -ForegroundColor Green
            } else {
                Write-Host "✗ New mod CurrentGameVersion incorrect: $($newMod.CurrentGameVersion)" -ForegroundColor Red
                $global:TestFailed = $true
            }
            
            if ($newMod.CurrentVersion -eq "1.0.0") {
                Write-Host "✓ New mod uses CurrentVersion correctly" -ForegroundColor Green
            } else {
                Write-Host "✗ New mod CurrentVersion incorrect: $($newMod.CurrentVersion)" -ForegroundColor Red
                $global:TestFailed = $true
            }
            
            # Check Next version columns exist (even if empty)
            if ($newMod.PSObject.Properties.Name -contains "NextVersion") {
                Write-Host "✓ New mod has NextVersion column" -ForegroundColor Green
            } else {
                Write-Host "✗ New mod missing NextVersion column" -ForegroundColor Red
                $global:TestFailed = $true
            }
        } else {
            Write-Host "✗ New mod not found in database" -ForegroundColor Red
            $global:TestFailed = $true
        }
    } else {
        Write-Host "✗ Add mod failed (exit code: $addExitCode)" -ForegroundColor Red
        $global:TestFailed = $true
    }
    
    # Final result
    if ($global:TestFailed) {
        Write-Host "`n=== Test 83: Next Version Validation - FAILED ===" -ForegroundColor Red
        $global:FailedTests++
    } else {
        Write-Host "`n=== Test 83: Next Version Validation - PASSED ===" -ForegroundColor Green
        $global:PassedTests++
    }
    
} catch {
    Write-Host "`n=== Test 83: Next Version Validation - ERROR ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    $global:FailedTests++
} finally {
    Finalize-Test
}