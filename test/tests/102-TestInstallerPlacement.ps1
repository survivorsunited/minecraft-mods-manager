# 102-TestInstallerPlacement.ps1
# Ensures 'installer' type artifacts are classified as server-only and placed under mods/server

. "$PSScriptRoot\..\TestFramework.ps1"
. "$PSScriptRoot\..\..\src\Release\Copy-ModsToRelease.ps1"
. "$PSScriptRoot\..\..\src\Release\Get-ExpectedReleaseFiles.ps1"

$TestFileName = "102-TestInstallerPlacement.ps1"
Initialize-TestEnvironment $TestFileName
$testOutDir = Get-TestOutputFolder $TestFileName

Write-TestHeader "Installer Placement"

$version = '1.21.8'
$csv = Join-Path $testOutDir 'installer-placement.csv'
$downloadModsDir = Join-Path $testOutDir 'download' $version 'mods'
$releaseModsDir = Join-Path $testOutDir 'release' 'mods'
New-Item -ItemType Directory -Path $downloadModsDir -Force | Out-Null

$rows = @(
    [pscustomobject]@{ Group='required'; Type='installer'; CurrentGameVersion=$version; ID='fabric-installer'; Name='Fabric Installer'; Jar='fabric-installer-1.jar'; ClientSide='unsupported'; ServerSide='required' },
    [pscustomobject]@{ Group='required'; Type='mod'; CurrentGameVersion=$version; ID='lithium'; Name='Lithium'; Jar='lithium-1.jar'; ClientSide='required'; ServerSide='required' }
)
$rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8

# Create dummy jars
Set-Content -Path (Join-Path $downloadModsDir 'fabric-installer-1.jar') -Value 'dummy' -Encoding UTF8
Set-Content -Path (Join-Path $downloadModsDir 'lithium-1.jar') -Value 'dummy' -Encoding UTF8

# Execute
$ok = Copy-ModsToRelease -SourcePath $downloadModsDir -DestinationPath $releaseModsDir -CsvPath $csv -TargetGameVersion $version
Write-TestResult "Copy-ModsToRelease executed" $ok

$serverDir = Join-Path $releaseModsDir 'server'
$rootJar = Join-Path $releaseModsDir 'fabric-installer-1.jar'
$optJar = Join-Path (Join-Path $releaseModsDir 'optional') 'fabric-installer-1.jar'
$serverJar = Join-Path $serverDir 'fabric-installer-1.jar'

Write-TestResult "Installer NOT in mods/ root" (-not (Test-Path $rootJar))
Write-TestResult "Installer NOT in mods/optional" (-not (Test-Path $optJar))
Write-TestResult "Installer in mods/server" (Test-Path $serverJar)

# Also ensure a normal mod goes to mods root
Write-TestResult "Normal mod in mods/" (Test-Path (Join-Path $releaseModsDir 'lithium-1.jar'))

Show-TestSummary "Installer Placement"
return ($script:TestResults.Failed -eq 0)
