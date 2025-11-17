# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = "105-TestRecordHashValidation.ps1"
Initialize-TestEnvironment $TestFileName

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ModListPath = Join-Path $ProjectRoot "modlist.csv"

Write-TestHeader "Validate all CSV rows have RecordHash"

$mods = Import-Csv $ModListPath
$missingHash = @()
$invalidHash = @()

foreach ($mod in $mods) {
    if (-not $mod.RecordHash -or $mod.RecordHash.Trim() -eq "") {
        $missingHash += $mod
    } else {
        # Verify hash is valid (64 char hex)
        if ($mod.RecordHash.Length -ne 64 -or $mod.RecordHash -notmatch '^[0-9a-f]{64}$') {
            $invalidHash += $mod
        }
    }
}

$allHaveHash = $missingHash.Count -eq 0
$allValidHash = $invalidHash.Count -eq 0

Write-TestResult "All rows have RecordHash" $allHaveHash
if (-not $allHaveHash) {
    Write-Host "  Missing RecordHash: $($missingHash.Count) rows" -ForegroundColor Red
    $missingHash | Select-Object -First 5 Name, ID | Format-Table
}

Write-TestResult "All RecordHash values are valid (64-char hex)" $allValidHash
if (-not $allValidHash) {
    Write-Host "  Invalid RecordHash: $($invalidHash.Count) rows" -ForegroundColor Red
    $invalidHash | Select-Object -First 5 Name, ID, RecordHash | Format-Table
}

Show-TestSummary

