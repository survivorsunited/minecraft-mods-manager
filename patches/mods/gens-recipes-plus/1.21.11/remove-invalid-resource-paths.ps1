param(
    [string]$DownloadRoot,
    [string]$TargetGameVersion,
    [string]$ModListPath
)

if ($TargetGameVersion -and $TargetGameVersion -ne "1.21.11") { return }
if (-not (Test-Path $DownloadRoot)) { return }

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $jars = Get-ChildItem -Path $DownloadRoot -Filter "recipes-plus-*.jar" -Recurse -ErrorAction SilentlyContinue

    foreach ($jar in $jars) {
        $zip = $null
        try {
            $zip = [System.IO.Compression.ZipFile]::Open($jar.FullName, [System.IO.Compression.ZipArchiveMode]::Update)
            $badEntries = @($zip.Entries | Where-Object {
                $_.FullName -like "*.json" -and $_.FullName -match "\s"
            })

            foreach ($entry in $badEntries) {
                $entryName = $entry.FullName
                $entry.Delete()
                Write-Host "    🧹 Gen's Recipes Plus: removed invalid resource path $entryName" -ForegroundColor Yellow
            }
        } finally {
            if ($zip) { $zip.Dispose() }
        }
    }
} catch {
    Write-Host "    ⚠️  Gen's Recipes Plus patch failed: $($_.Exception.Message)" -ForegroundColor Yellow
}
