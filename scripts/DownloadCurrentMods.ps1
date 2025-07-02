# DownloadCurrentMods.ps1
# Downloads current versions of all mods
# 
# This script downloads the current versions of all mods as specified in the database:
# 1. Download current mods (no database update)
#
# Usage: .\scripts\DownloadCurrentMods.ps1 [-DownloadFolder "path"] [-DatabaseFile "path"]

param(
    [Parameter(Mandatory=$false)]
    [string]$DownloadFolder = "download",
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseFile = "modlist.csv"
)

# Script configuration
$ModManagerPath = Join-Path $PSScriptRoot "..\ModManager.ps1"

# Color definitions for output
$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "White"
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n" + ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host $Message -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
}

function Write-Step {
    param([string]$Step, [string]$Description)
    Write-Host "`n[$Step] $Description" -ForegroundColor $Colors.Info
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $Colors.Success
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $Colors.Warning
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $Colors.Error
}

function Test-ModManagerExists {
    if (-not (Test-Path $ModManagerPath)) {
        Write-Error "ModManager.ps1 not found at: $ModManagerPath"
        Write-Host "Please run this script from the project root directory." -ForegroundColor $Colors.Error
        exit 1
    }
}

function Test-DatabaseExists {
    if (-not (Test-Path $DatabaseFile)) {
        Write-Error "Database file not found: $DatabaseFile"
        Write-Host "Please ensure modlist.csv exists in the current directory." -ForegroundColor $Colors.Error
        exit 1
    }
}

function Invoke-ModManagerCommand {
    param(
        [string]$Command,
        [string]$StepName,
        [string]$SuccessMessage,
        [string]$ErrorMessage
    )
    
    Write-Step $StepName "Executing: $Command"
    
    try {
        $result = & pwsh -NoProfile -ExecutionPolicy Bypass -Command $Command 2>&1
        $exitCode = $LASTEXITCODE
        
        # Display the output
        $result | ForEach-Object { Write-Host $_ }
        
        if ($exitCode -eq 0) {
            Write-Success $SuccessMessage
            return $true
        } else {
            Write-Warning "$ErrorMessage (Exit code: $exitCode)"
            return $false
        }
    }
    catch {
        Write-Error "$ErrorMessage - Exception: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
Write-Header "Downloading Current Mod Versions"
Write-Host "This script will download the current versions of all mods as specified in the database." -ForegroundColor $Colors.Info
Write-Host "Download Folder: $DownloadFolder" -ForegroundColor $Colors.Info
Write-Host "Database File: $DatabaseFile" -ForegroundColor $Colors.Info

# Validate prerequisites
Write-Step "VALIDATION" "Checking prerequisites..."
Test-ModManagerExists
Test-DatabaseExists
Write-Success "Prerequisites validated"

# Build common parameters
$commonParams = "-DatabaseFile `"$DatabaseFile`" -DownloadFolder `"$DownloadFolder`" -UseCachedResponses"

# Step 1: Download current mods
Write-Step "STEP 1" "Downloading current mods"
$downloadCommand = "& `"$ModManagerPath`" -Download $commonParams"
$downloadSuccess = Invoke-ModManagerCommand -Command $downloadCommand -StepName "DOWNLOAD" -SuccessMessage "Current mods downloaded successfully" -ErrorMessage "Failed to download current mods"

if (-not $downloadSuccess) {
    Write-Error "Mod download failed."
    exit 1
}

# Summary
Write-Header "Current Mods Download Complete"
Write-Host "Download Folder: $DownloadFolder" -ForegroundColor $Colors.Info
Write-Host "Database File: $DatabaseFile" -ForegroundColor $Colors.Info

if (Test-Path $DownloadFolder) {
    $modCount = (Get-ChildItem -Path "$DownloadFolder\*\mods\*.jar" -Recurse -ErrorAction SilentlyContinue).Count
    Write-Host "Mods Downloaded: $modCount" -ForegroundColor $Colors.Info
}

Write-Host "`nNext Steps:" -ForegroundColor $Colors.Info
Write-Host "1. Review downloaded mods in: $DownloadFolder" -ForegroundColor $Colors.Info
Write-Host "2. To get latest versions, run: .\scripts\DownloadLatestMods.ps1" -ForegroundColor $Colors.Info
Write-Host "3. To test server compatibility, run: .\scripts\TestLatestMods.ps1" -ForegroundColor $Colors.Info

Write-Success "Current mods download completed!" 