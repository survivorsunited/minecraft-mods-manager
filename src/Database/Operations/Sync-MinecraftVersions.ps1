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
        # Get available Minecraft versions
        $availableVersions = Get-MinecraftVersions -Channel $Channel -MinVersion $MinVersion -Order asc
        
        if (-not $availableVersions -or $availableVersions.Count -eq 0) {
            Write-Host "❌ No versions found to sync" -ForegroundColor Red
            return
        }
        
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
        $addedCount = 0
        
        foreach ($version in $versionsToAddServer) {
            Write-Host "   ➕ Adding Minecraft Server $version..." -ForegroundColor Cyan
            
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
                Url = ""
                CurrentVersionUrl = ""
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
            
            $mods += $newServerEntry
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
                Url = ""
                CurrentVersionUrl = ""
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
            
            $mods += $newLauncherEntry
            $addedCount++
        }
        
        # Save updated database
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        
        Write-Host ""
        Write-Host "✅ Successfully synced $addedCount new Minecraft versions" -ForegroundColor Green
        Write-Host "   Database: $CsvPath" -ForegroundColor Gray
        
    } catch {
        Write-Host "❌ Error syncing Minecraft versions: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function is available for dot-sourcing

