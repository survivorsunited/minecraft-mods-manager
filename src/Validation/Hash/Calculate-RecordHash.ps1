# =============================================================================
# Record Hash Calculation Module
# =============================================================================
# This module handles hash calculation for mod records and CSV entries.
# =============================================================================

<#
.SYNOPSIS
    Calculates a record hash for a CSV mod entry.

.DESCRIPTION
    Computes a SHA256 hash for a CSV record by concatenating all fields
    except RecordHash itself. Sorting keys ensures stable ordering.

.PARAMETER Record
    The PSCustomObject record to hash.

.EXAMPLE
    Calculate-RecordHash -Record $mod

.NOTES
    - Excludes RecordHash from calculation
    - Returns lowercase hex string of the hash
#>
function Calculate-RecordHash {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Record
    )

    try {
        # Build key=value pairs for all fields except RecordHash
        $recordData = @()
        $Record.PSObject.Properties |
            Where-Object { $_.Name -ne 'RecordHash' } |
            ForEach-Object { $recordData += ("$($_.Name)=$($_.Value)") }

        # Sort for stable ordering
        $recordData = $recordData | Sort-Object

        $recordString = $recordData -join '|'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($recordString)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($bytes)
        $hash = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
        return $hash.ToLower()
    } catch {
        Write-Warning "Failed to calculate record hash: $($_.Exception.Message)"
        return $null
    }
}

# Function is available for dot-sourcing 