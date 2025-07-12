# =============================================================================
# File Hash Calculation Module
# =============================================================================
# This module handles SHA256 hash calculation for files.
# =============================================================================

<#
.SYNOPSIS
    Calculates the SHA256 hash of a file.

.DESCRIPTION
    Computes the SHA256 hash for the specified file path using secure cryptographic methods.

.PARAMETER FilePath
    The path to the file to hash.

.EXAMPLE
    Calculate-FileHash -FilePath "mod.jar"

.NOTES
    - Uses SHA256 algorithm for secure hashing
    - Returns null if file doesn't exist or hash calculation fails
    - Returns lowercase hex string of the hash
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
        Write-Host "Failed to hash $($FilePath): $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing 