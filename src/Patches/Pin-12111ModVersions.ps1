# =============================================================================
# 1.21.11 Mod Version Pins
# =============================================================================
# Keep release-critical first-party mods on the exact jar versions that have been
# validated for SurvivorsUnited.
# =============================================================================

if (-not $script:OriginalGetModListBefore12111Pins -and (Get-Command Get-ModList -ErrorAction SilentlyContinue)) {
    $script:OriginalGetModListBefore12111Pins = ${function:Get-ModList}
}

function Set-12111BasicStoragePin {
    param([Parameter(Mandatory = $true)]$Row)

    $Row.CurrentGameVersion = '1.21.11'
    $Row.CurrentVersion = '2.0.20'
    $Row.CurrentVersionUrl = 'https://github.com/survivorsunited/mod-basic-storage/releases/download/2.0.20/basic-storage-2.0.20+1.21.11.jar'
    $Row.Jar = 'basic-storage-2.0.20+1.21.11.jar'
    $Row.LatestGameVersion = '1.21.11'
    $Row.LatestVersion = '2.0.20'
    $Row.LatestVersionUrl = 'https://github.com/survivorsunited/mod-basic-storage/releases/download/2.0.20/basic-storage-2.0.20+1.21.11.jar'
    $Row.Url = 'https://github.com/survivorsunited/mod-basic-storage'
    $Row.Host = 'github'
    $Row.ApiSource = 'github'
}

function Test-12111BasicStorageRow {
    param([Parameter(Mandatory = $true)]$Row)

    $id = if ($Row.ID) { $Row.ID.Trim().ToLowerInvariant() } else { '' }
    $name = if ($Row.Name) { $Row.Name.Trim().ToLowerInvariant() } else { '' }
    $title = if ($Row.Title) { $Row.Title.Trim().ToLowerInvariant() } else { '' }
    $url = if ($Row.Url) { $Row.Url.Trim().ToLowerInvariant() } else { '' }
    $jar = if ($Row.Jar) { $Row.Jar.Trim().ToLowerInvariant() } else { '' }

    return (
        $id -eq 'survivorsunited/mod-basic-storage' -or
        $id -eq 'basicstorage' -or
        $id -eq 'basic-storage' -or
        $name -eq 'basic storage' -or
        $title -eq 'basic storage' -or
        $url -like '*survivorsunited/mod-basic-storage*' -or
        $jar -like 'basic-storage-*'
    )
}

function Get-ModList {
    param([string]$CsvPath = $ModListPath)

    $rows = @(& $script:OriginalGetModListBefore12111Pins -CsvPath $CsvPath)

    foreach ($row in $rows) {
        if (Test-12111BasicStorageRow -Row $row) {
            Set-12111BasicStoragePin -Row $row
        }
    }

    return $rows
}
