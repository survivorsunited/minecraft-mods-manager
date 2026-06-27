# Final download wrapper for Furnace Recycle 1.21.11 compatibility.
# The upstream jar contains data/furnacerecycle/recipe/smelt_chain.json with an item id
# that no longer exists in 1.21.11. Remove only that known bad recipe before server validation.

if (-not $script:DownloadModsBeforeFurnaceRecyclePatch) {
    $script:DownloadModsBeforeFurnaceRecyclePatch = ${function:Download-Mods}
}

function Remove-FurnaceRecycleSmeltChainRecipe {
    param(
        [string]$DownloadFolder,
        [string]$TargetGameVersion = ""
    )

    $searchRoot = $DownloadFolder
    if (-not [string]::IsNullOrWhiteSpace($TargetGameVersion)) {
        $candidateRoot = Join-Path $DownloadFolder $TargetGameVersion
        if (Test-Path $candidateRoot) { $searchRoot = $candidateRoot }
    }

    if (-not (Test-Path $searchRoot)) { return }

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $jars = Get-ChildItem -Path $searchRoot -Filter "furnacerecycle-*.jar" -Recurse -ErrorAction SilentlyContinue
        foreach ($jar in $jars) {
            $zip = $null
            try {
                $zip = [System.IO.Compression.ZipFile]::Open($jar.FullName, [System.IO.Compression.ZipArchiveMode]::Update)
                $badEntries = @($zip.Entries | Where-Object {
                    $_.FullName -eq "data/furnacerecycle/recipe/smelt_chain.json" -or
                    $_.FullName -eq "data/furnacerecycle/recipes/smelt_chain.json"
                })
                foreach ($entry in $badEntries) {
                    $entryName = $entry.FullName
                    $entry.Delete()
                    Write-Host "🧹 Patched Furnace Recycle jar: removed invalid recipe $entryName" -ForegroundColor Yellow
                }
            } finally {
                if ($zip) { $zip.Dispose() }
            }
        }
    } catch {
        Write-Host "⚠️  Failed to patch Furnace Recycle jar: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Download-Mods {
    param(
        [string]$CsvPath = $ModListPath,
        [string]$DownloadFolder = "download",
        [switch]$UseLatestVersion,
        [switch]$UseNextVersion,
        [switch]$ForceDownload,
        [string]$TargetGameVersion = $null,
        [string]$ApiResponseFolder = $null,
        [switch]$SkipServerFiles
    )

    $params = @{
        CsvPath = $CsvPath
        DownloadFolder = $DownloadFolder
        ForceDownload = $ForceDownload
        SkipServerFiles = $SkipServerFiles
    }
    if ($ApiResponseFolder) { $params.ApiResponseFolder = $ApiResponseFolder }
    if ($UseLatestVersion) { $params.UseLatestVersion = $true }
    if ($UseNextVersion) { $params.UseNextVersion = $true }
    if ($TargetGameVersion) { $params.TargetGameVersion = $TargetGameVersion }

    & $script:DownloadModsBeforeFurnaceRecyclePatch @params

    $effectiveTargetGameVersion = $TargetGameVersion
    if ([string]::IsNullOrWhiteSpace($effectiveTargetGameVersion) -and -not $UseLatestVersion -and -not $UseNextVersion) {
        if (Get-Command Get-ReleaseVersionTargets -ErrorAction SilentlyContinue) {
            $targets = Get-ReleaseVersionTargets
            if ($targets -and $targets.Current) { $effectiveTargetGameVersion = $targets.Current }
        }
    }

    Remove-FurnaceRecycleSmeltChainRecipe -DownloadFolder $DownloadFolder -TargetGameVersion $effectiveTargetGameVersion
}
