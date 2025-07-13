# =============================================================================
# Server Files Download Module
# =============================================================================
# This module handles downloading Minecraft server JARs and Fabric launchers.
# =============================================================================

<#
.SYNOPSIS
    Downloads server JARs and Fabric launchers.

.DESCRIPTION
    Downloads Minecraft server JARs and Fabric launcher files
    for different game versions.

.PARAMETER DownloadFolder
    The base download folder.

.PARAMETER ForceDownload
    Whether to force download even if files exist.

.EXAMPLE
    Download-ServerFiles -DownloadFolder "download" -ForceDownload

.NOTES
    - Downloads server JARs for multiple game versions
    - Downloads Fabric launchers for server setup
    - Creates organized folder structure by version
    - Provides detailed download reports
#>
# Function to download server JARs and Fabric launchers
function Download-ServerFiles {
    param(
        [string]$DownloadFolder = "download",
        [switch]$ForceDownload
    )
    
    try {
        Write-Host "Downloading server files..." -ForegroundColor Yellow
        
        # Create download folder if it doesn't exist
        if (-not (Test-Path $DownloadFolder)) {
            New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
        }
        
        $downloadResults = @()
        $successCount = 0
        $errorCount = 0
        
        # Server JARs to download
        $serverFiles = @(
            @{
                Version = "1.21.5"
                Url = "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar"
                Filename = "minecraft_server.1.21.5.jar"
            },
            @{
                Version = "1.21.6"
                Url = "https://piston-data.mojang.com/v1/objects/6e64dcabba3c01a7271b4fa6bd898483b794c59b/server.jar"
                Filename = "minecraft_server.1.21.6.jar"
            }
        )
        
        # Fabric launchers to download
        $launcherFiles = @(
            @{
                Version = "1.21.5"
                Url = "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar"
                Filename = "fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar"
            },
            @{
                Version = "1.21.6"
                Url = "https://meta.fabricmc.net/v2/versions/loader/1.21.6/0.16.14/1.0.3/server/jar"
                Filename = "fabric-server-mc.1.21.6-loader.0.16.14-launcher.1.0.3.jar"
            }
        )
        
        # Download server JARs
        foreach ($server in $serverFiles) {
            $versionFolder = Join-Path $DownloadFolder $server.Version
            if (-not (Test-Path $versionFolder)) {
                New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
            }
            
            $downloadPath = Join-Path $versionFolder $server.Filename
            
            # Check if file already exists
            if ((Test-Path $downloadPath) -and -not $ForceDownload) {
                Write-Host "⏭️  $($server.Filename): Already exists" -ForegroundColor Yellow
                $downloadResults += [PSCustomObject]@{
                    Name = $server.Filename
                    Status = "Skipped"
                    Version = $server.Version
                    File = $server.Filename
                    Path = $downloadPath
                    Error = "File already exists"
                }
                continue
            }
            
            # Download the file
            Write-Host "⬇️  $($server.Filename): Downloading..." -ForegroundColor Cyan
            
            try {
                $webRequest = Invoke-WebRequest -Uri $server.Url -OutFile $downloadPath -UseBasicParsing
                
                if (Test-Path $downloadPath) {
                    $fileSize = (Get-Item $downloadPath).Length
                    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                    
                    Write-Host "✅ $($server.Filename): Downloaded successfully ($fileSizeMB MB)" -ForegroundColor Green
                    
                    $downloadResults += [PSCustomObject]@{
                        Name = $server.Filename
                        Status = "Success"
                        Version = $server.Version
                        File = $server.Filename
                        Path = $downloadPath
                        Size = "$fileSizeMB MB"
                        Error = $null
                    }
                    $successCount++
                } else {
                    throw "File was not created"
                }
            }
            catch {
                Write-Host "❌ $($server.Filename): Download failed - $($_.Exception.Message)" -ForegroundColor Red
                
                # Clean up partial download if it exists
                if (Test-Path $downloadPath) {
                    Remove-Item $downloadPath -Force
                }
                
                $downloadResults += [PSCustomObject]@{
                    Name = $server.Filename
                    Status = "Failed"
                    Version = $server.Version
                    File = $server.Filename
                    Path = $downloadPath
                    Size = $null
                    Error = $_.Exception.Message
                }
                $errorCount++
            }
        }
        
        # Download Fabric launchers
        foreach ($launcher in $launcherFiles) {
            $versionFolder = Join-Path $DownloadFolder $launcher.Version
            if (-not (Test-Path $versionFolder)) {
                New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
            }
            
            $downloadPath = Join-Path $versionFolder $launcher.Filename
            
            # Check if file already exists
            if ((Test-Path $downloadPath) -and -not $ForceDownload) {
                Write-Host "⏭️  $($launcher.Filename): Already exists" -ForegroundColor Yellow
                $downloadResults += [PSCustomObject]@{
                    Name = $launcher.Filename
                    Status = "Skipped"
                    Version = $launcher.Version
                    File = $launcher.Filename
                    Path = $downloadPath
                    Error = "File already exists"
                }
                continue
            }
            
            # Download the file
            Write-Host "⬇️  $($launcher.Filename): Downloading..." -ForegroundColor Cyan
            
            try {
                $webRequest = Invoke-WebRequest -Uri $launcher.Url -OutFile $downloadPath -UseBasicParsing
                
                if (Test-Path $downloadPath) {
                    $fileSize = (Get-Item $downloadPath).Length
                    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                    
                    Write-Host "✅ $($launcher.Filename): Downloaded successfully ($fileSizeMB MB)" -ForegroundColor Green
                    
                    $downloadResults += [PSCustomObject]@{
                        Name = $launcher.Filename
                        Status = "Success"
                        Version = $launcher.Version
                        File = $launcher.Filename
                        Path = $downloadPath
                        Size = "$fileSizeMB MB"
                        Error = $null
                    }
                    $successCount++
                } else {
                    throw "File was not created"
                }
            }
            catch {
                Write-Host "❌ $($launcher.Filename): Download failed - $($_.Exception.Message)" -ForegroundColor Red
                
                # Clean up partial download if it exists
                if (Test-Path $downloadPath) {
                    Remove-Item $downloadPath -Force
                }
                
                $downloadResults += [PSCustomObject]@{
                    Name = $launcher.Filename
                    Status = "Failed"
                    Version = $launcher.Version
                    File = $launcher.Filename
                    Path = $downloadPath
                    Size = $null
                    Error = $_.Exception.Message
                }
                $errorCount++
            }
        }
        
        # Display summary
        Write-Host ""
        Write-Host "Server Files Download Summary:" -ForegroundColor Yellow
        Write-Host "=============================" -ForegroundColor Yellow
        Write-Host "✅ Successfully downloaded: $successCount" -ForegroundColor Green
        Write-Host "⏭️  Skipped (already exists): $(($downloadResults | Where-Object { $_.Status -eq "Skipped" }).Count)" -ForegroundColor Yellow
        Write-Host "❌ Failed: $errorCount" -ForegroundColor Red
        
        # Show failed downloads
        if ($errorCount -gt 0) {
            Write-Host ""
            Write-Host "Failed downloads:" -ForegroundColor Red
            foreach ($result in $downloadResults | Where-Object { $_.Status -eq "Failed" }) {
                Write-Host "  ❌ $($result.Name): $($result.Error)" -ForegroundColor Red
            }
        }
        
        return $successCount
    }
    catch {
        Write-Error "Failed to download server files: $($_.Exception.Message)"
        return 0
    }
}

# Function is available for dot-sourcing 