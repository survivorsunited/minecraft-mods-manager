# TestLatestMods.ps1
# Tests latest mod versions with latest Minecraft server
# 
# This script performs the complete latest mods testing workflow:
# 1. Update mod database to latest versions
# 2. Download latest mods
# 3. Download latest server files
# 4. Start server to test compatibility
#
# Usage: .\scripts\TestLatestMods.ps1 [-DownloadFolder "path"] [-DatabaseFile "path"]

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
Write-Header "Testing Latest Mod Versions with Latest Server"
Write-Host "This script will test the latest versions of all mods with the latest Minecraft server." -ForegroundColor $Colors.Info
Write-Host "Download Folder: $DownloadFolder" -ForegroundColor $Colors.Info
Write-Host "Database File: $DatabaseFile" -ForegroundColor $Colors.Info

# Validate prerequisites
Write-Step "VALIDATION" "Checking prerequisites..."
Test-ModManagerExists
Test-DatabaseExists
Write-Success "Prerequisites validated"

# Build common parameters
$commonParams = "-DatabaseFile `"$DatabaseFile`" -DownloadFolder `"$DownloadFolder`" -UseCachedResponses"

# Step 1: Update mod database to latest versions
Write-Step "STEP 1" "Updating mod database to latest versions"
$updateCommand = "& `"$ModManagerPath`" -UpdateMods $commonParams"
$updateSuccess = Invoke-ModManagerCommand -Command $updateCommand -StepName "UPDATE" -SuccessMessage "Mod database updated successfully" -ErrorMessage "Failed to update mod database"

if (-not $updateSuccess) {
    Write-Warning "Mod database update failed, but continuing with existing data..."
}

# Step 2: Download latest mods
Write-Step "STEP 2" "Downloading latest mods"
$downloadCommand = "& `"$ModManagerPath`" -Download -UseLatestVersion $commonParams"
$downloadSuccess = Invoke-ModManagerCommand -Command $downloadCommand -StepName "DOWNLOAD" -SuccessMessage "Latest mods downloaded successfully" -ErrorMessage "Failed to download latest mods"

if (-not $downloadSuccess) {
    Write-Error "Mod download failed. Cannot proceed with server testing."
    exit 1
}

# Step 3: Download latest server files
Write-Step "STEP 3" "Downloading latest server files"
$serverCommand = "& `"$ModManagerPath`" -DownloadServer -DownloadFolder `"$DownloadFolder`" -UseCachedResponses"
$serverSuccess = Invoke-ModManagerCommand -Command $serverCommand -StepName "SERVER" -SuccessMessage "Server files downloaded successfully" -ErrorMessage "Failed to download server files"

if (-not $serverSuccess) {
    Write-Error "Server download failed. Cannot proceed with server testing."
    exit 1
}

# Step 4: Start server to test compatibility
Write-Step "STEP 4" "Starting server to test compatibility"
$startCommand = "& `"$ModManagerPath`" -StartServer -DownloadFolder `"$DownloadFolder`""
$startSuccess = Invoke-ModManagerCommand -Command $startCommand -StepName "START" -SuccessMessage "Server started successfully - all mods are compatible!" -ErrorMessage "Server startup failed - compatibility issues detected"

if (-not $startSuccess) {
    Write-Warning "Server startup failed. This may indicate compatibility issues."
    Write-Host "`nCheck the server logs in $DownloadFolder for detailed error messages." -ForegroundColor $Colors.Warning
    Write-Host "Common issues:" -ForegroundColor $Colors.Warning
    Write-Host "  - Missing dependencies (e.g., Fabric API)" -ForegroundColor $Colors.Warning
    Write-Host "  - Version conflicts between mods" -ForegroundColor $Colors.Warning
    Write-Host "  - Minecraft version mismatches" -ForegroundColor $Colors.Warning
}

# Summary
Write-Header "Latest Mods Testing Complete"
Write-Host "Download Folder: $DownloadFolder" -ForegroundColor $Colors.Info
Write-Host "Database File: $DatabaseFile" -ForegroundColor $Colors.Info

if (Test-Path $DownloadFolder) {
    $modCount = (Get-ChildItem -Path "$DownloadFolder\*\mods\*.jar" -Recurse -ErrorAction SilentlyContinue).Count
    Write-Host "Mods Downloaded: $modCount" -ForegroundColor $Colors.Info
}

Write-Host "`nNext Steps:" -ForegroundColor $Colors.Info
Write-Host "1. Check server logs for any compatibility issues" -ForegroundColor $Colors.Info
Write-Host "2. Review downloaded mods in: $DownloadFolder" -ForegroundColor $Colors.Info
Write-Host "3. If issues found, check the troubleshooting guide in USECASE_LATEST_MODS_TESTING.md" -ForegroundColor $Colors.Info

Write-Success "Latest mods testing completed!" 