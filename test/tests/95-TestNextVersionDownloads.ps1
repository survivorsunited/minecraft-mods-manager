# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "95-TestNextVersionDownloads.ps1"

# Initialize test environment (this starts console logging)
Initialize-TestEnvironment $TestFileName

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestCacheDir = Join-Path $TestOutputDir ".cache"

Write-Host "Minecraft Mod Manager - Next Version Downloads Tests" -ForegroundColor $Colors.Header
Write-Host "=====================================================" -ForegroundColor $Colors.Header

function Invoke-TestNextVersionDownloads {
    param([string]$TestFileName = $null)
    
    Write-TestHeader "Test 1: Download 1.21.6 mods using NextVersionUrl from database"
    
    # Clean test directories
    if (Test-Path $TestDownloadDir) {
        Remove-Item -Path $TestDownloadDir -Recurse -Force
    }
    if (Test-Path $TestCacheDir) {
        Remove-Item -Path $TestCacheDir -Recurse -Force
    }
    
    # Create test database with 1.21.5 as current so 1.21.6 is next version
    # Empty server/launcher URLs will trigger auto-resolution
    $TestDbPath = Join-Path $TestOutputDir "test-modlist.csv"
    $testData = @'
Group,Type,GameVersion,ID,Loader,Version,Name,Jar,Url,NextGameVersion,NextVersionUrl
required,mod,1.21.5,fabric-api,fabric,0.113.0+1.21.5,Fabric API,fabric-api-0.113.0+1.21.5.jar,https://modrinth.com/mod/fabric-api,1.21.6,https://cdn.modrinth.com/data/P7dR8mSH/versions/fabric-api-0.114.0+1.21.6.jar
required,mod,1.21.5,lithium,fabric,mc1.21.5-0.14.5,Lithium,lithium-fabric-0.14.5+mc1.21.5.jar,https://modrinth.com/mod/lithium,1.21.6,https://cdn.modrinth.com/data/gvQqBUqZ/versions/mc1.21.6-0.14.6.jar
system,server,1.21.6,minecraft-server,vanilla,1.21.6,Minecraft Server,minecraft_server.1.21.6.jar,,,
system,launcher,1.21.6,fabric-launcher,fabric,0.17.3,Fabric Launcher,fabric-server-mc.1.21.6-loader.0.17.3-launcher.1.1.0.jar,,,
'@
    $testData | Out-File -FilePath $TestDbPath -Encoding UTF8
    
    # Run ModManager to download 1.21.6 mods
    Write-Host "  Running: ModManager -DownloadMods -UseNextVersion -TargetVersion `"1.21.6`"" -ForegroundColor Cyan
    $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ModManagerPath `
        -DownloadMods `
        -UseNextVersion `
        -TargetVersion "1.21.6" `
        -DatabaseFile $TestDbPath `
        -DownloadFolder $TestDownloadDir `
        -UseCachedResponses 2>&1
    
    $exitCode = $LASTEXITCODE
    
    # Check exit code
    if ($exitCode -ne 0) {
        Write-TestResult "ModManager exit code" $false "Expected 0, got $exitCode"
        return $false
    }
    Write-TestResult "ModManager exit code" $true
    
    # Check that 1.21.6 folder exists
    $version126Folder = Join-Path $TestDownloadDir "1.21.6"
    if (-not (Test-Path $version126Folder)) {
        Write-TestResult "1.21.6 folder created" $false
        return $false
    }
    Write-TestResult "1.21.6 folder created" $true
    
    # Check that mods folder exists
    $modsFolder = Join-Path $version126Folder "mods"
    if (-not (Test-Path $modsFolder)) {
        Write-TestResult "Mods folder created" $false
        return $false
    }
    Write-TestResult "Mods folder created" $true
    
    # Count mods downloaded
    $modFiles = Get-ChildItem -Path $modsFolder -Recurse -Filter "*.jar"
    $modCount = $modFiles.Count
    Write-Host "  Found $modCount mod files" -ForegroundColor Gray
    
    if ($modCount -lt 2) {
        Write-TestResult "Sufficient mods downloaded" $false "Expected >= 2, got $modCount"
        return $false
    }
    Write-TestResult "Sufficient mods downloaded" $true
    
    # Check specific mods that should have 1.21.6 versions in database
    $fabricApiFile = Get-ChildItem -Path $modsFolder -Recurse -Filter "fabric-api*.jar" | Select-Object -First 1
    if (-not $fabricApiFile) {
        Write-TestResult "Fabric API downloaded" $false
        return $false
    }
    Write-TestResult "Fabric API downloaded" $true
    Write-Host "  Fabric API filename: $($fabricApiFile.Name)" -ForegroundColor Gray
    
    # Check server files
    $minecraftServer = Get-ChildItem -Path $version126Folder -Filter "minecraft_server.1.21.6.jar"
    if (-not $minecraftServer) {
        Write-TestResult "Minecraft Server 1.21.6 downloaded" $false
        return $false
    }
    Write-TestResult "Minecraft Server 1.21.6 downloaded" $true
    
    $fabricLauncher = Get-ChildItem -Path $version126Folder -Filter "fabric-server*.jar"
    if (-not $fabricLauncher) {
        Write-TestResult "Fabric Launcher 1.21.6 downloaded" $false
        return $false
    }
    Write-TestResult "Fabric Launcher 1.21.6 downloaded" $true
    
    # Verify no other version JARs exist in the folder
    $otherVersionServers = Get-ChildItem -Path $version126Folder -Filter "minecraft_server*.jar" | 
        Where-Object { $_.Name -notmatch "1\.21\.6" }
    
    if ($otherVersionServers) {
        Write-TestResult "No other version server JARs" $false "Found: $($otherVersionServers.Name -join ', ')"
        return $false
    }
    Write-TestResult "No other version server JARs" $true
    
    # Summary
    Write-Host ""
    Write-Host "Test Summary:" -ForegroundColor $Colors.Header
    Write-Host "  Total mods downloaded: $modCount" -ForegroundColor Green
    Write-Host "  Server files: 2" -ForegroundColor Green
    Write-Host "  Version isolation: Verified" -ForegroundColor Green
    
    Show-TestSummary
    
    return ($script:TestResults.Failed -eq 0)
}

# Always execute tests when this file is run
Invoke-TestNextVersionDownloads -TestFileName $TestFileName

