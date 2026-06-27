# =============================================================================
# Calculate Next Game Version Function
# =============================================================================
# This function calculates the "next" version after the majority version
# for testing if the next version will work with current mods.
# =============================================================================

<#
.SYNOPSIS
    Calculates the next game version for testing purposes.

.DESCRIPTION
    Determines the next Minecraft version after the majority version using known
    versions in the database before falling back to legacy patch incrementing.

.PARAMETER CsvPath
    Path to the CSV file containing mod data.

.EXAMPLE
    Calculate-NextGameVersion -CsvPath "modlist.csv"

.NOTES
    - Gets the majority version first
    - Prefers the next known version in the database, e.g. 1.21.11 -> 26.1
    - Falls back to patch incrementing only when no known newer version exists
#>
function Calculate-NextGameVersion {
    param(
        [string]$CsvPath = "modlist.csv"
    )
    
    function ConvertTo-SortableGameVersion {
        param([string]$Version)
        try {
            $clean = ($Version -replace '[^0-9\.]', '')
            if ([string]::IsNullOrWhiteSpace($clean)) { return $null }
            return [version]$clean
        } catch { return $null }
    }

    function Get-KnownGameVersions {
        param([array]$Rows)

        $versions = @()
        foreach ($row in $Rows) {
            foreach ($field in @('CurrentGameVersion', 'GameVersion', 'NextGameVersion', 'LatestGameVersion', 'AvailableGameVersions')) {
                if (-not ($row.PSObject.Properties.Name -contains $field)) { continue }
                $value = $row.$field
                if ([string]::IsNullOrWhiteSpace($value)) { continue }
                foreach ($candidate in ($value -split ',')) {
                    $v = $candidate.Trim()
                    if ($v -match '^\d+(\.\d+){1,2}$') { $versions += $v }
                }
            }
        }

        return $versions | Select-Object -Unique | Sort-Object { ConvertTo-SortableGameVersion $_ }
    }

    try {
        # Get majority version first
        $majorityResult = Get-MajorityGameVersion -CsvPath $CsvPath
        $majorityVersion = $majorityResult.MajorityVersion
        
        Write-Host "🔍 Current majority version: $majorityVersion" -ForegroundColor Cyan
        
        # Get all available versions from database
        $mods = Import-Csv -Path $CsvPath
        $allVersions = Get-KnownGameVersions -Rows $mods
        
        Write-Host "📋 Known versions in database: $($allVersions -join ', ')" -ForegroundColor Gray
        
        # Also check download folder for available versions
        $downloadFolder = "download"
        $downloadVersions = @()
        if (Test-Path $downloadFolder) {
            $downloadVersions = Get-ChildItem -Path $downloadFolder -Directory -ErrorAction SilentlyContinue | 
                               Where-Object { $_.Name -match '^\d+(\.\d+){1,2}$' } |
                               Select-Object -ExpandProperty Name
            if ($downloadVersions.Count -gt 0) {
                Write-Host "📁 Available versions in download: $($downloadVersions -join ', ')" -ForegroundColor Gray
            }
        }
        
        # Combine and deduplicate versions
        $combinedVersions = ($allVersions + $downloadVersions) | Select-Object -Unique | Sort-Object { ConvertTo-SortableGameVersion $_ }
        $majoritySortable = ConvertTo-SortableGameVersion $majorityVersion
        $nextVersion = $null

        if ($majoritySortable) {
            foreach ($version in $combinedVersions) {
                $sortable = ConvertTo-SortableGameVersion $version
                if ($sortable -and $sortable -gt $majoritySortable) {
                    $nextVersion = $version
                    break
                }
            }
        }

        # Explicit known boundary: Minecraft jumped from 1.21.11 to 26.1.
        if (-not $nextVersion -and $majorityVersion -eq '1.21.11') {
            $nextVersion = '26.1'
            Write-Host "🎯 Using known next version transition: 1.21.11 -> 26.1" -ForegroundColor Green
        }

        # Legacy fallback only when we cannot find a known newer version.
        if (-not $nextVersion) {
            if ($majorityVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
                $major = [int]$matches[1]
                $minor = [int]$matches[2]
                $patch = [int]$matches[3]
                $nextVersion = "$major.$minor.$($patch + 1)"
                Write-Host "⚠️  No known newer version found; calculated fallback next version: $nextVersion" -ForegroundColor Yellow
            } else {
                $nextVersion = $majorityVersion
                Write-Host "⚠️  Using majority version as fallback: $nextVersion" -ForegroundColor Yellow
            }
        } else {
            Write-Host "🎯 Calculated next version from known versions: $nextVersion" -ForegroundColor Green
        }
        
        # Check if next version has any mod support
        $nextVersionMods = $mods | Where-Object {
            $_.CurrentGameVersion -eq $nextVersion -or
            $_.GameVersion -eq $nextVersion -or
            $_.NextGameVersion -eq $nextVersion -or
            $_.LatestGameVersion -eq $nextVersion -or
            ($_.AvailableGameVersions -and (($_.AvailableGameVersions -split ',') | ForEach-Object { $_.Trim() }) -contains $nextVersion)
        }
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
        Write-Host "  - Mods/records supporting next version: $modCount" -ForegroundColor Gray
        Write-Host "  - Is highest available: $($result.IsHighestVersion)" -ForegroundColor Gray
        
        return $result
        
    } catch {
        Write-Host "❌ Error calculating next game version: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing