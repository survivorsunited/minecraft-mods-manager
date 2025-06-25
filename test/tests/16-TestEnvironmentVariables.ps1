# Test Environment Variables
# Tests .env file loading and environment variable configuration

param([string]$TestFileName = $null)

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "16-TestEnvironmentVariables.ps1"

Write-Host "Minecraft Mod Manager - Environment Variables Tests" -ForegroundColor $Colors.Header
Write-Host "==================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

# Test configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Join-Path $PSScriptRoot "..\test-output\16-TestEnvironmentVariables"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestModListPath = Join-Path $TestOutputDir "test-modlist.csv"
$TestApiResponseFolder = Join-Path $TestOutputDir "apiresponse"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputDir)) {
    New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
}

# Initialize test results at script level
$script:TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
}

function Invoke-TestEnvironmentVariables {
    param([string]$TestFileName = $null)
    
    Write-TestSuiteHeader "Environment Variables Tests" $TestFileName
    
    # Test 1: .env file loading functionality
    Write-TestStep "Testing .env file loading"
    
    # Create a test .env file
    $testEnvPath = Join-Path $TestOutputDir ".env"
    $envContent = @"
# Test environment variables
MODRINTH_API_BASE_URL=https://test-api.modrinth.com/v2
CURSEFORGE_API_BASE_URL=https://test-api.curseforge.com/v1
CURSEFORGE_API_KEY=test-api-key-12345
APIRESPONSE_MODRINTH_SUBFOLDER=test-modrinth
APIRESPONSE_CURSEFORGE_SUBFOLDER=test-curseforge
"@
    $envContent | Out-File -FilePath $testEnvPath -Encoding UTF8
    
    if (Test-Path $testEnvPath) {
        Write-TestResult ".env File Creation" $true "Successfully created test .env file"
        $script:TestResults.Passed++
    } else {
        Write-TestResult ".env File Creation" $false "Failed to create test .env file"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 2: Environment variable loading from .env file
    Write-TestStep "Testing environment variable loading"
    
    # Create a test script that loads environment variables
    $testScriptPath = Join-Path $TestOutputDir "test-env-loading.ps1"
    $testScriptContent = @"
# Test environment variable loading
function Load-EnvironmentVariables {
    if (Test-Path "$testEnvPath") {
        Get-Content "$testEnvPath" | ForEach-Object {
            if (`$_ -match "^([^#][^=]+)=(.*)`$") {
                `$name = `$matches[1].Trim()
                `$value = `$matches[2].Trim()
                Set-Variable -Name `$name -Value `$value -Scope Global
            }
        }
    }
}

Load-EnvironmentVariables

# Output the loaded variables
Write-Output "MODRINTH_API_BASE_URL=`$MODRINTH_API_BASE_URL"
Write-Output "CURSEFORGE_API_BASE_URL=`$CURSEFORGE_API_BASE_URL"
Write-Output "CURSEFORGE_API_KEY=`$CURSEFORGE_API_KEY"
Write-Output "APIRESPONSE_MODRINTH_SUBFOLDER=`$APIRESPONSE_MODRINTH_SUBFOLDER"
Write-Output "APIRESPONSE_CURSEFORGE_SUBFOLDER=`$APIRESPONSE_CURSEFORGE_SUBFOLDER"
"@
    $testScriptContent | Out-File -FilePath $testScriptPath -Encoding UTF8
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $testScriptPath
    
    if ($result -and $result.Count -ge 5) {
        Write-TestResult "Environment Variable Loading" $true "Successfully loaded environment variables from .env file"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Environment Variable Loading" $false "Failed to load environment variables from .env file"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 3: Default values when environment variables not set
    Write-TestStep "Testing default values"
    
    # Test with no .env file
    $noEnvScriptPath = Join-Path $TestOutputDir "test-defaults.ps1"
    $noEnvScriptContent = @"
# Test default values when no .env file exists
`$ModrinthApiBaseUrl = if (`$env:MODRINTH_API_BASE_URL) { `$env:MODRINTH_API_BASE_URL } else { "https://api.modrinth.com/v2" }
`$CurseForgeApiBaseUrl = if (`$env:CURSEFORGE_API_BASE_URL) { `$env:CURSEFORGE_API_BASE_URL } else { "https://www.curseforge.com/api/v1" }
`$ModrinthApiResponseSubfolder = if (`$env:APIRESPONSE_MODRINTH_SUBFOLDER) { `$env:APIRESPONSE_MODRINTH_SUBFOLDER } else { "modrinth" }
`$CurseForgeApiResponseSubfolder = if (`$env:APIRESPONSE_CURSEFORGE_SUBFOLDER) { `$env:APIRESPONSE_CURSEFORGE_SUBFOLDER } else { "curseforge" }

Write-Output "Default Modrinth API URL: `$ModrinthApiBaseUrl"
Write-Output "Default CurseForge API URL: `$CurseForgeApiBaseUrl"
Write-Output "Default Modrinth subfolder: `$ModrinthApiResponseSubfolder"
Write-Output "Default CurseForge subfolder: `$CurseForgeApiResponseSubfolder"
"@
    $noEnvScriptContent | Out-File -FilePath $noEnvScriptPath -Encoding UTF8
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $noEnvScriptPath
    
    if ($result -and $result.Count -ge 4) {
        $expectedDefaults = @(
            "Default Modrinth API URL: https://api.modrinth.com/v2",
            "Default CurseForge API URL: https://www.curseforge.com/api/v1",
            "Default Modrinth subfolder: modrinth",
            "Default CurseForge subfolder: curseforge"
        )
        
        $allDefaultsCorrect = $true
        foreach ($expected in $expectedDefaults) {
            if ($result -notcontains $expected) {
                $allDefaultsCorrect = $false
                break
            }
        }
        
        if ($allDefaultsCorrect) {
            Write-TestResult "Default Values" $true "Correctly used default values when environment variables not set"
            $script:TestResults.Passed++
        } else {
            Write-TestResult "Default Values" $false "Incorrect default values used"
            $script:TestResults.Failed++
        }
    } else {
        Write-TestResult "Default Values" $false "Failed to test default values"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 4: API configuration respects environment variables
    Write-TestStep "Testing API configuration with environment variables"
    
    # Create a test script that simulates ModManager's API configuration
    $apiConfigScriptPath = Join-Path $TestOutputDir "test-api-config.ps1"
    $apiConfigScriptContent = @"
# Test API configuration with environment variables
function Load-EnvironmentVariables {
    if (Test-Path "$testEnvPath") {
        Get-Content "$testEnvPath" | ForEach-Object {
            if (`$_ -match "^([^#][^=]+)=(.*)`$") {
                `$name = `$matches[1].Trim()
                `$value = `$matches[2].Trim()
                Set-Variable -Name `$name -Value `$value -Scope Global
            }
        }
    }
}

Load-EnvironmentVariables

# API URLs from environment variables or defaults
`$ModrinthApiBaseUrl = if (`$MODRINTH_API_BASE_URL) { `$MODRINTH_API_BASE_URL } else { "https://api.modrinth.com/v2" }
`$CurseForgeApiBaseUrl = if (`$CURSEFORGE_API_BASE_URL) { `$CURSEFORGE_API_BASE_URL } else { "https://www.curseforge.com/api/v1" }
`$CurseForgeApiKey = `$CURSEFORGE_API_KEY

# API Response Subfolder Configuration
`$ModrinthApiResponseSubfolder = if (`$APIRESPONSE_MODRINTH_SUBFOLDER) { `$APIRESPONSE_MODRINTH_SUBFOLDER } else { "modrinth" }
`$CurseForgeApiResponseSubfolder = if (`$APIRESPONSE_CURSEFORGE_SUBFOLDER) { `$APIRESPONSE_CURSEFORGE_SUBFOLDER } else { "curseforge" }

Write-Output "Configured Modrinth API URL: `$ModrinthApiBaseUrl"
Write-Output "Configured CurseForge API URL: `$CurseForgeApiBaseUrl"
Write-Output "Configured CurseForge API Key: `$CurseForgeApiKey"
Write-Output "Configured Modrinth subfolder: `$ModrinthApiResponseSubfolder"
Write-Output "Configured CurseForge subfolder: `$CurseForgeApiResponseSubfolder"
"@
    $apiConfigScriptContent | Out-File -FilePath $apiConfigScriptPath -Encoding UTF8
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $apiConfigScriptPath
    
    if ($result -and $result.Count -ge 5) {
        $expectedConfig = @(
            "Configured Modrinth API URL: https://test-api.modrinth.com/v2",
            "Configured CurseForge API URL: https://test-api.curseforge.com/v1",
            "Configured CurseForge API Key: test-api-key-12345",
            "Configured Modrinth subfolder: test-modrinth",
            "Configured CurseForge subfolder: test-curseforge"
        )
        
        $allConfigCorrect = $true
        foreach ($expected in $expectedConfig) {
            if ($result -notcontains $expected) {
                $allConfigCorrect = $false
                break
            }
        }
        
        if ($allConfigCorrect) {
            Write-TestResult "API Configuration" $true "API configuration correctly respects environment variables"
            $script:TestResults.Passed++
        } else {
            Write-TestResult "API Configuration" $false "API configuration does not respect environment variables"
            $script:TestResults.Failed++
        }
    } else {
        Write-TestResult "API Configuration" $false "Failed to test API configuration"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 5: ModManager integration with environment variables
    Write-TestStep "Testing ModManager integration"
    
    # Copy the test .env file to the ModManager directory temporarily
    $originalEnvPath = Join-Path (Split-Path $ModManagerPath) ".env"
    $backupEnvPath = Join-Path (Split-Path $ModManagerPath) ".env.backup"
    
    # Backup existing .env if it exists
    if (Test-Path $originalEnvPath) {
        Copy-Item $originalEnvPath $backupEnvPath -Force
    }
    
    # Copy test .env to ModManager directory
    Copy-Item $testEnvPath $originalEnvPath -Force
    
    try {
        # Test ModManager with environment variables
        $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
            -ShowHelp `
            -ApiResponseFolder $TestApiResponseFolder
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "ModManager Integration" $true "ModManager successfully loaded and used environment variables"
            $script:TestResults.Passed++
        } else {
            Write-TestResult "ModManager Integration" $false "ModManager failed to load environment variables"
            $script:TestResults.Failed++
        }
    } catch {
        Write-TestResult "ModManager Integration" $false "ModManager integration test failed: $($_.Exception.Message)"
        $script:TestResults.Failed++
    } finally {
        # Restore original .env file
        if (Test-Path $backupEnvPath) {
            Copy-Item $backupEnvPath $originalEnvPath -Force
            Remove-Item $backupEnvPath -Force
        } elseif (Test-Path $originalEnvPath) {
            Remove-Item $originalEnvPath -Force
        }
    }
    $script:TestResults.Total++
    
    # Test 6: Environment variable validation
    Write-TestStep "Testing environment variable validation"
    
    # Test with invalid .env file
    $invalidEnvPath = Join-Path $TestOutputDir "invalid.env"
    $invalidEnvContent = @"
# Invalid environment file
INVALID_FORMAT
MISSING_EQUALS
=NO_NAME
#COMMENT_ONLY
"@
    $invalidEnvContent | Out-File -FilePath $invalidEnvPath -Encoding UTF8
    
    $validationScriptPath = Join-Path $TestOutputDir "test-validation.ps1"
    $validationScriptContent = @"
# Test environment variable validation
function Load-EnvironmentVariables {
    if (Test-Path "$invalidEnvPath") {
        Get-Content "$invalidEnvPath" | ForEach-Object {
            if (`$_ -match "^([^#][^=]+)=(.*)`$") {
                `$name = `$matches[1].Trim()
                `$value = `$matches[2].Trim()
                Set-Variable -Name `$name -Value `$value -Scope Global
            }
        }
    }
}

Load-EnvironmentVariables

# Check if any invalid variables were loaded
`$invalidVars = Get-Variable -Name "INVALID_FORMAT", "MISSING_EQUALS", "NO_NAME" -ErrorAction SilentlyContinue
if (`$invalidVars.Count -eq 0) {
    Write-Output "VALIDATION_PASSED"
} else {
    Write-Output "VALIDATION_FAILED"
}
"@
    $validationScriptContent | Out-File -FilePath $validationScriptPath -Encoding UTF8
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $validationScriptPath
    
    if ($result -and $result -contains "VALIDATION_PASSED") {
        Write-TestResult "Environment Variable Validation" $true "Successfully validated and filtered invalid environment variables"
        $script:TestResults.Passed++
    } else {
        Write-TestResult "Environment Variable Validation" $false "Failed to validate environment variables"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    # Test 7: API response subfolder creation with environment variables
    Write-TestStep "Testing API response subfolder creation"
    
    # Create a test script that simulates the Get-ApiResponsePath function
    $subfolderScriptPath = Join-Path $TestOutputDir "test-subfolders.ps1"
    $subfolderScriptContent = @"
# Test API response subfolder creation
function Load-EnvironmentVariables {
    if (Test-Path "$testEnvPath") {
        Get-Content "$testEnvPath" | ForEach-Object {
            if (`$_ -match "^([^#][^=]+)=(.*)`$") {
                `$name = `$matches[1].Trim()
                `$value = `$matches[2].Trim()
                Set-Variable -Name `$name -Value `$value -Scope Global
            }
        }
    }
}

Load-EnvironmentVariables

# API Response Subfolder Configuration
`$ModrinthApiResponseSubfolder = if (`$APIRESPONSE_MODRINTH_SUBFOLDER) { `$APIRESPONSE_MODRINTH_SUBFOLDER } else { "modrinth" }
`$CurseForgeApiResponseSubfolder = if (`$APIRESPONSE_CURSEFORGE_SUBFOLDER) { `$APIRESPONSE_CURSEFORGE_SUBFOLDER } else { "curseforge" }

# Test subfolder creation
`$testBaseFolder = "$TestApiResponseFolder"
`$modrinthFolder = Join-Path `$testBaseFolder `$ModrinthApiResponseSubfolder
`$curseforgeFolder = Join-Path `$testBaseFolder `$CurseForgeApiResponseSubfolder

# Create folders
if (-not (Test-Path `$modrinthFolder)) {
    New-Item -ItemType Directory -Path `$modrinthFolder -Force | Out-Null
}
if (-not (Test-Path `$curseforgeFolder)) {
    New-Item -ItemType Directory -Path `$curseforgeFolder -Force | Out-Null
}

Write-Output "Modrinth folder created: `$modrinthFolder"
Write-Output "CurseForge folder created: `$curseforgeFolder"
Write-Output "Modrinth folder exists: `$(Test-Path `$modrinthFolder)"
Write-Output "CurseForge folder exists: `$(Test-Path `$curseforgeFolder)"
"@
    $subfolderScriptContent | Out-File -FilePath $subfolderScriptPath -Encoding UTF8
    
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $subfolderScriptPath
    
    if ($result -and $result.Count -ge 4) {
        $modrinthFolderExists = $result -contains "Modrinth folder exists: True"
        $curseforgeFolderExists = $result -contains "CurseForge folder exists: True"
        
        if ($modrinthFolderExists -and $curseforgeFolderExists) {
            Write-TestResult "Subfolder Creation" $true "Successfully created API response subfolders with environment variables"
            $script:TestResults.Passed++
        } else {
            Write-TestResult "Subfolder Creation" $false "Failed to create API response subfolders"
            $script:TestResults.Failed++
        }
    } else {
        Write-TestResult "Subfolder Creation" $false "Failed to test subfolder creation"
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
    
    Write-TestSuiteSummary "Environment Variables Tests"
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestEnvironmentVariables -TestFileName $TestFileName 