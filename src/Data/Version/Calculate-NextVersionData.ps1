# =============================================================================
# Calculate Next Version Data Function
# =============================================================================
# Populates Next* columns with appropriate version data for testing workflow
# =============================================================================

<#
.SYNOPSIS
    Calculates and populates Next version data for Current/Next/Latest workflow.

.DESCRIPTION
    Populates NextGameVersion, NextVersion, and NextVersionUrl columns by:
    1. Determining the next logical Minecraft version after CurrentGameVersion
    2. Finding mods that support the next game version
    3. Selecting appropriate mod versions for the next game version
    4. Populating URLs from API data or AvailableGameVersions

.PARAMETER CsvPath
    Path to the database CSV file to update.

.PARAMETER DryRun
    If specified, shows what would be updated without making changes.

.EXAMPLE
    Calculate-NextVersionData -CsvPath "modlist.csv" -DryRun
    
.EXAMPLE  
    Calculate-NextVersionData -CsvPath "modlist.csv"

.NOTES
    - Requires migrated database with Current/Next/Latest structure
    - Uses AvailableGameVersions to find supported versions
    - Updates NextGameVersion, NextVersion, NextVersionUrl columns
    - Safe to run multiple times (updates based on current data)
#>
function Calculate-NextVersionData {
    param(
        [string]$CsvPath = "modlist.csv",
        [switch]$DryRun,
        [switch]$ReturnData
    )
    
    try {
        Write-Host "🔄 Calculating Next Version Data" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        Write-Host "Database: $CsvPath" -ForegroundColor Gray
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
        $requiredColumns = @("CurrentGameVersion", "NextGameVersion", "NextVersion", "NextVersionUrl", "AvailableGameVersions")
        $existingColumns = ($mods | Get-Member -MemberType NoteProperty).Name
        $missingColumns = $requiredColumns | Where-Object { $_ -notin $existingColumns }
        
        if ($missingColumns) {
            throw "Missing required columns: $($missingColumns -join ', '). Run migration first."
        }
        
        # Calculate next game version logic
        Write-Host "🔍 Analyzing current game versions..." -ForegroundColor Yellow
        
        # Group by CurrentGameVersion to find majority version
        $versionGroups = $mods | Where-Object { $_.Type -eq "mod" -and $_.CurrentGameVersion } | Group-Object CurrentGameVersion
        $majorityVersion = ($versionGroups | Sort-Object Count -Descending | Select-Object -First 1).Name
        
        Write-Host "   Majority version: $majorityVersion" -ForegroundColor Green
        
        # Calculate next version (increment patch version)
        $versionParts = $majorityVersion -split '\.'
        if ($versionParts.Count -ge 3) {
            $nextPatchVersion = [int]$versionParts[2] + 1
            $nextGameVersion = "$($versionParts[0]).$($versionParts[1]).$nextPatchVersion"
        } else {
            throw "Unable to parse version format: $majorityVersion"
        }
        
        Write-Host "   Calculated next version: $nextGameVersion" -ForegroundColor Green
        
        # Process each mod
        $updateCount = 0
        $skipCount = 0
        $updateSummary = @()
        
        Write-Host ""
        Write-Host "🔄 Processing mods for next version data..." -ForegroundColor Yellow
        
        foreach ($mod in $mods) {
            # Skip system entries
            if ($mod.Type -ne "mod") {
                $skipCount++
                continue
            }
            
            # If no available versions metadata, still try to query API for next game version
            if ([string]::IsNullOrEmpty($mod.AvailableGameVersions)) {
                $mod.NextGameVersion = $nextGameVersion
                
                # Try to query API for the next game version
                $isGitHub = ($mod.Host -eq "github" -or $mod.ApiSource -eq "github" -or $mod.Url -match "github\.com")
                
                if ($isGitHub) {
                    # GitHub mod - query GitHub API
                    $repositoryUrl = $mod.Url
                    if (-not $repositoryUrl -and $mod.ID -match '^([^/]+)/([^/]+)$') {
                        $repositoryUrl = "https://github.com/$($mod.ID)"
                    }
                    
                    if ($repositoryUrl) {
                        try {
                            $githubModulePath = Join-Path $PSScriptRoot "..\Provider\GitHub\Validate-GitHubModVersion.ps1"
                            if (Test-Path $githubModulePath) {
                                . $githubModulePath
                            }
                            
                            $nextValidation = Validate-GitHubModVersion -ModID $repositoryUrl -Version "latest" -Loader $mod.Loader -GameVersion $nextGameVersion -Quiet
                            
                            if ($nextValidation -and $nextValidation.Success) {
                                $mod.NextVersion = $nextValidation.LatestVersion
                                $mod.NextVersionUrl = $nextValidation.LatestVersionUrl
                                
                                $updateSummary += [PSCustomObject]@{
                                    Name = $mod.Name
                                    Action = "GitHub API (no metadata)"
                                    NextVersion = $mod.NextVersion
                                    Supports = "Yes (GitHub API)"
                                }
                            } else {
                                # Fallback to current
                                $mod.NextVersion = $mod.CurrentVersion
                                $mod.NextVersionUrl = $mod.CurrentVersionUrl
                                $updateSummary += [PSCustomObject]@{
                                    Name = $mod.Name
                                    Action = "GitHub fallback (no metadata)"
                                    NextVersion = $mod.NextVersion
                                    Supports = "Unknown"
                                }
                            }
                        } catch {
                            # Fallback to current
                            $mod.NextVersion = $mod.CurrentVersion
                            $mod.NextVersionUrl = $mod.CurrentVersionUrl
                            $updateSummary += [PSCustomObject]@{
                                Name = $mod.Name
                                Action = "GitHub error (no metadata)"
                                NextVersion = $mod.NextVersion
                                Supports = "Unknown"
                            }
                        }
                    }
                } else {
                    # Prefer Latest when it matches the calculated next game version; otherwise fallback to Current
                    if (-not [string]::IsNullOrEmpty($mod.LatestGameVersion) -and $mod.LatestGameVersion -eq $nextGameVersion -and -not [string]::IsNullOrEmpty($mod.LatestVersion)) {
                        $mod.NextVersion = $mod.LatestVersion
                        $mod.NextVersionUrl = $mod.LatestVersionUrl
                        $updateSummary += [PSCustomObject]@{
                            Name = $mod.Name
                            Action = "No metadata (used latest)"
                            NextVersion = $mod.NextVersion
                            Supports = "Unknown (no AvailableGameVersions)"
                        }
                    } else {
                        $mod.NextVersion = $mod.CurrentVersion
                        $mod.NextVersionUrl = $mod.CurrentVersionUrl
                        $updateSummary += [PSCustomObject]@{
                            Name = $mod.Name
                            Action = "No metadata (used current)"
                            NextVersion = $mod.NextVersion
                            Supports = "Unknown (no AvailableGameVersions)"
                        }
                    }
                }

                $updateCount++
                continue
            }
            
            # Parse available versions
            $availableVersions = $mod.AvailableGameVersions -split ',' | Where-Object { $_ -match '^\d+\.\d+' }
            
            # Find versions that support the next game version
            $nextVersionSupported = $availableVersions | Where-Object { $_ -eq $nextGameVersion }
            
            if ($nextVersionSupported) {
                # Mod supports next game version - QUERY API FOR ACTUAL VERSION
                $mod.NextGameVersion = $nextGameVersion
                
                # Query API to get the actual version for the next game version
                try {
                    Write-Host "    Querying API for $($mod.Name) version $nextGameVersion..." -ForegroundColor Gray
                    
                    # Check if this is a GitHub mod
                    $isGitHub = ($mod.Host -eq "github" -or $mod.ApiSource -eq "github" -or $mod.Url -match "github\.com")
                    
                    if ($isGitHub) {
                        # GitHub mod - use GitHub API
                        $repositoryUrl = $mod.Url
                        if (-not $repositoryUrl -and $mod.ID -match '^([^/]+)/([^/]+)$') {
                            $repositoryUrl = "https://github.com/$($mod.ID)"
                        }
                        
                        if ($repositoryUrl) {
                            # Import GitHub functions if available
                            $githubModulePath = Join-Path $PSScriptRoot "..\Provider\GitHub\Validate-GitHubModVersion.ps1"
                            if (Test-Path $githubModulePath) {
                                . $githubModulePath
                            }
                            
                            # Validate for next game version
                            $nextValidation = Validate-GitHubModVersion -ModID $repositoryUrl -Version "latest" -Loader $mod.Loader -GameVersion $nextGameVersion -Quiet
                            
                            if ($nextValidation -and $nextValidation.Success) {
                                $mod.NextVersion = $nextValidation.LatestVersion
                                $mod.NextVersionUrl = $nextValidation.LatestVersionUrl
                                
                                Write-Host "      ✓ Found $($mod.Name) $nextGameVersion version: $($mod.NextVersion)" -ForegroundColor Green
                                
                                $updateSummary += [PSCustomObject]@{
                                    Name = $mod.Name
                                    Action = "GitHub API Updated"
                                    NextVersion = $mod.NextVersion
                                    Supports = "Yes (GitHub API verified)"
                                }
                            } else {
                                # Fallback for GitHub
                                if ($mod.LatestGameVersion -eq $nextGameVersion) {
                                    $mod.NextVersion = $mod.LatestVersion
                                    $mod.NextVersionUrl = $mod.LatestVersionUrl
                                } else {
                                    $mod.NextVersion = $mod.CurrentVersion
                                    $mod.NextVersionUrl = $mod.CurrentVersionUrl
                                }
                                
                                Write-Host "      ⚠ GitHub API fallback: $($mod.NextVersion)" -ForegroundColor Yellow
                                
                                $updateSummary += [PSCustomObject]@{
                                    Name = $mod.Name
                                    Action = "GitHub Fallback"
                                    NextVersion = $mod.NextVersion
                                    Supports = "Yes (fallback)"
                                }
                            }
                        }
                    } else {
                        # Modrinth mod - use Modrinth API
                        $apiUrl = "https://api.modrinth.com/v2/project/$($mod.ID)/version?loaders=[`"$($mod.Loader)`"]&game_versions=[`"$nextGameVersion`"]"
                        $headers = @{
                            'Accept' = 'application/json'
                            'User-Agent' = 'MinecraftModManager/1.0'
                        }
                        
                        $apiResponse = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -TimeoutSec 30
                        
                        if ($apiResponse -and $apiResponse.Count -gt 0) {
                            $nextVersion = $apiResponse[0]
                            $mod.NextVersion = $nextVersion.version_number
                            $mod.NextVersionUrl = $nextVersion.files[0].url
                            
                            Write-Host "      ✓ Found $($mod.Name) $nextGameVersion version: $($mod.NextVersion)" -ForegroundColor Green
                            
                            $updateSummary += [PSCustomObject]@{
                                Name = $mod.Name
                                Action = "API Updated"
                                NextVersion = $mod.NextVersion
                                Supports = "Yes (API verified)"
                            }
                        } else {
                            # No API response, fallback to latest if it supports next game version
                            if ($mod.LatestGameVersion -eq $nextGameVersion) {
                                $mod.NextVersion = $mod.LatestVersion
                                $mod.NextVersionUrl = $mod.LatestVersionUrl
                            } else {
                                $mod.NextVersion = $mod.CurrentVersion
                                $mod.NextVersionUrl = $mod.CurrentVersionUrl
                            }
                            
                            Write-Host "      ⚠ No API response, using fallback: $($mod.NextVersion)" -ForegroundColor Yellow
                            
                            $updateSummary += [PSCustomObject]@{
                                Name = $mod.Name
                                Action = "Fallback"
                                NextVersion = $mod.NextVersion
                                Supports = "Yes (fallback)"
                            }
                        }
                    }
                } catch {
                    # API error, use fallback
                    Write-Host "      ❌ API error for $($mod.Name): $($_.Exception.Message)" -ForegroundColor Red
                    
                    if ($mod.LatestGameVersion -eq $nextGameVersion) {
                        $mod.NextVersion = $mod.LatestVersion
                        $mod.NextVersionUrl = $mod.LatestVersionUrl
                    } else {
                        $mod.NextVersion = $mod.CurrentVersion
                        $mod.NextVersionUrl = $mod.CurrentVersionUrl
                    }
                    
                    $updateSummary += [PSCustomObject]@{
                        Name = $mod.Name
                        Action = "Error Fallback"
                        NextVersion = $mod.NextVersion
                        Supports = "Unknown"
                    }
                }
                
                $updateCount++
            } else {
                # Find highest compatible version below next
                $compatibleVersions = $availableVersions | Where-Object { 
                    $vParts = $_ -split '\.'
                    if ($vParts.Count -ge 3) {
                        $major = [int]$vParts[0]
                        $minor = [int]$vParts[1]
                        # Handle patches like '4-pre3' by extracting numeric portion
                        $patchToken = [string]$vParts[2]
                        $patchMatch = [regex]::Match($patchToken, '\d+')
                        $patch = if ($patchMatch.Success) { [int]$patchMatch.Value } else { -1 }
                        
                        $major -eq [int]$versionParts[0] -and 
                        $minor -eq [int]$versionParts[1] -and
                        $patch -ge 0 -and $patch -le [int]$nextPatchVersion
                    }
                } | Sort-Object { [Version]($_ -replace '[^\d.]', '') } -Descending
                
                $mod.NextGameVersion = $nextGameVersion
                
                if ($compatibleVersions) {
                    # Use current version (best available for current game version)
                    $mod.NextVersion = $mod.CurrentVersion
                    $mod.NextVersionUrl = $mod.CurrentVersionUrl
                    
                    $updateSummary += [PSCustomObject]@{
                        Name = $mod.Name
                        Action = "Fallback"
                        NextVersion = $mod.NextVersion
                        Supports = "No (using current)"
                    }
                } else {
                    # No compatible version found
                    $mod.NextVersion = ""
                    $mod.NextVersionUrl = ""
                    
                    $updateSummary += [PSCustomObject]@{
                        Name = $mod.Name
                        Action = "No compatible version"
                        NextVersion = ""
                        Supports = "No"
                    }
                }
                $updateCount++
            }
        }
        
        if ($DryRun) {
            Write-Host ""
            Write-Host "🔍 DRY RUN SUMMARY:" -ForegroundColor Yellow
            Write-Host "Next Game Version: $nextGameVersion" -ForegroundColor Cyan
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
            $backupPath = Join-Path $backupDir "$timestamp-pre-nextversion-$(Split-Path $CsvPath -Leaf)"
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
            Write-Host "✅ NEXT VERSION DATA CALCULATED!" -ForegroundColor Green
            Write-Host "=================================" -ForegroundColor Green
            Write-Host "Next Game Version: $nextGameVersion" -ForegroundColor Green
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
        Write-Host "❌ Failed to calculate next version data: $($_.Exception.Message)" -ForegroundColor Red
        if ($ReturnData) {
            return @()
        }
        return $false
    }
}

# Function is available for dot-sourcing