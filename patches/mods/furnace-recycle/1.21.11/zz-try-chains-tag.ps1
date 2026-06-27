param(
    [string]$DownloadRoot,
    [string]$TargetGameVersion,
    [string]$ModListPath
)

if ($TargetGameVersion -and $TargetGameVersion -ne "1.21.11") { return }
if (-not (Test-Path $DownloadRoot)) { return }

$recipe = @'
{
  "type": "minecraft:smelting",
  "group": "iron_ingot",
  "experience": 0.1,
  "cookingtime": 200,
  "ingredient": {
    "tag": "minecraft:chains"
  },
  "result": {
    "id": "minecraft:iron_ingot",
    "count": 1
  }
}
'@

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $jars = Get-ChildItem -Path $DownloadRoot -Filter "furnacerecycle-*.jar" -Recurse -ErrorAction SilentlyContinue
    foreach ($jar in $jars) {
        $zip = $null
        try {
            $zip = [System.IO.Compression.ZipFile]::Open($jar.FullName, [System.IO.Compression.ZipArchiveMode]::Update)
            $path = "data/furnacerecycle/recipe/smelt_chain.json"
            $old = $zip.GetEntry($path)
            if ($old) { $old.Delete() }
            $entry = $zip.CreateEntry($path)
            $stream = $entry.Open()
            try {
                $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
                try { $writer.Write($recipe) } finally { $writer.Dispose() }
            } finally {
                $stream.Dispose()
            }
            Write-Host "    🧪 Furnace Recycle: trying chains tag recipe shape for smelt_chain" -ForegroundColor Yellow
        } finally {
            if ($zip) { $zip.Dispose() }
        }
    }
} catch {
    Write-Host "    ⚠️  Furnace Recycle chains tag test failed: $($_.Exception.Message)" -ForegroundColor Yellow
}
