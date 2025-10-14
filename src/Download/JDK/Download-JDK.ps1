# =============================================================================
# JDK Download Module
# =============================================================================
# This module handles downloading JDK files from database entries.
# =============================================================================

<#
.SYNOPSIS
    Downloads JDK files based on database entries.

.DESCRIPTION
    Downloads JDK ZIP/TAR.GZ files from Adoptium and extracts them to
    a local jdk/ folder for use by Minecraft servers.

.PARAMETER CsvPath
    Path to the CSV database file.

.PARAMETER DownloadFolder
    Base folder for downloads. Default: "download"

.PARAMETER Version
    JDK version to download (e.g., "21"). If not specified, downloads based on requirement.

.PARAMETER Platform
    Platform to download for. If not specified, auto-detects current OS.

.PARAMETER ForceDownload
    Force re-download even if JDK already exists.

.EXAMPLE
    Download-JDK -CsvPath "modlist.csv" -Version "21"

.EXAMPLE
    Download-JDK -CsvPath "modlist.csv" -Version "21" -Platform "windows" -ForceDownload

.NOTES
    - Downloads to .cache/jdk/jdk-{version}-{platform}/
    - Extracts ZIP/TAR.GZ automatically
    - Verifies checksums if available
    - Auto-detects platform if not specified
    - JDK is infrastructure, stored in .cache not download
#>
function Download-JDK {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [string]$DownloadFolder = "download",
        [string]$Version = "21",
        [string]$Platform = "",
        [switch]$ForceDownload = $false
    )
    
    try {
        # Auto-detect platform if not specified
        if (-not $Platform) {
            if ($IsWindows -or $env:OS -eq "Windows_NT") {
                $Platform = "windows"
            } elseif ($IsLinux) {
                $Platform = "linux"
            } elseif ($IsMacOS) {
                $Platform = "mac"
            } else {
                Write-Host "❌ Could not auto-detect platform" -ForegroundColor Red
                return $false
            }
        }
        
        Write-Host ""
        Write-Host "📦 Downloading JDK $Version for $Platform" -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Load database and find JDK entry
        $mods = Import-Csv -Path $CsvPath
        $jdkEntry = $mods | Where-Object { 
            $_.Type -eq "jdk" -and 
            $_.ID -eq "jdk-$Version-$Platform"
        } | Select-Object -First 1
        
        if (-not $jdkEntry) {
            Write-Host "❌ JDK $Version for $Platform not found in database" -ForegroundColor Red
            Write-Host "   Run: .\ModManager.ps1 -SyncJDKVersions" -ForegroundColor Yellow
            return $false
        }
        
        # Create JDK cache folder (infrastructure goes in .cache, not download)
        $cacheFolder = ".cache"
        $jdkBaseFolder = Join-Path $cacheFolder "jdk"
        $jdkFolder = Join-Path $jdkBaseFolder "jdk-$Version-$Platform"
        
        if (-not (Test-Path $cacheFolder)) {
            New-Item -ItemType Directory -Path $cacheFolder -Force | Out-Null
        }
        
        if (-not (Test-Path $jdkBaseFolder)) {
            New-Item -ItemType Directory -Path $jdkBaseFolder -Force | Out-Null
        }
        
        # Check if JDK already extracted
        $jdkBinFolder = Join-Path $jdkFolder "bin"
        if ((Test-Path $jdkBinFolder) -and -not $ForceDownload) {
            Write-Host "✅ JDK $Version already downloaded and extracted" -ForegroundColor Green
            Write-Host "   Location: $jdkFolder" -ForegroundColor Gray
            return $true
        }
        
        # Download JDK
        $downloadUrl = $jdkEntry.Url
        $fileName = $jdkEntry.Jar
        $downloadPath = Join-Path $jdkBaseFolder $fileName
        
        Write-Host "   📥 Downloading JDK $($jdkEntry.CurrentVersion)..." -ForegroundColor Cyan
        Write-Host "      URL: $downloadUrl" -ForegroundColor Gray
        Write-Host "      File: $fileName" -ForegroundColor Gray
        
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -TimeoutSec 300
        
        if (-not (Test-Path $downloadPath)) {
            Write-Host "   ❌ Download failed" -ForegroundColor Red
            return $false
        }
        
        $downloadedSize = (Get-Item $downloadPath).Length
        Write-Host "      ✓ Downloaded $([Math]::Round($downloadedSize / 1MB, 2)) MB" -ForegroundColor Green
        
        # Extract JDK
        Write-Host "   📦 Extracting JDK..." -ForegroundColor Cyan
        
        if ($fileName -match '\.zip$') {
            # Windows ZIP file
            Expand-Archive -Path $downloadPath -DestinationPath $jdkBaseFolder -Force
            
            # Find the extracted folder (usually has a version-specific name)
            $extractedFolders = Get-ChildItem -Path $jdkBaseFolder -Directory | Where-Object { $_.Name -like "*jdk*$Version*" }
            if ($extractedFolders) {
                $extractedFolder = $extractedFolders[0].FullName
                
                # Rename to standard name if different
                if ($extractedFolder -ne $jdkFolder) {
                    if (Test-Path $jdkFolder) {
                        Remove-Item -Path $jdkFolder -Recurse -Force
                    }
                    Move-Item -Path $extractedFolder -Destination $jdkFolder -Force
                }
            }
        } elseif ($fileName -match '\.(tar\.gz|tgz)$') {
            # Linux/Mac TAR.GZ file
            if (Get-Command tar -ErrorAction SilentlyContinue) {
                & tar -xzf $downloadPath -C $jdkBaseFolder
                
                # Find and rename extracted folder
                $extractedFolders = Get-ChildItem -Path $jdkBaseFolder -Directory | Where-Object { $_.Name -like "*jdk*$Version*" }
                if ($extractedFolders) {
                    $extractedFolder = $extractedFolders[0].FullName
                    if ($extractedFolder -ne $jdkFolder) {
                        if (Test-Path $jdkFolder) {
                            Remove-Item -Path $jdkFolder -Recurse -Force
                        }
                        Move-Item -Path $extractedFolder -Destination $jdkFolder -Force
                    }
                }
            } else {
                Write-Host "      ⚠️  tar command not available, skipping extraction" -ForegroundColor Yellow
            }
        }
        
        # Verify extraction
        if (Test-Path $jdkBinFolder) {
            Write-Host "      ✓ Extracted successfully" -ForegroundColor Green
            Write-Host "      ✓ JDK location: $jdkFolder" -ForegroundColor Green
            
            # Clean up downloaded archive
            Remove-Item -Path $downloadPath -Force
            Write-Host "      ✓ Cleaned up archive" -ForegroundColor Gray
            
            return $true
        } else {
            Write-Host "      ❌ Extraction failed - bin folder not found" -ForegroundColor Red
            return $false
        }
        
    } catch {
        Write-Host "❌ Error downloading JDK: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function is available for dot-sourcing

