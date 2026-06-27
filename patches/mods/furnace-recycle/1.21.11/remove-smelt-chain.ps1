param(
    [string]$DownloadRoot,
    [string]$TargetGameVersion,
    [string]$ModListPath
)

if ($TargetGameVersion -and $TargetGameVersion -ne "1.21.11") { return }
if (-not (Test-Path $DownloadRoot)) { return }

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $jars = Get-ChildItem -Path $DownloadRoot -Filter "furnacerecycle-*.jar" -Recurse -ErrorAction SilentlyContinue

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
                Write-Host "    🧹 Furnace Recycle: removed invalid recipe $entryName" -ForegroundColor Yellow
            }
        } finally {
            if ($zip) { $zip.Dispose() }
        }
    }
} catch {
    Write-Host "    ⚠️  Furnace Recycle patch failed: $($_.Exception.Message)" -ForegroundColor Yellow
}
