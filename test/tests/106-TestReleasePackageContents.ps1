# Import test framework
. "$PSScriptRoot\..\TestFramework.ps1"

$TestFileName = "106-TestReleasePackageContents.ps1"
Initialize-TestEnvironment $TestFileName

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ModManagerPath = Join-Path $ProjectRoot "ModManager.ps1"
$ReleaseScript = Join-Path $ProjectRoot "src\Release\New-Release.ps1"
$TestOutputDir = Get-TestOutputFolder $TestFileName
$DownloadDir = Join-Path $TestOutputDir "download"
$ReleaseDir = Join-Path $TestOutputDir "releases"

New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-TestHeader "Create release package for 1.21.8"
# Import modules first
. (Join-Path $ProjectRoot "src\Import-Modules.ps1")
. $ReleaseScript
$releaseResult = New-Release -CsvPath (Join-Path $ProjectRoot "modlist.csv") -DownloadFolder $DownloadDir -ApiResponseFolder (Join-Path $ProjectRoot "apiresponse") -ReleasePath $ReleaseDir -GameVersion "1.21.8" -ProjectRoot $ProjectRoot -NoAutoRestart
$ok = if ($releaseResult -is [bool]) { $releaseResult } else { $true }
Write-TestResult "Release created" $ok

$relPath = Join-Path $ReleaseDir "1.21.8"
$zip = Get-ChildItem -Path $relPath -Filter "*.zip" -File -ErrorAction SilentlyContinue | Select-Object -First 1
$zipExists = $null -ne $zip
Write-TestResult "modpack.zip exists" $zipExists

if ($zipExists) {
    Write-TestHeader "Validate ZIP contents"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipFile = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
    $entries = $zipFile.Entries | Select-Object -ExpandProperty FullName
    $zipFile.Dispose()
    
    # Check for forbidden files
    $forbidden = @("expected-release-files.txt", "actual-release-files.txt", "verification-missing.txt", "verification-extra.txt")
    $foundForbidden = @()
    foreach ($f in $forbidden) {
        $found = $entries | Where-Object { $_ -like "*$f*" }
        if ($found) { $foundForbidden += $found }
    }
    
    $noForbidden = $foundForbidden.Count -eq 0
    Write-TestResult "ZIP excludes verification files" $noForbidden
    if (-not $noForbidden) {
        Write-Host "  Found forbidden files:" -ForegroundColor Red
        $foundForbidden | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    }
    
    # Check for reconcile directories
    $reconcileDirs = $entries | Where-Object { $_ -like "*reconcile-*" }
    $noReconcile = $reconcileDirs.Count -eq 0
    Write-TestResult "ZIP excludes reconcile directories" $noReconcile
    if (-not $noReconcile) {
        Write-Host "  Found reconcile dirs:" -ForegroundColor Red
        $reconcileDirs | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    }
    
    # Check for installers
    $hasExe = $entries | Where-Object { $_ -like "*fabric-installer*.exe" } | Select-Object -First 1
    $hasJar = $entries | Where-Object { $_ -like "*install/*fabric-installer*.jar" } | Select-Object -First 1
    Write-TestResult "ZIP contains installer EXE" ($null -ne $hasExe)
    Write-TestResult "ZIP contains installer JAR in install/" ($null -ne $hasJar)
    
    if ($hasExe) { Write-Host "  Found: $hasExe" -ForegroundColor Green }
    if ($hasJar) { Write-Host "  Found: $hasJar" -ForegroundColor Green }
    
    # Validate README.md has Category column in tables
    Write-TestHeader "Validate README.md format"
    $readmeEntry = $entries | Where-Object { $_ -eq "README.md" } | Select-Object -First 1
    $hasReadme = $null -ne $readmeEntry
    Write-TestResult "README.md exists in ZIP" $hasReadme
    
    if ($hasReadme) {
        $tempReadme = Join-Path $TestOutputDir "README.md"
        $zipFile = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
        $readmeEntry = $zipFile.Entries | Where-Object { $_.FullName -eq "README.md" } | Select-Object -First 1
        if ($readmeEntry) {
            $stream = $readmeEntry.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $readmeContent = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            $readmeContent | Out-File -FilePath $tempReadme -Encoding UTF8 -Force
        }
        $zipFile.Dispose()
        
        if ($readmeContent) {
            # Check for combined mods table - can be "### All Mods" or "## Mods Table"
            $allModsMatches = [regex]::Matches($readmeContent, '(### All Mods|## Mods Table)')
            $hasAllModsSection = $allModsMatches.Count -ge 1
            Write-TestResult "README has mods table section" $hasAllModsSection
            
            # Check for Category and Type columns in the table (flexible regex)
            $hasCategoryHeader = $readmeContent -match '\|.*Name.*\|.*ID.*\|.*Version.*\|.*Description.*\|.*Category.*\|.*Type.*\|'
            Write-TestResult "README has Category and Type columns in mods table" $hasCategoryHeader
            
            # Verify no separate sections exist (should be combined table)
            $hasMandatorySection = $readmeContent -match '### Mandatory Mods'
            $hasOptionalSection = $readmeContent -match '### Optional Mods'
            $hasBlockedSection = $readmeContent -match '### Blocked Mods'
            $noSeparateSections = -not ($hasMandatorySection -or $hasOptionalSection -or $hasBlockedSection)
            Write-TestResult "README does not have separate Mandatory/Optional/Blocked sections" $noSeparateSections
            
            # Verify tables are actually tables (not bullet lists) - more flexible regex
            $hasTableFormat = $readmeContent -match '\|.*Name.*\|.*ID.*\|.*Version.*\|.*Description.*\|.*Category.*\|.*Type.*\|'
            $hasTableSeparator = $readmeContent -match '\|[-:]+\|[-:]+\|[-:]+\|[-:]+\|[-:]+\|[-:]+\|'
            $hasProperTable = $hasTableFormat -and $hasTableSeparator
            Write-TestResult "README uses proper Markdown table format (not bullet lists)" $hasProperTable
        } else {
            Write-TestResult "README.md content readable" $false
        }
    }
}

Show-TestSummary

