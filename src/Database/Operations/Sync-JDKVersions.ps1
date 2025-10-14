# =============================================================================
# JDK Versions Sync Module
# =============================================================================
# This module handles syncing JDK versions to the database.
# =============================================================================

<#
.SYNOPSIS
    Syncs JDK versions to the database.

.DESCRIPTION
    Fetches JDK download information from Adoptium API and adds
    JDK entries to the database for automatic download management.

.PARAMETER CsvPath
    Path to the CSV database file.

.PARAMETER Versions
    JDK versions to sync (e.g., @("17", "21")). Default: @("17", "21")

.PARAMETER Platforms
    OS platforms to sync (e.g., @("windows", "linux", "mac")). Default: @("windows", "linux", "mac")

.PARAMETER DryRun
    Show what would be added without making changes.

.EXAMPLE
    Sync-JDKVersions -CsvPath "modlist.csv"

.EXAMPLE
    Sync-JDKVersions -CsvPath "modlist.csv" -Versions @("21") -Platforms @("windows") -DryRun

.NOTES
    - Adds JDK entries with type='jdk'
    - Supports Windows, Linux, and macOS
    - Uses Adoptium (Eclipse Temurin) builds
#>
function Sync-JDKVersions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        [string[]]$Versions = @("17", "21"),
        [string[]]$Platforms = @("windows", "linux", "mac"),
        [switch]$DryRun = $false
    )
    
    try {
        Write-Host ""
        Write-Host "🔄 Syncing JDK Versions" -ForegroundColor Cyan
        Write-Host "======================" -ForegroundColor Cyan
        Write-Host ""
        
        # Load existing database
        $mods = Import-Csv -Path $CsvPath
        $existingJDKs = $mods | Where-Object { $_.Type -eq "jdk" }
        
        Write-Host "📊 Current Status:" -ForegroundColor Cyan
        Write-Host "   Existing JDK entries: $($existingJDKs.Count)" -ForegroundColor White
        Write-Host "   Target versions: $($Versions -join ', ')" -ForegroundColor White
        Write-Host "   Target platforms: $($Platforms -join ', ')" -ForegroundColor White
        Write-Host ""
        
        # Collect JDKs to add
        $jdksToAdd = @()
        
        foreach ($version in $Versions) {
            foreach ($platform in $Platforms) {
                # Check if this JDK already exists
                $existingJDK = $existingJDKs | Where-Object { 
                    $_.CurrentVersion -like "$version.*" -and $_.Category -eq $platform
                }
                
                if ($existingJDK) {
                    Write-Host "   ⏭️  JDK $version ($platform) already exists" -ForegroundColor Gray
                    continue
                }
                
                # Fetch JDK info from Adoptium
                $jdkInfo = Get-AdoptiumJDK -Version $version -OS $platform
                
                if (-not $jdkInfo -or -not $jdkInfo.Success) {
                    Write-Host "   ⚠️  Could not fetch JDK $version for $platform" -ForegroundColor Yellow
                    continue
                }
                
                $jdksToAdd += @{
                    Version = $version
                    Platform = $platform
                    Info = $jdkInfo
                }
            }
        }
        
        if ($jdksToAdd.Count -eq 0) {
            Write-Host "✅ All JDK versions already in database - no sync needed" -ForegroundColor Green
            return
        }
        
        Write-Host ""
        Write-Host "📋 JDKs to Add: $($jdksToAdd.Count)" -ForegroundColor Cyan
        
        if ($DryRun) {
            Write-Host ""
            Write-Host "🔍 DRY RUN - Would add these JDKs:" -ForegroundColor Yellow
            $jdksToAdd | ForEach-Object {
                Write-Host "   • JDK $($_.Version) for $($_.Platform) - v$($_.Info.Version)" -ForegroundColor White
            }
            return
        }
        
        # Convert to ArrayList for efficient appending
        $modsList = [System.Collections.ArrayList]::new()
        $mods | ForEach-Object { $modsList.Add($_) | Out-Null }
        
        # Add JDK entries
        $addedCount = 0
        
        foreach ($jdk in $jdksToAdd) {
            $version = $jdk.Version
            $platform = $jdk.Platform
            $info = $jdk.Info
            
            Write-Host "   ➕ Adding JDK $version for $platform..." -ForegroundColor Cyan
            
            # Determine folder name based on platform
            $folderName = switch ($platform) {
                "windows" { "jdk-$version-windows" }
                "linux" { "jdk-$version-linux" }
                "mac" { "jdk-$version-macos" }
            }
            
            $newJDKEntry = [PSCustomObject]@{
                Group = "infrastructure"
                Type = "jdk"
                CurrentGameVersion = ""
                ID = "jdk-$version-$platform"
                Loader = ""
                CurrentVersion = $info.Version
                Name = "OpenJDK $version ($platform)"
                Description = "Eclipse Temurin JDK $version for $platform"
                Category = $platform
                Jar = $info.FileName
                NextVersion = ""
                NextVersionUrl = ""
                NextGameVersion = ""
                LatestVersion = ""
                LatestVersionUrl = ""
                LatestGameVersion = ""
                Url = $info.DownloadUrl
                CurrentVersionUrl = $info.DownloadUrl
                UrlDirect = ""
                CurrentDependencies = ""
                CurrentDependenciesRequired = ""
                CurrentDependenciesOptional = ""
                LatestDependencies = ""
                LatestDependenciesRequired = ""
                LatestDependenciesOptional = ""
                Host = "adoptium"
                ApiSource = "adoptium"
                ClientSide = "optional"
                ServerSide = "required"
                Title = "Eclipse Temurin JDK $version"
                ProjectDescription = "OpenJDK $version build by Eclipse Adoptium for $platform ($($info.Architecture))"
                IconUrl = ""
                IssuesUrl = ""
                SourceUrl = "https://github.com/adoptium/temurin$version-binaries"
                WikiUrl = "https://adoptium.net/"
                AvailableGameVersions = ""
                RecordHash = ""
            }
            
            $modsList.Add($newJDKEntry) | Out-Null
            $addedCount++
        }
        
        # Save updated database
        $modsList | Export-Csv -Path $CsvPath -NoTypeInformation
        
        Write-Host ""
        Write-Host "✅ Successfully synced $addedCount JDK entries" -ForegroundColor Green
        Write-Host "   Database: $CsvPath" -ForegroundColor Gray
        
    } catch {
        Write-Host "❌ Error syncing JDK versions: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function is available for dot-sourcing

