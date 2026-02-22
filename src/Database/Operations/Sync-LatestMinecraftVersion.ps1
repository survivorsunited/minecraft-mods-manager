# =============================================================================
# Sync Latest Minecraft Version (Server, Launcher, Installer) to Database
# =============================================================================
# Ensures the latest Minecraft release has server, launcher, and installer
# rows in the DB so releases and Next/Latest builds use the correct JARs.
# =============================================================================

<#
.SYNONOPSIS
    Adds the latest Minecraft version's server, launcher, and installer to the database if missing.

.DESCRIPTION
    Fetches the latest release version from Mojang, then adds missing server (Minecraft JAR),
    launcher (Fabric server launcher), and installer (EXE + JAR) rows for that version.
    Idempotent: only adds rows that do not already exist.

.PARAMETER CsvPath
    Path to the modlist CSV file.

.PARAMETER DryRun
    If set, report what would be added without writing to the database.

.EXAMPLE
    Sync-LatestMinecraftVersion -CsvPath "modlist.csv"

.EXAMPLE
    Sync-LatestMinecraftVersion -CsvPath "modlist.csv" -DryRun

.NOTES
    - Depends on Get-MojangVersions, Get-FabricVersions, Calculate-RecordHash
    - Server/launcher use same structure as Sync-MinecraftVersions
#>
function Sync-LatestMinecraftVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CsvPath,
        [switch]$DryRun = $false
    )

    try {
        Write-Host "🔄 Syncing latest Minecraft version (server, launcher, installer) to database..." -ForegroundColor Cyan

        $apiUrl = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
        $manifest = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
        if (-not $manifest -or -not $manifest.latest -or -not $manifest.latest.release) {
            Write-Host "❌ Could not get latest release from Mojang" -ForegroundColor Red
            return $false
        }
        $latestVer = $manifest.latest.release
        Write-Host "   Latest Minecraft release: $latestVer" -ForegroundColor Gray

        if (-not (Test-Path $CsvPath)) {
            Write-Host "❌ Database not found: $CsvPath" -ForegroundColor Red
            return $false
        }

        $mods = Import-Csv -Path $CsvPath
        $existingServer = $mods | Where-Object { $_.Type -eq "server" -and $_.CurrentGameVersion -eq $latestVer }
        $existingLauncher = $mods | Where-Object { $_.Type -eq "launcher" -and $_.CurrentGameVersion -eq $latestVer }
        $existingInstallers = $mods | Where-Object { $_.Type -eq "installer" -and $_.CurrentGameVersion -eq $latestVer }

        $needServer = -not $existingServer
        $needLauncher = -not $existingLauncher
        $needInstallers = ($existingInstallers | Measure-Object).Count -lt 2

        if (-not $needServer -and -not $needLauncher -and -not $needInstallers) {
            Write-Host "✅ Latest version $latestVer already has server, launcher, and installer in database" -ForegroundColor Green
            return $true
        }

        if ($DryRun) {
            Write-Host "🔍 DRY RUN - Would add for $latestVer :" -ForegroundColor Yellow
            if ($needServer) { Write-Host "   • Server" -ForegroundColor White }
            if ($needLauncher) { Write-Host "   • Launcher" -ForegroundColor White }
            if ($needInstallers) { Write-Host "   • Installer (EXE + JAR)" -ForegroundColor White }
            return $true
        }

        $modsList = [System.Collections.ArrayList]::new()
        $mods | ForEach-Object { $modsList.Add($_) | Out-Null }
        $addedCount = 0

        # --- Server ---
        if ($needServer) {
            Write-Host "   ➕ Adding Minecraft Server $latestVer..." -ForegroundColor Cyan
            $versionObj = $manifest.versions | Where-Object { $_.id -eq $latestVer -and $_.type -eq "release" } | Select-Object -First 1
            $serverUrl = ""
            if ($versionObj -and $versionObj.url) {
                try {
                    $versionDetails = Invoke-RestMethod -Uri $versionObj.url -Method Get -TimeoutSec 30
                    if ($versionDetails.downloads.server.url) { $serverUrl = $versionDetails.downloads.server.url }
                } catch {
                    Write-Host "      ⚠️  Could not fetch server URL: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
            $newServer = [PSCustomObject]@{
                Group = "server"
                Type = "server"
                CurrentGameVersion = $latestVer
                ID = "minecraft-server"
                Loader = "vanilla"
                CurrentVersion = $latestVer
                Name = "Minecraft Server"
                Description = "Official Minecraft Server JAR for $latestVer"
                Category = "server"
                Jar = "minecraft_server.$latestVer.jar"
                NextVersion = ""; NextVersionUrl = ""; NextGameVersion = ""
                LatestVersion = ""; LatestVersionUrl = ""; LatestGameVersion = ""
                Url = $serverUrl; CurrentVersionUrl = $serverUrl; UrlDirect = ""
                CurrentDependencies = ""; CurrentDependenciesRequired = ""; CurrentDependenciesOptional = ""
                LatestDependencies = ""; LatestDependenciesRequired = ""; LatestDependenciesOptional = ""
                Host = "mojang"; ApiSource = "mojang"
                ClientSide = "optional"; ServerSide = "required"
                Title = "Minecraft Server $latestVer"
                ProjectDescription = "Official Minecraft Java Edition Server"
                IconUrl = ""; IssuesUrl = ""; SourceUrl = ""; WikiUrl = ""
                AvailableGameVersions = $latestVer
                RecordHash = ""
            }
            if (Get-Command Calculate-RecordHash -ErrorAction SilentlyContinue) {
                $newServer.RecordHash = Calculate-RecordHash -Record $newServer
            }
            $modsList.Add($newServer) | Out-Null
            $addedCount++
        }

        # --- Launcher ---
        if ($needLauncher) {
            Write-Host "   ➕ Adding Fabric Launcher $latestVer..." -ForegroundColor Cyan
            $fabricLoader = Get-FabricVersions -GameVersion $latestVer -StableOnly
            $loaderVersion = if ($fabricLoader) { $fabricLoader.loader.version } else { "latest" }
            $jarName = if ($fabricLoader) { "fabric-server-mc.$latestVer-loader.$loaderVersion.jar" } else { "fabric-server-mc.$latestVer-loader.jar" }
            $fabricUrl = ""
            if ($fabricLoader) {
                try {
                    $installerResponse = Invoke-RestMethod -Uri "https://meta.fabricmc.net/v2/versions/installer" -Method Get -TimeoutSec 30
                    if ($installerResponse -and $installerResponse.Count -gt 0) {
                        $instVer = $installerResponse[0].version
                        $fabricUrl = "https://meta.fabricmc.net/v2/versions/loader/$latestVer/$loaderVersion/$instVer/server/jar"
                    }
                } catch { }
            }
            $newLauncher = [PSCustomObject]@{
                Group = "server"
                Type = "launcher"
                CurrentGameVersion = $latestVer
                ID = "fabric-launcher"
                Loader = "fabric"
                CurrentVersion = $loaderVersion
                Name = "Fabric Server Launcher"
                Description = "Fabric server launcher for $latestVer (loader $loaderVersion)"
                Category = "server"
                Jar = $jarName
                NextVersion = ""; NextVersionUrl = ""; NextGameVersion = ""
                LatestVersion = ""; LatestVersionUrl = ""; LatestGameVersion = ""
                Url = $fabricUrl; CurrentVersionUrl = $fabricUrl; UrlDirect = ""
                CurrentDependencies = ""; CurrentDependenciesRequired = ""; CurrentDependenciesOptional = ""
                LatestDependencies = ""; LatestDependenciesRequired = ""; LatestDependenciesOptional = ""
                Host = "fabric"; ApiSource = "fabric"
                ClientSide = "unsupported"; ServerSide = "required"
                Title = "Fabric Launcher $latestVer"
                ProjectDescription = "Fabric mod loader for Minecraft $latestVer"
                IconUrl = ""; IssuesUrl = ""; SourceUrl = ""; WikiUrl = ""
                AvailableGameVersions = $latestVer
                RecordHash = ""
            }
            if (Get-Command Calculate-RecordHash -ErrorAction SilentlyContinue) {
                $newLauncher.RecordHash = Calculate-RecordHash -Record $newLauncher
            }
            $modsList.Add($newLauncher) | Out-Null
            $addedCount++
        }

        # --- Installer (EXE + JAR) ---
        if ($needInstallers) {
            Write-Host "   ➕ Adding Fabric Installer rows for $latestVer..." -ForegroundColor Cyan
            $instVersion = "1.1.0"
            try {
                $installerResponse = Invoke-RestMethod -Uri "https://meta.fabricmc.net/v2/versions/installer" -Method Get -TimeoutSec 30
                if ($installerResponse -and $installerResponse.Count -gt 0) {
                    $instVersion = $installerResponse[0].version
                }
            } catch { }
            $exeUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/$instVersion/fabric-installer-$instVersion.exe"
            $jarUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/$instVersion/fabric-installer-$instVersion.jar"
            $installerRows = @(
                @{ Id = "fabric-installer-$latestVer-$instVersion-exe"; Name = "Fabric Installer (EXE)"; Url = $exeUrl },
                @{ Id = "fabric-installer-$latestVer-$instVersion-jar"; Name = "Fabric Installer (JAR)"; Url = $jarUrl }
            )
            foreach ($variant in $installerRows) {
                $row = [PSCustomObject]@{
                    Group = "required"
                    Type = "installer"
                    CurrentGameVersion = $latestVer
                    ID = $variant.Id
                    Loader = "fabric"
                    CurrentVersion = $instVersion
                    Name = $variant.Name
                    Description = ""
                    Category = "Infrastructure"
                    Jar = ""
                    NextVersion = ""; NextVersionUrl = ""; NextGameVersion = ""
                    LatestVersion = ""; LatestVersionUrl = ""; LatestGameVersion = ""
                    Url = $variant.Url; CurrentVersionUrl = ""; UrlDirect = ""
                    CurrentDependencies = ""; CurrentDependenciesRequired = ""; CurrentDependenciesOptional = ""
                    LatestDependencies = ""; LatestDependenciesRequired = ""; LatestDependenciesOptional = ""
                    Host = "direct"; ApiSource = "direct"
                    ClientSide = ""; ServerSide = ""
                    Title = $variant.Name; ProjectDescription = ""
                    IconUrl = ""; IssuesUrl = ""; SourceUrl = ""; WikiUrl = ""
                    AvailableGameVersions = ""
                    RecordHash = ""
                }
                if (Get-Command Calculate-RecordHash -ErrorAction SilentlyContinue) {
                    $row.RecordHash = Calculate-RecordHash -Record $row
                }
                $modsList.Add($row) | Out-Null
                $addedCount++
            }
        }

        $modsList | Export-Csv -Path $CsvPath -NoTypeInformation
        Write-Host "✅ Synced latest Minecraft version: added $addedCount row(s) for $latestVer" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Error syncing latest Minecraft version: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
