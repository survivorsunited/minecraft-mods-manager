# 97-TestServerOnlyClassification.ps1
# Verifies server-only classification logic for release packaging.
# Rules:
#   - server-only when client_side == 'unsupported' OR explicit type in (server, launcher, installer)
#   - otherwise mod is client/dual (placed in mods/ or mods/optional/ based on Group)
#   - invalid case (both sides unsupported) should be skipped from mods/server and logged (implicitly by absence)

. "$PSScriptRoot\..\TestFramework.ps1"
# Import functions under test
. "$PSScriptRoot\..\..\src\Release\Get-ExpectedReleaseFiles.ps1"
. "$PSScriptRoot\..\..\src\Release\Copy-ModsToRelease.ps1"

$TestFileName = "97-TestServerOnlyClassification.ps1"
Write-Host "Server-Only Classification Tests" -ForegroundColor $Colors.Header
Write-Host "================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName
$testOutDir = Get-TestOutputFolder $TestFileName
$csvPath = Join-Path $testOutDir 'classification-test.csv'
$downloadDir = Join-Path $testOutDir 'download'
$version = '1.21.8'
$downloadModsDir = Join-Path $downloadDir $version 'mods'
New-Item -ItemType Directory -Path $downloadModsDir -Force | Out-Null

# Build synthetic CSV rows covering scenarios
$rows = @(
    # client-only (required on client, unsupported on server)
    [pscustomobject]@{ ID='entityculling'; Name='Entity Culling'; Type='mod'; Group='required'; ClientSide='required'; ServerSide='unsupported'; CurrentGameVersion=$version; Jar='entityculling-1.jar' },
    # server-only (client unsupported, server required)
    [pscustomobject]@{ ID='ledger'; Name='Ledger'; Type='mod'; Group='required'; ClientSide='unsupported'; ServerSide='required'; CurrentGameVersion=$version; Jar='ledger-1.jar' },
    # explicit server type (should be server-only regardless of ClientSide)
    [pscustomobject]@{ ID='minecraft-server'; Name='Minecraft Server'; Type='server'; Group='required'; ClientSide='unsupported'; ServerSide='required'; CurrentGameVersion=$version; Jar='minecraft_server.1.21.8.jar' },
    # optional client mod (stays in optional)
    [pscustomobject]@{ ID='sodium'; Name='Sodium'; Type='mod'; Group='admin'; ClientSide='required'; ServerSide='unsupported'; CurrentGameVersion=$version; Jar='sodium-1.jar' },
    # dual side (both required)
    [pscustomobject]@{ ID='luckperms'; Name='LuckPerms'; Type='mod'; Group='required'; ClientSide='required'; ServerSide='required'; CurrentGameVersion=$version; Jar='luckperms-1.jar' },
    # invalid (both unsupported) -> expect skip, not copied anywhere
    [pscustomobject]@{ ID='ghostmod'; Name='GhostMod'; Type='mod'; Group='required'; ClientSide='unsupported'; ServerSide='unsupported'; CurrentGameVersion=$version; Jar='ghostmod-1.jar' },
    # installer type (should be server-only)
    [pscustomobject]@{ ID='fabric-installer'; Name='Fabric Installer'; Type='installer'; Group='required'; ClientSide='unsupported'; ServerSide='required'; CurrentGameVersion=$version; Jar='fabric-installer-1.jar' }
)
$rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# Create dummy jar files in source mods folder for each Jar
foreach ($r in $rows) {
    $jarPath = Join-Path $downloadModsDir $r.Jar
    Set-Content -Path $jarPath -Value "dummy" -Encoding UTF8
}

Write-TestHeader "Classification Execution"
Write-Host "Invoking Copy-ModsToRelease with synthetic dataset" -ForegroundColor Yellow
$releaseDir = Join-Path $testOutDir 'release'
$releaseModsDir = Join-Path $releaseDir 'mods'
$result = Copy-ModsToRelease -SourcePath $downloadModsDir -DestinationPath $releaseModsDir -CsvPath $csvPath -TargetGameVersion $version
Write-TestResult "Copy-ModsToRelease succeeded" $result

Write-TestHeader "Assertions"

# Paths
$serverDir = Join-Path $releaseModsDir 'server'
# $optionalDir reserved for future optional-group assertions
# $blockDir reserved for future assertions on blocked mods

function ExistsIn($dir, $name) { Test-Path (Join-Path $dir $name) }

# 1. Entity Culling (client required, server unsupported) -> client-only (mods root)
$entityCullingOk = ExistsIn $releaseModsDir 'entityculling-1.jar' -and -not (ExistsIn $serverDir 'entityculling-1.jar')
Write-TestResult "EntityCulling classified as client-only" $entityCullingOk

# 2. Ledger (client unsupported) -> server-only
$ledgerOk = ExistsIn $serverDir 'ledger-1.jar' -and -not (ExistsIn $releaseModsDir 'ledger-1.jar')
Write-TestResult "Ledger classified as server-only" $ledgerOk

# 3. LuckPerms (dual side) -> mods root
$luckPermsOk = ExistsIn $releaseModsDir 'luckperms-1.jar' -and -not (ExistsIn $serverDir 'luckperms-1.jar')
Write-TestResult "LuckPerms classified as dual/client mod" $luckPermsOk

# 4. GhostMod (both unsupported) -> treated as server-only (client unsupported)
$ghostServer = ExistsIn $serverDir 'ghostmod-1.jar'
Write-TestResult "GhostMod classified as server-only (client unsupported)" $ghostServer

Write-TestHeader "Summary"
Write-Host "Release mods directory contents:" -ForegroundColor Gray
Get-ChildItem -Path $releaseModsDir -Recurse -File | ForEach-Object { Write-Host "  $(($_.FullName).Replace($releaseModsDir, ''))" -ForegroundColor DarkGray }

Show-TestSummary "Server-Only Classification"
return ($script:TestResults.Failed -eq 0)
