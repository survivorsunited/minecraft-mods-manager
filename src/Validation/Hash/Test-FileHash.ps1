# =============================================================================
# File Hash Verification Module
# =============================================================================
# This module handles verification of file hashes for integrity checking.
# =============================================================================

<#
.SYNOPSIS
    Verifies file hash against expected hash.

.DESCRIPTION
    Calculates the hash of a file and compares it against an expected hash
    to verify file integrity.

.PARAMETER FilePath
    The path to the file to verify.

.PARAMETER ExpectedHash
    The expected hash value to compare against.

.EXAMPLE
    Test-FileHash -FilePath "mod.jar" -ExpectedHash "abc123..."

.NOTES
    - Uses SHA256 hash calculation
    - Returns false if file doesn't exist or hash calculation fails
    - Returns true if hashes match
#>
function Test-FileHash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [string]$ExpectedHash
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            return $false
        }
        
        $actualHash = Calculate-FileHash -FilePath $FilePath
        if (-not $actualHash) {
            return $false
        }
        
        return $actualHash -eq $ExpectedHash
    }
    catch {
        Write-Warning "Failed to verify hash for $FilePath : $($_.Exception.Message)"
        return $false
    }
}

# Function is available for dot-sourcing 