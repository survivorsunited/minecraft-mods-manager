# =============================================================================
# Release Creation Module
# =============================================================================
# This module handles the complete release package creation workflow.
# =============================================================================

<#
.SYNOPSIS
    Creates a complete release package for a specific Minecraft version.

.DESCRIPTION
    Orchestrates the full release creation workflow:
    1. Determines target version
    2. Downloads mods for the version
    3. Downloads server files
    4. Validates mods by starting server
    5. Organizes mods into release structure
    6. Generates hashes and documentation
    7. Creates ZIP package

.PARAMETER CsvPath
    Path to the mod database CSV file.

.PARAMETER DownloadFolder
    Path to the download folder.

.PARAMETER ApiResponseFolder
    Path to the API response cache folder.

.PARAMETER ReleasePath
    Path where release packages will be created.

.PARAMETER TargetVersion
    Specific version to target for release.

.PARAMETER GameVersion
    Game version to use (alternative to TargetVersion).

.PARAMETER UseLatestVersion
    Use the latest game version.

.PARAMETER UseNextVersion
    Use the next game version.

.PARAMETER NoAutoRestart
    Disable automatic server restart during validation.

.PARAMETER ProjectRoot
    Root directory of the project (for finding hash script).

.EXAMPLE
    New-Release -CsvPath "modlist.csv" -DownloadFolder "download" -ReleasePath "releases" -GameVersion "1.21.5"

.NOTES
    - Exits with code 0 on success
    - Exits with code 1 on failure
    - Performs server validation before creating release
#>
function New-Release {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        
        [Parameter(Mandatory=$true)]
        [string]$DownloadFolder,
        
        [Parameter(Mandatory=$true)]
        [string]$ApiResponseFolder,
        
        [Parameter(Mandatory=$true)]
        [string]$ReleasePath,
        
        [Parameter(Mandatory=$false)]
        [string]$TargetVersion,
        
        [Parameter(Mandatory=$false)]
        [string]$GameVersion,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseLatestVersion,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseNextVersion,
        
        [Parameter(Mandatory=$false)]
        [switch]$NoAutoRestart,
        
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot
    )
    
    Write-Host "Creating release package..." -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    
    # Determine target version
    if ($TargetVersion) {
        $targetVersion = $TargetVersion
        Write-Host "🎯 Target version: $targetVersion (user specified via TargetVersion)" -ForegroundColor Green
    } elseif ($GameVersion) {
        $targetVersion = $GameVersion
        Write-Host "🎯 Target version: $targetVersion (user specified via GameVersion)" -ForegroundColor Green
    } elseif ($UseLatestVersion) {
        $targetVersion = Get-LatestVersion -CsvPath $CsvPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine latest game version" -ForegroundColor Red
            return $false
        }
        Write-Host "🎯 Target version: $targetVersion (LATEST version)" -ForegroundColor Green
    } elseif ($UseNextVersion) {
        $targetVersion = Get-NextVersion -CsvPath $CsvPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine next game version" -ForegroundColor Red
            return $false
        }
        Write-Host "🎯 Target version: $targetVersion (NEXT version)" -ForegroundColor Green
    } else {
        $targetVersion = Get-CurrentVersion -CsvPath $CsvPath
        if (-not $targetVersion) {
            Write-Host "❌ Failed to determine current game version" -ForegroundColor Red
            return $false
        }
        Write-Host "🎯 Target version: $targetVersion (CURRENT version - default)" -ForegroundColor Green
    }
    
    Write-Host "" -ForegroundColor White
    
    # Step 1: Download mods for target version
    Write-Host "📦 Downloading mods for version $targetVersion..." -ForegroundColor Cyan
    Download-Mods -CsvPath $CsvPath -DownloadFolder $DownloadFolder -ApiResponseFolder $ApiResponseFolder -TargetGameVersion $targetVersion
    
    Write-Host "" -ForegroundColor White
    
    # Step 2: Download server files
    Write-Host "📦 Downloading server files for version $targetVersion..." -ForegroundColor Cyan
    Download-ServerFiles -DownloadFolder $DownloadFolder -ForceDownload:$false -GameVersion $targetVersion
    
    Write-Host "" -ForegroundColor White
    
    # Step 3: VALIDATION GATE - Start server to verify compatibility
    Write-Host "🧪 Validating mods by starting server..." -ForegroundColor Yellow
    Write-Host "   This ensures all mods are compatible before creating release package" -ForegroundColor Gray
    Write-Host "" -ForegroundColor White
    
    $serverParams = @{
        DownloadFolder = $DownloadFolder
        TargetVersion = $targetVersion
        CsvPath = $CsvPath
    }
    if ($NoAutoRestart) {
        $serverParams.Add("NoAutoRestart", $true)
    }
    
    $serverResult = Start-MinecraftServer @serverParams
    
    if (-not $serverResult) {
        Write-Host "" -ForegroundColor White
        Write-Host "❌ SERVER VALIDATION FAILED - Release creation aborted!" -ForegroundColor Red
        Write-Host "💡 This version has mod compatibility issues and cannot be released." -ForegroundColor Yellow
        Write-Host "💡 Fix the mod compatibility issues before creating a release package." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "" -ForegroundColor White
    Write-Host "✅ Server validation passed - proceeding with release creation" -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    
    # Step 4: Create release directory structure
    $releaseDir = Join-Path $ReleasePath $targetVersion
    $releaseModsPath = Join-Path $releaseDir "mods"
    
    Write-Host "📁 Creating release directory: $releaseDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    
    # Step 5: Organize mods into mandatory/optional structure
    $sourceModsPath = Join-Path $DownloadFolder "$targetVersion\mods"
    $organizeResult = Copy-ModsToRelease -SourcePath $sourceModsPath -DestinationPath $releaseModsPath -CsvPath $CsvPath -TargetGameVersion $targetVersion
    
    if (-not $organizeResult) {
        Write-Host "❌ Failed to organize mods for release" -ForegroundColor Red
        return $false
    }
    
    Write-Host "" -ForegroundColor White
    
    # Step 6: Run hash generator to create documentation and ZIP
    Write-Host "📦 Generating hashes and documentation..." -ForegroundColor Cyan
    $hashScriptPath = Join-Path $ProjectRoot "tools\minecraft-mod-hash\hash.ps1"
    
    if (-not (Test-Path $hashScriptPath)) {
        Write-Host "❌ Hash generator not found: $hashScriptPath" -ForegroundColor Red
        Write-Host "💡 Ensure the minecraft-mod-hash submodule is initialized:" -ForegroundColor Yellow
        Write-Host "   git submodule update --init --recursive" -ForegroundColor Gray
        return $false
    }
    
    try {
        & $hashScriptPath -ModsPath $releaseModsPath -OutputPath $releaseDir -CreateZip -UpdateConfig
        
        # Verify critical files were created (don't rely on exit code)
        $hashFile = Join-Path $releaseDir "hash.txt"
        $readmeFile = Join-Path $releaseDir "README.md"
        $zipFiles = Get-ChildItem -Path $releaseDir -Filter "*.zip" -File -ErrorAction SilentlyContinue
        
        if (-not (Test-Path $hashFile)) {
            Write-Host "❌ Hash file not created: $hashFile" -ForegroundColor Red
            return $false
        }
        if (-not (Test-Path $readmeFile)) {
            Write-Host "❌ README file not created: $readmeFile" -ForegroundColor Red
            return $false
        }
        if ($zipFiles.Count -eq 0) {
            Write-Host "❌ ZIP package not created" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Error running hash generator: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    Write-Host "" -ForegroundColor White
    Write-Host "✅ Release package created successfully!" -ForegroundColor Green
    Write-Host "📂 Location: $releaseDir" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    Write-Host "📦 Package contents:" -ForegroundColor Cyan
    Write-Host "   - mods/ (mandatory mods)" -ForegroundColor Gray
    Write-Host "   - mods/optional/ (optional mods)" -ForegroundColor Gray
    Write-Host "   - hash.txt (MD5 hashes)" -ForegroundColor Gray
    Write-Host "   - README.md (documentation)" -ForegroundColor Gray
    Write-Host "   - InertiaAntiCheat.toml (IAC config)" -ForegroundColor Gray
    
    # Check if ZIP was created
    $zipFiles = Get-ChildItem -Path $releaseDir -Filter "*.zip" -File -ErrorAction SilentlyContinue
    if ($zipFiles.Count -gt 0) {
        Write-Host "   - $($zipFiles[0].Name) (packaged release)" -ForegroundColor Gray
    }
    
    return $true
}

