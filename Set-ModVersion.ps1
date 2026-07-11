<#
.SYNOPSIS
    Sets the version of an existing mod database row.

.DESCRIPTION
    Updates CurrentVersion for a mod and, by default, keeps LatestVersion in sync.
    Unless -SkipValidation is used, the requested version is validated through the
    row's configured provider and the current download URL, JAR name, metadata and
    record hash are refreshed.

    Validation is performed against a temporary copy of the database. This prevents
    provider validation from partially changing the real database when validation
    fails or when a provider suggests a different version.

.PARAMETER ModID
    Exact mod ID from modlist.csv.

.PARAMETER Version
    Exact provider version to set. The command fails if validation resolves a
    different version.

.PARAMETER GameVersion
    Optional Minecraft version override. By default, CurrentGameVersion from the row
    is used.

.PARAMETER DatabaseFile
    CSV database to update. Defaults to modlist.csv in the current directory.

.PARAMETER ApiResponseFolder
    API response/cache directory. Defaults to apiresponse.

.PARAMETER CurrentOnly
    Update CurrentVersion fields only and leave LatestVersion fields unchanged.

.PARAMETER SkipValidation
    Set the version without contacting the configured provider. URLs and JAR metadata
    are left unchanged. Intended for controlled/manual database repairs and tests.

.EXAMPLE
    .\Set-ModVersion.ps1 -ModID "servux" -Version "0.9.5"

.EXAMPLE
    .\Set-ModVersion.ps1 -ModID "servux" -Version "0.9.5" -CurrentOnly

.EXAMPLE
    .\Set-ModVersion.ps1 -ModID "servux" -Version "0.9.5" -SkipValidation -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [Alias("Id")]
    [ValidateNotNullOrEmpty()]
    [string]$ModID,

    [Parameter(Mandatory = $true)]
    [Alias("ModVersion")]
    [ValidateNotNullOrEmpty()]
    [string]$Version,

    [string]$GameVersion = "",

    [Alias("CsvPath", "ModListFile")]
    [string]$DatabaseFile = "modlist.csv",

    [string]$ApiResponseFolder = "apiresponse",

    [switch]$CurrentOnly,
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-ValuePresent {
    param([object]$Value)

    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return -not [string]::IsNullOrWhiteSpace($Value) }
    return $true
}

function Get-ResultValue {
    param(
        [object]$Result,
        [string]$Name
    )

    if ($null -eq $Result) { return $null }

    if ($Result -is [System.Collections.IDictionary]) {
        if ($Result.Contains($Name)) { return $Result[$Name] }
        return $null
    }

    $property = $Result.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Set-RecordProperty {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Record,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [object]$Value,
        [switch]$AllowEmpty
    )

    if (-not $AllowEmpty -and -not (Test-ValuePresent -Value $Value)) { return }

    if ($Record.PSObject.Properties.Name -contains $Name) {
        $Record.$Name = $Value
    } else {
        $Record | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

$tempValidationCsv = $null

try {
    $projectRoot = $PSScriptRoot
    . (Join-Path $projectRoot "src\Import-Modules.ps1")

    $script:DefaultLoader = "fabric"
    $script:DefaultGameVersion = if (Test-ValuePresent -Value $GameVersion) { $GameVersion } else { "1.21.11" }
    $script:ApiResponseFolder = $ApiResponseFolder

    try { Load-EnvironmentVariables } catch { }

    $csvPath = if ([System.IO.Path]::IsPathRooted($DatabaseFile)) {
        $DatabaseFile
    } else {
        Join-Path (Get-Location) $DatabaseFile
    }

    if (-not (Test-Path -LiteralPath $csvPath)) {
        throw "Database file not found: $csvPath"
    }

    $mods = @(Import-Csv -LiteralPath $csvPath)
    $matches = @($mods | Where-Object { $_.ID -eq $ModID })

    if ($matches.Count -eq 0) {
        throw "Mod with ID '$ModID' was not found in $csvPath"
    }
    if ($matches.Count -gt 1) {
        throw "Mod ID '$ModID' is not unique in $csvPath ($($matches.Count) rows found)"
    }

    $mod = $matches[0]
    $loader = if (Test-ValuePresent -Value $mod.Loader) { $mod.Loader } else { "fabric" }
    $targetGameVersion = if (Test-ValuePresent -Value $GameVersion) {
        $GameVersion
    } elseif (Test-ValuePresent -Value $mod.CurrentGameVersion) {
        $mod.CurrentGameVersion
    } else {
        $script:DefaultGameVersion
    }

    $validationResult = $null
    $resolvedVersion = $Version

    if (-not $SkipValidation) {
        # Provider routing needs the CSV row, but validation must not be able to
        # partially rewrite the real database. Give it a disposable migrated copy.
        $providerRows = foreach ($row in $mods) {
            $copy = $row.PSObject.Copy()
            if (-not ($copy.PSObject.Properties.Name -contains "Version")) {
                $legacyVersion = if ($copy.PSObject.Properties.Name -contains "CurrentVersion") { $copy.CurrentVersion } else { "" }
                $copy | Add-Member -MemberType NoteProperty -Name "Version" -Value $legacyVersion
            }
            $copy
        }

        $tempValidationCsv = Join-Path ([System.IO.Path]::GetTempPath()) "mod-manager-set-version-$([guid]::NewGuid().ToString('N')).csv"
        $providerRows | Export-Csv -LiteralPath $tempValidationCsv -NoTypeInformation

        Write-Host "Validating $ModID version $Version for $loader/$targetGameVersion..." -ForegroundColor Cyan
        $validationResult = Validate-ModVersion `
            -ModId $ModID `
            -Version $Version `
            -Loader $loader `
            -GameVersion $targetGameVersion `
            -ResponseFolder $ApiResponseFolder `
            -CsvPath $tempValidationCsv

        $exists = [bool](Get-ResultValue -Result $validationResult -Name "Exists")
        if (-not $exists) {
            $validationError = Get-ResultValue -Result $validationResult -Name "Error"
            if (-not (Test-ValuePresent -Value $validationError)) { $validationError = "Provider validation failed" }
            throw $validationError
        }

        $providerVersion = Get-ResultValue -Result $validationResult -Name "LatestVersion"
        if (-not (Test-ValuePresent -Value $providerVersion)) {
            $providerVersion = Get-ResultValue -Result $validationResult -Name "Version"
        }
        if (Test-ValuePresent -Value $providerVersion) {
            $resolvedVersion = [string]$providerVersion
        }

        if ($resolvedVersion -ne $Version) {
            throw "Requested version '$Version' resolved to '$resolvedVersion'. Set-ModVersion requires an exact version."
        }
    }

    $oldCurrentVersion = if ($mod.PSObject.Properties.Name -contains "CurrentVersion") { $mod.CurrentVersion } else { "" }

    if (-not $PSCmdlet.ShouldProcess($csvPath, "Set $ModID version from '$oldCurrentVersion' to '$resolvedVersion'")) {
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$csvPath.set-version.$timestamp.bak"
    Copy-Item -LiteralPath $csvPath -Destination $backupPath -Force

    Set-RecordProperty -Record $mod -Name "CurrentVersion" -Value $resolvedVersion -AllowEmpty

    if ($validationResult) {
        $versionUrl = Get-ResultValue -Result $validationResult -Name "VersionUrl"
        if (-not (Test-ValuePresent -Value $versionUrl)) {
            $versionUrl = Get-ResultValue -Result $validationResult -Name "LatestVersionUrl"
        }

        Set-RecordProperty -Record $mod -Name "CurrentVersionUrl" -Value $versionUrl
        Set-RecordProperty -Record $mod -Name "Jar" -Value (Get-ResultValue -Result $validationResult -Name "Jar")
        Set-RecordProperty -Record $mod -Name "Title" -Value (Get-ResultValue -Result $validationResult -Name "Title")
        Set-RecordProperty -Record $mod -Name "ProjectDescription" -Value (Get-ResultValue -Result $validationResult -Name "ProjectDescription")
        Set-RecordProperty -Record $mod -Name "IconUrl" -Value (Get-ResultValue -Result $validationResult -Name "IconUrl")
        Set-RecordProperty -Record $mod -Name "IssuesUrl" -Value (Get-ResultValue -Result $validationResult -Name "IssuesUrl")
        Set-RecordProperty -Record $mod -Name "SourceUrl" -Value (Get-ResultValue -Result $validationResult -Name "SourceUrl")
        Set-RecordProperty -Record $mod -Name "WikiUrl" -Value (Get-ResultValue -Result $validationResult -Name "WikiUrl")
        Set-RecordProperty -Record $mod -Name "ClientSide" -Value (Get-ResultValue -Result $validationResult -Name "ClientSide")
        Set-RecordProperty -Record $mod -Name "ServerSide" -Value (Get-ResultValue -Result $validationResult -Name "ServerSide")
        Set-RecordProperty -Record $mod -Name "CurrentDependencies" -Value (Get-ResultValue -Result $validationResult -Name "CurrentDependencies") -AllowEmpty
        Set-RecordProperty -Record $mod -Name "CurrentDependenciesRequired" -Value (Get-ResultValue -Result $validationResult -Name "CurrentDependenciesRequired") -AllowEmpty
        Set-RecordProperty -Record $mod -Name "CurrentDependenciesOptional" -Value (Get-ResultValue -Result $validationResult -Name "CurrentDependenciesOptional") -AllowEmpty
    }

    if (-not $CurrentOnly) {
        Set-RecordProperty -Record $mod -Name "LatestVersion" -Value $resolvedVersion -AllowEmpty

        if ($validationResult) {
            $latestUrl = Get-ResultValue -Result $validationResult -Name "LatestVersionUrl"
            if (-not (Test-ValuePresent -Value $latestUrl)) {
                $latestUrl = Get-ResultValue -Result $validationResult -Name "VersionUrl"
            }
            $latestGameVersion = Get-ResultValue -Result $validationResult -Name "LatestGameVersion"
            if (-not (Test-ValuePresent -Value $latestGameVersion)) { $latestGameVersion = $targetGameVersion }

            Set-RecordProperty -Record $mod -Name "LatestVersionUrl" -Value $latestUrl
            Set-RecordProperty -Record $mod -Name "LatestGameVersion" -Value $latestGameVersion
            Set-RecordProperty -Record $mod -Name "LatestDependencies" -Value (Get-ResultValue -Result $validationResult -Name "LatestDependencies") -AllowEmpty
            Set-RecordProperty -Record $mod -Name "LatestDependenciesRequired" -Value (Get-ResultValue -Result $validationResult -Name "LatestDependenciesRequired") -AllowEmpty
            Set-RecordProperty -Record $mod -Name "LatestDependenciesOptional" -Value (Get-ResultValue -Result $validationResult -Name "LatestDependenciesOptional") -AllowEmpty
        }
    }

    Set-RecordProperty -Record $mod -Name "RecordHash" -Value (Calculate-RecordHash -Record $mod) -AllowEmpty
    $mods | Export-Csv -LiteralPath $csvPath -NoTypeInformation

    Write-Host "✅ Updated '$ModID' from version '$oldCurrentVersion' to '$resolvedVersion'" -ForegroundColor Green
    Write-Host "   Game version: $targetGameVersion" -ForegroundColor Cyan
    if (Test-ValuePresent -Value $mod.Jar) { Write-Host "   JAR: $($mod.Jar)" -ForegroundColor Cyan }
    Write-Host "   Backup: $backupPath" -ForegroundColor DarkGray
    exit 0
}
catch {
    Write-Host "❌ Failed to set version for '$ModID': $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($tempValidationCsv -and (Test-Path -LiteralPath $tempValidationCsv)) {
        Remove-Item -LiteralPath $tempValidationCsv -Force -ErrorAction SilentlyContinue
    }
}
