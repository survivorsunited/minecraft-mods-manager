# Current/Next/Latest Workflow Tests
# Tests the new Current/Next/Latest version progression workflow

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "81-TestCurrentNextLatestWorkflow.ps1"

Write-Host "Minecraft Mod Manager - Current/Next/Latest Workflow Tests" -ForegroundColor $Colors.Header
Write-Host "=========================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName -UseMigratedSchema

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestDbPath = Join-Path $TestOutputDir "workflow-test.csv"

# Create necessary directories
New-Item -ItemType Directory -Path $script:TestApiResponseDir -Force | Out-Null
New-Item -ItemType Directory -Path $TestDownloadDir -Force | Out-Null

# Add test data to the migrated schema database
$testData = @(
    [PSCustomObject]@{
        Group = "required"
        Type = "mod"
        CurrentGameVersion = "1.21.5"
        ID = "fabric-api"
        Loader = "fabric"
        CurrentVersion = "0.127.1+1.21.5"
        Name = "Fabric API"
        Description = "Essential API for Fabric mods"
        Jar = ""
        Url = "https://modrinth.com/mod/fabric-api"
        Category = "api"
        CurrentVersionUrl = "https://cdn.modrinth.com/data/P7dR8mSH/versions/current.jar"
        NextVersion = "0.127.1+1.21.6"
        NextVersionUrl = "https://cdn.modrinth.com/data/P7dR8mSH/versions/next.jar"
        NextGameVersion = "1.21.6"
        LatestVersionUrl = "https://cdn.modrinth.com/data/P7dR8mSH/versions/latest.jar"
        LatestVersion = "0.128.0+1.21.8"
        LatestGameVersion = "1.21.8"
        ApiSource = "modrinth"
        Host = "modrinth"
        IconUrl = ""
        ClientSide = ""
        ServerSide = ""
        Title = ""
        ProjectDescription = ""
        IssuesUrl = ""
        SourceUrl = ""
        WikiUrl = ""
        RecordHash = ""
        UrlDirect = ""
        AvailableGameVersions = "1.21.5,1.21.6,1.21.7,1.21.8"
        CurrentDependenciesRequired = ""
        CurrentDependenciesOptional = ""
        LatestDependenciesRequired = ""
        LatestDependenciesOptional = ""
    },
    [PSCustomObject]@{
        Group = "required"
        Type = "mod"
        CurrentGameVersion = "1.21.5"
        ID = "sodium"
        Loader = "fabric"
        CurrentVersion = "mc1.21.5-0.6.13-fabric"
        Name = "Sodium"
        Description = "Modern rendering engine"
        Jar = ""
        Url = "https://modrinth.com/mod/sodium"
        Category = "performance"
        CurrentVersionUrl = "https://cdn.modrinth.com/data/AANobbMI/versions/current.jar"
        NextVersion = "mc1.21.6-0.6.13-fabric"
        NextVersionUrl = "https://cdn.modrinth.com/data/AANobbMI/versions/next.jar"
        NextGameVersion = "1.21.6"
        LatestVersionUrl = "https://cdn.modrinth.com/data/AANobbMI/versions/latest.jar"
        LatestVersion = "mc1.21.8-0.6.14-fabric"
        LatestGameVersion = "1.21.8"
        ApiSource = "modrinth"
        Host = "modrinth"
        IconUrl = ""
        ClientSide = ""
        ServerSide = ""
        Title = ""
        ProjectDescription = ""
        IssuesUrl = ""
        SourceUrl = ""
        WikiUrl = ""
        RecordHash = ""
        UrlDirect = ""
        AvailableGameVersions = "1.21.5,1.21.6,1.21.7,1.21.8"
        CurrentDependenciesRequired = ""
        CurrentDependenciesOptional = ""
        LatestDependenciesRequired = ""
        LatestDependenciesOptional = ""
    }
)

$testData | Export-Csv -Path $TestDbPath -NoTypeInformation

# Debug: Check initial database content
Write-Host "DEBUG: Initial database structure after test data creation:" -ForegroundColor Yellow
$initialMods = Import-Csv -Path $TestDbPath
$initialColumns = ($initialMods | Get-Member -MemberType NoteProperty).Name
Write-Host "Columns: $($initialColumns -join ', ')" -ForegroundColor Gray

Write-TestHeader "Database Column Structure"
$mods = Import-Csv -Path $TestDbPath
$requiredColumns = @("CurrentGameVersion", "CurrentVersion", "CurrentVersionUrl", 
                    "NextVersion", "NextVersionUrl", "NextGameVersion",
                    "LatestVersion", "LatestVersionUrl", "LatestGameVersion")

$missingColumns = @()
foreach ($column in $requiredColumns) {
    if (-not ($mods[0].PSObject.Properties.Name -contains $column)) {
        $missingColumns += $column
    }
}

if ($missingColumns.Count -eq 0) {
    Write-TestResult "All Current/Next/Latest columns present" $true $TestFileName
} else {
    Write-TestResult "Missing columns: $($missingColumns -join ', ')" $false $TestFileName
}

Write-TestHeader "Help Documentation"
$helpOutput = & $ModManagerPath -ShowHelp -ApiResponseFolder $script:TestApiResponseDir 2>&1
# Check each line for UseNextVersion flag
$foundUseNextVersion = $false
foreach ($line in $helpOutput) {
    if ($line -and $line.ToString() -match "UseNextVersion") {
        $foundUseNextVersion = $true
        break
    }
}

if ($foundUseNextVersion) {
    Write-TestResult "UseNextVersion flag documented" $true $TestFileName
} else {
    Write-TestResult "UseNextVersion flag missing from help" $false $TestFileName
}

Write-TestHeader "Current Version Download (Default)"
Test-Command "& '$ModManagerPath' -DatabaseFile '$TestDbPath' -Download -ForceDownload -DownloadFolder '$TestDownloadDir' -ApiResponseFolder '$script:TestApiResponseDir'" "Current version download" 0 $null $TestFileName

Write-TestHeader "Next Version Download"
Test-Command "& '$ModManagerPath' -DatabaseFile '$TestDbPath' -Download -UseNextVersion -ForceDownload -DownloadFolder '$TestDownloadDir' -ApiResponseFolder '$script:TestApiResponseDir'" "Next version download" 0 $null $TestFileName

Write-TestHeader "Latest Version Download"
Test-Command "& '$ModManagerPath' -DatabaseFile '$TestDbPath' -Download -UseLatestVersion -ForceDownload -DownloadFolder '$TestDownloadDir' -ApiResponseFolder '$script:TestApiResponseDir'" "Latest version download" 0 $null $TestFileName

Write-TestHeader "Validation with Next Version Support"
Test-Command "& '$ModManagerPath' -DatabaseFile '$TestDbPath' -ValidateAllModVersions -ApiResponseFolder '$script:TestApiResponseDir'" "Validation includes Next version fields" 0 $null $TestFileName

# Check if validation results include Next version fields
$resultsFile = Join-Path $script:TestApiResponseDir "version-validation-results.csv"
if (Test-Path $resultsFile) {
    $results = Import-Csv -Path $resultsFile
    if ($results[0].PSObject.Properties.Name -contains "NextVersion") {
        Write-TestResult "Validation results include NextVersion field" $true $TestFileName
    } else {
        Write-TestResult "Validation results missing NextVersion field" $false $TestFileName
    }
} else {
    Write-TestResult "Validation results file not found" $false $TestFileName
}

Write-TestHeader "Data Integrity Check"
$mods = Import-Csv -Path $TestDbPath
$fabricMod = $mods | Where-Object { $_.ID -eq "fabric-api" } | Select-Object -First 1

$dataTests = @(
    @{ Property = "CurrentVersion"; Expected = "0.127.1+1.21.5"; Actual = $fabricMod.CurrentVersion }
    @{ Property = "NextVersion"; Expected = "0.127.1+1.21.6"; Actual = $fabricMod.NextVersion }
    @{ Property = "LatestVersion"; Expected = "0.128.0+1.21.8"; Actual = $fabricMod.LatestVersion }
    @{ Property = "CurrentGameVersion"; Expected = "1.21.5"; Actual = $fabricMod.CurrentGameVersion }
    @{ Property = "NextGameVersion"; Expected = "1.21.6"; Actual = $fabricMod.NextGameVersion }
    @{ Property = "LatestGameVersion"; Expected = "1.21.8"; Actual = $fabricMod.LatestGameVersion }
)

foreach ($test in $dataTests) {
    $result = ($test.Actual -eq $test.Expected)
    Write-TestResult "$($test.Property): Expected '$($test.Expected)', got '$($test.Actual)'" $result $TestFileName
}

# Final summary
Write-TestSummary $TestFileName