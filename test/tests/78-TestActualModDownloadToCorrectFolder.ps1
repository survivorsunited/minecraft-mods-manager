# =============================================================================
# Test: ACTUAL Mod Download to Correct Folder
# =============================================================================
# This test ACTUALLY downloads mods and verifies they end up in the RIGHT folder
# No more fucking around with theory - this PROVES it works or doesn't!
# =============================================================================

# Import modules first
. "$PSScriptRoot\..\..\src\Import-Modules.ps1"

function Test-ActualModDownloadToCorrectFolder {
    param(
        [string]$TestDownloadFolder = "test-output/test-actual-download"
    )
    
    Write-Host "🧪 ACTUAL TEST: Download mods to the CORRECT FUCKING FOLDER!" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    
    try {
        # Ensure test-output directory exists
        $testOutputDir = Split-Path $TestDownloadFolder -Parent
        if (-not (Test-Path $testOutputDir)) {
            New-Item -ItemType Directory -Path $testOutputDir -Force | Out-Null
        }
        
        # Clean up any existing test folder
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
        
        # Test 1: First, let's see what mods are for 1.21.6 in the database
        Write-Host "🔍 Test 1: Checking what mods exist for 1.21.6 in database..." -ForegroundColor Yellow
        
        $allMods = Get-ModList -CsvPath "modlist.csv"
        $mods126 = $allMods | Where-Object { $_.GameVersion -eq "1.21.6" }
        
        Write-Host "  📊 Total mods in database: $($allMods.Count)" -ForegroundColor Gray
        Write-Host "  📊 Mods for 1.21.6: $($mods126.Count)" -ForegroundColor Gray
        
        if ($mods126.Count -gt 0) {
            Write-Host "  📋 1.21.6 mods found:" -ForegroundColor Gray
            $mods126 | ForEach-Object {
                Write-Host "    - $($_.Name) ($($_.Type))" -ForegroundColor Gray
            }
        }
        
        # Test 2: Now let's ACTUALLY download for 1.21.6
        Write-Host ""
        Write-Host "🔍 Test 2: ACTUALLY downloading mods for version 1.21.6..." -ForegroundColor Yellow
        Write-Host "  📁 Target folder: $TestDownloadFolder/1.21.6/mods/" -ForegroundColor Cyan
        
        # Capture the output to see what the fuck is happening
        $output = Download-Mods -CsvPath "modlist.csv" `
                               -DownloadFolder $TestDownloadFolder `
                               -TargetGameVersion "1.21.6" `
                               -ForceDownload 2>&1
        
        # Show key output lines
        $output | Where-Object { $_ -match "(Filtering|Targeting|Will clear|Successfully downloaded)" } | ForEach-Object {
            Write-Host "  OUTPUT: $_" -ForegroundColor DarkGray
        }
        
        # Test 3: Check what folders were created
        Write-Host ""
        Write-Host "🔍 Test 3: Checking created folders..." -ForegroundColor Yellow
        
        if (Test-Path $TestDownloadFolder) {
            $versionFolders = Get-ChildItem -Path $TestDownloadFolder -Directory
            Write-Host "  📁 Version folders created:" -ForegroundColor Gray
            foreach ($folder in $versionFolders) {
                Write-Host "    - $($folder.Name)" -ForegroundColor Gray
                
                # Check mods subfolder
                $modsFolder = Join-Path $folder.FullName "mods"
                if (Test-Path $modsFolder) {
                    $modFiles = Get-ChildItem -Path $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue
                    Write-Host "      └─ mods/ ($($modFiles.Count) files)" -ForegroundColor Gray
                    
                    if ($modFiles.Count -gt 0) {
                        $modFiles | Select-Object -First 3 | ForEach-Object {
                            Write-Host "         - $($_.Name)" -ForegroundColor DarkGray
                        }
                        if ($modFiles.Count -gt 3) {
                            Write-Host "         ... and $($modFiles.Count - 3) more" -ForegroundColor DarkGray
                        }
                    }
                }
            }
        } else {
            Write-Host "  ❌ No download folder created at all!" -ForegroundColor Red
        }
        
        # Test 4: CRITICAL - Check if mods are in 1.21.6 folder
        Write-Host ""
        Write-Host "🔍 Test 4: CRITICAL CHECK - Are mods in 1.21.6 folder?" -ForegroundColor Yellow
        
        $folder126 = Join-Path $TestDownloadFolder "1.21.6"
        $modsFolder126 = Join-Path $folder126 "mods"
        
        $success = $false
        
        if (Test-Path $modsFolder126) {
            $modFiles126 = Get-ChildItem -Path $modsFolder126 -Filter "*.jar" -ErrorAction SilentlyContinue
            
            if ($modFiles126.Count -gt 0) {
                Write-Host "  ✅ SUCCESS! Found $($modFiles126.Count) mods in 1.21.6/mods/!" -ForegroundColor Green
                Write-Host "  📋 Mods in correct folder:" -ForegroundColor Green
                $modFiles126 | Select-Object -First 5 | ForEach-Object {
                    Write-Host "    ✓ $($_.Name)" -ForegroundColor Green
                }
                $success = $true
            } else {
                Write-Host "  ❌ FAILURE! Mods folder exists but is EMPTY!" -ForegroundColor Red
            }
        } else {
            Write-Host "  ❌ FAILURE! No mods folder in 1.21.6!" -ForegroundColor Red
        }
        
        # Test 5: Check if mods ended up in WRONG folder (1.21.5)
        Write-Host ""
        Write-Host "🔍 Test 5: Checking if mods went to WRONG folder..." -ForegroundColor Yellow
        
        $folder125 = Join-Path $TestDownloadFolder "1.21.5"
        $modsFolder125 = Join-Path $folder125 "mods"
        
        if (Test-Path $modsFolder125) {
            $modFiles125 = Get-ChildItem -Path $modsFolder125 -Filter "*.jar" -ErrorAction SilentlyContinue
            
            if ($modFiles125.Count -gt 0) {
                Write-Host "  ❌ PROBLEM! Found $($modFiles125.Count) mods in WRONG folder (1.21.5)!" -ForegroundColor Red
                Write-Host "  📋 Mods in WRONG folder:" -ForegroundColor Red
                $modFiles125 | Select-Object -First 3 | ForEach-Object {
                    Write-Host "    - $($_.Name)" -ForegroundColor Red
                }
                $success = $false
            }
        }
        
        # Final verdict
        Write-Host ""
        Write-Host "================================================" -ForegroundColor Cyan
        if ($success) {
            Write-Host "🎉 TEST PASSED! MODS ARE IN THE CORRECT FOLDER!" -ForegroundColor Green
            Write-Host "✅ Version 1.21.6 mods are in download/1.21.6/mods/" -ForegroundColor Green
        } else {
            Write-Host "💥 TEST FAILED! MODS ARE NOT IN THE CORRECT FOLDER!" -ForegroundColor Red
            Write-Host "❌ The targeting is STILL BROKEN!" -ForegroundColor Red
            
            # Debug info
            Write-Host ""
            Write-Host "🔍 DEBUG INFO:" -ForegroundColor Yellow
            Write-Host "  - Expected mods in: $modsFolder126" -ForegroundColor Yellow
            Write-Host "  - Mods might be in: $modsFolder125" -ForegroundColor Yellow
            Write-Host "  - Check the output above for clues!" -ForegroundColor Yellow
        }
        
        return $success
        
    } catch {
        Write-Host "❌ Test crashed with error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $false
    } finally {
        # Clean up test folder
        if (Test-Path $TestDownloadFolder) {
            Remove-Item -Recurse -Force $TestDownloadFolder -ErrorAction SilentlyContinue
        }
    }
}

# Run the fucking test
Write-Host "🚀 Running ACTUAL download test..." -ForegroundColor Magenta
$testResult = Test-ActualModDownloadToCorrectFolder

if ($testResult) {
    Write-Host ""
    Write-Host "✅ THE FIX WORKS! Mods download to correct folder!" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "❌ THE FIX DOESN'T WORK! Still broken!" -ForegroundColor Red
    exit 1
}