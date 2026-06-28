# Prefer direct CurseForge/ForgeCDN URLs already stored in modlist.csv before calling CurseForge API.

if (-not $script:ValidateCurseForgeModVersionOriginalCommand) {
    $script:ValidateCurseForgeModVersionOriginalCommand = ${function:Validate-CurseForgeModVersion}
}

function Find-CurseForgeDirectRow {
    param(
        [string]$ModId,
        [string]$CsvPath
    )

    $paths = @($CsvPath, "modlist.csv") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    foreach ($path in $paths) {
        if (-not (Test-Path $path)) { continue }
        try {
            $row = Import-Csv -Path $path | Where-Object { $_.ID -eq $ModId } | Select-Object -First 1
            if ($row) { return $row }
        } catch { }
    }
    return $null
}

function Get-FileNameFromDirectUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return "" }
    try {
        $decoded = [System.Web.HttpUtility]::UrlDecode($Url)
        return [System.IO.Path]::GetFileName(($decoded -split '\?')[0])
    } catch { return "" }
}

function Validate-CurseForgeModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModId,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$Loader = "fabric",
        [string]$ResponseFolder = ".",
        [string]$Jar = "",
        [string]$ModUrl = "",
        [string]$CsvPath = "",
        [switch]$Quiet = $false
    )

    $row = Find-CurseForgeDirectRow -ModId $ModId -CsvPath $CsvPath
    if ($row) {
        $directUrl = if ($row.CurrentVersionUrl) { $row.CurrentVersionUrl } elseif ($row.LatestVersionUrl) { $row.LatestVersionUrl } else { $row.UrlDirect }
        if ($directUrl -and ($directUrl -like "*forgecdn.net*" -or $directUrl -like "*edge.forgecdn.net*")) {
            $fileName = Get-FileNameFromDirectUrl -Url $directUrl
            if (-not $Quiet) { Write-Host "CurseForge direct DB URL matched $($row.Name): $fileName" -ForegroundColor Green }
            return @{
                Success = $true
                Exists = $true
                Found = $true
                ModId = $ModId
                Version = if ($row.CurrentVersion) { $row.CurrentVersion } else { $Version }
                Loader = $Loader
                VersionUrl = $directUrl
                LatestVersion = if ($row.LatestVersion) { $row.LatestVersion } else { $row.CurrentVersion }
                LatestVersionUrl = if ($row.LatestVersionUrl) { $row.LatestVersionUrl } else { $directUrl }
                LatestGameVersion = if ($row.LatestGameVersion) { $row.LatestGameVersion } else { $row.CurrentGameVersion }
                FileName = $fileName
                Error = $null
                Title = if ($row.Title) { $row.Title } else { $row.Name }
                ProjectDescription = $row.ProjectDescription
                IconUrl = $row.IconUrl
                IssuesUrl = $row.IssuesUrl
                SourceUrl = $row.SourceUrl
                WikiUrl = $row.WikiUrl
            }
        }
    }

    & $script:ValidateCurseForgeModVersionOriginalCommand -ModId $ModId -Version $Version -Loader $Loader -ResponseFolder $ResponseFolder -Jar $Jar -ModUrl $ModUrl -CsvPath $CsvPath -Quiet:$Quiet
}
