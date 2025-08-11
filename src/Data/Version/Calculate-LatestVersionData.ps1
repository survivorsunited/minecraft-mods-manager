# =============================================================================
# Calculate Latest Version Data Function
# =============================================================================
# Populates Latest* columns with appropriate version data for testing workflow
# =============================================================================

<#
.SYNOPSIS
    Calculates and populates Latest version data for Current/Next/Latest workflow.

.DESCRIPTION
    Populates LatestGameVersion, LatestVersion, and LatestVersionUrl columns by:
    1. Determining the latest logical Minecraft version (1.21.8)
    2. Finding mods that support the latest game version
    3. Selecting appropriate mod versions for the latest game version
    4. Populating URLs from API data or AvailableGameVersions

.PARAMETER CsvPath
    Path to the database CSV file to update.

.PARAMETER DryRun
    If specified, shows what would be updated without making changes.

.PARAMETER TargetLatestVersion
    Override the calculated latest version (default: 1.21.8).

.EXAMPLE
    Calculate-LatestVersionData -CsvPath "modlist.csv" -DryRun
    
.EXAMPLE  
    Calculate-LatestVersionData -CsvPath "modlist.csv"

.NOTES
    - Requires migrated database with Current/Next/Latest structure
    - Uses AvailableGameVersions to find supported versions
    - Updates LatestGameVersion, LatestVersion, LatestVersionUrl columns
    - Safe to run multiple times (updates based on current data)
#>
function Calculate-LatestVersionData {
    param(
        [string]$CsvPath = "modlist.csv",
        [string]$TargetLatestVersion = "1.21.8",
        [switch]$DryRun,
        [switch]$ReturnData
    )
    
    try {
        Write-Host "🔄 Calculating Latest Version Data" -ForegroundColor Cyan
        Write-Host "===================================" -ForegroundColor Cyan
        Write-Host "Database: $CsvPath" -ForegroundColor Gray
        Write-Host "Target Latest Version: $TargetLatestVersion" -ForegroundColor Gray
        Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'UPDATE MODE' })" -ForegroundColor Gray
        Write-Host ""
        
        # Check if file exists
        if (-not (Test-Path $CsvPath)) {
            throw "Database file not found: $CsvPath"
        }
        
        # Load database  
        Write-Host "📊 Loading database..." -ForegroundColor Yellow
        $mods = Import-Csv -Path $CsvPath
        Write-Host "   Loaded $($mods.Count) records" -ForegroundColor Green
        
        # Verify new structure exists
        $requiredColumns = @("CurrentGameVersion", "LatestGameVersion", "LatestVersion", "LatestVersionUrl", "AvailableGameVersions")
        $existingColumns = ($mods | Get-Member -MemberType NoteProperty).Name
        $missingColumns = $requiredColumns | Where-Object { $_ -notin $existingColumns }
        
        if ($missingColumns) {
            throw "Missing required columns: $($missingColumns -join ', '). Run migration first."
        }
        
        Write-Host "🔍 Using latest game version: $TargetLatestVersion" -ForegroundColor Yellow
        
        # Process each mod
        $updateCount = 0
        $skipCount = 0
        $updateSummary = @()
        
        Write-Host ""
        Write-Host "🔄 Processing mods for latest version data..." -ForegroundColor Yellow
        
        foreach ($mod in $mods) {
            # Skip system entries
            if ($mod.Type -ne "mod") {
                $skipCount++
                continue
            }
            
            # Skip if no available versions data
            if ([string]::IsNullOrEmpty($mod.AvailableGameVersions)) {
                $mod.LatestGameVersion = $TargetLatestVersion
                $mod.LatestVersion = ""
                $mod.LatestVersionUrl = ""
                $skipCount++
                continue
            }
            
            # Parse available versions
            $availableVersions = $mod.AvailableGameVersions -split ',' | Where-Object { $_ -match '^\d+\.\d+' }
            
            # Find versions that support the latest game version
            $latestVersionSupported = $availableVersions | Where-Object { $_ -eq $TargetLatestVersion }
            
            if ($latestVersionSupported) {
                # Mod supports latest game version - QUERY API FOR ACTUAL VERSION
                $mod.LatestGameVersion = $TargetLatestVersion
                
                # Query API to get the actual version for the latest game version
                try {
                    Write-Host "    Querying API for $($mod.Name) version $TargetLatestVersion..." -ForegroundColor Gray
                    
                    $apiUrl = "https://api.modrinth.com/v2/project/$($mod.ID)/version?loaders=[`"fabric`"]&game_versions=[`"$TargetLatestVersion`"]"
                    $headers = @{
                        'Accept' = 'application/json'
                        'User-Agent' = 'MinecraftModManager/1.0'
                    }
                    
                    $apiResponse = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -TimeoutSec 30
                    
                    if ($apiResponse -and $apiResponse.Count -gt 0) {
                        $latestVersion = $apiResponse[0]
                        $mod.LatestVersion = $latestVersion.version_number
                        $mod.LatestVersionUrl = $latestVersion.files[0].url
                        
                        Write-Host "      ✓ Found $($mod.Name) $TargetLatestVersion version: $($mod.LatestVersion)" -ForegroundColor Green
                        
                        $updateSummary += [PSCustomObject]@{
                            Name = $mod.Name
                            Action = "API Updated"
                            LatestVersion = $mod.LatestVersion
                            Supports = "Yes (API verified)"
                        }
                    } else {
                        # No API response, use current version as fallback
                        $mod.LatestVersion = $mod.CurrentVersion
                        $mod.LatestVersionUrl = $mod.CurrentVersionUrl
                        
                        Write-Host "      ⚠ No API response for $TargetLatestVersion, using current: $($mod.LatestVersion)" -ForegroundColor Yellow
                        
                        $updateSummary += [PSCustomObject]@{
                            Name = $mod.Name
                            Action = "Fallback to Current"
                            LatestVersion = $mod.LatestVersion
                            Supports = "No (using current)"
                        }
                    }
                } catch {
                    # API error, use current version as fallback
                    Write-Host "      ❌ API error for $($mod.Name): $($_.Exception.Message)" -ForegroundColor Red
                    
                    $mod.LatestVersion = $mod.CurrentVersion
                    $mod.LatestVersionUrl = $mod.CurrentVersionUrl
                    
                    $updateSummary += [PSCustomObject]@{
                        Name = $mod.Name
                        Action = "Error Fallback to Current"
                        LatestVersion = $mod.LatestVersion
                        Supports = "Unknown"
                    }
                }
                
                $updateCount++
            } else {
                # Mod doesn't support latest game version - use highest available version
                $compatibleVersions = $availableVersions | Sort-Object { [Version]($_ -replace '[^\d.]', '') } -Descending
                
                $mod.LatestGameVersion = $TargetLatestVersion
                
                if ($compatibleVersions) {
                    # Use highest available version (even if not latest game version)
                    $highestVersion = $compatibleVersions[0]
                    
                    # Query API for the highest available version
                    try {
                        Write-Host "    Querying API for $($mod.Name) highest version $highestVersion..." -ForegroundColor Gray
                        
                        $apiUrl = "https://api.modrinth.com/v2/project/$($mod.ID)/version?loaders=[`"fabric`"]&game_versions=[`"$highestVersion`"]"
                        $headers = @{
                            'Accept' = 'application/json'
                            'User-Agent' = 'MinecraftModManager/1.0'
                        }
                        
                        $apiResponse = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -TimeoutSec 30
                        
                        if ($apiResponse -and $apiResponse.Count -gt 0) {
                            $latestVersion = $apiResponse[0]
                            $mod.LatestVersion = $latestVersion.version_number
                            $mod.LatestVersionUrl = $latestVersion.files[0].url
                            
                            Write-Host "      ✓ Found $($mod.Name) highest available: $($mod.LatestVersion)" -ForegroundColor Green
                            
                            $updateSummary += [PSCustomObject]@{
                                Name = $mod.Name
                                Action = "Highest Available"
                                LatestVersion = $mod.LatestVersion
                                Supports = "No (using $highestVersion)"
                            }
                        } else {
                            # Fallback to current version
                            $mod.LatestVersion = $mod.CurrentVersion
                            $mod.LatestVersionUrl = $mod.CurrentVersionUrl
                            
                            $updateSummary += [PSCustomObject]@{
                                Name = $mod.Name
                                Action = "Fallback to Current"
                                LatestVersion = $mod.LatestVersion
                                Supports = "No"
                            }
                        }
                    } catch {
                        # API error, fallback to current
                        $mod.LatestVersion = $mod.CurrentVersion
                        $mod.LatestVersionUrl = $mod.CurrentVersionUrl
                        
                        $updateSummary += [PSCustomObject]@{
                            Name = $mod.Name
                            Action = "Error Fallback"
                            LatestVersion = $mod.LatestVersion
                            Supports = "Unknown"
                        }
                    }
                } else {
                    # No compatible version found
                    $mod.LatestVersion = $mod.CurrentVersion
                    $mod.LatestVersionUrl = $mod.CurrentVersionUrl
                    
                    $updateSummary += [PSCustomObject]@{
                        Name = $mod.Name
                        Action = "No compatible version"
                        LatestVersion = $mod.LatestVersion
                        Supports = "No"
                    }
                }
                $updateCount++
            }
        }
        
        if ($DryRun) {
            Write-Host ""
            Write-Host "🔍 DRY RUN SUMMARY:" -ForegroundColor Yellow
            Write-Host "Latest Game Version: $TargetLatestVersion" -ForegroundColor Cyan
            Write-Host "Mods to update: $updateCount" -ForegroundColor Green
            Write-Host "Mods to skip: $skipCount" -ForegroundColor Gray
            
            # Show first 10 examples
            Write-Host ""
            Write-Host "📋 Update Examples (first 10):" -ForegroundColor Yellow
            $updateSummary | Select-Object -First 10 | Format-Table -AutoSize
            
            Write-Host ""
            Write-Host "🔍 Use without -DryRun to apply changes." -ForegroundColor Yellow
            return $true
        }
        
        # Initialize backup path variable
        $backupPath = ""
        
        # Only save to disk if not returning data for validation
        if (-not $ReturnData) {
            # Create backup
            Write-Host ""
            Write-Host "💾 Creating backup..." -ForegroundColor Yellow
            $backupDir = "backups"
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backupPath = Join-Path $backupDir "$timestamp-pre-latestversion-$(Split-Path $CsvPath -Leaf)"
            Copy-Item -Path $CsvPath -Destination $backupPath -Force
            Write-Host "   Backup created: $backupPath" -ForegroundColor Green
            
            # Save updated data
            Write-Host ""
            Write-Host "💾 Saving updated data..." -ForegroundColor Yellow
            $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        }
        
        # Summary (only if not returning data for validation)
        if (-not $ReturnData) {
            Write-Host ""
            Write-Host "✅ LATEST VERSION DATA CALCULATED!" -ForegroundColor Green
            Write-Host "===================================" -ForegroundColor Green
            Write-Host "Latest Game Version: $TargetLatestVersion" -ForegroundColor Green
            Write-Host "Mods updated: $updateCount" -ForegroundColor Green
            Write-Host "Mods skipped: $skipCount" -ForegroundColor Green
            Write-Host "Backup: $backupPath" -ForegroundColor Green
            
            # Show summary by action
            Write-Host ""
            Write-Host "📊 Update Summary by Action:" -ForegroundColor Cyan
            $actionSummary = $updateSummary | Group-Object Action
            foreach ($group in $actionSummary) {
                Write-Host "   $($group.Name): $($group.Count) mods" -ForegroundColor Yellow
            }
        }
        
        # Return data if requested for validation integration
        if ($ReturnData) {
            return $mods
        }
        
        return $true
        
    } catch {
        Write-Host ""
        Write-Host "❌ Failed to calculate latest version data: $($_.Exception.Message)" -ForegroundColor Red
        if ($ReturnData) {
            return @()
        }
        return $false
    }
}

# Function is available for dot-sourcing