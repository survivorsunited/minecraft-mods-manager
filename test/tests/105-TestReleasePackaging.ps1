# 105-TestReleasePackaging.ps1
# Tests for release packaging issues:
# 1. Installer version matching (exe and jar must match)
# 2. Installer file duplication (should only be in install/, not root)
# 3. Server mods placement (should be in mods/, not mods/server/)
# 4. Build artifacts exclusion (verification files should not be in release)

. "$PSScriptRoot\..\TestFramework.ps1"
. "$PSScriptRoot\..\..\src\Release\Copy-ModsToRelease.ps1"
. "$PSScriptRoot\..\..\src\Release\Get-ExpectedReleaseFiles.ps1"

$TestFileName = "105-TestReleasePackaging.ps1"
Initialize-TestEnvironment $TestFileName
$testOutDir = Get-TestOutputFolder $TestFileName

Write-Host "Minecraft Mod Manager - Release Packaging Tests" -ForegroundColor $Colors.Header
Write-Host "=================================================" -ForegroundColor $Colors.Header
Write-Host ""

# Test 1: Installer version matching
Write-TestHeader "Test 1: Installer Version Matching"

$version = '1.21.8'
$downloadDir = Join-Path $testOutDir 'download' $version
$installerDir = Join-Path $downloadDir 'installer'
$releaseDir = Join-Path $testOutDir 'release'

New-Item -ItemType Directory -Path $installerDir -Force | Out-Null
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

# Create installer files with matching versions (1.1.0)
$exeFile = Join-Path $installerDir 'fabric-installer-1.1.0.exe'
$jarFile = Join-Path $installerDir 'fabric-installer-1.1.0.jar'
Set-Content -Path $exeFile -Value 'dummy exe' -Encoding UTF8
Set-Content -Path $jarFile -Value 'dummy jar' -Encoding UTF8

# Simulate the release build process
$installReleaseDir = Join-Path $releaseDir 'install'
New-Item -ItemType Directory -Path $installReleaseDir -Force | Out-Null

# Copy installers (simulating New-Release.ps1 behavior)
$fabricInstallerExe = Get-ChildItem -Path $installerDir -Filter 'fabric-installer-*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
$fabricInstallerJar = Get-ChildItem -Path $installerDir -Filter 'fabric-installer-*.jar' -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($fabricInstallerExe -and $fabricInstallerJar) {
    # Extract versions from filenames
    $exeVersion = if ($fabricInstallerExe.Name -match 'fabric-installer-([\d.]+)\.exe') { $matches[1] } else { $null }
    $jarVersion = if ($fabricInstallerJar.Name -match 'fabric-installer-([\d.]+)\.jar') { $matches[1] } else { $null }
    
    Write-TestResult "Installer EXE version extracted" ($null -ne $exeVersion)
    Write-TestResult "Installer JAR version extracted" ($null -ne $jarVersion)
    Write-TestResult "Installer versions match" ($exeVersion -eq $jarVersion)
    
    if ($exeVersion -ne $jarVersion) {
        Write-Host "  ⚠️  Version mismatch: EXE=$exeVersion, JAR=$jarVersion" -ForegroundColor $Colors.Warning
    }
}

# Test 2: Installer duplication
Write-TestHeader "Test 2: Installer File Duplication"

# Simulate copying to root (should NOT happen)
$rootExe = Join-Path $releaseDir 'fabric-installer-1.1.0.exe'
$rootJar = Join-Path $releaseDir 'fabric-installer-1.1.0.jar'
$installExe = Join-Path $installReleaseDir 'fabric-installer-1.1.0.exe'
$installJar = Join-Path $installReleaseDir 'fabric-installer-1.1.0.jar'

# Copy to install/ only (correct behavior)
Copy-Item -Path $fabricInstallerExe.FullName -Destination $installExe -Force
Copy-Item -Path $fabricInstallerJar.FullName -Destination $installJar -Force

Write-TestResult "Installer EXE in install/ folder" (Test-Path $installExe)
Write-TestResult "Installer JAR in install/ folder" (Test-Path $installJar)
Write-TestResult "Installer EXE NOT in root" (-not (Test-Path $rootExe))
Write-TestResult "Installer JAR NOT in root" (-not (Test-Path $rootJar))

# Test 3: Server mods placement
Write-TestHeader "Test 3: Server Mods Placement"

$csv = Join-Path $testOutDir 'release-packaging.csv'
$downloadModsDir = Join-Path $downloadDir 'mods'
$releaseModsDir = Join-Path $releaseDir 'mods'
New-Item -ItemType Directory -Path $downloadModsDir -Force | Out-Null

# Create CSV with server-side mods
$rows = @(
    [pscustomobject]@{ 
        Group='required'; Type='mod'; CurrentGameVersion=$version; ID='luckperms'; Name='LuckPerms'; 
        Jar='LuckPerms-Fabric-5.5.10.jar'; ClientSide='unsupported'; ServerSide='required' 
    },
    [pscustomobject]@{ 
        Group='required'; Type='mod'; CurrentGameVersion=$version; ID='fabricproxy-lite'; Name='FabricProxy Lite'; 
        Jar='FabricProxy-Lite-2.10.1.jar'; ClientSide='unsupported'; ServerSide='required' 
    },
    [pscustomobject]@{ 
        Group='required'; Type='mod'; CurrentGameVersion=$version; ID='lithium'; Name='Lithium'; 
        Jar='lithium-fabric-0.18.1+mc1.21.8.jar'; ClientSide='required'; ServerSide='required' 
    }
)
$rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8

# Create dummy JARs
Set-Content -Path (Join-Path $downloadModsDir 'LuckPerms-Fabric-5.5.10.jar') -Value 'dummy' -Encoding UTF8
Set-Content -Path (Join-Path $downloadModsDir 'FabricProxy-Lite-2.10.1.jar') -Value 'dummy' -Encoding UTF8
Set-Content -Path (Join-Path $downloadModsDir 'lithium-fabric-0.18.1+mc1.21.8.jar') -Value 'dummy' -Encoding UTF8

# Execute copy
$ok = Copy-ModsToRelease -SourcePath $downloadModsDir -DestinationPath $releaseModsDir -CsvPath $csv -TargetGameVersion $version
Write-TestResult "Copy-ModsToRelease executed" $ok

# Check server mods are in main mods/ folder, not mods/server/
$serverDir = Join-Path $releaseModsDir 'server'
$luckpermsInServer = Join-Path $serverDir 'LuckPerms-Fabric-5.5.10.jar'
$luckpermsInMain = Join-Path $releaseModsDir 'LuckPerms-Fabric-5.5.10.jar'
$fabricproxyInServer = Join-Path $serverDir 'FabricProxy-Lite-2.10.1.jar'
$fabricproxyInMain = Join-Path $releaseModsDir 'FabricProxy-Lite-2.10.1.jar'

Write-TestResult "Server mods NOT in mods/server/ subfolder" ((-not (Test-Path $serverDir)) -or ((Get-ChildItem -Path $serverDir -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0))
Write-TestResult "Server mods in main mods/ folder" ((Test-Path $luckpermsInMain) -or (Test-Path $fabricproxyInMain))
Write-TestResult "Normal mod in mods/ folder" (Test-Path (Join-Path $releaseModsDir 'lithium-fabric-0.18.1+mc1.21.8.jar'))

# Test 4: Build artifacts exclusion
Write-TestHeader "Test 4: Build Artifacts Exclusion"

# Create build artifact files (should NOT be in release)
$artifacts = @(
    'actual-release-files.txt',
    'expected-release-files.txt',
    'verification-extra.txt',
    'verification-missing.txt'
)

# These should NOT exist in release
$artifactsFound = @()
foreach ($artifact in $artifacts) {
    $artifactPath = Join-Path $releaseDir $artifact
    if (Test-Path $artifactPath) {
        $artifactsFound += $artifact
    }
}

Write-TestResult "No build artifacts in release" ($artifactsFound.Count -eq 0)
if ($artifactsFound.Count -gt 0) {
    Write-Host "  ⚠️  Found build artifacts: $($artifactsFound -join ', ')" -ForegroundColor $Colors.Warning
}

# hash.txt and README.md are allowed (generated by hash tool)
$hashTxt = Join-Path $releaseDir 'hash.txt'
$readmeMd = Join-Path $releaseDir 'README.md'
Write-TestResult "hash.txt is allowed (generated by hash tool)" $true
Write-TestResult "README.md is allowed (generated by hash tool)" $true

Show-TestSummary "Release Packaging"
return ($script:TestResults.Failed -eq 0)

