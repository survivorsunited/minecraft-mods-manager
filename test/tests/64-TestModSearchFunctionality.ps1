# Mod Search Functionality Tests
# Tests that the mod search API integration works correctly

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "64-TestModSearchFunctionality.ps1"

Write-Host "Minecraft Mod Manager - Mod Search Functionality Tests" -ForegroundColor $Colors.Header
Write-Host "======================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"

Write-TestHeader "Test Environment Setup"

# Import core functions for testing search directly
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

Write-TestResult "Test Environment Setup" $true

# Test 1: Test Search Function Directly (Non-Interactive)
Write-TestHeader "Test 1: Test Search Function Directly"

try {
    $searchResults = Search-ModrinthProjects -Query "sodium" -ProjectType "mod" -Limit 5 -Quiet
    $searchWorked = $searchResults -and $searchResults.Count -gt 0
    
    Write-TestResult "Search API Call Successful" $searchWorked
    
    if ($searchResults) {
        Write-Host "  Found $($searchResults.Count) results" -ForegroundColor Gray
        Write-Host "  First result: $($searchResults[0].title)" -ForegroundColor Gray
        Write-Host "  Project ID: $($searchResults[0].project_id)" -ForegroundColor Gray
        Write-Host "  Project type: $($searchResults[0].project_type)" -ForegroundColor Gray
    }
} catch {
    Write-TestResult "Search API Call Successful" $false
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Test Search with Different Queries
Write-TestHeader "Test 2: Test Search with Different Queries"

$testQueries = @(
    @{ Query = "fabric api"; Type = "mod"; ExpectedFirst = "Fabric API" },
    @{ Query = "shaders"; Type = "shader"; ExpectedFirst = "BSL Shaders" },
    @{ Query = "datapack"; Type = "datapack"; ExpectedFirst = $null }  # Any datapack is fine
)

$allQueriesWorked = $true

foreach ($test in $testQueries) {
    try {
        $results = Search-ModrinthProjects -Query $test.Query -ProjectType $test.Type -Limit 3 -Quiet
        $queryWorked = $results -and $results.Count -gt 0
        
        if ($queryWorked) {
            Write-Host "  ✓ '$($test.Query)' ($($test.Type)): Found $($results.Count) results" -ForegroundColor Green
            if ($test.ExpectedFirst) {
                $foundExpected = $results[0].title -like "*$($test.ExpectedFirst)*"
                if (-not $foundExpected) {
                    Write-Host "    Note: Expected '$($test.ExpectedFirst)' but got '$($results[0].title)'" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "  ✗ '$($test.Query)' ($($test.Type)): No results" -ForegroundColor Red
            $allQueriesWorked = $false
        }
    } catch {
        Write-Host "  ✗ '$($test.Query)' ($($test.Type)): Error - $($_.Exception.Message)" -ForegroundColor Red
        $allQueriesWorked = $false
    }
}

Write-TestResult "Multiple Query Types Work" $allQueriesWorked

# Test 3: Test Search URL Construction
Write-TestHeader "Test 3: Test Search URL Construction"

# Test that the search builds correct URLs (we can't easily test this without modifying the function)
# But we can test that different parameters don't break the function

try {
    # Test with categories
    $resultsWithCategories = Search-ModrinthProjects -Query "optimization" -Categories @("performance", "utility") -Limit 2 -Quiet
    $categoriesWork = $resultsWithCategories -and $resultsWithCategories.Count -gt 0
    
    # Test with loaders
    $resultsWithLoaders = Search-ModrinthProjects -Query "api" -Loaders @("fabric", "forge") -Limit 2 -Quiet
    $loadersWork = $resultsWithLoaders -and $resultsWithLoaders.Count -gt 0
    
    # Test with game versions
    $resultsWithVersions = Search-ModrinthProjects -Query "sodium" -Versions @("1.21.5") -Limit 2 -Quiet
    $versionsWork = $resultsWithVersions -and $resultsWithVersions.Count -gt 0
    
    $advancedFiltersWork = $categoriesWork -and $loadersWork -and $versionsWork
    
    Write-TestResult "Advanced Filters Work" $advancedFiltersWork
    
    if ($categoriesWork) {
        Write-Host "  ✓ Categories filter: Found $($resultsWithCategories.Count) results" -ForegroundColor Green
    }
    if ($loadersWork) {
        Write-Host "  ✓ Loaders filter: Found $($resultsWithLoaders.Count) results" -ForegroundColor Green
    }
    if ($versionsWork) {
        Write-Host "  ✓ Versions filter: Found $($resultsWithVersions.Count) results" -ForegroundColor Green
    }
    
} catch {
    Write-TestResult "Advanced Filters Work" $false
    Write-Host "  Error testing advanced filters: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Test Error Handling
Write-TestHeader "Test 4: Test Error Handling"

try {
    # Test with empty query
    $emptyResults = Search-ModrinthProjects -Query "" -Quiet
    $emptyHandled = $emptyResults -eq $null
    
    # Test with very specific query that should return no results
    $noResults = Search-ModrinthProjects -Query "verylongandspecificquerythatshouldfindnothing12345" -Quiet
    $noResultsHandled = $noResults -eq $null
    
    $errorHandlingWorks = $emptyHandled -and $noResultsHandled
    
    Write-TestResult "Error Handling Works" $errorHandlingWorks
    
    if ($emptyHandled) {
        Write-Host "  ✓ Empty query handled correctly" -ForegroundColor Green
    }
    if ($noResultsHandled) {
        Write-Host "  ✓ No results scenario handled correctly" -ForegroundColor Green
    }
    
} catch {
    Write-TestResult "Error Handling Works" $false
    Write-Host "  Error testing error handling: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Test Integration with Project URL Generation
Write-TestHeader "Test 5: Test Project URL Generation"

try {
    $sodiumResult = Search-ModrinthProjects -Query "sodium" -ProjectType "mod" -Limit 1 -Quiet
    
    if ($sodiumResult -and $sodiumResult.Count -gt 0) {
        $project = $sodiumResult[0]
        
        # Test URL generation (this is what the ModManager does)
        $expectedUrl = "https://modrinth.com/$($project.project_type)/$($project.slug)"
        $urlGenerated = $expectedUrl -match "https://modrinth.com/mod/"
        
        Write-TestResult "Project URL Generation" $urlGenerated
        
        if ($urlGenerated) {
            Write-Host "  Generated URL: $expectedUrl" -ForegroundColor Gray
            Write-Host "  Project slug: $($project.slug)" -ForegroundColor Gray
        }
    } else {
        Write-TestResult "Project URL Generation" $false
        Write-Host "  Could not get search result for URL generation test" -ForegroundColor Red
    }
} catch {
    Write-TestResult "Project URL Generation" $false
    Write-Host "  Error testing URL generation: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Test API Response Structure
Write-TestHeader "Test 6: Test API Response Structure"

try {
    $result = Search-ModrinthProjects -Query "fabric-api" -Limit 1 -Quiet
    
    if ($result -and $result.Count -gt 0) {
        $project = $result[0]
        
        # Check that expected properties exist
        $hasRequiredProperties = ($project.project_id -and 
                                $project.title -and 
                                $project.description -and 
                                $project.project_type -and 
                                $project.slug)
        
        Write-TestResult "API Response Structure Valid" $hasRequiredProperties
        
        if ($hasRequiredProperties) {
            Write-Host "  ✓ All required properties present" -ForegroundColor Green
            Write-Host "    - project_id: $($project.project_id)" -ForegroundColor Gray
            Write-Host "    - title: $($project.title)" -ForegroundColor Gray
            Write-Host "    - project_type: $($project.project_type)" -ForegroundColor Gray
            Write-Host "    - slug: $($project.slug)" -ForegroundColor Gray
        } else {
            Write-Host "  ✗ Missing required properties" -ForegroundColor Red
        }
    } else {
        Write-TestResult "API Response Structure Valid" $false
        Write-Host "  Could not get search result for structure test" -ForegroundColor Red
    }
} catch {
    Write-TestResult "API Response Structure Valid" $false
    Write-Host "  Error testing API response structure: $($_.Exception.Message)" -ForegroundColor Red
}

# Show detailed results for debugging
Write-Host "`nDetailed Test Results:" -ForegroundColor $Colors.Info
Write-Host "========================" -ForegroundColor $Colors.Info

if ($searchResults -and $searchResults.Count -gt 0) {
    Write-Host "Sample search results for 'sodium':" -ForegroundColor Gray
    for ($i = 0; $i -lt [Math]::Min(3, $searchResults.Count); $i++) {
        $project = $searchResults[$i]
        Write-Host "  $($i+1). $($project.title) ($($project.project_type))" -ForegroundColor Gray
        Write-Host "     ID: $($project.project_id), Slug: $($project.slug)" -ForegroundColor DarkGray
    }
}

Show-TestSummary "Mod Search Functionality Tests"

Write-Host "`nMod Search Functionality Tests Complete" -ForegroundColor $Colors.Info 

return ($script:TestResults.Failed -eq 0)