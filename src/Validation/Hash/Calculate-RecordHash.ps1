# =============================================================================
# Record Hash Calculation Module
# =============================================================================
# This module handles hash calculation for mod records and CSV entries.
# =============================================================================

<#
.SYNOPSIS
    Calculates a record hash for a mod entry.

.DESCRIPTION
    Computes a unique hash for a mod record based on its key fields to ensure
    data integrity and detect changes.

.PARAMETER Mod
    The mod object/record to hash.

.EXAMPLE
    Calculate-RecordHash -Mod $mod

.NOTES
    - Uses key fields: ID, Version, GameVersion, Loader, Type
    - Creates consistent hash for data integrity checking
    - Returns lowercase hex string of the hash
#>
function Calculate-RecordHash {
    param([Parameter(Mandatory=$true)]$Mod)
    $fields = @('ID','Version','GameVersion','Loader','Type')
    $concat = ($fields | ForEach-Object { $Mod.($_)} ) -join '|'
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($concat)
    $hash = $sha256.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLower()
}

# Function is available for dot-sourcing 