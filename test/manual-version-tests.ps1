#!/usr/bin/env pwsh
# Manual Version Tests - Simple validation script

$versions = @("1.21.5", "1.21.6", "1.21.7", "1.21.8")
$results = @()

Write-Host "🧪 Manual Version Testing" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

foreach ($version in $versions) {
    Write-Host ""
    Write-Host "🎯 Testing Version: $version" -ForegroundColor Yellow
    
    # Test 1: Check if files exist
    $versionFolder = "download/$version"
    $serverJar = "$versionFolder/minecraft_server.$version.jar"
    $fabricJar = Get-ChildItem -Path $versionFolder -Filter "fabric-server*.jar" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    $serverExists = Test-Path $serverJar
    $fabricExists = $fabricJar -ne $null
    
    if ($serverExists) {
        $serverSize = [math]::Round((Get-Item $serverJar).Length / 1MB, 2)
        Write-Host "  ✅ Minecraft Server JAR: ${serverSize} MB" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Minecraft Server JAR: NOT FOUND" -ForegroundColor Red
    }
    
    if ($fabricExists) {
        $fabricSize = [math]::Round($fabricJar.Length / 1MB, 2)
        Write-Host "  ✅ Fabric Server JAR: ${fabricSize} MB" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Fabric Server JAR: NOT FOUND" -ForegroundColor Red
    }
    
    # Test 2: Check URL resolution worked
    $wasResolved = $serverExists -and $fabricExists
    if ($wasResolved) {
        Write-Host "  ✅ URL Resolution: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "  ❌ URL Resolution: FAILED" -ForegroundColor Red
    }
    
    $results += [PSCustomObject]@{
        Version = $version
        ServerJAR = $serverExists
        FabricJAR = $fabricExists
        URLResolution = $wasResolved
        Status = if ($wasResolved) { "PASS" } else { "FAIL" }
    }
}

Write-Host ""
Write-Host "📊 Test Summary" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan

$results | Format-Table -AutoSize

$passCount = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$totalCount = $results.Count

Write-Host ""
if ($passCount -eq $totalCount) {
    Write-Host "🎉 ALL VERSIONS PASSED ($passCount/$totalCount)" -ForegroundColor Green
} else {
    Write-Host "⚠️  SOME VERSIONS FAILED ($passCount/$totalCount passed)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🔍 Detailed File Analysis:" -ForegroundColor Cyan
foreach ($result in $results) {
    if ($result.Status -eq "PASS") {
        $versionFolder = "download/$($result.Version)"
        $files = Get-ChildItem -Path $versionFolder -Recurse -File | Measure-Object -Property Length -Sum
        $totalSize = [math]::Round($files.Sum / 1MB, 2)
        $fileCount = $files.Count
        Write-Host "  Version $($result.Version): $fileCount files, ${totalSize} MB total" -ForegroundColor Gray
    }
}