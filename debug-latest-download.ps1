# Debug Latest Version Download
# Minimal test to see what Download-Mods actually does

Import-Module ./src/Import-Modules.ps1

Write-Host "🔍 DEBUG: Testing Download-Mods -UseLatestVersion" -ForegroundColor Cyan
Write-Host ""

# Create test folder
$testFolder = "test-debug-latest"
if (Test-Path $testFolder) { Remove-Item -Recurse $testFolder -Force }
New-Item -ItemType Directory $testFolder -Force | Out-Null

Write-Host "1. Testing Get-MajorityLatestGameVersion..." -ForegroundColor Yellow
$versionResult = Get-MajorityLatestGameVersion -CsvPath "./modlist.csv"
Write-Host "   Result: $($versionResult.MajorityVersion)" -ForegroundColor Green

Write-Host ""
Write-Host "2. Testing fabric-api LatestVersionUrl..." -ForegroundColor Yellow
$mods = Import-Csv -Path "./modlist.csv" 
$fabricApi = $mods | Where-Object { $_.Name -eq "Fabric API" }
Write-Host "   LatestVersion: $($fabricApi.LatestVersion)" -ForegroundColor Green
Write-Host "   LatestVersionUrl: $($fabricApi.LatestVersionUrl)" -ForegroundColor Green

Write-Host ""
Write-Host "3. Running Download-Mods with -UseLatestVersion..." -ForegroundColor Yellow
Write-Host "   Expected: Downloads to 1.21.8 folder with fabric-api-0.131.0+1.21.8.jar" -ForegroundColor Gray

# Run download (limit to just fabric-api for speed)
$fabricOnlyFile = "$testFolder/fabric-only.csv"
$fabricApi | Export-Csv -Path $fabricOnlyFile -NoTypeInformation

Download-Mods -CsvPath $fabricOnlyFile -DownloadFolder $testFolder -UseLatestVersion

Write-Host ""
Write-Host "4. Results:" -ForegroundColor Yellow
if (Test-Path "$testFolder/1.21.8/mods") {
    $downloadedMods = Get-ChildItem "$testFolder/1.21.8/mods" -Filter "*.jar"
    Write-Host "   ✅ Downloaded to 1.21.8 folder:" -ForegroundColor Green
    foreach ($mod in $downloadedMods) {
        Write-Host "      - $($mod.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "   ❌ No 1.21.8/mods folder found" -ForegroundColor Red
    
    # Check what was created
    Write-Host "   Folders created:" -ForegroundColor Yellow
    Get-ChildItem $testFolder -Directory | ForEach-Object {
        Write-Host "      - $($_.Name)" -ForegroundColor Gray
        if (Test-Path "$($_.FullName)/mods") {
            $mods = Get-ChildItem "$($_.FullName)/mods" -Filter "*.jar"
            foreach ($mod in $mods) {
                Write-Host "        └─ $($mod.Name)" -ForegroundColor Gray
            }
        }
    }
}

Write-Host ""
Write-Host "Debug completed." -ForegroundColor Cyan