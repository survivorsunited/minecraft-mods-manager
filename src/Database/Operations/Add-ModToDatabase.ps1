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

        # Extract ID from URL if not provided
        if (-not $AddModId -and $AddModUrl) {
            if ($AddModUrl -match "modrinth\.com/mod/([^/]+)") {
                $AddModId = $matches[1]
            } elseif ($AddModUrl -match "modrinth\.com/shader/([^/]+)") {
                $AddModId = $matches[1]
            } elseif ($AddModUrl -match "curseforge\.com/minecraft/mc-mods/([^/]+)") {
                $AddModId = $matches[1]
            } elseif ($AddModUrl -match "maven\.fabricmc\.net") {
                # For Fabric installer URLs, use a system-specific ID with game version
                $AddModId = "fabric-installer-$AddModGameVersion"
            } elseif ($AddModUrl -match "meta\.fabricmc\.net") {
                # For Fabric server launcher URLs, use a system-specific ID with game version
                $AddModId = "fabric-server-launcher-$AddModGameVersion"
            } elseif ($AddModUrl -match "piston-data\.mojang\.com") {
                # For Mojang server URLs, use a system-specific ID with game version
                $AddModId = "minecraft-server-$AddModGameVersion"
            } else {
                # For other URLs, generate a unique ID based on the URL
                $urlHash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($AddModUrl))
                $AddModId = "system-" + [System.BitConverter]::ToString($urlHash).Replace("-", "").Substring(0, 8).ToLower()
            }
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

        # Extract version and name from URL if provided
        $extractedVersion = ""
        $extractedName = $AddModName
        
        if ($AddModUrl -and $AddModUrl -match "modrinth\.com") {
            # For Modrinth URLs, try to get project info to extract name
            $extractedVersion = "latest"
            if (-not $AddModName) {
                try {
                    $projectInfo = Get-ModrinthProjectInfo -ProjectId $AddModId -UseCachedResponses $false
                    if ($projectInfo -and $projectInfo.title) {
                        $extractedName = $projectInfo.title
                    }
                } catch {
                    # If API call fails, use ID as name
                    $extractedName = $AddModId
                }
            }
        } elseif ($AddModUrl -and $AddModUrl -match "curseforge\.com") {
            # For CurseForge URLs, we'll set a default version that can be updated later
            $extractedVersion = "latest"
            if (-not $AddModName) {
                $extractedName = $AddModId
            }
        } else {
            # Default version for manual entries
            $extractedVersion = "latest"
            if (-not $AddModName) {
                $extractedName = $AddModId
            }
        }

        # Create new mod entry
        $newMod = [PSCustomObject]@{
            Group = $AddModGroup
            Type = $AddModType
            GameVersion = $AddModGameVersion
            ID = $AddModId
            Loader = $AddModLoader
            Version = $extractedVersion
            Name = $extractedName
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
            Title = $extractedName
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