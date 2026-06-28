# =============================================================================
# Rollover Mods to Next Version Module
# =============================================================================
# This module handles rolling over mods from Current to Next versions.
# =============================================================================

<#
.SYNOPSIS
    Rolls over mods to their next version or a specified version.

.DESCRIPTION
    Updates mods in the database by rolling over Current* fields to Next* values,
    or by promoting the best known metadata for a specified game version into
    the Current* fields.

.PARAMETER CsvPath
    Path to the modlist CSV file.

.PARAMETER RolloverToVersion
    Optional: Specific game version to rollover to (e.g., "1.21.11").
    When supplied, the function promotes matching Next* or Latest* metadata into
    CurrentVersion, CurrentVersionUrl, CurrentGameVersion, and Jar.

.PARAMETER DryRun
    Show what would be changed without actually updating the database.

.EXAMPLE
    Rollover-ModsToNextVersion -CsvPath "modlist.csv"
    Rolls over all mods with NextVersion data to their next version.

.EXAMPLE
    Rollover-ModsToNextVersion -CsvPath "modlist.csv" -RolloverToVersion "1.21.11"
    Promotes known 1.21.11 version metadata to Current* fields.

.NOTES
    - Creates backup before making changes
    - Recalculates RecordHash after each changed record
    - Skips infrastructure entries; they are version-specific rows already
#>
function Rollover-ModsToNextVersion {
    param(
        [string]$CsvPath = "modlist.csv",
        [string]$RolloverToVersion = "",
        [switch]$DryRun = $false,
        [string]$ApiResponseFolder = "apiresponse"
    )

    function Get-RolloverArtifactFilename {
        param([string]$Url)

        if ([string]::IsNullOrWhiteSpace($Url)) { return "" }

        try {
            $decoded = [System.Web.HttpUtility]::UrlDecode($Url)
            $withoutQuery = ($decoded -split '\?')[0]
            $name = [System.IO.Path]::GetFileName($withoutQuery)
            if ([string]::IsNullOrWhiteSpace($name)) { return "" }
            return $name
        } catch {
            return ""
        }
    }

    function Get-TargetVersionCandidate {
        param(
            [pscustomobject]$Mod,
            [string]$TargetVersion
        )

        # Prefer exact Next metadata first because this is the normal staged path.
        if ($Mod.NextGameVersion -eq $TargetVersion -and -not [string]::IsNullOrWhiteSpace($Mod.NextVersionUrl)) {
            return [PSCustomObject]@{
                Source = "Next"
                Version = $Mod.NextVersion
                Url = $Mod.NextVersionUrl
                GameVersion = $TargetVersion
            }
        }

        # Then use Latest metadata when it already points at the requested target.
        # This fixes records where CurrentGameVersion was bumped but CurrentVersionUrl
        # still points at an older artifact.
        if ($Mod.LatestGameVersion -eq $TargetVersion -and -not [string]::IsNullOrWhiteSpace($Mod.LatestVersionUrl)) {
            return [PSCustomObject]@{
                Source = "Latest"
                Version = $Mod.LatestVersion
                Url = $Mod.LatestVersionUrl
                GameVersion = $TargetVersion
            }
        }

        # Finally keep current metadata if it is already an exact current target row.
        if ($Mod.CurrentGameVersion -eq $TargetVersion -and -not [string]::IsNullOrWhiteSpace($Mod.CurrentVersionUrl)) {
            return [PSCustomObject]@{
                Source = "Current"
                Version = $Mod.CurrentVersion
                Url = $Mod.CurrentVersionUrl
                GameVersion = $TargetVersion
            }
        }

        return $null
    }

    try {
        # Load mods
        $mods = Import-Csv -Path $CsvPath
        if (-not $mods) {
            Write-Host "❌ No mods found in database" -ForegroundColor Red
            return $false
        }

        Write-Host "🔄 Rollover Mods to Next Version" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        Write-Host ""

        if ($RolloverToVersion) {
            Write-Host "🎯 Target Version: $RolloverToVersion (specified)" -ForegroundColor Yellow
            Write-Host "📝 Mode: Promote matching Next/Latest metadata into Current fields" -ForegroundColor Gray
        } else {
            Write-Host "📝 Mode: Rollover to NextVersion data" -ForegroundColor Gray
        }

        if ($DryRun) {
            Write-Host "🔍 DRY RUN MODE: No changes will be saved" -ForegroundColor Magenta
        }
        Write-Host ""

        # Create backup before making changes
        if (-not $DryRun) {
            $backupPath = Get-BackupPath -CsvPath $CsvPath -Prefix "pre-rollover"
            Copy-Item -Path $CsvPath -Destination $backupPath -Force
            Write-Host "💾 Backup created: $backupPath" -ForegroundColor Green
            Write-Host ""
        }

        $rolledOverCount = 0
        $skippedCount = 0
        $errorCount = 0

        foreach ($mod in $mods) {
            # Skip infrastructure entries; they are explicit version rows and should not be mass-mutated.
            if ($mod.Type -in @("installer", "launcher", "server", "jdk")) {
                continue
            }

            if ($RolloverToVersion) {
                $candidate = Get-TargetVersionCandidate -Mod $mod -TargetVersion $RolloverToVersion

                if ($candidate) {
                    $oldCurrentVersion = $mod.CurrentVersion
                    $oldCurrentUrl = $mod.CurrentVersionUrl
                    $oldGameVersion = $mod.CurrentGameVersion
                    $oldJar = $mod.Jar
                    $newJar = Get-RolloverArtifactFilename -Url $candidate.Url

                    if ($DryRun) {
                        Write-Host "  Would update $($mod.Name) from $($candidate.Source):" -ForegroundColor Yellow
                        Write-Host "    GameVersion: $oldGameVersion → $($candidate.GameVersion)" -ForegroundColor Gray
                        Write-Host "    Version: $oldCurrentVersion → $($candidate.Version)" -ForegroundColor Gray
                        Write-Host "    URL: $oldCurrentUrl → $($candidate.Url)" -ForegroundColor Gray
                        if ($newJar) { Write-Host "    Jar: $oldJar → $newJar" -ForegroundColor Gray }
                    } else {
                        $mod.CurrentGameVersion = $candidate.GameVersion
                        if (-not [string]::IsNullOrWhiteSpace($candidate.Version)) {
                            $mod.CurrentVersion = $candidate.Version
                        }
                        $mod.CurrentVersionUrl = $candidate.Url
                        if ($newJar) { $mod.Jar = $newJar }

                        try { $mod.RecordHash = Calculate-RecordHash -Record $mod } catch { }

                        Write-Host "✓ Updated $($mod.Name) from $($candidate.Source):" -ForegroundColor Green
                        Write-Host "  GameVersion: $oldGameVersion → $($mod.CurrentGameVersion)" -ForegroundColor Cyan
                        Write-Host "  Version: $oldCurrentVersion → $($mod.CurrentVersion)" -ForegroundColor Cyan
                        if ($oldCurrentUrl -ne $mod.CurrentVersionUrl) { Write-Host "  URL updated" -ForegroundColor Cyan }
                        if ($oldJar -ne $mod.Jar) { Write-Host "  Jar: $oldJar → $($mod.Jar)" -ForegroundColor Cyan }
                    }

                    $rolledOverCount++
                } else {
                    $skippedCount++
                    Write-Host "⏭️  Skipped $($mod.Name): no Current/Next/Latest URL for $RolloverToVersion" -ForegroundColor Yellow
                }
            } else {
                # Mode 2: Rollover using NextVersion data
                if ($mod.NextVersion -and $mod.NextVersion -ne "") {
                    $oldVersion = $mod.CurrentVersion
                    $oldGameVersion = $mod.CurrentGameVersion
                    $oldJar = $mod.Jar
                    $newJar = Get-RolloverArtifactFilename -Url $mod.NextVersionUrl

                    if ($DryRun) {
                        Write-Host "  Would rollover $($mod.Name):" -ForegroundColor Yellow
                        Write-Host "    Version: $oldVersion → $($mod.NextVersion)" -ForegroundColor Gray
                        Write-Host "    GameVersion: $oldGameVersion → $($mod.NextGameVersion)" -ForegroundColor Gray
                        if ($newJar) { Write-Host "    Jar: $oldJar → $newJar" -ForegroundColor Gray }
                    } else {
                        # Rollover Current* to Next* values
                        $mod.CurrentVersion = $mod.NextVersion
                        $mod.CurrentVersionUrl = $mod.NextVersionUrl
                        $mod.CurrentGameVersion = $mod.NextGameVersion
                        if ($newJar) { $mod.Jar = $newJar }

                        # Clear Next* fields (will be repopulated on next UpdateMods)
                        $mod.NextVersion = ""
                        $mod.NextVersionUrl = ""
                        $mod.NextGameVersion = ""

                        try { $mod.RecordHash = Calculate-RecordHash -Record $mod } catch { }

                        Write-Host "✓ Rolled over $($mod.Name):" -ForegroundColor Green
                        Write-Host "  Version: $oldVersion → $($mod.CurrentVersion)" -ForegroundColor Cyan
                        Write-Host "  GameVersion: $oldGameVersion → $($mod.CurrentGameVersion)" -ForegroundColor Cyan
                        if ($oldJar -ne $mod.Jar) { Write-Host "  Jar: $oldJar → $($mod.Jar)" -ForegroundColor Cyan }
                    }

                    $rolledOverCount++
                } else {
                    $skippedCount++
                }
            }
        }

        # Save changes
        if (-not $DryRun -and $rolledOverCount -gt 0) {
            $mods | Export-Csv -Path $CsvPath -NoTypeInformation
            Write-Host ""
            Write-Host "💾 Database updated successfully" -ForegroundColor Green
        }

        # Summary
        Write-Host ""
        Write-Host "📊 Rollover Summary:" -ForegroundColor Cyan
        Write-Host "  Rolled over: $rolledOverCount mods" -ForegroundColor Green
        Write-Host "  Skipped: $skippedCount mods" -ForegroundColor Yellow
        Write-Host "  Errors: $errorCount mods" -ForegroundColor Red

        if ($RolloverToVersion -and -not $DryRun) {
            Write-Host ""
            Write-Host "✅ Current fields now use known metadata for $RolloverToVersion where matching URLs exist." -ForegroundColor Green
            Write-Host "ℹ️  Run -UpdateMods after this to refresh Next/Latest metadata for the next release target." -ForegroundColor Gray
        }

        return $true

    } catch {
        Write-Host "❌ Error during rollover: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function is available for dot-sourcing