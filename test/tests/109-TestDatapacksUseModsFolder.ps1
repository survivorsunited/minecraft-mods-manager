# Datapack Mods Folder Tests
# Verifies SurvivorsUnited datapack rows are packaged with mods.

. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = "109-TestDatapacksUseModsFolder.ps1"
Write-Host "Minecraft Mod Manager - Datapacks Use Mods Folder Tests" -ForegroundColor $Colors.Header
Write-Host "========================================================" -ForegroundColor $Colors.Header

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..") | Select-Object -ExpandProperty Path
$TestOutputDir = Get-TestOutputFolder $TestFileName
$CsvPath = Join-Path $TestOutputDir "datapack-mods-folder.csv"

. (Join-Path $RepoRoot "src\Release\Get-ExpectedReleaseFiles.ps1")
. (Join-Path $RepoRoot "src\Patches\Force-DatapacksIntoModsFolder.ps1")

$rows = @(
    [pscustomobject]@{
        Group = "required"
        Type = "datapack"
        CurrentGameVersion = "1.21.11"
        ID = "test-datapack"
        Loader = "fabric"
        CurrentVersion = "1.0.0"
        Name = "Test Datapack"
        Description = ""
        Jar = "test-datapack-1.0.0-1.21.11.jar"
        Url = ""
        Category = "Utility"
        CurrentVersionUrl = "https://example.com/test-datapack-1.0.0-1.21.11.jar"
        NextVersion = ""
        NextVersionUrl = ""
        NextGameVersion = ""
        LatestVersionUrl = ""
        LatestVersion = ""
        ApiSource = "github"
        Host = "github"
        IconUrl = ""
        ClientSide = "optional"
        ServerSide = "optional"
        Title = "Test Datapack"
        ProjectDescription = ""
        IssuesUrl = ""
        SourceUrl = ""
        WikiUrl = ""
        LatestGameVersion = ""
        RecordHash = ""
    },
    [pscustomobject]@{
        Group = "optional"
        Type = "datapack"
        CurrentGameVersion = "1.21.11"
        ID = "test-optional-datapack"
        Loader = "fabric"
        CurrentVersion = "1.0.0"
        Name = "Test Optional Datapack"
        Description = ""
        Jar = "test-optional-datapack-1.0.0-1.21.11.zip"
        Url = ""
        Category = "Utility"
        CurrentVersionUrl = "https://example.com/test-optional-datapack-1.0.0-1.21.11.zip"
        NextVersion = ""
        NextVersionUrl = ""
        NextGameVersion = ""
        LatestVersionUrl = ""
        LatestVersion = ""
        ApiSource = "github"
        Host = "github"
        IconUrl = ""
        ClientSide = "optional"
        ServerSide = "optional"
        Title = "Test Optional Datapack"
        ProjectDescription = ""
        IssuesUrl = ""
        SourceUrl = ""
        WikiUrl = ""
        LatestGameVersion = ""
        RecordHash = ""
    }
)

$rows | Export-Csv -Path $CsvPath -NoTypeInformation

Write-TestHeader "Expected release paths"
$expected = @(Get-ExpectedReleaseFiles -Version "1.21.11" -CsvPath $CsvPath)
Write-TestResult "Required datapack expected in mods" ($expected -contains "mods/test-datapack-1.0.0-1.21.11.jar") ($expected -join ", ")
Write-TestResult "Optional datapack expected in mods optional" ($expected -contains "mods/optional/test-optional-datapack-1.0.0-1.21.11.zip") ($expected -join ", ")
Write-TestResult "No datapacks folder expected" (-not ($expected | Where-Object { $_ -like "datapacks/*" })) ($expected -join ", ")

Write-TestHeader "Download CSV conversion"
$tempCsv = New-DatapacksAsModsCsvForDownload -CsvPath $CsvPath
try {
    $tempRows = @(Import-Csv -Path $tempCsv)
    $converted = $tempRows | Where-Object { $_.ID -in @("test-datapack", "test-optional-datapack") }
    Write-TestResult "Datapack rows become mod rows for downloader" (($converted | Where-Object { $_.Type -ne "mod" }).Count -eq 0) (($converted | ForEach-Object { "$($_.ID)=$($_.Type)" }) -join ", ")
} finally {
    if ($tempCsv -and (Test-Path $tempCsv)) { Remove-Item -Path $tempCsv -Force -ErrorAction SilentlyContinue }
}

Write-Host "`nDatapacks Use Mods Folder Tests Complete" -ForegroundColor $Colors.Info
