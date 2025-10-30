function Reconcile-ExpectedVsCache {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$CsvPath = "modlist.csv",
        [string]$DownloadFolder = "download",
        # report: exact comparison; relaxed-version: ignore version-only differences for mods
        [ValidateSet('report','relaxed-version')]
        [string]$Mode = 'report',
        [string]$OutputPath
    )

    $ErrorActionPreference = 'Stop'

    # Resolve paths
    if (-not ([System.IO.Path]::IsPathRooted($CsvPath))) {
        $CsvPath = Join-Path $PSScriptRoot (Join-Path '..\..' $CsvPath) | Resolve-Path | Select-Object -ExpandProperty Path
    }
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $dlVersionPath = Join-Path (Join-Path $repoRoot $DownloadFolder) $Version
    if (-not (Test-Path $dlVersionPath)) { throw "download/$Version not found at $dlVersionPath" }

    # Prepare output dir
    if (-not $OutputPath) {
        $baseReleaseDir = Join-Path (Join-Path $repoRoot 'releases') $Version
        New-Item -ItemType Directory -Path $baseReleaseDir -Force | Out-Null
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $outDir = Join-Path $baseReleaseDir ("reconcile-" + $stamp)
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        $OutputPath = Join-Path $outDir 'reconciliation-report.txt'
    } else {
        if (-not ([System.IO.Path]::IsPathRooted($OutputPath))) { $OutputPath = Join-Path $repoRoot $OutputPath }
        $outDir = Split-Path -Parent $OutputPath
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    Write-Host "Reconciling CSV expectations vs cache for $Version" -ForegroundColor Cyan

    # 1) Expected files from CSV
    $expectedTmp = Join-Path $outDir 'expected.txt'
    $null = Get-ExpectedReleaseFiles -Version $Version -CsvPath $CsvPath -OutputPath $expectedTmp
    if (-not (Test-Path $expectedTmp)) { throw "Expected list not created at $expectedTmp" }

    # Filter scope
    $expectedCompare = Get-Content -Path $expectedTmp | Where-Object { (($_ -like 'mods/*') -or ($_ -like 'shaderpacks/*') -or ($_ -like 'datapacks/*')) -and ($_ -notlike 'mods/block/*') }

    # 2) Actual files from cache layout
    $modsPath = Join-Path $dlVersionPath 'mods'
    $shaderPath = Join-Path $dlVersionPath 'shaderpacks'
    $datapacksPath = Join-Path $dlVersionPath 'datapacks'
    $actual = @()
    if (Test-Path $modsPath) { $actual += (Get-ChildItem -Path $modsPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.jar', '.zip') } | ForEach-Object { "mods/" + $_.Name }) }
    $modsOpt = Join-Path $modsPath 'optional'
    if (Test-Path $modsOpt) { $actual += (Get-ChildItem -Path $modsOpt -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.jar', '.zip') } | ForEach-Object { "mods/optional/" + $_.Name }) }
    if (Test-Path $shaderPath) { $actual += (Get-ChildItem -Path $shaderPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip','.jar') } | ForEach-Object { "shaderpacks/" + $_.Name }) }
    if (Test-Path $datapacksPath) {
        $dpFiles = Get-ChildItem -Path $datapacksPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip','.jar') }
        $actual += ($dpFiles | ForEach-Object { "datapacks/" + $_.Name })
        foreach ($f in $dpFiles) { if ($f.Extension.ToLower() -eq '.jar') { $actual += ("mods/" + $f.Name) } }
    }
    $actual = $actual | Sort-Object

    # 3) Differences
    $expectedSet = New-Object System.Collections.Generic.HashSet[string]
    $null = $expectedCompare | ForEach-Object { $expectedSet.Add($_) | Out-Null }
    $actualSet = New-Object System.Collections.Generic.HashSet[string]
    $null = $actual | ForEach-Object { $actualSet.Add($_) | Out-Null }

    $missing = @(); foreach ($e in $expectedSet) { if (-not $actualSet.Contains($e)) { $missing += $e } }
    $extra = @(); foreach ($a in $actualSet) { if (-not $expectedSet.Contains($a)) { $extra += $a } }

    # Warnings
    $expectedModZips = $expectedCompare | Where-Object { ($_ -like 'mods/*.zip') -or ($_ -like 'mods/optional/*.zip') }
    $actualModZips = $actual | Where-Object { ($_ -like 'mods/*.zip') -or ($_ -like 'mods/optional/*.zip') }
    $warnings = @()
    if ($expectedModZips.Count -gt 0) { $warnings += "CSV expects ZIPs under mods/: likely misclassification or bad filename:"; $warnings += ($expectedModZips | ForEach-Object { "  - $_" }) }
    if ($actualModZips.Count -gt 0) { $warnings += "Cache contains ZIPs under mods/: likely wrong file picked (expected JAR):"; $warnings += ($actualModZips | ForEach-Object { "  - $_" }) }
    if (Test-Path $datapacksPath) {
        $dpJarAliases = Get-ChildItem -Path $datapacksPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.jar' } | ForEach-Object { $_.Name }
        if ($dpJarAliases.Count -gt 0) { $warnings += "Datapack JARs will be placed under mods/ in release (aliased here):"; $warnings += ($dpJarAliases | ForEach-Object { "  - $_" }) }
    }

    # Optional relaxed version pairing
    $versionPairs = @()
    if ($Mode -eq 'relaxed-version') {
        function Get-BaseModKey([string]$relPath) {
            if ($relPath -notlike 'mods/*') { return $null }
            $folder = if ($relPath.StartsWith('mods/optional/')) { 'mods/optional/' } else { 'mods/' }
            $file = $relPath.Substring($folder.Length)
            $name = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $m = [System.Text.RegularExpressions.Regex]::Match($name, '^(.*?)(?:[-_]?)(?=\d)')
            $base = if ($m.Success -and $m.Groups.Count -gt 1 -and $m.Groups[1].Value.Trim().Length -gt 0) { $m.Groups[1].Value.TrimEnd('-','_') } else { $name }
            return $folder + $base.ToLower()
        }
        $expectedByBase = @{}; foreach ($e in $missing) { $k = Get-BaseModKey $e; if ($null -ne $k) { if (-not $expectedByBase.ContainsKey($k)) { $expectedByBase[$k] = @() }; $expectedByBase[$k] += $e } }
        $actualByBase = @{}; foreach ($a in $extra)   { $k = Get-BaseModKey $a; if ($null -ne $k) { if (-not $actualByBase.ContainsKey($k))   { $actualByBase[$k] = @() } ; $actualByBase[$k]   += $a } }
        $pairedMissing = New-Object System.Collections.Generic.HashSet[string]
        $pairedExtra = New-Object System.Collections.Generic.HashSet[string]
        foreach ($k in $expectedByBase.Keys) {
            if ($actualByBase.ContainsKey($k)) {
                foreach ($eItem in $expectedByBase[$k]) { $pairedMissing.Add($eItem) | Out-Null }
                foreach ($aItem in $actualByBase[$k])   { $pairedExtra.Add($aItem)  | Out-Null }
                $versionPairs += [pscustomobject]@{ Base=$k; Expected=($expectedByBase[$k] -join ', '); Actual=($actualByBase[$k] -join ', ') }
            }
        }
        if ($pairedMissing.Count -gt 0 -or $pairedExtra.Count -gt 0) {
            $missing = $missing | Where-Object { -not $pairedMissing.Contains($_) }
            $extra   = $extra   | Where-Object { -not $pairedExtra.Contains($_) }
        }
    }

    # Report
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("Reconciliation Report for $Version")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format 'u')")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Summary:")
    [void]$sb.AppendLine("  Expected (CSV): $($expectedCompare.Count)")
    [void]$sb.AppendLine("  Actual (Cache): $($actual.Count)")
    [void]$sb.AppendLine("  Missing: $($missing.Count)")
    [void]$sb.AppendLine("  Extra:   $($extra.Count)")
    [void]$sb.AppendLine("  Mode:    $Mode")
    [void]$sb.AppendLine("")
    if ($versionPairs.Count -gt 0) {
        [void]$sb.AppendLine("Version-only differences paired (mods):")
        foreach ($p in $versionPairs) { [void]$sb.AppendLine("  - Base: $($p.Base)\n    expected: $($p.Expected)\n    actual:   $($p.Actual)") }
        [void]$sb.AppendLine("")
    }
    [void]$sb.AppendLine("Missing (expected but not in cache):")
    foreach ($m in ($missing | Sort-Object)) { [void]$sb.AppendLine("  - $m") }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Extra (in cache but not expected):")
    foreach ($x in ($extra | Sort-Object)) { [void]$sb.AppendLine("  - $x") }

    $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8
    ($missing | Sort-Object) | Out-File -FilePath (Join-Path $outDir 'missing.txt') -Encoding UTF8
    ($extra   | Sort-Object) | Out-File -FilePath (Join-Path $outDir 'extra.txt') -Encoding UTF8
    ($expectedCompare | Sort-Object) | Out-File -FilePath (Join-Path $outDir 'expected.txt') -Encoding UTF8
    ($actual  | Sort-Object) | Out-File -FilePath (Join-Path $outDir 'actual.txt') -Encoding UTF8

    if ($warnings.Count -gt 0) {
        $warningsHeader = @("Warnings:")
        $warningsOut = $warningsHeader + $warnings
        $warningsOut | Out-File -FilePath (Join-Path $outDir 'warnings.txt') -Encoding UTF8
        Write-Host "⚠️  Reconciliation warnings detected (${($warnings.Count)} lines)" -ForegroundColor DarkYellow
    }

    Write-Host "Report written -> $OutputPath" -ForegroundColor Green
    Write-Host "Missing: $($missing.Count) | Extra: $($extra.Count)" -ForegroundColor Yellow

    return [pscustomobject]@{
        Version = $Version
        Mode = $Mode
        OutputPath = $OutputPath
        MissingCount = $missing.Count
        ExtraCount = $extra.Count
        OutDir = $outDir
        WarningsCount = $warnings.Count
    }
}
