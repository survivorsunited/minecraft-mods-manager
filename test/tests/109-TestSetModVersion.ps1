# Set-ModVersion command tests
# Tests explicit version updates, backup/hash generation, CurrentOnly and WhatIf.

. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = "109-TestSetModVersion.ps1"

Write-Host "Minecraft Mod Manager - Set Mod Version Tests" -ForegroundColor $Colors.Header
Write-Host "=================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName

$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestDbPath = Join-Path $TestOutputDir "set-version-test.csv"
$SetVersionPath = Join-Path $PSScriptRoot "..\..\Set-ModVersion.ps1"
$ApiResponsePath = Join-Path $TestOutputDir "apiresponse"
New-Item -ItemType Directory -Path $ApiResponsePath -Force | Out-Null

$initialRow = [pscustomobject][ordered]@{
    Group = "required"
    Type = "mod"
    CurrentGameVersion = "1.21.11"
    ID = "servux"
    Loader = "fabric"
    CurrentVersion = "0.9.4"
    Name = "Servux"
    Description = ""
    Category = "Multiplayer & Server"
    Jar = "servux-fabric-1.21.11-0.9.4.jar"
    NextVersion = ""
    NextVersionUrl = ""
    NextGameVersion = "26.1.2"
    LatestVersion = "0.9.4"
    LatestVersionUrl = "https://example.invalid/servux-0.9.4.jar"
    LatestGameVersion = "1.21.11"
    Url = "https://modrinth.com/mod/servux"
    CurrentVersionUrl = "https://example.invalid/servux-0.9.4.jar"
    UrlDirect = ""
    CurrentDependencies = ""
    CurrentDependenciesRequired = ""
    CurrentDependenciesOptional = ""
    LatestDependencies = ""
    LatestDependenciesRequired = ""
    LatestDependenciesOptional = ""
    Host = "modrinth"
    ApiSource = "modrinth"
    ClientSide = "unsupported"
    ServerSide = "required"
    Title = "Servux"
    ProjectDescription = ""
    IconUrl = ""
    IssuesUrl = ""
    SourceUrl = ""
    WikiUrl = ""
    AvailableGameVersions = "1.21.11"
    RecordHash = ""
}

@($initialRow) | Export-Csv -LiteralPath $TestDbPath -NoTypeInformation

Write-TestHeader "Command Exists"
Write-TestResult "Set-ModVersion.ps1 exists" (Test-Path -LiteralPath $SetVersionPath)

Write-TestHeader "Set Current and Latest Version"
$output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $SetVersionPath `
    -ModID "servux" `
    -Version "0.9.5" `
    -DatabaseFile $TestDbPath `
    -ApiResponseFolder $ApiResponsePath `
    -SkipValidation 2>&1
$exitCode = $LASTEXITCODE
$row = Import-Csv -LiteralPath $TestDbPath | Select-Object -First 1

Write-TestResult "Set version command succeeds" ($exitCode -eq 0) ($output -join "`n")
Write-TestResult "CurrentVersion updated" ($row.CurrentVersion -eq "0.9.5") "CurrentVersion=$($row.CurrentVersion)"
Write-TestResult "LatestVersion updated by default" ($row.LatestVersion -eq "0.9.5") "LatestVersion=$($row.LatestVersion)"
Write-TestResult "RecordHash generated" (-not [string]::IsNullOrWhiteSpace($row.RecordHash))

$backups = @(Get-ChildItem -Path "$TestDbPath.set-version.*.bak" -ErrorAction SilentlyContinue)
Write-TestResult "Database backup generated" ($backups.Count -ge 1) "Backups=$($backups.Count)"

Write-TestHeader "CurrentOnly Leaves Latest Version"
$output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $SetVersionPath `
    -ModID "servux" `
    -Version "0.9.6" `
    -DatabaseFile $TestDbPath `
    -ApiResponseFolder $ApiResponsePath `
    -SkipValidation `
    -CurrentOnly 2>&1
$exitCode = $LASTEXITCODE
$row = Import-Csv -LiteralPath $TestDbPath | Select-Object -First 1

Write-TestResult "CurrentOnly command succeeds" ($exitCode -eq 0) ($output -join "`n")
Write-TestResult "CurrentOnly updates CurrentVersion" ($row.CurrentVersion -eq "0.9.6") "CurrentVersion=$($row.CurrentVersion)"
Write-TestResult "CurrentOnly preserves LatestVersion" ($row.LatestVersion -eq "0.9.5") "LatestVersion=$($row.LatestVersion)"

Write-TestHeader "WhatIf Does Not Modify Database"
$beforeWhatIf = Get-Content -LiteralPath $TestDbPath -Raw
$output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $SetVersionPath `
    -ModID "servux" `
    -Version "0.9.7" `
    -DatabaseFile $TestDbPath `
    -ApiResponseFolder $ApiResponsePath `
    -SkipValidation `
    -WhatIf 2>&1
$exitCode = $LASTEXITCODE
$afterWhatIf = Get-Content -LiteralPath $TestDbPath -Raw

Write-TestResult "WhatIf command succeeds" ($exitCode -eq 0) ($output -join "`n")
Write-TestResult "WhatIf preserves database" ($beforeWhatIf -eq $afterWhatIf)

Write-TestHeader "Missing Mod Fails Safely"
$beforeMissing = Get-Content -LiteralPath $TestDbPath -Raw
$output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $SetVersionPath `
    -ModID "missing-mod" `
    -Version "1.0.0" `
    -DatabaseFile $TestDbPath `
    -ApiResponseFolder $ApiResponsePath `
    -SkipValidation 2>&1
$exitCode = $LASTEXITCODE
$afterMissing = Get-Content -LiteralPath $TestDbPath -Raw

Write-TestResult "Missing mod returns failure" ($exitCode -eq 1) ($output -join "`n")
Write-TestResult "Missing mod preserves database" ($beforeMissing -eq $afterMissing)

Write-Host "`nSet Mod Version Tests Complete" -ForegroundColor $Colors.Info
Show-TestSummary
