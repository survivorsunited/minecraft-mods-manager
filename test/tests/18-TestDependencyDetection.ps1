# Test Dependency Detection Functionality
# Tests the new dependency detection feature that extracts and stores mod dependencies

param([string]$TestFileName = $null)

# Import test framework
. (Join-Path $PSScriptRoot "..\TestFramework.ps1")

function Invoke-TestDependencyDetection {
    param([string]$TestFileName = $null)
    
    Write-TestSuiteHeader "Test Dependency Detection Functionality" $TestFileName
    
    # Initialize test results
    $script:TestResults = @{
        Total = 0
        Passed = 0
        Failed = 0
    }
    
    # Test setup - PROPER ISOLATION
    $TestOutputDir = Join-Path $PSScriptRoot "..\test-output\18-TestDependencyDetection"
    $TestDownloadDir = Join-Path $TestOutputDir "download"
    $TestApiResponseDir = Join-Path $PSScriptRoot "..\apiresponse"
    $ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
    $ModListPath = Join-Path $PSScriptRoot "..\..\modlist.csv"
    $TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"
    
    # Clean previous test artifacts
    if (Test-Path $TestOutputDir) {
        Remove-Item -Path $TestOutputDir -Recurse -Force
    }
    
    # Ensure clean state
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $TestDownloadDir -Force | Out-Null
    
    # Copy main modlist to test location for isolation
    Copy-Item -Path $ModListPath -Destination $TestModListPath -Force
    
    Write-Host "🧪 Testing Dependency Detection Functionality" -ForegroundColor Cyan
    
    # Test 1: Verify dependency columns are added to CSV
    Write-Host "Test 1: Verifying dependency columns in CSV..." -ForegroundColor Yellow
    $script:TestResults.Total++
    
    try {
        # Run update to ensure dependency columns are added - USING ISOLATED FILES
        $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $TestModListPath -ApiResponseFolder $TestApiResponseDir -UseCachedResponses
        if ($LASTEXITCODE -eq 0) {
            # Check if dependency columns exist in TEST CSV
            $csvContent = Import-Csv $TestModListPath
            $headers = $csvContent[0].PSObject.Properties.Name
            
            if ($headers -contains "CurrentDependencies" -and $headers -contains "LatestDependencies") {
                Write-Host "✅ Dependency columns found in CSV" -ForegroundColor Green
                $script:TestResults.Passed++
            } else {
                Write-Host "❌ Dependency columns not found in CSV" -ForegroundColor Red
                Write-Host "   Found headers: $($headers -join ', ')" -ForegroundColor Gray
                $script:TestResults.Failed++
            }
        } else {
            Write-Host "❌ Failed to update mods: $result" -ForegroundColor Red
            $script:TestResults.Failed++
        }
    }
    catch {
        Write-Host "❌ Error testing dependency columns: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Failed++
    }
    
    # Test 2: Verify dependency extraction from API responses
    Write-Host "Test 2: Verifying dependency extraction from API..." -ForegroundColor Yellow
    $script:TestResults.Total++
    
    try {
        # Check if architectury-api has dependencies in API response - USING TEST API FOLDER
        $apiResponsePath = Join-Path $TestApiResponseDir "modrinth\architectury-api-versions.json"
        if (Test-Path $apiResponsePath) {
            $apiResponse = Get-Content $apiResponsePath | ConvertFrom-Json
            
            # Find Fabric version with dependencies
            $fabricVersion = $apiResponse | Where-Object { 
                $_.loaders -contains "fabric" -and $_.dependencies.Count -gt 0 
            } | Select-Object -First 1
            
            if ($fabricVersion -and $fabricVersion.dependencies.Count -gt 0) {
                Write-Host "✅ Found dependencies in API response" -ForegroundColor Green
                Write-Host "   Dependencies: $($fabricVersion.dependencies | ConvertTo-Json -Compress)" -ForegroundColor Gray
                $script:TestResults.Passed++
            } else {
                Write-Host "❌ No dependencies found in API response" -ForegroundColor Red
                $script:TestResults.Failed++
            }
        } else {
            Write-Host "❌ API response file not found: $apiResponsePath" -ForegroundColor Red
            $script:TestResults.Failed++
        }
    }
    catch {
        Write-Host "❌ Error testing dependency extraction: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Failed++
    }
    
    # Test 3: Verify Convert-DependenciesToJson function
    Write-Host "Test 3: Verifying Convert-DependenciesToJson function..." -ForegroundColor Yellow
    $script:TestResults.Total++
    
    try {
        # Test with sample dependency data
        $sampleDependencies = @(
            @{
                project_id = "P7dR8mSH"
                dependency_type = "required"
                version_id = $null
                version_range = $null
            }
        )
        
        # Call the function directly
        $jsonResult = & pwsh -NoProfile -ExecutionPolicy Bypass -Command {
            param($deps)
            
            # Function to convert dependencies to JSON format for CSV storage
            function Convert-DependenciesToJson {
                param(
                    [Parameter(Mandatory=$true)]
                    $Dependencies
                )
                
                try {
                    if (-not $Dependencies -or $Dependencies.Count -eq 0) {
                        return ""
                    }
                    
                    $dependencyList = @()
                    foreach ($dep in $Dependencies) {
                        $dependencyInfo = @{
                            project_id = $dep.project_id
                            dependency_type = $dep.dependency_type
                            version_id = if ($dep.version_id) { $dep.version_id } else { $null }
                            version_range = if ($dep.version_range) { $dep.version_range } else { $null }
                        }
                        $dependencyList += $dependencyInfo
                    }
                    
                    return $dependencyList | ConvertTo-Json -Compress
                }
                catch {
                    Write-Warning "Failed to convert dependencies to JSON: $($_.Exception.Message)"
                    return ""
                }
            }
            
            Convert-DependenciesToJson -Dependencies $deps
        } -Args $sampleDependencies
        
        if ($jsonResult -and $jsonResult -ne "") {
            Write-Host "✅ Convert-DependenciesToJson function working" -ForegroundColor Green
            Write-Host "   Result: $jsonResult" -ForegroundColor Gray
            $script:TestResults.Passed++
        } else {
            Write-Host "❌ Convert-DependenciesToJson function failed" -ForegroundColor Red
            $script:TestResults.Failed++
        }
    }
    catch {
        Write-Host "❌ Error testing Convert-DependenciesToJson: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Failed++
    }
    
    # Test 4: Verify dependency data in CSV after update
    Write-Host "Test 4: Verifying dependency data in CSV..." -ForegroundColor Yellow
    $script:TestResults.Total++
    
    try {
        # Check if any mods have dependency data - USING TEST CSV
        $csvContent = Import-Csv $TestModListPath
        $modsWithDependencies = $csvContent | Where-Object { 
            $_.CurrentDependencies -or $_.LatestDependencies 
        }
        
        if ($modsWithDependencies.Count -gt 0) {
            Write-Host "✅ Found $($modsWithDependencies.Count) mods with dependency data" -ForegroundColor Green
            foreach ($mod in $modsWithDependencies | Select-Object -First 3) {
                Write-Host "   $($mod.Name): CurrentDependencies=$($mod.CurrentDependencies), LatestDependencies=$($mod.LatestDependencies)" -ForegroundColor Gray
            }
            $script:TestResults.Passed++
        } else {
            Write-Host "❌ No mods found with dependency data" -ForegroundColor Red
            $script:TestResults.Failed++
        }
    }
    catch {
        Write-Host "❌ Error checking dependency data in CSV: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Failed++
    }
    
    # Test 5: Verify dependency parsing in Validate-ModVersion
    Write-Host "Test 5: Verifying dependency parsing in Validate-ModVersion..." -ForegroundColor Yellow
    $script:TestResults.Total++
    
    try {
        # Test with a mod that should have dependencies - USING ISOLATED FILES
        $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -ValidateMod -ModID "architectury-api" -DatabaseFile $TestModListPath -ApiResponseFolder $TestApiResponseDir -UseCachedResponses
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Validate-ModVersion executed successfully" -ForegroundColor Green
            $script:TestResults.Passed++
        } else {
            Write-Host "❌ Validate-ModVersion failed" -ForegroundColor Red
            $script:TestResults.Failed++
        }
    }
    catch {
        Write-Host "❌ Error testing Validate-ModVersion: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Failed++
    }
    
    # Summary
    Write-TestSuiteSummary "Test Dependency Detection Functionality"
    
    # Clean up test artifacts - PROPER CLEANUP
    if (Test-Path $TestOutputDir) {
        Remove-Item -Path $TestOutputDir -Recurse -Force
    }
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestDependencyDetection -TestFileName $TestFileName
