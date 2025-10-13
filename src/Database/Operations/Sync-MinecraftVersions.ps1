# =============================================================================
# Minecraft Versions Sync Module
# =============================================================================
# This module handles syncing Minecraft versions to the database.
# =============================================================================

<#
.SYNOPSIS
    Syncs available Minecraft versions to the database.

.DESCRIPTION
    Fetches available Minecraft versions from mc-versions-api.net and adds
    missing server entries to the database.

.PARAMETER CsvPath
    Path to the CSV database file.

.PARAMETER Channel
    Release channel (stable, snapshot). Default: stable

.PARAMETER MinVersion
    Minimum version to sync (e.g., "1.21.5"). Default: 1.21.5

.PARAMETER DryRun
    Show what would be added without making changes.

.EXAMPLE
    Sync-MinecraftVersions -CsvPath "modlist.csv" -MinVersion "1.21.5"

.EXAMPLE
    Sync-MinecraftVersions -CsvPath "modlist.csv" -DryRun

.NOTES
    - Adds both Minecraft server and Fabric launcher entries
    - Only adds missing versions (doesn't duplicate)
    - Automatically resolves download URLs
#>
function Sync-MinecraftVersions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [string]$Channel = "stable",
        [string]$MinVersion = "1.21.5",
        [switch]$DryRun = $false
    )
    
    try {
        # Get available Minecraft versions from Mojang's official API
        $versionObjects = Get-MojangVersions -MinVersion $MinVersion -Order asc
        
        if (-not $versionObjects -or $versionObjects.Count -eq 0) {
            Write-Host "❌ No versions found to sync" -ForegroundColor Red
            return
        }
        
        # Extract version IDs for display
        $availableVersions = $versionObjects | ForEach-Object { $_.id }
        
        Write-Host ""
        Write-Host "📋 Available Minecraft Versions (>= $MinVersion):" -ForegroundColor Cyan
        $availableVersions | ForEach-Object { Write-Host "   • $_" -ForegroundColor White }
        
        # Load existing database
        $mods = Import-Csv -Path $CsvPath
        $existingServerVersions = $mods | Where-Object { $_.Type -eq "server" } | Select-Object -ExpandProperty CurrentGameVersion
        $existingLauncherVersions = $mods | Where-Object { $_.Type -eq "launcher" } | Select-Object -ExpandProperty CurrentGameVersion
        
        # Find versions to add
        $versionsToAddServer = $availableVersions | Where-Object { $existingServerVersions -notcontains $_ }
        $versionsToAddLauncher = $availableVersions | Where-Object { $existingLauncherVersions -notcontains $_ }
        
        Write-Host ""
        Write-Host "📊 Sync Summary:" -ForegroundColor Cyan
        Write-Host "   Total available versions: $($availableVersions.Count)" -ForegroundColor White
        Write-Host "   Existing server versions: $($existingServerVersions.Count)" -ForegroundColor Gray
        Write-Host "   New server versions: $($versionsToAddServer.Count)" -ForegroundColor Green
        Write-Host "   New launcher versions: $($versionsToAddLauncher.Count)" -ForegroundColor Green
        
        if ($versionsToAddServer.Count -eq 0 -and $versionsToAddLauncher.Count -eq 0) {
            Write-Host ""
            Write-Host "✅ All versions already in database - no sync needed" -ForegroundColor Green
            return
        }
        
        if ($DryRun) {
            Write-Host ""
            Write-Host "🔍 DRY RUN - Would add these versions:" -ForegroundColor Yellow
            if ($versionsToAddServer.Count -gt 0) {
                Write-Host "   Servers:" -ForegroundColor Cyan
                $versionsToAddServer | ForEach-Object { Write-Host "     • $_" -ForegroundColor White }
            }
            if ($versionsToAddLauncher.Count -gt 0) {
                Write-Host "   Launchers:" -ForegroundColor Cyan
                $versionsToAddLauncher | ForEach-Object { Write-Host "     • $_" -ForegroundColor White }
            }
            return
        }
        
        # Add new versions to database
        # Convert to ArrayList for efficient appending
        $modsList = [System.Collections.ArrayList]::new()
        $mods | ForEach-Object { $modsList.Add($_) | Out-Null }
        $addedCount = 0
        
        foreach ($version in $versionsToAddServer) {
            Write-Host "   ➕ Adding Minecraft Server $version..." -ForegroundColor Cyan
            
            # Get version details to extract server download URL
            $versionObj = $versionObjects | Where-Object { $_.id -eq $version } | Select-Object -First 1
            $serverUrl = ""
            
            if ($versionObj -and $versionObj.url) {
                try {
                    Write-Host "      🔍 Fetching server download URL..." -ForegroundColor Gray
                    $versionDetails = Invoke-RestMethod -Uri $versionObj.url -Method Get -TimeoutSec 30
                    if ($versionDetails.downloads.server.url) {
                        $serverUrl = $versionDetails.downloads.server.url
                        Write-Host "      ✓ Found server download URL" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "      ⚠️  Could not fetch server URL: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
            
            $newServerEntry = [PSCustomObject]@{
                Group = "server"
                Type = "server"
                CurrentGameVersion = $version
                ID = "minecraft-server"
                Loader = "vanilla"
                CurrentVersion = $version
                Name = "Minecraft Server"
                Description = "Official Minecraft Server JAR for $version"
                Category = "server"
                Jar = "minecraft_server.$version.jar"
                NextVersion = ""
                NextVersionUrl = ""
                NextGameVersion = ""
                LatestVersion = ""
                LatestVersionUrl = ""
                LatestGameVersion = ""
                Url = $serverUrl
                CurrentVersionUrl = $serverUrl
                UrlDirect = ""
                CurrentDependencies = ""
                CurrentDependenciesRequired = ""
                CurrentDependenciesOptional = ""
                LatestDependencies = ""
                LatestDependenciesRequired = ""
                LatestDependenciesOptional = ""
                Host = "mojang"
                ApiSource = "mojang"
                ClientSide = "optional"
                ServerSide = "required"
                Title = "Minecraft Server $version"
                ProjectDescription = "Official Minecraft Java Edition Server"
                IconUrl = ""
                IssuesUrl = ""
                SourceUrl = ""
                WikiUrl = ""
                AvailableGameVersions = $version
                RecordHash = ""
            }
            
            $modsList.Add($newServerEntry) | Out-Null
            $addedCount++
        }
        
        foreach ($version in $versionsToAddLauncher) {
            Write-Host "   ➕ Adding Fabric Launcher $version..." -ForegroundColor Cyan
            
            # Get actual Fabric loader version from Fabric Meta API
            $fabricLoader = Get-FabricVersions -GameVersion $version -StableOnly
            $loaderVersion = if ($fabricLoader) { $fabricLoader.loader.version } else { "latest" }
            $jarName = if ($fabricLoader) { 
                "fabric-server-mc.$version-loader.$loaderVersion.jar" 
            } else { 
                "fabric-server-mc.$version-loader.jar" 
            }
            
            # Get installer version and construct download URL
            $fabricUrl = ""
            if ($fabricLoader) {
                try {
                    Write-Host "      🔍 Fetching Fabric installer version..." -ForegroundColor Gray
                    $installerResponse = Invoke-RestMethod -Uri "https://meta.fabricmc.net/v2/versions/installer" -Method Get -TimeoutSec 30
                    if ($installerResponse -and $installerResponse.Count -gt 0) {
                        $latestInstaller = $installerResponse[0].version
                        $fabricUrl = "https://meta.fabricmc.net/v2/versions/loader/$version/$loaderVersion/$latestInstaller/server/jar"
                        Write-Host "      ✓ Fabric URL: .../$version/$loaderVersion/$latestInstaller/server/jar" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "      ⚠️  Could not construct Fabric URL: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
            
            $newLauncherEntry = [PSCustomObject]@{
                Group = "server"
                Type = "launcher"
                CurrentGameVersion = $version
                ID = "fabric-launcher"
                Loader = "fabric"
                CurrentVersion = $loaderVersion
                Name = "Fabric Server Launcher"
                Description = "Fabric server launcher for $version (loader $loaderVersion)"
                Category = "server"
                Jar = $jarName
                NextVersion = ""
                NextVersionUrl = ""
                NextGameVersion = ""
                LatestVersion = ""
                LatestVersionUrl = ""
                LatestGameVersion = ""
                Url = $fabricUrl
                CurrentVersionUrl = $fabricUrl
                UrlDirect = ""
                CurrentDependencies = ""
                CurrentDependenciesRequired = ""
                CurrentDependenciesOptional = ""
                LatestDependencies = ""
                LatestDependenciesRequired = ""
                LatestDependenciesOptional = ""
                Host = "fabric"
                ApiSource = "fabric"
                ClientSide = "unsupported"
                ServerSide = "required"
                Title = "Fabric Launcher $version"
                ProjectDescription = "Fabric mod loader for Minecraft $version"
                IconUrl = ""
                IssuesUrl = ""
                SourceUrl = ""
                WikiUrl = ""
                AvailableGameVersions = $version
                RecordHash = ""
            }
            
            $modsList.Add($newLauncherEntry) | Out-Null
            $addedCount++
        }
        
        # Save updated database
        $modsList | Export-Csv -Path $CsvPath -NoTypeInformation
        
        Write-Host ""
        Write-Host "✅ Successfully synced $addedCount new Minecraft versions" -ForegroundColor Green
        Write-Host "   Database: $CsvPath" -ForegroundColor Gray
        
    } catch {
        Write-Host "❌ Error syncing Minecraft versions: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function is available for dot-sourcing

