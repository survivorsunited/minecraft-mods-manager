# =============================================================================
# Server Files Download From Database Module
# =============================================================================
# This module handles downloading server, launcher, and installer files based on database entries.
# =============================================================================

<#
.SYNOPSIS
    Downloads server, launcher, and installer artifacts based on database entries.

.DESCRIPTION
    Reads server-related entries (Type in server|launcher|installer) from the CSV database
    and downloads the required artifacts into download/<version>/, placing installer artifacts
    under download/<version>/installer/.

.PARAMETER DownloadFolder
    The base download folder.

.PARAMETER ForceDownload
    Whether to force download even if files exist.

.PARAMETER CsvPath
    Path to the CSV database file.

.PARAMETER GameVersion
    Optional specific game version to filter entries.

.EXAMPLE
    Download-ServerFilesFromDatabase -DownloadFolder "download" -CsvPath "modlist.csv"

.NOTES
    - Resolves URLs dynamically when the CSV contains placeholders or API base URLs
    - Uses a simple cache in .cache/ to avoid repeated downloads
    - Returns the count of successful downloads
#>
function Download-ServerFilesFromDatabase {
    param(
        [string]$DownloadFolder = "download",
        [switch]$ForceDownload,
        [string]$CsvPath = "modlist.csv",
        [string]$GameVersion = ""
    )

    try {
        Write-Host "Downloading server files from database..." -ForegroundColor Yellow

        if (-not (Test-Path $DownloadFolder)) {
            New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
        }

        if (-not (Test-Path $CsvPath)) {
            Write-Host "❌ Database file not found: $CsvPath" -ForegroundColor Red
            return 0
        }

        $database = Import-Csv -Path $CsvPath
        $serverEntries = $database | Where-Object { $_.Type -in @('server','launcher','installer') }
        if ($GameVersion) {
            $serverEntries = $serverEntries | Where-Object { $_.CurrentGameVersion -eq $GameVersion -or $_.GameVersion -eq $GameVersion }
        }

        Write-Host "Found $($serverEntries.Count) server/launcher/installer entries in database" -ForegroundColor Cyan

        $downloadResults = @()
        $successCount = 0
        $errorCount = 0
        $skippedNoUrl = 0

        foreach ($entry in $serverEntries) {
            # Resolve URLs when missing or pointing to API base
            $needsResolution = (-not $entry.Url) -or $entry.Url -eq '' -or $entry.Url -eq 'https://meta.fabricmc.net/v2/versions'
            $resolvedUrl = $null
            $resolvedFilename = $null
            $resolvedUrls = @()
            $resolvedFilenames = @()

            if ($needsResolution -or $entry.Type -eq 'installer') {
                Write-Host "⏭️  $($entry.Name) ($(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })): No URL specified, attempting dynamic resolution..." -ForegroundColor Yellow
                $mcVer = if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion }

                if ($entry.Type -eq 'server' -and $entry.ID -match 'minecraft-server') {
                    try {
                        $manifestUrl = if ($env:MINECRAFT_SERVER_URL) { $env:MINECRAFT_SERVER_URL } else { 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json' }
                        $manifest = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
                        $versionInfo = $manifest.versions | Where-Object { $_.id -eq $mcVer } | Select-Object -First 1
                        if ($versionInfo) {
                            $versionDetails = Invoke-RestMethod -Uri $versionInfo.url -UseBasicParsing
                            if ($versionDetails.downloads.server.url) {
                                $resolvedUrl = $versionDetails.downloads.server.url
                                $resolvedFilename = "minecraft_server.$mcVer.jar"
                                Write-Host "  ✅ Resolved URL: $resolvedUrl" -ForegroundColor Green
                            }
                        }
                    } catch {
                        Write-Host "  ❌ Failed to resolve Minecraft server URL: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } elseif ($entry.Type -eq 'launcher' -and $entry.ID -match 'fabric-server-launcher') {
                    try {
                        $fabricUrl = if ($env:FABRIC_SERVER_URL) { $env:FABRIC_SERVER_URL } else { 'https://meta.fabricmc.net/v2/versions' }
                        $fabricVersions = Invoke-RestMethod -Uri $fabricUrl -UseBasicParsing
                        $latestLoader = $fabricVersions.loader | Select-Object -First 1
                        $latestInstaller = $fabricVersions.installer | Select-Object -First 1
                        if ($latestLoader -and $latestInstaller) {
                            $resolvedUrl = "https://meta.fabricmc.net/v2/versions/loader/$mcVer/$($latestLoader.version)/$($latestInstaller.version)/server/jar"
                            $resolvedFilename = "fabric-server-mc.$mcVer-loader.$($latestLoader.version)-launcher.$($latestInstaller.version).jar"
                            Write-Host "  ✅ Resolved Fabric launcher URL: $resolvedUrl" -ForegroundColor Green
                            Write-Host "  📦 Using loader $($latestLoader.version) and installer $($latestInstaller.version)" -ForegroundColor Gray
                        } else {
                            Write-Host "  ❌ Could not find Fabric loader or installer versions" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "  ❌ Failed to resolve Fabric launcher URL: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } elseif ($entry.Type -eq 'installer') {
                    try {
                        # Try to parse version from URL or ID/name fields
                        $ver = $null
                        if ($entry.Url -and ($entry.Url -match '/fabric-installer/([0-9.]+)/')) { $ver = $matches[1] }
                        if (-not $ver -and $entry.Jar -and ($entry.Jar -match 'fabric-installer-([0-9.]+)\.(jar|exe)$')) { $ver = $matches[1] }
                        if (-not $ver -and $entry.ID -and ($entry.ID -match 'fabric-installer-([0-9.]+)$')) { $ver = $matches[1] }
                        if (-not $ver -and $entry.Name -and ($entry.Name -match '([0-9.]+)')) { $ver = $matches[1] }

                        if (-not $ver) {
                            # Fallback to meta latest
                            $fabricUrl = if ($env:FABRIC_SERVER_URL) { $env:FABRIC_SERVER_URL } else { 'https://meta.fabricmc.net/v2/versions' }
                            $fabricVersions = Invoke-RestMethod -Uri $fabricUrl -UseBasicParsing
                            $latestInstaller = $fabricVersions.installer | Select-Object -First 1
                            if ($latestInstaller -and $latestInstaller.version) { $ver = $latestInstaller.version }
                        }

                        if ($ver) {
                            $mavenBase = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/$ver"
                            $resolvedUrls = @(
                                "$mavenBase/fabric-installer-$ver.jar",
                                "$mavenBase/fabric-installer-$ver.exe"
                            )
                            $resolvedFilenames = @(
                                "fabric-installer-$ver.jar",
                                "fabric-installer-$ver.exe"
                            )
                            Write-Host "  ✅ Resolved Fabric installer: version $ver (JAR and EXE)" -ForegroundColor Green
                        } else {
                            Write-Host "  ❌ Could not determine Fabric installer version" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "  ❌ Failed to resolve Fabric installer artifacts: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }

                if ($resolvedUrl) {
                    $entry | Add-Member -MemberType NoteProperty -Name 'ResolvedUrl' -Value $resolvedUrl -Force
                    $entry | Add-Member -MemberType NoteProperty -Name 'ResolvedFilename' -Value $resolvedFilename -Force
                    try { Update-ModUrlInDatabase -ModId $entry.ID -NewUrl $resolvedUrl -CsvPath $CsvPath | Out-Null } catch { }
                } elseif ($resolvedUrls -and $resolvedUrls.Count -gt 0) {
                    $entry | Add-Member -MemberType NoteProperty -Name 'ResolvedUrls' -Value $resolvedUrls -Force
                    $entry | Add-Member -MemberType NoteProperty -Name 'ResolvedFilenames' -Value $resolvedFilenames -Force
                } else {
                    $skippedNoUrl++
                    $downloadResults += [PSCustomObject]@{
                        Name = $entry.Name
                        Status = 'Skipped'
                        Version = $(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })
                        File = ''
                        Path = ''
                        Error = 'No URL available'
                    }
                    continue
                }
            }

            # Determine download URLs and target filenames
            $downloadUrls = @()
            $filenames = @()
            if ($entry.PSObject.Properties.Match('ResolvedUrls').Count -gt 0 -and $entry.PSObject.Properties.Match('ResolvedFilenames').Count -gt 0) {
                $downloadUrls = $entry.ResolvedUrls
                $filenames = $entry.ResolvedFilenames
            } else {
                $downloadUrl = if ($entry.PSObject.Properties.Match('ResolvedUrl').Count -gt 0) { $entry.ResolvedUrl } else { $entry.Url }
                $filename = if ($entry.PSObject.Properties.Match('ResolvedFilename').Count -gt 0) { $entry.ResolvedFilename } elseif ($entry.Jar) { $entry.Jar } else {
                    if ($entry.Type -eq 'server') {
                        "minecraft_server.$(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion }).jar"
                    } elseif ($entry.Type -eq 'launcher') {
                        "fabric-server-launcher.$(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion }).jar"
                    } else {
                        'fabric-installer-latest.jar'
                    }
                }
                $downloadUrls = @($downloadUrl)
                $filenames = @($filename)
            }

            # Create version folder and target subfolder
            $verFolder = Join-Path $DownloadFolder $(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })
            if (-not (Test-Path $verFolder)) { New-Item -ItemType Directory -Path $verFolder -Force | Out-Null }
            $targetFolder = if ($entry.Type -eq 'installer') {
                $installerFolder = Join-Path $verFolder 'installer'
                if (-not (Test-Path $installerFolder)) { New-Item -ItemType Directory -Path $installerFolder -Force | Out-Null }
                $installerFolder
            } else { $verFolder }

            # Download artifacts
            for ($i = 0; $i -lt $downloadUrls.Count; $i++) {
                $downloadUrl = $downloadUrls[$i]
                $filename = $filenames[$i]
                $downloadPath = Join-Path $targetFolder $filename

                if ((Test-Path $downloadPath) -and -not $ForceDownload) {
                    Write-Host "⏭️  $($entry.Name) ($(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })): Already exists" -ForegroundColor Yellow
                    $downloadResults += [PSCustomObject]@{
                        Name = $entry.Name
                        Status = 'Skipped'
                        Version = $(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })
                        File = $filename
                        Path = $downloadPath
                        Error = 'File already exists'
                    }
                    continue
                }

                Write-Host "⬇️  $($entry.Name) ($(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })): Downloading $filename..." -ForegroundColor Cyan
                try {
                    $urlHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($downloadUrl))).Replace('-', '').Substring(0, 16)
                    $cacheFolder = if ($entry.Type -eq 'server') { '.cache\mojang' } else { '.cache\fabric' }
                    if (-not (Test-Path $cacheFolder)) { New-Item -ItemType Directory -Path $cacheFolder -Force | Out-Null }
                    $cachePath = Join-Path $cacheFolder ("$urlHash-$filename")

                    if (-not (Test-Path $cachePath)) {
                        Write-Host "  💾 Downloading to cache..." -ForegroundColor Gray
                        $null = Invoke-WebRequest -Uri $downloadUrl -OutFile $cachePath -UseBasicParsing
                    } else {
                        Write-Host "  ✓ Using cached file" -ForegroundColor Gray
                    }

                    Copy-Item -Path $cachePath -Destination $downloadPath -Force
                    if (Test-Path $downloadPath) {
                        $fileSize = (Get-Item $downloadPath).Length
                        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                        Write-Host "✅ $($entry.Name) ($(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })): Downloaded successfully ($fileSizeMB MB) -> $filename" -ForegroundColor Green
                        $downloadResults += [PSCustomObject]@{
                            Name = $entry.Name
                            Status = 'Success'
                            Version = $(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })
                            File = $filename
                            Path = $downloadPath
                            Size = "$fileSizeMB MB"
                            Error = $null
                        }
                        $successCount++
                    } else {
                        throw 'File was not created'
                    }
                } catch {
                    Write-Host "❌ $($entry.Name) ($(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })): Download failed - $($_.Exception.Message)" -ForegroundColor Red
                    if (Test-Path $downloadPath) { Remove-Item $downloadPath -Force }
                    $downloadResults += [PSCustomObject]@{
                        Name = $entry.Name
                        Status = 'Failed'
                        Version = $(if ($entry.CurrentGameVersion) { $entry.CurrentGameVersion } else { $entry.GameVersion })
                        File = $filename
                        Path = $downloadPath
                        Size = $null
                        Error = $_.Exception.Message
                    }
                    $errorCount++
                }
            }
        }

        # Summary
        Write-Host "" -ForegroundColor White
        Write-Host "Server Files Download Summary:" -ForegroundColor Yellow
        Write-Host "=============================" -ForegroundColor Yellow
        Write-Host "✅ Successfully downloaded: $successCount" -ForegroundColor Green
        Write-Host ("⏭️  Skipped (already exists): {0}" -f (($downloadResults | Where-Object { $_.Status -eq 'Skipped' -and $_.Error -eq 'File already exists' }).Count)) -ForegroundColor Yellow
        Write-Host "⏭️  Skipped (no URL): $skippedNoUrl" -ForegroundColor Yellow
        Write-Host "❌ Failed: $errorCount" -ForegroundColor Red

        if ($errorCount -gt 0) {
            Write-Host "" -ForegroundColor White
            Write-Host "Failed downloads:" -ForegroundColor Red
            foreach ($r in $downloadResults | Where-Object { $_.Status -eq 'Failed' }) {
                Write-Host "  ❌ $($r.Name): $($r.Error)" -ForegroundColor Red
            }
        }

        return $successCount
    } catch {
        Write-Error ("Failed to download server files: {0}" -f $_.Exception.Message)
        return 0
    }
}

# Function is available for dot-sourcing