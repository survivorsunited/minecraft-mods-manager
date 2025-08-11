# Version Compatibility Matrix Generator
# Creates a matrix showing what mod versions get downloaded for each workflow

function Show-VersionMatrix {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestOutputDir,
        [string]$WorkflowType = "Unknown"
    )
    
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    Write-Host "VERSION COMPATIBILITY MATRIX - $WorkflowType Workflow" -ForegroundColor $Colors.Header
    Write-Host ("=" * 80) -ForegroundColor $Colors.Header
    
    # Check all version folders
    $versionFolders = @("1.21.5", "1.21.6", "1.21.8")
    $matrix = @{}
    
    foreach ($version in $versionFolders) {
        $versionPath = Join-Path $TestOutputDir "download" $version "mods"
        if (Test-Path $versionPath) {
            $modFiles = Get-ChildItem -Path $versionPath -Filter "*.jar" -Recurse
            
            $versionCounts = @{
                "1.21.5" = 0
                "1.21.6" = 0
                "1.21.7" = 0
                "1.21.8" = 0
                "unknown" = 0
            }
            
            foreach ($mod in $modFiles) {
                $fileName = $mod.Name
                $matched = $false
                
                foreach ($checkVersion in @("1.21.5", "1.21.6", "1.21.7", "1.21.8")) {
                    if ($fileName -match $checkVersion.Replace(".", "\.")) {
                        $versionCounts[$checkVersion]++
                        $matched = $true
                        break
                    }
                }
                
                if (-not $matched) {
                    $versionCounts["unknown"]++
                }
            }
            
            $matrix[$version] = $versionCounts
        } else {
            $matrix[$version] = @{
                "1.21.5" = 0; "1.21.6" = 0; "1.21.7" = 0; "1.21.8" = 0; "unknown" = 0
            }
        }
    }
    
    # Display matrix
    Write-Host "Download Folder | 1.21.5 Mods | 1.21.6 Mods | 1.21.7 Mods | 1.21.8 Mods | Unknown" -ForegroundColor Cyan
    Write-Host ("-" * 80) -ForegroundColor Gray
    
    foreach ($folder in $versionFolders) {
        $counts = $matrix[$folder]
        $total = ($counts.Values | Measure-Object -Sum).Sum
        
        $line = "{0,-15} | {1,11} | {2,11} | {3,11} | {4,11} | {5,7}" -f @(
            $folder,
            $counts["1.21.5"],
            $counts["1.21.6"], 
            $counts["1.21.7"],
            $counts["1.21.8"],
            $counts["unknown"]
        )
        
        $color = "Gray"
        if ($folder -eq "1.21.5" -and $counts["1.21.5"] -gt $counts["1.21.6"]) { $color = "Green" }
        elseif ($folder -eq "1.21.6" -and $counts["1.21.6"] -gt 0) { $color = "Green" }
        elseif ($folder -eq "1.21.8" -and $counts["1.21.8"] -gt 0) { $color = "Green" }
        elseif ($total -gt 0) { $color = "Yellow" }
        
        Write-Host $line -ForegroundColor $color
    }
    
    Write-Host ("-" * 80) -ForegroundColor Gray
    Write-Host "EXPECTED BEHAVIOR:" -ForegroundColor White
    Write-Host "1.21.5 (Current)  : All mods should be 1.21.5 versions" -ForegroundColor Gray
    Write-Host "1.21.6 (Next)     : Mix of 1.21.5 (current) + 1.21.6 (next) versions" -ForegroundColor Gray  
    Write-Host "1.21.8 (Latest)   : Mix of 1.21.5 + 1.21.6 + 1.21.8 versions" -ForegroundColor Gray
    Write-Host ""
}