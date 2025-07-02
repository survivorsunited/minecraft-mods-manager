# =============================================================================
# Utility Functions Module
# =============================================================================
# This module contains all utility/helper functions used throughout the project.
# Includes hashing, file operations, version normalization, and other helpers.
# =============================================================================

<#
.SYNOPSIS
    Calculates the SHA256 hash of a file.
.DESCRIPTION
    Computes the SHA256 hash for the specified file path.
.PARAMETER FilePath
    The path to the file to hash.
.EXAMPLE
    Calculate-FileHash -FilePath "mod.jar"
#>
function Calculate-FileHash {
    param([Parameter(Mandatory=$true)][string]$FilePath)
    try {
        if (-not (Test-Path $FilePath)) { return $null }
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($FilePath)
        try {
            $hash = $sha256.ComputeHash($stream)
            return ([BitConverter]::ToString($hash) -replace '-', '').ToLower()
        } finally {
            $stream.Dispose()
        }
    } catch {
        Write-Host "Failed to hash $FilePath: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

<#
.SYNOPSIS
    Calculates a record hash for a mod entry.
.DESCRIPTION
    Computes a unique hash for a mod record based on its key fields.
.PARAMETER Mod
    The mod object/record to hash.
.EXAMPLE
    Calculate-RecordHash -Mod $mod
#>
function Calculate-RecordHash {
    param([Parameter(Mandatory=$true)]$Mod)
    $fields = @('ID','Version','GameVersion','Loader','Type')
    $concat = ($fields | ForEach-Object { $Mod.$_ }) -join '|'
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($concat)
    $hash = $sha256.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLower()
}

<#
.SYNOPSIS
    Normalizes a version string.
.DESCRIPTION
    Cleans and normalizes a version string for comparison.
.PARAMETER Version
    The version string to normalize.
.EXAMPLE
    Normalize-Version -Version "1.21.5"
#>
function Normalize-Version {
    param([Parameter(Mandatory=$true)][string]$Version)
    return ($Version -replace '[^0-9a-zA-Z\.-]', '').ToLower()
}

<#
.SYNOPSIS
    Cleans a filename for safe use.
.DESCRIPTION
    Removes invalid characters from a filename.
.PARAMETER Name
    The filename to clean.
.EXAMPLE
    Clean-Filename -Name "mod:api?*"
#>
function Clean-Filename {
    param([Parameter(Mandatory=$true)][string]$Name)
    return ($Name -replace '[\\/:*?"<>|]', '_')
}

# Export functions for use in other modules
Export-ModuleMember -Function @(
    'Calculate-FileHash',
    'Calculate-RecordHash',
    'Normalize-Version',
    'Clean-Filename'
) 