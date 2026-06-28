# =============================================================================
# 1.21.11 Mod Version Pins
# =============================================================================
# Keep release-critical mods on exact jar versions that have been validated for
# SurvivorsUnited. This avoids provider auto-selection moving a known-good row to
# a newer beta build during release/update workflows.
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

function Set-12111SodiumPin {
    param([Parameter(Mandatory = $true)]$Row)

    $url = 'https://cdn.modrinth.com/data/AANobbMI/versions/NFkjnzWE/sodium-fabric-0.8.12%2Bmc1.21.11.jar'
    $Row.CurrentGameVersion = '1.21.11'
    $Row.CurrentVersion = 'mc1.21.11-0.8.12-fabric'
    $Row.CurrentVersionUrl = $url
    $Row.Jar = 'sodium-fabric-0.8.12+mc1.21.11.jar'
    $Row.LatestGameVersion = '1.21.11'
    $Row.LatestVersion = 'mc1.21.11-0.8.12-fabric'
    $Row.LatestVersionUrl = $url
    $Row.Url = 'https://modrinth.com/mod/sodium'
    $Row.Host = 'modrinth'
    $Row.ApiSource = 'modrinth'
}

function Set-12111FabricLauncherPin {
    param([Parameter(Mandatory = $true)]$Row)

    $url = 'https://meta.fabricmc.net/v2/versions/loader/1.21.11/0.19.3/1.1.1/server/jar'
    $Row.CurrentGameVersion = '1.21.11'
    $Row.CurrentVersion = '0.19.3'
    $Row.CurrentVersionUrl = $url
    $Row.Jar = 'fabric-server-mc.1.21.11-loader.0.19.3.jar'
    $Row.Url = $url
    $Row.Host = 'fabric'
    $Row.ApiSource = 'fabric'
    if ($Row.Name) { $Row.Name = 'Fabric Server Launcher' }
    if ($Row.Title) { $Row.Title = 'Fabric Launcher 1.21.11' }
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

function Test-12111SodiumRow {
    param([Parameter(Mandatory = $true)]$Row)

    $id = if ($Row.ID) { $Row.ID.Trim().ToLowerInvariant() } else { '' }
    $name = if ($Row.Name) { $Row.Name.Trim().ToLowerInvariant() } else { '' }
    $title = if ($Row.Title) { $Row.Title.Trim().ToLowerInvariant() } else { '' }
    $jar = if ($Row.Jar) { $Row.Jar.Trim().ToLowerInvariant() } else { '' }

    return (
        $id -eq 'sodium' -or
        $name -eq 'sodium' -or
        $title -eq 'sodium' -or
        $jar -like 'sodium-fabric-*'
    )
}

function Test-12111FabricLauncherRow {
    param([Parameter(Mandatory = $true)]$Row)

    $id = if ($Row.ID) { $Row.ID.Trim().ToLowerInvariant() } else { '' }
    $type = if ($Row.Type) { $Row.Type.Trim().ToLowerInvariant() } else { '' }
    $gameVersion = if ($Row.CurrentGameVersion) { $Row.CurrentGameVersion.Trim() } else { '' }
    $jar = if ($Row.Jar) { $Row.Jar.Trim().ToLowerInvariant() } else { '' }

    return (
        $gameVersion -eq '1.21.11' -and
        $type -eq 'launcher' -and
        (
            $id -eq 'fabric-launcher' -or
            $id -eq 'fabric-server-launcher-1.21.11' -or
            $jar -like 'fabric-server-mc.1.21.11-loader.*.jar'
        )
    )
}

function Get-ModList {
    param([string]$CsvPath = $ModListPath)

    $rows = @(& $script:OriginalGetModListBefore12111Pins -CsvPath $CsvPath)

    foreach ($row in $rows) {
        if (Test-12111BasicStorageRow -Row $row) {
            Set-12111BasicStoragePin -Row $row
        }
        if (Test-12111SodiumRow -Row $row) {
            Set-12111SodiumPin -Row $row
        }
        if (Test-12111FabricLauncherRow -Row $row) {
            Set-12111FabricLauncherPin -Row $row
        }
    }

    return $rows
}
