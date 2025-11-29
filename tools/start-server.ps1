# Minecraft Fabric Server Startup Script
# Automatically finds and launches the Fabric server JAR file

param(
    [switch]$NoAutoRestart,  # Disable automatic server restart on normal exit
    [string]$JdkCacheDir = ".cache\jdk"  # Bundled JDK directory (relative or absolute). Empty string disables bundled search.
)

# Configuration: prefer bundled JDK in .cache folder; fallback to system Java if not available
$JavaExe = $null

 

# No version gating: pick bundled or PATH java if available (no explicit path parameter)

# Navigate up to project root from server folder
# Server folder is typically: project/download/version/ or project/test/test-output/testname/download/version/
$currentPath = $PSScriptRoot
$ProjectRoot = $currentPath

# Keep going up until we find the project root (contains ModManager.ps1)
while ($ProjectRoot -and -not (Test-Path (Join-Path $ProjectRoot "ModManager.ps1"))) {
    $parentPath = Split-Path $ProjectRoot -Parent
    if ($parentPath -eq $ProjectRoot) {
        # Reached root of filesystem, stop
        break
    }
    $ProjectRoot = $parentPath
}

# Resolve JDK cache folder: if relative, anchor to project root; if absolute, use as-is
$UseBundled = $true
if (-not $JdkCacheDir -or $JdkCacheDir.Trim() -eq "") {
    $UseBundled = $false
} elseif ([System.IO.Path]::IsPathRooted($JdkCacheDir)) {
    $JdkCacheFolder = $JdkCacheDir
} else {
    $JdkCacheFolder = Join-Path -Path $ProjectRoot -ChildPath $JdkCacheDir
}

if ($UseBundled) {
    Write-Host "🔍 Looking for bundled JDK in: $JdkCacheFolder" -ForegroundColor Cyan
} else {
    Write-Host "🔍 Bundled JDK search disabled (JdkCacheDir empty)." -ForegroundColor Cyan
}

if (-not $JavaExe -and $UseBundled -and (Test-Path $JdkCacheFolder)) {
    # Find JDK folders (prefer JDK 22 > 21, sorted descending by name)
    $jdkFolders = Get-ChildItem $JdkCacheFolder -Directory | 
        Where-Object { $_.Name -match "jdk-\d+" } | 
        Sort-Object Name -Descending
    
    foreach ($jdkFolder in $jdkFolders) {
        # Cross-platform Java executable detection
        $javaExt = if ($IsWindows -or $env:OS -match "Windows") { "java.exe" } else { "java" }
        $javaPath = Join-Path $jdkFolder.FullName "bin\$javaExt"

        if (Test-Path $javaPath) {
            # Use first valid bundled JDK; version is informational only
            try {
                $verLine = & $javaPath -version 2>&1 | Select-String "version" | Select-Object -First 1
                $infoMajor = $null
                if ($verLine -and $verLine.ToString() -match '"(\d+)') { $infoMajor = [int]$Matches[1] }
                $JavaExe = $javaPath
                if ($infoMajor) {
                    Write-Host "✅ Using bundled JDK: $($jdkFolder.Name) (major: $infoMajor)" -ForegroundColor Green
                } else {
                    Write-Host "✅ Using bundled JDK: $($jdkFolder.Name)" -ForegroundColor Green
                }
                Write-Host "   Location: $JavaExe" -ForegroundColor Gray
                break
            } catch {
                # Even if version check fails, we can still try to use it
                $JavaExe = $javaPath
                Write-Host "✅ Using bundled JDK: $($jdkFolder.Name)" -ForegroundColor Green
                Write-Host "   Location: $JavaExe" -ForegroundColor Gray
                break
            }
        }
    }
}

if (-not $JavaExe) {
    # Try system Java from PATH as a fallback
    Write-Host "ℹ️  No bundled JDK found. Attempting system Java from PATH..." -ForegroundColor Yellow
    try {
        $javaCheck = & java -version 2>&1 | Select-String "version" | Select-Object -First 1
        if ($javaCheck) {
            # Parse major version for informational logging only
            $infoMajor = $null
            if ($javaCheck.ToString() -match '"(\d+)') { $infoMajor = [int]$Matches[1] }
            if ($infoMajor) {
                Write-Host "✅ System Java detected (major: $infoMajor)" -ForegroundColor Green
            } else {
                Write-Host "✅ System Java detected" -ForegroundColor Green
            }
            $JavaExe = "java"
            Write-Host "   Using system Java from PATH" -ForegroundColor Gray
        } else {
            Write-Host "❌ No system Java found in PATH" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Error invoking system Java: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# If still no Java, exit with guidance
if (-not $JavaExe) {
    Write-Host "" -ForegroundColor Red
    Write-Host "❌ ERROR: No suitable Java found (bundled or system)!" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "💡 Minecraft 1.21+ requires Java 21 or higher." -ForegroundColor Yellow
    Write-Host "💡 Options:" -ForegroundColor Yellow
    Write-Host "   - Download bundled JDK: .\ModManager.ps1 -DownloadJDK -JDKVersion 21" -ForegroundColor Gray
    Write-Host "   - Or install Java 21+ and ensure it is in PATH" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Yellow
    if ($UseBundled) {
        Write-Host "   Searched bundled path: $JdkCacheFolder" -ForegroundColor DarkGray
    } else {
        Write-Host "   Bundled JDK search was disabled (JdkCacheDir empty)." -ForegroundColor DarkGray
    }
    exit 1
}

# Java memory settings (configurable via environment variables)
$MinMemory = if ($env:MINECRAFT_MIN_MEMORY) { $env:MINECRAFT_MIN_MEMORY } else { "1G" }
$MaxMemory = if ($env:MINECRAFT_MAX_MEMORY) { $env:MINECRAFT_MAX_MEMORY } else { "4G" }

$JavaOpts = @(
  "-server"
  "-XX:+UseG1GC"
  "-XX:+ParallelRefProcEnabled"
  "-XX:MaxGCPauseMillis=200"
  "-XX:+UnlockExperimentalVMOptions"
  "-XX:+DisableExplicitGC"
  "-Xms$MinMemory"
  "-Xmx$MaxMemory"
  "--enable-native-access=ALL-UNNAMED"
)

$LogDir = "logs"

# Function to find Fabric server JAR
function Find-FabricServerJar {
    $fabricJars = Get-ChildItem -Path "." -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue
    
    if ($fabricJars.Count -eq 0) {
        Write-Host "❌ No Fabric server JAR found in current directory" -ForegroundColor Red
        Write-Host "Expected pattern: fabric-server*.jar" -ForegroundColor Yellow
        Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
        return $null
    }
    
    if ($fabricJars.Count -gt 1) {
        Write-Host "⚠️  Multiple Fabric server JARs found:" -ForegroundColor Yellow
        $fabricJars | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
        Write-Host "Using the first one: $($fabricJars[0].Name)" -ForegroundColor Yellow
    }
    
    $selectedJar = $fabricJars[0]
    Write-Host "✅ Found Fabric server JAR: $($selectedJar.Name)" -ForegroundColor Green
    return $selectedJar.Name
}

# Ensure logs folder exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
    Write-Host "📁 Created logs directory: $LogDir" -ForegroundColor Green
}

# Find the Fabric server JAR
$JarFile = Find-FabricServerJar
if (-not $JarFile) {
    Write-Host "`n💡 Make sure you have downloaded the Fabric server using ModManager.ps1" -ForegroundColor Cyan
    Write-Host "Example: .\ModManager.ps1 -AddMod -AddModName 'Fabric Server' -AddModType 'launcher' -AddModUrl '...'" -ForegroundColor Cyan
    exit 1
}

Write-Host "🚀 Starting Fabric server with JAR: $JarFile" -ForegroundColor Green
Write-Host "📊 Memory allocation: Min $MinMemory, Max $MaxMemory" -ForegroundColor Gray
Write-Host "📊 Java options: $($JavaOpts.Count) options configured" -ForegroundColor Gray

if ($NoAutoRestart) {
    Write-Host "⚠️  Auto-restart disabled. Server will not automatically restart after exit." -ForegroundColor Yellow
}

# Main server loop - continues running unless NoAutoRestart is set or error occurs
$continueRunning = $true
while ($continueRunning) {
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
    $LogFile = Join-Path $LogDir "console-$Timestamp.log"
    
    # Build the launch arguments array
    $LaunchArgs = $JavaOpts + @("-jar", $JarFile, "--nogui")

    # Write header to log file
    @"
=== Fabric Server Start: $Timestamp ===
=== JAR File: $JarFile ===
=== Java Executable: $JavaExe ===
=== Java Options: $($JavaOpts -join ' ') ===
=== Log File: $LogFile ===

"@ | Out-File -FilePath $LogFile -Encoding utf8

    Write-Host "`n🔄 Starting server... (Log: $LogFile)" -ForegroundColor Cyan
    
    # Set console encoding for proper character handling
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    # Run the server command directly (not via string command) with nogui flag
    # This ensures nogui is properly passed and prevents GUI error dialogs
    & $JavaExe @LaunchArgs 2>&1 | Tee-Object -FilePath $LogFile -Append
    
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 1) {
        # Read the log file to extract error information
        $logContent = Get-Content -Path $LogFile -Raw -ErrorAction SilentlyContinue
        
        # Look for the solution message
        $solutionPattern = "A potential solution has been determined, this may resolve your problem:(.*?)--- Server exited with code"
        $solutionMatch = [regex]::Match($logContent, $solutionPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        $terminateMsg = "`n--- Server exited with code $exitCode. Terminating due to error exit code. ---`n"
        Write-Host $terminateMsg -ForegroundColor Red
        $terminateMsg | Out-File -FilePath $LogFile -Encoding utf8 -Append
        
        if ($solutionMatch.Success) {
            $solutionText = $solutionMatch.Groups[1].Value.Trim()
            Write-Host "❌ SERVER ERROR DETECTED:" -ForegroundColor Red
            Write-Host "🔍 Potential Solution:" -ForegroundColor Yellow
            Write-Host $solutionText -ForegroundColor White
            Write-Host ""
            Write-Host "💡 This typically indicates that server mods are not compatible with the current version." -ForegroundColor Cyan
            Write-Host "   Check your mod versions and ensure they support the target Minecraft version." -ForegroundColor Cyan
        } else {
            Write-Host "❌ Server terminated due to exit code 1. Check logs for details." -ForegroundColor Red
        }
        
        exit 1
    } else {
        if ($NoAutoRestart) {
            # If NoAutoRestart flag is set, exit normally without restarting
            $exitMsg = "`n--- Server exited with code $exitCode. Auto-restart disabled, shutting down. ---`n"
            Write-Host $exitMsg -ForegroundColor Green
            $exitMsg | Out-File -FilePath $LogFile -Encoding utf8 -Append
            $continueRunning = $false
        } else {
            # Default behavior: restart after 10 seconds
            $restartMsg = "`n--- Server exited with code $exitCode. Restarting in 10 seconds... ---`n"
            Write-Host $restartMsg -ForegroundColor Yellow
            $restartMsg | Out-File -FilePath $LogFile -Encoding utf8 -Append
            Start-Sleep -Seconds 10
        }
    }
}
