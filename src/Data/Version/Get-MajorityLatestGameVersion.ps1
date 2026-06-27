# =============================================================================
# Get Majority Latest Game Version Module
# =============================================================================
# Determines the latest game-version target for -UseLatestVersion workflows.
# =============================================================================

function Get-MajorityLatestGameVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
            $targets = Get-ReleaseVersionTargets
            if ($targets -and -not [string]::IsNullOrWhiteSpace($targets.Latest)) {
                Write-Host "   Latest game version from release-config.json: $($targets.Latest)" -ForegroundColor Green
                return @{
                    MajorityVersion = $targets.Latest
                    Analysis = @{
                        TotalMods = 0
                        MajorityVersion = $targets.Latest
                        MajorityCount = 0
                        Source = "release-config.json"
                        VersionDistribution = @{}
                    }
                }
            }
        }

        Write-Host "📊 Analyzing latest game versions..." -ForegroundColor Yellow
        $mods = Import-Csv -Path $CsvPath
        $modEntries = $mods | Where-Object { $_.Type -eq "mod" }
        Write-Host "   Found $($modEntries.Count) mod entries" -ForegroundColor Green
        
        $latestVersionGroups = $modEntries | Where-Object { 
            $_.LatestGameVersion -and $_.LatestGameVersion -ne "" 
        } | Group-Object LatestGameVersion | Sort-Object Count -Descending
        
        if ($latestVersionGroups -and $latestVersionGroups.Count -gt 0) {
            $majorityLatestVersion = $latestVersionGroups[0].Name
            $majorityCount = $latestVersionGroups[0].Count
            Write-Host "   Majority latest game version: $majorityLatestVersion ($majorityCount mods)" -ForegroundColor Green
            
            $analysis = @{
                TotalMods = $modEntries.Count
                MajorityVersion = $majorityLatestVersion
                MajorityCount = $majorityCount
                VersionDistribution = @{}
            }
            foreach ($group in $latestVersionGroups) { $analysis.VersionDistribution[$group.Name] = $group.Count }
            return @{ MajorityVersion = $majorityLatestVersion; Analysis = $analysis }
        }

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
        }

        throw "No game version data found in database"
    } catch {
        Write-Host "❌ Failed to get majority latest game version: $($_.Exception.Message)" -ForegroundColor Red
        return @{ MajorityVersion = "1.21.5"; Analysis = @{ Error = $_.Exception.Message; Fallback = $true } }
    }
}

# Function is available for dot-sourcing
