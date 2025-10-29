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
    New-Item -ItemType Directory -Path (Join-Path $DestinationPath "block") -Force | Out-Null
    
    # Read mod database
    $mods = Import-Csv -Path $CsvPath

    # Build lookup maps for fast classification
    $groupById = @{}
    $groupByName = @{}
    foreach ($m in $mods) {
        $idKey = if ($m.ID) { $m.ID.Trim().ToLower() } else { $null }
        $nameKey = if ($m.Name) { $m.Name.Trim().ToLower() } else { $null }
        $grp = if ($m.Group) { $m.Group.Trim().ToLower() } else { "required" }
        if ($idKey -and -not $groupById.ContainsKey($idKey)) { $groupById[$idKey] = $grp }
        if ($nameKey -and -not $groupByName.ContainsKey($nameKey)) { $groupByName[$nameKey] = $grp }
    }

    function Get-JarModIdAndName {
        param([string]$JarPath)
        $result = @{ Id = $null; Name = [System.IO.Path]::GetFileNameWithoutExtension($JarPath) }
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
            $zip = [System.IO.Compression.ZipFile]::OpenRead($JarPath)
            $entry = $zip.GetEntry("fabric.mod.json")
            if ($entry) {
                $tempBase = Join-Path $PSScriptRoot "..\..\tools\minecraft-mod-hash\tests\temp"
                if (-not (Test-Path $tempBase)) { New-Item -ItemType Directory -Path $tempBase -Force | Out-Null }
                $tmp = Join-Path $tempBase ([System.Guid]::NewGuid().ToString() + "-fabric.mod.json")
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tmp, $true)
                if (Test-Path $tmp) {
                    $json = Get-Content $tmp -Raw | ConvertFrom-Json
                    if ($json.id) { $result.Id = $json.id }
                    if ($json.name) { $result.Name = $json.name }
                    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                }
            }
            $zip.Dispose()
        } catch { }
        return $result
    }
    
    # Get all JAR files from source
    $sourceJars = Get-ChildItem -Path $SourcePath -Filter "*.jar" -File -ErrorAction SilentlyContinue
    
    if ($sourceJars.Count -eq 0) {
        Write-Host "⚠️  No JAR files found in source path" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "📊 Found $($sourceJars.Count) JAR files in source" -ForegroundColor Gray
    
    $mandatoryCount = 0
    $optionalCount = 0
    $blockedCount = 0
    
    foreach ($jarFile in $sourceJars) {
        # Classify each JAR using CSV Group, defaulting to required
        $info = Get-JarModIdAndName -JarPath $jarFile.FullName
        $idKey = if ($info.Id) { $info.Id.Trim().ToLower() } else { $null }
        $nameKey = if ($info.Name) { $info.Name.Trim().ToLower() } else { $null }

        $grp = $null
        if ($idKey -and $groupById.ContainsKey($idKey)) { $grp = $groupById[$idKey] }
        elseif ($nameKey -and $groupByName.ContainsKey($nameKey)) { $grp = $groupByName[$nameKey] }
        if (-not $grp) { $grp = "required" }

        switch ($grp) {
            "optional" {
                $destination = Join-Path (Join-Path $DestinationPath "optional") $jarFile.Name
                Copy-Item -Path $jarFile.FullName -Destination $destination -Force
                Write-Host "  📦 Optional: $($jarFile.Name)" -ForegroundColor Yellow
                $optionalCount++
            }
            "block" {
                $destination = Join-Path (Join-Path $DestinationPath "block") $jarFile.Name
                Copy-Item -Path $jarFile.FullName -Destination $destination -Force
                Write-Host "  ⛔ Blocked: $($jarFile.Name)" -ForegroundColor DarkRed
                $blockedCount++
            }
            default {
                $destination = Join-Path $DestinationPath $jarFile.Name
                Copy-Item -Path $jarFile.FullName -Destination $destination -Force
                Write-Host "  ✓ Required: $($jarFile.Name)" -ForegroundColor Green
                $mandatoryCount++
            }
        }
    }
    
    Write-Host "" -ForegroundColor White
    Write-Host "📊 Organization Summary:" -ForegroundColor Cyan
    Write-Host "   ✓ Mandatory mods: $mandatoryCount" -ForegroundColor Green
    Write-Host "   📦 Optional mods: $optionalCount" -ForegroundColor Gray
    Write-Host "   ⛔ Blocked mods:  $blockedCount" -ForegroundColor DarkGray
    
    return $true
}

