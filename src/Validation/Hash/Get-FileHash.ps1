# =============================================================================
# File Hash Validation Module
# =============================================================================
# This module handles file hash calculation and validation.
# =============================================================================

<#
.SYNOPSIS
    Calculates SHA256 hash of a file.

.DESCRIPTION
    Calculates the SHA256 hash of a file for integrity verification.

.PARAMETER FilePath
    The path to the file to hash.

.EXAMPLE
    Calculate-FileHash -FilePath "mod.jar"

.NOTES
    - Returns SHA256 hash as lowercase string
    - Returns null if file doesn't exist or hash calculation fails
#>
function Calculate-FileHash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            return $null
        }
        
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        return $hash.Hash
    }
    catch {
        Write-Warning "Failed to calculate hash for $FilePath : $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Calculates hash of a CSV record.

.DESCRIPTION
    Calculates SHA256 hash of a CSV record for integrity verification.

.PARAMETER Record
    The PSCustomObject record to hash.

.EXAMPLE
    Calculate-RecordHash -Record $modRecord

.NOTES
    - Creates string representation of all record fields
    - Excludes RecordHash field from calculation
    - Returns SHA256 hash as lowercase string
#>
function Calculate-RecordHash {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Record
    )
    
    try {
        # Create a string representation of all record fields (excluding RecordHash itself)
        $recordData = @()
        $record.PSObject.Properties | Where-Object { $_.Name -ne "RecordHash" } | ForEach-Object {
            $recordData += "$($_.Name)=$($_.Value)"
        }
        
        # Sort the data to ensure consistent hashing
        $recordData = $recordData | Sort-Object
        
        # Create the hash
        $recordString = $recordData -join "|"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($recordString)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($bytes)
        $hash = [System.BitConverter]::ToString($hashBytes) -replace "-", ""
        
        return $hash.ToLower()
    }
    catch {
        Write-Warning "Failed to calculate record hash: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Verifies file hash against expected value.

.DESCRIPTION
    Compares calculated hash of a file against expected hash value.

.PARAMETER FilePath
    The path to the file to verify.

.PARAMETER ExpectedHash
    The expected hash value to compare against.

.EXAMPLE
    Test-FileHash -FilePath "mod.jar" -ExpectedHash "abc123..."

.NOTES
    - Returns true if hashes match
    - Returns false if file doesn't exist or hashes don't match
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

<#
.SYNOPSIS
    Verifies CSV record hash.

.DESCRIPTION
    Compares calculated hash of a record against stored hash value.

.PARAMETER Record
    The PSCustomObject record to verify.

.EXAMPLE
    Test-RecordHash -Record $modRecord

.NOTES
    - Returns true if hashes match
    - Returns false if record has no hash or hashes don't match
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