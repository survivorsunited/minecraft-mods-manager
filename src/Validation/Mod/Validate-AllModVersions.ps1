# =============================================================================
# All Mod Versions Validation Module
# =============================================================================
# This module handles validation of all mod versions in a list.
# =============================================================================

<#
.SYNOPSIS
    Validates all mods in the list.

.DESCRIPTION
    Validates all mod versions in a CSV file and provides comprehensive
    analysis and recommendations.

.PARAMETER CsvPath
    The path to the CSV file.

.PARAMETER DatabaseFile
    The database file path.

.PARAMETER ModListFile
    The modlist file path.

.PARAMETER ResponseFolder
    The folder for API responses.

.PARAMETER UpdateModList
    Whether to update the modlist with latest versions.

.EXAMPLE
    Validate-AllModVersions -CsvPath "modlist.csv" -UpdateModList

.NOTES
    - Validates all mods excluding installer, launcher, server types
    - Provides comprehensive analysis and recommendations
    - Can update modlist with latest versions
#>
function Validate-AllModVersions {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$DatabaseFile,
        [string]$ModListFile,
        [string]$ResponseFolder = $ApiResponseFolder,
        [switch]$UpdateModList
    )
    
    $effectiveModListPath = Get-EffectiveModListPath -DatabaseFile $DatabaseFile -ModListFile $ModListFile -ModListPath $CsvPath
    $mods = Get-ModList -CsvPath $effectiveModListPath
    if (-not $mods) {
        return
    }
    
    $results = @()
    
    # Count total mods to validate (excluding installer, launcher, server types)
    $modsToValidate = $mods | Where-Object { 
        -not [string]::IsNullOrEmpty($_.ID) -and 
        $_.Type -notin @("installer", "launcher", "server") 
    }
    $totalMods = $modsToValidate.Count
    $currentMod = 0
    
    foreach ($mod in $modsToValidate) {
        $currentMod++
        $percentComplete = [math]::Round(($currentMod / $totalMods) * 100)
        Write-Progress -Activity "Validating mod versions" -Status "Processing $($mod.Name)" -PercentComplete $percentComplete -CurrentOperation "Validating $currentMod of $totalMods"
        
        # Get loader from CSV, default to "fabric" if not specified
        $loader = if (-not [string]::IsNullOrEmpty($mod.Loader)) { $mod.Loader.Trim() } else { $DefaultLoader }
        # Get host from CSV, default to "modrinth" if not specified
        $modHost = if (-not [string]::IsNullOrEmpty($mod.Host)) { $mod.Host } else { "modrinth" }
        # Get game version from CSV, default to "1.21.5" if not specified
        $gameVersion = if (-not [string]::IsNullOrEmpty($mod.GameVersion)) { $mod.GameVersion } else { $DefaultGameVersion }
        # Get JAR filename from CSV
        $jarFilename = if (-not [string]::IsNullOrEmpty($mod.Jar)) { $mod.Jar } else { "" }
        
        # Use appropriate API based on host (suppress output)
        if ($modHost -eq "curseforge") {
            $result = Validate-CurseForgeModVersion -ModId $mod.ID -Version $mod.Version -Loader $loader -ResponseFolder $ResponseFolder -Jar $jarFilename -ModUrl $mod.URL -Quiet
        } else {
            # If version is empty, treat as "get latest version" request
            $versionToCheck = if ([string]::IsNullOrEmpty($mod.Version)) { "latest" } else { $mod.Version }
            $result = Validate-ModVersion -ModId $mod.ID -Version $versionToCheck -Loader $loader -ResponseFolder $ResponseFolder -Jar $jarFilename -Quiet
        }
        
        # Show result with current vs latest version comparison
        $currentVersion = $mod.Version ?? "none"
        $latestVersion = $result.LatestVersion ?? "unknown"
        
        # Determine status and colors based on game version compatibility
        $targetGameVersion = $mod.GameVersion ?? $DefaultGameVersion
        $currentSupportsTarget = $false
        $latestSupportsTarget = $false
        
        # Check if current version supports target game version
        if ($result.Exists -and $result.LatestGameVersion) {
            $currentSupportsTarget = $result.LatestGameVersion -eq $targetGameVersion
        }
        
        # Check if latest version supports target game version
        if ($result.Exists -and $result.LatestGameVersion) {
            $latestSupportsTarget = $result.LatestGameVersion -eq $targetGameVersion
        }
        
        if (-not $result.Exists) {
            $statusIcon = "❌"
            $statusColor = "Red"
            $currentColor = "Red"
            $latestColor = "Red"
        } elseif ([string]::IsNullOrEmpty($latestVersion) -or $latestVersion -eq "No $loader versions found") {
            $statusIcon = "❌"
            $statusColor = "Red"
            $currentColor = "Yellow"
            $latestColor = "Red"
        } elseif ($currentVersion -eq $latestVersion) {
            $statusIcon = "➖"
            $statusColor = "Gray"
            $currentColor = "Gray"
            $latestColor = "Gray"
        } else {
            $statusIcon = "⬆️"
            $statusColor = "Yellow"
            $currentColor = "Red"
            $latestColor = "Green"
        }
        
        # Log detailed info but don't show in terminal
        $logMessage = "[$currentMod/$totalMods] $($mod.Name) $currentVersion → $latestVersion $statusIcon"
        
        $results += [PSCustomObject]@{
            Name = $mod.Name
            ID = $mod.ID
            ExpectedVersion = $mod.Version
            Loader = $loader
            Host = $modHost
            VersionExists = $result.Exists
            ResponseFile = $result.ResponseFile
            Error = $result.Error
            AvailableVersions = if ($result.AvailableVersions) { $result.AvailableVersions -join ', ' } else { $null }
            LatestVersion = $result.LatestVersion
            VersionUrl = $result.VersionUrl
            LatestVersionUrl = $result.LatestVersionUrl
            IconUrl = $result.IconUrl
            ClientSide = $result.ClientSide
            ServerSide = $result.ServerSide
            Title = $result.Title
            ProjectDescription = $result.ProjectDescription
            IssuesUrl = if ($result.IssuesUrl) { $result.IssuesUrl.ToString() } else { "" }
            SourceUrl = if ($result.SourceUrl) { $result.SourceUrl.ToString() } else { "" }
            WikiUrl = if ($result.WikiUrl) { $result.WikiUrl.ToString() } else { "" }
            VersionFoundByJar = $result.VersionFoundByJar
            LatestGameVersion = $result.LatestGameVersion
            CurrentDependencies = $result.CurrentDependencies
            LatestDependencies = $result.LatestDependencies
            CurrentDependenciesRequired = $result.CurrentDependenciesRequired
            CurrentDependenciesOptional = $result.CurrentDependenciesOptional
            LatestDependenciesRequired = $result.LatestDependenciesRequired
            LatestDependenciesOptional = $result.LatestDependenciesOptional
        }
    }
    
    Write-Progress -Activity "Validating mod versions" -Completed
    
    # Save results to CSV
    $resultsFile = Join-Path $ResponseFolder "version-validation-results.csv"
    $results | Export-Csv -Path $resultsFile -NoTypeInformation
    
    # Analyze version differences and provide upgrade recommendations
    Write-Host ""
    
    $modsNotSupportingLatest = @()
    $modsSupportingLatest = @()
    $modsNotUpdated = @()
    $modsWithUpdates = @()
    $modsExternallyUpdated = @()
    $modsNotFound = @()
    $modsWithErrors = @()
    
    foreach ($result in $results) {
        if (-not $result.VersionExists) {
            if ([string]::IsNullOrEmpty($result.Error)) {
                $modsNotFound += $result
            } else {
                $modsWithErrors += $result
            }
            continue
        }
        
        $currentVersion = $result.ExpectedVersion ?? "none"
        $latestVersion = $result.LatestVersion ?? "unknown"
        $latestGameVersion = $result.LatestGameVersion ?? "unknown"
        
        # Use the calculated latest game version from the summary logic
        # This will be calculated later in the code, so we'll use a placeholder for now
        # The actual calculation will be done in the summary section
        $targetGameVersion = $null  # Will be set later
        
        # Check if mod supports latest game version
        # A mod supports latest if its game version is >= target game version
        $supportsLatest = $false
        if ($latestGameVersion -and $targetGameVersion) {
            # Convert version strings to comparable format
            $latestVersionParts = $latestGameVersion -split '\.'
            $targetVersionParts = $targetGameVersion -split '\.'
            
            # Compare major.minor versions
            if ($latestVersionParts.Count -ge 2 -and $targetVersionParts.Count -ge 2) {
                $latestMajor = [int]$latestVersionParts[0]
                $latestMinor = [int]$latestVersionParts[1]
                $targetMajor = [int]$targetVersionParts[0]
                $targetMinor = [int]$targetVersionParts[1]
                
                $supportsLatest = ($latestMajor -gt $targetMajor) -or 
                                (($latestMajor -eq $targetMajor) -and ($latestMinor -ge $targetMinor))
            } else {
                # Fallback to string comparison if version format is unexpected
                $supportsLatest = $latestGameVersion -eq $targetGameVersion
            }
        }
        
        # Check if mod has version updates available
        $hasUpdates = $currentVersion -ne $latestVersion -and -not [string]::IsNullOrEmpty($latestVersion)
        
        # Check if mod was externally updated (this would be from the earlier external changes detection)
        $wasExternallyUpdated = $false # This would be set based on the external changes detection
        
        if (-not $supportsLatest) {
            $modsNotSupportingLatest += $result
        } else {
            $modsSupportingLatest += $result
        }
        
        if ($hasUpdates) {
            $modsWithUpdates += $result
        } else {
            $modsNotUpdated += $result
        }
        
        if ($wasExternallyUpdated) {
            $modsExternallyUpdated += $result
        }
    }
    
    # Find most common GameVersion in database to determine target
    $gameVersions = $results | Where-Object { $_.GameVersion -and $_.GameVersion -ne "unknown" } | Select-Object -ExpandProperty GameVersion
    $mostCommonGameVersion = if ($gameVersions) {
        $gameVersionCounts = $gameVersions | Group-Object | Sort-Object Count -Descending
        $gameVersionCounts[0].Name
    } else {
        $DefaultGameVersion
    }
    
    # Use the new function to calculate Latest Game Version from actual available versions
    # Get all available game versions from all mods
    $allModAvailableGameVersions = @()
    Write-Host "DEBUG: Processing $($results.Count) results for available game versions" -ForegroundColor Yellow
    foreach ($result in $results) {
        if ($result.AvailableGameVersions -and $result.AvailableGameVersions.Count -gt 0) {
            Write-Host "DEBUG: Adding $($result.AvailableGameVersions.Count) game versions from $($result.ID)" -ForegroundColor Yellow
            $allModAvailableGameVersions += $result.AvailableGameVersions
        } else {
            Write-Host "DEBUG: No available game versions for $($result.ID)" -ForegroundColor Yellow
        }
    }
    $allModAvailableGameVersions = $allModAvailableGameVersions | Select-Object -Unique | Sort-Object
    Write-Host "DEBUG: Total unique available game versions: $($allModAvailableGameVersions.Count)" -ForegroundColor Yellow
    
    # Calculate Latest Game Version and Latest Available Game Versions using actual API data
    $versionCalculation = Calculate-LatestGameVersionFromAvailableVersions -AvailableGameVersions $allModAvailableGameVersions -CurrentGameVersion $mostCommonGameVersion
    $calculatedLatestGameVersion = $versionCalculation.LatestGameVersion
    $latestAvailableGameVersions = $versionCalculation.LatestAvailableGameVersions
    
    # Filter out ancient versions from Latest Available Game Versions
    $filteredLatestAvailableVersions = Filter-RelevantGameVersions -GameVersions $latestAvailableGameVersions -MinimumRelevantVersion "1.20.0"
    $availableGameVersionsString = if ($filteredLatestAvailableVersions) { ($filteredLatestAvailableVersions | Sort-Object) -join ", " } else { "unknown" }

    # Show summary with total counts
    Write-Host ""
    Write-Host "📊 Update Summary:" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host "   🕹️  Latest Game Version: $calculatedLatestGameVersion" -ForegroundColor Cyan
    Write-Host "   🗂️  Latest Available Game Versions: $availableGameVersionsString" -ForegroundColor Cyan
    Write-Host "   🎯 Supporting latest version: $($modsSupportingLatest.Count) mods" -ForegroundColor Green
    Write-Host "   ⬆️  Have updates available: $($modsWithUpdates.Count) mods" -ForegroundColor Cyan
    Write-Host "   ⚠️  Not supporting latest version: $($modsNotSupportingLatest.Count) mods" -ForegroundColor Yellow
    Write-Host "   ➖ Not updated: $($modsNotUpdated.Count) mods" -ForegroundColor Gray
    Write-Host "   🔄 Externally updated: $($modsExternallyUpdated.Count) mods" -ForegroundColor Blue
    Write-Host "   ❌ Not found: $($modsNotFound.Count) mods" -ForegroundColor Red
    Write-Host "   ⚠️  Errors: $($modsWithErrors.Count) mods" -ForegroundColor Red
    
    # Update modlist with latest versions if requested
    if ($UpdateModList) {
        # Load current modlist
        $currentMods = Get-ModList -CsvPath $effectiveModListPath
        if (-not $currentMods) {
            Write-Host "❌ Failed to load current modlist" -ForegroundColor Red
            return
        }
        
        # Ensure CSV has required columns including dependency columns
        $currentMods = Ensure-CsvColumns -CsvPath $effectiveModListPath
        if (-not $currentMods) {
            Write-Host "❌ Failed to ensure CSV columns" -ForegroundColor Red
            return
        }
        
        $updatedCount = 0
        $newMods = @()
        
        foreach ($currentMod in $currentMods) {
            # Find matching validation result
            $validationResult = $results | Where-Object { $_.ID -eq $currentMod.ID -and $_.Host -eq $currentMod.Host } | Select-Object -First 1
            
            if ($validationResult -and $validationResult.VersionExists) {
                # Update with latest information
                $updatedMod = $currentMod.PSObject.Copy()
                $updatedMod.LatestVersion = $validationResult.LatestVersion
                $updatedMod.VersionUrl = $validationResult.VersionUrl
                $updatedMod.LatestVersionUrl = $validationResult.LatestVersionUrl
                $updatedMod.IconUrl = $validationResult.IconUrl
                $updatedMod.ClientSide = $validationResult.ClientSide
                $updatedMod.ServerSide = $validationResult.ServerSide
                $updatedMod.Title = $validationResult.Title
                $updatedMod.ProjectDescription = $validationResult.ProjectDescription
                $updatedMod.IssuesUrl = $validationResult.IssuesUrl
                $updatedMod.SourceUrl = $validationResult.SourceUrl
                $updatedMod.WikiUrl = $validationResult.WikiUrl
                $updatedMod.LatestGameVersion = $validationResult.LatestGameVersion
                $updatedMod.CurrentDependencies = $validationResult.CurrentDependencies
                $updatedMod.LatestDependencies = $validationResult.LatestDependencies
                # Create new object with all properties including new dependency fields
                $updatedMod = [PSCustomObject]@{
                    Group = $currentMod.Group
                    Type = $currentMod.Type
                    GameVersion = $currentMod.GameVersion
                    ID = $currentMod.ID
                    Loader = $currentMod.Loader
                    Version = $currentMod.Version
                    Name = $currentMod.Name
                    Description = $currentMod.Description
                    Jar = $currentMod.Jar
                    Url = $currentMod.Url
                    Category = $currentMod.Category
                    VersionUrl = $validationResult.VersionUrl
                    LatestVersionUrl = $validationResult.LatestVersionUrl
                    LatestVersion = $validationResult.LatestVersion
                    ApiSource = $currentMod.ApiSource
                    Host = $currentMod.Host
                    IconUrl = $validationResult.IconUrl
                    ClientSide = $validationResult.ClientSide
                    ServerSide = $validationResult.ServerSide
                    Title = $validationResult.Title
                    ProjectDescription = $validationResult.ProjectDescription
                    IssuesUrl = $validationResult.IssuesUrl
                    SourceUrl = $validationResult.SourceUrl
                    WikiUrl = $validationResult.WikiUrl
                    LatestGameVersion = $validationResult.LatestGameVersion
                    RecordHash = $currentMod.RecordHash
                    CurrentDependencies = $validationResult.CurrentDependencies
                    LatestDependencies = $validationResult.LatestDependencies
                    CurrentDependenciesRequired = $validationResult.CurrentDependenciesRequired
                    CurrentDependenciesOptional = $validationResult.CurrentDependenciesOptional
                    LatestDependenciesRequired = $validationResult.LatestDependenciesRequired
                    LatestDependenciesOptional = $validationResult.LatestDependenciesOptional
                }
                
                if ($newMods.Count -eq 0) {
                    $newMods = @($updatedMod)
                } else {
                    $newMods += $updatedMod
                }
                $updatedCount++
            } else {
                # Keep existing mod as-is
                if ($newMods.Count -eq 0) {
                    $newMods = @($currentMod)
                } else {
                    $newMods += $currentMod
                }
            }
        }
        
        # Save updated modlist
        $newMods | Export-Csv -Path $effectiveModListPath -NoTypeInformation
        
        Write-Host "✅ Updated $updatedCount mods with latest information" -ForegroundColor Green
    }
    
    return $results
}

# Function is available for dot-sourcing 