# =============================================================================
# Validate Mod Version URLs Function
# =============================================================================
# Validates that mod URLs match the expected GameVersion and fixes mismatches
# =============================================================================

<#
.SYNOPSIS
    Validates and fixes mod version URL mismatches in the database.

.DESCRIPTION
    This function checks if mod download URLs actually match the GameVersion
    specified in the database. It detects mismatches where a 1.21.5 entry
    has URLs pointing to 1.21.6 or other versions, and attempts to fix them.

.PARAMETER CsvPath
    Path to the mod database CSV file.

.PARAMETER DryRun
    If specified, only reports issues without making changes.

.PARAMETER BackupDatabase
    Whether to create a backup before making changes (default: true).

.EXAMPLE
    Validate-ModVersionUrls -CsvPath "modlist.csv" -DryRun
    
.EXAMPLE
    Validate-ModVersionUrls -CsvPath "modlist.csv"

.NOTES
    - Creates backups before modifying the database
    - Uses Modrinth API to find correct version URLs
    - Reports all detected mismatches
#>
function Validate-ModVersionUrls {
    param(
        [string]$CsvPath = "modlist.csv",
        [switch]$DryRun,
        [switch]$BackupDatabase = $true
    )
    
    # Import provider functions
    $scriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . "$scriptRoot\Provider\Modrinth\Get-ModrinthProjectInfo.ps1"
    . "$scriptRoot\Provider\CurseForge\Get-CurseForgeProjectInfo.ps1"
    . "$scriptRoot\Database\Operations\Update-ModUrlInDatabase.ps1"
    
    try {
        Write-Host "🔍 Validating mod version URLs in database..." -ForegroundColor Cyan
        Write-Host "Database: $CsvPath" -ForegroundColor Gray
        Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'REPAIR MODE' })" -ForegroundColor Gray
        Write-Host ""
        
        # Load database
        if (-not (Test-Path $CsvPath)) {
            throw "Database file not found: $CsvPath"
        }
        
        $mods = Import-Csv -Path $CsvPath
        Write-Host "📊 Loaded $($mods.Count) entries from database" -ForegroundColor Green
        
        # Create backup if not dry run
        if (-not $DryRun -and $BackupDatabase) {
            $backupDir = "backups"
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backupPath = Join-Path $backupDir "$timestamp-validation-backup-$(Split-Path $CsvPath -Leaf)"
            Copy-Item -Path $CsvPath -Destination $backupPath -Force
            Write-Host "💾 Created backup: $backupPath" -ForegroundColor Green
        }
        
        # Track issues found
        $issuesFound = @()
        $fixesApplied = @()
        
        Write-Host "🔍 Scanning for version/URL mismatches..." -ForegroundColor Yellow
        
        foreach ($mod in $mods) {
            # Skip entries without version info
            if ([string]::IsNullOrEmpty($mod.GameVersion)) {
                continue
            }
            
            # Check CurrentVersionUrl field (current version download URL)
            $currentUrlMatch = $null
            if (-not [string]::IsNullOrEmpty($mod.CurrentVersionUrl) -and $mod.CurrentVersionUrl -match "1\.2[0-9]") {
                $urlVersions = [regex]::Matches($mod.CurrentVersionUrl, "1\.2[0-9](?:\.[0-9]+)?")
                $currentUrlMatch = $urlVersions | Select-Object -Last 1 | ForEach-Object { $_.Value }
            }
            
            # Check NextVersionUrl field (next version download URL)
            $nextUrlMatch = $null
            if (-not [string]::IsNullOrEmpty($mod.NextVersionUrl) -and $mod.NextVersionUrl -match "1\.2[0-9]") {
                $urlVersions = [regex]::Matches($mod.NextVersionUrl, "1\.2[0-9](?:\.[0-9]+)?")
                $nextUrlMatch = $urlVersions | Select-Object -Last 1 | ForEach-Object { $_.Value }
            }
            
            # Check LatestVersionUrl field (latest version download URL) 
            $latestUrlMatch = $null
            if (-not [string]::IsNullOrEmpty($mod.LatestVersionUrl) -and $mod.LatestVersionUrl -match "1\.2[0-9]") {
                $urlVersions = [regex]::Matches($mod.LatestVersionUrl, "1\.2[0-9](?:\.[0-9]+)?")
                $latestUrlMatch = $urlVersions | Select-Object -Last 1 | ForEach-Object { $_.Value }
            }
            
            # Check for mismatches in CurrentVersionUrl
            if ($currentUrlMatch -and $currentUrlMatch -ne $mod.CurrentGameVersion) {
                $issue = [PSCustomObject]@{
                    Name = $mod.Name
                    ID = $mod.ID
                    ExpectedVersion = $mod.CurrentGameVersion
                    UrlVersion = $currentUrlMatch
                    CurrentUrl = $mod.CurrentVersionUrl
                    UrlType = "CurrentVersionUrl"
                    Type = $mod.Type
                    Host = $mod.Host
                }
                $issuesFound += $issue
                
                Write-Host "⚠️  MISMATCH: $($mod.Name) [CurrentVersionUrl]" -ForegroundColor Red
                Write-Host "   Expected: MC $($mod.CurrentGameVersion)" -ForegroundColor Yellow
                Write-Host "   URL has:  MC $currentUrlMatch" -ForegroundColor Red
                Write-Host "   URL: $($mod.CurrentVersionUrl)" -ForegroundColor Gray
                Write-Host ""
            }
            
            # Check for mismatches in NextVersionUrl
            if ($nextUrlMatch -and $nextUrlMatch -ne $mod.NextGameVersion) {
                $issue = [PSCustomObject]@{
                    Name = $mod.Name
                    ID = $mod.ID
                    ExpectedVersion = $mod.NextGameVersion
                    UrlVersion = $nextUrlMatch
                    CurrentUrl = $mod.NextVersionUrl
                    UrlType = "NextVersionUrl"
                    Type = $mod.Type
                    Host = $mod.Host
                }
                $issuesFound += $issue
                
                Write-Host "⚠️  MISMATCH: $($mod.Name) [NextVersionUrl]" -ForegroundColor Red
                Write-Host "   Expected: MC $($mod.NextGameVersion)" -ForegroundColor Yellow
                Write-Host "   URL has:  MC $nextUrlMatch" -ForegroundColor Red
                Write-Host "   URL: $($mod.NextVersionUrl)" -ForegroundColor Gray
                Write-Host ""
            }
            
            # Check for mismatches in LatestVersionUrl  
            if ($latestUrlMatch -and $latestUrlMatch -ne $mod.LatestGameVersion) {
                $issue = [PSCustomObject]@{
                    Name = $mod.Name
                    ID = $mod.ID
                    ExpectedVersion = $mod.LatestGameVersion
                    UrlVersion = $latestUrlMatch
                    CurrentUrl = $mod.LatestVersionUrl
                    UrlType = "LatestVersionUrl"
                    Type = $mod.Type
                    Host = $mod.Host
                }
                $issuesFound += $issue
                
                Write-Host "⚠️  MISMATCH: $($mod.Name) [LatestVersionUrl]" -ForegroundColor Red
                Write-Host "   Expected: MC $($mod.LatestGameVersion)" -ForegroundColor Yellow
                Write-Host "   URL has:  MC $latestUrlMatch" -ForegroundColor Red
                Write-Host "   URL: $($mod.LatestVersionUrl)" -ForegroundColor Gray
                Write-Host ""
            }
        }
        
        # Report findings
        Write-Host "📋 VALIDATION SUMMARY" -ForegroundColor Cyan
        Write-Host "=====================" -ForegroundColor Cyan
        Write-Host "Total entries scanned: $($mods.Count)" -ForegroundColor Gray
        Write-Host "Version mismatches found: $($issuesFound.Count)" -ForegroundColor $(if ($issuesFound.Count -gt 0) { 'Red' } else { 'Green' })
        
        if ($issuesFound.Count -gt 0) {
            Write-Host ""
            Write-Host "🔧 DETECTED ISSUES BY GAME VERSION:" -ForegroundColor Yellow
            $issuesByVersion = $issuesFound | Group-Object ExpectedVersion | Sort-Object Name
            foreach ($group in $issuesByVersion) {
                Write-Host "  MC $($group.Name): $($group.Count) mods with wrong URLs" -ForegroundColor Red
                foreach ($issue in $group.Group | Select-Object -First 3) {
                    Write-Host "    - $($issue.Name) (URL has MC $($issue.UrlVersion))" -ForegroundColor Gray
                }
                if ($group.Count -gt 3) {
                    Write-Host "    ... and $($group.Count - 3) more" -ForegroundColor Gray
                }
            }
            
            Write-Host ""
            Write-Host "💡 RECOMMENDATIONS:" -ForegroundColor Cyan
            Write-Host "  1. Run without -DryRun to attempt automatic fixes" -ForegroundColor Green
            Write-Host "  2. Check if newer versions of these mods support the target Minecraft version" -ForegroundColor Green
            Write-Host "  3. Consider updating incompatible mods to correct versions" -ForegroundColor Green
            
            if (-not $DryRun) {
                Write-Host ""
                Write-Host "🔨 ATTEMPTING AUTOMATIC FIXES..." -ForegroundColor Yellow
                Write-Host "⚠️  Note: This will query APIs to find correct versions" -ForegroundColor Yellow
                
                $fixedCount = 0
                $failedFixes = @()
                
                # Group issues by mod to avoid duplicate API calls
                $issuesByMod = $issuesFound | Group-Object Name, ID, Host
                
                foreach ($modGroup in $issuesByMod) {
                    $issue = $modGroup.Group[0]
                    Write-Host ""
                    Write-Host "🔧 Fixing: $($issue.Name) (MC $($issue.ExpectedVersion))" -ForegroundColor Cyan
                    
                    try {
                        # Query the appropriate API based on host
                        $projectInfo = $null
                        if ($issue.Host -eq "modrinth.com") {
                            Write-Host "   📡 Querying Modrinth API..." -ForegroundColor Gray
                            $projectInfo = Get-ModrinthProjectInfo -ProjectId $issue.ID
                        } elseif ($issue.Host -eq "curseforge.com") {
                            Write-Host "   📡 Querying CurseForge API..." -ForegroundColor Gray
                            $projectInfo = Get-CurseForgeProjectInfo -ProjectId $issue.ID
                        }
                        
                        if (-not $projectInfo) {
                            Write-Host "   ❌ Failed to get project info from API" -ForegroundColor Red
                            $failedFixes += $issue
                            continue
                        }
                        
                        # Find the correct version for the expected game version
                        $targetVersion = $issue.ExpectedVersion
                        $correctVersion = $null
                        
                        # First, try to find exact match
                        $correctVersion = $projectInfo.versions | Where-Object {
                            $_.game_versions -contains $targetVersion
                        } | Sort-Object date_published -Descending | Select-Object -First 1
                        
                        # If no exact match, find closest compatible version
                        if (-not $correctVersion) {
                            Write-Host "   ⚠️  No exact match for MC $targetVersion, searching for compatible version..." -ForegroundColor Yellow
                            
                            # Parse target version
                            $targetParts = $targetVersion -split '\.'
                            $targetMajor = [int]$targetParts[0]
                            $targetMinor = [int]$targetParts[1]
                            $targetPatch = if ($targetParts.Count -gt 2) { [int]$targetParts[2] } else { 0 }
                            
                            # Find the closest lower version
                            $compatibleVersions = $projectInfo.versions | Where-Object {
                                $gameVersions = $_.game_versions | Where-Object { $_ -match '^1\.2[0-9]' }
                                foreach ($gv in $gameVersions) {
                                    $gvParts = $gv -split '\.'
                                    $gvMajor = [int]$gvParts[0]
                                    $gvMinor = [int]$gvParts[1]
                                    $gvPatch = if ($gvParts.Count -gt 2) { [int]$gvParts[2] } else { 0 }
                                    
                                    # Accept if same major.minor or lower
                                    if ($gvMajor -eq $targetMajor -and $gvMinor -le $targetMinor) {
                                        return $true
                                    }
                                }
                                return $false
                            } | Sort-Object {
                                # Sort by closest version
                                $gameVersions = $_.game_versions | Where-Object { $_ -match '^1\.2[0-9]' }
                                $closest = $gameVersions | ForEach-Object {
                                    $gvParts = $_ -split '\.'
                                    $gvMinor = [int]$gvParts[1]
                                    $gvPatch = if ($gvParts.Count -gt 2) { [int]$gvParts[2] } else { 0 }
                                    [PSCustomObject]@{
                                        Version = $_
                                        Score = ($targetMinor - $gvMinor) * 100 + ($targetPatch - $gvPatch)
                                    }
                                } | Sort-Object Score | Select-Object -First 1
                                $closest.Score
                            } -Descending
                            
                            $correctVersion = $compatibleVersions | Select-Object -First 1
                        }
                        
                        if ($correctVersion) {
                            # Get the download URL
                            $downloadUrl = $null
                            if ($correctVersion.files -and $correctVersion.files.Count -gt 0) {
                                $downloadUrl = $correctVersion.files[0].url
                            }
                            
                            if ($downloadUrl) {
                                # Update the database
                                $actualGameVersion = $correctVersion.game_versions | Where-Object { $_ -match '^1\.2[0-9]' } | Select-Object -First 1
                                Write-Host "   ✅ Found version: $($correctVersion.version_number) (MC $actualGameVersion)" -ForegroundColor Green
                                Write-Host "   📝 Updating database..." -ForegroundColor Gray
                                
                                # Update the mod in database
                                Update-ModUrlInDatabase -ModName $issue.Name `
                                    -GameVersion $issue.ExpectedVersion `
                                    -NewUrl $downloadUrl `
                                    -UrlType $issue.UrlType `
                                    -CsvPath $CsvPath `
                                    -BackupDatabase 0  # Already backed up
                                
                                $fixedCount++
                                Write-Host "   ✅ Fixed!" -ForegroundColor Green
                            } else {
                                Write-Host "   ❌ No download URL found in version info" -ForegroundColor Red
                                $failedFixes += $issue
                            }
                        } else {
                            Write-Host "   ❌ No compatible version found for MC $targetVersion" -ForegroundColor Red
                            $failedFixes += $issue
                        }
                        
                    } catch {
                        Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                        $failedFixes += $issue
                    }
                }
                
                Write-Host ""
                Write-Host "📊 FIX SUMMARY" -ForegroundColor Cyan
                Write-Host "===============" -ForegroundColor Cyan
                Write-Host "Successfully fixed: $fixedCount" -ForegroundColor Green
                Write-Host "Failed to fix: $($failedFixes.Count)" -ForegroundColor Red
                
                if ($failedFixes.Count -gt 0) {
                    Write-Host ""
                    Write-Host "❌ The following mods need manual attention:" -ForegroundColor Red
                    foreach ($failed in $failedFixes) {
                        Write-Host "   - $($failed.Name): Update URL for MC $($failed.ExpectedVersion)" -ForegroundColor Yellow
                    }
                }
            }
        } else {
            Write-Host ""
            Write-Host "✅ No version/URL mismatches detected!" -ForegroundColor Green
            Write-Host "   All mod URLs appear to match their expected game versions." -ForegroundColor Green
        }
        
        return $issuesFound.Count
        
    } catch {
        Write-Host "❌ Validation failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Function is available for dot-sourcing