# 101-TestExpectedListAndAdminGroup.ps1
# Validates expected file list generation, especially that 'admin' group is treated as optional.

. "$PSScriptRoot\..\TestFramework.ps1"
. "$PSScriptRoot\..\..\src\Release\Get-ExpectedReleaseFiles.ps1"

$TestFileName = "101-TestExpectedListAndAdminGroup.ps1"
Initialize-TestEnvironment $TestFileName
$testOutDir = Get-TestOutputFolder $TestFileName

Write-TestHeader "Expected Files: Admin treated as Optional"

$csv = Join-Path $testOutDir 'expected-admin.csv'
$version = '1.21.8'

$rows = @(
    [pscustomobject]@{ Group='required'; Type='mod'; CurrentGameVersion=$version; ID='fabric-api'; Name='Fabric API'; Jar='fabric-api-1.jar'; ClientSide='required' },
    [pscustomobject]@{ Group='optional'; Type='mod'; CurrentGameVersion=$version; ID='sodium'; Name='Sodium'; Jar='sodium-1.jar'; ClientSide='required' },
    [pscustomobject]@{ Group='admin'; Type='mod'; CurrentGameVersion=$version; ID='reeses'; Name="Reese's Sodium Options"; Jar='reeses-1.jar'; ClientSide='required' },
    [pscustomobject]@{ Group='required'; Type='mod'; CurrentGameVersion=$version; ID='ledger'; Name='Ledger'; Jar='ledger-1.jar'; ClientSide='unsupported' },
    [pscustomobject]@{ Group='required'; Type='server'; CurrentGameVersion=$version; ID='minecraft-server'; Name='Minecraft Server'; Jar='minecraft_server.1.21.8.jar' }
)
$rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8

$expected = Get-ExpectedReleaseFiles -Version $version -CsvPath $csv

# Assertions
$hasFabric = ($expected -contains 'mods/fabric-api-1.jar')
$hasSodiumOpt = ($expected -contains 'mods/optional/sodium-1.jar')
$hasReesesOpt = ($expected -contains 'mods/optional/reeses-1.jar')
$hasLedgerServer = ($expected -contains 'mods/server/ledger-1.jar')
$hasServerJarUnderMods = ($expected -contains 'mods/minecraft_server.1.21.8.jar')
$hasServerJarUnderServer = ($expected -contains 'mods/server/minecraft_server.1.21.8.jar')

Write-TestResult "Required mod under mods/" $hasFabric
Write-TestResult "Optional mod under mods/optional/" $hasSodiumOpt
Write-TestResult "Admin treated as optional (mods/optional/)" $hasReesesOpt
Write-TestResult "Server-only mod under mods/server/" $hasLedgerServer
Write-TestResult "Server binary NOT under mods/ root" (-not $hasServerJarUnderMods)
Write-TestResult "Server binary under mods/server/" $hasServerJarUnderServer

Show-TestSummary "Expected Files"
return ($script:TestResults.Failed -eq 0)
