# =============================================================================
# Get Majority Latest Game Version Module
# =============================================================================
# This module determines the majority latest game version from the database.
# =============================================================================

<#
.SYNOPSIS
    Gets the majority latest game version from the database.

.DESCRIPTION
    Analyzes the LatestGameVersion column to determine which version
    is the most common among mods, for use with -UseLatestVersion workflow.

.PARAMETER CsvPath
    Path to the CSV database file.

.EXAMPLE
    $result = Get-MajorityLatestGameVersion -CsvPath "modlist.csv"
    Write-Host "Majority latest version: $($result.MajorityVersion)"

.NOTES
    - Returns the most common LatestGameVersion among mods
    - Falls back to CurrentGameVersion analysis if LatestGameVersion is empty
    - Provides detailed analysis for debugging
#>
function Get-MajorityLatestGameVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        Write-Host "📊 Analyzing latest game versions..." -ForegroundColor Yellow
        
        # Load database
        $mods = Import-Csv -Path $CsvPath
        $modEntries = $mods | Where-Object { $_.Type -eq "mod" }
        
        Write-Host "   Found $($modEntries.Count) mod entries" -ForegroundColor Green
        
        # Group by LatestGameVersion
        $latestVersionGroups = $modEntries | Where-Object { 
            $_.LatestGameVersion -and $_.LatestGameVersion -ne "" 
        } | Group-Object LatestGameVersion | Sort-Object Count -Descending
        
        if ($latestVersionGroups -and $latestVersionGroups.Count -gt 0) {
            $majorityLatestVersion = $latestVersionGroups[0].Name
            $majorityCount = $latestVersionGroups[0].Count
            
            Write-Host "   Majority latest game version: $majorityLatestVersion ($majorityCount mods)" -ForegroundColor Green
            
            # Create detailed analysis
            $analysis = @{
                TotalMods = $modEntries.Count
                MajorityVersion = $majorityLatestVersion
                MajorityCount = $majorityCount
                VersionDistribution = @{}
            }
            
            foreach ($group in $latestVersionGroups) {
                $analysis.VersionDistribution[$group.Name] = $group.Count
            }
            
            return @{
                MajorityVersion = $majorityLatestVersion
                Analysis = $analysis
            }
        } else {
            # Fallback to current version analysis
            Write-Host "   ⚠️  No LatestGameVersion data found, falling back to CurrentGameVersion" -ForegroundColor Yellow
            
            $currentVersionGroups = $modEntries | Where-Object { 
                $_.CurrentGameVersion -and $_.CurrentGameVersion -ne "" 
            } | Group-Object CurrentGameVersion | Sort-Object Count -Descending
            
            if ($currentVersionGroups -and $currentVersionGroups.Count -gt 0) {
                $fallbackVersion = $currentVersionGroups[0].Name
                $fallbackCount = $currentVersionGroups[0].Count
                
                Write-Host "   Fallback to current version: $fallbackVersion ($fallbackCount mods)" -ForegroundColor Yellow
                
                return @{
                    MajorityVersion = $fallbackVersion
                    Analysis = @{
                        TotalMods = $modEntries.Count
                        MajorityVersion = $fallbackVersion
                        MajorityCount = $fallbackCount
                        Fallback = $true
                        VersionDistribution = @{}
                    }
                }
            } else {
                throw "No game version data found in database"
            }
        }
        
    } catch {
        Write-Host "❌ Failed to get majority latest game version: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            MajorityVersion = "1.21.5"  # Safe fallback
            Analysis = @{
                Error = $_.Exception.Message
                Fallback = $true
            }
        }
    }
}

# Function is available for dot-sourcing