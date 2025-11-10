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
    New-Item -ItemType Directory -Path (Join-Path $DestinationPath "server") -Force | Out-Null
    
    # Read mod database
    $mods = Import-Csv -Path $CsvPath

    # Build expected file sets to avoid copying extras/duplicates
    $expectedList = Get-ExpectedReleaseFiles -Version $TargetGameVersion -CsvPath $CsvPath
    $expectedModsSet = New-Object System.Collections.Generic.HashSet[string]
    $expectedModsBaseSet = New-Object System.Collections.Generic.HashSet[string]
    $expectedOptSet = New-Object System.Collections.Generic.HashSet[string]
    $expectedServerSet = New-Object System.Collections.Generic.HashSet[string]
    $expectedServerBaseSet = New-Object System.Collections.Generic.HashSet[string]
    function Get-BaseName([string]$fileName) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $m = [System.Text.RegularExpressions.Regex]::Match($name, '^(.*?)(?:[-_]?)(?=\d)')
        $base = if ($m.Success -and $m.Groups.Count -gt 1 -and $m.Groups[1].Value.Trim().Length -gt 0) { $m.Groups[1].Value.TrimEnd('-','_') } else { $name }
        return $base.ToLower()
    }
    foreach ($rel in $expectedList) {
        if ($rel -like 'mods/*' -and $rel -notlike 'mods/optional/*' -and $rel -notlike 'mods/block/*' -and $rel -notlike 'mods/server/*') {
            $expectedModsSet.Add($rel.Substring(5)) | Out-Null  # store filename
            $expectedModsBaseSet.Add((Get-BaseName ($rel.Substring(5)))) | Out-Null
        } elseif ($rel -like 'mods/optional/*') {
            $expectedOptSet.Add($rel.Substring(14)) | Out-Null
        } elseif ($rel -like 'mods/server/*') {
            $expectedServerSet.Add($rel.Substring(12)) | Out-Null
            $expectedServerBaseSet.Add((Get-BaseName ($rel.Substring(12)))) | Out-Null
        }
    }

    # Calculate which exact expected mod filenames are actually available in source (to avoid copying relaxed duplicates when exact exists)
    $sourceJarNamesSet = New-Object System.Collections.Generic.HashSet[string]
    $sourceJarFiles = Get-ChildItem -Path $SourcePath -Filter "*.jar" -File -ErrorAction SilentlyContinue
    foreach ($sf in $sourceJarFiles) { [void]$sourceJarNamesSet.Add($sf.Name) }
    $expectedExactAvailableSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($fname in $expectedModsSet) { if ($sourceJarNamesSet.Contains($fname)) { [void]$expectedExactAvailableSet.Add($fname) } }
    $expectedExactBasesAvailable = New-Object System.Collections.Generic.HashSet[string]
    foreach ($fname in $expectedExactAvailableSet) { [void]$expectedExactBasesAvailable.Add((Get-BaseName $fname)) }
    $copiedBasesSet = New-Object System.Collections.Generic.HashSet[string]

    # Build lookup maps for fast classification
    $groupById = @{}
    $groupByName = @{}
    $clientSideById = @{}
    $clientSideByName = @{}
    $serverSideById = @{}
    $serverSideByName = @{}
    $typeById = @{}
    $typeByName = @{}
    foreach ($m in $mods) {
        $idKey = if ($m.ID) { $m.ID.Trim().ToLower() } else { $null }
        $nameKey = if ($m.Name) { $m.Name.Trim().ToLower() } else { $null }
        $grp = if ($m.Group) { $m.Group.Trim().ToLower() } else { "required" }
        $clientSide = if ($m.ClientSide) { $m.ClientSide.Trim().ToLower() } else { $null }
        $serverSide = if ($m.ServerSide) { $m.ServerSide.Trim().ToLower() } else { $null }
        $type = if ($m.Type) { $m.Type.Trim().ToLower() } else { $null }
        if ($idKey -and -not $groupById.ContainsKey($idKey)) { $groupById[$idKey] = $grp }
        if ($nameKey -and -not $groupByName.ContainsKey($nameKey)) { $groupByName[$nameKey] = $grp }
        if ($idKey -and -not $clientSideById.ContainsKey($idKey)) { $clientSideById[$idKey] = $clientSide }
        if ($nameKey -and -not $clientSideByName.ContainsKey($nameKey)) { $clientSideByName[$nameKey] = $clientSide }
        if ($idKey -and -not $serverSideById.ContainsKey($idKey)) { $serverSideById[$idKey] = $serverSide }
        if ($nameKey -and -not $serverSideByName.ContainsKey($nameKey)) { $serverSideByName[$nameKey] = $serverSide }
        if ($idKey -and -not $typeById.ContainsKey($idKey)) { $typeById[$idKey] = $type }
        if ($nameKey -and -not $typeByName.ContainsKey($nameKey)) { $typeByName[$nameKey] = $type }
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
    $serverOnlyCount = 0
    
    foreach ($jarFile in $sourceJars) {
        # Classify each JAR using CSV Group, defaulting to required
        $info = Get-JarModIdAndName -JarPath $jarFile.FullName
        $idKey = if ($info.Id) { $info.Id.Trim().ToLower() } else { $null }
        $nameKey = if ($info.Name) { $info.Name.Trim().ToLower() } else { $null }

    $grp = $null
    $clientSide = $null
    $serverSide = $null
    $type = $null
        if ($idKey -and $groupById.ContainsKey($idKey)) { $grp = $groupById[$idKey] }
        elseif ($nameKey -and $groupByName.ContainsKey($nameKey)) { $grp = $groupByName[$nameKey] }
        if (-not $grp) { $grp = "required" }

    # If this JAR is expected to be server-only (per expected list), honor that ahead of classification
    $base = Get-BaseName $jarFile.Name
    if ($expectedServerSet.Contains($jarFile.Name) -or ($expectedServerBaseSet.Contains($base) -and -not $expectedExactBasesAvailable.Contains($base) -and -not $copiedBasesSet.Contains("server::" + $base))) {
        $serverDestDir = Join-Path $DestinationPath 'server'
        if (-not (Test-Path $serverDestDir)) { New-Item -ItemType Directory -Path $serverDestDir -Force | Out-Null }
        $destination = Join-Path $serverDestDir $jarFile.Name
        Copy-Item -Path $jarFile.FullName -Destination $destination -Force
        Write-Host "  🛡️  Server-only: $($jarFile.Name)" -ForegroundColor DarkCyan
        [void]$copiedBasesSet.Add("server::" + $base)
        $serverOnlyCount++
        continue
    }

    if ($idKey -and $clientSideById.ContainsKey($idKey)) { $clientSide = $clientSideById[$idKey] }
    elseif ($nameKey -and $clientSideByName.ContainsKey($nameKey)) { $clientSide = $clientSideByName[$nameKey] }
    if ($idKey -and $serverSideById.ContainsKey($idKey)) { $serverSide = $serverSideById[$idKey] }
    elseif ($nameKey -and $serverSideByName.ContainsKey($nameKey)) { $serverSide = $serverSideByName[$nameKey] }
    if ($idKey -and $typeById.ContainsKey($idKey)) { $type = $typeById[$idKey] }
    elseif ($nameKey -and $typeByName.ContainsKey($nameKey)) { $type = $typeByName[$nameKey] }

    # Server-only classification rule (simplified): only when client_side == unsupported OR type explicitly server/launcher/installer
    $isServerOnly = $false
    if ($clientSide -eq 'unsupported') { $isServerOnly = $true }
    if ($type -in @('server','launcher','installer')) { $isServerOnly = $true }

        if ($isServerOnly) {
            # Only copy server-only files that are expected; allow relaxed-version fallback if the exact expected isn't available
            $serverDestDir = Join-Path $DestinationPath 'server'
            $base = Get-BaseName $jarFile.Name
            $shouldCopyServer = $false
            if ($expectedServerSet.Contains($jarFile.Name)) {
                $shouldCopyServer = $true
            } elseif ($expectedServerBaseSet.Contains($base) -and -not $expectedExactBasesAvailable.Contains($base)) {
                # Exact expected server file not present in source; allow relaxed fallback
                $shouldCopyServer = -not $copiedBasesSet.Contains("server::" + $base)
            }
            if (-not $shouldCopyServer) { continue }
            if (-not (Test-Path $serverDestDir)) { New-Item -ItemType Directory -Path $serverDestDir -Force | Out-Null }
            $destination = Join-Path $serverDestDir $jarFile.Name
            Copy-Item -Path $jarFile.FullName -Destination $destination -Force
            Write-Host "  🛡️  Server-only: $($jarFile.Name)" -ForegroundColor DarkCyan
            [void]$copiedBasesSet.Add("server::" + $base)
            $serverOnlyCount++
            continue
        }

        switch ($grp) {
            "admin" {
                if (-not $expectedOptSet.Contains($jarFile.Name)) { continue }
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
                $base = Get-BaseName $jarFile.Name
                $isExactExpected = $expectedModsSet.Contains($jarFile.Name)
                if (-not $isExactExpected) {
                    # Allow relaxed-version only if base is expected AND an exact expected for this base is NOT available in source
                    if (-not $expectedModsBaseSet.Contains($base)) { continue }
                    if ($expectedExactBasesAvailable.Contains($base)) { continue }
                    # Avoid copying multiple relaxed variants for the same base
                    if ($copiedBasesSet.Contains($base)) { continue }
                    Write-Host "  ✓ Required (relaxed-version): $($jarFile.Name)" -ForegroundColor DarkGreen
                }
                $destination = Join-Path $DestinationPath $jarFile.Name
                Copy-Item -Path $jarFile.FullName -Destination $destination -Force
                Write-Host "  ✓ Required: $($jarFile.Name)" -ForegroundColor Green
                [void]$copiedBasesSet.Add($base)
                $mandatoryCount++
            }
        }
    }
    
    Write-Host "" -ForegroundColor White
    Write-Host "📊 Organization Summary:" -ForegroundColor Cyan
    Write-Host "   ✓ Mandatory mods: $mandatoryCount" -ForegroundColor Green
    Write-Host "   📦 Optional mods: $optionalCount" -ForegroundColor Gray
    Write-Host "   ⛔ Blocked mods:  $blockedCount" -ForegroundColor DarkGray
    Write-Host "   🛡️  Server-only:   $serverOnlyCount" -ForegroundColor DarkCyan
    
    return $true
}

