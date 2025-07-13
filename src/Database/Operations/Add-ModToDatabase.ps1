# =============================================================================
# Add Mod To Database Function
# =============================================================================
# This function adds a new mod to the CSV database with proper validation
# =============================================================================

<#
.SYNOPSIS
    Adds a new mod to the CSV database.
.DESCRIPTION
    Adds a new mod entry to the CSV database with validation and proper formatting.
    Currently supports CSV storage provider only.
.PARAMETER AddModId
    The mod ID to add.
.PARAMETER AddModUrl
    The mod URL.
.PARAMETER AddModName
    The mod name.
.PARAMETER AddModLoader
    The mod loader (fabric, forge, etc.).
.PARAMETER AddModGameVersion
    The Minecraft game version.
.PARAMETER AddModType
    The mod type (mod, shaderpack, etc.).
.PARAMETER AddModGroup
    The mod group (required, optional, block, etc.).
.PARAMETER AddModDescription
    The mod description.
.PARAMETER AddModJar
    The mod JAR filename.
.PARAMETER AddModUrlDirect
    Direct download URL for the mod.
.PARAMETER AddModCategory
    The mod category.
.PARAMETER ForceDownload
    Force download the mod file.
.PARAMETER CsvPath
    Path to the CSV database file.
.EXAMPLE
    Add-ModToDatabase -AddModId "fabric-api" -AddModName "Fabric API" -AddModLoader "fabric" -AddModGameVersion "1.21.5"
#>
function Add-ModToDatabase {
    param(
        [string]$AddModId,
        [string]$AddModUrl,
        [string]$AddModName,
        [string]$AddModLoader = "fabric",
        [string]$AddModGameVersion = "1.21.5",
        [string]$AddModType = "mod",
        [string]$AddModGroup = "required",
        [string]$AddModDescription = "",
        [string]$AddModJar = "",
        [string]$AddModUrlDirect = "",
        [string]$AddModCategory = "",
        [switch]$ForceDownload,
        [string]$CsvPath = "modlist.csv"
    )

    try {
        # Validate required parameters
        if (-not $AddModId -and -not $AddModUrl) {
            Write-Host "Error: Either AddModId or AddModUrl must be provided" -ForegroundColor Red
            return $false
        }

        # Load existing mods - ensure it's always an array
        $mods = @()
        if (Test-Path $CsvPath) {
            $importedMods = Import-Csv -Path $CsvPath
            if ($importedMods) {
                $mods = @($importedMods)
            }
        }

        # Check if mod already exists
        $existingMod = $mods | Where-Object { $_.ID -eq $AddModId }
        if ($existingMod) {
            Write-Host "Warning: Mod with ID '$AddModId' already exists in database" -ForegroundColor Yellow
            return $false
        }

        # Create new mod entry
        $newMod = [PSCustomObject]@{
            Group = $AddModGroup
            Type = $AddModType
            GameVersion = $AddModGameVersion
            ID = $AddModId
            Loader = $AddModLoader
            Version = ""
            Name = $AddModName
            Description = $AddModDescription
            Jar = $AddModJar
            Url = $AddModUrl
            Category = $AddModCategory
            VersionUrl = ""
            LatestVersionUrl = ""
            LatestVersion = ""
            ApiSource = "modrinth"
            Host = "modrinth"
            IconUrl = ""
            ClientSide = "optional"
            ServerSide = "optional"
            Title = $AddModName
            ProjectDescription = $AddModDescription
            IssuesUrl = ""
            SourceUrl = ""
            WikiUrl = ""
            LatestGameVersion = ""
            RecordHash = ""
            CurrentDependencies = ""
            LatestDependencies = ""
            CurrentDependenciesRequired = ""
            CurrentDependenciesOptional = ""
            LatestDependenciesRequired = ""
            LatestDependenciesOptional = ""
        }

        # Add to mods array
        $mods += $newMod

        # Save back to CSV
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation

        Write-Host "✅ Successfully added mod '$AddModName' to database" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Error adding mod to database: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} 