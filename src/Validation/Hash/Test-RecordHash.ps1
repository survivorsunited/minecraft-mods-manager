# =============================================================================
# Record Hash Verification Module
# =============================================================================
# This module handles verification of record hashes for data integrity.
# =============================================================================

<#
.SYNOPSIS
    Verifies CSV record hash for data integrity.

.DESCRIPTION
    Calculates the hash of a CSV record and compares it against the stored
    hash to verify data integrity.

.PARAMETER Record
    The CSV record object to verify.

.EXAMPLE
    Test-RecordHash -Record $modRecord

.NOTES
    - Uses SHA256 hash calculation
    - Returns false if record has no hash or calculation fails
    - Returns true if hashes match
#>
function Test-RecordHash {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Record
    )
    
    try {
        if (-not $Record.RecordHash) {
            return $false
        }
        
        $calculatedHash = Calculate-RecordHash -Record $Record
        if (-not $calculatedHash) {
            return $false
        }
        
        return $calculatedHash -eq $Record.RecordHash
    }
    catch {
        Write-Warning "Failed to verify record hash: $($_.Exception.Message)"
        return $false
    }
}

# Function is available for dot-sourcing 