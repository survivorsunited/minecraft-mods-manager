$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../TestFramework.ps1"
$script:TestResults = @{Total=0; Passed=0; Failed=0}
Initialize-TestEnvironment '109-TestForkReleaseAssets.ps1'
. "$PSScriptRoot/../../src/Provider/GitHub/Validate-GitHubModVersion.ps1"
$cases = @(
    @{Name='custom-portals-4.0.33+1.21.11.jar'; Version='4.0.33'; Game='1.21.11'},
    @{Name='Amecs-Reborn-2.0.3+mc1.21.11.jar'; Version='2.0.3'; Game='1.21.11'},
    @{Name='custom-portals-4.0.31-1.21.8.jar'; Version='4.0.31'; Game='1.21.8'},
    @{Name='custom-portals-4.0.33%2B1.21.11.jar'; Version='4.0.33'; Game='1.21.11'}
)
foreach ($case in $cases) {
    $meta = Get-GitHubJarMetadataFromFileName $case.Name
    if (!$meta -or $meta.Version -ne $case.Version -or $meta.GameVersion -ne $case.Game) { throw "Wrong metadata: $($case.Name)" }
    Write-TestResult "Metadata: $($case.Name)" $true
}
foreach ($name in @('custom-portals-4.0.33+1.21.11-sources.jar', 'Amecs-Reborn-2.0.3+mc1.21.11-dev.jar', 'SHA256SUMS.txt')) {
    if (Test-GitHubPlayableJarAsset $name) { throw "Non-playable asset selected: $name" }
    Write-TestResult "Excluded asset: $name" $true
}
& {
    function Get-GitHubProjectInfo { param($RepositoryUrl,$UseCachedResponses,[switch]$Quiet) return @{name='mod-CustomPortals'} }
    function Get-GitHubReleases {
        param($RepositoryUrl,$UseCachedResponses,[switch]$Quiet)
        return @{published_at='2026-10-01T00:00:00Z'; tag_name='4.0.33'; assets=@(
            @{name='custom-portals-4.0.33+1.21.11.jar'; browser_download_url='https://example.invalid/portals.jar'; size=100}
        )}
    }
    $result = Validate-GitHubModVersion -ModID survivorsunited/mod-CustomPortals -Version 99.0.0 -Loader fabric -GameVersion 1.21.11 -Quiet
    if ($result.Success) { throw 'Unavailable pinned version silently selected another release' }
    Write-TestResult 'Unavailable pinned version rejected' $true
    $result = Validate-GitHubModVersion -ModID survivorsunited/mod-CustomPortals -Version 4.0.33 -Loader fabric -GameVersion 1.21.11 -Quiet
    if (!$result.Success -or $result.Version -ne '4.0.33') { throw 'Exact pinned fork version was not selected' }
    Write-TestResult 'Exact pinned fork version selected' $true
    $result = Validate-GitHubModVersion -ModID survivorsunited/mod-CustomPortals -Version '4.0.33+1.21.11' -Loader fabric -GameVersion 1.21.11 -Quiet
    if (!$result.Success) { throw 'Legacy pin including Minecraft suffix was rejected' }
    Write-TestResult 'Legacy Minecraft suffix pin accepted' $true
}
$payload = Join-Path (Get-TestOutputFolder '109-TestForkReleaseAssets.ps1') ('payload-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$payload/mods" -Force | Out-Null
$pins = Join-Path $payload 'pins.json'
$file = Join-Path $payload 'mods/custom-portals-4.0.33+1.21.11.jar'
[IO.File]::WriteAllText($file, 'test artifact')
$hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
@{mods=@(@{pattern='custom-portals-*.jar'; file=[IO.Path]::GetFileName($file); sha256=$hash})} | ConvertTo-Json -Depth 4 | Set-Content $pins
$validator = "$PSScriptRoot/../../scripts/Validate-ForkReleasePayload.ps1"
& $validator -ReleasePath $payload -PinsPath $pins
Write-TestResult 'Exact checksum passes release gate' $true
[IO.File]::WriteAllText($file, 'corrupt artifact')
$rejected = $false
try { & $validator -ReleasePath $payload -PinsPath $pins } catch { $rejected = $_.Exception.Message -match 'checksum mismatch' }
if (!$rejected) { throw 'Corrupted fork asset passed release gate' }
Write-TestResult 'Corrupted checksum rejected' $true
Copy-Item -LiteralPath $file -Destination "$payload/mods/custom-portals-old.jar"
$rejected = $false
try { & $validator -ReleasePath $payload -PinsPath $pins } catch { $rejected = $_.Exception.Message -match 'exactly one' }
if (!$rejected) { throw 'Duplicate fork asset passed release gate' }
Write-TestResult 'Duplicate fork version rejected' $true
& {
    function Validate-AllModVersions {}
    . "$PSScriptRoot/../../src/Validation/Mod/Validate-AllModVersionsKnownTargets.ps1"
    $db = Join-Path $payload 'repair.csv'
    @([pscustomobject]@{Host='github'; ApiSource='github'; Url='https://github.com/example/mod'; Name='Example'; CurrentGameVersion='1.21.11'; LatestGameVersion='1.21.11'; CurrentVersion='4.0.32'; LatestVersion='4.0.33'; CurrentVersionUrl='https://example.invalid/old.jar'; LatestVersionUrl='https://github.com/example/mod/releases/download/4.0.33/custom-portals-4.0.33+1.21.11.jar'; Jar='old.jar'; RecordHash=''}) | Export-Csv $db -NoTypeInformation
    Repair-GitHubCurrentUrlsFromLatest -CsvPath $db
    $repaired = Import-Csv $db
    if ($repaired.Jar -cne 'custom-portals-4.0.33+1.21.11.jar') { throw 'URL repair changed a literal plus into a space' }
    Write-TestResult 'URL repair preserves literal plus in fork filename' $true
}
. "$PSScriptRoot/../../src/Release/Get-ExpectedReleaseFiles.ps1"
. "$PSScriptRoot/../../src/Release/Copy-ModsToRelease.ps1"
$copyDb = Join-Path $payload 'copy.csv'
Import-Csv "$PSScriptRoot/../../modlist.csv" | Where-Object ID -eq 'survivorsunited/mod-CustomPortals' | Export-Csv $copyDb -NoTypeInformation
$copyResult = Copy-ModsToRelease -SourcePath "$payload/mods" -DestinationPath "$payload/release/mods" -CsvPath $copyDb -TargetGameVersion '1.21.11'
if (!$copyResult -or !(Test-Path "$payload/release/mods/custom-portals-4.0.33+1.21.11.jar")) { throw 'Fork JAR was omitted during release organization' }
Write-TestResult 'Fork JAR survives target-version release organization' $true
& {
    function Get-ModList {}
    . "$PSScriptRoot/../../src/Patches/Pin-12111ModVersions.ps1"
    $row = Import-Csv "$PSScriptRoot/../../modlist.csv" | Where-Object ID -eq 'survivorsunited/mod-basic-storage'
    $databaseJar = $row.Jar
    Set-12111BasicStoragePin $row
    if ($row.CurrentVersionUrl -notmatch '%2B') { throw 'Effective Basic Storage pin bypasses safe URL encoding' }
    Write-TestResult 'Effective Basic Storage pin uses safe asset URL' $true
    if ($databaseJar -cne $row.Jar) { throw 'Database Basic Storage filename differs from effective download pin' }
    Write-TestResult 'Basic Storage database matches effective release pin' $true
    $row = Import-Csv "$PSScriptRoot/../../modlist.csv" | Where-Object {$_.ID -eq 'fabric-launcher' -and $_.CurrentGameVersion -eq '1.21.11'}
    Set-12111FabricLauncherPin $row
    if ($row.CurrentVersion -ne '0.19.5') { throw 'Effective launcher pin does not meet Kotlin loader requirement' }
    Write-TestResult 'Effective Fabric pin meets Kotlin loader requirement' $true
}
. "$PSScriptRoot/../../src/Download/Mods/Download-Mods.ps1"
foreach ($header in @(
    'attachment; filename=custom-portals-4.0.33+1.21.11.jar',
    'attachment; filename="custom-portals-4.0.33+1.21.11.jar"',
    "attachment; filename*=UTF-8''custom-portals-4.0.33%2B1.21.11.jar"
)) {
    # Reproduce the stale version capture present in a real download loop.
    '1.21.11' -match '(1\.\d+\.\d+)' | Out-Null
    $response = [pscustomobject]@{Headers=@{'Content-Disposition'=[string[]]@($header)}}
    if ((Get-DownloadResponseFilename $response) -cne 'custom-portals-4.0.33+1.21.11.jar') { throw 'Array-valued download header reused a stale version capture' }
    Write-TestResult "GitHub response filename parsed: $header" $true
}
foreach ($header in @('invalid header', 'attachment; filename="../escape.jar"')) {
    if (Get-DownloadResponseFilename ([pscustomobject]@{Headers=@{'Content-Disposition'=[string[]]@($header)}})) { throw 'Unsafe or invalid response filename accepted' }
    Write-TestResult "Unsafe response filename ignored: $header" $true
}
Show-TestSummary
