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
    
    # Find the most recent version folder
    $versionFolders = Get-ChildItem -Path $DownloadFolder -Directory -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Name -match "^\d+\.\d+\.\d+" } |
                     Sort-Object Name -Descending
    
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
    
    # Start the server as a background job
    Write-Host "🔄 Starting server as background job..." -ForegroundColor Cyan
    Write-Host "📋 Server logs will be saved to: $logsDir" -ForegroundColor Gray
    
    try {
        # Start the server as a background job
        $job = Start-Job -ScriptBlock {
            param($ScriptPath, $WorkingDir)
            Set-Location $WorkingDir
            & $ScriptPath
        } -ArgumentList $serverScript, $targetFolder
        
        Write-Host "✅ Server job started successfully (Job ID: $($job.Id))" -ForegroundColor Green
        Write-Host "🔄 Monitoring server logs for errors..." -ForegroundColor Cyan
        
        # Monitor logs for errors
        $logFile = $null
        $startTime = Get-Date
        $timeout = 60  # Wait up to 60 seconds for log file to appear
        
        # Wait for log file to be created
        while ((Get-Date) -lt ($startTime.AddSeconds($timeout))) {
            $logFiles = Get-ChildItem -Path $logsDir -Filter "console-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
            if ($logFiles.Count -gt 0) {
                $logFile = $logFiles[0].FullName
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
        
        # Monitor for errors for a longer period
        $monitorTime = 60  # Monitor for 60 seconds
        $monitorStart = Get-Date
        $errorFound = $false
        $lastLogSize = 0
        
        while ((Get-Date) -lt ($monitorStart.AddSeconds($monitorTime)) -and -not $errorFound) {
            # Check if job is still running
            $jobStatus = Get-Job -Id $job.Id
            if ($jobStatus.State -eq "Failed" -or $jobStatus.State -eq "Completed") {
                Write-Host "❌ Server job stopped unexpectedly (State: $($jobStatus.State))" -ForegroundColor Red
                $jobOutput = Receive-Job -Id $job.Id -ErrorAction SilentlyContinue
                if ($jobOutput) {
                    Write-Host "📄 Job output: $jobOutput" -ForegroundColor Gray
                }
                $errorFound = $true
                break
            }
            
            # Check log file for errors
            if (Test-Path $logFile) {
                $currentLogSize = (Get-Item $logFile).Length
                if ($currentLogSize -gt $lastLogSize) {
                    $newLines = Get-Content $logFile -Tail 10 -ErrorAction SilentlyContinue
                    foreach ($line in $newLines) {
                        if ($line -match "(ERROR|FATAL|Exception|Failed|Error)" -and $line -notmatch "Server exited") {
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
        
        if ($errorFound) {
            Write-Host "⚠️  Errors detected during server startup" -ForegroundColor Yellow
            Write-Host "🛑 Stopping server job..." -ForegroundColor Cyan
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -ErrorAction SilentlyContinue
            Write-Host "📄 Check the log file for details: $logFile" -ForegroundColor Gray
            exit 1
        }
        
        Write-Host "✅ Server started successfully!" -ForegroundColor Green
        Write-Host "🔄 Server is running in background (Job ID: $($job.Id))" -ForegroundColor Cyan
        Write-Host "📄 Log file: $logFile" -ForegroundColor Gray
        Write-Host "🛑 To stop the server, run: Stop-Job -Id $($job.Id)" -ForegroundColor Yellow
        
        return $true
        
    } catch {
        Write-Host "❌ Error starting server: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} 