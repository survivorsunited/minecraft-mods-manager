# =============================================================================
# Apply Mod Patches
# =============================================================================
# Runs local post-download patch scripts from patches/mods/<mod-id>/<version>/*.ps1.
# =============================================================================

function Apply-ModPatches {
    param(
        [string]$DownloadFolder = "download",
        [string]$TargetGameVersion = "",
        [string]$ModListPath = "modlist.csv"
    )

    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $patchRoot = Join-Path $projectRoot "patches\mods"

    if (-not (Test-Path $patchRoot)) { return }

    $effectiveDownloadFolder = if ([System.IO.Path]::IsPathRooted($DownloadFolder)) { $DownloadFolder } else { Join-Path $projectRoot $DownloadFolder }
    $effectiveModListPath = if ([System.IO.Path]::IsPathRooted($ModListPath)) { $ModListPath } else { Join-Path $projectRoot $ModListPath }

    $patchScripts = @()

    if (-not [string]::IsNullOrWhiteSpace($TargetGameVersion)) {
        $patchScripts += Get-ChildItem -Path $patchRoot -Recurse -Filter "*.ps1" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\$([regex]::Escape($TargetGameVersion))\\" }
    } else {
        $patchScripts += Get-ChildItem -Path $patchRoot -Recurse -Filter "*.ps1" -ErrorAction SilentlyContinue
    }

    $patchScripts = @($patchScripts | Sort-Object FullName -Unique)
    if ($patchScripts.Count -eq 0) { return }

    Write-Host "🧩 Applying $($patchScripts.Count) mod patch script(s)..." -ForegroundColor Cyan

    foreach ($script in $patchScripts) {
        try {
            Write-Host "  🧩 Patch: $($script.FullName.Replace($projectRoot, '').TrimStart('\'))" -ForegroundColor DarkGray
            & $script.FullName -DownloadRoot $effectiveDownloadFolder -TargetGameVersion $TargetGameVersion -ModListPath $effectiveModListPath
        } catch {
            Write-Host "  ⚠️  Patch failed: $($script.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}
