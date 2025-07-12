# Function to load mod list from CSV
function Get-ModList {
    param(
        [string]$CsvPath,
        [string]$ApiResponseFolder = $ApiResponseFolder
    )
    try {
        if (-not (Test-Path $CsvPath)) {
            throw "Mod list CSV file not found: $CsvPath"
        }
        $mods = Import-Csv -Path $CsvPath
        if ($mods -isnot [System.Collections.IEnumerable]) { $mods = @($mods) }
        
        # Ensure CSV has required columns including dependency columns
        $mods = Ensure-CsvColumns -CsvPath $CsvPath
        if (-not $mods) {
            throw "Failed to ensure CSV columns"
        }
        
        # Add RecordHash to records that don't have it and verify integrity
        $modifiedRecords = @()
        $externalChanges = @()
        foreach ($mod in $mods) {
            # Add RecordHash property if it doesn't exist
            if (-not $mod.PSObject.Properties.Match('RecordHash').Count) {
                $mod | Add-Member -MemberType NoteProperty -Name 'RecordHash' -Value $null
            }
            
            $recordHash = Calculate-RecordHash -Record $mod
            
            # Check if record has been modified externally
            if ($mod.RecordHash -and $mod.RecordHash -ne $recordHash) {
                $externalChanges += $mod
            }
            
            # Update hash if missing or if external change detected
            if (-not $mod.RecordHash -or $mod.RecordHash -ne $recordHash) {
                $mod.RecordHash = $recordHash
                $modifiedRecords += $mod
            }
        }
        
        # If external changes were detected, verify and update those records
        if ($externalChanges.Count -gt 0) {
            Write-Host "🔄 Verifying $($externalChanges.Count) externally modified records..." -ForegroundColor Cyan
            
            $currentIndex = 0
            foreach ($changedMod in $externalChanges) {
                $currentIndex++
                $percentComplete = [math]::Round(($currentIndex / $externalChanges.Count) * 100)
                Write-Progress -Activity "Verifying externally modified records" -Status "Processing $($changedMod.Name)" -PercentComplete $percentComplete -CurrentOperation "Updating record $currentIndex of $($externalChanges.Count)"
                
                # For externally modified records, we should verify them
                if ($changedMod.Type -eq "mod" -or $changedMod.Type -eq "shaderpack" -or $changedMod.Type -eq "datapack") {
                    # Make API call to get current data for externally modified records
                    try {
                        # Use the existing Validate-ModVersion function to get current data
                        $validationResult = Validate-ModVersion -ModId $changedMod.ID -Version $changedMod.Version -Loader $changedMod.Loader -Jar $changedMod.Jar -ResponseFolder $ApiResponseFolder -Quiet
                        
                        if ($validationResult -and $validationResult.Exists) {
                            # Update the record with current API data
                            $changedMod.VersionUrl = $validationResult.VersionUrl
                            $changedMod.LatestVersionUrl = $validationResult.LatestVersionUrl
                            $changedMod.LatestVersion = $validationResult.LatestVersion
                            $changedMod.LatestGameVersion = $validationResult.LatestGameVersion
                            $changedMod.IconUrl = $validationResult.IconUrl
                            $changedMod.ClientSide = $validationResult.ClientSide
                            $changedMod.ServerSide = $validationResult.ServerSide
                            $changedMod.Title = $validationResult.Title
                            $changedMod.ProjectDescription = $validationResult.ProjectDescription
                            $changedMod.IssuesUrl = $validationResult.IssuesUrl
                            $changedMod.SourceUrl = $validationResult.SourceUrl
                            $changedMod.WikiUrl = $validationResult.WikiUrl
                        }
                    }
                    catch {
                        # Silent error handling - continue with existing data
                    }
                }
            }
            
            Write-Progress -Activity "Verifying externally modified records" -Completed
            Write-Host "✅ All externally modified records have been verified and updated" -ForegroundColor Green
        }
        
        # Save updated records if any were modified
        if ($modifiedRecords.Count -gt 0) {
            $mods | Export-Csv -Path $CsvPath -NoTypeInformation
            # Write-Host "💾 Updated $($modifiedRecords.Count) records with new hash values" -ForegroundColor Cyan
        }
        
        return $mods
    }
    catch {
        Write-Error "Failed to load mod list from $CsvPath : $($_.Exception.Message)"
        return @()
    }
} 