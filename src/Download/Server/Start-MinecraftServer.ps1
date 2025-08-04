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
.EXAMPLE
    Start-MinecraftServer -DownloadFolder "download"
#>
function Start-MinecraftServer {
    param(
        [string]$DownloadFolder = "download",
        [string]$ScriptSource = (Join-Path $PSScriptRoot "..\..\..\tools\start-server.ps1")
    )
    
    Write-Host "🚀 Starting Minecraft server..." -ForegroundColor Green
    
    # Get minimum Java version from environment or use default
    $minJavaVersion = [int]($env:JAVA_VERSION_MIN ?? "17")
    
    # Check Java version first
    Write-Host "🔍 Checking Java version..." -ForegroundColor Cyan
    try {
        $javaVersion = java -version 2>&1 | Select-String "version" | Select-Object -First 1
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
                    Write-Host "💡 Please upgrade to Java $minJavaVersion or later" -ForegroundColor Yellow
                    return $false
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
    
    # Find the most recent version folder (sort numerically)
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
    
    Write-Host "✅ Found Fabric server JAR: $($fabricJars[0].Name)" -ForegroundColor Green
    
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
        Write-Host "📝 Running server to generate configuration files..." -ForegroundColor Cyan
        
        # Run server first time to generate files
        Write-Host "  🔄 Starting Minecraft server to generate config files..." -ForegroundColor Gray
        $initJob = Start-Job -ScriptBlock {
            param($JarPath, $WorkingDir)
            Set-Location $WorkingDir
            
            # Run server and capture output
            $output = java -Xms512M -Xmx1G -jar $JarPath nogui 2>&1
            return $output
        } -ArgumentList $fabricJars[0].Name, $targetFolder
        
        # Monitor for file creation or timeout
        $maxWait = 45
        $waitTime = 0
        $filesCreated = $false
        
        while ($waitTime -lt $maxWait -and -not $filesCreated) {
            Start-Sleep -Seconds 2
            $waitTime += 2
            
            # Check if both files are created
            if ((Test-Path $eulaPath) -and (Test-Path $propsPath)) {
                $filesCreated = $true
                Write-Host "  ✅ Configuration files detected" -ForegroundColor Green
                
                # Stop the initialization job since files are created
                Write-Host "  🛑 Stopping initialization job..." -ForegroundColor Gray
                Stop-Job -Job $initJob -PassThru | Out-Null
                break
            }
            
            # Check if job completed
            if ($initJob.State -eq "Completed") {
                Write-Host "  ⏹️  Initialization job completed" -ForegroundColor Gray
                break
            }
            
            Write-Host "  ⏳ Waiting for config files... ($waitTime/${maxWait}s)" -ForegroundColor Gray
        }
        
        # Get job output and clean up
        try {
            $jobOutput = Receive-Job -Job $initJob -ErrorAction SilentlyContinue
        } catch {
            Write-Host "  ⚠️  Job output could not be retrieved" -ForegroundColor Yellow
        }
        Remove-Job -Job $initJob -Force -ErrorAction SilentlyContinue
        
        if ($jobOutput) {
            Write-Host "📋 Initialization output:" -ForegroundColor Gray
            Write-Host ($jobOutput | Out-String) -ForegroundColor Gray
        }
        
        # Wait a moment for files to be fully written
        Start-Sleep -Seconds 3
        
        # Verify files were actually created
        Write-Host "🔍 Verifying initialization files..." -ForegroundColor Gray
        if (Test-Path $eulaPath) {
            Write-Host "  ✅ eula.txt exists" -ForegroundColor Green
        } else {
            Write-Host "  ❌ eula.txt missing" -ForegroundColor Red
        }
        
        if (Test-Path $propsPath) {
            Write-Host "  ✅ server.properties exists" -ForegroundColor Green
        } else {
            Write-Host "  ❌ server.properties missing" -ForegroundColor Red
        }
        
        # Accept EULA
        if (Test-Path $eulaPath) {
            $eulaContent = Get-Content $eulaPath -Raw
            $eulaContent = $eulaContent -replace "eula=false", "eula=true"
            Set-Content -Path $eulaPath -Value $eulaContent -NoNewline
            Write-Host "✅ EULA accepted" -ForegroundColor Green
        } else {
            # Create EULA file if it doesn't exist
            "eula=true" | Set-Content -Path $eulaPath -NoNewline
            Write-Host "✅ EULA file created and accepted" -ForegroundColor Green
        }
        
        # Set offline mode for testing
        if (Test-Path $propsPath) {
            $propsContent = Get-Content $propsPath -Raw
            if ($propsContent -match "online-mode=true") {
                $propsContent = $propsContent -replace "online-mode=true", "online-mode=false"
                Set-Content -Path $propsPath -Value $propsContent -NoNewline
                Write-Host "✅ Set offline mode for testing" -ForegroundColor Green
            }
        } else {
            Write-Host "⚠️  server.properties not found after initialization" -ForegroundColor Yellow
        }
        
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
    
    # Start the actual validation run
    Write-Host "🔄 Starting server validation run..." -ForegroundColor Cyan
    Write-Host "📋 Server logs will be saved to: $logsDir" -ForegroundColor Gray
    
    try {
        # Start the server as a background job - run Java directly for better control
        $job = Start-Job -ScriptBlock {
            param($JarPath, $WorkingDir)
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
            
            # Run the Fabric server directly
            java -server -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -Xms1G -Xmx4G --enable-native-access=ALL-UNNAMED -jar $JarPath nogui
        } -ArgumentList $fabricJars[0].Name, $targetFolder
        
        Write-Host "✅ Server job started successfully (Job ID: $($job.Id))" -ForegroundColor Green
        Write-Host "🔄 Monitoring server logs for errors..." -ForegroundColor Cyan
        
        # Monitor logs for errors
        $logFile = $null
        $startTime = Get-Date
        $timeout = 60  # Wait up to 60 seconds for log file to appear
        
        # Wait for server log file to be created (prefer latest.log, fallback to console-*.log)
        while ((Get-Date) -lt ($startTime.AddSeconds($timeout))) {
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
            Start-Sleep -Seconds 1
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
        $monitorTime = 300  # Monitor for up to 5 minutes
        $monitorStart = Get-Date
        $errorFound = $false
        $serverLoaded = $false
        $lastLogSize = 0
        
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
                # For server startup scripts, completion is normal - they launch Java processes and exit
                Write-Host "✅ Server startup script completed - checking for Java process..." -ForegroundColor Green
                
                # Check if a Java process is running (indicating server startup)
                $javaProcesses = Get-Process -Name "java" -ErrorAction SilentlyContinue
                if ($javaProcesses.Count -gt 0) {
                    Write-Host "✅ Java processes detected - server likely started!" -ForegroundColor Green
                    break
                } else {
                    # Wait a bit more for the server to start
                    Start-Sleep -Seconds 2
                    $javaProcesses = Get-Process -Name "java" -ErrorAction SilentlyContinue
                    if ($javaProcesses.Count -gt 0) {
                        Write-Host "✅ Java processes detected after delay!" -ForegroundColor Green
                        break
                    } else {
                        Write-Host "⚠️  No Java processes found - server may have failed to start" -ForegroundColor Yellow
                    }
                }
            }
            
            # Check log file for errors
            if (Test-Path $logFile) {
                $currentLogSize = (Get-Item $logFile).Length
                if ($currentLogSize -gt $lastLogSize) {
                    $newLines = Get-Content $logFile -Tail 20 -ErrorAction SilentlyContinue
                    foreach ($line in $newLines) {
                        # Check for server loaded successfully  
                        if ($line -match "Done \(.*\)! For help, type" -or 
                            $line -match "Server thread.*INFO.*Done") {
                            Write-Host "✅ Server fully loaded! Message: $line" -ForegroundColor Green
                            $serverLoaded = $true
                            break
                        }
                        
                        # Check for actual errors, but ignore common Fabric warnings and setup messages
                        if ($line -match "(ERROR|FATAL|Exception|Failed|Error)" -and 
                            $line -notmatch "Server exited" -and
                            $line -notmatch "Incomplete remapped file found" -and
                            $line -notmatch "remapping process failed on the previous launch" -and
                            $line -notmatch "Fabric is preparing JARs" -and
                            $line -notmatch "GameRemap.*WARN") {
                            Write-Host "❌ Error detected in logs: $line" -ForegroundColor Red
                            $errorFound = $true
                            break
                        }
                    }
                    $lastLogSize = $currentLogSize
                }
            }
            
            Start-Sleep -Seconds 2
        }
        
        # Handle the results
        if ($errorFound) {
            Write-Host "❌ SERVER STARTUP FAILED - Errors detected during startup" -ForegroundColor Red
            Write-Host "🛑 Stopping server job..." -ForegroundColor Red
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -ErrorAction SilentlyContinue
            Write-Host "📄 Check the log file for details: $logFile" -ForegroundColor Gray
            return $false
        } elseif ($serverLoaded) {
            Write-Host "✅ SERVER FULLY LOADED SUCCESSFULLY!" -ForegroundColor Green
            Write-Host "🛑 Stopping server for pipeline validation..." -ForegroundColor Yellow
            
            # Send stop command to server
            $stopCommand = "stop"
            $serverProcess = Get-Process | Where-Object { $_.ProcessName -eq "java" } | Select-Object -First 1
            if ($serverProcess) {
                # Try to stop gracefully - this is basic, server should stop from the stop command in console
                Write-Host "📤 Sending stop command to server..." -ForegroundColor Gray
            }
            
            # Wait a moment for graceful shutdown
            Start-Sleep -Seconds 5
            
            # Force stop the job
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -ErrorAction SilentlyContinue
            
            Write-Host "✅ SERVER VALIDATION COMPLETE - Server loaded and stopped successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⏰ SERVER STARTUP TIMEOUT - Server did not fully load within $monitorTime seconds" -ForegroundColor Red
            Write-Host "🛑 Stopping server job..." -ForegroundColor Red
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -ErrorAction SilentlyContinue
            Write-Host "📄 Check the log file for details: $logFile" -ForegroundColor Gray
            return $false
        }
        
    } catch {
        Write-Host "❌ Error starting server: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} 