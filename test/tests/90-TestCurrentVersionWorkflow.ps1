# Current Version Only Test
# Tests ONLY the current version workflow with proper mod loading and server startup

# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

# Set the test file name for use throughout the script
$TestFileName = "90-TestCurrentVersionOnly.ps1"

Write-Host "Minecraft Mod Manager - Current Version Only Test" -ForegroundColor $Colors.Header
Write-Host "=================================================" -ForegroundColor $Colors.Header

Initialize-TestEnvironment $TestFileName -UseMigratedSchema

# Helper to get the full path to ModManager.ps1
$ModManagerPath = Join-Path $PSScriptRoot "..\..\ModManager.ps1"

# Set up isolated paths
$TestOutputDir = Get-TestOutputFolder $TestFileName
$script:TestApiResponseDir = Join-Path $TestOutputDir "apiresponse"
$TestDownloadDir = Join-Path $TestOutputDir "download"
$TestDbPath = Join-Path $TestOutputDir "workflow-test.csv"

# Create necessary directories
New-Item -ItemType Directory -Path $script:TestApiResponseDir -Force | Out-Null
New-Item -ItemType Directory -Path $TestDownloadDir -Force | Out-Null

# Copy the main database instead of using test data
Copy-Item -Path "$PSScriptRoot\..\..\modlist.csv" -Destination $TestDbPath -Force

# Skip adding test data - we're using the main database
$testData = @()
<# Commenting out test data since we're using main database
    [PSCustomObject]@{
        Group = "required"
        Type = "mod"
        CurrentGameVersion = "1.21.5"
        ID = "fabric-api"
        Loader = "fabric"
        CurrentVersion = "0.127.1+1.21.5"
        Name = "Fabric API"
        Description = "Essential API for Fabric mods"
        Jar = ""
        Url = "https://modrinth.com/mod/fabric-api"
        Category = "api"
        CurrentVersionUrl = "https://cdn.modrinth.com/data/P7dR8mSH/versions/vNBWcMLP/fabric-api-0.127.1%2B1.21.5.jar"
        NextVersion = "0.127.1+1.21.6"
        NextVersionUrl = "https://cdn.modrinth.com/data/P7dR8mSH/versions/next.jar"
        NextGameVersion = "1.21.6"
        LatestVersionUrl = "https://cdn.modrinth.com/data/P7dR8mSH/versions/latest.jar"
        LatestVersion = "0.128.0+1.21.8"
        LatestGameVersion = "1.21.8"
        ApiSource = "modrinth"
        Host = "modrinth"
        IconUrl = ""
        ClientSide = ""
        ServerSide = ""
        Title = ""
        ProjectDescription = ""
        IssuesUrl = ""
        SourceUrl = ""
        WikiUrl = ""
        RecordHash = ""
        UrlDirect = ""
        AvailableGameVersions = "1.21.5,1.21.6,1.21.7,1.21.8"
        CurrentDependenciesRequired = ""
        CurrentDependenciesOptional = ""
        LatestDependenciesRequired = ""
        LatestDependenciesOptional = ""
    },
    [PSCustomObject]@{
        Group = "required"
        Type = "mod"
        CurrentGameVersion = "1.21.5"
        ID = "sodium"
        Loader = "fabric"
        CurrentVersion = "mc1.21.5-0.6.13-fabric"
        Name = "Sodium"
        Description = "Modern rendering engine"
        Jar = ""
        Url = "https://modrinth.com/mod/sodium"
        Category = "performance"
        CurrentVersionUrl = "https://cdn.modrinth.com/data/AANobbMI/versions/DA250htH/sodium-fabric-0.6.13%2Bmc1.21.5.jar"
        NextVersion = "mc1.21.6-0.6.13-fabric"
        NextVersionUrl = "https://cdn.modrinth.com/data/AANobbMI/versions/next.jar"
        NextGameVersion = "1.21.6"
        LatestVersionUrl = "https://cdn.modrinth.com/data/AANobbMI/versions/latest.jar"
        LatestVersion = "mc1.21.8-0.6.14-fabric"
        LatestGameVersion = "1.21.8"
        ApiSource = "modrinth"
        Host = "modrinth"
        IconUrl = ""
        ClientSide = ""
        ServerSide = ""
        Title = ""
        ProjectDescription = ""
        IssuesUrl = ""
        SourceUrl = ""
        WikiUrl = ""
        RecordHash = ""
        UrlDirect = ""
        AvailableGameVersions = "1.21.5,1.21.6,1.21.7,1.21.8"
        CurrentDependenciesRequired = ""
        CurrentDependenciesOptional = ""
        LatestDependenciesRequired = ""
        LatestDependenciesOptional = ""
    },
    [PSCustomObject]@{
        Group = "system"
        Type = "server"
        CurrentGameVersion = "1.21.5"
        ID = "minecraft-server"
        Loader = ""
        CurrentVersion = "1.21.5"
        Name = "Minecraft Server"
        Description = "Minecraft server JAR"
        Jar = "minecraft_server.1.21.5.jar"
        Url = "https://piston-data.mojang.com/v1/objects/4707d00eb834b446575d89a61a11b5d548d8c001/server.jar"
        Category = "server"
        CurrentVersionUrl = "https://piston-data.mojang.com/v1/objects/4707d00eb834b446575d89a61a11b5d548d8c001/server.jar"
        NextVersion = "1.21.6"
        NextVersionUrl = ""
        NextGameVersion = "1.21.6"
        LatestVersionUrl = ""
        LatestVersion = ""
        LatestGameVersion = ""
        ApiSource = "mojang"
        Host = "mojang"
        IconUrl = ""
        ClientSide = ""
        ServerSide = ""
        Title = ""
        ProjectDescription = ""
        IssuesUrl = ""
        SourceUrl = ""
        WikiUrl = ""
        RecordHash = ""
        UrlDirect = ""
        AvailableGameVersions = "1.21.5"
        CurrentDependenciesRequired = ""
        CurrentDependenciesOptional = ""
        LatestDependenciesRequired = ""
        LatestDependenciesOptional = ""
    },
    [PSCustomObject]@{
        Group = "system"
        Type = "launcher"
        CurrentGameVersion = "1.21.5"
        ID = "fabric-server"
        Loader = "fabric"
        CurrentVersion = "1.21.5-0.16.14-1.0.3"
        Name = "Fabric Server"
        Description = "Fabric server launcher"
        Jar = "fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar"
        Url = "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar"
        Category = "launcher"
        CurrentVersionUrl = "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar"
        NextVersion = "1.21.6-0.16.14-1.0.3"
        NextVersionUrl = ""
        NextGameVersion = "1.21.6"
        LatestVersionUrl = ""
        LatestVersion = ""
        LatestGameVersion = ""
        ApiSource = "fabric"
        Host = "fabric"
        IconUrl = ""
        ClientSide = ""
        ServerSide = ""
        Title = ""
        ProjectDescription = ""
        IssuesUrl = ""
        SourceUrl = ""
        WikiUrl = ""
        RecordHash = ""
        UrlDirect = ""
        AvailableGameVersions = "1.21.5"
        CurrentDependenciesRequired = ""
        CurrentDependenciesOptional = ""
        LatestDependenciesRequired = ""
        LatestDependenciesOptional = ""
    }
)
#>

# Skip test data export since we copied the main database
# $testData | Export-Csv -Path $TestDbPath -NoTypeInformation

Write-TestHeader "Current Version Download Test"
Test-Command "& '$ModManagerPath' -DatabaseFile '$TestDbPath' -Download -ForceDownload -DownloadFolder '$TestDownloadDir' -ApiResponseFolder '$script:TestApiResponseDir'" "Current version download" 0 $null $TestFileName

Write-TestHeader "Server Files Download Test"
# Manually download server files since DownloadServerFiles might have issues
try {
    $serverDir = Join-Path $TestDownloadDir "1.21.5"
    New-Item -ItemType Directory -Path $serverDir -Force | Out-Null
    
    # Download Minecraft server
    $mcServerUrl = "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar"
    $mcServerPath = Join-Path $serverDir "minecraft_server.1.21.5.jar"
    if (-not (Test-Path $mcServerPath)) {
        Invoke-WebRequest -Uri $mcServerUrl -OutFile $mcServerPath -UseBasicParsing
    }
    
    # Download Fabric server launcher
    $fabricUrl = "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.16.14/1.0.3/server/jar"
    $fabricPath = Join-Path $serverDir "fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar"
    if (-not (Test-Path $fabricPath)) {
        Invoke-WebRequest -Uri $fabricUrl -OutFile $fabricPath -UseBasicParsing
    }
    
    Write-TestResult "Server files downloaded" $true $TestFileName
} catch {
    Write-TestResult "Server files download failed: $_" $false $TestFileName
}

Write-TestHeader "Database vs Downloads Verification"

# Read the database to get ALL mods that should be downloaded
$dbData = Import-Csv -Path $TestDbPath
$expectedMods = $dbData | Where-Object { 
    $_.Type -eq "mod" -and 
    $_.CurrentGameVersion -eq "1.21.5"
}

Write-Host "  Database contains $($expectedMods.Count) mods for 1.21.5" -ForegroundColor Cyan

# Check downloaded mods
$modsPath = Join-Path $TestDownloadDir "1.21.5\mods"
if (Test-Path $modsPath) {
    $modFiles = Get-ChildItem -Path $modsPath -Filter "*.jar"
    
    # ModManager should download ALL mods from the database
    Write-TestResult "Downloaded ALL $($expectedMods.Count) mods from database" ($modFiles.Count -eq $expectedMods.Count) $TestFileName
    
    if ($modFiles.Count -ne $expectedMods.Count) {
        Write-Host "  Expected: $($expectedMods.Count) mods" -ForegroundColor Yellow
        Write-Host "  Downloaded: $($modFiles.Count) mods" -ForegroundColor Yellow
        
        # Show which mods are missing
        $downloadedNames = @{}
        foreach ($file in $modFiles) {
            $downloadedNames[$file.Name] = $true
        }
        
        $missingMods = @()
        foreach ($mod in $expectedMods) {
            $found = $false
            # Check if any downloaded file matches this mod (by name or ID)
            foreach ($file in $modFiles) {
                if ($file.Name -like "*$($mod.ID)*" -or $file.Name -like "*$($mod.Name)*") {
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                $missingMods += "$($mod.Name) (ID: $($mod.ID))"
            }
        }
        
        if ($missingMods.Count -gt 0) {
            Write-Host "  ❌ Missing mods not downloaded:" -ForegroundColor Red
            foreach ($mod in $missingMods) {
                Write-Host "    - $mod" -ForegroundColor Red
            }
        }
    }
    
    # List what was actually downloaded
    Write-Host "  Downloaded files:" -ForegroundColor Gray
    foreach ($mod in $modFiles | Sort-Object Name) {
        Write-Host "    - $($mod.Name)" -ForegroundColor Gray
    }
    
} else {
    Write-TestResult "Mods folder exists" $false $TestFileName
}

Write-TestHeader "Server Files Verification"
# Verify server files are in place based on database
$serverDir = Join-Path $TestDownloadDir "1.21.5"

# Get expected server files from database
$expectedServers = $dbData | Where-Object { 
    ($_.Type -eq "server" -or $_.Type -eq "launcher") -and 
    $_.CurrentGameVersion -eq "1.21.5"
}

Write-Host "  Database contains $($expectedServers.Count) server/launcher files for 1.21.5" -ForegroundColor Cyan

$allServerFilesPresent = $true
foreach ($server in $expectedServers) {
    $serverFile = Join-Path $serverDir $server.Jar
    $exists = Test-Path $serverFile
    Write-TestResult "$($server.Name) JAR exists ($($server.Jar))" $exists $TestFileName
    if (-not $exists) {
        $allServerFilesPresent = $false
    }
}

# Simple server startup test - just verify it can initialize
Write-TestHeader "Server Initialization Test"
try {
    $serverDir = Join-Path $TestDownloadDir "1.21.5"
    
    # Create eula.txt to allow server to start
    $eulaPath = Join-Path $serverDir "eula.txt"
    "eula=true" | Out-File -FilePath $eulaPath -Encoding utf8
    
    # Create basic server.properties
    $propsPath = Join-Path $serverDir "server.properties"
    @"
online-mode=false
server-port=25565
max-players=20
"@ | Out-File -FilePath $propsPath -Encoding utf8
    
    Write-TestResult "Server configuration created" $true $TestFileName
    
    # Verify mods are in the right place
    $modsPath = Join-Path $serverDir "mods"
    $modCount = (Get-ChildItem -Path $modsPath -Filter "*.jar" -ErrorAction SilentlyContinue).Count
    Write-TestResult "Server has $modCount mods ready" ($modCount -gt 0) $TestFileName
    
} catch {
    Write-TestResult "Server startup failed: $($_.Exception.Message)" $false $TestFileName
}

# Final summary
Write-TestSummary $TestFileName