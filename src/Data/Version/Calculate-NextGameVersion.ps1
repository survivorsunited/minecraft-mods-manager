# =============================================================================
# Calculate Next Game Version Function
# =============================================================================
# This function calculates the "next" version after the majority version
# for testing if the next version will work with current mods
# =============================================================================

<#
.SYNOPSIS
    Calculates the next game version for testing purposes.

.DESCRIPTION
    Determines the next Minecraft version after the majority version
    to test if mods will work with newer versions.

.PARAMETER CsvPath
    Path to the CSV file containing mod data.

.EXAMPLE
    Calculate-NextGameVersion -CsvPath "modlist.csv"

.NOTES
    - Gets the majority version first
    - Finds available versions in download folder or database
    - Returns the next logical version for testing
#>
function Calculate-NextGameVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    try {
        # Get majority version first
        $majorityResult = Get-MajorityGameVersion -CsvPath $CsvPath
        $majorityVersion = $majorityResult.MajorityVersion
        
        Write-Host "🔍 Current majority version: $majorityVersion" -ForegroundColor Cyan
        
        # Get all available versions from database
        $mods = Import-Csv -Path $CsvPath
        $allVersions = $mods | Where-Object { -not [string]::IsNullOrEmpty($_.CurrentGameVersion) -or -not [string]::IsNullOrEmpty($_.GameVersion) } |
                       ForEach-Object { if ($_.CurrentGameVersion) { $_.CurrentGameVersion } else { $_.GameVersion } } |
                       Select-Object -Unique |
                       Sort-Object { [version]$_ }
        
        Write-Host "📋 Available versions in database: $($allVersions -join ', ')" -ForegroundColor Gray
        
        # Also check download folder for available versions
        $downloadFolder = "download"
        $downloadVersions = @()
        if (Test-Path $downloadFolder) {
            $downloadVersions = Get-ChildItem -Path $downloadFolder -Directory -ErrorAction SilentlyContinue | 
                               Where-Object { $_.Name -match "^\d+\.\d+\.\d+$" } |
                               Select-Object -ExpandProperty Name |
                               Sort-Object { [version]$_ }
            
            if ($downloadVersions.Count -gt 0) {
                Write-Host "📁 Available versions in download: $($downloadVersions -join ', ')" -ForegroundColor Gray
            }
        }
        
        # Combine and deduplicate versions
        $combinedVersions = ($allVersions + $downloadVersions) | Select-Object -Unique | Sort-Object { [version]$_ }
        
        # Calculate next version by incrementing patch version (CurrentGameVersion + 1)
        # This ensures Next is always CurrentGameVersion + 1, not the highest available
        if ($majorityVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            $patch = [int]$matches[3]
            $nextPatch = $patch + 1
            $nextVersion = "$major.$minor.$nextPatch"
            Write-Host "🎯 Calculated next version: $nextVersion (from $majorityVersion + 1)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Could not parse majority version format: $majorityVersion" -ForegroundColor Yellow
            # Fallback: try to find next in available versions
        $majorityIndex = -1
        for ($i = 0; $i -lt $combinedVersions.Count; $i++) {
            if ($combinedVersions[$i] -eq $majorityVersion) {
                $majorityIndex = $i
                break
            }
        }
        
            if ($majorityIndex -ge 0 -and $majorityIndex + 1 -lt $combinedVersions.Count) {
            $nextVersion = $combinedVersions[$majorityIndex + 1]
                Write-Host "🎯 Using next available version: $nextVersion" -ForegroundColor Yellow
        } else {
            $nextVersion = $majorityVersion
                Write-Host "⚠️  Using majority version as fallback: $nextVersion" -ForegroundColor Yellow
            }
        }
        
        # Check if next version has any mod support
        $nextVersionMods = $mods | Where-Object { $_.CurrentGameVersion -eq $nextVersion -or $_.GameVersion -eq $nextVersion }
        $modCount = $nextVersionMods.Count
        
        $result = @{
            NextVersion = $nextVersion
            MajorityVersion = $majorityVersion
            ModCount = $modCount
            IsHighestVersion = ($nextVersion -eq $majorityVersion)
            AvailableVersions = $combinedVersions
        }
        
        Write-Host "📊 Next version analysis:" -ForegroundColor Yellow
        Write-Host "  - Next version: $nextVersion" -ForegroundColor Gray
        Write-Host "  - Mods supporting next version: $modCount" -ForegroundColor Gray
        Write-Host "  - Is highest available: $($result.IsHighestVersion)" -ForegroundColor Gray
        
        return $result
        
    } catch {
        Write-Host "❌ Error calculating next game version: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing