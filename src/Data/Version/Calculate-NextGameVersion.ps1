# =============================================================================
# Calculate Next Game Version Function
# =============================================================================
# This function calculates the "next" version target for testing workflows.
# =============================================================================

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
        $mods = Import-Csv -Path $CsvPath
        $majorityResult = Get-MajorityGameVersion -CsvPath $CsvPath
        $majorityVersion = $majorityResult.MajorityVersion
        Write-Host "🔍 Current majority version: $majorityVersion" -ForegroundColor Cyan

        $releaseTargets = $null
        if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
            $releaseTargets = Get-ReleaseVersionTargets
        }

        if ($releaseTargets -and -not [string]::IsNullOrWhiteSpace($releaseTargets.Next)) {
            $nextVersion = $releaseTargets.Next
            Write-Host "🎯 Next version from release-config.json: $nextVersion" -ForegroundColor Green
        } else {
            $allVersions = Get-KnownGameVersions -Rows $mods
            Write-Host "📋 Known versions in database: $($allVersions -join ', ')" -ForegroundColor Gray

            $downloadFolder = "download"
            $downloadVersions = @()
            if (Test-Path $downloadFolder) {
                $downloadVersions = Get-ChildItem -Path $downloadFolder -Directory -ErrorAction SilentlyContinue |
                                   Where-Object { $_.Name -match '^\d+(\.\d+){1,2}$' } |
                                   Select-Object -ExpandProperty Name
            }

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

            if (-not $nextVersion -and $majorityVersion -eq '1.21.11') {
                $nextVersion = '26.1'
                Write-Host "🎯 Using fallback known transition: 1.21.11 -> 26.1" -ForegroundColor Green
            }

            if (-not $nextVersion) {
                if ($majorityVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
                    $major = [int]$matches[1]
                    $minor = [int]$matches[2]
                    $patch = [int]$matches[3]
                    $nextVersion = "$major.$minor.$($patch + 1)"
                    Write-Host "⚠️  No configured next version found; calculated fallback: $nextVersion" -ForegroundColor Yellow
                } else {
                    $nextVersion = $majorityVersion
                    Write-Host "⚠️  Using majority version as fallback: $nextVersion" -ForegroundColor Yellow
                }
            }
        }

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
            AvailableVersions = @()
            ReleaseTargets = $releaseTargets
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
