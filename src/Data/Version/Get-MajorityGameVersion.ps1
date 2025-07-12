# =============================================================================
# Game Version Analysis Module
# =============================================================================
# This module handles analysis of game versions in mod lists.
# =============================================================================

<#
.SYNOPSIS
    Determines the majority game version from modlist.

.DESCRIPTION
    Analyzes the modlist to find the most common game version
    and provides detailed analysis of version distribution.

.PARAMETER CsvPath
    The path to the CSV file.

.EXAMPLE
    Get-MajorityGameVersion -CsvPath "modlist.csv"

.NOTES
    - Analyzes LatestGameVersion field from all mods
    - Returns majority version and detailed analysis
    - Shows version distribution and mod lists by version
#>
# Function to determine the majority game version from modlist
function Get-MajorityGameVersion {
    param(
        [string]$CsvPath = $ModListPath
    )
    
    try {
        $mods = Get-ModList -CsvPath $CsvPath
        if (-not $mods) {
            return @{
                MajorityVersion = $DefaultGameVersion
                Analysis = $null
            }
        }
        
        # Get all LatestGameVersion values that are not null or empty
        $gameVersions = $mods | Where-Object { -not [string]::IsNullOrEmpty($_.LatestGameVersion) } | Select-Object -ExpandProperty LatestGameVersion
        
        if ($gameVersions.Count -eq 0) {
            return @{
                MajorityVersion = $DefaultGameVersion
                Analysis = $null
            }
        }
        
        # Group by version and count occurrences
        $versionCounts = $gameVersions | Group-Object | Sort-Object Count -Descending
        
        # Get the most common version
        $majorityVersion = $versionCounts[0].Name
        $majorityCount = $versionCounts[0].Count
        $totalCount = $gameVersions.Count
        
        # Calculate percentage
        $percentage = [math]::Round(($majorityCount / $totalCount) * 100, 1)
        
        # Create detailed analysis object
        $analysis = @{
            TotalMods = $totalCount
            MajorityVersion = $majorityVersion
            MajorityCount = $majorityCount
            MajorityPercentage = $percentage
            VersionDistribution = @()
            ModsByVersion = @{}
        }
        
        # Build version distribution and mod lists
        foreach ($versionGroup in $versionCounts) {
            $versionPercentage = [math]::Round(($versionGroup.Count / $totalCount) * 100, 1)
            $analysis.VersionDistribution += @{
                Version = $versionGroup.Name
                Count = $versionGroup.Count
                Percentage = $versionPercentage
            }
            
            # Get list of mods for this version
            $modsForVersion = $mods | Where-Object { $_.LatestGameVersion -eq $versionGroup.Name } | Select-Object Name, ID, Version, LatestVersion
            $analysis.ModsByVersion[$versionGroup.Name] = $modsForVersion
        }
        
        Write-Host "Game Version Analysis:" -ForegroundColor Cyan
        Write-Host "=====================" -ForegroundColor Cyan
        Write-Host "Total mods with LatestGameVersion: $totalCount" -ForegroundColor White
        Write-Host "Majority version: $majorityVersion ($majorityCount mods, $percentage%)" -ForegroundColor Green
        
        # Show all version distributions
        Write-Host ""
        Write-Host "Version distribution:" -ForegroundColor Yellow
        foreach ($versionGroup in $versionCounts) {
            $versionPercentage = [math]::Round(($versionGroup.Count / $totalCount) * 100, 1)
            Write-Host "  $($versionGroup.Name): $($versionGroup.Count) mods ($versionPercentage%)" -ForegroundColor White
        }
        Write-Host ""
        
        return @{
            MajorityVersion = $majorityVersion
            Analysis = $analysis
        }
    }
    catch {
        Write-Host "Error determining majority game version: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            MajorityVersion = $DefaultGameVersion
            Analysis = $null
        }
    }
}

# Function is available for dot-sourcing 