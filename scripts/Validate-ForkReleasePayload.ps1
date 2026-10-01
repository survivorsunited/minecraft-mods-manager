param(
    [Parameter(Mandatory=$true)][string]$ReleasePath,
    [string]$PinsPath = "$PSScriptRoot/../fork-release-pins.json"
)
$ErrorActionPreference = 'Stop'
$pins = Get-Content -LiteralPath $PinsPath -Raw | ConvertFrom-Json
$modsPath = Join-Path $ReleasePath 'mods'
$jars = @(Get-ChildItem -LiteralPath $modsPath -Recurse -File | Where-Object {
    $_.Extension -eq '.jar' -and $_.FullName -notmatch '[\\/]block[\\/]'
})
foreach ($pin in $pins.mods) {
    $family = @($jars | Where-Object { $_.Name -like $pin.pattern })
    if ($family.Count -ne 1 -or $family[0].Name -cne $pin.file) {
        throw "Expected exactly one $($pin.file); found: $($family.Name -join ', ')"
    }
    $hash = (Get-FileHash -LiteralPath $family[0].FullName -Algorithm SHA256).Hash
    if ($hash -ne $pin.sha256) { throw "Release asset checksum mismatch: $($pin.file)" }
    Write-Host "Verified published fork asset: $($pin.file)"
}
