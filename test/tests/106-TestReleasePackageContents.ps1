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
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
            $readmeContent = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            $readmeContent | Out-File -FilePath $tempReadme -Encoding UTF8 -Force
        }
        $zipFile.Dispose()
        
        if ($readmeContent) {
            # Debug: Save README for inspection
            $readmeDebugPath = Join-Path $TestOutputDir "README-debug.txt"
            $readmeContent | Out-File -FilePath $readmeDebugPath -Encoding UTF8 -Force
            Write-Host "DEBUG: README length: $($readmeContent.Length) chars" -ForegroundColor Yellow
            Write-Host "DEBUG: First 1000 chars of README:" -ForegroundColor Yellow
            Write-Host $readmeContent.Substring(0, [Math]::Min(1000, $readmeContent.Length)) -ForegroundColor Gray
            
            # Check for combined mods table - can be "### All Mods" or "## Mods Table" (case insensitive)
            # Pattern allows for optional count in parentheses like "### All Mods (42)"
            # Use multiline mode to match across lines
            $allModsPattern = '(?im)(^###\s+All\s+Mods|^##\s+Mods\s+Table)'
            $allModsMatches = [regex]::Matches($readmeContent, $allModsPattern)
            $hasAllModsSection = $allModsMatches.Count -ge 1
            if (-not $hasAllModsSection) {
                # Debug: Check what sections actually exist
                $sectionMatches = [regex]::Matches($readmeContent, '(?im)^#{1,3}\s+.+', [System.Text.RegularExpressions.RegexOptions]::Multiline)
                Write-Host "DEBUG: Found sections: $($sectionMatches.Count)" -ForegroundColor Yellow
                foreach ($match in $sectionMatches) {
                    Write-Host "  - $($match.Value.Trim())" -ForegroundColor Gray
                }
                # Also check for the exact pattern we're looking for
                Write-Host "DEBUG: Searching for pattern: $allModsPattern" -ForegroundColor Yellow
                Write-Host "DEBUG: First 500 chars of README:" -ForegroundColor Yellow
                Write-Host $readmeContent.Substring(0, [Math]::Min(500, $readmeContent.Length)) -ForegroundColor Gray
            }
            Write-TestResult "README has mods table section" $hasAllModsSection
            
            # Check for Category and Type columns in the table (case insensitive, flexible spacing)
            # Use multiline mode and allow for flexible spacing
            $headerPattern = '(?im)\|.*Name.*\|.*ID.*\|.*Version.*\|.*Description.*\|.*Category.*\|.*Type.*\|'
            $hasCategoryHeader = $readmeContent -match $headerPattern
            if (-not $hasCategoryHeader) {
                # Debug: Find what header lines actually exist
                $headerLines = [regex]::Matches($readmeContent, '(?im)^\|.*\|', [System.Text.RegularExpressions.RegexOptions]::Multiline)
                Write-Host "DEBUG: Found $($headerLines.Count) table header lines" -ForegroundColor Yellow
                foreach ($match in $headerLines | Select-Object -First 3) {
                    Write-Host "  - $($match.Value.Trim())" -ForegroundColor Gray
                }
            }
            Write-TestResult "README has Category and Type columns in mods table" $hasCategoryHeader
            
            # Verify no separate sections exist (should be combined table)
            $hasMandatorySection = $readmeContent -match '(?i)###\s+Mandatory\s+Mods'
            $hasOptionalSection = $readmeContent -match '(?i)###\s+Optional\s+Mods'
            $hasBlockedSection = $readmeContent -match '(?i)###\s+Blocked\s+Mods'
            $noSeparateSections = -not ($hasMandatorySection -or $hasOptionalSection -or $hasBlockedSection)
            Write-TestResult "README does not have separate Mandatory/Optional/Blocked sections" $noSeparateSections
            
            # Verify tables are actually tables (not bullet lists) - flexible regex
            $hasTableFormat = $readmeContent -match $headerPattern
            # Table separator can have any combination of dashes and colons
            $separatorPattern = '\|[\s]*[-:]+[\s]*\|'
            $hasTableSeparator = $readmeContent -match $separatorPattern
            $hasProperTable = $hasTableFormat -and $hasTableSeparator
            Write-TestResult "README uses proper Markdown table format (not bullet lists)" $hasProperTable
        } else {
            Write-TestResult "README.md content readable" $false
        }
    }
}

Show-TestSummary

