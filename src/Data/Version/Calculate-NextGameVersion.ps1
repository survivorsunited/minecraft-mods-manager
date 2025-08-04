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
        $allVersions = $mods | Where-Object { -not [string]::IsNullOrEmpty($_.GameVersion) } |
                       Select-Object -ExpandProperty GameVersion -Unique |
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
        
        # Find the next version after majority
        $majorityIndex = -1
        for ($i = 0; $i -lt $combinedVersions.Count; $i++) {
            if ($combinedVersions[$i] -eq $majorityVersion) {
                $majorityIndex = $i
                break
            }
        }
        
        if ($majorityIndex -eq -1) {
            Write-Host "⚠️  Majority version $majorityVersion not found in available versions" -ForegroundColor Yellow
            # Return the highest version as fallback
            $nextVersion = $combinedVersions | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
            Write-Host "🎯 Using highest available version as next: $nextVersion" -ForegroundColor Yellow
        } elseif ($majorityIndex + 1 -lt $combinedVersions.Count) {
            # Return the next version after majority
            $nextVersion = $combinedVersions[$majorityIndex + 1]
            Write-Host "🎯 Next version after $majorityVersion is: $nextVersion" -ForegroundColor Green
        } else {
            # Majority is already the highest version
            Write-Host "ℹ️  $majorityVersion is already the highest available version" -ForegroundColor Blue
            $nextVersion = $majorityVersion
            Write-Host "🎯 Using majority version (already highest): $nextVersion" -ForegroundColor Blue
        }
        
        # Check if next version has any mod support
        $nextVersionMods = $mods | Where-Object { $_.GameVersion -eq $nextVersion }
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