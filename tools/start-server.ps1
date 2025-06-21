# Minecraft Fabric Server Startup Script
# Automatically finds and launches the Fabric server JAR file

$JavaOpts = @(
  "-server"
  "-XX:+UseG1GC"
  "-XX:+ParallelRefProcEnabled"
  "-XX:MaxGCPauseMillis=200"
  "-XX:+UnlockExperimentalVMOptions"
  "-XX:+DisableExplicitGC"
  "-Xms8G"
  "-Xmx32G"
  "--enable-native-access=ALL-UNNAMED"
)

$LogDir = "logs"

# Function to find Fabric server JAR
function Find-FabricServerJar {
    $fabricJars = Get-ChildItem -Path "." -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue
    
    if ($fabricJars.Count -eq 0) {
        Write-Host "❌ No Fabric server JAR found in current directory" -ForegroundColor Red
        Write-Host "Expected pattern: fabric-server*.jar" -ForegroundColor Yellow
        Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
        return $null
    }
    
    if ($fabricJars.Count -gt 1) {
        Write-Host "⚠️  Multiple Fabric server JARs found:" -ForegroundColor Yellow
        $fabricJars | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
        Write-Host "Using the first one: $($fabricJars[0].Name)" -ForegroundColor Yellow
    }
    
    $selectedJar = $fabricJars[0]
    Write-Host "✅ Found Fabric server JAR: $($selectedJar.Name)" -ForegroundColor Green
    return $selectedJar.Name
}

# Ensure logs folder exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
    Write-Host "📁 Created logs directory: $LogDir" -ForegroundColor Green
}

# Find the Fabric server JAR
$JarFile = Find-FabricServerJar
if (-not $JarFile) {
    Write-Host "`n💡 Make sure you have downloaded the Fabric server using ModManager.ps1" -ForegroundColor Cyan
    Write-Host "Example: .\ModManager.ps1 -AddMod -AddModName 'Fabric Server' -AddModType 'launcher' -AddModUrl '...'" -ForegroundColor Cyan
    exit 1
}

Write-Host "🚀 Starting Fabric server with JAR: $JarFile" -ForegroundColor Green
Write-Host "📊 Java options: $($JavaOpts.Count) options configured" -ForegroundColor Gray

while ($true) {
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
    $LogFile = "$LogDir/console-$Timestamp.log"
    $LaunchCmd = "java " + ($JavaOpts -join " ") + " -jar `"$JarFile`" nogui"

    @"
=== Fabric Server Start: $Timestamp ===
=== JAR File: $JarFile ===
=== Launch Command: $LaunchCmd ===
=== Java Options: $($JavaOpts -join ' ') ===

"@ | Out-File -FilePath $LogFile -Encoding utf8

    Write-Host "`n🔄 Starting server... (Log: $LogFile)" -ForegroundColor Cyan
    
    pwsh -NoProfile -Command @"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
& $LaunchCmd | Tee-Object -FilePath '$LogFile' -Append
"@

    $exitCode = $LASTEXITCODE
    $restartMsg = "`n--- Server exited with code $exitCode. Restarting in 10 seconds... ---`n"
    
    Write-Host $restartMsg -ForegroundColor Yellow
    $restartMsg | Out-File -FilePath $LogFile -Encoding utf8 -Append
    
    Start-Sleep -Seconds 10
}
