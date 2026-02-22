# Add Fabric installer (EXE + JAR) rows for 1.21.9, 1.21.10, 1.21.11 to modlist.csv.
# Run from repo root. Uses same Fabric installer 1.1.0 URLs as 1.21.8.
param(
    [string]$CsvPath = "modlist.csv"
)
$ErrorActionPreference = 'Stop'
$csvFullPath = Join-Path (Get-Location) $CsvPath
if (-not (Test-Path $csvFullPath)) { Write-Error "Not found: $csvFullPath"; exit 1 }

. (Join-Path $PSScriptRoot '..' 'src' 'Import-Modules.ps1') | Out-Null
. (Join-Path $PSScriptRoot '..' 'src' 'Validation' 'Hash' 'Calculate-RecordHash.ps1') | Out-Null

$mods = Import-Csv -Path $csvFullPath
$exeUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.0/fabric-installer-1.1.0.exe"
$jarUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.0/fabric-installer-1.1.0.jar"
$versions = @("1.21.9", "1.21.10", "1.21.11")
$templateExe = $mods | Where-Object { $_.Type -eq "installer" -and $_.ID -like "*-exe" } | Select-Object -First 1
$templateJar = $mods | Where-Object { $_.Type -eq "installer" -and $_.ID -like "*-jar" } | Select-Object -First 1
if (-not $templateExe -or -not $templateJar) { Write-Error "No installer template rows found"; exit 1 }

$newRows = [System.Collections.ArrayList]::new()
foreach ($ver in $versions) {
    $idExe = "fabric-installer-$ver-1.1.0-exe"
    $idJar = "fabric-installer-$ver-1.1.0-jar"
    $existing = $mods | Where-Object { $_.CurrentGameVersion -eq $ver -and $_.Type -eq "installer" }
    if ($existing) { Write-Host "Skipping $ver installer (already present)"; continue }
    foreach ($variant in @(
        @{ Id = $idExe; Name = "Fabric Installer (EXE)"; Url = $exeUrl; Template = $templateExe },
        @{ Id = $idJar; Name = "Fabric Installer (JAR)"; Url = $jarUrl; Template = $templateJar }
    )) {
        $row = [PSCustomObject]@{
            Group = "required"
            Type = "installer"
            CurrentGameVersion = $ver
            ID = $variant.Id
            Loader = "fabric"
            CurrentVersion = "1.1.0"
            Name = $variant.Name
            Description = ""
            Category = "Infrastructure"
            Jar = ""
            NextVersion = ""
            NextVersionUrl = ""
            NextGameVersion = ""
            LatestVersion = ""
            LatestVersionUrl = ""
            LatestGameVersion = ""
            Url = $variant.Url
            CurrentVersionUrl = ""
            UrlDirect = ""
            CurrentDependencies = ""
            CurrentDependenciesRequired = ""
            CurrentDependenciesOptional = ""
            LatestDependencies = ""
            LatestDependenciesRequired = ""
            LatestDependenciesOptional = ""
            Host = "direct"
            ApiSource = "direct"
            ClientSide = ""
            ServerSide = ""
            Title = $variant.Name
            ProjectDescription = ""
            IconUrl = ""
            IssuesUrl = ""
            SourceUrl = ""
            WikiUrl = ""
            AvailableGameVersions = ""
            RecordHash = ""
        }
        $hash = Calculate-RecordHash -Record $row
        if ($hash) { $row.RecordHash = $hash }
        [void]$newRows.Add($row)
    }
}
if ($newRows.Count -eq 0) { Write-Host "No new installer rows to add."; exit 0 }
$insertIndex = -1
for ($i = 0; $i -lt $mods.Count; $i++) {
    if ($mods[$i].Type -eq "installer" -and $mods[$i].ID -like "*-jar") { $insertIndex = $i; break }
}
if ($insertIndex -lt 0) { $insertIndex = $mods.Count - 1 }
$before = $mods[0..$insertIndex]
$after = $mods[($insertIndex + 1)..($mods.Count - 1)]
$result = $before + [object[]]$newRows + $after
$result | Export-Csv -Path $csvFullPath -NoTypeInformation
Write-Host "Added $($newRows.Count) installer rows (1.21.9, 1.21.10, 1.21.11 EXE+JAR)."
