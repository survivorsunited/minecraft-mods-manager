# =============================================================================
# Update Missing Categories Script
# =============================================================================
# Updates Category field for mods that have empty Category values
# by querying their API source (Modrinth, CurseForge, or GitHub)
# =============================================================================

param(
    [string]$CsvPath = "modlist.csv",
    [switch]$UseCachedResponses = $false
)

# Import required modules
. "$PSScriptRoot\..\src\Import-Modules.ps1"

Write-Host "Updating missing Category fields..." -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

$mods = Import-Csv -Path $CsvPath
$updatedCount = 0

foreach ($mod in $mods) {
    # Skip if Category is already populated
    if ($mod.Category -and $mod.Category.Trim() -ne "") {
        continue
    }
    
    # Skip system entries
    if ($mod.Type -in @("server", "launcher", "installer")) {
        continue
    }
    
    Write-Host "Processing: $($mod.Name) ($($mod.ID))" -ForegroundColor Yellow
    
    $category = ""
    $modHost = if ($mod.Host) { $mod.Host } else { "modrinth" }
    
    try {
        if ($modHost -eq "modrinth") {
            # Get Modrinth project info
            $projectInfo = Get-ModrinthProjectInfo -ProjectId $mod.ID -UseCachedResponses $UseCachedResponses -Quiet
            if ($projectInfo -and $projectInfo.categories) {
                $modrinthCategory = $projectInfo.categories[0]
                $categoryMap = @{
                    "storage" = "Storage"
                    "technology" = "Technology"
                    "adventure" = "Adventure"
                    "magic" = "Magic"
                    "decoration" = "Decoration"
                    "library" = "Library"
                    "food" = "Food"
                    "equipment" = "Equipment"
                    "misc" = "Miscellaneous"
                    "optimization" = "Optimization"
                    "worldgen" = "World Generation"
                    "api" = "API"
                    "cursed" = "Cursed"
                    "fabric" = "Fabric"
                    "forge" = "Forge"
                }
                if ($categoryMap.ContainsKey($modrinthCategory)) {
                    $category = $categoryMap[$modrinthCategory]
                } else {
                    $category = (Get-Culture).TextInfo.ToTitleCase($modrinthCategory)
                }
            }
        } elseif ($modHost -eq "curseforge") {
            # Get CurseForge project info
            $projectInfo = Get-CurseForgeProjectInfo -ProjectId $mod.ID -UseCachedResponses $UseCachedResponses -Quiet
            if ($projectInfo) {
                $classId = $projectInfo.data.classId
                $categoryMap = @{
                    4 = "Adventure"
                    5 = "Magic"
                    6 = "Technology"
                    12 = "World Generation"
                    17 = "Storage"
                    23 = "Food"
                    24 = "Equipment"
                    25 = "Miscellaneous"
                    26 = "Optimization"
                    4471 = "API"
                }
                if ($categoryMap.ContainsKey($classId)) {
                    $category = $categoryMap[$classId]
                } else {
                    $category = "Utility"
                }
            }
        } elseif ($modHost -eq "github") {
            # Get GitHub project info
            $repositoryUrl = if ($mod.Url) { $mod.Url } else { "https://github.com/$($mod.ID)" }
            $projectInfo = Get-GitHubProjectInfo -RepositoryUrl $repositoryUrl -UseCachedResponses $UseCachedResponses -Quiet
            if ($projectInfo -and $projectInfo.topics) {
                $topicMap = @{
                    "storage" = "Storage"
                    "technology" = "Technology"
                    "adventure" = "Adventure"
                    "magic" = "Magic"
                    "decoration" = "Decoration"
                    "library" = "Library"
                    "api" = "API"
                    "optimization" = "Optimization"
                    "worldgen" = "World Generation"
                }
                foreach ($topic in $projectInfo.topics) {
                    $topicLower = $topic.ToLower()
                    if ($topicMap.ContainsKey($topicLower)) {
                        $category = $topicMap[$topicLower]
                        break
                    }
                }
            }
            if (-not $category) {
                $category = "Utility"
            }
        }
        
        if ($category) {
            $mod.Category = $category
            $updatedCount++
            Write-Host "  ✓ Updated Category: $category" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Could not determine category" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Save updated CSV
if ($updatedCount -gt 0) {
    $mods | Export-Csv -Path $CsvPath -NoTypeInformation
    Write-Host "✅ Updated $updatedCount mods with Category fields" -ForegroundColor Green
} else {
    Write-Host "ℹ No mods needed Category updates" -ForegroundColor Cyan
}

