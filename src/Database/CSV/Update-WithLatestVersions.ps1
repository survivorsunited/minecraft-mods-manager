# Function to update modlist with latest versions
function Update-ModListWithLatestVersions {
    param(
        [string]$CsvPath,
        [array]$ValidationResults
    )
    try {
        # Ensure CSV has required columns
        $mods = Ensure-CsvColumns -CsvPath $CsvPath
        if (-not $mods) {
            return 0
        }
        
        # Clean up system entries (installer, launcher, server) to ensure proper empty strings
        $mods = Clean-SystemEntries -Mods $mods
        
        # Create a backup of the original file
        $backupPath = Get-BackupPath -OriginalPath $CsvPath -BackupType "update"
        Copy-Item -Path $CsvPath -Destination $backupPath
        Write-Host "Created backup: $backupPath" -ForegroundColor Yellow
        
        # Update mods with URLs only (DO NOT UPDATE VERSION COLUMN)
        $updatedCount = 0
        foreach ($mod in $mods) {
            $validationResult = $ValidationResults | Where-Object { $_.ModId -eq $mod.ID } | Select-Object -First 1
            
            if ($validationResult) {
                # Update API-related fields
                $mod.CurrentVersionUrl = $validationResult.VersionUrl
                $mod.NextVersionUrl = $validationResult.NextVersionUrl ?? ""
                $mod.NextVersion = $validationResult.NextVersion ?? ""
                $mod.NextGameVersion = $validationResult.NextGameVersion ?? ""
                $mod.LatestVersionUrl = $validationResult.LatestVersionUrl
                $mod.LatestVersion = $validationResult.LatestVersion
                $mod.LatestGameVersion = $validationResult.LatestGameVersion
                $mod.IconUrl = $validationResult.IconUrl
                $mod.ClientSide = $validationResult.ClientSide
                $mod.ServerSide = $validationResult.ServerSide
                $mod.Title = $validationResult.Title
                $mod.ProjectDescription = $validationResult.ProjectDescription
                $mod.IssuesUrl = $validationResult.IssuesUrl
                $mod.SourceUrl = $validationResult.SourceUrl
                $mod.WikiUrl = $validationResult.WikiUrl
                $mod.AvailableGameVersions = $validationResult.AvailableGameVersions
                $mod.CurrentDependenciesRequired = $validationResult.CurrentDependenciesRequired
                $mod.CurrentDependenciesOptional = $validationResult.CurrentDependenciesOptional
                $mod.LatestDependenciesRequired = $validationResult.LatestDependenciesRequired
                $mod.LatestDependenciesOptional = $validationResult.LatestDependenciesOptional
                
                $updatedCount++
            }
        }
        
        # Save updated CSV
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        Write-Host "✅ Updated $updatedCount mods with latest version information" -ForegroundColor Green
        
        return $updatedCount
    }
    catch {
        Write-Error "Failed to update modlist with latest versions: $($_.Exception.Message)"
        return 0
    }
} 