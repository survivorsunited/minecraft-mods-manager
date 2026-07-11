# =============================================================================
# GitHub Add-Mod Database Path
# =============================================================================
# Handles GitHub repo URLs and direct GitHub release JAR URLs before the generic
# Add-ModToDatabase flow can fall back to system-* or Modrinth.
# =============================================================================

if (-not $script:OriginalAddModToDatabase -and (Get-Command Add-ModToDatabase -ErrorAction SilentlyContinue)) {
    $script:OriginalAddModToDatabase = ${function:Add-ModToDatabase}
}

if (-not $script:OriginalValidateGitHubModVersion -and (Get-Command Validate-GitHubModVersion -ErrorAction SilentlyContinue)) {
    $script:OriginalValidateGitHubModVersion = ${function:Validate-GitHubModVersion}
}

function Resolve-GitHubModIdFromCsv {
    param(
        [string]$ModID,
        [string]$CsvPath
    )

    if ([string]::IsNullOrWhiteSpace($CsvPath) -or -not (Test-Path $CsvPath)) { return $ModID }
    if ($ModID -match 'github\.com') { return $ModID }
    if ($ModID -match '^[^/\s]+/[^/\s]+$') { return $ModID }

    try {
        $row = Import-Csv -Path $CsvPath | Where-Object { $_.ID -eq $ModID } | Select-Object -First 1
        if ($row -and $row.Url -and $row.Url -match 'github\.com') {
            return $row.Url
        }
    } catch { }

    return $ModID
}

function Validate-GitHubModVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModID,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [Parameter(Mandatory=$true)]
        [string]$Loader,
        [string]$GameVersion = "",
        [bool]$UseCachedResponses = $false,
        [string]$CsvPath = $null,
        [switch]$Quiet = $false
    )

    $resolvedModId = Resolve-GitHubModIdFromCsv -ModID $ModID -CsvPath $CsvPath

    $call = @{
        ModID = $resolvedModId
        Version = $Version
        Loader = $Loader
        GameVersion = $GameVersion
        UseCachedResponses = $UseCachedResponses
        CsvPath = $CsvPath
    }
    if ($Quiet) { $call.Quiet = $true }

    return & $script:OriginalValidateGitHubModVersion @call
}

function Get-AddGitHubRepoUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return "" }

    if ($Url -match '^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/#?]+)') {
        return "https://github.com/$($matches.owner)/$(($matches.repo -replace '\.git$', ''))"
    }

    return ""
}

function Get-AddGitHubFallbackId {
    param([string]$Url)

    if ($Url -match '^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/#?]+)') {
        return "$($matches.owner)/$(($matches.repo -replace '\.git$', ''))"
    }

    return ""
}

function Add-GitHubModRowToDatabase {
    param(
        [string]$AddModId,
        [string]$AddModUrl,
        [string]$AddModName,
        [string]$AddModLoader,
        [string]$AddModGameVersion,
        [string]$AddModVersion,
        [string]$AddModType,
        [string]$AddModGroup,
        [string]$AddModDescription,
        [string]$AddModJar,
        [string]$AddModCategory,
        [string]$CsvPath
    )

    $repoUrl = Get-AddGitHubRepoUrl -Url $AddModUrl
    $validationTarget = if ($AddModUrl -match '/releases/download/.+\.jar') { $AddModUrl } else { $repoUrl }
    if (-not $validationTarget) { return $null }

    $result = Validate-GitHubModVersion -ModID $validationTarget -Version $AddModVersion -Loader $AddModLoader -GameVersion $AddModGameVersion -Quiet
    if (-not $result -or -not $result.Success) {
        Write-Host "  Warning: Could not validate GitHub metadata, falling back to generic add" -ForegroundColor Yellow
        return $null
    }

    if (-not $AddModId) { $AddModId = if ($result.ModId) { $result.ModId } else { Get-AddGitHubFallbackId -Url $AddModUrl } }
    if (-not $AddModName) { $AddModName = if ($result.Title) { $result.Title } else { $AddModId } }
    if (-not $AddModDescription -and $result.ProjectDescription) { $AddModDescription = $result.ProjectDescription }
    if (-not $AddModJar -and $result.Jar) { $AddModJar = $result.Jar }
    if (-not $AddModCategory) { $AddModCategory = "Utility" }
    if (-not $repoUrl -and $result.SourceUrl) { $repoUrl = $result.SourceUrl }

    if ($result.Version) { $AddModVersion = $result.Version }
    if ($result.CurrentGameVersion) { $AddModGameVersion = $result.CurrentGameVersion }

    $mods = @()
    if (Test-Path $CsvPath) {
        $existing = Import-Csv -Path $CsvPath
        if ($existing) { $mods = @($existing) }
    }

    if ($mods | Where-Object { $_.ID -eq $AddModId }) {
        Write-Host "Warning: Mod with ID '$AddModId' already exists in database" -ForegroundColor Yellow
        return $false
    }

    $newMod = [PSCustomObject]@{
        Group = $AddModGroup
        Type = $AddModType
        CurrentGameVersion = $AddModGameVersion
        ID = $AddModId
        Loader = $AddModLoader
        CurrentVersion = $AddModVersion
        Name = $AddModName
        Description = $AddModDescription
        Jar = $AddModJar
        Url = $AddModUrl
        Category = $AddModCategory
        CurrentVersionUrl = $result.VersionUrl
        NextVersion = ""
        NextVersionUrl = ""
        NextGameVersion = ""
        LatestVersionUrl = $result.LatestVersionUrl
        LatestVersion = $result.LatestVersion
        ApiSource = "github"
        Host = "github"
        IconUrl = $result.IconUrl
        ClientSide = "optional"
        ServerSide = "optional"
        Title = $AddModName
        ProjectDescription = if ($result.ProjectDescription) { $result.ProjectDescription } else { $AddModDescription }
        IssuesUrl = $result.IssuesUrl
        SourceUrl = if ($result.SourceUrl) { $result.SourceUrl } else { $repoUrl }
        WikiUrl = $result.WikiUrl
        LatestGameVersion = $result.LatestGameVersion
        RecordHash = ""
        CurrentDependencies = ""
        LatestDependencies = ""
        CurrentDependenciesRequired = ""
        CurrentDependenciesOptional = ""
        LatestDependenciesRequired = ""
        LatestDependenciesOptional = ""
    }

    try {
        if (Get-Command Calculate-RecordHash -ErrorAction SilentlyContinue) {
            $newMod.RecordHash = Calculate-RecordHash -Record $newMod
        }
    } catch { }

    $mods += $newMod
    $mods | Export-Csv -Path $CsvPath -NoTypeInformation

    Write-Host "✅ Successfully added mod '$AddModName' to database" -ForegroundColor Green
    return $true
}

function Add-ModToDatabase {
    param(
        [string]$AddModId,
        [string]$AddModUrl,
        [string]$AddModName,
        [string]$AddModLoader = "fabric",
        [string]$AddModGameVersion = "1.21.8",
        [string]$AddModVersion = "current",
        [string]$AddModType = "mod",
        [string]$AddModGroup = "required",
        [string]$AddModDescription = "",
        [string]$AddModJar = "",
        [string]$AddModUrlDirect = "",
        [string]$AddModCategory = "",
        [switch]$ForceDownload,
        [string]$CsvPath = "modlist.csv"
    )

    if ($AddModUrl -and $AddModUrl -match 'github\.com') {
        $added = Add-GitHubModRowToDatabase `
            -AddModId $AddModId `
            -AddModUrl $AddModUrl `
            -AddModName $AddModName `
            -AddModLoader $AddModLoader `
            -AddModGameVersion $AddModGameVersion `
            -AddModVersion $AddModVersion `
            -AddModType $AddModType `
            -AddModGroup $AddModGroup `
            -AddModDescription $AddModDescription `
            -AddModJar $AddModJar `
            -AddModCategory $AddModCategory `
            -CsvPath $CsvPath

        if ($null -ne $added) { return $added }
    }

    $call = @{
        AddModId = $AddModId
        AddModUrl = $AddModUrl
        AddModName = $AddModName
        AddModLoader = $AddModLoader
        AddModGameVersion = $AddModGameVersion
        AddModVersion = $AddModVersion
        AddModType = $AddModType
        AddModGroup = $AddModGroup
        AddModDescription = $AddModDescription
        AddModJar = $AddModJar
        AddModUrlDirect = $AddModUrlDirect
        AddModCategory = $AddModCategory
        CsvPath = $CsvPath
    }

    if ($ForceDownload) { $call.ForceDownload = $true }

    return & $script:OriginalAddModToDatabase @call
}
