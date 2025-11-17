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
        [string]$AddModGameVersion = "1.21.8",
        [string]$AddModVersion = "current",
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
            } elseif ($AddModUrl -match "modrinth\.com/datapack/([^/]+)") {
                $AddModId = $matches[1]
            } elseif ($AddModUrl -match "modrinth\.com/resourcepack/([^/]+)") {
                $AddModId = $matches[1]
            } elseif ($AddModUrl -match "modrinth\.com/plugin/([^/]+)") {
                $AddModId = $matches[1]
            } elseif ($AddModUrl -match "curseforge\.com/minecraft/mc-mods/([^/]+)") {
                $AddModId = $matches[1]
            } elseif ($AddModUrl -match "maven\.fabricmc\.net") {
                # For Fabric installer URLs, extract version from filename first
                $installerVersion = ""
                $fileExt = "exe"
                if ($AddModUrl -match "fabric-installer-([\d\.]+)\.(exe|jar)") {
                    $installerVersion = $matches[1]
                    $fileExt = $matches[2]
                }
                # Use game version + installer version + extension to ensure uniqueness per game version
                $versionPart = if ($installerVersion) { $installerVersion } else { "unknown" }
                $AddModId = "fabric-installer-$AddModGameVersion-$versionPart-$fileExt"
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

        # Initialize extracted version and name
        $extractedVersion = ""
        $extractedName = $AddModName

        # Detect Fabric installer from maven.fabricmc.net URLs FIRST (before other URL processing)
        $isFabricInstaller = $false
        if ($AddModUrl -and $AddModUrl -match "maven\.fabricmc\.net.*fabric-installer") {
            $isFabricInstaller = $true
            if (-not $AddModCategory) { $AddModCategory = "Infrastructure" }
            
            # Extract version and name from filename (e.g., fabric-installer-1.1.0.exe -> 1.1.0)
            if ($AddModUrl -match "fabric-installer-([\d\.]+)\.(exe|jar)") {
                $extractedVersion = $matches[1]
                $fileExt = $matches[2]
                Write-Host "  Detected Fabric installer, extracted version from URL: $extractedVersion" -ForegroundColor Gray
                
                # Extract name from URL filename if name not provided
                if ([string]::IsNullOrEmpty($AddModName)) {
                    # Get filename from URL (e.g., fabric-installer-1.1.0.exe)
                    $urlParts = $AddModUrl -split '/'
                    $filename = $urlParts[-1]
                    # Remove extension for cleaner name (e.g., fabric-installer-1.1.0)
                    $extractedName = $filename -replace '\.(exe|jar)$', ''
                    Write-Host "  Extracted name from URL: $extractedName" -ForegroundColor Gray
                }
            }
        }
        
        if ($AddModUrl -and $AddModUrl -match "modrinth\.com" -and -not $isFabricInstaller) {
            # For Modrinth URLs, try to get project info to extract name, detect type, and find best version
            # Only set version if not already extracted (e.g., from Fabric installer URL)
            if ([string]::IsNullOrEmpty($extractedVersion)) {
                # Only set version if not already extracted (e.g., from Fabric installer URL)
            if ([string]::IsNullOrEmpty($extractedVersion)) {
                $extractedVersion = $AddModVersion
            }
            }
            try {
                $projectInfo = Get-ModrinthProjectInfo -ProjectId $AddModId -UseCachedResponses $false
                if ($projectInfo) {
                    # Extract name if not provided
                    if (-not $AddModName -and $projectInfo.title) {
                        $extractedName = $projectInfo.title
                    }
                    
                    # Auto-detect project type based on loaders
                    if ($projectInfo.loaders) {
                        if ($projectInfo.loaders -contains "datapack") {
                            # If it supports datapack, treat it as a datapack
                            # This handles both pure datapacks and mixed projects
                            $AddModType = "datapack"
                        } elseif ($projectInfo.project_type) {
                            # Use the project_type from API (mod, shader, etc.)
                            $AddModType = $projectInfo.project_type
                        }
                        # else keep the provided/default type
                    }
                    
                    # Auto-detect best version for the specified game version if version is "latest"
                    if ($AddModVersion -eq "latest" -and $AddModGameVersion) {
                        try {
                            # Use the validation function to find the best version
                            $validationResult = Validate-ModVersion -ModId $AddModId -Version "latest" -Loader $AddModLoader -GameVersion $AddModGameVersion -Quiet
                            if ($validationResult -and $validationResult.LatestVersion) {
                                $extractedVersion = $validationResult.LatestVersion
                                Write-Host "  Auto-detected best version for ${AddModGameVersion}: $extractedVersion" -ForegroundColor Gray
                            }
                        } catch {
                            Write-Host "  Warning: Could not auto-detect version, using latest" -ForegroundColor Yellow
                        }
                    }
                    
                    Write-Host "  Auto-detected project type: $AddModType" -ForegroundColor Gray
                }
            } catch {
                # If API call fails, use ID as name and keep default type
                if (-not $AddModName) {
                    $extractedName = $AddModId
                }
                Write-Host "  Warning: Could not fetch project info for type detection" -ForegroundColor Yellow
            }
        } elseif ($AddModUrl -and $AddModUrl -match "curseforge\.com") {
            # For CurseForge URLs, detect type from URL pattern first
            if (-not $AddModType) {
                if ($AddModUrl -match "/mc-mods/") {
                    $AddModType = "mod"
                } elseif ($AddModUrl -match "/texture-packs/") {
                    $AddModType = "resourcepack"
                } elseif ($AddModUrl -match "/customization/") {
                    $AddModType = "datapack"
                } else {
                    $AddModType = "mod"  # Default for CurseForge
                }
                Write-Host "  Auto-detected type from URL: $AddModType (/mc-mods/ pattern)" -ForegroundColor Gray
            }
            
            # Resolve slug to numeric ID when necessary
            if ($AddModId -and ($AddModId -notmatch '^\d+$')) {
                $resolvedId = Resolve-CurseForgeProjectId -Identifier $AddModId -Quiet
                if ($resolvedId) {
                    Write-Host "  Resolved CurseForge ID: $AddModId -> $resolvedId" -ForegroundColor Gray
                    $AddModId = $resolvedId
                } else {
                    Write-Host "  Warning: Could not resolve numeric CurseForge ID for slug '$AddModId'" -ForegroundColor Yellow
                }
            }
            
            # Then try to get project info to extract name and validate type
            # Only set version if not already extracted (e.g., from Fabric installer URL)
            if ([string]::IsNullOrEmpty($extractedVersion)) {
                $extractedVersion = $AddModVersion
            }
            try {
                $projectInfo = Get-CurseForgeProjectInfo -ProjectId $AddModId -UseCachedResponses $false
                if ($projectInfo -and $projectInfo.data) {
                    # Extract name if not provided
                    if (-not $AddModName -and $projectInfo.data.name) {
                        $extractedName = $projectInfo.data.name
                    }
                    
                    # Validate/refine type based on CurseForge category if available
                    if ($projectInfo.data.classId) {
                        # ClassId 6 = Mods, 12 = Resource Packs, etc.
                        # Only override if we have specific info from API
                        # For now, trust our URL-based detection
                    }
                    
                    Write-Host "  Confirmed project type: $AddModType (CurseForge)" -ForegroundColor Gray
                } else {
                    Write-Host "❌ Error: Project not found on CurseForge (ID/slug: $AddModId)" -ForegroundColor Red
                    Write-Host "   The project ID may be incorrect or the mod may not exist" -ForegroundColor Yellow
                    # Don't hard fail; allow adding by ID/URL so user can fix later
                }
            } catch {
                Write-Host "❌ Error: Failed to fetch CurseForge project info: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "   Proceeding to add entry with provided information" -ForegroundColor Yellow
            }
        } else {
            # Default version for manual entries
            # Only set version if not already extracted (e.g., from Fabric installer URL)
            if ([string]::IsNullOrEmpty($extractedVersion)) {
                $extractedVersion = $AddModVersion
            }
            # Only set name if not already extracted (e.g., from Fabric installer URL)
            if (-not $AddModName -and [string]::IsNullOrEmpty($extractedName)) {
                $extractedName = $AddModId
            }
        }

        # Auto-assign URL for server types from environment variables
        if ($AddModType -eq "server" -and -not $AddModUrl) {
            if ($AddModId -match "minecraft-server" -and $env:MINECRAFT_SERVER_URL) {
                $AddModUrl = $env:MINECRAFT_SERVER_URL
                Write-Host "  Auto-assigned Minecraft server URL from environment" -ForegroundColor Gray
            } elseif ($AddModId -match "fabric-server" -and $env:FABRIC_SERVER_URL) {
                $AddModUrl = $env:FABRIC_SERVER_URL
                Write-Host "  Auto-assigned Fabric server URL from environment" -ForegroundColor Gray
            }
        } elseif ($AddModType -eq "launcher" -and -not $AddModUrl) {
            if ($AddModId -match "fabric-server-launcher" -and $env:FABRIC_SERVER_URL) {
                $AddModUrl = $env:FABRIC_SERVER_URL
                Write-Host "  Auto-assigned Fabric launcher URL from environment" -ForegroundColor Gray
            } elseif ($AddModId -match "fabric-installer") {
                # For Fabric installers, we need to construct the URL dynamically
                try {
                    $fabricUrl = if ($env:FABRIC_SERVER_URL) { $env:FABRIC_SERVER_URL } else { "https://meta.fabricmc.net/v2/versions" }
                    $fabricVersions = Invoke-RestMethod -Uri $fabricUrl -UseBasicParsing
                    
                    # Get latest loader and installer versions
                    $latestLoader = $fabricVersions.loader | Select-Object -First 1
                    $latestInstaller = $fabricVersions.installer | Select-Object -First 1
                    
                    if ($latestLoader -and $latestInstaller) {
                        $AddModUrl = "https://meta.fabricmc.net/v2/versions/loader/$AddModGameVersion/$($latestLoader.version)/$($latestInstaller.version)/installer/jar"
                        Write-Host "  Auto-generated Fabric installer URL" -ForegroundColor Gray
                    }
                } catch {
                    Write-Host "  Warning: Could not generate Fabric installer URL" -ForegroundColor Yellow
                }
            }
        }

        # Re-check if mod exists after any ID normalization (e.g., CurseForge slug -> numeric ID)
        $existingModPost = $mods | Where-Object { $_.ID -eq $AddModId }
        if ($existingModPost) {
            Write-Host "Warning: Mod with ID '$AddModId' already exists in database" -ForegroundColor Yellow
            return $false
        }

        # Determine source/host based on URL or ID pattern
        # Priority: Fabric installer (maven.fabricmc.net) -> direct
        # Then: explicit CurseForge URL -> curseforge
        # Otherwise: numeric ID implies CurseForge -> curseforge
        # Fallback: modrinth
        $apiSource = "modrinth"
        $providerHost = "modrinth"
        if ($isFabricInstaller) {
            $apiSource = "direct"
            $providerHost = "direct"
        } elseif ($AddModUrl -and $AddModUrl -match "curseforge\.com") {
            $apiSource = "curseforge"
            $providerHost = "curseforge"
        } elseif ($AddModId -and $AddModId -match '^[0-9]+$') {
            # Numeric IDs are used for CurseForge projects
            $apiSource = "curseforge"
            $providerHost = "curseforge"
        }

        # Create new mod entry
        $newMod = [PSCustomObject]@{
            Group = $AddModGroup
            Type = $AddModType
            CurrentGameVersion = $AddModGameVersion
            ID = $AddModId
            Loader = $AddModLoader
            CurrentVersion = $extractedVersion
            Name = $extractedName
            Description = $AddModDescription
            Jar = $AddModJar
            Url = $AddModUrl
            Category = $AddModCategory
            CurrentVersionUrl = ""
            NextVersion = ""
            NextVersionUrl = ""
            NextGameVersion = ""
            LatestVersionUrl = ""
            LatestVersion = ""
            ApiSource = $apiSource
            Host = $providerHost
            IconUrl = ""
            ClientSide = if ($isFabricInstaller) { "" } else { "optional" }
            ServerSide = if ($isFabricInstaller) { "" } else { "optional" }
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

        # Compute and set RecordHash
        try {
            $hashValue = $null
            if (Get-Command Calculate-RecordHash -ErrorAction SilentlyContinue) {
                $hashValue = Calculate-RecordHash -Record $newMod
            } else {
                # Inline fallback: compute SHA256 over sorted key=value (excluding RecordHash)
                $kv = @()
                $newMod.PSObject.Properties |
                    Where-Object { $_.Name -ne 'RecordHash' } |
                    ForEach-Object { $kv += (\"$($_.Name)=$($_.Value)\") }
                $kv = $kv | Sort-Object
                $recordString = ($kv -join '|')
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($recordString)
                $sha256 = [System.Security.Cryptography.SHA256]::Create()
                $hashBytes = $sha256.ComputeHash($bytes)
                $hashValue = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLower()
            }
            if ($hashValue) { $newMod.RecordHash = $hashValue }
        } catch {
            # leave RecordHash empty on error
        }

        # Add to mods array
        $mods += $newMod

        # Save back to CSV
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation

        Write-Host "✅ Successfully added mod '$extractedName' to database" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Error adding mod to database: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} 