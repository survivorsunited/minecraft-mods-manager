param(
    [string]$DownloadRoot,
    [string]$TargetGameVersion,
    [string]$ModListPath
)

if ($TargetGameVersion -and $TargetGameVersion -ne "1.21.11") { return }
if (-not (Test-Path $DownloadRoot)) { return }

# Furnace Recycle ships smelt_chain.json in an older/incompatible recipe shape.
# Replace it with a valid 1.21.11 smelting recipe rather than removing the recipe entirely.
$fixedRecipeJson = @'
{
  "type": "minecraft:smelting",
  "category": "misc",
  "ingredient": {
    "item": "minecraft:chain"
  },
  "result": {
    "id": "minecraft:iron_nugget",
    "count": 1
  },
  "experience": 0.1,
  "cookingtime": 200
}
'@

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $jars = Get-ChildItem -Path $DownloadRoot -Filter "furnacerecycle-*.jar" -Recurse -ErrorAction SilentlyContinue

    foreach ($jar in $jars) {
        $zip = $null
        try {
            $zip = [System.IO.Compression.ZipFile]::Open($jar.FullName, [System.IO.Compression.ZipArchiveMode]::Update)
            $entryPaths = @(
                "data/furnacerecycle/recipe/smelt_chain.json",
                "data/furnacerecycle/recipes/smelt_chain.json"
            )

            $patched = $false
            foreach ($entryPath in $entryPaths) {
                $entry = $zip.GetEntry($entryPath)
                if ($entry) {
                    $entry.Delete()
                    $newEntry = $zip.CreateEntry($entryPath)
                    $stream = $newEntry.Open()
                    try {
                        $writer = New-Object System.IO.StreamWriter($stream, [System.Text.UTF8Encoding]::new($false))
                        try { $writer.Write($fixedRecipeJson) } finally { $writer.Dispose() }
                    } finally {
                        $stream.Dispose()
                    }
                    Write-Host "    🧹 Furnace Recycle: rewrote recipe $entryPath as a valid chain smelting recipe" -ForegroundColor Yellow
                    $patched = $true
                }
            }

            if (-not $patched) {
                # If the upstream jar changes path slightly, add the fixed recipe at the modern path.
                $entryPath = "data/furnacerecycle/recipe/smelt_chain.json"
                $newEntry = $zip.CreateEntry($entryPath)
                $stream = $newEntry.Open()
                try {
                    $writer = New-Object System.IO.StreamWriter($stream, [System.Text.UTF8Encoding]::new($false))
                    try { $writer.Write($fixedRecipeJson) } finally { $writer.Dispose() }
                } finally {
                    $stream.Dispose()
                }
                Write-Host "    🧹 Furnace Recycle: added fixed recipe $entryPath" -ForegroundColor Yellow
            }
        } finally {
            if ($zip) { $zip.Dispose() }
        }
    }
} catch {
    Write-Host "    ⚠️  Furnace Recycle recipe fix failed: $($_.Exception.Message)" -ForegroundColor Yellow
}
