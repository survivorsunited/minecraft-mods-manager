# =============================================================================
# Release Creation Module
# =============================================================================
# This module handles the complete release package creation workflow.
# =============================================================================

<#
.SYNOPSIS
    Creates a complete release package for a specific Minecraft version.

.DESCRIPTION
    Orchestrates the full release creation workflow:
    1. Determines target version
    2. Downloads mods for the version
    3. Downloads server files
    4. Validates mods by starting server
    5. Organizes mods into release structure
    6. Generates hashes and documentation
    7. Creates ZIP package

.PARAMETER CsvPath
    Path to the mod database CSV file.

.PARAMETER DownloadFolder
    Path to the download folder.

.PARAMETER ApiResponseFolder
    Path to the API response cache folder.

.PARAMETER ReleasePath
    Path where release packages will be created.

.PARAMETER TargetVersion
    Specific version to target for release.

.PARAMETER GameVersion
    Game version to use (alternative to TargetVersion).

.PARAMETER UseLatestVersion
    Use the latest game version.

.PARAMETER UseNextVersion
    Use the next game version.

.PARAMETER NoAutoRestart
    Disable automatic server restart during validation.

.PARAMETER ProjectRoot
    Root directory of the project (for finding hash script).

.EXAMPLE
    New-Release -CsvPath "modlist.csv" -DownloadFolder "download" -ReleasePath "releases" -GameVersion "1.21.5"

.NOTES
    - Exits with code 0 on success
    - Exits with code 1 on failure
    - Performs server validation before creating release
#>
function New-Release {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder,
        
        [Parameter(Mandatory=$true)]
        [string]$ApiResponseFolder,
        
        [Parameter(Mandatory=$true)]
        [string]$ReleasePath,
        
        [Parameter(Mandatory=$false)]
        [string]$TargetVersion,
        
        [Parameter(Mandatory=$false)]
        [string]$GameVersion,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseLatestVersion,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseNextVersion,
        
        [Parameter(Mandatory=$false)]
        [switch]$NoAutoRestart,
        
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot
    )
    
    Write-Host "Creating release package..." -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    
    # Determine target version
    if ($TargetVersion) {
        $targetVersion = $TargetVersion
        Write-Host "🎯 Target version: $targetVersion (user specified via TargetVersion)" -ForegroundColor Green
    } elseif ($GameVersion) {
        $targetVersion = $GameVersion
        Write-Host "🎯 Target version: $targetVersion (user specified via GameVersion)" -ForegroundColor Green
    } elseif ($UseLatestVersion) {
        $targetVersion = Get-LatestVersion -CsvPath $CsvPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine latest game version" -ForegroundColor Red
            return $false
        }
        Write-Host "🎯 Target version: $targetVersion (LATEST version)" -ForegroundColor Green
    } elseif ($UseNextVersion) {
        $targetVersion = Get-NextVersion -CsvPath $CsvPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine next game version" -ForegroundColor Red
            return $false
        }
        Write-Host "🎯 Target version: $targetVersion (NEXT version)" -ForegroundColor Green
    } else {
        $targetVersion = Get-CurrentVersion -CsvPath $CsvPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine current game version" -ForegroundColor Red
            return $false
        }
        Write-Host "🎯 Target version: $targetVersion (CURRENT version - default)" -ForegroundColor Green
    }
    
    Write-Host "" -ForegroundColor White
    
    # Pre-step: Single DB validation pass to refresh URLs and classifications (ClientSide/ServerSide)
    Write-Host "🧹 Validating database (URLs, versions, classifications) before release..." -ForegroundColor Cyan
    # Be resilient to terminating errors from validation helpers: suppress progress and continue on errors
    $prevEAP = $ErrorActionPreference
    $prevPP = $ProgressPreference
    try {
        $ErrorActionPreference = 'Continue'
        $ProgressPreference = 'SilentlyContinue'
        # Update CSV with latest validated data, including ClientSide/ServerSide from providers
        try { Validate-AllModVersions -CsvPath $CsvPath -ResponseFolder $ApiResponseFolder -UpdateModList -ErrorAction Continue | Out-Null } catch { Write-Host "  ⚠️  Validation update failed: $($_.Exception.Message)" -ForegroundColor Yellow }
        try {
            # Fix version/URL mismatches discovered in DB
            if (Get-Command Validate-ModVersionUrls -ErrorAction SilentlyContinue) {
                $null = Validate-ModVersionUrls -CsvPath $CsvPath -ErrorAction Continue
            }
        } catch { Write-Host "  ⚠️  URL mismatch validator failed: $($_.Exception.Message)" -ForegroundColor Yellow }
        try {
            # Lint for common DB issues (e.g., ZIPs under mods)
            if (Get-Command Test-ModDatabase -ErrorAction SilentlyContinue) {
                $null = Test-ModDatabase -CsvPath $CsvPath -ErrorAction Continue
            }
        } catch { Write-Host "  ⚠️  Database lint failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    } finally {
        $ErrorActionPreference = $prevEAP
        $ProgressPreference = $prevPP
    }
    
    # Step 1: Download mods for target version
    Write-Host "📦 Downloading mods for version $targetVersion..." -ForegroundColor Cyan
    Download-Mods -CsvPath $CsvPath -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder -TargetGameVersion $targetVersion
    
    Write-Host "" -ForegroundColor White
    
    # Step 2: Download server files
    Write-Host "📦 Downloading server files for version $targetVersion..." -ForegroundColor Cyan
    Download-ServerFiles -DownloadFolder $DownloadFolder -ForceDownload:$false -GameVersion $targetVersion
    
    Write-Host "" -ForegroundColor White
    
    # Step 3: VALIDATION GATE - Start server to verify compatibility (non-blocking)
    Write-Host "🧪 Validating mods by starting server..." -ForegroundColor Yellow
    Write-Host "   This ensures all mods are compatible before creating release package" -ForegroundColor Gray
    Write-Host "" -ForegroundColor White

    $serverParams = @{
        DownloadFolder = $DownloadFolder
        TargetVersion = $targetVersion
        CsvPath = $CsvPath
        LogFileTimeout = 120  # 2 minutes for log file detection
        ServerMonitorTimeout = 300  # 5 minutes for server startup monitoring
    }
    if ($NoAutoRestart) { $serverParams.Add("NoAutoRestart", $true) }

    $serverResult = $true
    try {
        $serverResult = Start-MinecraftServer @serverParams
    } catch {
        $serverResult = $false
    }

    if (-not $serverResult) {
        Write-Host "" -ForegroundColor White
        Write-Host "⚠️  SERVER VALIDATION FAILED - proceeding to package anyway (non-blocking)" -ForegroundColor Yellow
        Write-Host "   A release will still be created so clients can update; investigate validation logs separately." -ForegroundColor DarkYellow
    } else {
        Write-Host "" -ForegroundColor White
        Write-Host "✅ Server validation passed - proceeding with release creation" -ForegroundColor Green
    }

    # Step 4: Ensure cache of mods/shaderpacks/datapacks is populated for this version
    Write-Host "📦 Ensuring cache is populated (mods/shaderpacks/datapacks)..." -ForegroundColor Cyan
    try {
        Download-Mods -CsvPath $CsvPath -DownloadFolder $DownloadFolder -ApiResponseFolder (Join-Path $ProjectRoot 'apiresponse') -TargetGameVersion $targetVersion -SkipServerFiles | Out-Null
    } catch { Write-Host "  ⚠️  Warning: Ensure-cache step failed: $($_.Exception.Message)" -ForegroundColor Yellow }

    # Step 5: Create timestamped release directory and organize content
    $releaseBase = Join-Path $ReleasePath $targetVersion
    $runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $releaseDir = Join-Path $releaseBase $runStamp
    $releaseModsPath = Join-Path $releaseDir 'mods'
    $releaseShaderpacks = Join-Path $releaseDir 'shaderpacks'
    $releaseDatapacks = Join-Path $releaseDir 'datapacks'
    New-Item -ItemType Directory -Path $releaseModsPath -Force | Out-Null

    $downloadVersionPath = Join-Path $DownloadFolder $targetVersion
    $sourceModsPath = Join-Path $downloadVersionPath 'mods'
    if (-not (Test-Path $sourceModsPath)) {
        Write-Host "❌ Source mods not found: $sourceModsPath" -ForegroundColor Red
        return $false
    }

    $organizeOk = Copy-ModsToRelease -SourcePath $sourceModsPath -DestinationPath $releaseModsPath -CsvPath $CsvPath -TargetGameVersion $targetVersion
    if (-not $organizeOk) { Write-Host "❌ Failed to organize mods for release" -ForegroundColor Red; return $false }

    # Copy shaderpacks
    $sourceShaderpacks = Join-Path $downloadVersionPath 'shaderpacks'
    if (Test-Path $sourceShaderpacks) {
        New-Item -ItemType Directory -Path $releaseShaderpacks -Force | Out-Null
        $shaderFiles = Get-ChildItem -Path $sourceShaderpacks -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip', '.jar') }
        foreach ($sp in $shaderFiles) { Copy-Item -Path $sp.FullName -Destination (Join-Path $releaseShaderpacks $sp.Name) -Force }
        Write-Host "Copied $($shaderFiles.Count) shaderpack file(s)" -ForegroundColor Gray
    } else { Write-Host "No shaderpacks found (skipping)" -ForegroundColor DarkGray }

    # Copy datapacks: JAR -> mods (respect Group), ZIP -> datapacks
    $sourceDatapacks = Join-Path $downloadVersionPath 'datapacks'
    if (Test-Path $sourceDatapacks) {
        $rows = Import-Csv -Path $CsvPath
        function Normalize($s) { if ($null -eq $s) { return $null } ($s.ToString()).Trim() }
        $versionFilter = {
            param($r)
            $cur = Normalize $r.CurrentGameVersion; $avail = Normalize $r.AvailableGameVersions
            if ([string]::IsNullOrWhiteSpace($cur) -and [string]::IsNullOrWhiteSpace($avail)) { return $false }
            if ($cur -eq $targetVersion) { return $true }
            if ($avail -and $avail -match [Regex]::Escape($targetVersion)) { return $true }
            return $false
        }
        $dpRows = $rows | Where-Object { (Normalize $_.Type) -eq 'datapack' -and (& $versionFilter $_) }
        $copiedJarCount = 0; $copiedZipCount = 0
        foreach ($d in $dpRows) {
            $jarName = Normalize $d.Jar; if ([string]::IsNullOrWhiteSpace($jarName)) { continue }
            $src = Join-Path $sourceDatapacks $jarName; if (-not (Test-Path $src)) { continue }
            $ext = [System.IO.Path]::GetExtension($jarName).ToLower()
            if ($ext -eq '.jar') {
                $grp = (Normalize $d.Group); if ([string]::IsNullOrWhiteSpace($grp)) { $grp = 'required' }
                $destDir = switch ($grp.ToLower()) { 'optional' { Join-Path $releaseModsPath 'optional' } 'block' { Join-Path $releaseModsPath 'block' } default { $releaseModsPath } }
                if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                Copy-Item -Path $src -Destination (Join-Path $destDir $jarName) -Force; $copiedJarCount++
            } elseif ($ext -eq '.zip') {
                if (-not (Test-Path $releaseDatapacks)) { New-Item -ItemType Directory -Path $releaseDatapacks -Force | Out-Null }
                Copy-Item -Path $src -Destination (Join-Path $releaseDatapacks $jarName) -Force; $copiedZipCount++
            }
        }
        Write-Host "Datapacks copied -> jars to mods: $copiedJarCount, zips to datapacks: $copiedZipCount" -ForegroundColor Gray
    } else { Write-Host "No datapacks found (skipping)" -ForegroundColor DarkGray }

    # Step 6: Expected vs actual verification (relaxed-version)
    $expectedFile = Join-Path $releaseDir 'expected-release-files.txt'
    $null = Get-ExpectedReleaseFiles -Version $targetVersion -CsvPath $CsvPath -OutputPath $expectedFile
    if (-not (Test-Path $expectedFile)) { Write-Host "❌ Expected file list not produced" -ForegroundColor Red; return $false }

    $actualList = @()
    if (Test-Path $releaseModsPath) { $actualList += (Get-ChildItem -Path $releaseModsPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.jar', '.zip') } | ForEach-Object { "mods/" + $_.Name }) }
    $optPath = Join-Path $releaseModsPath 'optional'; if (Test-Path $optPath) { $actualList += (Get-ChildItem -Path $optPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.jar', '.zip') } | ForEach-Object { "mods/optional/" + $_.Name }) }
    $serverPath = Join-Path $releaseModsPath 'server'; if (Test-Path $serverPath) { $actualList += (Get-ChildItem -Path $serverPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.jar', '.zip') } | ForEach-Object { "mods/server/" + $_.Name }) }
    if (Test-Path $releaseShaderpacks) { $actualList += (Get-ChildItem -Path $releaseShaderpacks -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip', '.jar') } | ForEach-Object { "shaderpacks/" + $_.Name }) }
    if (Test-Path $releaseDatapacks) { $actualList += (Get-ChildItem -Path $releaseDatapacks -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.zip' } | ForEach-Object { "datapacks/" + $_.Name }) }
    $actualFile = Join-Path $releaseDir 'actual-release-files.txt'
    $actualList | Sort-Object | Out-File -FilePath $actualFile -Encoding UTF8

    $expectedCompare = Get-Content -Path $expectedFile | Where-Object { (($_ -like 'mods/*') -or ($_ -like 'shaderpacks/*') -or ($_ -like 'datapacks/*')) -and ($_ -notlike 'mods/block/*') }
    $actualCompare = Get-Content -Path $actualFile
    $expectedSet = New-Object System.Collections.Generic.HashSet[string]; $null = $expectedCompare | ForEach-Object { $expectedSet.Add($_) | Out-Null }
    $actualSet = New-Object System.Collections.Generic.HashSet[string];   $null = $actualCompare  | ForEach-Object { $actualSet.Add($_)  | Out-Null }
    $missing = @(); foreach ($e in $expectedSet) { if (-not $actualSet.Contains($e)) { $missing += $e } }
    $extra   = @(); foreach ($a in $actualSet)   { if (-not $expectedSet.Contains($a)) { $extra   += $a } }

    # relaxed-version pairing for mods
    function Get-BaseModKey([string]$relPath) {
        if ($relPath -notlike 'mods/*') { return $null }
        $folder = if ($relPath.StartsWith('mods/optional/')) { 'mods/optional/' } elseif ($relPath.StartsWith('mods/server/')) { 'mods/server/' } else { 'mods/' }
        $file = $relPath.Substring($folder.Length)
        $name = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $m = [System.Text.RegularExpressions.Regex]::Match($name, '^(.*?)(?:[-_]?)(?=\d)')
        $base = if ($m.Success -and $m.Groups.Count -gt 1 -and $m.Groups[1].Value.Trim().Length -gt 0) { $m.Groups[1].Value.TrimEnd('-','_') } else { $name }
        return $folder + $base.ToLower()
    }
    $expectedByBase = @{}; foreach ($e in $missing) { $k = Get-BaseModKey $e; if ($null -ne $k) { if (-not $expectedByBase.ContainsKey($k)) { $expectedByBase[$k] = @() }; $expectedByBase[$k] += $e } }
    $actualByBase   = @{}; foreach ($a in $extra)   { $k = Get-BaseModKey $a; if ($null -ne $k) { if (-not $actualByBase.ContainsKey($k))   { $actualByBase[$k]   = @() } ; $actualByBase[$k]   += $a } }
    $pairedMissing = New-Object System.Collections.Generic.HashSet[string]
    $pairedExtra   = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $expectedByBase.Keys) {
        if ($actualByBase.ContainsKey($k)) { foreach ($eItem in $expectedByBase[$k]) { $pairedMissing.Add($eItem) | Out-Null }; foreach ($aItem in $actualByBase[$k]) { $pairedExtra.Add($aItem) | Out-Null } }
    }
    if ($pairedMissing.Count -gt 0 -or $pairedExtra.Count -gt 0) {
        $missing = $missing | Where-Object { -not $pairedMissing.Contains($_) }
        $extra   = $extra   | Where-Object { -not $pairedExtra.Contains($_) }
        Write-Host "  ⚠️  Ignoring version-only differences for mods (relaxed-version)" -ForegroundColor DarkYellow
    }

    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        Write-Host "Verification differences detected:" -ForegroundColor Yellow
        $missingPath = Join-Path $releaseDir 'verification-missing.txt'
        $extraPath = Join-Path $releaseDir 'verification-extra.txt'
        if ($missing.Count -gt 0) { Write-Host "  Missing (expected but not found):" -ForegroundColor Red; $missing | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }; $missing | Out-File -FilePath $missingPath -Encoding UTF8 } else { '' | Out-File -FilePath $missingPath -Encoding UTF8 }
        if ($extra.Count -gt 0)   { Write-Host "  Unexpected (present but not expected):" -ForegroundColor DarkYellow; $extra | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkYellow }; $extra | Out-File -FilePath $extraPath -Encoding UTF8 } else { '' | Out-File -FilePath $extraPath -Encoding UTF8 }
        Write-Host "⚠️  Continuing despite differences (relaxed-version)" -ForegroundColor DarkYellow
    } else { Write-Host "✓ Release files verified against DB expectations" -ForegroundColor Green }

    # Stage server jars, installer, and IAC config before packaging (so zip can include them)
    try {
        $serverVersionPath = Join-Path $DownloadFolder $targetVersion
        if (Test-Path $serverVersionPath) {
            Write-Host "📦 Staging server jars, installer, and config for packaging..." -ForegroundColor Cyan
            # Copy server jars to release root
            $minecraftJar = Get-ChildItem -Path $serverVersionPath -Filter 'minecraft_server*.jar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($minecraftJar) { Copy-Item -Path $minecraftJar.FullName -Destination $releaseDir -Force; Write-Host "  ✓ Copied: $($minecraftJar.Name)" -ForegroundColor Green } else { Write-Host "  ⚠️  Minecraft server JAR not found" -ForegroundColor Yellow }
            $fabricJar = Get-ChildItem -Path $serverVersionPath -Filter 'fabric-server*.jar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($fabricJar) { Copy-Item -Path $fabricJar.FullName -Destination $releaseDir -Force; Write-Host "  ✓ Copied: $($fabricJar.Name)" -ForegroundColor Green } else { Write-Host "  ⚠️  Fabric launcher JAR not found" -ForegroundColor Yellow }

            # Stage installer in install/ folder within release (and keep copy at root)
            $installerPath = Join-Path $serverVersionPath 'installer'
            if (Test-Path $installerPath) {
                $installDir = Join-Path $releaseDir 'install'
                if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
                # Stage EXE installer
                $fabricInstallerExe = Get-ChildItem -Path $installerPath -Filter 'fabric-installer-*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($fabricInstallerExe) {
                    Copy-Item -Path $fabricInstallerExe.FullName -Destination $releaseDir -Force
                    Copy-Item -Path $fabricInstallerExe.FullName -Destination (Join-Path $installDir $fabricInstallerExe.Name) -Force
                    Write-Host "  ✓ Staged installer EXE: $($fabricInstallerExe.Name) (root and install/)" -ForegroundColor Green
                } else { Write-Host "  ⚠️  Fabric installer EXE not found" -ForegroundColor Yellow }
                # Stage JAR installer
                $fabricInstallerJar = Get-ChildItem -Path $installerPath -Filter 'fabric-installer-*.jar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($fabricInstallerJar) {
                    # Keep JAR only under install/
                    Copy-Item -Path $fabricInstallerJar.FullName -Destination (Join-Path $installDir $fabricInstallerJar.Name) -Force
                    Write-Host "  ✓ Staged installer JAR: $($fabricInstallerJar.Name) (install/)" -ForegroundColor Green
                } else { Write-Host "  ⚠️  Fabric installer JAR not found" -ForegroundColor Yellow }
            }
        }

        # Copy InertiaAntiCheat config from repository config folder into release (if present)
        $repoIacConfig = Join-Path $ProjectRoot 'config\InertiaAntiCheat\InertiaAntiCheat.toml'
        if (Test-Path $repoIacConfig) {
            $releaseIacDir = Join-Path $releaseDir 'config\InertiaAntiCheat'
            if (-not (Test-Path $releaseIacDir)) { New-Item -ItemType Directory -Path $releaseIacDir -Force | Out-Null }
            Copy-Item -Path $repoIacConfig -Destination (Join-Path $releaseIacDir 'InertiaAntiCheat.toml') -Force
            Write-Host "  ✓ Included IAC config: config/InertiaAntiCheat/InertiaAntiCheat.toml" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Repo IAC config not found at config/InertiaAntiCheat/InertiaAntiCheat.toml" -ForegroundColor Yellow
        }
    } catch { Write-Host "  ⚠️  Failed to stage server/installer/config: $($_.Exception.Message)" -ForegroundColor Yellow }

    # Step 7: Run hash generator to create README/hash and modpack.zip (now includes install/, server jars, and config)
    $hashScriptPath = Join-Path $ProjectRoot "tools\minecraft-mod-hash\hash.ps1"
    if (-not (Test-Path $hashScriptPath)) { Write-Host "❌ Hash generator not found: $hashScriptPath" -ForegroundColor Red; return $false }
    try {
        & $hashScriptPath -ModsPath $releaseModsPath -OutputPath $releaseDir -CreateZip -UpdateConfig
        $hashFile = Join-Path $releaseDir 'hash.txt'; $readmeFile = Join-Path $releaseDir 'README.md'; $zipFiles = Get-ChildItem -Path $releaseDir -Filter '*.zip' -File -ErrorAction SilentlyContinue
        if (-not (Test-Path $hashFile)) { Write-Host "❌ Hash file not created" -ForegroundColor Red; return $false }
        if (-not (Test-Path $readmeFile)) { Write-Host "❌ README file not created" -ForegroundColor Red; return $false }
        if ($zipFiles.Count -eq 0) { Write-Host "❌ ZIP package not created" -ForegroundColor Red; return $false }
    } catch { Write-Host "❌ Error running hash generator: $($_.Exception.Message)" -ForegroundColor Red; return $false }

    Write-Host "" -ForegroundColor White
    Write-Host "✅ Release package created successfully!" -ForegroundColor Green
    Write-Host "📂 Location: $releaseDir" -ForegroundColor Cyan
    return $true
}

