# 103-TestVersionMatrixCounts.ps1
# Validates the Version Compatibility Matrix logic by creating versioned jar names in download folders

. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = "103-TestVersionMatrixCounts.ps1"
Initialize-TestEnvironment $TestFileName
$testOutDir = Get-TestOutputFolder $TestFileName

Write-TestHeader "Version Compatibility Matrix Counts"

# Prepare download structure with version-tagged jars
$folders = @(
    @{ ver = '1.21.8'; files = @('alpha-1.21.8.jar','beta-1.21.9.jar') },
    @{ ver = '1.21.9'; files = @('gamma-1.21.9.jar','delta-foo.jar','epsilon-1.21.10.jar') },
    @{ ver = '1.21.10'; files = @('zeta-1.21.10.jar') }
)

foreach ($f in $folders) {
    $modsDir = Join-Path $testOutDir (Join-Path 'download' (Join-Path $f.ver 'mods'))
    New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
    foreach ($name in $f.files) {
        Set-Content -Path (Join-Path $modsDir $name) -Value 'dummy' -Encoding UTF8
    }
}

# Function to compute counts similar to Show-VersionMatrix logic
function Get-MatrixCounts {
    param([string]$BaseDir)
    $versions = @('1.21.8','1.21.9','1.21.10','1.21.11')
    $result = @{}
    foreach ($folder in @('1.21.8','1.21.9','1.21.10')) {
        $path = Join-Path $BaseDir (Join-Path 'download' (Join-Path $folder 'mods'))
        $counts = @{
            '1.21.8' = 0; '1.21.9' = 0; '1.21.10' = 0; '1.21.11' = 0; 'unknown' = 0
        }
        if (Test-Path $path) {
            $mods = Get-ChildItem -Path $path -Filter '*.jar' -Recurse -ErrorAction SilentlyContinue
            foreach ($m in $mods) {
                $name = $m.Name
                $matched = $false
                foreach ($v in $versions) {
                    if ($name -match $v.Replace('.','\.')) { $counts[$v]++; $matched = $true; break }
                }
                if (-not $matched) { $counts['unknown']++ }
            }
        }
        $result[$folder] = $counts
    }
    return $result
}

$matrix = Get-MatrixCounts -BaseDir $testOutDir

# Expected counts
$exp_128 = @{ '1.21.8' = 1; '1.21.9' = 1; '1.21.10' = 0; '1.21.11' = 0; 'unknown' = 0 }
$exp_129 = @{ '1.21.8' = 0; '1.21.9' = 1; '1.21.10' = 1; '1.21.11' = 0; 'unknown' = 1 }
$exp_1210 = @{ '1.21.8' = 0; '1.21.9' = 0; '1.21.10' = 1; '1.21.11' = 0; 'unknown' = 0 }

function Assert-Counts($label, $actual, $expected) {
    foreach ($k in $expected.Keys) {
        $ok = ($actual[$k] -eq $expected[$k])
        $actualValue = if ($actual.ContainsKey($k)) { $actual[$k] } else { 0 }
        Write-TestResult "$label: $k = $($expected[$k])" $ok "Actual: $actualValue"
    }
}

Assert-Counts '1.21.8 folder' $matrix['1.21.8'] $exp_128
Assert-Counts '1.21.9 folder' $matrix['1.21.9'] $exp_129
Assert-Counts '1.21.10 folder' $matrix['1.21.10'] $exp_1210

# Also invoke Show-TestSummary to render the matrix for human verification
Show-TestSummary "Version Matrix"

return ($script:TestResults.Failed -eq 0)
