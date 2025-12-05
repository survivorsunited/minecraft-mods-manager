. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = "99-TestMandatoryReadsCompliance.ps1"
Initialize-TestEnvironment $TestFileName

$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestDbPath = Join-Path $TestOutputDir "test-modlist.csv"

if (-not (Test-Path $TestDbPath)) {
    @'
Group,Type,GameVersion,ID,Loader,Version,Name,Jar,Url
required,mod,1.21.8,placeholder,fabric,latest,Placeholder Mod,placeholder.jar,https://example.invalid/mod
'@ | Set-Content -Path $TestDbPath -Encoding UTF8
}

function Invoke-TestMandatoryReadsCompliance {
    param([string]$TestFileName = $null)

    Write-TestSuiteHeader "Mandatory Read Instructions Compliance" $TestFileName
    $script:TestResults = @{
        Total = 0
        Passed = 0
        Failed = 0
    }

    Write-TestHeader "Validate mandatory read references"

    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $rulePath = Join-Path $projectRoot ".cursor\rules\gov-08-mandatory-reads.mdc"

    $script:TestResults.Total++
    if (-not (Test-Path $rulePath)) {
        Write-TestResult "Mandatory reads file exists" $false "Missing file at $rulePath"
        $script:TestResults.Failed++
    }
    else {
        Write-TestResult "Mandatory reads file exists" $true "Validated file at $rulePath"
        $script:TestResults.Passed++

        $ruleContent = Get-Content -Path $rulePath -Raw
        $hasDeprecatedRefs = $ruleContent -match "CLAUDE\.md" -or $ruleContent -match "TODO\.md"

        $script:TestResults.Total++
        if ($hasDeprecatedRefs) {
            Write-TestResult "Deprecated references removed" $false "Found references to CLAUDE.md or TODO.md in $rulePath"
            $script:TestResults.Failed++
        } else {
            Write-TestResult "Deprecated references removed" $true "No references to CLAUDE.md or TODO.md remain"
            $script:TestResults.Passed++
        }
    }

    Show-TestSummary
    return ($script:TestResults.Failed -eq 0)
}

Invoke-TestMandatoryReadsCompliance -TestFileName $TestFileName

