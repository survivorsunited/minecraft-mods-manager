# Function to validate all mods in the list
function Validate-AllModVersions {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$ResponseFolder = $ApiResponseFolder,
        [switch]$UpdateModList
    )
    try {
        # Load mod list
        $mods = Get-ModList -CsvPath $CsvPath -ApiResponseFolder $ResponseFolder
        if (-not $mods -or $mods.Count -eq 0) {
            Write-Host "❌ No mods found in $CsvPath" -ForegroundColor Red
            return @()
        }
        
        Write-Host "🔍 Validating $($mods.Count) mods..." -ForegroundColor Cyan
        
        $validationResults = @()
        $currentIndex = 0
        
        foreach ($mod in $mods) {
            $currentIndex++
            $percentComplete = [math]::Round(($currentIndex / $mods.Count) * 100)
            Write-Progress -Activity "Validating mods" -Status "Processing $($mod.Name)" -PercentComplete $percentComplete -CurrentOperation "Validating mod $currentIndex of $($mods.Count)"
            
            # Skip system entries (installer, launcher, server)
            if ($mod.Type -in @("installer", "launcher", "server")) {
                Write-Host ("  ⏭️  Skipping system entry: {0}" -f $mod.Name) -ForegroundColor DarkGray
                continue
            }
            
            # Determine which API to use based on Host field
            $modHost = if ($mod.Host) { $mod.Host.ToLower() } else { "modrinth" }
            
            $validationResult = $null
            
            if ($modHost -eq "curseforge") {
                Write-Host ("  🔍 Validating CurseForge mod: {0}" -f $mod.Name) -ForegroundColor DarkGray
                $validationResult = Validate-CurseForgeModVersion -ModId $mod.ID -Version $(if ($mod.CurrentVersion) { $mod.CurrentVersion } else { $mod.Version }) -Loader $mod.Loader -Jar $mod.Jar -ResponseFolder $ResponseFolder
            } else {
                Write-Host ("  🔍 Validating Modrinth mod: {0}" -f $mod.Name) -ForegroundColor DarkGray
                $validationResult = Validate-ModVersion -ModId $mod.ID -Version $(if ($mod.CurrentVersion) { $mod.CurrentVersion } else { $mod.Version }) -Loader $mod.Loader -Jar $mod.Jar -ResponseFolder $ResponseFolder
            }
            
            if ($validationResult) {
                # Add mod information to result
                $validationResult | Add-Member -MemberType NoteProperty -Name "ID" -Value $mod.ID
                $validationResult | Add-Member -MemberType NoteProperty -Name "Name" -Value $mod.Name
                $validationResult | Add-Member -MemberType NoteProperty -Name "ExpectedVersion" -Value $(if ($mod.CurrentVersion) { $mod.CurrentVersion } else { $mod.Version })
                $validationResult | Add-Member -MemberType NoteProperty -Name "Host" -Value $modHost
                
                $validationResults += $validationResult
                
                # Display result
                if ($validationResult.Exists) {
                    Write-Host ("  ✅ {0}: Version {1} exists" -f $mod.Name, $(if ($mod.CurrentVersion) { $mod.CurrentVersion } else { $mod.Version })) -ForegroundColor Green
                } else {
                    Write-Host ("  ❌ {0}: Version {1} not found" -f $mod.Name, $(if ($mod.CurrentVersion) { $mod.CurrentVersion } else { $mod.Version })) -ForegroundColor Red
                }
            }
        }
        
        Write-Progress -Activity "Validating mods" -Completed
        Write-Host "✅ Validation complete. Found $($validationResults.Count) results." -ForegroundColor Green
        
        # Update modlist if requested
        if ($UpdateModList) {
            $updatedCount = Update-ModListWithLatestVersions -CsvPath $CsvPath -ValidationResults $validationResults
            Write-Host "📝 Updated $updatedCount mods in the database" -ForegroundColor Cyan
        }
        
        return $validationResults
    }
    catch {
        Write-Error "Failed to validate all mod versions: $($_.Exception.Message)"
        return @()
    }
} 