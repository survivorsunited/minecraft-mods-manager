# =============================================================================
# Download Readme Generation Module
# =============================================================================
# This module handles generation of README files for download results.
# =============================================================================

<#
.SYNOPSIS
    Creates README file with download analysis.

.DESCRIPTION
    Generates a comprehensive README.md file documenting download results,
    game version analysis, and mod information.

.PARAMETER FolderPath
    The folder path where to create the README file.

.PARAMETER Analysis
    The game version analysis object.

.PARAMETER DownloadResults
    The download results array.

.PARAMETER TargetVersion
    The target game version.

.PARAMETER UseLatestVersion
    Whether latest versions were used.

.EXAMPLE
    Write-DownloadReadme -FolderPath "download/1.21.5" -Analysis $analysis -DownloadResults $results -TargetVersion "1.21.5"

.NOTES
    - Creates detailed README with version analysis
    - Documents download success/failure statistics
    - Lists all downloaded mods with versions
    - Shows download settings and configuration
#>
function Write-DownloadReadme {
    param(
        [string]$FolderPath,
        [object]$Analysis,
        [object]$DownloadResults,
        [string]$TargetVersion,
        [switch]$UseLatestVersion
    )
    
    $readmePath = Join-Path $FolderPath "README.md"
    $readmeContent = @"
# Minecraft Mod Pack - $TargetVersion

Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Game Version Analysis

**Total mods analyzed:** $($Analysis.TotalMods) (out of $($Analysis.TotalMods + 1), one had no LatestGameVersion)
**Majority version:** $($Analysis.MajorityVersion) ($($Analysis.MajorityCount) mods, $($Analysis.MajorityPercentage)%)
**Target version:** $TargetVersion (automatically selected)

## Version Distribution

"@

    foreach ($version in $Analysis.VersionDistribution) {
        $marker = if ($version.Version -eq $Analysis.MajorityVersion) { " ← Majority" } else { "" }
        $readmeContent += "`n**$($version.Version):** $($version.Count) mods ($($version.Percentage)%)$marker"
        
        # Add mod list for this version
        $readmeContent += "`n`n  **Mods for $($version.Version):**`n"
        foreach ($mod in $Analysis.ModsByVersion[$version.Version]) {
            $readmeContent += "  - $($mod.Name) (ID: $($mod.ID)) - Current: $($mod.Version), Latest: $($mod.LatestVersion)`n"
        }
        $readmeContent += "`n"
    }

    $readmeContent += @"

## Download Results

**✅ Successfully downloaded:** $(($DownloadResults | Where-Object { $_.Status -eq "Success" }).Count) mods
**⏭️ Skipped (already exists):** $(($DownloadResults | Where-Object { $_.Status -eq "Skipped" }).Count) mods  
**❌ Failed:** $(($DownloadResults | Where-Object { $_.Status -eq "Failed" }).Count) mods

**📁 All mods downloaded to:** mods/$TargetVersion/ folder

## Failed Downloads

"@

    $failedMods = $DownloadResults | Where-Object { $_.Status -eq "Failed" }
    if ($failedMods.Count -gt 0) {
        foreach ($failed in $failedMods) {
            $readmeContent += "`n- **$($failed.Name):** $($failed.Error)"
        }
    } else {
        $readmeContent += "`nNo failed downloads."
    }

    $readmeContent += @"

## Download Settings

- **Use Latest Version:** $UseLatestVersion
- **Force Download:** $ForceDownload
- **Target Game Version:** $TargetVersion

## Mod List

"@

    $successfulMods = $DownloadResults | Where-Object { $_.Status -eq "Success" } | Sort-Object Name
    foreach ($mod in $successfulMods) {
        $readmeContent += "`n- **$($mod.Name)** - Version: $($mod.Version) - Size: $($mod.Size)"
    }

    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    Write-Host "Created README.md in: $FolderPath" -ForegroundColor Green
}

# Function is available for dot-sourcing 