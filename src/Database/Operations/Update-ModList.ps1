# =============================================================================
# Mod List Update Operations Module
# =============================================================================
# This module handles updating mod lists with latest versions.
# =============================================================================

<#
.SYNOPSIS
    Updates modlist with latest versions.

.DESCRIPTION
    Updates a mod list CSV file with latest version information
    from validation results.

.PARAMETER CsvPath
    The path to the CSV file.

.PARAMETER ValidationResults
    The validation results to apply.

.EXAMPLE
    Update-ModListWithLatestVersions -CsvPath "modlist.csv" -ValidationResults $results

.NOTES
    - Creates backup before updating
    - Updates multiple fields based on validation results
    - Returns count of updated records
#>
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
        $updateSummary = @()
        
        foreach ($mod in $mods) {
            $result = $ValidationResults | Where-Object { $_.ID -eq $mod.ID }
            if ($result) {
                $changes = @()
                $updatedFields = @{
                    LatestVersion = $false
                    VersionUrl = $false
                    LatestVersionUrl = $false
                    IconUrl = $false
                    ClientSide = $false
                    ServerSide = $false
                    Title = $false
                    ProjectDescription = $false
                    IssuesUrl = $false
                    SourceUrl = $false
                    WikiUrl = $false
                    Version = $false
                    LatestGameVersion = $false
                    CurrentDependencies = $false
                    LatestDependencies = $false
                    CurrentDependenciesRequired = $false
                    CurrentDependenciesOptional = $false
                    LatestDependenciesRequired = $false
                    LatestDependenciesOptional = $false
                }
                
                # Update LatestVersion if available
                if ($result.LatestVersion -and $result.LatestVersion -ne $mod.LatestVersion) {
                    $mod.LatestVersion = $result.LatestVersion
                    $updatedFields.LatestVersion = $true
                }
                
                # Update VersionUrl if available (for current expected version)
                if ($result.VersionUrl -and $result.VersionUrl -ne $mod.VersionUrl) {
                    $mod.VersionUrl = $result.VersionUrl
                    $updatedFields.VersionUrl = $true
                }
                
                # Update LatestVersionUrl if available
                if ($result.LatestVersionUrl -and $result.LatestVersionUrl -ne $mod.LatestVersionUrl) {
                    $mod.LatestVersionUrl = $result.LatestVersionUrl
                    $updatedFields.LatestVersionUrl = $true
                }
                
                # Update IconUrl if available
                if ($result.IconUrl -and $result.IconUrl -ne $mod.IconUrl) {
                    $mod.IconUrl = $result.IconUrl
                    $updatedFields.IconUrl = $true
                }
                
                # Update new Modrinth project info fields if available
                if ($result.ClientSide -and $result.ClientSide -ne $mod.ClientSide) {
                    $mod.ClientSide = $result.ClientSide
                    $updatedFields.ClientSide = $true
                }
                if ($result.ServerSide -and $result.ServerSide -ne $mod.ServerSide) {
                    $mod.ServerSide = $result.ServerSide
                    $updatedFields.ServerSide = $true
                }
                if ($result.Title -and $result.Title -ne $mod.Title) {
                    $mod.Title = $result.Title
                    $updatedFields.Title = $true
                }
                if ($result.ProjectDescription -and $result.ProjectDescription -ne $mod.ProjectDescription) {
                    $mod.ProjectDescription = $result.ProjectDescription
                    $updatedFields.ProjectDescription = $true
                }
                # Handle IssuesUrl - ensure it's a string, not null or array
                $issuesUrlValue = if ($result.IssuesUrl) { $result.IssuesUrl.ToString() } else { "" }
                if ($issuesUrlValue -ne $mod.IssuesUrl) {
                    $mod.IssuesUrl = $issuesUrlValue
                    $updatedFields.IssuesUrl = $true
                }
                # Handle SourceUrl - ensure it's a string, not null or array
                $sourceUrlValue = if ($result.SourceUrl) { $result.SourceUrl.ToString() } else { "" }
                if ($sourceUrlValue -ne $mod.SourceUrl) {
                    $mod.SourceUrl = $sourceUrlValue
                    $updatedFields.SourceUrl = $true
                }
                # Handle WikiUrl - ensure it's a string, not null or array
                $wikiUrlValue = if ($result.WikiUrl) { $result.WikiUrl.ToString() } else { "" }
                if ($wikiUrlValue -ne $mod.WikiUrl) {
                    $mod.WikiUrl = $wikiUrlValue
                    $updatedFields.WikiUrl = $true
                }
                
                # Special case: If version was found by JAR filename, update the Version column
                # This is needed for the patcher to work correctly
                if ($result.VersionFoundByJar -and $result.ExpectedVersion -ne $mod.Version) {
                    $mod.Version = $result.ExpectedVersion
                    $updatedFields.Version = $true
                }
                
                # Update LatestGameVersion if available
                if ($result.LatestGameVersion -and $result.LatestGameVersion -ne $mod.LatestGameVersion) {
                    $mod.LatestGameVersion = $result.LatestGameVersion
                    $changes += "LatestGameVersion: updated"
                }
                
                # Update CurrentDependencies if available
                if ($result.CurrentDependencies -and $result.CurrentDependencies -ne $mod.CurrentDependencies) {
                    $mod.CurrentDependencies = $result.CurrentDependencies
                    $updatedFields.CurrentDependencies = $true
                }
                
                # Update LatestDependencies if available
                if ($result.LatestDependencies -and $result.LatestDependencies -ne $mod.LatestDependencies) {
                    $mod.LatestDependencies = $result.LatestDependencies
                    $updatedFields.LatestDependencies = $true
                }
                
                # Add new dependency properties if they don't exist
                if (-not $mod.PSObject.Properties.Name -contains "CurrentDependenciesRequired") {
                    $mod | Add-Member -MemberType NoteProperty -Name "CurrentDependenciesRequired" -Value ""
                }
                if (-not $mod.PSObject.Properties.Name -contains "CurrentDependenciesOptional") {
                    $mod | Add-Member -MemberType NoteProperty -Name "CurrentDependenciesOptional" -Value ""
                }
                if (-not $mod.PSObject.Properties.Name -contains "LatestDependenciesRequired") {
                    $mod | Add-Member -MemberType NoteProperty -Name "LatestDependenciesRequired" -Value ""
                }
                if (-not $mod.PSObject.Properties.Name -contains "LatestDependenciesOptional") {
                    $mod | Add-Member -MemberType NoteProperty -Name "LatestDependenciesOptional" -Value ""
                }
                
                # Update new dependency fields if available
                if ($result.CurrentDependenciesRequired -and $result.CurrentDependenciesRequired -ne $mod.CurrentDependenciesRequired) {
                    $mod.CurrentDependenciesRequired = $result.CurrentDependenciesRequired
                    $updatedFields.CurrentDependenciesRequired = $true
                }
                if ($result.CurrentDependenciesOptional -and $result.CurrentDependenciesOptional -ne $mod.CurrentDependenciesOptional) {
                    $mod.CurrentDependenciesOptional = $result.CurrentDependenciesOptional
                    $updatedFields.CurrentDependenciesOptional = $true
                }
                if ($result.LatestDependenciesRequired -and $result.LatestDependenciesRequired -ne $mod.LatestDependenciesRequired) {
                    $mod.LatestDependenciesRequired = $result.LatestDependenciesRequired
                    $updatedFields.LatestDependenciesRequired = $true
                }
                if ($result.LatestDependenciesOptional -and $result.LatestDependenciesOptional -ne $mod.LatestDependenciesOptional) {
                    $mod.LatestDependenciesOptional = $result.LatestDependenciesOptional
                    $updatedFields.LatestDependenciesOptional = $true
                }
                
                # Check if any fields were updated
                $anyUpdates = $updatedFields.Values -contains $true
                if ($anyUpdates) {
                    $updatedCount++
                    $updateSummary += [PSCustomObject]@{
                        Name = $mod.Name
                        LatestVersion = if ($updatedFields.LatestVersion) { "✓" } else { "" }
                        VersionUrl = if ($updatedFields.VersionUrl) { "✓" } else { "" }
                        LatestVersionUrl = if ($updatedFields.LatestVersionUrl) { "✓" } else { "" }
                        IconUrl = if ($updatedFields.IconUrl) { "✓" } else { "" }
                        ClientSide = if ($updatedFields.ClientSide) { "✓" } else { "" }
                        ServerSide = if ($updatedFields.ServerSide) { "✓" } else { "" }
                        Title = if ($updatedFields.Title) { "✓" } else { "" }
                        ProjectDescription = if ($updatedFields.ProjectDescription) { "✓" } else { "" }
                        IssuesUrl = if ($updatedFields.IssuesUrl) { "✓" } else { "" }
                        SourceUrl = if ($updatedFields.SourceUrl) { "✓" } else { "" }
                        WikiUrl = if ($updatedFields.WikiUrl) { "✓" } else { "" }
                        Version = if ($updatedFields.Version) { "✓" } else { "" }
                        LatestGameVersion = if ($updatedFields.LatestGameVersion) { "✓" } else { "" }
                        CurrentDependencies = if ($updatedFields.CurrentDependencies) { "✓" } else { "" }
                        LatestDependencies = if ($updatedFields.LatestDependencies) { "✓" } else { "" }
                        CurrentDependenciesRequired = if ($updatedFields.CurrentDependenciesRequired) { "✓" } else { "" }
                        CurrentDependenciesOptional = if ($updatedFields.CurrentDependenciesOptional) { "✓" } else { "" }
                        LatestDependenciesRequired = if ($updatedFields.LatestDependenciesRequired) { "✓" } else { "" }
                        LatestDependenciesOptional = if ($updatedFields.LatestDependenciesOptional) { "✓" } else { "" }
                    }
                }
            }
        }
        
        # Save updated modlist
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation
        
        # Display summary table (hidden for cleaner output)
        # if ($updateSummary.Count -gt 0) {
        #     Write-Host ""
        #     Write-Host "Update Summary:" -ForegroundColor Yellow
        #     Write-Host "==============" -ForegroundColor Yellow
        #     $updateSummary | Format-Table -AutoSize | Out-Host
        # }
        
        return $updatedCount
    }
    catch {
        Write-Error "Failed to update modlist: $($_.Exception.Message)"
        return 0
    }
}

# Function is available for dot-sourcing 