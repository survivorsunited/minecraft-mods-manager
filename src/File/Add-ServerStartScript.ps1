# =============================================================================
# Add Server Start Script Function
# =============================================================================
# This function creates a server startup script for testing mods
# =============================================================================

<#
.SYNOPSIS
    Creates a server startup script for testing mods.
.DESCRIPTION
    Creates a PowerShell script that can start a Minecraft server with the downloaded mods
    for testing purposes.
.PARAMETER DownloadFolder
    The download folder containing mods and server files.
.EXAMPLE
    Add-ServerStartScript -DownloadFolder "download"
#>
function Add-ServerStartScript {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder
    )

    try {
        # Check if download folder exists
        if (-not (Test-Path $DownloadFolder)) {
            Write-Host "❌ Download folder not found: $DownloadFolder" -ForegroundColor Red
            Write-Host "💡 Run -DownloadMods or -DownloadServer first to create the download folder" -ForegroundColor Yellow
            return $false
        }
        
        # Find the most recent version folder
        $versionFolders = Get-ChildItem -Path $DownloadFolder -Directory -ErrorAction SilentlyContinue | 
                         Where-Object { $_.Name -match "^\d+\.\d+\.\d+" } |
                         Sort-Object Name -Descending
        
        if ($versionFolders.Count -eq 0) {
            Write-Host "❌ No version folders found in $DownloadFolder" -ForegroundColor Red
            Write-Host "💡 Run -DownloadMods or -DownloadServer first to download server files" -ForegroundColor Yellow
            return $false
        }
        
        $targetVersion = $versionFolders[0].Name
        $targetFolder = Join-Path $DownloadFolder $targetVersion
        
        Write-Host "📁 Using version folder: $targetFolder" -ForegroundColor Cyan
        
        # Copy start-server script to target folder
        $scriptSource = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "tools/start-server.ps1"
        $serverScript = Join-Path $targetFolder "start-server.ps1"
        
        if (-not (Test-Path $scriptSource)) {
            Write-Host "❌ Start server script not found: $scriptSource" -ForegroundColor Red
            return $false
        }
        
        try {
            Copy-Item -Path $scriptSource -Destination $serverScript -Force
            Write-Host "Successfully copied start-server script to: $serverScript" -ForegroundColor Green
            Write-Host "💡 You can now run the server from: $targetFolder" -ForegroundColor Yellow
            return $true
        }
        catch {
            Write-Host "❌ Failed to copy start-server script: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }

    } catch {
        Write-Host "Error creating server start script: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} 