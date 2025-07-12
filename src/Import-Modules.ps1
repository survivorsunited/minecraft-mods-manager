# Import all modular functions
# This script loads all the modular functions from the src/ directory structure

# Core modules
. "$PSScriptRoot\Core\Environment\Load-EnvironmentVariables.ps1"
. "$PSScriptRoot\Core\Paths\Get-EffectiveModListPath.ps1"
. "$PSScriptRoot\Core\Paths\Get-ApiResponsePath.ps1"

# Validation modules
. "$PSScriptRoot\Validation\Hash\Calculate-FileHash.ps1"
. "$PSScriptRoot\Validation\Hash\Calculate-RecordHash.ps1"
. "$PSScriptRoot\Validation\Hash\Test-FileHash.ps1"
. "$PSScriptRoot\Validation\Hash\Test-RecordHash.ps1"
. "$PSScriptRoot\Validation\Mod\Validate-AllVersions.ps1"

# Data processing modules
. "$PSScriptRoot\Data\Version\Normalize-Version.ps1"
. "$PSScriptRoot\Data\Version\Get-MajorityGameVersion.ps1"
. "$PSScriptRoot\Data\Dependencies\Convert-DependenciesToJson.ps1"
. "$PSScriptRoot\Data\Dependencies\Convert-DependenciesToJsonRequired.ps1"
. "$PSScriptRoot\Data\Dependencies\Convert-DependenciesToJsonOptional.ps1"
. "$PSScriptRoot\Data\Dependencies\Set-Equals.ps1"

# Database modules
. "$PSScriptRoot\Database\CSV\Get-ModList.ps1"
. "$PSScriptRoot\Database\CSV\Ensure-Columns.ps1"
. "$PSScriptRoot\Database\CSV\Clean-SystemEntries.ps1"
. "$PSScriptRoot\Database\CSV\Update-WithLatestVersions.ps1"

# API modules
. "$PSScriptRoot\API\Modrinth\Get-ProjectInfo.ps1"
. "$PSScriptRoot\API\Modrinth\Validate-Version.ps1"
. "$PSScriptRoot\API\CurseForge\Validate-Version.ps1"

# Download modules
. "$PSScriptRoot\Download\Mod\Download-Mods.ps1"
. "$PSScriptRoot\Download\Modpack\Download-Modpack.ps1"
. "$PSScriptRoot\Download\Server\Download-ServerFiles.ps1"

# File utility modules
. "$PSScriptRoot\File\Backup\Get-BackupPath.ps1"
. "$PSScriptRoot\File\Utility\Clean-Filename.ps1"

# Display modules
. "$PSScriptRoot\Display\Help\Show-Help.ps1"
. "$PSScriptRoot\Display\Summary\Show-VersionSummary.ps1"
. "$PSScriptRoot\Display\Summary\Write-DownloadReadme.ps1"

Write-Host "✅ All modular functions imported successfully" -ForegroundColor Green 