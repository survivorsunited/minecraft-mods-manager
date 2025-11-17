# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = "104-AddInstallerUrls.ps1"
Initialize-TestEnvironment $TestFileName

# Paths
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ModManagerPath = Join-Path $ProjectRoot "ModManager.ps1"

# Isolated CSV for this test - start with clean DB (header only)
$TestOutputDir = Get-TestOutputFolder $TestFileName
$IsolatedCsv = Join-Path $TestOutputDir "modlist.test.csv"

# Create clean CSV by copying just the header row from main database
$sourceCsv = Join-Path $ProjectRoot "modlist.csv"
if (Test-Path $sourceCsv) {
    Get-Content $sourceCsv -First 1 | Out-File -FilePath $IsolatedCsv -Encoding UTF8 -Force
    Write-Host "Created clean test database (header only)" -ForegroundColor Gray
} else {
    Write-Host "Warning: Source modlist.csv not found, test may fail" -ForegroundColor Yellow
}

Write-TestHeader "Add Fabric Installer EXE via URL only (auto-detect everything)"
$exeUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.0/fabric-installer-1.1.0.exe"
# ONLY pass URL - let system detect type, category, version, game version, etc.
& pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
  -AddModUrl $exeUrl `
  -DatabaseFile $IsolatedCsv | Out-Null

Write-TestHeader "Add Fabric Installer JAR via URL only (auto-detect everything)"
$jarUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.0/fabric-installer-1.1.0.jar"
# ONLY pass URL - let system detect type, category, version, game version, etc.
& pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
  -AddModUrl $jarUrl `
  -DatabaseFile $IsolatedCsv | Out-Null

# Validate results from isolated CSV
$rows = Import-Csv $IsolatedCsv
$exeRow = $rows | Where-Object { $_.Url -eq $exeUrl }
$jarRow = $rows | Where-Object { $_.Url -eq $jarUrl }

$exeAdded = $null -ne $exeRow
$jarAdded = $null -ne $jarRow
Write-TestResult "EXE entry added to isolated DB" $exeAdded
Write-TestResult "JAR entry added to isolated DB" $jarAdded

# Ensure both have non-empty RecordHash
$exeHashOk = $exeAdded -and $exeRow.RecordHash -and $exeRow.RecordHash.Trim() -ne ""
$jarHashOk = $jarAdded -and $jarRow.RecordHash -and $jarRow.RecordHash.Trim() -ne ""
Write-TestResult "EXE entry has RecordHash" $exeHashOk
Write-TestResult "JAR entry has RecordHash" $jarHashOk

# Validate Fabric installer-specific fields for EXE
if ($exeAdded) {
    Write-TestHeader "Validate EXE entry fields"
    $versionOk = $exeRow.CurrentVersion -eq "1.1.0"
    $categoryOk = $exeRow.Category -eq "Infrastructure"
    $hostOk = $exeRow.Host -eq "direct"
    $apiSourceOk = $exeRow.ApiSource -eq "direct"
    $clientSideOk = [string]::IsNullOrEmpty($exeRow.ClientSide)
    $serverSideOk = [string]::IsNullOrEmpty($exeRow.ServerSide)
    
    Write-TestResult "EXE CurrentVersion extracted from URL (1.1.0)" $versionOk
    Write-TestResult "EXE Category = Infrastructure" $categoryOk
    Write-TestResult "EXE Host = direct" $hostOk
    Write-TestResult "EXE ApiSource = direct" $apiSourceOk
    Write-TestResult "EXE ClientSide is empty" $clientSideOk
    Write-TestResult "EXE ServerSide is empty" $serverSideOk
}

# Validate Fabric installer-specific fields for JAR
if ($jarAdded) {
    Write-TestHeader "Validate JAR entry fields"
    $versionOk = $jarRow.CurrentVersion -eq "1.1.0"
    $categoryOk = $jarRow.Category -eq "Infrastructure"
    $hostOk = $jarRow.Host -eq "direct"
    $apiSourceOk = $jarRow.ApiSource -eq "direct"
    $clientSideOk = [string]::IsNullOrEmpty($jarRow.ClientSide)
    $serverSideOk = [string]::IsNullOrEmpty($jarRow.ServerSide)
    
    Write-TestResult "JAR CurrentVersion extracted from URL (1.1.0)" $versionOk
    Write-TestResult "JAR Category = Infrastructure" $categoryOk
    Write-TestResult "JAR Host = direct" $hostOk
    Write-TestResult "JAR ApiSource = direct" $apiSourceOk
    Write-TestResult "JAR ClientSide is empty" $clientSideOk
    Write-TestResult "JAR ServerSide is empty" $serverSideOk
}

Show-TestSummary


