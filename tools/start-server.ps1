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

$JarFile = "fabric-server-mc.1.21.5-loader.0.16.14-launcher.1.0.3.jar"
$LogDir = "logs"

# Ensure logs folder exists
if (-not (Test-Path $LogDir)) {
  New-Item -ItemType Directory -Path $LogDir | Out-Null
}

while ($true) {
  $Timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
  $LogFile = "$LogDir/console-$Timestamp.log"
  $LaunchCmd = "java " + ($JavaOpts -join " ") + " -jar `"$JarFile`" nogui"

  @"
--- Server Start: $Timestamp ---
--- Launch Command: $LaunchCmd ---

"@ | Out-File -FilePath $LogFile -Encoding utf8

  pwsh -NoProfile -Command @"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
& $LaunchCmd | Tee-Object -FilePath '$LogFile' -Append
"@

  "`n--- Server exited. Restarting in 10 seconds... ---`n" | Out-File -FilePath $LogFile -Encoding utf8 -Append
  Start-Sleep -Seconds 10
}
