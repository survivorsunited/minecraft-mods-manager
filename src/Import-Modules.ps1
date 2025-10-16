# Import all modular functions
# This script loads all the modular functions from the src/ directory structure

# Core modules
. "$PSScriptRoot\Core\Environment\Load-EnvironmentVariables.ps1"
. "$PSScriptRoot\Core\Paths\Get-EffectiveModListPath.ps1"
. "$PSScriptRoot\Core\Paths\Get-ApiResponsePath.ps1"

# Validation modules
. "$PSScriptRoot\Validation\Hash\Get-FileHash.ps1"
. "$PSScriptRoot\Validation\Hash\Calculate-RecordHash.ps1"
. "$PSScriptRoot\Validation\Hash\Test-FileHash.ps1"
. "$PSScriptRoot\Validation\Hash\Test-RecordHash.ps1"
. "$PSScriptRoot\Validation\Mod\Validate-AllModVersions.ps1"
. "$PSScriptRoot\Validation\Database\Validate-ModVersionUrls.ps1"

# Data processing modules
. "$PSScriptRoot\Data\Version\Normalize-Version.ps1"
. "$PSScriptRoot\Data\Version\Get-MajorityGameVersion.ps1"
. "$PSScriptRoot\Data\Version\Get-CurrentVersion.ps1"
. "$PSScriptRoot\Data\Version\Get-NextVersion.ps1"
. "$PSScriptRoot\Data\Version\Get-LatestVersion.ps1"
. "$PSScriptRoot\Data\Version\Get-MajorityLatestGameVersion.ps1"
. "$PSScriptRoot\Data\Version\Calculate-LatestGameVersionFromAvailableVersions.ps1"
. "$PSScriptRoot\Data\Version\Calculate-NextGameVersion.ps1"
. "$PSScriptRoot\Data\Version\Calculate-NextVersionData.ps1"
. "$PSScriptRoot\Data\Version\Calculate-LatestVersionData.ps1"
. "$PSScriptRoot\Data\Version\Filter-RelevantGameVersions.ps1"
. "$PSScriptRoot\Data\Utility\Convert-DependenciesToJson.ps1"
. "$PSScriptRoot\Data\Utility\Clean-SystemEntries.ps1"

# Database modules
. "$PSScriptRoot\Database\CSV\Get-ModList.ps1"
. "$PSScriptRoot\Database\CSV\Ensure-Columns.ps1"
. "$PSScriptRoot\Database\CSV\Clean-SystemEntries.ps1"
. "$PSScriptRoot\Database\CSV\Update-WithLatestVersions.ps1"
. "$PSScriptRoot\Database\Operations\Add-ModToDatabase.ps1"
. "$PSScriptRoot\Database\Operations\Delete-ModFromDatabase.ps1"
. "$PSScriptRoot\Database\Operations\Update-ModUrlInDatabase.ps1"
. "$PSScriptRoot\Database\Operations\Sync-MinecraftVersions.ps1"
. "$PSScriptRoot\Database\Operations\Sync-JDKVersions.ps1"
. "$PSScriptRoot\Database\Maintenance\Reorder-CsvColumns.ps1"
. "$PSScriptRoot\Database\Migration\Migrate-ToCurrentNextLatest.ps1"

# Provider modules (consolidated from API folder)
. "$PSScriptRoot\Provider\Common.ps1"
. "$PSScriptRoot\Provider\Modrinth\Get-ModrinthProjectInfo.ps1"
. "$PSScriptRoot\Provider\Modrinth\Validate-ModrinthModVersion.ps1"
. "$PSScriptRoot\Provider\Modrinth\Search-ModrinthProjects.ps1"
. "$PSScriptRoot\Provider\CurseForge\Get-CurseForgeProjectInfo.ps1"
. "$PSScriptRoot\Provider\CurseForge\Get-CurseForgeFileInfo.ps1"
. "$PSScriptRoot\Provider\CurseForge\Validate-CurseForgeModVersion.ps1"
. "$PSScriptRoot\Provider\Mojang\Get-MojangServerInfo.ps1"
. "$PSScriptRoot\Provider\Mojang\Get-MojangVersions.ps1"
. "$PSScriptRoot\Provider\Fabric\Get-FabricLoaderInfo.ps1"
. "$PSScriptRoot\Provider\Fabric\Get-FabricVersions.ps1"
. "$PSScriptRoot\Provider\Minecraft\Get-MinecraftVersions.ps1"
. "$PSScriptRoot\Provider\Adoptium\Get-AdoptiumJDK.ps1"

# Download modules
. "$PSScriptRoot\Download\Mods\Download-Mods.ps1"
. "$PSScriptRoot\Download\Modpack\Download-Modpack.ps1"
. "$PSScriptRoot\Download\Server\Download-ServerFiles.ps1"
. "$PSScriptRoot\Download\Server\Download-ServerFilesFromDatabase.ps1"
. "$PSScriptRoot\Download\Server\Start-MinecraftServer.ps1"
. "$PSScriptRoot\Download\JDK\Download-JDK.ps1"

# File utility modules
. "$PSScriptRoot\File\Get-BackupPath.ps1"
. "$PSScriptRoot\File\Clean-Filename.ps1"
. "$PSScriptRoot\File\Calculate-FileHash.ps1"
. "$PSScriptRoot\File\Add-ServerStartScript.ps1"

# Display modules
. "$PSScriptRoot\Display\Help\Show-Help.ps1"
. "$PSScriptRoot\Display\Summary\Show-VersionSummary.ps1"
. "$PSScriptRoot\Display\Summary\Write-DownloadReadme.ps1"

# Release modules
. "$PSScriptRoot\Release\Copy-ModsToRelease.ps1"

Write-Host "✅ All modular functions imported successfully" -ForegroundColor Green 