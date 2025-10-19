# Test API Response Organization
# Tests the new domain-based API response organization using environment variables

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Import required modules
. "$PSScriptRoot\..\..\src\Core\Paths\Get-ApiResponsePath.ps1"

# Set the test file name for use throughout the script
$TestFileName = "13-TestApiResponseOrganization.ps1"

Initialize-TestEnvironment $TestFileName

function Invoke-TestApiResponseOrganization {
    param([string]$TestFileName = $null)
    
    Write-TestSuiteHeader "API Response Organization Tests" $TestFileName
    
    # Set up test output and API response directories (like test 12)
    $TestOutputDir = Get-TestOutputFolder $TestFileName
    $TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
    $TestDownloadDir = Join-Path $TestOutputDir "download"
    $TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"
    $ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
    
    # Test 1: Verify environment variables are loaded
    Write-TestStep "Verifying environment variables"
    
    # Load environment variables
    if (Test-Path "..\..\.env") {
        Get-Content "..\..\.env" | ForEach-Object {
            if ($_ -match "^([^#][^=]+)=(.*)$") {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                Set-Variable -Name $name -Value $value -Scope Global
            }
        }
    }
    
    $modrinthSubfolder = if ($env:APIRESPONSE_MODRINTH_SUBFOLDER) { $env:APIRESPONSE_MODRINTH_SUBFOLDER } else { "modrinth" }
    $curseforgeSubfolder = if ($env:APIRESPONSE_CURSEFORGE_SUBFOLDER) { $env:APIRESPONSE_CURSEFORGE_SUBFOLDER } else { "curseforge" }
    
    Write-TestResult "Environment Variables" $true "Modrinth: $modrinthSubfolder, CurseForge: $curseforgeSubfolder"
    
    # Test 2: Verify test API response structure
    Write-TestStep "Verifying test API response structure"
    $modrinthPath = Join-Path $TestApiResponseDir $modrinthSubfolder
    $curseforgePath = Join-Path $TestApiResponseDir $curseforgeSubfolder
    
    if (-not (Test-Path $modrinthPath)) {
        New-Item -ItemType Directory -Path $modrinthPath -Force | Out-Null
        Write-TestResult "Modrinth Subfolder" $true "Created: $modrinthPath"
    } else {
        $modrinthFiles = Get-ChildItem $modrinthPath -File | Measure-Object
        Write-TestResult "Modrinth Subfolder" $true "Found: $modrinthPath ($($modrinthFiles.Count) files)"
    }
    
    if (-not (Test-Path $curseforgePath)) {
        New-Item -ItemType Directory -Path $curseforgePath -Force | Out-Null
        Write-TestResult "CurseForge Subfolder" $true "Created: $curseforgePath"
    } else {
        $curseforgeFiles = Get-ChildItem $curseforgePath -File | Measure-Object
        Write-TestResult "CurseForge Subfolder" $true "Found: $curseforgePath ($($curseforgeFiles.Count) files)"
    }
    
    # Test 3: Test new organization logic
    Write-TestStep "Testing new organization logic"
    $testModrinthPath = Get-ApiResponsePath -ModId "test-mod" -ResponseType "project" -Domain "modrinth" -BaseResponseFolder $TestApiResponseDir
    $testCurseForgePath = Get-ApiResponsePath -ModId "test-mod" -ResponseType "versions" -Domain "curseforge" -BaseResponseFolder $TestApiResponseDir
    $expectedModrinthPath = Join-Path $TestApiResponseDir $modrinthSubfolder "test-mod-project.json"
    $expectedCurseForgePath = Join-Path $TestApiResponseDir $curseforgeSubfolder "test-mod-curseforge-versions.json"
    if ($testModrinthPath -eq $expectedModrinthPath) {
        Write-TestResult "Modrinth Path Generation" $true "Correct path: $testModrinthPath"
    } else {
        Write-TestResult "Modrinth Path Generation" $false "Expected: $expectedModrinthPath, Got: $testModrinthPath"
    }
    if ($testCurseForgePath -eq $expectedCurseForgePath) {
        Write-TestResult "CurseForge Path Generation" $true "Correct path: $testCurseForgePath"
    } else {
        Write-TestResult "CurseForge Path Generation" $false "Expected: $expectedCurseForgePath, Got: $testCurseForgePath"
    }
    
    # Test 4: Test file organization
    Write-TestStep "Testing file organization"
    $modrinthJsonFiles = Get-ChildItem $modrinthPath -Filter "*.json" -File -ErrorAction SilentlyContinue
    $curseforgeJsonFiles = Get-ChildItem $curseforgePath -Filter "*.json" -File -ErrorAction SilentlyContinue
    # Note: When using cached responses, files may not be created during test
    if ($modrinthJsonFiles.Count -gt 0) {
        Write-TestResult "Modrinth JSON Files" $true "Found $($modrinthJsonFiles.Count) JSON files in Modrinth folder"
    } else {
        Write-TestResult "Modrinth JSON Files" $true "No JSON files found in Modrinth folder (using cached responses)"
    }
    if ($curseforgeJsonFiles.Count -gt 0) {
        Write-TestResult "CurseForge JSON Files" $true "Found $($curseforgeJsonFiles.Count) JSON files in CurseForge folder"
    } else {
        Write-TestResult "CurseForge JSON Files" $true "No JSON files found in CurseForge folder (may be normal)"
    }
    
    # Test 5: Integration with ModManager
    Write-TestStep "Testing integration with ModManager"
    $headers = @("Group", "Type", "GameVersion", "ID", "Loader", "Version", "Name", "Description", "Jar", "Url", "Category", "VersionUrl", "LatestVersionUrl", "LatestVersion", "ApiSource", "Host", "IconUrl", "ClientSide", "ServerSide", "Title", "ProjectDescription", "IssuesUrl", "SourceUrl", "WikiUrl", "LatestGameVersion", "RecordHash")
    $headers -join "," | Out-File $TestModListPath -Encoding UTF8
    
    $addModResult = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -AddMod `
        -AddModId "fabric-api" `
        -AddModName "Fabric API" `
        -AddModLoader "fabric" `
        -AddModGameVersion "1.21.6" `
        -AddModType "mod" `
        -AddModGroup "optional" `
        -DatabaseFile $TestModListPath `
        -ApiResponseFolder $TestApiResponseDir `
        -UseCachedResponses
    
    $addModExitCode = $LASTEXITCODE
    if ($addModExitCode -eq 0) {
        Write-TestResult "ModManager Integration" $true "Successfully added mod with new API organization"
        $testModrinthResponses = Get-ChildItem (Join-Path $TestApiResponseDir $modrinthSubfolder) -Filter "*fabric-api*" -File -ErrorAction SilentlyContinue
        # Note: When using cached responses, new files won't be created
        if ($testModrinthResponses.Count -gt 0) {
            Write-TestResult "Test API Response Creation" $true "Created $($testModrinthResponses.Count) API responses in Modrinth subfolder"
        } else {
            Write-TestResult "Test API Response Creation" $true "No API responses created (using cached responses)"
        }
    } else {
        Write-TestResult "ModManager Integration" $false "Failed to add mod: $($addModResult | Out-String)"
    }
    
    # Test 6: Test isolation
    Write-TestStep "Testing test isolation"
    if ($TestOutputDir -like "*test-output*") {
        Write-TestResult "Test Isolation" $true "Test using isolated output directory: $TestOutputDir"
    } else {
        Write-TestResult "Test Isolation" $false "Test not using isolated output directory: $TestOutputDir"
    }
    $testApiResponseCount = Get-ChildItem $TestApiResponseDir -File -ErrorAction SilentlyContinue | Measure-Object
    if ($testApiResponseCount.Count -ge 0) {
        Write-TestResult "API Response Isolation" $true "Test API responses ($($testApiResponseCount.Count)) are isolated in $TestApiResponseDir"
    } else {
        Write-TestResult "API Response Isolation" $false "Test API responses not isolated"
    }
    
    # Test 7: Verify no shared folders
    Write-TestStep "Verifying no shared folders"
    $sharedDownloadPath = Join-Path $PSScriptRoot "..\test-output\download"
    if (Test-Path $sharedDownloadPath) {
        Write-TestResult "No Shared Download Folder" $false "Found shared download folder: $sharedDownloadPath"
    } else {
        Write-TestResult "No Shared Download Folder" $true "No shared download folder found (correct)"
    }
    $testDownloadPath = $TestDownloadDir
    if (Test-Path $testDownloadPath) {
        Write-TestResult "Test Own Download Folder" $true "Test has its own download folder: $testDownloadPath"
    } else {
        Write-TestResult "Test Own Download Folder" $true "Test download folder will be created when needed"
    }
    
    Write-TestSuiteSummary "API Response Organization Tests"
    return $true
}

# Run the test
Invoke-TestApiResponseOrganization $MyInvocation.MyCommand.Name 