# =============================================================================
# Modpack Download Module
# =============================================================================
# This module handles downloading and extracting modpacks.
# =============================================================================

<#
.SYNOPSIS
    Downloads and extracts modpacks.

.DESCRIPTION
    Downloads modpack files (.mrpack), extracts them, and processes
    the modrinth.index.json to download all included files.

.PARAMETER ModId
    The modpack ID.

.PARAMETER VersionUrl
    The download URL for the modpack.

.PARAMETER ModName
    The name of the modpack.

.PARAMETER GameVersion
    The target game version.

.PARAMETER DownloadFolder
    The base download folder.

.PARAMETER ForceDownload
    Whether to force download even if files exist.

.EXAMPLE
    Download-Modpack -ModId "fabulously-optimized" -VersionUrl "https://..." -ModName "Fabulously Optimized" -GameVersion "1.21.5" -DownloadFolder "download"

.NOTES
    - Downloads .mrpack files and extracts them
    - Processes modrinth.index.json for file downloads
    - Handles overrides folder copying
    - Creates organized folder structure
#>
# Function to download modpacks
function Download-Modpack {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        [Parameter(Mandatory=$true)]
        [string]$VersionUrl,
        [Parameter(Mandatory=$true)]
        [string]$ModName,
        [Parameter(Mandatory=$true)]
        [string]$GameVersion,
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder,
        [bool]$ForceDownload = $false
    )
    try {
        Write-Host "📦 Downloading modpack: $ModName" -ForegroundColor Cyan
        Write-Host "   URL: $VersionUrl" -ForegroundColor Gray
        
        # Create download directory structure using the passed DownloadFolder parameter
        $downloadDir = Join-Path $DownloadFolder $GameVersion
        $modpackDir = Join-Path $downloadDir "modpacks\$ModName"
        if (-not (Test-Path $downloadDir)) {
            New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
        }
        if (-not (Test-Path $modpackDir)) {
            New-Item -ItemType Directory -Path $modpackDir -Force | Out-Null
        }
        
        # Download the .mrpack file
        $mrpackFileName = "$ModName.mrpack"
        $mrpackPath = Join-Path $modpackDir $mrpackFileName
        if ((Test-Path $mrpackPath) -and (-not $ForceDownload)) {
            Write-Host "⏭️  Modpack file already exists, skipping download" -ForegroundColor Yellow
        } else {
            Write-Host "⬇️  Downloading modpack file..." -ForegroundColor Yellow
            try {
                Invoke-WebRequest -Uri $VersionUrl -OutFile $mrpackPath -UseBasicParsing
                Write-Host "✅ Downloaded modpack file" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to download modpack file: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
        
        # Extract the .mrpack file (it's just a zip file)
        Write-Host "📂 Extracting modpack..." -ForegroundColor Yellow
        try {
            Expand-Archive -Path $mrpackPath -DestinationPath $modpackDir -Force
        } catch {
            Write-Host "❌ Failed to extract modpack: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
        
        # Find and process modrinth.index.json
        $indexPath = Join-Path $modpackDir "modrinth.index.json"
        if (-not (Test-Path $indexPath)) {
            Write-Host "❌ modrinth.index.json not found in extracted modpack" -ForegroundColor Red
            Write-Host "   Expected path: $indexPath" -ForegroundColor Gray
            Write-Host "   Available files:" -ForegroundColor Gray
            Get-ChildItem $modpackDir | ForEach-Object { Write-Host "     $($_.Name)" -ForegroundColor Gray }
            return 0
        }
        
        $indexContent = Get-Content $indexPath | ConvertFrom-Json
        Write-Host "📋 Processing modpack index with $($indexContent.files.Count) files..." -ForegroundColor Cyan
        
        # Download files from the index
        $successCount = 0
        $errorCount = 0
        foreach ($file in $indexContent.files) {
            $filePath = $file.path
            $downloadUrl = $file.downloads[0]  # Use first download URL
            
            # Create the target directory
            $targetDir = Split-Path -Path (Join-Path $downloadDir $filePath) -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            $targetPath = Join-Path $downloadDir $filePath
            
            # Download the file
            try {
                if ((Test-Path $targetPath) -and (-not $ForceDownload)) {
                    Write-Host "  ⏭️  Skipped: $filePath (already exists)" -ForegroundColor Gray
                } else {
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $targetPath -UseBasicParsing
                    Write-Host "  ✅ Downloaded: $filePath" -ForegroundColor Green
                    $successCount++
                }
            } catch {
                Write-Host "  ❌ Failed: $filePath - $($_.Exception.Message)" -ForegroundColor Red
                $errorCount++
            }
        }
        
        # Handle overrides folder
        $overridesPath = Join-Path $modpackDir "overrides"
        if (Test-Path $overridesPath) {
            Write-Host "📁 Copying overrides folder contents..." -ForegroundColor Yellow
            Copy-Item -Path "$overridesPath\*" -Destination $downloadDir -Recurse -Force
            Write-Host "✅ Copied overrides to $downloadDir" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "📦 Modpack installation complete!" -ForegroundColor Green
        Write-Host "✅ Successfully downloaded: $successCount files" -ForegroundColor Green
        Write-Host "⏭️  Skipped (already exists): $(($indexContent.files.Count - $successCount - $errorCount))" -ForegroundColor Yellow
        Write-Host "❌ Failed: $errorCount files" -ForegroundColor Red
        return $successCount
    } catch {
        Write-Host "❌ Modpack download failed: $($_.Exception.Message)" -ForegroundColor Red
        return 0
    }
}

# Function is available for dot-sourcing 