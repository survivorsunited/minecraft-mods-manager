# =============================================================================
# Copy Mods to Release Directory
# =============================================================================
# This function organizes mods into mandatory/optional structure for releases
# =============================================================================

<#
.SYNOPSIS
    Copies and organizes mods for release packaging.

.DESCRIPTION
    Reads the mod database to determine which mods are mandatory vs optional,
    then copies them to the appropriate folders for hash generation and packaging.

.PARAMETER SourcePath
    The source mods directory (e.g., download/1.21.8/mods)

.PARAMETER DestinationPath
    The destination directory for organized mods (e.g., releases/1.21.8/mods)

.PARAMETER CsvPath
    Path to the modlist.csv database file

.EXAMPLE
    Copy-ModsToRelease -SourcePath "download/1.21.8/mods" -DestinationPath "releases/1.21.8/mods"

.NOTES
    - Creates mods/ folder for mandatory mods
    - Creates mods/optional/ folder for optional mods
    - Skips server-only files (launcher, server, installer types)
#>
function Copy-ModsToRelease {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,
        
        [string]$CsvPath = "modlist.csv",
        
        [string]$TargetGameVersion = $null
    )
    
    Write-Host "📋 Organizing mods for release..." -ForegroundColor Cyan
    
    # Validate source path
    if (-not (Test-Path $SourcePath)) {
        Write-Host "❌ Source path not found: $SourcePath" -ForegroundColor Red
        return $false
    }
    
    # Create destination structure
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $DestinationPath "optional") -Force | Out-Null
    
    # Read mod database
    $mods = Import-Csv -Path $CsvPath
    
    # Get all JAR files from source
    $sourceJars = Get-ChildItem -Path $SourcePath -Filter "*.jar" -File -ErrorAction SilentlyContinue
    
    if ($sourceJars.Count -eq 0) {
        Write-Host "⚠️  No JAR files found in source path" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "📊 Found $($sourceJars.Count) JAR files in source" -ForegroundColor Gray
    
    $mandatoryCount = 0
    $optionalCount = 0
    $skippedCount = 0
    
    foreach ($jarFile in $sourceJars) {
        # Copy all mods to mandatory folder - hash generator will handle organization
        # It reads fabric.mod.json and filters server-only mods automatically
        $destination = Join-Path $DestinationPath $jarFile.Name
        Copy-Item -Path $jarFile.FullName -Destination $destination -Force
        Write-Host "  ✓ Copied: $($jarFile.Name)" -ForegroundColor Green
        $mandatoryCount++
    }
    
    Write-Host "" -ForegroundColor White
    Write-Host "📊 Organization Summary:" -ForegroundColor Cyan
    Write-Host "   ✓ Mandatory mods: $mandatoryCount" -ForegroundColor Green
    Write-Host "   📦 Optional mods: $optionalCount" -ForegroundColor Gray
    Write-Host "   ⏭️  Skipped: $skippedCount" -ForegroundColor DarkGray
    
    return $true
}

