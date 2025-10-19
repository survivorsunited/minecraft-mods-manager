# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name
$TestFileName = "53-TestDependencyFieldSplit.ps1"

# Initialize test environment
Initialize-TestEnvironment $TestFileName

# Define paths
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestCsvPath = Join-Path $TestOutputDir "modlist.csv"

# Copy the main modlist to the test output directory for isolation
Copy-Item -Path (Join-Path $PSScriptRoot "..\..\modlist.csv") -Destination $TestCsvPath -Force

Write-Host "Minecraft Mod Manager - Dependency Field Split Tests" -ForegroundColor $Colors.Header
Write-Host "=====================================================" -ForegroundColor $Colors.Header

function Invoke-DependencyFieldSplitTest {
    param([string]$TestFileName = $null)

    Write-TestHeader "Step 1: Run update to split dependency fields"
    $result1 = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $TestCsvPath -UseCachedResponses
    $step1Success = $LASTEXITCODE -eq 0
    Write-TestResult "Update command executed successfully" $step1Success

    Write-TestHeader "Step 2: Validate dependency columns exist and are properly initialized"
    $csv = Import-Csv -Path $TestCsvPath
    $requiredColExists = $csv[0].PSObject.Properties.Name -contains "LatestDependenciesRequired"
    $optionalColExists = $csv[0].PSObject.Properties.Name -contains "LatestDependenciesOptional"
    $currentRequiredColExists = $csv[0].PSObject.Properties.Name -contains "CurrentDependenciesRequired"
    $currentOptionalColExists = $csv[0].PSObject.Properties.Name -contains "CurrentDependenciesOptional"
    
    # Check that all dependency columns exist
    $allColumnsExist = $requiredColExists -and $optionalColExists -and $currentRequiredColExists -and $currentOptionalColExists
    
    # Check that all mods have the dependency fields (even if empty)
    $allModsHaveRequired = $csv | Where-Object { $_.LatestDependenciesRequired -ne $null }
    $allModsHaveOptional = $csv | Where-Object { $_.LatestDependenciesOptional -ne $null }
    $allModsHaveCurrentRequired = $csv | Where-Object { $_.CurrentDependenciesRequired -ne $null }
    $allModsHaveCurrentOptional = $csv | Where-Object { $_.CurrentDependenciesOptional -ne $null }
    
    $allFieldsPresent = ($allModsHaveRequired.Count -eq $csv.Count) -and 
                       ($allModsHaveOptional.Count -eq $csv.Count) -and
                       ($allModsHaveCurrentRequired.Count -eq $csv.Count) -and
                       ($allModsHaveCurrentOptional.Count -eq $csv.Count)
    
    $result2 = $allColumnsExist -and $allFieldsPresent
    Write-TestResult "Dependency columns exist and are properly initialized" $result2

    Write-TestHeader "Step 3: Run update again to check for false update counts"
    $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath -UpdateMods -DatabaseFile $TestCsvPath -UseCachedResponses 2>&1
    # Check for either the old message or that no updates were counted
    $noFalseUpdate = ($output -match "All mods already have latest version information").Count -gt 0 -or 
                     ($output -match "Updated: 0 mods").Count -gt 0 -or
                     ($output -match "0 mods updated").Count -gt 0
    Write-TestResult "No false update counts on second run" $noFalseUpdate

    Show-TestSummary "Dependency Field Split Test"
    return ($script:TestResults.Failed -eq 0)
}

Invoke-DependencyFieldSplitTest -TestFileName $TestFileName 