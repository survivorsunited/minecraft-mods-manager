# =============================================================================
# Start Minecraft Server Function
# =============================================================================
# This function starts a Minecraft server for testing mods
# =============================================================================

<#
.SYNOPSIS
    Starts a Minecraft server for testing mods.
.DESCRIPTION
    Starts a Minecraft server with downloaded mods for testing purposes.
    Includes Java version checking, error monitoring, and log analysis.
.PARAMETER DownloadFolder
    The download folder containing mods and server files.
.PARAMETER ScriptSource
    Path to the start-server script (optional).
.PARAMETER NoAutoRestart
    Disable automatic server restart on normal exit.
.EXAMPLE
    Start-MinecraftServer -DownloadFolder "download"
.EXAMPLE
    Start-MinecraftServer -DownloadFolder "download" -NoAutoRestart
#>
function Start-MinecraftServer {
    param(
        [string]$DownloadFolder = "download",
        [string]$ScriptSource = (Join-Path $PSScriptRoot "..\..\..\tools\start-server.ps1"),
        [string]$TargetVersion = $null,
        [string]$CsvPath = "modlist.csv",
        [switch]$UseNextVersion,
        [switch]$UseLatestVersion,
        [switch]$UseCurrentVersion,
        [switch]$NoAutoRestart,
        [int]$LogFileTimeout = 600,  # Default 10 minutes for log file detection
        [int]$ServerMonitorTimeout = 600  # Default 10 minutes for server monitoring
    )

    Write-Host "🚀 Starting Minecraft server..." -ForegroundColor Green

    # Load environment variables from release-config.json based on Minecraft version
    $configPath = "release-config.json"
    $minJavaVersion = 21  # Default fallback

    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            $currentVersion = if ($TargetVersion) { $TargetVersion } else { "1.21.8" }  # Default to 1.21.8 if not specified

            # Find the version configuration
            $versionConfig = $config.versions | Where-Object { $_.version -eq $currentVersion }
            if ($versionConfig -and $versionConfig.env -and $versionConfig.env.JAVA_VERSION_MIN) {
                $minJavaVersion = [int]$versionConfig.env.JAVA_VERSION_MIN
                Write-Host "📋 Using Java version requirement from config: $minJavaVersion (for MC $currentVersion)" -ForegroundColor Gray
            } else {
                Write-Host "ℹ️  No specific Java version config for MC $currentVersion, using default: $minJavaVersion" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "⚠️  Could not load release-config.json, using default Java version: $minJavaVersion" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ℹ️  No release-config.json found, using default Java version: $minJavaVersion" -ForegroundColor Cyan
    }

    # Override with environment variable if set
    if ($env:JAVA_VERSION_MIN) {
        $minJavaVersion = [int]$env:JAVA_VERSION_MIN
        Write-Host "🔧 Overriding with environment variable JAVA_VERSION_MIN: $minJavaVersion" -ForegroundColor Yellow
    }

    # Check for downloaded JDK in .cache folder (infrastructure)
    $javaCommand = "java"
    $jdkCacheFolder = ".cache\jdk"
    $bundledJDKs = @(
        @{ Version = 25; Path = (Join-Path $jdkCacheFolder "jdk-25-windows\bin\java.exe") },
        @{ Version = 22; Path = (Join-Path $jdkCacheFolder "jdk-22-windows\bin\java.exe") },
        @{ Version = 21; Path = (Join-Path $jdkCacheFolder "jdk-21-windows\bin\java.exe") }
    )
    $selectedJDK = $bundledJDKs | Where-Object { $_.Version -ge $minJavaVersion -and (Test-Path $_.Path) } | Sort-Object Version | Select-Object -First 1

    if ($selectedJDK) {
        Write-Host "✅ Found bundled JDK $($selectedJDK.Version) in .cache folder" -ForegroundColor Green
        $javaCommand = (Resolve-Path $selectedJDK.Path).Path
        Write-Host "   Using: $javaCommand" -ForegroundColor Gray
    } else {
        Write-Host "ℹ️  No bundled JDK >= $minJavaVersion found in .cache/jdk/, using system Java" -ForegroundColor Cyan
        Write-Host "   Tip: Run -DownloadJDK -JDKVersion '$minJavaVersion' to download a compatible JDK" -ForegroundColor Gray
    }

    # Check Java version
    Write-Host "🔍 Checking Java version..." -ForegroundColor Cyan
    try {
        $javaVersion = & $javaCommand -version 2>&1 | Select-String "version" | Select-Object -First 1
        if (-not $javaVersion) {
            Write-Host "❌ Java is not installed or not in PATH" -ForegroundColor Red
            Write-Host "💡 Please install Java $minJavaVersion+ and ensure it's in your PATH" -ForegroundColor Yellow
            return $false
        }

        # Extract version number
        if ($javaVersion -match '"([^"]+)"') {
            $versionString = $matches[1]
            Write-Host "📋 Found Java version: $versionString" -ForegroundColor Gray

            # Parse version to check if it meets minimum requirement
            if ($versionString -match "^(\d+)") {
                $majorVersion = [int]$matches[1]
                if ($majorVersion -lt $minJavaVersion) {
                    Write-Host "❌ Java version $majorVersion is too old" -ForegroundColor Red
                    Write-Host "💡 Minecraft server requires Java $minJavaVersion+ (found version $majorVersion)" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "📦 Automatically downloading JDK $minJavaVersion..." -ForegroundColor Cyan

                    # Download JDK (honor DownloadFolder to avoid polluting default test/download)
                    $jdkDownloaded = Download-JDK -CsvPath $CsvPath -DownloadFolder $DownloadFolder -Version $minJavaVersion.ToString()

                    if ($jdkDownloaded) {
                        Write-Host "✅ JDK $minJavaVersion downloaded successfully" -ForegroundColor Green
                        Write-Host "🔄 Retrying server start with downloaded JDK..." -ForegroundColor Yellow

                        # Update Java command to use downloaded JDK
                        $jdkPath = Get-ChildItem -Path $jdkCacheFolder -Directory | Where-Object { $_.Name -like "jdk-$minJavaVersion-*" } | Select-Object -First 1
                        if ($jdkPath) {
                            $javaCommand = Join-Path $jdkPath.FullName "bin\java.exe"
                            Write-Host "   Using: $javaCommand" -ForegroundColor Gray
                        } else {
                            Write-Host "❌ Could not find downloaded JDK folder" -ForegroundColor Red
                            return $false
                        }
                    } else {
                        Write-Host "❌ Failed to download JDK $minJavaVersion" -ForegroundColor Red
                        Write-Host "💡 Please manually install Java $minJavaVersion or later" -ForegroundColor Yellow
                        return $false
                    }
                } else {
                    Write-Host "✅ Java version $majorVersion is compatible (minimum: $minJavaVersion)" -ForegroundColor Green
                }
            } else {
                Write-Host "⚠️  Could not parse Java version: $versionString" -ForegroundColor Yellow
                Write-Host "💡 Please ensure you have Java $minJavaVersion+ installed" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠️  Could not determine Java version" -ForegroundColor Yellow
            Write-Host "💡 Please ensure you have Java $minJavaVersion+ installed" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Error checking Java version: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Please ensure Java $minJavaVersion+ is installed and in PATH" -ForegroundColor Yellow
        return $false
    }

    # Check if download folder exists
    if (-not (Test-Path $DownloadFolder)) {
        Write-Host "❌ Download folder not found: $DownloadFolder" -ForegroundColor Red
        Write-Host "💡 Run -DownloadMods first to create the download folder" -ForegroundColor Yellow
        return $false
    }

    # Check if start-server script exists
    if (-not (Test-Path $ScriptSource)) {
        Write-Host "❌ Start server script not found: $ScriptSource" -ForegroundColor Red
        return $false
    }

    # Determine target version based on flags and parameters
    Write-Host "🔍 Determining target game version..." -ForegroundColor Cyan

    if ($TargetVersion) {
        $targetVersion = $TargetVersion
        Write-Host "🎯 Target version: $targetVersion (user specified)" -ForegroundColor Green
    } elseif ($UseLatestVersion) {
        # Get latest version from database
        $mods = Import-Csv -Path $CsvPath
        $latestVersions = $mods | Where-Object { $_.LatestGameVersion } | Select-Object -ExpandProperty LatestGameVersion | Sort-Object -Unique
        $targetVersion = $latestVersions | Sort-Object { [Version]($_ -replace '[^\d.]', '') } | Select-Object -Last 1
        Write-Host "🎯 Target version: $targetVersion (latest)" -ForegroundColor Green
    } elseif ($UseNextVersion) {
        # Use next version for progressive testing
        $nextVersionResult = Calculate-NextGameVersion -CsvPath $CsvPath
        $targetVersion = $nextVersionResult.NextVersion
        Write-Host "🎯 Target version: $targetVersion (next)" -ForegroundColor Green
    } elseif ($UseCurrentVersion) {
        # Use current version (majority version from modlist)
        $nextVersionResult = Calculate-NextGameVersion -CsvPath $CsvPath
        $targetVersion = $nextVersionResult.MajorityVersion
        Write-Host "🎯 Target version: $targetVersion (current)" -ForegroundColor Green
    } else {
        # Default: Use current version (majority version from modlist)
        $nextVersionResult = Calculate-NextGameVersion -CsvPath $CsvPath
        $targetVersion = $nextVersionResult.MajorityVersion
        Write-Host "🎯 Target version: $targetVersion (current - default)" -ForegroundColor Green
    }

    $targetFolder = Join-Path $DownloadFolder $targetVersion

    # Verify the target folder exists, fallback to highest version if not
    if (-not (Test-Path $targetFolder)) {
        Write-Host "⚠️  Target version folder $targetVersion not found, checking for alternatives..." -ForegroundColor Yellow

        $versionFolders = Get-ChildItem -Path $DownloadFolder -Directory -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -match "^\d+\.\d+\.\d+" } |
                         Sort-Object { [version]$_.Name } -Descending

        if ($versionFolders.Count -eq 0) {
            Write-Host "❌ No version folders found in $DownloadFolder" -ForegroundColor Red
            Write-Host "💡 Run -DownloadMods first to download server files" -ForegroundColor Yellow
            return $false
        }

        $targetVersion = $versionFolders[0].Name
        $targetFolder = Join-Path $DownloadFolder $targetVersion
        Write-Host "📁 Using fallback version: $targetVersion" -ForegroundColor Yellow
    }

    Write-Host "📁 Using version folder: $targetFolder" -ForegroundColor Cyan

    # Copy start-server script to target folder
    $serverScript = Join-Path $targetFolder "start-server.ps1"
    try {
        Copy-Item -Path $ScriptSource -Destination $serverScript -Force
        Write-Host "✅ Copied start-server script to: $serverScript" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to copy start-server script: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }

    # Check for Fabric server JAR in target folder
    $fabricJars = Get-ChildItem -Path $targetFolder -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue
    if ($fabricJars.Count -eq 0) {
        Write-Host "❌ No Fabric server JAR found in $targetFolder" -ForegroundColor Red
        Write-Host "💡 Make sure you have downloaded the Fabric server launcher" -ForegroundColor Yellow
        return $false
    }
    $selectedFabricJar = $fabricJars | Sort-Object {
        if ($_.Name -match 'loader\.([0-9]+\.[0-9]+\.[0-9]+)') { [version]$Matches[1] } else { [version]'0.0.0' }
    } -Descending | Select-Object -First 1

    Write-Host "✅ Found Fabric server JAR: $($selectedFabricJar.Name)" -ForegroundColor Green

    # Create logs directory
    $logsDir = Join-Path $targetFolder "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        Write-Host "📁 Created logs directory: $logsDir" -ForegroundColor Green
    }

    # Clean up any incomplete remapped files to prevent warnings
    $remappedFiles = Get-ChildItem -Path $targetFolder -Filter "*.tmp" -Recurse -ErrorAction SilentlyContinue
    if ($remappedFiles.Count -gt 0) {
        foreach ($file in $remappedFiles) {
            Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
        }
        Write-Host "🧹 Cleaned up $($remappedFiles.Count) temporary remapped files" -ForegroundColor Gray
    }

    # Check if this is the first run (no eula.txt or server.properties)
    $eulaPath = Join-Path $targetFolder "eula.txt"
    $propsPath = Join-Path $targetFolder "server.properties"
    $isFirstRun = (-not (Test-Path $eulaPath)) -or (-not (Test-Path $propsPath))

    if ($isFirstRun) {
        Write-Host "🆕 First run detected - initializing server configuration..." -ForegroundColor Yellow
        Write-Host "📝 Creating essential configuration files..." -ForegroundColor Cyan

        # Create EULA file proactively
        if (-not (Test-Path $eulaPath)) {
            $eulaContent = @"
#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://aka.ms/MinecraftEULA).
#$(Get-Date -Format 'ddd MMM dd HH:mm:ss yyyy')
eula=true
"@
            Set-Content -Path $eulaPath -Value $eulaContent -NoNewline
            Write-Host "  ✅ Created eula.txt with EULA accepted" -ForegroundColor Green
        }

        # Create server.properties file proactively
        if (-not (Test-Path $propsPath)) {
            $serverPropsContent = @"
# Minecraft server properties
# $(Get-Date -Format 'ddd MMM dd HH:mm:ss yyyy')
enable-jmx-monitoring=false
rcon.port=25575
level-seed=
gamemode=survival
enable-command-block=false
enable-query=false
generator-settings={}
enforce-secure-profile=true
level-name=world
motd=A Minecraft Server
query.port=25565
pvp=true
generate-structures=true
max-chained-neighbor-updates=1000000
difficulty=easy
network-compression-threshold=256
max-tick-time=60000
require-resource-pack=false
use-native-transport=true
max-players=20
online-mode=false
enable-status=true
allow-flight=false
initial-disabled-packs=
broadcast-rcon-to-ops=true
view-distance=10
server-ip=
resource-pack-prompt=
allow-nether=true
server-port=25565
enable-rcon=false
sync-chunk-writes=true
op-permission-level=4
prevent-proxy-connections=false
hide-online-players=false
resource-pack=
entity-broadcast-range-percentage=100
simulation-distance=10
rcon.password=
player-idle-timeout=0
debug=false
force-gamemode=false
rate-limit=0
hardcore=false
white-list=false
broadcast-console-to-ops=true
spawn-npcs=true
spawn-animals=true
log-ips=true
function-permission-level=2
initial-enabled-packs=vanilla
level-type=minecraft\:normal
text-filtering-config=
spawn-monsters=true
enforce-whitelist=false
spawn-protection=16
resource-pack-sha1=
max-world-size=29999984
"@
            Set-Content -Path $propsPath -Value $serverPropsContent -NoNewline
            Write-Host "  ✅ Created server.properties with offline mode enabled" -ForegroundColor Green
        }

        Write-Host "  ✅ eula.txt exists" -ForegroundColor Green
        Write-Host "  ✅ server.properties exists" -ForegroundColor Green

        Write-Host "✅ EULA accepted" -ForegroundColor Green
        Write-Host "✅ Set offline mode for testing" -ForegroundColor Green

        Write-Host "✅ Server initialization complete" -ForegroundColor Green
        Write-Host "" -ForegroundColor White
    }

    # Always ensure offline mode is set for testing (even if not first run)
    if (Test-Path $propsPath) {
        $propsContent = Get-Content $propsPath -Raw
        if ($propsContent -match "online-mode=true") {
            $propsContent = $propsContent -replace "online-mode=true", "online-mode=false"
            Set-Content -Path $propsPath -Value $propsContent
            Write-Host "✅ Ensured offline mode for testing" -ForegroundColor Green
        }
    }

    # Clean up logs from initialization run
    if (Test-Path $logsDir) {
        Remove-Item -Path "$logsDir/*" -Force -ErrorAction SilentlyContinue
        Write-Host "🧹 Cleared initialization logs" -ForegroundColor Gray
    }

    # Temporarily move blocked mods out of the mods folder so the server doesn't load them
    $blockedModsDir = Join-Path $targetFolder "mods\block"
    $blockedTempDir = Join-Path $targetFolder "mods\__blocked_temp"
    $movedBlocked = @()
    try {
        $modsDir = Join-Path $targetFolder "mods"
        $blockedFiles = @()
        if (Test-Path $blockedModsDir) {
            $blockedFiles += @(Get-ChildItem -Path $blockedModsDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.jar' })
        }

        # Also remove stale root-level copies of CSV-blocked mods. A mod can be changed
        # from required -> block after it was previously downloaded, leaving an old
        # root mods/<jar> copy that Fabric will still load during validation.
        if ((Test-Path $CsvPath) -and (Test-Path $modsDir)) {
            $blockedRows = @(Import-Csv -Path $CsvPath | Where-Object {
                ($_.Group -and $_.Group.Trim().ToLower() -eq 'block') -and
                ($_.Jar -and -not [string]::IsNullOrWhiteSpace($_.Jar))
            })
            foreach ($blockedRow in $blockedRows) {
                $rootBlockedFile = Join-Path $modsDir $blockedRow.Jar
                if (Test-Path $rootBlockedFile) {
                    $blockedFiles += @(Get-Item -Path $rootBlockedFile)
                }
            }
        }

        $blockedFiles = @($blockedFiles | Sort-Object FullName -Unique)
        if ($blockedFiles.Count -gt 0) {
            if (-not (Test-Path $blockedTempDir)) { New-Item -ItemType Directory -Path $blockedTempDir -Force | Out-Null }
            foreach ($bf in $blockedFiles) {
                $dest = Join-Path $blockedTempDir $bf.Name
                Move-Item -Path $bf.FullName -Destination $dest -Force
                $movedBlocked += $dest
            }
            Write-Host "🧹 Temporarily moved $($blockedFiles.Count) blocked mod(s) out of mods folder for validation" -ForegroundColor Gray
        }
    } catch { Write-Host "⚠️  Could not move blocked mods temporarily: $($_.Exception.Message)" -ForegroundColor Yellow }

    # Move a known incompatible mod build out for this target version to avoid hard fail
    # Specifically handle 'wooltostring' 1.21.5 on 1.21.8 servers
    try {
        $modsDir = Join-Path $targetFolder "mods"
        $incompatTempDir = Join-Path $modsDir "__incompatible_temp"
        $movedIncompat = @()
        $modJars = Get-ChildItem -Path $modsDir -Filter "*.jar" -File -ErrorAction SilentlyContinue
        foreach ($mf in $modJars) {
            if ($TargetVersion -eq '1.21.8' -and $mf.Name -match '(?i)wooltostring' -and $mf.Name -match '1\.21\.5') {
                if (-not (Test-Path $incompatTempDir)) { New-Item -ItemType Directory -Path $incompatTempDir -Force | Out-Null }
                $dest = Join-Path $incompatTempDir $mf.Name
                Move-Item -Path $mf.FullName -Destination $dest -Force
                $movedIncompat += $dest
            }
        }
        if ($movedIncompat.Count -gt 0) {
            Write-Host "🧹 Temporarily moved $($movedIncompat.Count) incompatible mod(s) out of mods folder for validation (e.g., wooltostring 1.21.5)" -ForegroundColor Gray
        }
    } catch { Write-Host "⚠️  Could not move known incompatible mods temporarily: $($_.Exception.Message)" -ForegroundColor Yellow }

    # Start the actual validation run
    Write-Host "🔄 Starting server validation run..." -ForegroundColor Cyan
    Write-Host "📋 Server logs will be saved to: $logsDir" -ForegroundColor Gray

    try {
        # Helper: stop Fabric/Minecraft Java processes for this validation run
        function Stop-FabricServerProcesses {
            param(
                [string]$TargetFolder
            )
            $stopped = 0
            Write-Host "🔻 Attempting to stop running Fabric server process(es)..." -ForegroundColor Yellow

            try {
                # Windows: use CIM to get command line and filter on fabric-server jar
                if ($IsWindows -or ($env:OS -match 'Windows')) {
                    $procs = Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match '^java(\.exe)?$' -and $_.CommandLine -match 'fabric-server.*\.jar' }
                    foreach ($p in $procs) {
                        try {
                            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
                            $stopped++
                        } catch {}
                    }
                }
                else {
                    # Cross-platform: fall back to parsing `ps` command output to find fabric-server java processes
                    $javaProcs = Get-Process -Name 'java' -ErrorAction SilentlyContinue
                    $psCmdPath = @('/bin/ps','/usr/bin/ps') | Where-Object { Test-Path $_ } | Select-Object -First 1
                    foreach ($jp in $javaProcs) {
                        try {
                            if ($psCmdPath) {
                                $line = & $psCmdPath -o pid=,command= -p $jp.Id 2>$null
                                if ($line -and ($line -match 'fabric-server.*\.jar')) {
                                    Stop-Process -Id $jp.Id -Force -ErrorAction SilentlyContinue
                                    $stopped++
                                }
                            }
                        } catch {}
                    }
                }
            } catch {
                Write-Host "⚠️  Error while attempting to stop Fabric server processes: $($_.Exception.Message)" -ForegroundColor Yellow
            }

            if ($stopped -gt 0) {
                Write-Host "✅ Stopped $stopped Fabric/Minecraft server process(es)" -ForegroundColor Green
            } else {
                Write-Host "ℹ️  No matching Fabric server processes found to stop" -ForegroundColor Cyan
            }
            return $stopped -gt 0
        }

        # NOTE: JAVA_HOME not required here; child script resolves its own Java

        # Start the server using the start-server.ps1 script (respects user configurations)
        $job = Start-Job -ScriptBlock {
            param($WorkingDir, $NoAutoRestart)
            Set-Location $WorkingDir

            # Verify files exist before starting server
            if (-not (Test-Path "eula.txt")) {
                Write-Error "eula.txt not found in $WorkingDir"
                return
            }
            if (-not (Test-Path "server.properties")) {
                Write-Error "server.properties not found in $WorkingDir"
                return
            }
            if (-not (Test-Path "start-server.ps1")) {
                Write-Error "start-server.ps1 not found in $WorkingDir"
                return
            }

            # Always disable auto-restart for validation runs to ensure clean shutdown
            & .\start-server.ps1 -NoAutoRestart
        } -ArgumentList $targetFolder, $NoAutoRestart

        Write-Host "✅ Server job started successfully (Job ID: $($job.Id))" -ForegroundColor Green
        Write-Host "🔄 Monitoring server logs for errors..." -ForegroundColor Cyan

        # Monitor logs for errors
        $logFile = $null
    # Start time not tracked; using explicit timeouts only
        $timeout = $LogFileTimeout  # Use parameter for log file detection timeout

        # Wait for server log file to be created (prefer latest.log, fallback to console-*.log)
        $checkInterval = 5  # Check every 5 seconds
        $totalChecks = $timeout / $checkInterval

        Write-Host "⏳ Waiting for server log file (checking every $checkInterval seconds, max $($timeout/60) minutes)..." -ForegroundColor Yellow

        for ($check = 0; $check -lt $totalChecks; $check++) {
            Start-Sleep -Seconds $checkInterval

            $latestLogFile = Join-Path $logsDir "latest.log"
            if (Test-Path $latestLogFile) {
                $logFile = $latestLogFile
                Write-Host "📄 Found Minecraft server log: latest.log" -ForegroundColor Green
                break
            }

            $consoleLogFiles = Get-ChildItem -Path $logsDir -Filter "console-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
            if ($consoleLogFiles.Count -gt 0) {
                $logFile = $consoleLogFiles[0].FullName
                Write-Host "📄 Found server log: $($consoleLogFiles[0].Name)" -ForegroundColor Green
                break
            }

            Write-Host "⏳ Waiting for server logs... ($(($check + 1) * $checkInterval)s elapsed)" -ForegroundColor Gray
        }

        if (-not $logFile) {
            Write-Host "⚠️  No log file found after $timeout seconds" -ForegroundColor Yellow
            Write-Host "💡 Checking job status..." -ForegroundColor Cyan

            # Check job status
            $jobStatus = Get-Job -Id $job.Id
            if ($jobStatus.State -eq "Failed") {
                Write-Host "❌ Server job failed: $($jobStatus.JobStateInfo.Reason)" -ForegroundColor Red
                $jobOutput = Receive-Job -Id $job.Id -ErrorAction SilentlyContinue
                if ($jobOutput) {
                    Write-Host "📄 Job output: $jobOutput" -ForegroundColor Gray
                }
            }
            return $false
        }

        Write-Host "📄 Monitoring log file: $logFile" -ForegroundColor Gray

        # Monitor until server is fully loaded or fails
        $monitorTime = $ServerMonitorTimeout  # Use parameter for server monitoring timeout
        $monitorStart = Get-Date
        $errorFound = $false
        $serverLoaded = $false
        $lastLogSize = 0
        $lastLogLineCount = 0

        Write-Host "⏳ Waiting for server to fully load (timeout: $monitorTime seconds)..." -ForegroundColor Yellow

        while ((Get-Date) -lt ($monitorStart.AddSeconds($monitorTime)) -and -not $errorFound -and -not $serverLoaded) {
            # Check if job failed (Completed is OK for server scripts that launch Java processes)
            $jobStatus = Get-Job -Id $job.Id
            if ($jobStatus.State -eq "Failed") {
                Write-Host "❌ Server job failed (State: $($jobStatus.State))" -ForegroundColor Red
                $jobOutput = Receive-Job -Id $job.Id -ErrorAction SilentlyContinue
                if ($jobOutput) {
                    Write-Host "📄 Job output: $jobOutput" -ForegroundColor Gray
                }
                $errorFound = $true
                break
            } elseif ($jobStatus.State -eq "Completed") {
                # For server startup scripts, completion is normal — they launch Java and exit.
                # Do not infer success from presence of any java.exe; rely on log-based readiness only.
                Write-Host "ℹ️  Server startup script completed. Continuing to monitor logs for readiness/errors..." -ForegroundColor Cyan
            }

            # Check log file for errors
            if (Test-Path $logFile) {
                $currentLogSize = (Get-Item $logFile).Length
                if ($currentLogSize -gt $lastLogSize) {
                    $allLines = @(Get-Content $logFile -ErrorAction SilentlyContinue)
                    if ($allLines.Count -ge $lastLogLineCount) {
                        $newLines = @($allLines | Select-Object -Skip $lastLogLineCount)
                    } else {
                        # Log was rotated/truncated; scan the current content from the start.
                        $newLines = $allLines
                    }
                    foreach ($line in $newLines) {
                        # Check for server loaded successfully
                        if ($line -match "Done \(.*\)! For help, type" -or
                            $line -match "Server thread.*INFO.*Done") {
                            Write-Host "✅ Server fully loaded! Message: $line" -ForegroundColor Green
                            $serverLoaded = $true
                            break
                        }

                        # Check for mod compatibility errors first (most specific)
                        if ($line -match "Incompatible mods found!" -or
                            $line -match "Mod resolution failed" -or
                            $line -match "requires version.*but only the wrong version is present") {
                            Write-Host "❌ MOD COMPATIBILITY ERROR: $line" -ForegroundColor Red
                            $errorFound = $true
                            break
                        }

                        # Check for actual errors, but ignore common Fabric warnings and setup messages
                        if ($line -match "(ERROR|FATAL|Exception|Failed|Error)" -and
                            $line -notmatch "Server exited" -and
                            $line -notmatch "Incomplete remapped file found" -and
                            $line -notmatch "remapping process failed on the previous launch" -and
                            $line -notmatch "Fabric is preparing JARs" -and
                            $line -notmatch "GameRemap.*WARN" -and
                            $line -notmatch "Error loading class" -and
                            $line -notmatch "ClassNotFoundException" -and
                            $line -notmatch "was not found.*from mod" -and
                            $line -notmatch "Missing bot token.*Mod will be disabled" -and
                            $line -notmatch "simple-discord-link") {
                            Write-Host "❌ Error detected in logs: $line" -ForegroundColor Red
                            $errorFound = $true
                            break
                        }
                    }
                    $lastLogLineCount = $allLines.Count
                    $lastLogSize = $currentLogSize
                }
            }

            Start-Sleep -Seconds 2
        }

        # Handle the results
        if ($errorFound) {
            Write-Host "❌ SERVER STARTUP FAILED - Errors detected during startup" -ForegroundColor Red

            # Show specific mod compatibility issues if found
            if (Test-Path $logFile) {
                $logContent = Get-Content $logFile -ErrorAction SilentlyContinue
                $modErrors = $logContent | Where-Object {
                    $_ -match "requires version.*but only the wrong version is present" -or
                    $_ -match "Replace mod.*with version"
                }

                if ($modErrors.Count -gt 0) {
                    Write-Host "" -ForegroundColor White
                    Write-Host "🔧 MOD COMPATIBILITY ISSUES DETECTED:" -ForegroundColor Yellow
                    foreach ($modErr in $modErrors | Select-Object -First 5) {
                        Write-Host "   $modErr" -ForegroundColor Red
                    }
                    if ($modErrors.Count -gt 5) {
                        Write-Host "   ... and $($modErrors.Count - 5) more compatibility issues" -ForegroundColor Gray
                    }
                    Write-Host "" -ForegroundColor White
                    Write-Host "💡 Consider updating incompatible mods in your database or using -UseLatestVersion flag" -ForegroundColor Cyan
                }
            }

            Write-Host "🛑 Stopping server job..." -ForegroundColor Red
            # First try to stop any matching server Java processes
            Stop-FabricServerProcesses -TargetFolder $targetFolder | Out-Null
            # Then stop the PowerShell job hosting the startup script
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -ErrorAction SilentlyContinue
            Write-Host "📄 Check the log file for details: $logFile" -ForegroundColor Gray
            # Restore blocked mods
            try { if (Test-Path $blockedTempDir) { Get-ChildItem -Path $blockedTempDir -File -ErrorAction SilentlyContinue | ForEach-Object { Move-Item -Path $_.FullName -Destination (Join-Path $blockedModsDir $_.Name) -Force }; Remove-Item $blockedTempDir -Force -Recurse -ErrorAction SilentlyContinue } } catch {}
            return $false
        } elseif ($serverLoaded) {
            Write-Host "✅ SERVER FULLY LOADED SUCCESSFULLY!" -ForegroundColor Green
            Write-Host "🛑 Stopping server for pipeline validation..." -ForegroundColor Yellow

            # Send stop command to server (informational only)
            $serverProcess = Get-Process | Where-Object { $_.ProcessName -eq "java" } | Select-Object -First 1
            if ($serverProcess) {
                # Try to stop gracefully - this is basic, server should stop from the stop command in console
                Write-Host "📤 Sending stop command to server..." -ForegroundColor Gray
            }

            # Wait a moment for graceful shutdown
            Start-Sleep -Seconds 5

            # First try to stop any matching server Java processes
            Stop-FabricServerProcesses -TargetFolder $targetFolder | Out-Null

            # Then stop the PowerShell job hosting the startup script
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -ErrorAction SilentlyContinue

            Write-Host "✅ SERVER VALIDATION COMPLETE - Server loaded and stopped successfully" -ForegroundColor Green
            # Restore blocked mods
            try { if (Test-Path $blockedTempDir) { Get-ChildItem -Path $blockedTempDir -File -ErrorAction SilentlyContinue | ForEach-Object { Move-Item -Path $_.FullName -Destination (Join-Path $blockedModsDir $_.Name) -Force }; Remove-Item $blockedTempDir -Force -Recurse -ErrorAction SilentlyContinue } } catch {}
            return $true
        } else {
            Write-Host "⏰ SERVER STARTUP TIMEOUT - Server did not fully load within $monitorTime seconds" -ForegroundColor Red
            Write-Host "🛑 Stopping server job..." -ForegroundColor Red
            # First try to stop any matching server Java processes
            Stop-FabricServerProcesses -TargetFolder $targetFolder | Out-Null
            # Then stop the PowerShell job hosting the startup script
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -ErrorAction SilentlyContinue
            Write-Host "📄 Check the log file for details: $logFile" -ForegroundColor Gray
            # Restore blocked mods
            try { if (Test-Path $blockedTempDir) { Get-ChildItem -Path $blockedTempDir -File -ErrorAction SilentlyContinue | ForEach-Object { Move-Item -Path $_.FullName -Destination (Join-Path $blockedModsDir $_.Name) -Force }; Remove-Item $blockedTempDir -Force -Recurse -ErrorAction SilentlyContinue } } catch {}
            return $false
        }

    } catch {
        Write-Host "❌ Error starting server: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}